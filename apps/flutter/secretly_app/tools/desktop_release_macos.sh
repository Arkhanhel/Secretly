#!/usr/bin/env bash
# Secretly Desktop — macOS RELEASE build, sign, notarize, package.
#
# Companion to tools/desktop_build_macos.sh (which is --debug only). This is the
# shippable path: AOT --release, the ffmpeg self-containment fix, optional
# Developer ID signing + notarization, and an optional DMG.
#
# Implements: R-01 (release build),
# R-02 (target assertion), R-07 (sign embedded natives inside-out),
# R-08 (ffmpeg dylib fix), R-10 (iCloud xattr trap).
#
# ---------------------------------------------------------------------------
# USAGE
#
#   bash tools/desktop_release_macos.sh                 # auto-picks a stable identity
#   SECRETLY_SIGN_IDENTITY="Developer ID Application: … (3HF84UAL32)" \
#     bash tools/desktop_release_macos.sh               # name the identity yourself
#   SECRETLY_SIGN_IDENTITY="…" SECRETLY_NOTARY_PROFILE=secretly \
#     bash tools/desktop_release_macos.sh               # + notarize & staple
#   SECRETLY_MAKE_DMG=1 bash tools/desktop_release_macos.sh   # + DMG
#
# ENV
#   SECRETLY_SIGN_IDENTITY   Signing identity. Unset → auto-selected (Developer
#                            ID first, then a Secretly Apple Development cert).
#                            A STABLE identity is what stops the macOS keychain
#                            prompt storm — see the signing section below.
#   SECRETLY_FORCE_ADHOC=1   Skip auto-selection and sign ad-hoc. Only to
#                            reproduce the old behaviour; the app will then ask
#                            for the keychain password on every launch.
#   SECRETLY_NOTARY_PROFILE  `xcrun notarytool` keychain profile name. Requires
#                            SECRETLY_SIGN_IDENTITY. Create once with:
#                              xcrun notarytool store-credentials secretly \
#                                --apple-id <id> --team-id 3HF84UAL32 --password <app-specific>
#   SECRETLY_MAKE_DMG=1      Build a DMG next to the .app.
#   SECRETLY_BUILD_NAME      Version shown to people, e.g. 1.8.51. Defaults to
#                            pubspec.yaml — which LAGS BEHIND on purpose (the
#                            number always comes from flags at release time),
#                            so a real release must pass this.
#   SECRETLY_BUILD_NUMBER    Build number, e.g. 610. Same rule.
#   SECRETLY_UPDATE_BASE_URL Where the DMG and appcast.xml will be published,
#                            e.g. https://example.com/updates/. When set (and
#                            with a DMG), the script signs the DMG with the
#                            Sparkle EdDSA key from the keychain and writes
#                            appcast.xml next to it. Without it, no appcast is
#                            produced — an appcast pointing at a URL nobody
#                            serves would tell every installed copy that an
#                            update exists and then fail to fetch it.
#   SECRETLY_LOCAL_DEV=1     Skip production endpoints (use in-code localhost).
#   SECRETLY_KEYS_BASE_URL / SECRETLY_RELAY_HTTP_BASE_URL / SECRETLY_RELAY_WS_URL
#                            Per-env endpoint overrides.
#
# NOTE: this script never flips store prices, never touches prod config flags,
# and never uploads anything. Notarization submits the binary to Apple only when
# SECRETLY_NOTARY_PROFILE is explicitly set.
# ---------------------------------------------------------------------------

set -euo pipefail

# Make a failure impossible to miss. A caller that pipes this script into
# `tail`/`tee` sees the PIPE's exit code, not ours, so a mid-script death can
# otherwise look like a clean run — which is exactly how a silently-skipped
# signing step once produced an "successful" ad-hoc build.
trap 's=$?; [ $s -ne 0 ] && echo "" && echo "!!! desktop_release_macos.sh FAILED at line $LINENO (exit $s) — the artifact is NOT complete" >&2; exit $s' ERR

cd "$(dirname "$0")/.."
PROJECT_DIR="$(pwd)"

