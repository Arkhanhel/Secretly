#!/usr/bin/env bash
# Прежний выпускной скрипт macOS. БОЛЬШЕ НЕ СОБИРАЕТ (30.09.2026).
#
# 🔴 ПОЧЕМУ. Выпусков macOS собиралось двумя скриптами, и правки шли только в
# один — `tools/macos_build_desktop_release.sh` в корне репозитория. Этот
# остановился 23.09.2026, и мимо него прошли исправления, без которых выпуск
# отдавать нельзя: подпись помощников Sparkle, минимальная macOS 13, сборка в
# пустой бандл без файлов прошлых сборок. Собранная им версия ушла бы с
# дырами, уже закрытыми в другом месте, и после выкладки нельзя было бы
# сказать, каким из двух путей она собрана.
#
# Файл НЕ удалён: старые заметки и привычная команда должны не собрать
# устаревшую версию молча, а сказать, куда идти, и вернуть ошибку.
#
# Перечень версий (appcast.xml) этот скрипт строил сам; теперь его строят при
# публикации — `generate_appcast` из `macos/Pods/Sparkle/bin` по папке с
# образами (ключ EdDSA он берёт из связки ключей).

cat >&2 <<'EOF'
error: tools/desktop_release_macos.sh no longer builds releases.

The macOS release is built by ONE script, from the repository root:

  tools/macos_build_desktop_release.sh --marker <marker> \
      --build-name <x.y.z> --build-number <n> --room-sender-key --notarize

(see --help there). The update feed is produced at publishing time with
macos/Pods/Sparkle/bin/generate_appcast.
EOF
exit 1
