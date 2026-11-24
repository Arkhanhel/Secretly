// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.

/// Обложка «Отпечаток ключа» (макет владельца, 21.11.2026): узор строится
/// из ключа шифрования человека — у каждого свой. При встрече двое
/// сравнивают узор на профиле собеседника с узором на его собственном
/// профиле: совпал — переписка защищена.
///
/// 🔴 ИСТОЧНИК КЛЮЧА — КЛЮЧ ЛИЧНОСТИ АККАУНТА (AIK), а не ключ устройства.
/// AIK один на человека и одинаков на всех его устройствах, поэтому узор
/// на своём профиле совпадает с тем, что видят на нём собеседники, с
/// какого бы устройства ни смотреть. Ключ устройства для этого не годится:
/// у человека с телефоном и ПК было бы два разных узора, и сравнение при
/// встрече давало бы ложную тревогу.
/// * свой профиль — `AppController.ownAccountIdentityPubB64` (сид только
///   читается, никогда не создаётся из экрана);
/// * контакт — `AppController.contactAccountIdentityPubB64`: ключ,
///   закреплённый при первом знакомстве (TOFU) и никогда не
///   перезаписываемый. Если сервер когда-то подставил чужой ключ, узор у
///   нас разойдётся с узором на телефоне собеседника — ради этого
///   сравнения обложка и существует.
///
/// Нет AIK (сборка контакта старше слоя 2, сид ещё не создан) — помощники
/// возвращают `null`, и узор рисуется из превью-ключа. 🔴 Тогда экран НЕ
/// ДОЛЖЕН показывать подсказку «узор построен из вашего ключа».
///
/// В узор идёт SHA-256 открытого ключа (32 байта), раскладка —
/// [KeyFingerprintLayout] в pattern_cover.dart.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_controller.dart';
import '../chat_screen_l10n.dart';
import '../secretly_snackbar.dart';
import 'pattern_cover.dart';

/// Идентификатор обложки «Отпечаток ключа».
final String kKeyFingerprintCoverId = patternCoverId(
  PatternCoverStyle.fingerprint,
);

/// Выбрана ли у профиля обложка «Отпечаток ключа».
bool isKeyFingerprintCover(String? coverId) =>
    patternCoverStyleFromId(coverId) == PatternCoverStyle.fingerprint;

/// Байты ключа для узора: экран профиля кладёт сюда SHA-256 ключа личности
/// человека, чей это профиль. Без области (плитки выбора, превью) — узор из
/// превью-ключа.
class PatternCoverKey extends InheritedWidget {
  const PatternCoverKey({
    super.key,
    required this.keyBytes,
    required super.child,
  });

  /// SHA-256 открытого ключа личности; `null` — ключ ещё не известен.
  final List<int>? keyBytes;

  /// Байты из ближайшей области; `null` — области нет или ключ не известен.
  static List<int>? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PatternCoverKey>()?.keyBytes;

  /// Байты для рисования: без ключа — превью-ключ.
  static List<int> of(BuildContext context) =>
      maybeOf(context) ?? KeyFingerprintLayout.previewSeed;

  @override
  bool updateShouldNotify(PatternCoverKey old) =>
      !_sameBytes(old.keyBytes, keyBytes);
}

bool _sameBytes(List<int>? a, List<int>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null || a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// SHA-256 открытого ключа в base64; `null` — ключа нет или он испорчен.
List<int>? fingerprintKeyFromPublicKeyB64(String? publicKeyB64) {
  final v = publicKeyB64?.trim() ?? '';
  if (v.isEmpty) return null;
  try {
    final raw = base64Decode(v);
    if (raw.isEmpty) return null;
    return crypto.sha256.convert(raw).bytes;
  } on FormatException {
    return null;
  }
}

/// Байты узора для СВОЕГО профиля (SHA-256 своего AIK) или `null`.
Future<List<int>?> ownFingerprintKey(AppController c) async =>
    fingerprintKeyFromPublicKeyB64(await c.ownAccountIdentityPubB64());

/// Байты узора для профиля контакта [profileId] (SHA-256 закреплённого AIK)
/// или `null`, если контакт свой ключ аккаунта не присылал.
Future<List<int>?> contactFingerprintKey(
  AppController c,
  String profileId,
) async => fingerprintKeyFromPublicKeyB64(
  await c.contactAccountIdentityPubB64(profileId),
);

/// Подсказка по касанию обложки «Отпечаток ключа».
String keyFingerprintHintText(BuildContext context) => chatText(
  context,
  ru:
      'Этот узор построен из вашего ключа шифрования — у каждого он свой. '
      'При встрече сравните его с узором у собеседника: если совпадает, '
      'переписка защищена.',
  en:
      'This pattern is built from your encryption key — everyone has their '
      'own. When you meet, compare it with the pattern on the other '
      "person's phone: if they match, your chat is protected.",
  uk:
      'Цей візерунок побудовано з вашого ключа шифрування — у кожного він '
      'свій. Під час зустрічі порівняйте його з візерунком у співрозмовника: '
      'якщо збігається, листування захищене.',
  es:
      'Este patrón se crea a partir de tu clave de cifrado: cada persona '
      'tiene el suyo. Cuando os veáis, compáralo con el patrón de la otra '
      'persona: si coincide, la conversación está protegida.',
  pt:
      'Este padrão é criado a partir da sua chave de encriptação — cada '
      'pessoa tem o seu. Quando se encontrarem, compare-o com o padrão da '
      'outra pessoa: se coincidir, a conversa está protegida.',
  ptBr:
      'Este padrão é criado a partir da sua chave de criptografia — cada '
      'pessoa tem o seu. Quando se encontrarem, compare-o com o padrão da '
      'outra pessoa: se for igual, a conversa está protegida.',
  fr:
      'Ce motif est créé à partir de votre clé de chiffrement — chacun a le '
      'sien. Quand vous vous voyez, comparez-le avec celui de votre '
      'interlocuteur : s’ils sont identiques, la conversation est protégée.',
  de:
      'Dieses Muster entsteht aus deinem Verschlüsselungsschlüssel – jeder '
      'hat sein eigenes. Vergleicht es bei einem Treffen mit dem Muster '
      'deines Gegenübers: Stimmt es überein, ist der Chat geschützt.',
);

/// Показать подсказку «узор из вашего ключа» (лёгкий отклик выбора).
void showKeyFingerprintHint(BuildContext context) {
  HapticFeedback.selectionClick();
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SecretlySnackBar(
        // SecretlySnackBar делит срок пополам: на деле ~4,5 с — текст длинный.
        duration: const Duration(seconds: 9),
        content: Text(keyFingerprintHintText(context)),
      ),
    );
}

/// Касание по [child] показывает подсказку «узор из вашего ключа».
/// [enabled] = false — касание проходит насквозь (не та обложка, ключ не
/// известен).
class KeyFingerprintTapHint extends StatelessWidget {
  const KeyFingerprintTapHint({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showKeyFingerprintHint(context),
      child: child,
    );
  }
}