# R-02: the desktop entry point is NOT the default main.dart. Building the wrong
# target silently ships the MOBILE app in a desktop window — assert it exists.
TARGET="lib/main_desktop.dart"
if [ ! -f "$PROJECT_DIR/$TARGET" ]; then
  echo "error: desktop target $TARGET not found — refusing to build." >&2
  echo "       (the default lib/main.dart is the MOBILE app; never ship it as desktop)" >&2
  exit 1
fi

# -------------------------------------------------------------------------
# R-10 / R-12: keep Xcode's product dir OUTSIDE iCloud.
#
# The repo lives under an iCloud-synced path; the file-provider daemon stamps
# new files with com.apple.fileprovider / com.apple.FinderInfo xattrs, and
# codesign refuses to sign anything carrying them. Symlinking build/macos to a
# cache dir sidesteps the race entirely. `flutter clean` wipes build/, so this
# has to be re-established on every run.
# -------------------------------------------------------------------------
EXTERNAL_BUILD="$HOME/Library/Caches/secretly_app_build_macos"
mkdir -p "$EXTERNAL_BUILD" "$PROJECT_DIR/build"
if [ -L "$PROJECT_DIR/build/macos" ]; then
  current="$(readlink "$PROJECT_DIR/build/macos")"
  if [ "$current" != "$EXTERNAL_BUILD" ]; then
    rm "$PROJECT_DIR/build/macos"
    ln -s "$EXTERNAL_BUILD" "$PROJECT_DIR/build/macos"
  fi
elif [ -e "$PROJECT_DIR/build/macos" ]; then
  rm -rf "$PROJECT_DIR/build/macos"
  ln -s "$EXTERNAL_BUILD" "$PROJECT_DIR/build/macos"
else
  ln -s "$EXTERNAL_BUILD" "$PROJECT_DIR/build/macos"
fi
echo "==> build/macos -> $(readlink "$PROJECT_DIR/build/macos")"

# -------------------------------------------------------------------------
# Production endpoints (same defaults as the debug helper). Without these the
# binary falls back to localhost and the desktop hangs on "Подключение…".
# -------------------------------------------------------------------------
KEYS_BASE_URL="${SECRETLY_KEYS_BASE_URL:-https://keys.secretlyapp.com}"
RELAY_HTTP_BASE_URL="${SECRETLY_RELAY_HTTP_BASE_URL:-https://relay.secretlyapp.com}"
RELAY_WS_URL="${SECRETLY_RELAY_WS_URL:-wss://relay.secretlyapp.com/ws}"

DART_DEFINES=()
if [ -z "${SECRETLY_LOCAL_DEV:-}" ]; then
  DART_DEFINES+=("--dart-define=SECRETLY_KEYS_BASE_URL=$KEYS_BASE_URL")
  DART_DEFINES+=("--dart-define=SECRETLY_RELAY_HTTP_BASE_URL=$RELAY_HTTP_BASE_URL")
  DART_DEFINES+=("--dart-define=SECRETLY_RELAY_WS_URL=$RELAY_WS_URL")
  echo "==> endpoints: keys=$KEYS_BASE_URL relay=$RELAY_HTTP_BASE_URL ws=$RELAY_WS_URL"
else
  echo "==> SECRETLY_LOCAL_DEV=1 — using in-code default endpoints"
fi

# Release builds must never boot the mock identity. Guard against a stray env.
if [ -n "${SECRETLY_DESKTOP_TEST_MODE:-}" ]; then
  echo "error: SECRETLY_DESKTOP_TEST_MODE is set — that mock-identity mode must" >&2
  echo "       never be baked into a release build. Unset it and re-run." >&2
  exit 1
fi

# -------------------------------------------------------------------------
# R-01: the actual AOT release build.
# -------------------------------------------------------------------------
# 🔴 НОМЕР ВЕРСИИ — ИЗ ФЛАГОВ, А НЕ ИЗ pubspec.yaml.
#
# В `pubspec.yaml` версия СОЗНАТЕЛЬНО отстаёт: у этого дерева номер на выпуске
# всегда задаётся флагами, как у телефонных сборок. Для обновлений это не
# мелочь: номер попадает в перечень версий, и по нему установленные копии
# решают, есть ли обновление. Собрать выпуск со старым номером значит либо не
# предложить обновление никому, либо предложить «обновиться» на то, что уже
# стоит.
VERSION_ARGS=()
if [ -n "${SECRETLY_BUILD_NAME:-}" ]; then
  VERSION_ARGS+=("--build-name=$SECRETLY_BUILD_NAME")
