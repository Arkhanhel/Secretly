// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app_controller.dart';
import '../../billing/show_paywall.dart';
import '../../entitlements/cosmetic_catalog.dart';
import '../paywall_screen.dart' show PaywallTrigger;
import '../wave1_l10n.dart';
import '../widgets/secretly_glass_sheet.dart';

/// One selectable launcher-icon style. [key] is the cross-platform identifier:
///  • iOS  → resolves to the `AltIcon{Key}` asset-catalog set
///           (e.g. 'midnight' → "AltIconMidnight").
///  • Android → resolves to the `MainActivity{Key}` activity-alias.
/// The special key 'default' reverts to the primary (stock) app icon.
class AppIconOption {
  const AppIconOption(this.key, this.asset);
  final String key;
  final String asset;
}

const List<AppIconOption> kAppIconOptions = <AppIconOption>[
  AppIconOption('default', 'assets/app_icons/default.png'),
  AppIconOption('midnight', 'assets/app_icons/midnight.png'),
  AppIconOption('ocean', 'assets/app_icons/ocean.png'),
  AppIconOption('sunset', 'assets/app_icons/sunset.png'),
  AppIconOption('emerald', 'assets/app_icons/emerald.png'),
  AppIconOption('graphite', 'assets/app_icons/graphite.png'),
];

/// Thin wrapper over the `secretly/app_icon` MethodChannel (AppDelegate.swift /
/// MainActivity.kt). Every call fails soft — a launcher icon is a cosmetic and
/// is never security-critical, so any platform error degrades to "no change".
class AppIconService {
  AppIconService._();

  static const MethodChannel _channel = MethodChannel('secretly/app_icon');

  /// Mirrors the chosen icon key into prefs so it can be re-applied after a
  /// safe-backup restore. Must match the key used by the backup collector.
  static const String prefsIconKey = 'secretly_app_icon_key_v1';

  static bool get isSupportedPlatform => Platform.isIOS || Platform.isAndroid;

  static String _capitalise(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  static Future<bool> supportsAlternateIcons() async {
    if (!isSupportedPlatform) return false;
    try {
      return (await _channel.invokeMethod<bool>('supportsAlternateIcons')) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<String> currentIconKey() async {
    if (!isSupportedPlatform) return 'default';
    try {
      final value =
          await _channel.invokeMethod<dynamic>('getAlternateIconName')
              as String?;
      if (value == null || value.isEmpty) {
        // The OS reports the stock icon. After a restore the alternate icon
        // may not have re-applied yet, so prefer a saved key when present.
        return await _savedIconKeyOrDefault();
      }
      String key;
      if (Platform.isIOS) {
        // 'AltIconMidnight' -> 'midnight'
        final stripped = value.startsWith('AltIcon')
            ? value.substring(7)
            : value;
        key = stripped.isEmpty
            ? 'default'
            : '${stripped[0].toLowerCase()}${stripped.substring(1)}';
      } else {
        key = value; // Android returns the key directly.
      }
      return kAppIconOptions.any((o) => o.key == key) ? key : 'default';
    } catch (_) {
      return await _savedIconKeyOrDefault();
    }
  }

  /// Reads the last-applied icon key from prefs (set by [setIcon]); falls back
  /// to 'default' when unset or unknown. Used when the OS can't report the
  /// current alternate icon (e.g. right after a safe-backup restore).
  static Future<String> _savedIconKeyOrDefault() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = (prefs.getString(prefsIconKey) ?? '').trim();
      if (saved.isEmpty) return 'default';
      return kAppIconOptions.any((o) => o.key == saved) ? saved : 'default';
    } catch (_) {
      return 'default';
    }
  }

  static Future<bool> setIcon(String key) async {
    if (!isSupportedPlatform) return false;
    final String? name;
    if (key == 'default') {
      name = null; // revert to the primary icon
    } else if (Platform.isIOS) {
      name = 'AltIcon${_capitalise(key)}';
    } else {
      name = key;
    }
    try {
      final ok =
          (await _channel.invokeMethod<bool>('setAlternateIcon', {
            'name': name,
          })) ??
          false;
      if (ok) {
        // Persist so the choice survives a safe-backup restore. Best-effort:
        // a launcher icon is cosmetic and never security-critical.
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(prefsIconKey, key);
        } catch (_) {
          // ignore persistence failures
        }
      }
      return ok;
    } catch (_) {
      return false;
    }
  }
}

