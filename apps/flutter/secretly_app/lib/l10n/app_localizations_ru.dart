// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Secretly';

  @override
  String get starting => 'Запуск…';

  @override
  String get encrypting => 'Шифрование…';

  @override
  String errorPrefix(Object error) {
    return 'Ошибка: $error';
  }

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get notificationsSection => 'Уведомления';

  @override
  String get languageSection => 'Язык';

  @override
  String get comingSoon => 'Скоро будет';

  @override
  String get idsTitle => 'Идентификаторы';

  @override
  String get profileIdLabel => 'ID профиля';

  @override
  String get deviceIdLabel => 'ID устройства';

  @override
  String get profileIdShort => 'Профиль';

  @override
  String get deviceIdShort => 'Устройство';

  @override
  String get copy => 'Копировать';

  @override
  String get copied => 'Скопировано';

  @override
  String get copyBoth => 'Копировать оба';

  @override
  String get openMyId => 'Открыть мой ID';

  @override
  String get close => 'Закрыть';

  @override
  String get tabChats => 'Чаты';

  @override
  String get tabGroups => 'Комнаты';

  @override
  String get tabContacts => 'Контакты';

  @override
  String get tabProfile => 'Профиль';

  @override
  String get accountSection => 'Аккаунт';

  @override
  String get chatsSection => 'Чаты';

  @override
  String get privacySection => 'Приватность';

  @override
  String get devicesSection => 'Устройства';

  @override
  String get systemSection => 'Система';

  @override
  String get languageSystemDefault => 'Системный язык';

  @override
  String languageSystemCurrent(Object language) {
    return 'Системный ($language)';
  }

  @override
  String get languageChooseAppLanguage => 'Выберите язык приложения';

  @override
  String get languageAvailableWave1 => 'Доступно: английский, русский, украинский, испанский, португальский (Бразилия), французский и немецкий. Можно также следовать системному языку.';

  @override
  String get languageMessageTranslation => 'Перевод сообщений';

  @override
  String get languageShowTranslateButton => 'Показывать кнопку «Перевести»';

  @override
  String get languageTranslateWholeChats => 'Переводить чаты целиком';

  @override
  String get favoritesTitle => 'Избранное';

  @override
  String get favoritesSubtitle => 'Ваши личные заметки';

  @override
  String get favoritesEmptyTitle => 'В избранном пока пусто';

  @override
  String get favoritesEmptySubtitle => 'Отправляйте сюда сообщения, файлы и заметки, чтобы хранить их приватно на своих устройствах.';

  @override
  String get favoritesPersonalNotebookLabel => 'Личные заметки';

  @override
  String get more => 'Ещё';

  @override
  String get stickersRecent => 'Недавние стикеры';

  @override
  String get searchStickers => 'Поиск стикеров';

  @override
  String get noStickersFound => 'Стикеры не найдены';

  @override
  String get noRecentStickers => 'Здесь появятся ваши последние стикеры';

  @override
  String get cancelSelection => 'Отменить выбор';

  @override
  String get chatsTitle => 'Чаты';

  @override
  String get newChat => 'Новый чат';

  @override
  String get openContactsToStartChat => 'Откройте «Контакты», чтобы начать чат';

  @override
  String get noChatsYet => 'Чатов пока нет';

  @override
  String get openDemoChat => 'Открыть демо-чат';

  @override
  String get archive => 'Архив';

  @override
  String get unarchive => 'Из архива';

  @override
  String get pin => 'Закрепить';

  @override
  String get unpin => 'Открепить';

  @override
  String get clearHistory => 'Очистить историю';

  @override
  String archiveHeader(Object count) {
    return 'Архив ($count)';
  }

  @override
  String deleteChatsConfirmTitle(Object count) {
    return 'Удалить $count чат(ов)?';
  }

  @override
  String get deleteChatsConfirmBody => 'Чаты будут удалены только с этого устройства.';

  @override
  String clearHistoryConfirmTitle(Object count) {
    return 'Очистить историю для $count чат(ов)?';
  }

  @override
  String get clearHistoryConfirmBody => 'Сообщения будут удалены только с этого устройства.';

  @override
  String get contactsTitle => 'Контакты';

  @override
  String get contactsTab => 'Контакты';

  @override
  String get requestsTab => 'Запросы';

  @override
  String get addContact => 'Добавить контакт';

  @override
  String get deleteContact => 'Удалить контакт';

  @override
  String get noContactsYet => 'Контактов пока нет';

  @override
  String get noRequests => 'Запросов нет';

  @override
  String get secretlyIdLabel => 'ID в Secretly';

  @override
  String get secretlyIdHint => 'XXXX-XXXX-...-CHECK';

  @override
  String get nameOptionalLabel => 'Имя (необязательно)';

  @override
  String get scanContactQrTitle => 'Сканировать QR контакта';

  @override
  String get qrMissingSecretlyId => 'В QR нет ID в Secretly';

  @override
  String get differentServerTitle => 'Другой сервер';

  @override
  String differentServerBody(Object qrServer, Object appServer) {
    return 'Этот QR относится к другому серверу.\n\nСервер в QR: $qrServer\nЭто приложение: $appServer\n\nУстановите одинаковый APK/сервер на оба телефона.';
  }

  @override
  String get contactActionProfileNotFound => 'Такого ID в Secretly нет на этом сервере.';

  @override
  String get contactActionTransportBlocked => 'Это действие недоступно, потому что приложение привязано к другому серверу.';

  @override
  String get contactActionServiceUnavailable => 'Сервер сейчас недоступен. Попробуйте ещё раз чуть позже.';

  @override
  String get contactActionCallsDisabled => 'Звонки отключены в настройках приватности.';

  @override
  String get contactActionCallsDisabledForContact => 'Звонки отключены для этого контакта.';

  @override
  String get callServiceUnavailable => 'Сервис звонков сейчас недоступен.';

  @override
  String get callAlreadyInProgress => 'Сейчас уже идёт другой звонок.';

  @override
  String get callIceUnavailable => 'Защищённое соединение для звонка сейчас недоступно. Попробуйте ещё раз чуть позже.';

  @override
  String get callPermissionDenied => 'Нет доступа к микрофону или камере. Разрешите доступ и попробуйте ещё раз.';

  @override
  String get callNegotiationFailed => 'Не удалось установить защищённый звонок. Попробуйте ещё раз.';

  @override
  String get callConnectionInterrupted => 'Соединение звонка было прервано. Попробуйте ещё раз.';

  @override
  String get callActionGeneric => 'Не удалось начать звонок. Попробуйте ещё раз.';

  @override
  String get callEncryptedBadge => 'Сквозное шифрование';

  @override
  String get incomingVideoCall => 'Входящий видеозвонок';

  @override
  String get incomingVoiceCall => 'Входящий аудиозвонок';

  @override
  String get callDecline => 'Отклонить';

  @override
  String get callConnectionUnstable => 'Связь нестабильна';

  @override
  String get callNetworkVeryWeak => 'Очень слабый сигнал сети';

  @override
  String get callNetworkWeak => 'Слабый сигнал сети';

  @override
  String get callEnded => 'Звонок завершён';

  @override
  String get callReplacedByNewerAttempt => 'Вызов заменён более новой попыткой';

  @override
  String get callDeclined => 'Вызов отклонён';

  @override
  String get callYouDeclined => 'Вы отклонили';

  @override
  String get callNoAnswer => 'Нет ответа';

  @override
  String get callConnectionError => 'Ошибка соединения';

  @override
  String get callVideoUnavailable => 'Видео недоступно';

  @override
  String get callWaitingForRemoteVideo => 'Ожидание видео собеседника...';

  @override
  String get callAttachingRemoteVideo => 'Подключаем видео...';

  @override
  String get callStartingRemoteVideo => 'Запускаем видео...';

  @override
  String get callRemoteVideoNotArriving => 'Видео собеседника не поступает';

  @override
  String get callRemoteVideoBindFailed => 'Не удалось привязать видеопоток';

  @override
  String get callRemoteVideoNoFrames => 'Видео подключено, но кадры не идут';

  @override
  String get callMinimize => 'Свернуть';

  @override
  String get callStatusCalling => 'Вызов...';

  @override
  String get callStatusIncoming => 'Входящий...';

  @override
  String get callStatusConnecting => 'Подключение...';

  @override
  String get callStatusReconnecting => 'Переподключение...';

  @override
  String get callStatusEnded => 'Завершён';

  @override
  String get callVideoCall => 'Видеозвонок';

  @override
  String get callControlMute => 'Микрофон';

  @override
  String get callControlSpeaker => 'Динамик';

  @override
  String get callControlCamera => 'Камера';

  @override
  String get callControlFlip => 'Развернуть';

  @override
  String get callControlStop => 'Стоп';

  @override
  String get callControlShare => 'Экран';

  @override
  String get callControlEnd => 'Завершить';

  @override
  String get contactActionGeneric => 'Не удалось выполнить действие. Попробуйте ещё раз.';

  @override
  String get notificationTitleRoom => 'Комната';

  @override
  String get notificationTitleRequest => 'Запрос';

  @override
  String get notificationTitleChat => 'Чат';

  @override
  String get notificationBodyNewMessage => 'Новое сообщение';

  @override
  String get contactLookupUnavailable => 'Поиск сейчас недоступен. Попробуйте ещё раз чуть позже.';

  @override
  String addContactFailed(Object error) {
    return 'Не удалось добавить контакт: $error';
  }

  @override
  String deleteContactsConfirmTitle(Object count) {
    return 'Удалить $count контакт(ов)?';
  }

  @override
  String get deleteContactsConfirmBody => 'Чаты не удаляются.';

  @override
  String get privacyTitle => 'Приватность';

  @override
  String get blockedUsersSubtitle => 'Заблокированные не смогут доставлять вам сообщения (на уровне сервера).';

  @override
  String get noBlockedUsers => 'Список пуст';

  @override
  String unblockFailed(Object error) {
    return 'Не удалось разблокировать: $error';
  }

  @override
  String get diagIdentity => 'Идентичность';

  @override
  String get diagEndpoints => 'Эндпоинты';

  @override
  String get diagServerBinding => 'Привязка к серверу';

  @override
  String get diagMismatch => 'Несовпадение: профиль относится к другому серверу. Используйте Настройки → Сбросить профиль.';

  @override
  String get diagStatus => 'Статус';

  @override
  String get diagTimestamps => 'Временные метки';

  @override
  String get diagTips => 'Подсказки';

  @override
  String get diagTipsBody => 'Если отправка не работает и пишет \"profile not found\":\n1) Проверьте, что на обоих телефонах один и тот же APK/сервер\n2) Пере-добавьте контакт, отсканировав QR\n3) Если менялись адреса, используйте Сброс профиля\n';

  @override
  String get secretlyUser => 'Пользователь Secretly';

  @override
  String get onlineStatus => 'в сети';

  @override
  String get edit => 'Редактировать';

  @override
  String get removePhoto => 'Удалить фото';

  @override
  String get profileSectionTitle => 'Профиль';

  @override
  String get myNicknameLabel => 'Мой ник';

  @override
  String get myNicknameHint => 'например, Алекс';

  @override
  String get includeNicknameInQr => 'Включать ник в моём QR';

  @override
  String get includeNicknameInQrSubtitle => 'По умолчанию выключено для приватности. Если включить, сканер может автоматически назвать вас.';

  @override
  String verifyTitle(Object title) {
    return 'Проверка: $title';
  }

  @override
  String get scanVerifyQrTitle => 'Сканировать QR для проверки';

  @override
  String qrBelongsAnotherServer(Object server) {
    return 'QR относится к другому серверу: $server';
  }

  @override
  String get qrSecretlyIdMismatch => 'ID в Secretly из QR не совпадает с этим контактом';

  @override
  String get qrMissingDeviceKeyInfo => 'В QR нет данных устройства/ключа';

  @override
  String get deviceNotCachedTapRefresh => 'Устройство не закешировано. Сначала нажмите «Обновить».';

  @override
  String get identityKeyMismatch => 'Несовпадение identity key. Не проверяйте.';

  @override
  String get verifiedSuccess => 'Проверено ✅';

  @override
  String get refreshKeys => 'Обновить ключи';

  @override
  String get keysOfflineCannotFetch => 'Keys недоступен. Сейчас нельзя получить ключи контакта.';

  @override
  String get devicesLabel => 'Устройства';

  @override
  String get noDeviceKeysCachedYet => 'Ключи устройств ещё не закешированы.';

  @override
  String deviceTitle(Object deviceId) {
    return 'Устройство $deviceId';
  }

  @override
  String deviceFpStatus(Object fp, Object status) {
    return 'fp: $fp\n$status';
  }

  @override
  String get verifiedLower => 'проверено';

  @override
  String get unverifiedLower => 'не проверено';

  @override
  String get keysOfflineIdTemporary => 'Keys недоступен. В dev-режиме ID может быть временным.';

  @override
  String get serverKeysLabel => 'Сервер (Keys)';

  @override
  String get nicknameLabel => 'Ник';

  @override
  String get identityFingerprintLabel => 'Отпечаток identity';

  @override
  String get scanToAddVerifyContact => 'Сканируйте, чтобы добавить/проверить этот контакт';

  @override
  String get mySecretlyId => 'Мой ID в Secretly';

  @override
  String get deviceId => 'ID устройства';

  @override
  String get recoveryKit => 'Recovery Kit';

  @override
  String get safeBackupTitle => 'Резервная копия';

  @override
  String get safeBackupSubtitle => 'Зашифрованная резервная копия на сервере';

  @override
  String get safeBackupIntro => 'Создайте зашифрованную резервную копию локально или на сервере. Позже можно восстановить аккаунт по файлу или ID в Secretly.';

  @override
  String get safeBackupUploadNow => 'Загрузить копию';

  @override
  String get safeBackupRestoreFromServer => 'Восстановить с сервера';

  @override
  String get safeBackupRestoreTitle => 'Восстановление с сервера';

  @override
  String get safeBackupRestoreConfirmTitle => 'Восстановить аккаунт?';

  @override
  String get safeBackupRestoreConfirmBody => 'Это удалит локальные чаты/контакты на этом устройстве и восстановит аккаунт из выбранной резервной копии. Приложение автоматически перезапустится.';

  @override
  String get safeBackupUploaded => 'Резервная копия загружена';

  @override
  String get safeBackupUploadFailed => 'Не удалось загрузить резервную копию';

  @override
  String safeBackupUploadFailedWithError(Object error) {
    return 'Не удалось загрузить резервную копию: $error';
  }

  @override
  String get safeBackupNotFound => 'На сервере нет резервной копии для этого ID в Secretly';

  @override
  String get exportRecoveryKit => 'Экспорт Recovery Kit';

  @override
  String get exportRecoveryKitSubtitle => 'Зашифрованный QR для восстановления аккаунта';

  @override
  String get restoreRecoveryKit => 'Восстановить из Recovery Kit';

  @override
  String get restoreRecoveryKitSubtitle => 'Удаляет локальные данные и восстанавливает ID в Secretly';

  @override
  String get recoveryPasswordTitle => 'Пароль Recovery Kit';

  @override
  String get password => 'Пароль';

  @override
  String get confirmPassword => 'Повторите пароль';

  @override
  String get export => 'Экспорт';

  @override
  String get scanQr => 'Сканировать QR';

  @override
  String get invalidRecoveryKit => 'Некорректный Recovery Kit';

  @override
  String get wrongPassword => 'Неверный пароль';

  @override
  String get restoreConfirmTitle => 'Восстановить аккаунт?';

  @override
  String get restoreConfirmBody => 'Это удалит локальные чаты/контакты на этом устройстве и восстановит аккаунт из Recovery Kit.';

  @override
  String get restore => 'Восстановить';

  @override
  String get darkTheme => 'Тёмная тема';

  @override
  String get darkThemeSubtitle => 'Тот же акцентный оттенок в тёмной теме.';

  @override
  String get blockUnverified => 'Блокировать отправку непроверенным';

  @override
  String get blockUnverifiedSubtitle => 'Строгий режим: в личной переписке писать только тем, чьи ключи вы сверили лично. На группы не распространяется.';

  @override
  String get blockedUsers => 'Заблокированные';

  @override
  String get resetProfile => 'Сбросить профиль';

  @override
  String get resetProfileSubtitle => 'Исправляет несоответствие сервера, создавая новый ID в Secretly';

  @override
  String get resetProfileDialogTitle => 'Сбросить профиль?';

  @override
  String get resetProfileDialogBody => 'Это удалит локальные чаты/контакты/запросы на этом устройстве и создаст новый ID в Secretly.\n\nИспользуйте, если вы сменили APK/сервер и сообщения перестали работать.';

  @override
  String get cancel => 'Отмена';

  @override
  String get ok => 'OK';

  @override
  String get add => 'Добавить';

  @override
  String get delete => 'Удалить';

  @override
  String get clear => 'Очистить';

  @override
  String get block => 'Заблокировать';

  @override
  String get unblock => 'Разблокировать';

  @override
  String get accept => 'Принять';

  @override
  String get verify => 'Проверить';

  @override
  String get menu => 'Меню';

  @override
  String get search => 'Поиск';

  @override
  String get queryLabel => 'Запрос';

  @override
  String get messageHint => 'Сообщение';

  @override
  String get notificationActionMarkRead => 'Прочитано';

  @override
  String get addCaption => 'Добавить подпись';

  @override
  String get uploadCanceled => 'Загрузка отменена';

  @override
  String get attachmentFinalizeTimeout => 'Сеть нестабильна: файл загружен, но подтверждение отправки не получено. Попробуйте ещё раз.';

  @override
  String get attachmentTransferUnavailable => 'Сейчас не удалось передать вложение. Проверьте интернет/сервер и попробуйте ещё раз.';

  @override
  String get attachmentSendUnavailable => 'Отправка вложения пока недоступна. Попробуйте ещё раз.';

  @override
  String get attachmentContactSyncPending => 'Ждём синхронизацию идентичности контакта. Попросите контакт отправить ещё одно сообщение и попробуйте снова.';

  @override
  String get attachmentContactBlocked => 'Этот контакт заблокирован.';

  @override
  String get attachmentRecipientNotFound => 'Профиль получателя не найден на этом сервере. Проверьте ID в Secretly и убедитесь, что у обоих устройств один и тот же сервер.';

  @override
  String get attachmentRecipientNoDevices => 'У получателя пока нет зарегистрированных устройств. Попросите открыть Secretly и попробуйте снова.';

  @override
  String get attachmentNoDeliverableDevices => 'Не удалось доставить вложение ни на одно устройство получателя. Попробуйте ещё раз.';

  @override
  String get attachmentActionGeneric => 'Не удалось отправить вложение. Попробуйте ещё раз.';

  @override
  String get send => 'Отправить';

  @override
  String get attach => 'Вложение';

  @override
  String get photo => 'Фото';

  @override
  String get video => 'Видео';

  @override
  String get file => 'Файл';

  @override
  String get music => 'Музыка';

  @override
  String get attachment => 'Вложение';

  @override
  String get downloading => 'Загрузка…';

  @override
  String downloadFailed(Object error) {
    return 'Не удалось скачать: $error';
  }

  @override
  String savedTo(Object path) {
    return 'Сохранено в: $path';
  }

  @override
  String get noMessagesYet => 'Сообщений пока нет';

  @override
  String get decrypting => 'Расшифровка…';

  @override
  String get uploading => 'Загрузка…';

  @override
  String get uploadTimedOut => 'Загрузка превысила время ожидания. Проверьте интернет/сервер и попробуйте ещё раз.';

  @override
  String uploadingBytes(Object sent, Object total) {
    return 'Загружено $sent / $total байт';
  }

  @override
  String get requestsInfo => 'Этот чат находится в «Запросах». Примите, чтобы отвечать, или заблокируйте, чтобы игнорировать.';

  @override
  String get verifyRequired => 'Нужна проверка';

  @override
  String get verifyContact => 'Проверить контакт';

  @override
  String get muteNotifications => 'Выключить уведомления';

  @override
  String get unmuteNotifications => 'Включить уведомления';

  @override
  String get setContactPhoto => 'Установить фото контакта';

  @override
  String get removeContactPhoto => 'Удалить фото контакта';

  @override
  String get blockUser => 'Заблокировать пользователя';

  @override
  String get unblockUser => 'Разблокировать пользователя';

  @override
  String get deleteChat => 'Удалить чат';

  @override
  String get missingRecipient => 'Не указан получатель';

  @override
  String get contactNotVerified => 'Код безопасности собеседника изменился. Сверьте его, чтобы писать дальше.';

  @override
  String get safetyNumberChangedTitle => 'Код безопасности изменился';

  @override
  String get safetyNumberChangedBody => 'Раньше вы сверяли код с этим человеком. Сейчас у него новые ключи — обычно так бывает после переустановки приложения или смены телефона. Переписка в любом случае остаётся зашифрованной. Сверьте код заново, если хотите убедиться, что это по-прежнему он.';

  @override
  String get safetyNumberStrictBody => 'У вас включено «Блокировать отправку непроверенным». Сверьте код этого человека, чтобы отправлять ему сообщения.';

  @override
  String get sendAnyway => 'Отправить всё равно';

  @override
  String get alsoDeleteChat => 'Также удалить чат';

  @override
  String get unblockUserConfirmTitle => 'Разблокировать пользователя?';

  @override
  String get blockUserConfirmTitle => 'Заблокировать пользователя?';

  @override
  String get deleteChatConfirmTitle => 'Удалить чат?';

  @override
  String get deleteChatConfirmBody => 'Чат будет удалён только с этого устройства.';

  @override
  String attachFailed(Object error) {
    return 'Не удалось прикрепить: $error';
  }

  @override
  String sendFailed(Object error) {
    return 'Не удалось отправить: $error';
  }

  @override
  String actionFailed(Object error) {
    return 'Действие не выполнено: $error';
  }

  @override
  String get roomPolicyNotMember => 'Вы больше не участник этой комнаты.';

  @override
  String get roomPolicyAdminsOnly => 'Только владельцы и администраторы могут делать это в комнате.';

  @override
  String get roomPolicyTextMessagesDisabled => 'Ваша роль не может отправлять текстовые сообщения в этой комнате.';

  @override
  String get roomPolicyMediaDisabled => 'Ваша роль не может отправлять медиа в этой комнате.';

  @override
  String get roomPolicyReactionsDisabled => 'Реакции в этой комнате отключены.';

  @override
  String get roomPolicyReactionNotAllowed => 'Эта реакция недоступна в этой комнате.';

  @override
  String get roomPolicyPinDenied => 'Только администраторы могут закреплять сообщения в этой комнате.';

  @override
  String get roomPolicyAddMembersDenied => 'Только администраторы могут добавлять участников в эту комнату.';

  @override
  String get roomPolicyChangeInfoDenied => 'Только администраторы могут изменять профиль группы.';

  @override
  String roomPolicySlowMode(Object seconds) {
    return 'Включён медленный режим. Попробуйте снова через $seconds сек.';
  }

  @override
  String get noMatches => 'Совпадений нет';

  @override
  String attachmentTooLarge(Object mb) {
    return 'Слишком большой файл ($mb МБ).';
  }

  @override
  String get attachmentFileMissing => 'Файл больше недоступен.';

  @override
  String foundPrefix(Object hit) {
    return 'Найдено: $hit';
  }

  @override
  String get contactDetailsChat => 'Чат';

  @override
  String get contactDetailsSound => 'Звук';

  @override
  String get contactDetailsCall => 'Звонок';

  @override
  String get contactDetailsVideo => 'Видео';

  @override
  String get contactDetailsUsernameLabel => 'Имя пользователя';

  @override
  String get contactDetailsAddToContacts => 'Добавить в контакты';

  @override
  String get contactDetailsMediaTab => 'Медиа';

  @override
  String get contactDetailsFilesTab => 'Файлы';

  @override
  String get contactDetailsNoMedia => 'Нет медиа';

  @override
  String get contactDetailsNoFiles => 'Нет файлов';

  @override
  String get contactDetailsStatusRecently => 'был(а) недавно';

  @override
  String contactDetailsStatusAt(Object time) {
    return 'был(а) в $time';
  }

  @override
  String get contactDetailsAutoDelete => 'Автоудаление';

  @override
  String get contactDetailsShareContact => 'Поделиться контактом';

  @override
  String get contactDetailsEditContact => 'Изменить контакт';

  @override
  String get contactDetailsDeleteContact => 'Удалить контакт';

  @override
  String get contactDetailsSendGift => 'Отправить подарок';

  @override
  String get contactDetailsStartSecretChat => 'Начать секретный чат';

  @override
  String get contactDetailsCreateShortcut => 'Создать ярлык';

  @override
  String get contactDetailsNameLabel => 'Имя';

  @override
  String get contactDetailsSave => 'Сохранить';

  @override
  String get contactDetailsDeleteConfirmTitle => 'Удалить контакт?';

  @override
  String get contactAutoDeleteOff => 'Выключено';

  @override
  String get contactAutoDelete1Day => '24 часа';

  @override
  String get contactAutoDelete7Days => '7 дней';

  @override
  String get contactAutoDelete30Days => '30 дней';

  @override
  String get contactEditTitle => 'Изменить контакт';

  @override
  String get contactEditDone => 'ГОТОВО';

  @override
  String get contactEditNameLabel => 'Имя';

  @override
  String get contactEditAssignEmoji => 'Присвоить эмодзи';

  @override
  String get contactEditClearEmoji => 'Убрать эмодзи';

  @override
  String get contactEditSetPhoto => 'Установить фото';

  @override
  String get chatMenuReply => 'Ответить';

  @override
  String get chatMenuCopy => 'Копировать';

  @override
  String get chatMenuForward => 'Переслать';

  @override
  String get chatMenuPin => 'Закрепить';

  @override
  String get chatMenuDelete => 'Удалить';

  @override
  String get reset => 'Сбросить';

  @override
  String get diagnostics => 'Диагностика';

  @override
  String get diagnosticsSubtitle => 'Статус, привязка, время';

  @override
  String get sendLater => 'Отправить позже';

  @override
  String get sendSilently => 'Отправить без звука';

  @override
  String scheduledSendToday(Object time) {
    return 'Отправить сегодня в $time';
  }

  @override
  String scheduledSendOn(Object date, Object time) {
    return 'Отправить $date в $time';
  }

  @override
  String get repeatNever => 'Никогда';

  @override
  String get repeat => 'Повторять';

  @override
  String get onboardingBackTooltip => 'Назад';

  @override
  String get onboardingWelcomeTitle => 'Добро пожаловать!';

  @override
  String get onboardingWelcomeSubtitle => 'Мессенджер нового поколения.\nПолная приватность. Без компромиссов.';

  @override
  String get onboardingCreateAccount => 'Создать новый аккаунт';

  @override
  String get onboardingAlreadyHaveAccount => 'Уже есть аккаунт';

  @override
  String get onboardingFeatureE2eTitle => 'Шифрование E2E';

  @override
  String get onboardingFeatureE2eBody => 'Сообщения шифруются на устройстве. Ключи — только у вас.';

  @override
  String get onboardingFeaturePrivacyTitle => 'Полная анонимность';

  @override
  String get onboardingFeaturePrivacyBody => 'Без номера телефона. Без привязки к личным данным.';

  @override
  String get onboardingFeatureRelayTitle => 'Без посредников';

  @override
  String get onboardingFeatureRelayBody => 'Relay-сервер не хранит сообщения. Только передаёт.';

  @override
  String get onboardingProfileTitle => 'Ваш профиль';

  @override
  String get onboardingProfileSubtitle => 'Как вас будут видеть другие пользователи';

  @override
  String get onboardingProfileNameSection => 'Имя профиля';

  @override
  String get onboardingProfileNameHint => 'Ваше имя или псевдоним';

  @override
  String get onboardingNotificationsSection => 'Уведомления';

  @override
  String get onboardingMessageNotificationsTitle => 'Уведомления о сообщениях';

  @override
  String get onboardingMessageNotificationsSubtitle => 'Получать push-уведомления от Secretly';

  @override
  String get onboardingIncomingCallsTitle => 'Входящие звонки';

  @override
  String get onboardingIncomingCallsSubtitle => 'Принимать звонки от контактов';

  @override
  String get continueAction => 'Продолжить';

  @override
  String get onboardingBackupSaveFailed => 'Не удалось сохранить настройки резервной копии';

  @override
  String get backupPasswordRequirements => 'Минимум 8 символов, латиница/ASCII, одна заглавная буква и один спецсимвол. Без пробелов в начале или конце.';

  @override
  String backupPasswordTooShort(Object minLength) {
    return 'Пароль должен быть не короче $minLength символов.';
  }

  @override
  String backupPasswordTooLong(Object maxLength) {
    return 'Пароль должен быть не длиннее $maxLength символов.';
  }

  @override
  String get backupPasswordNonAscii => 'Используйте только латиницу, цифры и ASCII-символы.';

  @override
  String get backupPasswordOuterWhitespace => 'Уберите пробелы в начале или конце пароля.';

  @override
  String get backupPasswordMissingUppercase => 'Добавьте хотя бы одну заглавную букву A-Z.';

  @override
  String get backupPasswordMissingSpecial => 'Добавьте хотя бы один спецсимвол, например !, # или ?.';

  @override
  String get onboardingBackupPasswordTitle => 'Пароль резервной копии';

  @override
  String get onboardingPasswordsDoNotMatch => 'Пароли не совпадают';

  @override
  String get onboardingBackupTitle => 'Резервные копии';

  @override
  String get onboardingBackupSubtitle => 'Защитите переписку от потери данных.\nДаже при смене устройства.';

  @override
  String get onboardingAutoBackupSection => 'Автоматическая резервная копия';

  @override
  String get onboardingAutoBackupTitle => 'Автокопия';

  @override
  String get onboardingAutoBackupSubtitle => 'Автоматически сохранять резервную копию';

  @override
  String get onboardingStorageTypeSection => 'Тип хранилища';

  @override
  String get onboardingBackupMediaTitle => 'Делать резервную копию медиа';

  @override
  String get onboardingBackupMediaSubtitle => 'Фото, видео, файлы и аватары попадут только в локальную резервную копию';

  @override
  String get onboardingFrequencySection => 'Частота';

  @override
  String get onboardingEnterSecretly => 'Войти в Secretly';

  @override
  String get onboardingSkipBackup => 'Пропустить настройку резервной копии';

  @override
  String get onboardingSecretlyIdCopied => 'Secretly ID скопирован';

  @override
  String get onboardingRegistrationCompleteTitle => 'Регистрация завершена';

  @override
  String get onboardingRegistrationCompleteSubtitle => 'Сохраните свой Secretly ID сейчас. Он нужен для восстановления аккаунта и резервной копии на новом устройстве.';

  @override
  String get onboardingYourSecretlyId => 'Ваш Secretly ID';

  @override
  String get onboardingCopyId => 'Скопировать ID';

  @override
  String get onboardingRecoveryWarning => 'Без ID в Secretly и пароля резервной копии восстановить серверную копию будет невозможно. Сохраните ID в надёжном месте и не забывайте пароль.';

  @override
  String get onboardingStorageCloud => 'Облако';

  @override
  String get onboardingStorageCloudSubtitle => 'На сервере Secretly';

  @override
  String get onboardingStorageLocal => 'Локально';

  @override
  String get onboardingStorageLocalSubtitle => 'На этом устройстве';

  @override
  String get onboardingInterval6Hours => '6 часов';

  @override
  String get onboardingInterval12Hours => '12 часов';

  @override
  String get onboardingIntervalEveryDay => 'Каждый день';

  @override
  String get onboardingIntervalEvery3Days => 'Каждые 3 дня';

  @override
  String get onboardingIntervalWeekly => 'Раз в неделю';

  @override
  String get onboardingBackupLocalCandidate => 'Локальная резервная копия Secretly';

  @override
  String get onboardingDownloads => 'Загрузки';

  @override
  String get onboardingDeviceFolder => 'Папка устройства';

  @override
  String get onboardingNoBackupsFound => 'Резервные копии на устройстве не найдены';

  @override
  String get onboardingFoundBackups => 'Найденные резервные копии';

  @override
  String get onboardingNoBackupsFoundBody => 'Secretly проверил локальные резервные копии приложения и папку Загрузки. Если файл лежит в другом месте, выберите его вручную.';

  @override
  String get chooseManually => 'Выбрать вручную';

  @override
  String get onboardingChooseBackupFileTitle => 'Выберите файл резервной копии Secretly';

  @override
  String get onboardingReadBackupFailed => 'Не удалось прочитать файл резервной копии';

  @override
  String get onboardingServerBackupNotFound => 'Резервная копия не найдена на сервере';

  @override
  String get onboardingRestoreThisBackupTitle => 'Восстановить эту резервную копию?';

  @override
  String get onboardingRestoreThisBackupBody => 'Текущие локальные данные на этом устройстве будут заменены.';

  @override
  String onboardingSecretlyIdSummary(Object profileId) {
    return 'ID в Secretly: $profileId';
  }

  @override
  String onboardingContactsSummary(Object count) {
    return 'Контакты: $count';
  }

  @override
  String onboardingMessagesSummary(Object count) {
    return 'Сообщения: $count';
  }

  @override
  String onboardingChatsSummary(Object count) {
    return 'Чаты: $count';
  }

  @override
  String onboardingMediaFilesSummary(Object count) {
    return 'Медиа-файлы: $count';
  }

  @override
  String get onboardingBrokenBackup => 'Повреждённый или неверный файл резервной копии';

  @override
  String get onboardingRestoreFailed => 'Ошибка восстановления. Попробуйте ещё раз.';

  @override
  String get onboardingRestoreLoginTitle => 'Войти в аккаунт';

  @override
  String get onboardingRestoreLoginSubtitle => 'Восстановите переписку и настройки\nиз ранее созданной резервной копии.';

  @override
  String get onboardingRestoreMediaSubtitle => 'Для будущих локальных резервных копий: фото, видео, файлы и аватары будут добавляться только если включить это.';

  @override
  String get onboardingRestoreFromCloudTitle => 'С облака Secretly';

  @override
  String get onboardingRestoreFromCloudSubtitle => 'Введите ID в Secretly и пароль резервной копии — данные загрузятся с сервера';

  @override
  String get onboardingRestoreFromDeviceTitle => 'Найти резервную копию на устройстве';

  @override
  String get onboardingRestoreFromDeviceSubtitle => 'Secretly сам проверит локальные резервные копии и Загрузки';

  @override
  String get onboardingRestoring => 'Восстановление...';

  @override
  String get onboardingRestoreFromServerTitle => 'Восстановить с сервера';

  @override
  String get callRecordOutgoingVideoCall => 'Исходящий видеозвонок';

  @override
  String get callRecordOutgoingCall => 'Исходящий звонок';

  @override
  String get callRecordIncomingVideoCall => 'Входящий видеозвонок';

  @override
  String get callRecordIncomingCall => 'Входящий звонок';

  @override
  String get callRecordMissedCall => 'Пропущенный звонок';

  @override
  String get callRecordDeclinedCall => 'Отклонённый звонок';

  @override
  String get callRecordBusy => 'Абонент занят';

  @override
  String get callRecordFailed => 'Ошибка связи';

  @override
  String get callRecordCanceled => 'Отменённый звонок';

  @override
  String get callRecordOngoing => 'Идёт звонок';

  @override
  String get safeBackupInvalidBackup => 'Некорректная резервная копия Secretly';

  @override
  String get recoveryKitPrepareFailed => 'Не удалось подготовить Recovery Kit на этом устройстве.';

  @override
  String safeBackupPreviewProfileId(String profileId) {
    return 'ID в Secretly: $profileId';
  }

  @override
  String safeBackupPreviewContacts(int count) {
    return 'Контакты: $count';
  }

  @override
  String safeBackupPreviewServer(String server) {
    return 'Сервер: $server';
  }

  @override
  String get safeBackupPreviewTitle => 'Что будет восстановлено:';

  @override
  String get safeBackupSavedToFiles => 'Резервная копия сохранена в Файлы Secretly';

  @override
  String get safeBackupExportCanceled => 'Экспорт резервной копии отменён';

  @override
  String safeBackupExportFailed(Object error) {
    return 'Не удалось экспортировать резервную копию: $error';
  }

  @override
  String get safeBackupCreateDialogTitle => 'Создать резервную копию';

  @override
  String get safeBackupServerDestination => 'Резервная копия на сервер';

  @override
  String get safeBackupLocalDestination => 'Резервная копия в файл';

  @override
  String get safeBackupRestoreDialogTitle => 'Восстановить резервную копию';

  @override
  String get safeBackupRestoreFromDevice => 'Восстановить из файла';

  @override
  String get safeBackupDownloadsLocation => 'Загрузки';

  @override
  String get safeBackupDeviceFolderLocation => 'Папка устройства';

  @override
  String get safeBackupChooseManualHint => 'Secretly автоматически проверил локальные резервные копии приложения и папку Загрузки. Можно выбрать файл вручную, если он сохранён в другом месте.';

  @override
  String get safeBackupChooseManually => 'Выбрать вручную';

  @override
  String safeBackupReadFileFailed(Object error) {
    return 'Не удалось прочитать файл резервной копии: $error';
  }

  @override
  String get safeBackupFrequencyTitle => 'Частота сохранения';

  @override
  String get saveAction => 'Сохранить';

  @override
  String get safeBackupEnableAutoTitle => 'Включить автокопию';

  @override
  String get safeBackupEnableAutoSubtitle => 'Работает в приложении при наличии сети; шифруется вашим паролем';

  @override
  String get safeBackupUploadToServer => 'Загружать на сервер';

  @override
  String get safeBackupSaveOnDevice => 'Сохранять на устройстве';

  @override
  String get safeBackupPasswordConfigured => 'Пароль автокопии: установлен';

  @override
  String get safeBackupPasswordNotSet => 'Пароль автокопии: не задан';

  @override
  String get safeBackupPasswordSaved => 'Пароль автокопии сохранён';

  @override
  String genericFailed(Object error) {
    return 'Ошибка: $error';
  }

  @override
  String get safeBackupSetPassword => 'Задать пароль';

  @override
  String get safeBackupPasswordRemoved => 'Пароль автокопии удалён';

  @override
  String get safeBackupClearPassword => 'Удалить пароль';

  @override
  String get safeBackupRunRequested => 'Автокопия запущена';

  @override
  String get safeBackupRunNow => 'Запустить автокопию сейчас';

  @override
  String safeBackupLastAutoBackup(String time) {
    return 'Последняя автокопия: $time';
  }

  @override
  String get safeBackupLastAutoBackupNever => 'Последняя автокопия: никогда';

  @override
  String safeBackupLastDeviceBackup(String time) {
    return 'Последняя резервная копия на устройстве: $time';
  }

  @override
  String safeBackupLastAutoBackupError(Object error) {
    return 'Ошибка автокопии: $error';
  }

  @override
  String get securityScopeAppObject => 'приложение';

  @override
  String get securityScopePersonalObject => 'Личные';

  @override
  String get securityUnlockAppTitle => 'Разблокируйте приложение';

  @override
  String get securityUnlockPersonalTitle => 'Разблокируйте Личные';

  @override
  String get securityUnlockFingerprintAutoSubtitle => 'Вход по отпечатку запускается автоматически. Если нужно, ниже можно сразу использовать пароль.';

  @override
  String get securityUnlockBiometricPatternAutoSubtitle => 'Сначала запускается нативная биометрия. Если нужно, ниже можно открыть экран графического ключа.';

  @override
  String get securityUnlockNativeSubtitle => 'Подтвердите вход через нативную аутентификацию устройства.';

  @override
  String securityUnlockPasswordSubtitle(String scopeName) {
    return 'Введите пароль, чтобы открыть $scopeName.';
  }

  @override
  String securityUnlockPatternSubtitle(String scopeName) {
    return 'Нарисуйте графический ключ для доступа к $scopeName.';
  }

  @override
  String get securityUnlockBiometricSubtitle => 'Подтвердите личность через нативную биометрию устройства.';

  @override
  String get securityUnlockAppBiometricReason => 'Подтвердите личность для входа в приложение';

  @override
  String get securityUnlockPersonalBiometricReason => 'Подтвердите личность для доступа к Личным';

  @override
  String get securityUnlockPasswordMismatch => 'Пароль не совпадает. Попробуйте еще раз.';

  @override
  String get securityUnlockPatternMismatch => 'Графический ключ не совпадает.';

  @override
  String get securityUnlockNativeIncomplete => 'Нативная аутентификация не завершена.';

  @override
  String get securityPasswordContinueHint => 'Введите пароль для входа';

  @override
  String get securityUseFingerprint => 'Войти с отпечатком';

  @override
  String get securityUsePassword => 'Войти с помощью пароля';

  @override
  String get securityClearPattern => 'Сбросить ключ';

  @override
  String get securityConnectFourDots => 'Соедините минимум 4 точки.';

  @override
  String get securityPasswordMinFourChars => 'Минимум 4 символа.';

  @override
  String get securityPasswordsMismatchFull => 'Пароли не совпадают.';

  @override
  String securityPasswordSetupTitle(String scopeName) {
    return 'Пароль для $scopeName';
  }

  @override
  String get securityPasswordSetupDescription => 'Пароль хранится только в защищенном хранилище устройства.';

  @override
  String get securityNewPassword => 'Новый пароль';

  @override
  String get securityRepeatPassword => 'Повторите пароль';

  @override
  String get securitySavePassword => 'Сохранить пароль';

  @override
  String get securityPatternSetupInstruction => 'Нарисуйте графический ключ минимум из 4 точек.';

  @override
  String get securityPatternSetupRepeat => 'Повторите графический ключ для подтверждения.';

  @override
  String get securityPatternMinFourDots => 'Минимум 4 точки.';

  @override
  String get securityPatternMismatchStartOver => 'Ключи не совпали. Начните заново.';

  @override
  String securityPatternSetupTitle(String scopeName) {
    return 'Графический ключ для $scopeName';
  }

  @override
  String get securityStartOver => 'Начать заново';

  @override
  String get securityTitle => 'Безопасность';

  @override
  String get securityNativeAuthentication => 'Нативная аутентификация';

  @override
  String get securityReady => 'Готово';

  @override
  String get securityUnavailable => 'Недоступно';

  @override
  String get securityNativeAvailableDescription => 'Используется для Face ID, отпечатка пальца и системной аутентификации устройства.';

  @override
  String get securityNativeUnavailableDescription => 'На этом устройстве биометрия или системная аутентификация сейчас недоступны.';

  @override
  String get securityAppLockTitle => 'Вход в приложение';

  @override
  String get securityAppLockDescription => 'Блокирует вход в приложение и может срабатывать после скрытия приложения.';

  @override
  String get securityPersonalChatsTitle => 'Личные чаты';

  @override
  String get securityPersonalChatsDescription => 'Защищает скрытую категорию Личные и вход в конкретные личные чаты.';

  @override
  String get securityAuthEnableAppLockReason => 'Подтвердите биометрию для включения входа в приложение';

  @override
  String get securityAuthChangeSettingsReason => 'Подтвердите биометрию для изменения настроек безопасности';

  @override
  String get securityAuthProtectPersonalReason => 'Подтвердите биометрию для защиты Личных';

  @override
  String get securityAuthChangePersonalReason => 'Подтвердите биометрию для изменения защиты Личных';

  @override
  String get securityNativeUnavailableError => 'Нативная аутентификация недоступна на этом устройстве.';

  @override
  String get securityBiometricCancelled => 'Подтверждение биометрии отменено.';

  @override
  String get securityProtectionMode => 'Режим защиты';

  @override
  String get securityProtectionModeSubtitle => 'Выберите, чем блокировать доступ.';

  @override
  String get securityProtectionModeDescription => 'Пароль и графический ключ хранятся только как стойкие хэши в secure storage. Биометрия использует нативный системный экран.';

  @override
  String get securityProtectionOff => 'Выключено';

  @override
  String get securityProtectionOffDescription => 'Доступ без дополнительной защиты.';

  @override
  String get securityPasswordModeDescription => 'Собственный пароль для разблокировки.';

  @override
  String get securityPatternModeTitle => 'Графический ключ';

  @override
  String get securityPatternModeDescription => 'Рисунок из точек, как на Android.';

  @override
  String get securityNativePromptDescription => 'Нативный системный экран Face ID, отпечатка или системной аутентификации устройства.';

  @override
  String get securityRelockAfterHidden => 'Перезапрашивать после скрытия приложения';

  @override
  String get securityRelockAfterHiddenDescription => 'Если выключить, защита будет срабатывать только после полного перезапуска приложения.';

  @override
  String get securityGracePeriod => 'Задержка перед повторной блокировкой';

  @override
  String get securityGraceUnavailable => 'Недоступно при выключенной автоблокировке.';

  @override
  String securityAllowQuickUnlockWith(String method) {
    return 'Разрешить быструю разблокировку через $method';
  }

  @override
  String get securityQuickUnlockSubtitle => 'Оставляет пароль или графический ключ как основной резервный способ.';

  @override
  String get securityChangePassword => 'Сменить пароль';

  @override
  String get securityChangePattern => 'Сменить графический ключ';

  @override
  String get securityChangeCredentialSubtitle => 'Текущая защита обновится сразу после подтверждения нового секрета.';

  @override
  String get securityProtectionActivated => 'Защита активирована сразу.';

  @override
  String get securityLockNow => 'Заблокировать сейчас';

  @override
  String get securitySaveChanges => 'Сохранить';

  @override
  String get securityGraceImmediately => 'Сразу';

  @override
  String securityGraceAfterSeconds(int seconds) {
    return 'Через $seconds сек';
  }

  @override
  String securityGraceAfterMinutes(int minutes) {
    return 'Через $minutes мин';
  }

  @override
  String get securityStatusLocked => 'Заблокировано';

  @override
  String get securityStatusUnlocked => 'Разблокировано';

  @override
  String get securityAfterHide => 'Сразу после скрытия';

  @override
  String securityGracePill(int seconds) {
    return 'Задержка $secondsс';
  }

  @override
  String get securityNoProtection => 'Без защиты';

  @override
  String get securityNativeBiometrics => 'Нативная биометрия';

  @override
  String get securityBiometricFaceFingerprint => 'Face ID / отпечаток';

  @override
  String get securityBiometricFingerprint => 'Отпечаток пальца';

  @override
  String get securityBiometricNativeDeviceAuthentication => 'Системная аутентификация';

  @override
  String get devicesLinkOpenFailed => 'Не удалось открыть ссылку в браузере.';

  @override
  String get devicesDesktopDescriptionPrefix => 'Вы можете зайти в приложение ';

  @override
  String get devicesDesktopAppLink => 'Secretly на компьютере';

  @override
  String get devicesDesktopDescriptionSuffix => ' с помощью QR кода.';

  @override
  String get devicesFailureTransportBlocked => 'Транспорт заблокирован для текущего сервера. Переключите телефон и desktop на один сервер и повторите.';

  @override
  String get devicesFailureIdentityNotServerBacked => 'Desktop-профиль еще не зарегистрирован на сервере. Повторите попытку через несколько секунд.';

  @override
  String get devicesFailureProfileUnavailable => 'Профиль desktop пока не виден на сервере. Держите приложение открытым и повторите попытку.';

  @override
  String get devicesFailureDeviceUnavailable => 'Устройство desktop пока не видно на сервере. Держите приложение открытым, затем обновите QR и повторите.';

  @override
  String get devicesFailureCompanionRequired => 'Для этого профиля не включён desktop companion. Активируйте доступ на основном телефоне и повторите попытку.';

  @override
  String get devicesFailureCompanionLimit => 'Лимит desktop-устройств для этого профиля исчерпан. Удалите старое desktop-устройство или увеличьте доступные места.';

  @override
  String get devicesFailurePrimaryRequired => 'Основной аккаунт нужно создать на телефоне, а desktop подключать через QR.';

  @override
  String get devicesFailureInvalidQr => 'Это не QR для авторизации устройства.';

  @override
  String get devicesFailureQrExpired => 'Срок действия QR истёк. Создайте новый код на desktop.';

  @override
  String get devicesFailureServerMismatch => 'Этот QR относится к другому серверу. Переключите телефон и desktop на один сервер и повторите.';

  @override
  String get devicesFailureProfileMismatch => 'Пакет синхронизации относится к другому профилю. Создайте новый QR и повторите.';

  @override
  String get devicesFailureRequestNotFound => 'Запрос синхронизации не найден или уже истёк. Создайте новый QR.';

  @override
  String get devicesFailureSessionExpired => 'Сессия QR истекла. Создайте новый QR и повторите.';

  @override
  String get devicesFailureSessionValidation => 'Проверка QR-сессии не прошла. Создайте новый QR и повторите.';

  @override
  String get devicesFailureStateMismatch => 'Состояние запроса синхронизации больше не актуально. Создайте новый QR и повторите.';

  @override
  String get devicesFailureDeviceMismatch => 'Пакет синхронизации относится к другому устройству. Создайте новый QR и повторите.';

  @override
  String get devicesFailureDeclined => 'Вход был отклонён на основном телефоне. Создайте новый QR и повторите попытку.';

  @override
  String get devicesFailureInvalidPayload => 'Получен некорректный пакет синхронизации. Создайте новый QR и повторите.';

  @override
  String get devicesFailureInterrupted => 'Защищённая синхронизация была прервана. Создайте новый QR и повторите.';

  @override
  String get devicesNewUser => 'Новый пользователь';

  @override
  String get devicesNewUserDesktopConfirm => 'Очистить локальные данные и подготовить это desktop-устройство для входа через QR с основного телефона?';

  @override
  String get devicesNewUserMobileConfirm => 'Очистить текущий локальный профиль и зарегистрировать нового пользователя на этом устройстве?';

  @override
  String get devicesCreateAction => 'Создать';

  @override
  String get devicesScanDeviceQr => 'Сканировать QR устройства';

  @override
  String get devicesRequestApproved => 'Запрос подтверждён. Синхронизация отправлена на компьютер.';

  @override
  String get devicesRequestDeclined => 'Запрос отклонён. Desktop останется неавторизованным.';

  @override
  String get devicesApproveSignInTitle => 'Разрешить вход на устройстве?';

  @override
  String get devicesConfirmSyncPrimary => 'Подтвердите синхронизацию с основного устройства (телефон).';

  @override
  String devicesApprovalDeviceOnly(String name) {
    return 'Устройство: $name. Подтверждение выполняется только с основного телефона.';
  }

  @override
  String get devicesSyncChats => 'Синхронизировать чаты';

  @override
  String get devicesSyncSettings => 'Синхронизировать настройки';

  @override
  String get devicesSyncMedia => 'Синхронизировать медиа';

  @override
  String get devicesDeclineSignIn => 'Отклонить вход';

  @override
  String get devicesApprove => 'Разрешить';

  @override
  String get devicesTitle => 'Устройства';

  @override
  String get devicesConnectDevice => 'Подключить устройство';

  @override
  String get devicesPrimaryDeviceTitle => 'Это основное устройство';

  @override
  String get devicesPrimaryDeviceSubtitle => 'Разрешение на синхронизацию чатов, настроек и медиа выдаётся только здесь.';

  @override
  String get devicesQrSessionExpiredNewCode => 'Срок действия QR истёк. Сгенерируйте новый код.';

  @override
  String devicesQrExpiresIn(String time) {
    return 'QR действует ещё $time';
  }

  @override
  String get devicesWaitingQrScan => 'Ожидание сканирования QR на телефоне.';

  @override
  String get devicesQrScannedConfirm => 'QR отсканирован. Подтвердите вход на телефоне.';

  @override
  String get devicesApplyingSecureBundle => 'Применяем защищённый пакет синхронизации…';

  @override
  String get devicesAuthorizationFailed => 'Ошибка авторизации. Повторите попытку.';

  @override
  String get devicesUnauthenticatedChooseAction => 'Вы не авторизованы. Выберите действие ниже.';

  @override
  String get devicesAuthenticated => 'Устройство авторизовано.';

  @override
  String get devicesDesktopWebAuthorization => 'Авторизация на Desktop/Web';

  @override
  String get devicesDesktopModeDescription => 'Выберите режим: зарегистрировать нового пользователя или войти через QR с подтверждением на телефоне.';

  @override
  String get devicesCancelQr => 'Отменить QR';

  @override
  String get devicesRefreshQr => 'Обновить QR';

  @override
  String get devicesSignInViaQr => 'Войти по QR';

  @override
  String get devicesOpenPrimaryInstruction => 'Откройте Secretly на основном телефоне → Настройки → Устройства → Подключить устройство.';

  @override
  String get storageSection => 'Хранилище';

  @override
  String get storageSectionSubtitle => 'Кеш и загрузки на этом устройстве';

  @override
  String get storageUsageTitle => 'Использование памяти';

  @override
  String get storageCategoryMedia => 'Кеш медиа';

  @override
  String get storageCategoryVoiceTranscripts => 'Расшифровки голоса';

  @override
  String get storageCategoryVoiceModel => 'Офлайн-модель голоса';

  @override
  String get storageCategoryStickers => 'Стикеры';

  @override
  String get storageCategoryEmoji => 'Анимированные эмодзи';

  @override
  String get storageCategoryProfileMedia => 'Моя галерея и аватары';

  @override
  String get storageCategoryRecents => 'Недавние файлы';

  @override
  String get storageTotal => 'Всего';

  @override
  String get storageCalculating => 'Подсчёт…';

  @override
  String get storageClearCache => 'Очистить кеш';

  @override
  String get storageClearCacheHint => 'Удаляет кешированные медиа, аватары собеседников и анимированные эмодзи. Ваша галерея, стикеры и чаты сохраняются; медиа скачается заново при просмотре.';

  @override
  String get storageClearing => 'Очистка кеша…';

  @override
  String get storageClearedToast => 'Кеш очищен';

  @override
  String get storageRemoveVoiceModel => 'Удалить офлайн-модель голоса (140 МБ)';

  @override
  String get storageRemoveVoiceModelHint => 'Освобождает модель распознавания речи на устройстве. Она скачается заново при следующей расшифровке голосового сообщения.';

  @override
  String get storageRemoveVoiceModelConfirmTitle => 'Удалить модель голоса?';

  @override
  String get storageRemoveVoiceModelConfirmBody => 'Модель распознавания речи (140 МБ) будет удалена с устройства. Она скачается заново при следующей расшифровке голосового сообщения.';

  @override
  String get storageRemoveVoiceModelConfirm => 'Удалить';

  @override
  String get storageVoiceModelNotInstalled => 'Модель голоса не установлена';

  @override
  String get storageVoiceModelRemovedToast => 'Модель голоса удалена';

  @override
  String get backupStateProtected => 'История защищена';

  @override
  String get backupStateUnprotected => 'История не защищена';

  @override
  String get backupStateFailing => 'Копия не создаётся';

  @override
  String get backupStateStale => 'Копия устарела';

  @override
  String get backupStateNone => 'Копия ещё не создана';

  @override
  String backupLastAt(Object time) {
    return 'Последняя копия: $time';
  }

  @override
  String get backupIntroHint => 'Копия позволяет вернуть переписку на новом устройстве';

  @override
  String get backupAccessUpgradeTitle => 'Пересохраните копию';

  @override
  String get backupAccessUpgradeBody => 'Ваша копия на сервере создана в старом формате: её можно скачать, зная только идентификатор профиля. Данные внутри зашифрованы вашим паролем, но лишний рубеж не помешает. Пересохранение добавит проверку пароля на самом сервере.';

  @override
  String get backupAccessUpgradeAction => 'Пересохранить';

  @override
  String get backupSectionAutomatic => 'Автоматически';

  @override
  String get backupAutoToggle => 'Создавать копии';

  @override
  String get backupPassword => 'Пароль';

  @override
  String get backupPasswordSet => 'Задан';

  @override
  String get backupPasswordNotSet => 'Не задан';

  @override
  String get backupPasswordSaved => 'Пароль сохранён';

  @override
  String get backupWhere => 'Куда';

  @override
  String get backupHowOften => 'Как часто';

  @override
  String get backupIncludeMedia => 'Включать медиа';

  @override
  String get backupAutoFooter => 'Копия зашифрована вашим паролем. Без него восстановить её невозможно — сохраните пароль отдельно. Медиа не попадают в копию на сервере.';

  @override
  String get backupNow => 'Создать копию сейчас';

  @override
  String get backupSectionRestore => 'Восстановление';

  @override
  String get backupRestoreAction => 'Восстановить из копии';

  @override
  String get backupRestoreFooter => 'Заменит переписку и настройки на этом устройстве данными из копии.';

  @override
  String get backupSectionKey => 'Ключ Secretly ID';

  @override
  String get backupKeyShow => 'Показать ключ';

  @override
  String get backupKeyRestore => 'Восстановить по ключу';

  @override
  String get backupKeyFooter => 'Возвращает только ваш Secretly ID — переписки в ключе нет. Восстановление по ключу стирает локальные данные.';

  @override
  String get backupDestServerDevice => 'Сервер и устройство';

  @override
  String get backupDestServer => 'Сервер';

  @override
  String get backupDestDevice => 'Устройство';

  @override
  String get backupDestNone => 'Не выбрано';

  @override
  String get backupDestServerOnly => 'Только сервер';

  @override
  String get backupDestDeviceOnly => 'Только устройство';

  @override
  String get backupTileOff => 'Выключен — история не защищена';

  @override
  String get backupTilePending => 'Включён, но ещё ни разу не выполнялся';

  @override
  String get backupTileFailing => 'Не выполняется — нужно проверить';

  @override
  String get backupTileStale => 'Давно не обновлялся';

  @override
  String get backupPasswordChange => 'Изменить пароль';

  @override
  String get backupPasswordRemove => 'Удалить пароль';

  @override
  String get chatUndecryptablePending => 'Сообщение пришло, но пока не читается — восстанавливаем защищённую сессию…';

  @override
  String get liquidGlassTitle => 'Жидкое стекло';

  @override
  String get liquidGlassSubtitle => 'Преломляющие панели и островки. Выключите для обычного материала — он экономнее и меньше греет.';

  @override
  String get billingPendingTitle => 'Ожидаем оплату';

  @override
  String get billingPendingBody => 'Заказ создан, но платёж ещё не подтверждён. Завершите оплату выбранным способом — премиум включится сам.';

  @override
  String get callsHideAddressTitle => 'Скрывать мой адрес в звонках';

  @override
  String get callsHideAddressSubtitle => 'Через наш сервер: собеседник не увидит IP-адрес, но задержка может вырасти';

  @override
  String get desktopJoinRoomByLink => 'Войти по ссылке';

  @override
  String get desktopJoinRoomLinkHint => 'Вставьте ссылку-приглашение';

  @override
  String get desktopJoinRoomLinkInvalid => 'Это не ссылка-приглашение в комнату';

  @override
  String get desktopOfflineLockTitle => 'Пароль после долгого отсутствия связи';

  @override
  String get desktopOfflineLockDescription => 'Компьютер не выходил на связь дольше срока — при запуске спросим пароль входа. Потерянный компьютер команду «отключить» не получает, а срок получает.';

  @override
  String get desktopOfflineLockNever => 'Никогда';

  @override
  String get desktopOfflineLockDays7 => '7 дней';

  @override
  String get desktopOfflineLockDays14 => '14 дней';

  @override
  String get desktopOfflineLockDays30 => '30 дней';

  @override
  String get desktopPollTitle => 'Опрос';

  @override
  String get desktopPollAnonymous => 'Анонимный опрос';

  @override
  String get desktopPollClosed => 'Завершён';

  @override
  String desktopPollVoters(Object count) {
    return 'Проголосовали: $count';
  }

  @override
  String get desktopPollMultipleHint => 'Можно выбрать несколько';

  @override
  String get desktopPollCloseAction => 'Завершить опрос';

  @override
  String get desktopEventTitle => 'Событие';

  @override
  String get desktopEventGoing => 'Иду';

  @override
  String get desktopEventMaybe => 'Возможно';

  @override
  String get desktopEventNo => 'Не иду';

  @override
  String get desktopPollNewTitle => 'Новый опрос';

  @override
  String get desktopPollQuestionHint => 'Вопрос';

  @override
  String desktopPollOptionHint(Object index) {
    return 'Вариант $index';
  }

  @override
  String get desktopPollAddOption => 'Добавить вариант';

  @override
  String get desktopPollCreateAction => 'Создать';

  @override
  String get desktopPollNeedTwo => 'Нужен вопрос и хотя бы два варианта';

  @override
  String get desktopPollMultipleLabel => 'Несколько ответов';

  @override
  String get desktopPollAnonymousLabel => 'Анонимно';

  @override
  String get desktopEventNewTitle => 'Новое событие';

  @override
  String get desktopEventTitleHint => 'Название';

  @override
  String get desktopEventDescriptionHint => 'Описание';

  @override
  String get desktopEventLocationHint => 'Место';

  @override
  String get desktopEventPickWhen => 'Выбрать дату и время';

  @override
  String get desktopEventNeedTitleAndDate => 'Нужны название и дата';

  @override
  String get desktopViewerOpenExternally => 'Открыть в программе';

  @override
  String get desktopViewerSaveAs => 'Сохранить как…';

  @override
  String desktopViewerPage(Object page, Object total) {
    return 'Страница $page из $total';
  }

  @override
  String get desktopViewerFailed => 'Не удалось показать файл';

  @override
  String get desktopViewerTooLarge => 'Файл слишком большой для просмотра здесь';

  @override
  String get desktopSupportAttach => 'Прикрепить файл';

  @override
  String desktopSupportAttachHint(Object limit) {
    return 'Снимок экрана или файл журнала — до $limit. Вложение шифруется вместе с сообщением.';
  }

  @override
  String desktopSupportTooLarge(Object limit) {
    return 'Файл больше $limit — такой не отправить';
  }

  @override
  String get desktopSupportUnreadable => 'Не удалось прочитать файл';

  @override
  String get desktopSupportRemoveAttachment => 'Убрать вложение';

  @override
  String desktopSupportMegabytes(Object value) {
    return '$value МБ';
  }

  @override
  String get desktopSupportYou => 'Вы';

  @override
  String get desktopSupportShrunk => 'Изображение ужато, чтобы уместиться';

  @override
  String get desktopStickerPackTitle => 'Набор стикеров';

  @override
  String get desktopStickerPackAddPlain => 'Добавить набор';

  @override
  String get desktopStickerPackInstalled => 'Установлено';

  @override
  String get desktopStickerPackInstalling => 'Установка…';

  @override
  String get desktopStickerPackOwn => 'Это ваш набор';

  @override
  String get desktopStickerPackNoAuthor => 'Автор набора неизвестен — откройте такой же стикер в личной переписке';

  @override
  String desktopStickerPackInstallingProgress(Object done, Object total) {
    return 'Установка… $done/$total';
  }

  @override
  String desktopStickerPackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count стикера',
      many: '$count стикеров',
      few: '$count стикера',
      one: '$count стикер',
    );
    return '$_temp0';
  }

  @override
  String desktopStickerPackAdd(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Добавить $count стикера',
      many: 'Добавить $count стикеров',
      few: 'Добавить $count стикера',
      one: 'Добавить $count стикер',
    );
    return '$_temp0';
  }
}