fi
if [ -n "${SECRETLY_BUILD_NUMBER:-}" ]; then
  VERSION_ARGS+=("--build-number=$SECRETLY_BUILD_NUMBER")
fi
if [ ${#VERSION_ARGS[@]} -eq 0 ]; then
  echo "    (no SECRETLY_BUILD_NAME/NUMBER — taking the version from pubspec.yaml,"
  echo "     which lags behind; fine for a local build, NOT for a release)"
fi

echo "==> flutter build macos --release --target=$TARGET"
flutter build macos --release --target="$TARGET" \
  ${VERSION_ARGS[@]+"${VERSION_ARGS[@]}"} \
  ${DART_DEFINES[@]+"${DART_DEFINES[@]}"} "$@"

APP_DIR="$PROJECT_DIR/build/macos/Build/Products/Release"
APP="$(/usr/bin/find "$APP_DIR" -maxdepth 1 -name '*.app' -print -quit 2>/dev/null || true)"
if [ -z "$APP" ] || [ ! -d "$APP" ]; then
  echo "error: no .app produced under $APP_DIR" >&2
  exit 1
fi
echo "==> built: $APP"

# -------------------------------------------------------------------------
# R-08: make the bundle launchable without Homebrew (ffmpeg absolute-path deps).
# MUST run BEFORE signing — it rewrites load commands inside the frameworks,
# which would otherwise invalidate their signatures.
# -------------------------------------------------------------------------
echo "==> fixing ffmpeg dylib dependencies"
bash "$PROJECT_DIR/tools/desktop_fix_ffmpeg_deps.sh" "$APP"

# -------------------------------------------------------------------------
# R-07: sign inside-out. `codesign --deep` is explicitly NOT used — it is
# unreliable for nested frameworks and Apple discourages it. We sign every
# embedded dylib/framework first, then the outer bundle, with the hardened
# runtime + entitlements that notarization requires.
# -------------------------------------------------------------------------
# -------------------------------------------------------------------------
# Signing identity.
#
# WHY THIS MATTERS BEYOND DISTRIBUTION — the keychain prompt storm.
#
# Secretly keeps its secrets in the macOS *login* keychain (the shared code
# sets `useDataProtectionKeyChain: false`). Items there carry an ACL that
# trusts a specific code signature. An **ad-hoc** signature is derived from the
# binary's own contents, so it changes on EVERY build — the ACL never matches
# the new binary, and macOS re-asks for every single item.
#
# There are ~12 such items (db passphrase, crypto key, per-profile secrets,
# per-device keys, entitlement state), which is why an ad-hoc build asks for
# the keychain password roughly ten times on every launch, and why clicking
# "Always Allow" never sticks.
#
# Signing with ANY stable identity fixes it: approve once per item, and the
# approval survives every later build. So we pick one automatically when the
# caller did not name one.
#
# Note: signing uses a private key from the keychain, so the FIRST signing run
# pops a macOS authorization dialog for that key. Approve it with "Always
# Allow" and later builds are silent.
# -------------------------------------------------------------------------
# The selection itself lives in tools/desktop_sign_identity.sh so the DEBUG
# path (desktop_fix_ffmpeg_deps.sh) uses the very same rules. It did not until
# 08.09.2026, and the storm this section describes survived there for a month.
. "$PROJECT_DIR/tools/desktop_sign_identity.sh"
IDENTITY="$(secretly_pick_sign_identity)"

if [ -n "$IDENTITY" ] && [ -z "${SECRETLY_SIGN_IDENTITY:-}" ]; then
  echo "==> auto-selected signing identity: $IDENTITY"
  echo "    (SECRETLY_SIGN_IDENTITY overrides; SECRETLY_FORCE_ADHOC=1 keeps"
  echo "     the old ad-hoc behaviour and its keychain prompts)"
fi

if [ -z "$IDENTITY" ]; then
  echo "==> WARNING: no signing identity — falling back to an ad-hoc signature."
  echo "    Expect macOS to ask for the keychain password on EVERY launch,"
  echo "    once per stored secret, because an ad-hoc signature changes with"
  echo "    every build and the keychain ACL can never match it."
fi

if [ -n "$IDENTITY" ]; then
  ENTITLEMENTS="$PROJECT_DIR/macos/Runner/Release.entitlements"
  if [ ! -f "$ENTITLEMENTS" ]; then
    echo "error: entitlements not found at $ENTITLEMENTS" >&2
    exit 1
  fi
  echo "==> signing inside-out as: $IDENTITY"

  # A secure timestamp is a NOTARIZATION requirement, and it costs a network
  # round-trip to Apple's timestamp server per signed item — with dozens of
  # embedded frameworks that turns a local build into a multi-minute stall, and
  # it hangs outright when the network is unavailable. Request it only when we
  # are actually going to notarize.
  if [ -n "${SECRETLY_NOTARY_PROFILE:-}" ]; then
    TS_FLAG="--timestamp"
  else
    TS_FLAG="--timestamp=none"
    echo "    (no notarization requested — skipping secure timestamps)"
  fi

  # 🔴 ПОРЯДОК: СНАЧАЛА ТО, ЧТО ЛЕЖИТ ГЛУБЖЕ. БЕЗ ИСКЛЮЧЕНИЙ.
  #
  # Раньше здесь было два прохода: сперва все `.framework`/`.dylib`, потом
  # `.xpc`/`.app`. Пока внутри рамок ничего не лежало, разница не видна. С
  # Sparkle (A-4) она стала поломкой: его `XPCServices/*.xpc`, `Updater.app`
  # и `Autoupdate` лежат ВНУТРИ `Sparkle.framework`, и подпись вложенного
  # ПОСЛЕ подписи рамки ломает подпись рамки — проверка видит изменившееся
  # содержимое. То же правило уже записано в шапке этого блока, но порядок
  # ему не следовал.
  #
  # Теперь список собирается один и сортируется по ГЛУБИНЕ ПУТИ по убыванию:
  # что бы ни вложили внутрь чего, вложенное подпишется раньше.
  #
  # Почему пересобирать подписи вообще надо: Sparkle приезжает уже подписанным
  # СВОЕЙ командой. Заверение у Apple отвергает бандл, внутри которого код
  # подписан чужой командой, — поэтому каждая вложенная часть переподписывается
  # нашим сертификатом.
  sign_list="$(mktemp)"
  # Бандлы и библиотеки.
  /usr/bin/find "$APP/Contents" \
      \( -name '*.dylib' -o -name '*.so' -o -name '*.framework' \
         -o -name '*.xpc' -o -name '*.app' \) \
      -mindepth 1 2>/dev/null >>"$sign_list" || true
  # Голые исполняемые файлы внутри рамок: у Sparkle это `Autoupdate` —
  # программа, которая и ставит обновление. Она не бандл, под шаблоны выше не
  # попадает, а остаться подписанной чужой командой не может.
  /usr/bin/find "$APP/Contents/Frameworks" -type f -perm -u+x \
      ! -name '*.dylib' ! -name '*.so' 2>/dev/null \
      | while IFS= read -r f; do
          case "$(/usr/bin/file -b "$f" 2>/dev/null)" in
            *Mach-O*executable*) echo "$f" ;;
          esac
        done >>"$sign_list" || true

  # Сортировка по числу «/» в пути, по убыванию — то есть сверху самое
  # глубокое. `sort -rn` по первому полю, само поле потом отрезается.
  while IFS= read -r nested; do
    [ -n "$nested" ] || continue
    codesign --force "$TS_FLAG" --options runtime \
      --sign "$IDENTITY" "$nested"
  done < <(awk -F/ '{print NF"\t"$0}' "$sign_list" | sort -rn -k1,1 | cut -f2-)
  rm -f "$sign_list"

  # Finally the outer bundle.
  codesign --force "$TS_FLAG" --options runtime \
    --entitlements "$ENTITLEMENTS" \
    --sign "$IDENTITY" "$APP"

  echo "==> verifying signature"
  codesign --verify --deep --strict --verbose=2 "$APP"
  # RK-5 guard: the encrypted-DB stack (sqlite3mc) is one of the embedded
  # natives. If it failed to sign or got stripped, the app opens with a broken
  # PRAGMA key at runtime — surface it here rather than in the field.
  if ! /usr/bin/find "$APP/Contents/Frameworks" -iname '*sqlite3*' | grep -q .; then
    echo "WARNING: no sqlite3/sqlite3mc artefact found under Frameworks." >&2
    echo "         Verify the encrypted database still opens in this build." >&2
  fi
else
  echo "==> SECRETLY_SIGN_IDENTITY unset — leaving Flutter's ad-hoc signature."
  echo "    This build runs on THIS machine only; Gatekeeper blocks it elsewhere."
fi

# -------------------------------------------------------------------------
# R-06: notarize + staple (opt-in, requires a real Developer ID signature).
# -------------------------------------------------------------------------
NOTARY_PROFILE="${SECRETLY_NOTARY_PROFILE:-}"
if [ -n "$NOTARY_PROFILE" ]; then
  if [ -z "$IDENTITY" ]; then
    echo "error: notarization requested but the build is signed ad-hoc." >&2
    echo "       Apple only notarizes Developer ID-signed code." >&2
    exit 1
  fi
  # 🔴 ПРОВЕРКА ТИПА СЕРТИФИКАТА, А НЕ ФАКТА ПОДПИСИ.
  #
  # Раньше здесь спрашивалось только «подписано ли хоть чем-нибудь». Но
  # сертификат выбирается автоматически, и на машине, где нет Developer ID,
  # выбор падал на Apple Development — проверка пропускала, а отказ приходил
  # от Apple через несколько минут ожидания и чужими словами. Отказывать надо
  # СРАЗУ и своими: Apple заверяет только код, подписанный Developer ID.
  case "$IDENTITY" in
    "Developer ID Application"*) ;;
    *)
      echo "error: notarization needs a Developer ID Application certificate." >&2
      echo "       this build is signed with: $IDENTITY" >&2
      echo "       set SECRETLY_SIGN_IDENTITY, or create the certificate:" >&2
      echo "       Xcode > Settings > Accounts > Manage Certificates > + " >&2
      echo "       Apple Development is for your own machines and Apple" >&2
      echo "       Distribution is for the App Store; neither can be" >&2
      echo "       notarized for download." >&2
      exit 1
      ;;
  esac
  # 🔴 ЕСЛИ АДРЕС ОБНОВЛЕНИЙ НЕ ОТВЕЧАЕТ — НЕ ОТГРУЖАЕМ.
  #
  # Заверение означает «эту сборку отдадут людям». Сборка, у которой
  # `SUFeedURL` указывает в пустоту, будет у каждого показывать «не удалось
  # проверить обновления» — и, что хуже, останется без обновлений насовсем,
  # потому что адрес зашит в неё навсегда. Ошибиться здесь можно один раз и
  # узнать об этом только от людей.
  #
  # Проверка читается из самого Info.plist собранного приложения, а не из
  # переменной: врать может переменная, а не то, что реально уехало в сборку.
  FEED_URL="$(/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' \
    "$APP/Contents/Info.plist" 2>/dev/null || true)"
  if [ -n "$FEED_URL" ]; then
    echo "==> checking the update feed is live: $FEED_URL"
    if ! /usr/bin/curl -sfI --max-time 15 "$FEED_URL" >/dev/null 2>&1; then
      echo "error: the update feed does not answer: $FEED_URL" >&2
      echo "       this build would ship with auto-update pointing at nothing." >&2
      echo "       publish appcast.xml there first (see the updates.* block in" >&2
      echo "       server/proxy/caddy/Caddyfile), or unset SUFeedURL to ship" >&2
      echo "       without the updater." >&2
      exit 1
    fi
  fi

  ZIP="$APP_DIR/$(basename "${APP%.app}")-notarize.zip"
  echo "==> submitting to Apple notary service (profile: $NOTARY_PROFILE)"
  /usr/bin/ditto -c -k --keepParent "$APP" "$ZIP"
  xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
  echo "==> stapling ticket"
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
  rm -f "$ZIP"