/// Premium-gated launcher-icon picker. Picking any non-default icon requires
/// unlocked cosmetics; reverting to 'default' is always allowed (fail-open
/// safety so a lapsed subscriber can never be stuck on a premium icon).
Future<void> showAppIconPicker(
  BuildContext context,
  AppController controller,
) async {
  if (!AppIconService.isSupportedPlatform) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AppIconPickerSheet(controller: controller),
  );
}

/// Inline horizontal carousel of icon styles, sized to sit beside the Themes /
/// Bubble-colors carousels in Settings. Self-contained state (reads the current
/// icon from the OS, applies on tap with premium gating) so it stays correct
/// regardless of which route hosts it.
class AppIconCarousel extends StatefulWidget {
  const AppIconCarousel({super.key, required this.controller});
  final AppController controller;

  @override
  State<AppIconCarousel> createState() => _AppIconCarouselState();
}

class _AppIconCarouselState extends State<AppIconCarousel> {
  String _current = 'default';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    AppIconService.currentIconKey().then((key) {
      if (mounted) setState(() => _current = key);
    });
  }

  bool get _unlocked => isCosmeticAllowed(
    widget.controller.entitlementStateNow,
    CosmeticKind.avatarFrame,
    'x',
  );

  Future<void> _select(AppIconOption option) async {
    if (_busy || option.key == _current) return;
    if (option.key != 'default' && !_unlocked) {
      await showPaywall(context, PaywallTrigger.cosmetic);
      if (!mounted || !_unlocked) return;
    }
    setState(() => _busy = true);
    final ok = await AppIconService.setIcon(option.key);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) _current = option.key;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 116,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: kAppIconOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final option = kAppIconOptions[i];
          return SizedBox(
            width: 78,
            child: _AppIconTile(
              option: option,
              selected: option.key == _current,
              locked: option.key != 'default' && !_unlocked,
              label: _labelFor(context, option.key),
              onTap: _busy ? null : () => _select(option),
            ),
          );
        },
      ),
    );
  }
}

class _AppIconPickerSheet extends StatefulWidget {
  const _AppIconPickerSheet({required this.controller});
  final AppController controller;

  @override
  State<_AppIconPickerSheet> createState() => _AppIconPickerSheetState();
}

