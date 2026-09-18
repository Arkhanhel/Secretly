// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

/// 🔴 `networkUnavailable` добавлен 08.08.2026 по полевой жалобе: «при плохом
/// интернете восстановление выдаёт ошибку, при нормальной сети восстанавливает
/// нормально».
///
/// Категорий было ДВЕ, и `invalidPayload` работал сборником всего непонятого.
/// То есть на секундный обрыв связи человеку сообщали, что его резервная копия
/// НЕДЕЙСТВИТЕЛЬНА — про единственный носитель его переписки. Хуже ошибки тут
/// только паника от неё: человек, поверивший, что копия испорчена, удалит её и
/// сделает новую с пустого места.
///
/// Это тот же класс, что уже записан как «куда врёт `catch` по умолчанию»:
/// обработчик по умолчанию обязан отвечать «не знаю», а не выбирать самый
/// пугающий из возможных ответов.
enum EncryptedRestoreFailureKind {
  wrongPassword,
  invalidPayload,
  networkUnavailable,
}

class EncryptedRestoreException implements Exception {
  const EncryptedRestoreException(this.kind, {this.cause});

  final EncryptedRestoreFailureKind kind;
  final Object? cause;

  @override
  String toString() => cause?.toString() ?? kind.name;
}

EncryptedRestoreException describeEncryptedRestoreError(Object error) {
  if (error is EncryptedRestoreException) {
    return error;
  }
  return EncryptedRestoreException(
    classifyEncryptedRestoreError(error),
    cause: error,
  );
}

EncryptedRestoreFailureKind classifyEncryptedRestoreError(Object error) {
  if (error is EncryptedRestoreException) {
    return error.kind;
  }
  if (error is SecretBoxAuthenticationError) {
    return EncryptedRestoreFailureKind.wrongPassword;
  }

  final message = error.toString().toLowerCase();
  if (message.contains('secretboxauthenticationerror') ||
      message.contains('authentication') ||
      message.contains('bad tag') ||
      message.contains('mac check failed')) {
    return EncryptedRestoreFailureKind.wrongPassword;
  }

  // 🔴 Сеть — ДО общего вывода. Восстановление трогает сервер (разрешение на
  // ротацию личности, регистрация устройства), и обрыв там ничего не говорит о
  // самой копии.
  if (_looksLikeNetworkFailure(error, message)) {
    return EncryptedRestoreFailureKind.networkUnavailable;
  }

  return EncryptedRestoreFailureKind.invalidPayload;
}

bool _looksLikeNetworkFailure(Object error, String message) {
  if (error is SocketException ||
      error is TimeoutException ||
      error is HandshakeException ||
      error is HttpException) {
    return true;
  }
  // По тексту — потому что клиент HTTP оборачивает свои сбои в собственный тип,
  // и по классу их не поймать (тот же приём, что в классификаторе звонков).
  return message.contains('socketexception') ||
      message.contains('clientexception') ||
      message.contains('timeoutexception') ||
      message.contains('failed host lookup') ||
      message.contains('no route to host') ||
      message.contains('network is unreachable') ||
      message.contains('connection closed') ||
      message.contains('connection refused') ||
      message.contains('connection reset') ||
      message.contains('handshakeexception') ||
      message.contains('software caused connection abort');
}