else
  echo "==> SECRETLY_NOTARY_PROFILE unset — skipping notarization."
fi

# -------------------------------------------------------------------------
# R-12: optional DMG.
# -------------------------------------------------------------------------
if [ -n "${SECRETLY_MAKE_DMG:-}" ]; then
  # 🔴 ИМЯ ОБРАЗА НЕСЁТ ВЕРСИЮ, И ЭТО НЕ КОСМЕТИКА.
  #
  # Образы раздаются с `Cache-Control: immutable` на год — так и должно быть,
  # содержимое версии не меняется никогда. Но при постоянном имени
  # `Secretly.dmg` тот же адрес указывал бы на РАЗНОЕ содержимое от выпуска к
  # выпуску, и промежуточные узлы весь год отдавали бы старый образ. Человек
  # видел бы «обновление есть», а скачивал бы прежнюю версию — и подпись в
  # перечне на неё не сошлась бы.
  DMG_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
    "$APP/Contents/Info.plist" 2>/dev/null || echo unknown)"
  DMG_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' \
    "$APP/Contents/Info.plist" 2>/dev/null || echo 0)"
  DMG="$APP_DIR/Secretly-$DMG_VERSION-$DMG_BUILD.dmg"
  echo "==> packaging $DMG"
  rm -f "$DMG"
  STAGE="$(mktemp -d)"
  cp -R "$APP" "$STAGE/"
  ln -s /Applications "$STAGE/Applications"
  /usr/bin/hdiutil create -volname "Secretly" -srcfolder "$STAGE" \
    -ov -format UDZO "$DMG" >/dev/null
  rm -rf "$STAGE"
  if [ -n "$IDENTITY" ]; then
    codesign --force "$TS_FLAG" --sign "$IDENTITY" "$DMG"
  fi
  # 🔴 ОБРАЗ ДИСКА ЗАВЕРЯЕТСЯ ОТДЕЛЬНО ОТ ПРИЛОЖЕНИЯ.
  #
  # Раньше заверялось только приложение, талон приклеивался к нему, а образ
  # оставался просто подписанным. Но человек скачивает ИМЕННО ОБРАЗ, и
  # Gatekeeper проверяет то, что скачано: незаверенный образ macOS не
  # открывает вовсе — «Apple не может проверить его на наличие вредоносного
  # ПО». То есть выпуск выглядел бы готовым и не открывался бы ни у кого.
  #
  # Подача вторая, отдельная: у приложения свой талон (оно работает и без
  # сети после того, как его скопировали), у образа — свой (он открывается).
  # Порядок обязателен: образ собирается из УЖЕ заверенного приложения, иначе
  # внутри окажется копия без талона.
  if [ -n "$NOTARY_PROFILE" ]; then
    echo "==> submitting the DMG to Apple notary service"
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
    xcrun stapler validate "$DMG"
  fi
  echo "==> DMG: $DMG"

  # -----------------------------------------------------------------------
  # Перечень версий для автообновления (Sparkle).
  # -----------------------------------------------------------------------
  #
  # 🔴 ПОДПИСЬ ПАКЕТА — НЕ ТО ЖЕ, ЧТО ПОДПИСЬ ПРИЛОЖЕНИЯ. Developer ID и
  # заверение отвечают на вопрос «можно ли это запустить»; подпись EdDSA
  # отвечает на другой — «мы ли это прислали». Обновление, скачанное с нашего
  # адреса, но подменённое по дороге, Gatekeeper пропустит: оно подписано
  # НАШИМ сертификатом только если подменивший его и есть мы. Поэтому Sparkle
  # проверяет свою подпись сам, ДО установки, и ключ для неё живёт отдельно —
  # в ключнице выпускающего, а не в дереве исходников.
  #
  # `generate_appcast` берёт закрытый ключ из ключницы сам, читает версию из
  # Info.plist внутри образа и пишет `appcast.xml` рядом.
  if [ -n "${SECRETLY_UPDATE_BASE_URL:-}" ]; then
    GEN_APPCAST="$PROJECT_DIR/macos/Pods/Sparkle/bin/generate_appcast"
    if [ ! -x "$GEN_APPCAST" ]; then
      echo "error: generate_appcast not found at $GEN_APPCAST" >&2
      echo "       run 'flutter build macos' once so CocoaPods fetches Sparkle." >&2
      exit 1
    fi
    # Отдельный каталог: `generate_appcast` перебирает ВСЁ, что в нём лежит, и
    # каталог сборки полон чужих файлов.
    UPDATES_DIR="$APP_DIR/updates"
    mkdir -p "$UPDATES_DIR"
    cp -f "$DMG" "$UPDATES_DIR/"
    echo "==> building appcast for $SECRETLY_UPDATE_BASE_URL"
    "$GEN_APPCAST" --download-url-prefix "$SECRETLY_UPDATE_BASE_URL" \
      "$UPDATES_DIR"
    if [ ! -f "$UPDATES_DIR/appcast.xml" ]; then
      echo "error: appcast.xml was not produced" >&2
      exit 1
    fi
    # 🔴 Без подписи в перечне обновление ставиться не будет — и узнаем мы об
    # этом от людей, у которых «проверка обновлений ничего не делает».
    if ! grep -q 'edSignature' "$UPDATES_DIR/appcast.xml"; then
      echo "error: appcast.xml carries no edSignature — the Sparkle key was" >&2
      echo "       not found in the keychain. Run generate_keys once." >&2
      exit 1
    fi
    echo "==> appcast: $UPDATES_DIR/appcast.xml"
    echo "    publish BOTH files at $SECRETLY_UPDATE_BASE_URL"
  fi