class _AppIconPickerSheetState extends State<_AppIconPickerSheet> {
  String _current = 'default';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    AppIconService.currentIconKey().then((key) {
      if (mounted) setState(() => _current = key);
    });
  }

  bool get _cosmeticsUnlocked => isCosmeticAllowed(
    widget.controller.entitlementStateNow,
    CosmeticKind.avatarFrame,
    'x',
  );

  Future<void> _select(AppIconOption option) async {
    if (_busy || option.key == _current) return;
    // Reverting to the stock icon is always free; premium styles gate.
    if (option.key != 'default' && !_cosmeticsUnlocked) {
      await showPaywall(context, PaywallTrigger.cosmetic);
      if (!mounted || !_cosmeticsUnlocked) return;
    }
    setState(() => _busy = true);
    final ok = await AppIconService.setIcon(option.key);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) _current = option.key;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: SecretlyGlassSheetSurface(
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: SecretlyGlassSheetHandle()),
                const SizedBox(height: 12),
                Text(
                  wave1Text(
                    context,
                    ru: 'Иконка приложения',
                    en: 'App icon',
                    uk: 'Іконка додатка',
                    es: 'Icono de la app',
                    pt: 'Ícone do app',
                    ptBr: 'Ícone do app',
                    fr: "Icône de l'app",
                    de: 'App-Symbol',
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  wave1Text(
                    context,
                    ru: 'Premium · обновите вид на домашнем экране',
                    en: 'Premium · refresh your home-screen look',
                    uk: 'Premium · оновіть вигляд на домашньому екрані',
                    es: 'Premium · renueva tu pantalla de inicio',
                    pt: 'Premium · renove o seu ecrã inicial',
                    ptBr: 'Premium · renove sua tela inicial',
                    fr: "Premium · changez l'allure de votre écran d'accueil",
                    de: 'Premium · frische deinen Startbildschirm auf',
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.82,
                  children: [
                    for (final option in kAppIconOptions)
                      _AppIconTile(
                        option: option,
                        selected: option.key == _current,
                        locked: option.key != 'default' && !_cosmeticsUnlocked,
                        label: _labelFor(context, option.key),
                        onTap: _busy ? null : () => _select(option),
                      ),
                  ],
                ),
                if (Platform.isAndroid) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 15,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          wave1Text(
                            context,
                            ru: 'Иконка обновится после обновления домашнего экрана',
                            en: 'The icon updates after the launcher refreshes',
                            uk: 'Іконка зміниться після оновлення екрана',
                            es: 'El icono se actualiza al refrescar el lanzador',
                            pt: 'O ícone muda após atualizar o ecrã inicial',
                            ptBr: 'O ícone muda após atualizar a tela inicial',
                            fr: "L'icône change après l'actualisation du lanceur",
                            de: 'Das Symbol ändert sich nach dem Aktualisieren des Launchers',
                          ),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _labelFor(BuildContext context, String key) {
  switch (key) {
    case 'default':
      return wave1Text(
        context,
        ru: 'Стандарт',
        en: 'Default',
        uk: 'Стандарт',
        es: 'Predeterminado',
        pt: 'Padrão',
        ptBr: 'Padrão',
        fr: 'Par défaut',
        de: 'Standard',
      );
    case 'midnight':
      return wave1Text(
        context,
        ru: 'Полночь',
        en: 'Midnight',
        uk: 'Опівніч',
        es: 'Medianoche',
        pt: 'Meia-noite',
        ptBr: 'Meia-noite',
        fr: 'Minuit',
        de: 'Mitternacht',
      );
    case 'ocean':
      return wave1Text(
        context,
        ru: 'Океан',
        en: 'Ocean',
        uk: 'Океан',
        es: 'Océano',
        pt: 'Oceano',
        ptBr: 'Oceano',
        fr: 'Océan',
        de: 'Ozean',
      );
    case 'sunset':
      return wave1Text(
        context,
        ru: 'Закат',
        en: 'Sunset',
        uk: 'Захід',
        es: 'Atardecer',
        pt: 'Pôr do sol',
        ptBr: 'Pôr do sol',
        fr: 'Coucher de soleil',
        de: 'Sonnenuntergang',
      );
    case 'emerald':
      return wave1Text(
        context,
        ru: 'Изумруд',
        en: 'Emerald',
        uk: 'Смарагд',
        es: 'Esmeralda',
        pt: 'Esmeralda',
        ptBr: 'Esmeralda',
        fr: 'Émeraude',
        de: 'Smaragd',
      );
    case 'graphite':
      return wave1Text(
        context,
        ru: 'Графит',
        en: 'Graphite',
        uk: 'Графіт',
        es: 'Grafito',
        pt: 'Grafite',
        ptBr: 'Grafite',
        fr: 'Graphite',
        de: 'Graphit',
      );
    default:
      return key;
  }
}

class _AppIconTile extends StatelessWidget {
  const _AppIconTile({
    required this.option,
    required this.selected,
    required this.locked,
    required this.label,
    required this.onTap,
  });

  final AppIconOption option;
  final bool selected;
  final bool locked;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const gold = Color(0xFFE8A33D);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: selected
                            ? gold
                            : Colors.white.withValues(alpha: 0.08),
                        width: selected ? 2 : 1,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: gold.withValues(alpha: 0.25),
                                blurRadius: 14,
                              ),
                            ]
                          : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(17),
                      child: Image.asset(option.asset, fit: BoxFit.cover),
                    ),
                  ),
                ),
                if (selected)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: gold,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: Colors.black,
                      ),
                    ),
                  )
                else if (locked)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        size: 13,
                        color: gold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: selected ? gold : cs.onSurface,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
