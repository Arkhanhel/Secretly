// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n.dart';
import 'welcome_style.dart';

const _kTermsUrl = 'https://www.secretlyapp.com/terms-of-service';
const _kPrivacyUrl = 'https://www.secretlyapp.com/privacy-policy';

/// Приветствие (макет «Secretly Kit», 17.11.2026): крупное «Secretly» под
/// знаком из частиц, обещание одной строкой, главная кнопка и мелкая строка
/// об условиях со ссылками. Одно и то же на телефоне и на компьютере — на
/// компьютере крупнее надпись и больше отступ снизу.
class WelcomeHero extends StatefulWidget {
  const WelcomeHero({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.large = false,
  });

  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Вид для компьютера: надпись 64, отступ снизу 64.
  final bool large;

  @override
  State<WelcomeHero> createState() => _WelcomeHeroState();
}

class _WelcomeHeroState extends State<WelcomeHero> {
  late final TapGestureRecognizer _terms;
  late final TapGestureRecognizer _privacy;

  @override
  void initState() {
    super.initState();
    _terms = TapGestureRecognizer()..onTap = () => _open(_kTermsUrl);
    _privacy = TapGestureRecognizer()..onTap = () => _open(_kPrivacyUrl);
  }

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  List<InlineSpan> _termsSpans(BuildContext context, WelcomeStyle s) {
    final l10n = context.l10n;
    const termsMark = '\u0001';
    const privacyMark = '\u0002';
    final notice = l10n.welcomeTermsNotice(termsMark, privacyMark);
    final linkStyle = TextStyle(
      color: s.textSecondary,
      decoration: TextDecoration.underline,
      decorationColor: s.textSecondary,
    );
    final spans = <InlineSpan>[];
    final buffer = StringBuffer();
    void flush() {
      if (buffer.isEmpty) return;
      spans.add(TextSpan(text: buffer.toString()));
      buffer.clear();
    }

    for (final ch in notice.characters) {
      if (ch == termsMark) {
        flush();
        spans.add(
          TextSpan(
            text: l10n.welcomeTermsLink,
            style: linkStyle,
            recognizer: _terms,
            mouseCursor: SystemMouseCursors.click,
          ),
        );
      } else if (ch == privacyMark) {
        flush();
        spans.add(
          TextSpan(
            text: l10n.welcomePrivacyLink,
            style: linkStyle,
            recognizer: _privacy,
            mouseCursor: SystemMouseCursors.click,
          ),
        );
      } else {
        buffer.write(ch);
      }
    }
    flush();
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final s = WelcomeStyle.of(context);
    final l10n = context.l10n;
    final secondary = widget.secondaryLabel;
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(28, 24, 28, widget.large ? 64 : 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Название — одной строкой при любом размере текста: с
                // крупным текстом из настроек iPhone оно ломалось на
                // «Secretl» и «y». Растёт вместе с текстом, но не шире экрана.
                Semantics(
                  header: true,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Secretly',
                      maxLines: 1,
                      softWrap: false,
                      style: s.display.copyWith(
                        fontSize: widget.large ? 64 : 46,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  l10n.welcomeTagline,
                  textAlign: TextAlign.center,
                  style: s.body.copyWith(
                    fontSize: 17,
                    height: 1.45,
                    color: s.text.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 36),
                WelcomePrimaryButton(
                  label: widget.primaryLabel,
                  onPressed: widget.onPrimary,
                ),
                if (secondary != null) ...[
                  const SizedBox(height: 6),
                  WelcomeTextButton(
                    label: secondary,
                    onPressed: widget.onSecondary,
                    height: 50,
                  ),
                ],
                const SizedBox(height: 10),
                Text.rich(
                  TextSpan(children: _termsSpans(context, s)),
                  textAlign: TextAlign.center,
                  style: s.caption.copyWith(
                    fontSize: 12,
                    color: s.textTertiary.withValues(alpha: s.dark ? 0.75 : 1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