fi

echo
echo "=============================================================="
echo " RELEASE ARTIFACT: $APP"
[ -n "${SECRETLY_MAKE_DMG:-}" ] && echo " DMG:              ${DMG:-$APP_DIR}"
echo
# 🔴 ЯРЛЫК ПОДПИСИ НАЗЫВАЛ «Developer ID» ЛЮБОЙ СЕРТИФИКАТ.
#
# Строка печаталась как `Developer ID ($IDENTITY)` независимо от того, чем
# подписано на самом деле, — и на машине без Developer ID выдавала
# «Signed: Developer ID (Apple Development: …)». Это не описка: по этой строке
# владелец 21.09.2026 решил, что сертификат для раздачи уже есть, а его нет.
# Отчёт, который называет вещь не своим именем, стоит дороже отсутствующего.
#
# Разница не в названии, а в том, что умеет каждый:
#   Apple Development  — запуск на своих машинах;
#   Apple Distribution — заливка в App Store / TestFlight;
#   Developer ID Application — ЕДИНСТВЕННЫЙ, с которым скачанное приложение
#   откроется у постороннего (и только вместе с заверением).
case "${IDENTITY:-}" in
  "")                            SIGN_LABEL="ad-hoc (local only — Gatekeeper will refuse a downloaded copy)" ;;
  "Developer ID Application"*)   SIGN_LABEL="Developer ID Application ($IDENTITY) — distributable once notarized" ;;
  "Apple Distribution"*)         SIGN_LABEL="Apple Distribution ($IDENTITY) — App Store / TestFlight ONLY, not for download" ;;
  "Apple Development"*)          SIGN_LABEL="Apple Development ($IDENTITY) — THIS MACHINE ONLY, not distributable" ;;
  *)                             SIGN_LABEL="$IDENTITY" ;;
esac
echo " Signed:     $SIGN_LABEL"
echo " Notarized:  $([ -n "$NOTARY_PROFILE" ] && echo "yes" || echo "no")"
case "${IDENTITY:-}" in
  "Developer ID Application"*) ;;
  *)
    echo
    echo " 🔴 NOT DISTRIBUTABLE. Gatekeeper opens a DOWNLOADED copy only when it is"
    echo "    signed with a Developer ID Application certificate AND notarized."
    echo "    Create one in Xcode: Settings > Accounts > Manage Certificates."
    ;;
esac
echo
if [ -n "${SECRETLY_UPDATE_BASE_URL:-}" ]; then
  echo " Appcast:    $APP_DIR/updates/appcast.xml"
fi
echo
echo " Smoke-test before distributing:"
echo "   1. open \"$APP\"  — must reach the UI (not crash on splash)"
echo "   2. pair with the phone by QR, send + receive a message"
echo "   3. confirm the encrypted DB opened (chat history persists across restart)"
echo "=============================================================="
