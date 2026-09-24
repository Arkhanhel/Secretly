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

  @override
  String get desktopPairingTitle => 'Подключите Secretly Desktop';

  @override
  String get desktopPairingHowTo => 'На телефоне откройте Secretly → Настройки → Устройства → «Подключить устройство» и отсканируйте этот QR-код.';

  @override
  String get desktopPairingPreparingQr => 'Готовим QR…';

  @override
  String get desktopPairingQrUnavailable => 'QR недоступен';

  @override
  String get desktopPairingCodeExpired => 'Код истёк — обновляем…';

  @override
  String desktopPairingCodeValidFor(Object time) {
    return 'Код действителен ещё $time';
  }

  @override
  String get desktopPairingPrepareFailed => 'Не удалось подготовить код. Проверьте подключение к интернету и попробуйте ещё раз.';

  @override
  String get desktopPairingRevoked => 'Это устройство удалили из аккаунта, поэтому код не создаётся.\nПодключите десктоп заново — он получит новую личность устройства, а старая останется отозванной. Доступ к перепискам даст только подтверждение с телефона.';

  @override
  String get desktopPairingPreparingNew => 'Готовим новое подключение…';

  @override
  String get desktopPairingConnectAsNew => 'Подключить как новое устройство';

  @override
  String get desktopPairingIdentityResetFailed => 'Не удалось пересоздать личность устройства. Перезапустите приложение и попробуйте ещё раз.';

  @override
  String get desktopPairingWaitingConfirm => 'Ожидаем подтверждения…';

  @override
  String get desktopPairingNewQr => 'Сгенерировать новый QR';

  @override
  String get desktopPairingCreatingRequest => 'Создаём запрос…';

  @override
  String get desktopPairingReadyToScan => 'Готов к сканированию';

  @override
  String get desktopPairingWaitingScan => 'Ожидаем сканирования на телефоне…';

  @override
  String get desktopPairingScannedConfirmOnPhone => 'QR отсканирован — подтвердите на телефоне.';

  @override
  String get desktopPairingFetchingProfile => 'Получаем профиль и ключи…';

  @override
  String get desktopPairingConnectedLoading => 'Подключено. Загружаем…';

  @override
  String get desktopPairingConnectionError => 'Ошибка подключения. Попробуйте ещё раз.';

  @override
  String get desktopMenuReaction => 'Реакция';

  @override
  String get desktopMenuContinueInTopic => 'Продолжить в теме';

  @override
  String get desktopMenuCopySelection => 'Копировать выделенное';

  @override
  String get desktopMenuCopyText => 'Копировать текст';

  @override
  String get desktopMenuCopyLink => 'Копировать ссылку';

  @override
  String get desktopMenuTranslate => 'Перевести';

  @override
  String get desktopMenuHideTranslation => 'Скрыть перевод';

  @override
  String get desktopMenuSelect => 'Выделить';

  @override
  String get desktopMenuPhotoOrVideo => 'Фото или видео';

  @override
  String get desktopMenuContact => 'Контакт';

  @override
  String get desktopMenuLocation => 'Геопозиция';

  @override
  String get desktopListPinned => 'ЗАКРЕПЛЁННЫЕ';

  @override
  String get desktopListToday => 'СЕГОДНЯ';

  @override
  String get desktopListYesterday => 'ВЧЕРА';

  @override
  String get desktopListThisWeek => 'НА ЭТОЙ НЕДЕЛЕ';

  @override
  String get desktopListEarlier => 'РАНЬШЕ';

  @override
  String get desktopListNothingFound => 'Ничего не найдено';

  @override
  String get desktopListAddFavourite => 'В избранное';

  @override
  String get desktopListRemoveFavourite => 'Убрать из избранного';

  @override
  String get desktopListMute => 'Заглушить';

  @override
  String get desktopListMarkRead => 'Отметить прочитанным';

  @override
  String get desktopListArchive => 'В архив';

  @override
  String get desktopListFolders => 'Папки';

  @override
  String get desktopListCreate => 'Создать';

  @override
  String get desktopListTyping => 'печатает';

  @override
  String get desktopListDraftPrefix => 'Черновик: ';

  @override
  String desktopListDiscussion(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Обсуждение · $count участника',
      many: 'Обсуждение · $count участников',
      few: 'Обсуждение · $count участника',
      one: 'Обсуждение · $count участник',
    );
    return '$_temp0';
  }

  @override
  String get desktopCallServerSilent => 'Сервер не ответил. Попробуйте ещё раз или выйдите из созвона.';

  @override
  String get desktopCallRoomMissing => 'Комната недоступна на сервере — созвон в ней не начать.';

  @override
  String get desktopCallNoServer => 'Нет связи с сервером. Проверьте подключение.';

  @override
  String get desktopCallJoinFailed => 'Не удалось войти в созвон. Проверьте связь и попробуйте ещё раз.';

  @override
  String desktopCallSharingScreen(Object name) {
    return '$name показывает экран';
  }

  @override
  String get desktopCallRoomEmpty => 'В комнате пока ничего не написано';

  @override
  String get desktopCallMessageHint => 'Сообщение в комнату…';

  @override
  String get desktopCallSendToRoom => 'Отправить в комнату';

  @override
  String desktopCallParticipantsTab(Object count) {
    return 'Участники · $count';
  }

  @override
  String get desktopCallNotesTab => 'Заметки';

  @override
  String get desktopCallLinkCopied => 'Ссылка скопирована';

  @override
  String get desktopCallFailed => 'Не удалось';

  @override
  String desktopCallFailedWith(Object error) {
    return 'Не удалось: $error';
  }

  @override
  String get desktopCallMicOn => 'Включить микрофон';

  @override
  String get desktopCallMicOff => 'Выключить микрофон';

  @override
  String get desktopCallCamOn => 'Включить камеру';

  @override
  String get desktopCallCamOff => 'Выключить камеру';

  @override
  String get desktopCallNoMediaVideo => 'Сервер не выдал медиа-канал — видео недоступно';

  @override
  String get desktopCallLayoutSingle => 'Один';

  @override
  String get desktopCallLayoutGrid => 'Сетка';

  @override
  String get desktopCallShowOneLarge => 'Показывать одного крупно';

  @override
  String get desktopCallShowGrid => 'Показать всех сеткой';

  @override
  String get desktopCallScreen => 'Экран';

  @override
  String get desktopCallShareStop => 'Остановить показ экрана';

  @override
  String get desktopCallShareStart => 'Показать экран';

  @override
  String get desktopCallNoMediaScreen => 'Сервер не выдал медиа-канал — показ экрана недоступен';

  @override
  String get desktopCallLeave => 'Выйти';

  @override
  String get desktopCallLeaveCall => 'Выйти из созвона';

  @override
  String get desktopCallNoMediaBoth => 'Сервер не выдал медиа-канал: в этом созвоне не будет ни звука, ни видео';

  @override
  String get desktopCallDiscussion => 'Обсуждение';

  @override
  String desktopCallDiscussionOf(Object title) {
    return 'Обсуждение · $title';
  }

  @override
  String get desktopCallEncrypted => 'Созвон защищён сквозным шифрованием';

  @override
  String desktopCallDurationOnAir(Object duration, Object count) {
    return '$duration · $count в эфире';
  }

  @override
  String get desktopCallExitFullScreen => 'Выйти из полноэкранного';

  @override
  String get desktopCallFullScreen => 'Во весь экран';

  @override
  String get desktopCallDemoRoom => 'Демонстрационная комната';

  @override
  String get desktopCallNoCallYet => 'Созвона пока нет';

  @override
  String get desktopCallDemoExplain => 'Она живёт только на этом компьютере и на сервере её нет — созвон в ней не начать. В настоящей комнате кнопка работает.';

  @override
  String get desktopCallStartHint => 'Начните — остальные увидят приглашение в комнате';

  @override
  String get desktopCallVoiceOnly => 'Голосом';

  @override
  String get desktopCallWithCamera => 'С камерой';

  @override
  String get desktopCallConnecting => 'Подключаемся…';

  @override
  String get desktopCallOngoing => 'Идёт обсуждение';

  @override
  String desktopCallOnAir(Object count) {
    return '$count в эфире';
  }

  @override
  String get desktopCallJoin => 'Присоединиться';

  @override
  String get desktopCallFullScreenShort => 'Во весь экран';

  @override
  String get desktopCallReconnecting => 'переподключается';

  @override
  String get desktopCallCannotHear => 'не слышит';

  @override
  String get desktopCallSharingShort => 'показывает экран';

  @override
  String get desktopCallCameraOn => 'камера включена';

  @override
  String get desktopCallPickDevice => 'Выбрать устройство';

  @override
  String get desktopCallPreparingLink => 'Готовим ссылку…';

  @override
  String get desktopCallInvite => 'Пригласить';

  @override
  String desktopCallFps(Object fps) {
    return '$fps к/с';
  }

  @override
  String get desktopSettingsTitle => 'Настройки';

  @override
  String get desktopSettingsGroupApp => 'Приложение';

  @override
  String get desktopSettingsGroupPrivacy => 'Приватность и безопасность';

  @override
  String get desktopSettingsGroupAccount => 'Аккаунт и данные';

  @override
  String get desktopSettingsGeneralLabel => 'Общие';

  @override
  String get desktopSettingsGeneralSubtitle => 'Язык, поведение приложения';

  @override
  String get desktopSettingsGeneralKeywords => 'язык, локаль, enter, отправка, ввод';

  @override
  String get desktopSettingsAppearanceLabel => 'Внешний вид';

  @override
  String get desktopSettingsAppearanceSubtitle => 'Тема, акцент, обои чата';

  @override
  String get desktopSettingsAppearanceKeywords => 'тема, акцент, обои, фон, пузыри, ник, цвет, тёмная, темная, индикатор, галочки, анимация';

  @override
  String get desktopSettingsShortcutsLabel => 'Горячие клавиши';

  @override
  String get desktopSettingsShortcutsSubtitle => 'Что нажимать, чтобы быстрее';

  @override
  String get desktopSettingsShortcutsKeywords => 'клавиши, сочетания, быстро, cmd, ctrl, shortcut';

  @override
  String get desktopSettingsPowerLabel => 'Энергопотребление';

  @override
  String get desktopSettingsPowerSubtitle => 'Что тратит батарею';

  @override
  String get desktopSettingsPowerKeywords => 'батарея, анимация, рамки, статусы, стекло, панели, производительность, нагрев';

  @override
  String get desktopSettingsNotificationsLabel => 'Уведомления';

  @override
  String get desktopSettingsNotificationsSubtitle => 'Звуки, превью, тишина';

  @override
  String get desktopSettingsNotificationsKeywords => 'звук, превью, тишина, не беспокоить, баннер, текст';

  @override
  String get desktopSettingsCallsLabel => 'Звонки';

  @override
  String get desktopSettingsCallsSubtitle => 'Приём звонков и демонстрации';

  @override
  String get desktopSettingsCallsKeywords => 'звонки, входящие, демонстрация, экран, видео, аудио';

  @override
  String get desktopSettingsMediaLabel => 'Звук и видео';

  @override
  String get desktopSettingsMediaSubtitle => 'Камера и микрофон для звонков';

  @override
  String get desktopSettingsMediaKeywords => 'камера, микрофон, устройство, вебкамера, гарнитура, наушники, звук, видео';

  @override
  String get desktopSettingsPrivacyLabel => 'Приватность';

  @override
  String get desktopSettingsPrivacySubtitle => 'Кто и что о вас видит';

  @override
  String get desktopSettingsPrivacyKeywords => 'кто видит, время захода, фото, звонки, сообщения, пересылка, никнейм, поиск, незнакомцы, удалить аккаунт';

  @override
  String get desktopSettingsSecurityLabel => 'Безопасность';

  @override
  String get desktopSettingsSecuritySubtitle => 'Шифрование и проверенные устройства';

  @override
  String get desktopSettingsSecurityKeywords => 'шифрование, e2ee, проверенные, непроверенные, блокировка, пароль, touch id, замок, верификация';

  @override
  String get desktopSettingsBackupLabel => 'Резервная копия';

  @override
  String get desktopSettingsBackupSubtitle => 'Что спасёт историю переписки';

  @override
  String get desktopSettingsBackupKeywords => 'бэкап, резервная, копия, восстановление, safe backup, пароль копии, медиа';

  @override
  String get desktopSettingsBlockedLabel => 'Заблокированные';

  @override
  String get desktopSettingsBlockedSubtitle => 'Кому закрыт доступ к вам';

  @override
  String get desktopSettingsBlockedKeywords => 'блок, заблокированные, разблокировать, чёрный список, черный список, спам';

  @override
  String get desktopSettingsDevicesLabel => 'Сессии и устройства';

  @override
  String get desktopSettingsDevicesSubtitle => 'Активные сеансы';

  @override
  String get desktopSettingsDevicesKeywords => 'устройства, сеансы, сессии, qr, привязка, выход, резервная копия, бэкап';

  @override
  String get desktopSettingsAccountLabel => 'Аккаунт';

  @override
  String get desktopSettingsAccountSubtitle => 'Профиль и выход';

  @override
  String get desktopSettingsAccountKeywords => 'имя, о себе, id, выйти, сбросить';

  @override
  String get desktopSettingsStorageLabel => 'Хранилище';

  @override
  String get desktopSettingsStorageSubtitle => 'Кеш, скачивания';

  @override
  String get desktopSettingsStorageKeywords => 'кеш, кэш, место, очистить, медиа';

  @override
  String get desktopSettingsSupportLabel => 'Поддержка';

  @override
  String get desktopSettingsSupportSubtitle => 'Зашифрованная переписка с нами';

  @override
  String get desktopSettingsSupportKeywords => 'поддержка, помощь, проблема, баг, написать, support';

  @override
  String get desktopSettingsAboutLabel => 'О программе';

  @override
  String get desktopSettingsAboutKeywords => 'версия, сборка, лицензии, сайт';

  @override
  String get desktopSettingsDangerLabel => 'Удалить аккаунт';

  @override
  String get desktopSettingsEndCallFirst => 'Сначала завершите активный звонок.';

  @override
  String get desktopSettingsSignOutTitle => 'Выйти из аккаунта на этом компьютере?';

  @override
  String get desktopSettingsSignOutBody => 'С этого компьютера будут удалены переписка, ключи и кэш. Аккаунт и история на телефоне не пострадают — десктоп можно привязать заново по QR-коду.';

  @override
  String get desktopSettingsSignOut => 'Выйти';

  @override
  String desktopSettingsSignOutFailed(Object error) {
    return 'Не удалось выйти: $error';
  }

  @override
  String get desktopSettingsActive => 'активно';

  @override
  String get desktopGeneralSystemLanguage => 'Системный';

  @override
  String get desktopGeneralInterfaceLanguage => 'Язык интерфейса';

  @override
  String get desktopGeneralAppliesAtOnce => 'Применяется сразу';

  @override
  String get desktopGeneralBehaviour => 'Поведение';

  @override
  String get desktopGeneralEnterSends => 'Enter отправляет сообщение';

  @override
  String get desktopGeneralShiftEnterNewline => 'Shift+Enter — новая строка';

  @override
  String get desktopGeneralEnterNewline => 'Enter — новая строка, Shift+Enter отправляет';

  @override
  String get desktopGeneralHoverMenu => 'Меню при наведении на сообщение';

  @override
  String get desktopGeneralHoverMenuOn => 'Над сообщением появляются реакции и действия';

  @override
  String get desktopGeneralHoverMenuOff => 'Действия — по правой кнопке мыши';

  @override
  String get desktopGeneralLinkPreviews => 'Превью ссылок';

  @override
  String get desktopGeneralLinkPreviewsOn => 'Карточка ссылки уходит вместе с сообщением';

  @override
  String get desktopGeneralLinkPreviewsOff => 'Ссылки уходят без карточки, страницы не открываются';

  @override
  String get desktopPowerAnimations => 'Анимации';

  @override
  String get desktopPowerAnimationsHint => 'Всё включено по умолчанию. Выключайте сверху вниз, если ноутбук греется или садится батарея.';

  @override
  String get desktopPowerFramesTitle => 'Анимация рамок и статусов';

  @override
  String get desktopPowerFramesHint => 'Живые рамки аватаров и эмодзи-статусы у собеседников. Самая дорогая из трёх — выключайте первой.';

  @override
  String get desktopPowerGlassBubbles => 'Стеклянные пузыри';

  @override
  String get desktopPowerGlassBubblesHint => 'Размытие под входящими сообщениями';

  @override
  String get desktopPowerMattePanels => 'Матовые панели';

  @override
  String get desktopPowerMattePanelsHint => 'Размытие панелей и всплывающих окон';

  @override
  String get desktopPowerNotAffectedTitle => 'Что это не затрагивает';

  @override
  String get desktopPowerNotAffectedHint => 'Доставка сообщений, шифрование и уведомления работают одинаково при любых значениях. Эти настройки влияют только на отрисовку.';

  @override
  String get desktopNotifHidden => 'Скрыто';

  @override
  String get desktopNotifSenderOnly => 'Только отправитель';

  @override
  String get desktopNotifSenderAndText => 'Отправитель и текст';

  @override
  String get desktopNotifUnavailableHere => 'Недоступно на этой платформе.';

  @override
  String get desktopNotifShowPreview => 'Показывать превью сообщения';

  @override
  String get desktopNotifInSystem => 'В системных уведомлениях';

  @override
  String get desktopNotifDirectChats => 'Личные чаты';

  @override
  String get desktopNotifDirectChatsHint => 'Уведомления о сообщениях один на один';

  @override
  String get desktopNotifRooms => 'Комнаты';

  @override
  String get desktopNotifRoomsHint => 'Уведомления о сообщениях в комнатах';

  @override
  String get desktopNotifSound => 'Звук';

  @override
  String get desktopNotifDnd => 'Не беспокоить';

  @override
  String get desktopNotifDndHint => 'Отключить все уведомления';

  @override
  String get desktopWallAnimContinuous => 'Постоянно';

  @override
  String get desktopWallAnimOnEnter => 'При открытии чата';

  @override
  String get desktopWallAnimTap => 'По клику по фону';

  @override
  String get desktopWallAnimOff => 'Не анимировать';

  @override
  String get desktopWallpaperNavy => 'Ночной синий';

  @override
  String get desktopWallpaperGraphite => 'Графит';

  @override
  String get desktopWallpaperTeal => 'Бирюза';

  @override
  String get desktopWallpaperPlum => 'Слива';

  @override
  String get desktopWallpaperWine => 'Вино';

  @override
  String get desktopWallpaperMint => 'Мята';

  @override
  String get desktopWallpaperLavender => 'Лаванда';

  @override
  String get desktopWallpaperSunset => 'Закат';

  @override
  String get desktopWallpaperPeach => 'Персик';

  @override
  String get desktopWallpaperSky => 'Небо';

  @override
  String get desktopWallpaperMidnight => 'Полночь';

  @override
  String get desktopAppearanceTitle => 'Оформление';

  @override
  String get desktopAppearanceHint => 'Схема этого окна. Телефон живёт со своей — эта настройка никуда не уезжает.';

  @override
  String get desktopAppearanceScheme => 'Схема';

  @override
  String get desktopAppearanceSchemeHint => 'Тёмная, светлая или по системной';

  @override
  String get desktopAppearanceDark => 'Тёмная';

  @override
  String get desktopAppearanceLight => 'Светлая';

  @override
  String get desktopAppearanceAuto => 'Авто';

  @override
  String get desktopAppearanceAccent => 'Акцент интерфейса';

  @override
  String get desktopAppearanceAccentHint => 'Кнопки, свои пузыри и выделения во всём приложении.';

  @override
  String get desktopAppearanceWallpaper => 'Обои чата';

  @override
  String get desktopAppearanceWallpaperHint => 'Фон чата для всех бесед.';

  @override
  String get desktopAppearanceLiveWallpaper => 'Живые обои';

  @override
  String get desktopAppearanceLiveWallpaperHint => 'Узор с мягким переливом. Тот же набор, что и на телефоне.';

  @override
  String get desktopAppearanceAnimBehaviour => 'Поведение анимации';

  @override
  String get desktopAppearanceAnimBehaviourHint => 'Когда узор оживает.';

  @override
  String get desktopAppearanceWallPulse => 'Обои проводят сообщение';

  @override
  String get desktopAppearanceWallPulseHint => 'Волна света идёт по узору: вверх — когда отправляете, вниз — когда получаете.';

  @override
  String get desktopAppearanceEnable => 'Включить';

  @override
  String get desktopAppearanceLiveOnly => 'Работает только на живых обоях';

  @override
  String get desktopAppearanceBubbleStyle => 'Стиль пузырей сообщений';

  @override
  String get desktopAppearanceBubbleStyleHint => 'Цвет ваших исходящих сообщений во всех чатах.';

  @override
  String get desktopAppearanceSenderColour => 'Цвет имени отправителя';

  @override
  String get desktopAppearanceSenderColourHint => 'Цвет ника собеседника в групповых чатах.';

  @override
  String get desktopAppearanceIndicatorColour => 'Цвет индикаторов';

  @override
  String get desktopAppearanceIndicatorColourHint => 'Галочки доставки и точка непрочитанного.';

  @override
  String get desktopAppearanceDemoMode => 'Демо-режим';

  @override
  String get desktopAppearanceDemoHint => 'Изменения внешнего вида сохранятся, когда профиль будет привязан.';

  @override
  String get desktopAppearanceCurrentChoice => 'Текущий выбор';

  @override
  String desktopAppearanceThemeIs(Object name) {
    return 'Тема: $name';
  }

  @override
  String get desktopBackupEvery6h => 'Каждые 6 часов';

  @override
  String get desktopBackupEvery12h => 'Каждые 12 часов';

  @override
  String get desktopBackupDaily => 'Раз в сутки';

  @override
  String get desktopBackupWeekly => 'Раз в неделю';

  @override
  String get desktopBackupOffWarning => 'Автокопия выключена — восстановить историю будет нечем';

  @override
  String get desktopBackupNeverRan => 'Включена, но ещё ни разу не выполнялась';

  @override
  String desktopBackupLastFailedWith(Object error) {
    return 'Последняя копия не удалась: $error';
  }

  @override
  String get desktopBackupLastFailed => 'Последняя копия не удалась';

  @override
  String get desktopBackupStale => 'Копия давно не обновлялась';

  @override
  String get desktopBackupFresh => 'Копия актуальна';

  @override
  String get desktopBackupState => 'Состояние';

  @override
  String get desktopBackupAutomatic => 'Автоматическая копия';

  @override
  String get desktopBackupAutomaticHint => 'Копия зашифрована вашим паролем. Без пароля её не восстановить ни нам, ни кому-либо ещё — поэтому пароль нужно помнить.';

  @override
  String get desktopBackupCreateAuto => 'Создавать автоматически';

  @override
  String get desktopBackupUploadServer => 'Выгружать на сервер';

  @override
  String get desktopBackupUploadServerHint => 'Доступна с любого устройства';

  @override
  String get desktopBackupKeepLocal => 'Сохранять на этом компьютере';

  @override
  String get desktopBackupKeepLocalHint => 'Не зависит от сети';

  @override
  String get desktopBackupIncludeMedia => 'Включать медиа';

  @override
  String get desktopBackupIncludeMediaHint => 'Копия станет заметно больше';

  @override
  String get desktopBackupFrequency => 'Частота';

  @override
  String get desktopBackupNowhereTitle => 'Копия никуда не сохраняется';

  @override
  String get desktopBackupNowhereHint => 'Автокопия включена, но оба места назначения выключены — значит копия не создаётся. Включите сервер или этот компьютер.';

  @override
  String get desktopBackupRecoveryKey => 'Набор восстановления';

  @override
  String get desktopBackupCreateRecoveryKey => 'Создать набор восстановления';

  @override
  String get desktopBackupRecoveryKeyHint => 'Понадобится, если не останется ни одного устройства с Secretly. Сохраните его отдельно от пароля.';

  @override
  String desktopBackupKeyFailed(Object error) {
    return 'Не удалось создать ключ: $error';
  }

  @override
  String get desktopBackupKeyPassword => 'Пароль набора восстановления';

  @override
  String get desktopBackupPasswordsDiffer => 'Пароли не совпадают.';

  @override
  String get desktopBackupKeyPasswordHint => 'Этим паролем шифруется сам набор. Он не заменяет пароль от приложения и не хранится нигде — восстановить его нельзя.';

  @override
  String get desktopBackupPasswordAgain => 'Ещё раз';

  @override
  String desktopUnblockTitle(Object name) {
    return 'Разблокировать $name?';
  }

  @override
  String get desktopUnblockBody => 'Этот человек снова сможет писать вам и звонить.';

  @override
  String get desktopUnblockAction => 'Разблокировать';

  @override
  String get desktopPrivacyLastSeen => 'Время захода';

  @override
  String get desktopPrivacyProfilePhoto => 'Фотографии профиля';

  @override
  String get desktopPrivacyForwarding => 'Пересылка сообщений';

  @override
  String get desktopPrivacyCalls => 'Звонки';

  @override
  String get desktopPrivacyVoice => 'Голосовые сообщения';

  @override
  String get desktopPrivacyMessages => 'Сообщения';

  @override
  String get desktopPrivacyNobody => 'Никто';

  @override
  String get desktopPrivacyEverybody => 'Все';

  @override
  String get desktopPrivacyContacts => 'Контакты';

  @override
  String get desktopPrivacyEncryption => 'Шифрование';

  @override
  String get desktopPrivacyEncryptionHint => 'Все сообщения и звонки защищены сквозным шифрованием. Ключи находятся только на ваших устройствах.';

  @override
  String get desktopPrivacyE2eeActive => 'Сквозное шифрование активно';

  @override
  String get desktopPrivacyWhoSees => 'Кто видит';

  @override
  String get desktopPrivacyWhoSeesHint => 'Те же настройки видимости, что и в мобильном приложении.';

  @override
  String get desktopPrivacyVisibility => 'Видимость';

  @override
  String get desktopPrivacyByNickname => 'Видимость по никнейму';

  @override
  String get desktopPrivacyByNicknameHint => 'Позволить находить вас по никнейму';

  @override
  String get desktopPrivacySuggest => 'Подсказка людей при поиске';

  @override
  String get desktopPrivacyStrangers => 'Новые чаты с незнакомцами';

  @override
  String get desktopPrivacyStrangersHint => 'В архив и без уведомлений';

  @override
  String get desktopPrivacyAutoDelete => 'Удалить мой аккаунт';

  @override
  String get desktopPrivacyAutoDeleteHint => 'Если вы не заходите дольше выбранного срока, аккаунт и все сообщения удаляются автоматически. Отсчёт сбрасывается при каждом входе.';

  @override
  String get desktopPrivacyIfAbsent => 'Если не захожу';

  @override
  String get desktopPrivacyIn1Month => 'Через 1 месяц';

  @override
  String get desktopPrivacyIn3Months => 'Через 3 месяца';

  @override
  String get desktopPrivacyIn6Months => 'Через 6 месяцев';

  @override
  String get desktopPrivacyIn1Year => 'Через год';

  @override
  String get desktopPrivacyIn2Years => 'Через 2 года';

  @override
  String get desktopLockImmediately => 'Сразу при потере фокуса';

  @override
  String desktopLockSeconds(Object value) {
    return '$value сек.';
  }

  @override
  String desktopLockMinutes(Object value) {
    return '$value мин.';
  }

  @override
  String desktopLockHours(Object value) {
    return '$value ч.';
  }

  @override
  String get desktopLockNoIdentityService => 'Служба проверки личности недоступна — блокировка не включена.';

  @override
  String get desktopLockNotConfirmed => 'Блокировка не включена: подтверждение не пройдено.';

  @override
  String get desktopLockTitle => 'Блокировка приложения';

  @override
  String get desktopLockTouchIdHint => 'Запрашивать Touch ID для входа после потери фокуса.';

  @override
  String get desktopLockPasswordHint => 'Запрашивать пароль устройства для входа после потери фокуса.';

  @override
  String get desktopLockEnableTouchId => 'Включить Touch ID';

  @override
  String get desktopLockEnableLock => 'Включить блокировку';

  @override
  String get desktopLockDevicePassword => 'Пароль устройства';

  @override
  String get desktopLockAfter => 'Блокировать через';

  @override
  String get desktopLockNow => 'Заблокировать сейчас';

  @override
  String get desktopDevicesEndSessionTitle => 'Завершить сеанс?';

  @override
  String desktopDevicesEndSessionBody(Object id) {
    return 'Устройство $id будет отключено от вашего профиля. Чтобы вернуть доступ, потребуется повторное сканирование QR. Продолжить?';
  }

  @override
  String get desktopDevicesEnd => 'Завершить';

  @override
  String desktopDevicesEndFailed(Object error) {
    return 'Не удалось завершить сеанс: $error';
  }

  @override
  String get desktopDevicesEnded => 'Сеанс устройства завершён.';

  @override
  String get desktopDevicesActiveSessions => 'Активные сессии';

  @override
  String get desktopDevicesDemoHint => 'Демо-режим · реальные устройства появятся после подключения профиля';

  @override
  String get desktopDevicesThisComputer => 'macOS · Этот компьютер';

  @override
  String get desktopDevicesDemoMac => 'MacBook Pro · Сейчас активен';

  @override
  String get desktopDevicesDemoIphone => 'iOS 18.2 · 2 часа назад (демо)';

  @override
  String get desktopDevicesDemoIpad => 'iPadOS 18 · вчера (демо)';

  @override
  String get desktopDevicesThisDevice => 'Это устройство';

  @override
  String get desktopDevicesRemoteDevice => 'Удалённое устройство';

  @override
  String get desktopDevicesDisconnect => 'Отключить';

  @override
  String get desktopDevicesTitle => 'Устройства';

  @override
  String desktopDevicesTitleCount(Object count) {
    return 'Устройства · $count';
  }

  @override
  String get desktopDevicesHint => 'Список устройств, привязанных к этому профилю на сервере ключей.';

  @override
  String get desktopDevicesLoadFailed => 'Не удалось загрузить';

  @override
  String get desktopDevicesRetry => 'Повторить';

  @override
  String get desktopDevicesNone => 'Устройств не найдено';

  @override
  String get desktopDevicesNotLinked => 'Профиль ещё не привязан к серверу.';

  @override
  String get desktopDevicesRefresh => 'Обновить список';

  @override
  String get desktopAccentCustom => 'Свой цвет';

  @override
  String get desktopAccentCustomChange => 'Свой цвет — изменить';

  @override
  String get desktopPairTitle => 'Подключить устройство';

  @override
  String get desktopPairHint => 'Покажите QR-код на новом устройстве или отсканируйте его с телефона';

  @override
  String get desktopPairRequestFailed => 'Не удалось создать запрос на подключение';

  @override
  String get desktopPairCodeCopied => 'Содержимое QR скопировано';

  @override
  String get desktopPairNewTitle => 'Подключить новое устройство';

  @override
  String get desktopPairNewHint => 'На новом устройстве откройте Secretly и выберите «Подключиться по QR». Затем отсканируйте код ниже.';

  @override
  String get desktopPairClose => 'Закрыть';

  @override
  String get desktopPairCopyCode => 'Скопировать код';

  @override
  String get desktopPairRefreshQr => 'Обновить QR';

  @override
  String desktopSyncPulled(Object count) {
    return 'Подгружено новых событий: $count';
  }

  @override
  String get desktopSyncTooOften => 'Слишком частые запросы — попробуйте позже';

  @override
  String get desktopSyncNothingNew => 'Готово · новых событий нет';

  @override
  String get desktopSyncDemoUnavailable => 'Недоступно в демо-режиме';

  @override
  String desktopSyncBlobsPulled(Object blobs, Object convos) {
    return 'Подгружено вложений: $blobs (чатов: $convos)';
  }

  @override
  String desktopSyncNoBlobs(Object convos) {
    return 'Готово · новых вложений нет (чатов: $convos)';
  }

  @override
  String get desktopSyncTitle => 'История с других устройств';

  @override
  String get desktopSyncHint => 'Запросить недавнюю историю чатов у мобильного устройства. Используется, если десктоп был офлайн дольше 7 дней или только что был привязан по QR-коду.';

  @override
  String get desktopSyncRunning => 'Синхронизация…';

  @override
  String get desktopSyncAskHistory => 'Запросить историю';

  @override
  String get desktopSyncAsk => 'Запросить';

  @override
  String get desktopSyncBlobsRunning => 'Загрузка вложений…';

  @override
  String get desktopSyncBlobsAction => 'Подкачать вложения';

  @override
  String get desktopSyncBlobsHint => 'Скачивает медиа из недавних чатов, если файлы отсутствуют локально (после повторной привязки или долгого офлайна).';

  @override
  String get desktopSyncBlobsShort => 'Подкачать';

  @override
  String desktopServerBackupOk(Object stamp, Object size, Object profile) {
    return 'Копия на сервере ✓ · $stamp · $size КБ · профиль $profile';
  }

  @override
  String get desktopServerBackupPassword => 'Пароль резервной копии';

  @override
  String get desktopServerBackupPasswordHint => 'Этим паролем копия шифруется и восстанавливается на любом устройстве. Запомните его — без пароля копия бесполезна, восстановить его нельзя.';

  @override
  String get desktopServerBackupRepeat => 'Повторите пароль';

  @override
  String get desktopServerBackupCreate => 'Создать копию';

  @override
  String get desktopServerBackupTitle => 'Резервная копия на сервер';

  @override
  String get desktopServerBackupHint => 'Зашифрованная копия аккаунта на сервере Secretly. Восстанавливается на любом устройстве через «Восстановить с сервера» по вашему Secretly ID и паролю.';

  @override
  String get desktopServerBackupLoading => 'Загрузка…';

  @override
  String get desktopServerBackupCreateOnServer => 'Создать копию на сервере';

  @override
  String get desktopServerBackupUpdate => 'Обновить копию';

  @override
  String desktopFailedWith(Object error) {
    return 'Не удалось: $error';
  }

  @override
  String get desktopStorageDeleteModelTitle => 'Удалить модель распознавания?';

  @override
  String get desktopStorageDeleteModelBody => 'Расшифровка голосовых сообщений перестанет работать, пока модель не скачается заново.';

  @override
  String get desktopStorageModelDeleted => 'Модель удалена';

  @override
  String desktopStorageDeleteFailed(Object error) {
    return 'Не удалось удалить: $error';
  }

  @override
  String desktopStorageKb(Object value) {
    return '$value КБ';
  }

  @override
  String desktopStorageMb(Object value) {
    return '$value МБ';
  }

  @override
  String desktopStorageGb(Object value) {
    return '$value ГБ';
  }

  @override
  String get desktopStorageUsage => 'Использование';

  @override
  String get desktopStorageUsageHint => 'Кеш и медиа на этом устройстве';

  @override
  String desktopStorageClearHint(Object size) {
    return 'Освободится $size. Сообщения, отправленные вами файлы и «недавние» не удаляются — их неоткуда восстановить.';
  }

  @override
  String get desktopStorageClear => 'Очистить кеш';

  @override
  String get desktopStorageCounting => 'Подсчёт…';

  @override
  String get desktopStorageSpeechModel => 'Модель распознавания речи';

  @override
  String get desktopStorageSpeechModelHint => 'Используется для расшифровки голосовых сообщений на этом компьютере, без отправки звука куда-либо. Обычная очистка кеша её НЕ удаляет — она большая и качается отдельно.';

  @override
  String get desktopStorageDeleteModel => 'Удалить модель';

  @override
  String desktopStorageMedia(Object size) {
    return 'Медиа · $size';
  }

  @override
  String desktopStorageVoice(Object size) {
    return 'Голос · $size';
  }

  @override
  String desktopStorageOther(Object size) {
    return 'Прочее · $size';
  }

  @override
  String get desktopStorageFree => 'Свободно';

  @override
  String desktopStorageTotal(Object size) {
    return 'Всего · $size';
  }

  @override
  String desktopAboutVersion(Object version, Object build) {
    return 'Версия $version · сборка $build';
  }

  @override
  String get desktopAboutTagline => 'Защищённый мессенджер с end-to-end шифрованием. Без облака. Без рекламы. Открытый исходный код.';

  @override
  String get desktopAboutLicences => 'Лицензии';

  @override
  String get desktopAboutWebsite => 'Сайт';

  @override
  String get desktopDangerTitle => 'Удалить аккаунт безвозвратно?';

  @override
  String get desktopDangerBody => 'Профиль, ключи, локальные данные и история сообщений будут удалены на этом и других устройствах. Восстановление невозможно.';

  @override
  String get desktopDangerDeleting => 'Удаление аккаунта…';

  @override
  String desktopDangerFailed(Object error) {
    return 'Не удалось удалить аккаунт: $error';
  }

  @override
  String get desktopDangerSection => 'Удаление аккаунта';

  @override
  String get desktopDangerDemo => 'Демо-режим · удаление недоступно без подключённого профиля.';

  @override
  String get desktopDangerEnterId => 'Введите ваш Secretly ID для подтверждения';

  @override
  String desktopDangerEnterIdExact(Object id) {
    return 'Введите $id для подтверждения';
  }

  @override
  String get desktopDangerAction => 'Удалить аккаунт';

  @override
  String get desktopDangerIrreversible => 'Это действие необратимо. Удалятся все ваши данные, история сообщений и ключи. Восстановление невозможно.';

  @override
  String get desktopSecurityE2ee => 'Сквозное шифрование';

  @override
  String get desktopSecurityE2eeHint => 'Все сообщения, звонки и файлы шифруются на вашем устройстве. Ключи не покидают ваши устройства — сервер видит только шифртекст.';

  @override
  String get desktopSecurityVerifiedDevices => 'Проверенные устройства';

  @override
  String get desktopSecurityVerifiedHint => 'Пока настройка включена, сообщения не уходят на неподтверждённые устройства собеседника. Это защита от подмены, но сообщение может не дойти, пока он не подтвердит новое. Только личная переписка: на группы не действует.';

  @override
  String get desktopSecurityOnlyVerified => 'Только проверенные устройства';

  @override
  String get desktopSecurityBlocked => 'Непроверенные устройства блокируются';

  @override
  String get desktopSecurityAllDevices => 'Сообщения уходят на все устройства собеседника';

  @override
  String get desktopSecurityAppEntry => 'Вход в приложение';

  @override
  String get desktopSecurityAppEntryHint => 'Пароль при открытии Secretly и после того, как окно было скрыто дольше минуты. Действует на этом компьютере.';

  @override
  String get desktopSecurityPersonalScopeHint => 'Отдельный пароль на категорию «Личные». Без него личные чаты открыты любому, у кого есть доступ к разблокированному компьютеру.';

  @override
  String get desktopCallsInApp => 'Звонки в приложении';

  @override
  String get desktopCallsInAppHint => 'Выключите, чтобы полностью отключить звонки';

  @override
  String get desktopCallsAccept => 'Принимать входящие';

  @override
  String get desktopCallsAcceptHint => 'Вам смогут звонить';

  @override
  String get desktopCallsDisabledHint => 'Недоступно, пока звонки выключены';

  @override
  String get desktopCallsScreenShare => 'Демонстрация экрана';

  @override
  String get desktopCallsScreenShareHint => 'Приём чужой демонстрации — отдельное разрешение: на экране может оказаться то, чего вы не ожидали увидеть.';

  @override
  String get desktopCallsAcceptScreenShare => 'Принимать демонстрацию экрана';

  @override
  String get desktopAccountIdCopied => 'Secretly ID скопирован';

  @override
  String get desktopAccountIdHint => 'Этим идентификатором делятся, чтобы вас нашли. Он не содержит ни номера телефона, ни почты.';

  @override
  String get desktopAccountCopy => 'Копировать';

  @override
  String get desktopAccountProfile => 'Профиль';

  @override
  String get desktopAccountProfileHint => 'Имя, фото, статус';

  @override
  String get desktopAccountOpenProfile => 'Открыть страницу профиля';

  @override
  String desktopScopePasswordFor(Object name) {
    return 'Пароль для «$name»';
  }

  @override
  String get desktopScopeMin4 => 'Минимум 4 символа';

  @override
  String get desktopScopeOn => 'Защита включена';

  @override
  String desktopScopeOnFailed(Object error) {
    return 'Не удалось включить: $error';
  }

  @override
  String get desktopScopeOff => 'Защита выключена';

  @override
  String desktopScopeOffFailed(Object error) {
    return 'Не удалось выключить: $error';
  }

  @override
  String get desktopScopePasswordsDiffer => 'Пароли не совпадают';

  @override
  String get desktopScopeTitle => 'Защита паролем';

  @override
  String get desktopScopeOnWithPassword => 'Включена — пароль';

  @override
  String get desktopScopeEnabled => 'Включена';

  @override
  String get desktopScopeDisabled => 'Выключена';

  @override
  String get desktopScopeChangePassword => 'Сменить пароль';

  @override
  String get desktopScopeLockNow => 'Заблокировать';

  @override
  String desktopBlockedUnblocked(Object name) {
    return '$name разблокирован';
  }

  @override
  String desktopBlockedUnblockFailed(Object error) {
    return 'Не удалось разблокировать: $error';
  }

  @override
  String get desktopBlockedTitle => 'Заблокированные';

  @override
  String get desktopBlockedEmptyHint => 'Список пуст. Заблокировать можно из меню чата.';

  @override
  String get desktopBlockedHint => 'Эти люди не могут писать вам и звонить.';

  @override
  String get desktopBlockedNone => 'Никто не заблокирован';

  @override
  String get desktopSupportSent => 'Сообщение отправлено';

  @override
  String get desktopSupportSendFailed => 'Не удалось отправить. Проверьте подключение.';

  @override
  String get desktopSupportUnavailable => 'Поддержка недоступна';

  @override
  String get desktopSupportUnavailableHint => 'Служба поддержки сейчас отключена. Попробуйте позже или напишите с телефона.';

  @override
  String get desktopSupportThread => 'Переписка с поддержкой';

  @override
  String get desktopSupportThreadHint => 'Сообщения шифруются на вашем устройстве. Сервер хранит только шифртекст — прочитать переписку может лишь поддержка.';

  @override
  String get desktopSupportNoReplies => 'Ответов пока нет. Опишите проблему — ответ придёт сюда.';

  @override
  String get desktopSupportWrite => 'Написать в поддержку';

  @override
  String get desktopSupportWriteHint => 'К сообщению автоматически прикладываются версия сборки и идентификатор устройства — без них воспроизвести проблему почти невозможно.';

  @override
  String get desktopSupportDescribe => 'Опишите, что произошло';

  @override
  String get desktopSupportSending => 'Отправляем…';

  @override
  String get desktopSupportSend => 'Отправить';

  @override
  String get desktopChatsEmptyHint => 'Начните общение с телефона — чаты автоматически синхронизируются на десктоп';

  @override
  String get desktopChatsPickOne => 'Выберите чат слева';

  @override
  String desktopChatsSendFailed(Object error) {
    return 'Не удалось отправить: $error';
  }

  @override
  String desktopChatsSendingTo(Object title) {
    return 'Отправляется в «$title»';
  }

  @override
  String get desktopChatsFilterAll => 'Все';

  @override
  String get desktopChatsFilterUnread => 'Непрочит.';

  @override
  String get desktopChatsFilterGroups => 'Группы';

  @override
  String get desktopChatsFilterArchive => 'Архив';

  @override
  String get desktopChatsFilterPersonal => 'Личные';

  @override
  String get desktopChatsRenameFolder => 'Переименовать папку';

  @override
  String get desktopChatsDeleteFolder => 'Удалить папку';

  @override
  String desktopChatsRenameFailed(Object error) {
    return 'Не удалось переименовать: $error';
  }

  @override
  String desktopChatsDeleteFolderTitle(Object name) {
    return 'Удалить папку «$name»?';
  }

  @override
  String get desktopChatsDeleteFolderBody => 'Чаты останутся на месте — удалится только папка.';

  @override
  String desktopChatsDeleteFailed(Object error) {
    return 'Не удалось удалить: $error';
  }

  @override
  String desktopChatsAddedToFolder(Object name) {
    return 'Добавлено в «$name»';
  }

  @override
  String desktopChatsRemovedFromFolder(Object name) {
    return 'Убрано из «$name»';
  }

  @override
  String desktopChatsFolderChangeFailed(Object error) {
    return 'Не удалось изменить папку: $error';
  }

  @override
  String desktopChatsFolderCreated(Object name) {
    return 'Папка «$name» создана';
  }

  @override
  String desktopChatsFolderCreateFailed(Object error) {
    return 'Не удалось создать папку: $error';
  }

  @override
  String get desktopChatsNewFolder => 'Новая папка';

  @override
  String get desktopChatsFolderName => 'Название папки';

  @override
  String desktopChatsRemoveFromFolder(Object name) {
    return 'Убрать из «$name»';
  }

  @override
  String desktopChatsAddToFolder(Object name) {
    return 'В папку «$name»';
  }

  @override
  String get desktopChatsNewFolderWithChat => 'Новая папка с этим чатом…';

  @override
  String get desktopChatsRemoveFromPersonal => 'Убрать из личных';

  @override
  String get desktopChatsAddToPersonal => 'В личные';

  @override
  String get desktopChatsArchiveEmpty => 'В архиве пусто';

  @override
  String get desktopChatsNoPersonal => 'Личных чатов нет';

  @override
  String get desktopChatsPersonalLocked => 'Личные чаты защищены паролем';

  @override
  String get desktopChatsAllRead => 'Всё прочитано';

  @override
  String get desktopChatsFolderEmpty => 'В этой папке пока пусто';

  @override
  String get desktopChatsNewChat => 'Новый чат';

  @override
  String get desktopChatsNewRoom => 'Новая комната';

  @override
  String get desktopChatsStartFailed => 'Не удалось начать чат: профиль недоступен';

  @override
  String get desktopChatsPhoto => 'Фото';

  @override
  String get desktopChatsVideo => 'Видео';

  @override
  String get desktopChatsAudio => 'Аудио';

  @override
  String get desktopChatsVoiceMessage => 'Голосовое сообщение';

  @override
  String get desktopChatsVoiceShort => 'Голосовое';

  @override
  String get desktopChatsLink => 'Ссылка';

  @override
  String get desktopChatsSticker => 'Стикер';

  @override
  String desktopChatsStickerWith(Object label) {
    return 'Стикер $label';
  }

  @override
  String desktopChatsPoll(Object question) {
    return '📊 Опрос: $question';
  }

  @override
  String get desktopChatsUnknown => 'неизвестно';

  @override
  String get desktopChatsMember => 'Участник';

  @override
  String get desktopChatsSoundOn => 'Включить звук';

  @override
  String get desktopChatsSoundOff => 'Без звука';

  @override
  String get desktopChatsClearHistoryTitle => 'Очистить историю?';

  @override
  String desktopChatsClearHistoryBody(Object title) {
    return 'Все сообщения чата «$title» на этом устройстве будут удалены.';
  }

  @override
  String get desktopChatsClear => 'Очистить';

  @override
  String get desktopChatsHistoryClearedBoth => 'История очищена у обоих';

  @override
  String get desktopChatsHistoryCleared => 'История очищена';

  @override
  String get desktopChatsDeleteChatTitle => 'Удалить чат?';

  @override
  String desktopChatsDeleteChatBody(Object title) {
    return 'Чат «$title» полностью удалится с этого устройства.';
  }

  @override
  String get desktopChatsRooms => 'Комнаты';

  @override
  String get desktopChatsGeneralTopic => 'Общий';

  @override
  String get desktopChatsNewTopicEllipsis => 'Новая тема…';

  @override
  String desktopChatsBranch(Object title) {
    return 'Ветка «$title»';
  }

  @override
  String get desktopChatsRename => 'Переименовать';

  @override
  String get desktopChatsIcon => 'Значок';

  @override
  String get desktopChatsDeleteBranch => 'Удалить ветку';

  @override
  String get desktopChatsBranchIcon => 'Значок ветки';

  @override
  String get desktopChatsBranchIconHint => 'Значок заменяет решётку перед названием. Цветные обещают, что внутри: зелёный — созвон, красный — срочное. Остальные серые, чтобы не спорить с именем.';

  @override
  String get desktopChatsHash => 'Решётка';

  @override
  String desktopChatsBranchFailed(Object error) {
    return 'Не удалось изменить ветки: $error';
  }

  @override
  String get desktopChatsNewTopic => 'Новая тема';

  @override
  String get desktopChatsRenameTopic => 'Переименовать тему';

  @override
  String get desktopChatsTopicName => 'Название темы';

  @override
  String desktopChatsReactionFailed(Object error) {
    return 'Не удалось сохранить реакцию: $error';
  }

  @override
  String desktopChatsReactionLocal(Object error) {
    return 'Реакция применена локально, но не доставлена собеседнику: $error';
  }

  @override
  String get desktopChatsRevealFailed => 'Не удалось показать файл в Finder';

  @override
  String desktopChatsVideoOpenFailed(Object error) {
    return 'Не удалось открыть видео: $error';
  }

  @override
  String get desktopChatsVideoUnavailable => 'Видео недоступно';

  @override
  String desktopChatsFileFetchFailed(Object error) {
    return 'Не удалось получить файл: $error';
  }

  @override
  String get desktopChatsSaveAttachment => 'Сохранить вложение';

  @override
  String get desktopChatsFileUnavailable => 'Файл недоступен';

  @override
  String desktopChatsSaveFailed(Object error) {
    return 'Не удалось сохранить: $error';
  }

  @override
  String desktopChatsOpenFailedWith(Object error) {
    return 'Не удалось открыть файл: $error';
  }

  @override
  String get desktopChatsOpenFailed => 'Не удалось открыть файл';

  @override
  String desktopChatsOpenFailedShort(Object error) {
    return 'Не удалось открыть: $error';
  }

  @override
  String desktopChatsPlayFailed(Object error) {
    return 'Не удалось воспроизвести: $error';
  }

  @override
  String get desktopChatsNoCallPeer => 'Не удалось определить собеседника для звонка.';

  @override
  String get desktopChatsCallsNotReady => 'Сервис звонков не готов.';

  @override
  String get desktopChatsCallInProgress => 'Звонок уже идёт.';

  @override
  String get desktopChatsEditFailed => 'Не удалось изменить сообщение.';

  @override
  String get desktopChatsNoRecipient => 'Не удалось определить получателя.';

  @override
  String get desktopChatsDeleteMessageTitle => 'Удалить сообщение?';

  @override
  String get desktopChatsDeleteMessagesTitle => 'Удалить выбранные сообщения?';

  @override
  String get desktopChatsDeleteOthersHint => 'Чужие сообщения удалятся только у вас.';

  @override
  String get desktopChatsDeleteForAll => 'Удалить у всех';

  @override
  String get desktopChatsDeleteForMeOnly => 'Удалить только у меня';

  @override
  String get desktopChatsDeleteForMe => 'Удалить у меня';

  @override
  String get desktopChatsSavePrivacyBlocked => 'Это сообщение нельзя сохранить из-за ограничений приватности.';

  @override
  String get desktopChatsNothingToSave => 'Вложение не скачано — сохранять нечего';

  @override
  String get desktopChatsSavedPartly => 'Сохранено в «Избранное», но не всё';

  @override
  String get desktopChatsSaved => 'Сохранено в «Избранное»';

  @override
  String get desktopChatsForwardPrivacyBlocked => 'Это сообщение нельзя переслать из-за ограничений приватности.';

  @override
  String desktopChatsForwardFailed(Object error) {
    return 'Не удалось переслать: $error';
  }

  @override
  String get desktopChatsNothingToForward => 'Вложение не скачано — переслать нечего';

  @override
  String desktopChatsForwardedPartly(Object title) {
    return 'Переслано в «$title», но не всё';
  }

  @override
  String desktopChatsForwarded(Object title) {
    return 'Переслано в «$title»';
  }

  @override
  String desktopChatsFileNotSentElsewhere(Object text) {
    return 'Файл в другую переписку не отправлен: $text';
  }

  @override
  String get desktopChatsFileSendFailed => 'Не удалось отправить файл.';

  @override
  String desktopChatsPremiumFiles(Object text) {
    return '$text С Premium можно отправлять файлы до 1 ГБ.';
  }

  @override
  String get desktopChatsTypingEllipsis => 'печатает…';

  @override
  String get desktopChatsOnline => 'в сети';

  @override
  String desktopChatsSomeoneTyping(Object name) {
    return '$name печатает';
  }

  @override
  String get desktopChatsLoadingList => 'Подтягиваем список из локального хранилища.';

  @override
  String get desktopChatsWillAppear => 'Сообщения и звонки появятся здесь, как только вы откроете чат.';

  @override
  String get desktopRoomNoOpenHere => 'Открыть переписку отсюда нельзя';

  @override
  String get desktopRoomIdCopied => 'ID скопирован';

  @override
  String get desktopRoomAwaiting => 'Ждёт одобрения';

  @override
  String get desktopRoomBlocked => 'Заблокирован';

  @override
  String get desktopRoomCopied => 'Скопировано';

  @override
  String get desktopRoomChangeRole => 'Изменить роль';

  @override
  String get desktopRoomTransfer => 'Передать владение';

  @override
  String get desktopRoomBlockMember => 'Заблокировать';

  @override
  String get desktopRoomKick => 'Исключить';

  @override
  String get desktopRoomKickTitle => 'Исключить участника?';

  @override
  String desktopRoomKickBody(Object name) {
    return '$name потеряет доступ к комнате. Вернуть его можно новым приглашением.';
  }

  @override
  String get desktopRoomBlockTitle => 'Заблокировать участника?';

  @override
  String desktopRoomBlockBody(Object name) {
    return '$name не сможет вернуться в комнату даже по приглашению, пока блокировку не снимут.';
  }

  @override
  String get desktopRoomTransferTitle => 'Передать владение комнатой?';

  @override
  String desktopRoomTransferBody(Object name) {
    return '$name станет владельцем, а вы — администратором. Отменить это сможет только новый владелец.';
  }

  @override
  String get desktopRoomTransferAction => 'Передать';

  @override
  String get desktopRoomClearTitle => 'Очистить историю?';

  @override
  String get desktopRoomClearBody => 'Все сообщения комнаты на этом устройстве будут удалены.';

  @override
  String get desktopRoomLeaveTitle => 'Покинуть комнату?';

  @override
  String get desktopRoomLeaveBody => 'Вы перестанете получать сообщения. Чтобы вернуться, понадобится новое приглашение.';

  @override
  String get desktopRoomLeave => 'Покинуть';

  @override
  String get desktopRoomInvite => 'Пригласить';

  @override
  String get desktopRoomCopyId => 'Копировать ID комнаты';

  @override
  String get desktopRoomMuteOff => 'Отключить уведомления';

  @override
  String get desktopRoomUnarchive => 'Вернуть из архива';

  @override
  String get desktopRoomLeaveRoom => 'Покинуть комнату';

  @override
  String get desktopRoomUntitled => 'Без названия';

  @override
  String get desktopRoomCopyInvite => 'Скопировать приглашение';

  @override
  String get desktopRoomSound => 'Звук';

  @override
  String get desktopRoomTabInfo => 'Инфо';

  @override
  String get desktopRoomTabMembers => 'Участники';

  @override
  String get desktopRoomTabMedia => 'Медиа';

  @override
  String get desktopRoomTopics => 'ТЕМЫ';

  @override
  String desktopRoomTopicsCount(Object count) {
    return 'ТЕМЫ · $count';
  }

  @override
  String get desktopRoomDescription => 'Описание';

  @override
  String get desktopRoomNotes => 'ЗАМЕТКИ';

  @override
  String get desktopRoomInformation => 'Информация';

  @override
  String get desktopRoomId => 'ID комнаты';

  @override
  String get desktopRoomInviteLink => 'Ссылка-приглашение · нажмите, чтобы скопировать';

  @override
  String get desktopRoomFavouriteHint => 'Плитка на рейке и место вверху списка';

  @override
  String get desktopRoomArchiveHint => 'Скрыть комнату из основного списка';

  @override
  String get desktopRoomNoMembers => 'Нет участников';

  @override
  String desktopRoomMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count участника',
      many: '$count участников',
      few: '$count участника',
      one: '$count участник',
    );
    return '$_temp0';
  }

  @override
  String get desktopRoomNobodyFound => 'Никто не найден';

  @override
  String get desktopRoomMembersUnavailable => 'Список участников недоступен.';

  @override
  String get desktopRoomInCall => 'В СОЗВОНЕ';

  @override
  String get desktopRoomOnline => 'В СЕТИ';

  @override
  String get desktopRoomOffline => 'НЕ В СЕТИ';

  @override
  String desktopRoomMoreHidden(Object count) {
    return 'Ещё $count — найдите поиском выше';
  }

  @override
  String get desktopRoomSearchMember => 'Поиск участника';

  @override
  String get desktopRoomJoinRequests => 'Заявки на вступление';

  @override
  String get desktopRoomAccept => 'Принять';

  @override
  String get desktopRoomDecline => 'Отклонить';

  @override
  String get desktopRoomRoleOwner => 'Владелец';

  @override
  String get desktopRoomRoleAdmin => 'Администратор';

  @override
  String get desktopRoomRoleModerator => 'Модератор';

  @override
  String get desktopRoomRoleRestricted => 'Ограниченный';

  @override
  String get desktopRoomRoleGuest => 'Гость';

  @override
  String get desktopContactBlockTitle => 'Заблокировать?';

  @override
  String get desktopContactUnblockTitle => 'Разблокировать?';

  @override
  String get desktopContactBlockBody => 'Собеседник больше не сможет отправлять вам сообщения и звонить.';

  @override
  String get desktopContactUnblockBody => 'Собеседник снова сможет с вами связаться.';

  @override
  String get desktopContactBlock => 'Заблокировать';

  @override
  String get desktopContactCallsNotReady => 'Сервис звонков ещё не готов';

  @override
  String get desktopContactCallInProgress => 'Звонок уже идёт';

  @override
  String desktopContactCallFailed(Object error) {
    return 'Не удалось начать звонок: $error';
  }

  @override
  String get desktopContactAutoDelete => 'Автоудаление сообщений';

  @override
  String get desktopContactAutoDeleteUpdated => 'Автоудаление обновлено';

  @override
  String get desktopContactClearBody => 'Все сообщения этого чата на этом устройстве будут удалены.';

  @override
  String get desktopContactDeleteBody => 'Чат полностью удалится с этого устройства.';

  @override
  String get desktopContactOff => 'Выключено';

  @override
  String get desktopContactDisable => 'Выключить';

  @override
  String get desktopContactDay1 => '1 день';

  @override
  String get desktopContactDays7 => '7 дней';

  @override
  String get desktopContactDays30 => '30 дней';

  @override
  String get desktopContactHour1 => '1 час';

  @override
  String desktopContactMinutes(Object value) {
    return '$value мин';
  }

  @override
  String get desktopContactOffline => 'не в сети';

  @override
  String desktopContactSeenAt(Object time) {
    return 'был(а) в $time';
  }

  @override
  String get desktopContactSeenYesterday => 'был(а) вчера';

  @override
  String desktopContactSeenOn(Object date) {
    return 'был(а) $date';
  }

  @override
  String get desktopContactCopyId => 'Копировать ID';

  @override
  String get desktopContactCopyIdShort => 'Скопировать ID';

  @override
  String get desktopContactDisappearing => 'Исчезающие сообщения';

  @override
  String get desktopContactDeleteChat => 'Удалить чат';

  @override
  String get desktopContactCall => 'Звонок';

  @override
  String get desktopContactBlockShort => 'Блок';

  @override
  String get desktopContactSecurity => 'Безопасность';

  @override
  String get desktopContactVerify => 'Проверить контакт';

  @override
  String get desktopContactArchiveHint => 'Скрыть чат из основного списка';

  @override
  String get desktopThreadMessageHint => 'Сообщение…';

  @override
  String get desktopThreadPasteFailed => 'Не удалось вставить картинку';

  @override
  String get desktopThreadNoScheduleEdit => 'Правку нельзя отложить — она меняет уже отправленное';

  @override
  String desktopThreadWillLeave(Object when) {
    return 'Уйдёт $when';
  }

  @override
  String desktopThreadSeconds(Object value) {
    return '$value с';
  }

  @override
  String desktopThreadMinutes(Object value) {
    return '$value мин';
  }

  @override
  String desktopThreadHours(Object value) {
    return '$value ч';
  }

  @override
  String desktopThreadDays(Object value) {
    return '$value дн';
  }

  @override
  String desktopThreadWeeks(Object value) {
    return '$value нед';
  }

  @override
  String desktopThreadSelected(Object count) {
    return 'Выбрано: $count';
  }

  @override
  String get desktopThreadDisappearingOn => 'Исчезающие сообщения включены';

  @override
  String get desktopThreadCallAction => 'Позвонить';

  @override
  String get desktopThreadCallRoom => 'Созвон';

  @override
  String get desktopThreadVideoCall => 'Видеозвонок';

  @override
  String get desktopThreadSearchShortcut => 'Поиск в чате  Cmd F';

  @override
  String get desktopThreadHideDetails => 'Скрыть детали';

  @override
  String get desktopThreadShowDetails => 'Показать детали';

  @override
  String get desktopThreadMore => 'Ещё';

  @override
  String get desktopThreadPinned => 'Закреплённое сообщение';

  @override
  String get desktopThreadNoMatches => 'нет совпадений';

  @override
  String get desktopThreadSearchHint => 'Поиск в чате…';

  @override
  String get desktopThreadPrevMatch => 'Предыдущее (Shift F3)';

  @override
  String get desktopThreadNextMatch => 'Следующее (F3)';

  @override
  String get desktopThreadCloseEsc => 'Закрыть (Esc)';

  @override
  String get desktopThreadNewMessages => 'Новые сообщения';

  @override
  String desktopThreadUnreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count непрочитанных',
      many: '$count непрочитанных',
      few: '$count непрочитанных',
      one: '$count непрочитанное',
    );
    return '$_temp0';
  }

  @override
  String get desktopThreadToday => 'Сегодня';

  @override
  String get desktopThreadYesterday => 'Вчера';

  @override
  String get desktopProfileEmojiStatus => 'Эмодзи-статус';

  @override
  String get desktopProfileClearStatus => 'Убрать статус';

  @override
  String desktopProfileApplyFailed(Object error) {
    return 'Не удалось применить: $error';
  }

  @override
  String get desktopProfileAvatarFrame => 'Рамка аватара';

  @override
  String get desktopProfileCover => 'Обложка профиля';

  @override
  String get desktopProfileNoFrame => 'Без рамки';

  @override
  String get desktopProfileNoCover => 'Без обложки';

  @override
  String get desktopProfileReadFailed => 'Не удалось прочитать файл';

  @override
  String get desktopProfilePhotoUpdated => 'Фото профиля обновлено';

  @override
  String desktopProfilePhotoFailed(Object error) {
    return 'Не удалось обновить фото: $error';
  }

  @override
  String desktopProfilePhotoRemoveFailed(Object error) {
    return 'Не удалось убрать фото: $error';
  }

  @override
  String get desktopProfileMine => 'Мой профиль';

  @override
  String get desktopProfileEdit => 'Редактировать';

  @override
  String get desktopProfileName => 'Имя';

  @override
  String get desktopProfileChangePhoto => 'Сменить фото';

  @override
  String get desktopProfileFrameShort => 'Рамка';

  @override
  String get desktopProfileCoverShort => 'Обложка';

  @override
  String get desktopProfileStatus => 'Статус';

  @override
  String get desktopProfileAppearanceHint => 'Тема, акцент и обои чата';

  @override
  String get desktopProfileAbout => 'О себе';

  @override
  String get desktopProfileEmpty => 'Не заполнено';

  @override
  String get desktopProfilePhoto => 'Фото профиля';

  @override
  String get desktopProfileReplacePhoto => 'Заменить фото';

  @override
  String get desktopProfilePickPhoto => 'Выбрать фото';

  @override
  String get desktopProfilePickedHere => 'Выбрано на этом компьютере';

  @override
  String get desktopProfileSyncedWithPhone => 'Синхронизировано с телефоном';

  @override
  String get desktopProfileNotPicked => 'Не выбрано';

  @override
  String get desktopProfileRemovePhoto => 'Убрать фото';

  @override
  String get desktopProfileInitialsStay => 'Останутся инициалы';

  @override
  String get desktopProfileAccount => 'Аккаунт';

  @override
  String get desktopProfileRecovery => 'Восстановление';

  @override
  String get desktopProfileRecoveryHint => 'Этот компьютер подключён к телефону и своей фразы восстановления не хранит: аккаунт возвращает копия и набор восстановления.';

  @override
  String get desktopProfileDevicesHint => 'Подключённые компьютеры и телефоны';

  @override
  String get desktopProfileFrameCaps => 'РАМКА АВАТАРА';

  @override
  String get desktopGalleryMedia => 'Медиа';

  @override
  String get desktopGalleryFiles => 'Файлы';

  @override
  String get desktopGalleryLinks => 'Ссылки';

  @override
  String get desktopGalleryNoMedia => 'Нет медиа';

  @override
  String get desktopGalleryNoFiles => 'Нет файлов';

  @override
  String get desktopGalleryNoAudio => 'Нет аудио';

  @override
  String get desktopGalleryNoLinks => 'Нет ссылок';

  @override
  String get desktopGalleryPathCopied => 'Путь скопирован';

  @override
  String get desktopGalleryOpen => 'Открыть';

  @override
  String get desktopGalleryView => 'Просмотр';

  @override
  String get desktopGalleryOpenInSystem => 'Открыть в системе';

  @override
  String get desktopGalleryRevealFinder => 'Показать в Finder';

  @override
  String get desktopGalleryRevealExplorer => 'Показать в проводнике';

  @override
  String get desktopGalleryOpenFolder => 'Открыть папку';

  @override
  String get desktopGalleryCopyPath => 'Копировать путь';

  @override
  String desktopGalleryBytes(Object value) {
    return '$value Б';
  }

  @override
  String get desktopGalleryZeroBytes => '0 Б';

  @override
  String desktopOutgoingFolderSingle(Object name) {
    return 'папку «$name» отправить нельзя';
  }

  @override
  String get desktopOutgoingFoldersMany => 'папки отправить нельзя';

  @override
  String desktopOutgoingTooLargeOne(Object name, Object limit) {
    return '«$name» больше $limit МБ';
  }

  @override
  String desktopOutgoingTooLargeMany(int count, Object limit) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count файла больше $limit МБ',
      many: '$count файлов больше $limit МБ',
      few: '$count файла больше $limit МБ',
      one: '$count файл больше $limit МБ',
    );
    return '$_temp0';
  }

  @override
  String desktopOutgoingEmptyOne(Object name) {
    return '«$name» пустой';
  }

  @override
  String desktopOutgoingEmptyMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count файла пустые',
      many: '$count файлов пустые',
      few: '$count файла пустые',
      one: '$count файл пустой',
    );
    return '$_temp0';
  }

  @override
  String desktopOutgoingUnreadableOne(Object name) {
    return '«$name» не удалось прочитать';
  }

  @override
  String desktopOutgoingUnreadableMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count файла не удалось прочитать',
      many: '$count файлов не удалось прочитать',
      few: '$count файла не удалось прочитать',
      one: '$count файл не удалось прочитать',
    );
    return '$_temp0';
  }

  @override
  String get desktopOutgoingSending => 'Отправка';

  @override
  String desktopOutgoingPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count фото',
      one: '$count фото',
    );
    return '$_temp0';
  }

  @override
  String desktopOutgoingVideos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count видео',
      one: '$count видео',
    );
    return '$_temp0';
  }

  @override
  String desktopOutgoingMedia(Object count) {
    return '$count медиа';
  }

  @override
  String desktopOutgoingAudios(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count аудио',
      one: '$count аудио',
    );
    return '$_temp0';
  }

  @override
  String desktopOutgoingFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count файла',
      many: '$count файлов',
      few: '$count файла',
      one: '$count файл',
    );
    return '$_temp0';
  }

  @override
  String get desktopCallsPickOne => 'Выберите звонок слева';

  @override
  String get desktopCallsPickHint => 'Здесь появятся подробности и кнопка перезвонить';

  @override
  String get desktopCallsNone => 'Звонков пока нет';

  @override
  String get desktopCallsNoneHint => 'История появится после первого звонка';

  @override
  String get desktopCallsOutgoing => 'Исходящий';

  @override
  String get desktopCallsIncoming => 'Входящий';

  @override
  String get desktopCallsGroup => 'групповой';

  @override
  String get desktopCallsVideoKind => 'видео';

  @override
  String get desktopCallsAudioKind => 'аудио';

  @override
  String get desktopCallsMissed => 'пропущен';

  @override
  String desktopPhotoCopyFailed(Object error) {
    return 'Не удалось скопировать: $error';
  }

  @override
  String get desktopPhotoSave => 'Сохранить фото';

  @override
  String get desktopPhotoSaved => 'Сохранено';

  @override
  String desktopPhotoRevealFailed(Object error) {
    return 'Не удалось показать в Finder: $error';
  }

  @override
  String get desktopPhotoLoadFailed => 'Не удалось загрузить';

  @override
  String get desktopPhotoZoomOut => 'Уменьшить';

  @override
  String get desktopPhotoZoomReset => 'Сбросить масштаб';

  @override
  String get desktopPhotoZoomIn => 'Увеличить';

  @override
  String get desktopPhotoCopy => 'Скопировать';

  @override
  String desktopBubbleForwardedFrom(Object from) {
    return 'Переслано от $from';
  }

  @override
  String get desktopBubbleAudioFile => 'Аудиофайл';

  @override
  String get desktopBubbleTranslating => 'Переводим…';

  @override
  String get desktopBubbleTranslation => 'ПЕРЕВОД';

  @override
  String get desktopBubbleEdited => 'изменено';

  @override
  String get desktopBubbleMoreReactions => 'Ещё реакции';

  @override
  String get desktopBubbleRoleOwner => 'владелец';

  @override
  String get desktopBubbleRoleAdmin => 'админ';

  @override
  String get desktopBubbleRoleMod => 'модер';

  @override
  String get desktopBubbleSpeed => 'Скорость воспроизведения';

  @override
  String get desktopSpotlightGoChats => 'Перейти к чатам';

  @override
  String get desktopSpotlightGoRooms => 'Перейти к комнатам';

  @override
  String get desktopSpotlightGoContacts => 'Перейти к контактам';

  @override
  String get desktopSpotlightGoCalls => 'Перейти к звонкам';

  @override
  String get desktopSpotlightSelect => 'выбор';

  @override
  String get desktopSpotlightOpen => 'открыть';

  @override
  String get desktopSpotlightClose => 'закрыть';

  @override
  String get desktopSpotlightRoom => 'Комната';

  @override
  String get desktopSpotlightMessage => 'Сообщение';

  @override
  String get desktopSpotlightCommand => 'Команда';

  @override
  String get desktopComposerCancelRec => 'Отменить запись';

  @override
  String desktopComposerRecording(Object time) {
    return 'Запись  $time';
  }

  @override
  String get desktopComposerSendVoice => 'Отправить голосовое';

  @override
  String get desktopComposerAttach => 'Прикрепить';

  @override
  String get desktopComposerEmoji => 'Эмодзи и стикеры';

  @override
  String get desktopComposerRecordVoice => 'Записать голосовое';

  @override
  String get desktopComposerEnterSends => 'Enter — отправить · Shift+Enter — перенос';

  @override
  String get desktopComposerEnterNewline => 'Enter — перенос · Shift+Enter — отправить';

  @override
  String get desktopComposerEditing => 'Редактирование';

  @override
  String desktopComposerReplyTo(Object name) {
    return 'Ответ · $name';
  }

  @override
  String get desktopComposerCancelAction => 'Отменить';

  @override
  String get desktopComposerSendHint => 'Отправить · Enter\nПравая кнопка — отправить позже';

  @override
  String get desktopComposerWriteFirst => 'Сначала напишите сообщение';

  @override
  String desktopComposerToTopic(Object title) {
    return 'в тему «$title»';
  }

  @override
  String get desktopShortcutsNavigation => 'Навигация';

  @override
  String get desktopShortcutsTabs => 'Чаты · Комнаты · Звонки · Контакты';

  @override
  String get desktopShortcutsSearchAll => 'Поиск по чатам и сообщениям';

  @override
  String get desktopShortcutsPrevNext => 'Предыдущий / следующий чат';

  @override
  String get desktopShortcutsInChat => 'В переписке';

  @override
  String get desktopShortcutsFindHere => 'Найти в этой переписке';

  @override
  String get desktopShortcutsSend => 'Отправить (настраивается)';

  @override
  String get desktopShortcutsNewline => 'Перенос строки';

  @override
  String get desktopShortcutsPaste => 'Вставить изображение из буфера';

  @override
  String get desktopShortcutsApp => 'Приложение';

  @override
  String get desktopShortcutsThisHelp => 'Эта справка';

  @override
  String get desktopShortcutsCloseWindow => 'Закрыть окно или поиск';

  @override
  String get desktopShortcutsTray => 'Свернуть в трей';

  @override
  String get desktopShortcutsTitle => 'Горячие клавиши';

  @override
  String get desktopMediaCancelSend => 'Отменить отправку';

  @override
  String get desktopMediaSending => 'Отправка…';

  @override
  String desktopMediaSendingOf(Object total) {
    return 'Отправка… · $total';
  }

  @override
  String get desktopMediaRetryDownload => 'Повторить загрузку';

  @override
  String get desktopMediaImage => 'Изображение';

  @override
  String desktopMediaDownloading(Object size) {
    return 'Загрузка… · $size';
  }

  @override
  String get desktopMediaDownload => 'Загрузить';

  @override
  String get desktopSendAsMedia => 'Отправить как медиа';

  @override
  String get desktopSendAsFiles => 'Отправить как файлы';

  @override
  String get desktopSendUngroup => 'Не группировать';

  @override
  String get desktopSendGroup => 'Группировать';

  @override
  String get desktopSendAddFiles => 'Добавить файлы…';

  @override
  String get desktopSendDropHere => 'Отпустите, чтобы добавить';

  @override
  String get desktopSendCloseEsc => 'Закрыть · Esc';

  @override
  String desktopSendToDestination(Object destination) {
    return 'в «$destination»';
  }

  @override
  String get desktopSendCaptionHint => 'Добавить подпись…';

  @override
  String get desktopSendEmoji => 'Эмодзи';

  @override
  String get desktopSendRemove => 'Убрать';

  @override
  String get desktopSendEnter => 'Отправить · Enter';

  @override
  String get desktopSendShiftEnter => 'Отправить · Shift+Enter';

  @override
  String get desktopCallCtlShareStop => 'Остановить демонстрацию';

  @override
  String get desktopCallCtlShare => 'Демонстрация экрана';

  @override
  String desktopAbsenceDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дня',
      many: '$count дней',
      few: '$count дня',
      one: '$count день',
    );
    return '$_temp0';
  }

  @override
  String desktopAbsencePastFanout(Object days) {
    return 'Этот компьютер не выходил на связь $days. За это время отправители перестали шифровать сообщения для него, и часть переписки сюда не придёт. Она цела на телефоне — откройте там нужные чаты, и свежая история подтянется.';
  }

  @override
  String desktopAbsenceWithinWindow(Object days) {
    return 'Этот компьютер не выходил на связь $days. Сообщения хранятся на сервере неделю, поэтому часть из них могла не сохраниться для него. На телефоне они целы.';
  }

  @override
  String get desktopAbsenceGotIt => 'Понятно';

  @override
  String get desktopNavContacts => 'Контакты';

  @override
  String get desktopChatNotFound => 'Переписка не найдена';

  @override
  String desktopUnreadTitle(Object count) {
    return 'Secretly — $count непрочитанных';
  }

  @override
  String get desktopRoomsNone => 'Комнат пока нет';

  @override
  String get desktopRoomsNoneHint => 'Создайте комнату с телефона — она появится здесь автоматически';

  @override
  String get desktopRoomsPickOne => 'Выберите комнату слева';

  @override
  String get desktopScheduleTitle => 'Отправить позже';

  @override
  String get desktopScheduleInHour => 'Через час';

  @override
  String get desktopScheduleTonight => 'Сегодня в 19:00';

  @override
  String get desktopScheduleTomorrow => 'Завтра в 9:00';

  @override
  String get desktopScheduleInWeek => 'Через неделю';

  @override
  String desktopScheduleTodayAt(Object time) {
    return 'сегодня в $time';
  }

  @override
  String desktopScheduleTomorrowAt(Object time) {
    return 'завтра в $time';
  }

  @override
  String desktopScheduleOnAt(Object date, Object time) {
    return '$date в $time';
  }

  @override
  String get desktopScheduleHint => 'Сообщение уйдёт само в выбранное время — даже если окно будет закрыто, оно отправится при следующем запуске.';

  @override
  String get desktopSchedulePickTime => 'Выбрать время…';

  @override
  String get desktopDevicesSearching => 'Ищем устройства…';

  @override
  String get desktopDevicesNoCameras => 'Камер не найдено. Возможно, приложению не дали к ним доступ в настройках системы.';

  @override
  String get desktopDevicesNoMics => 'Микрофонов не найдено. Возможно, приложению не дали к ним доступ в настройках системы.';

  @override
  String get desktopDevicesOutputHint => 'Куда выводить звук, выбирается в самом созвоне — шевроном у «Микрофона». Там же приложение само переключается на наушники, когда их подключают.';

  @override
  String get desktopDevicesSystemDefault => 'Как выбрано в системе';

  @override
  String get desktopRailSettings => 'Настройки   Cmd ,';

  @override
  String get desktopRailConnected => 'Подключено';

  @override
  String get desktopRailConnecting => 'Подключение…';

  @override
  String get desktopRailOffline => 'Нет соединения';

  @override
  String desktopRailProfile(Object status) {
    return 'Профиль   Cmd P   ·   $status';
  }

  @override
  String get desktopEmojiSmileys => 'Смайлики и эмоции';

  @override
  String get desktopEmojiPeople => 'Люди и тело';

  @override
  String get desktopEmojiNature => 'Природа';

  @override
  String get desktopEmojiFood => 'Еда и напитки';

  @override
  String get desktopEmojiTravel => 'Путешествия';

  @override
  String get desktopEmojiActivities => 'Активности';

  @override
  String get desktopEmojiObjects => 'Предметы';

  @override
  String get desktopEmojiSymbols => 'Символы';

  @override
  String get desktopEmojiFlags => 'Флаги';

  @override
  String get desktopEmojiOther => 'Прочее';

  @override
  String get desktopLockedTitle => 'Secretly заблокирован';

  @override
  String get desktopLockedTouchIdPrompt => 'Подтвердите личность через Touch ID, чтобы продолжить.';

  @override
  String get desktopLockedPasswordPrompt => 'Подтвердите паролем устройства, чтобы продолжить.';

  @override
  String get desktopLockedUnlock => 'Разблокировать';

  @override
  String get desktopLockedWaiting => 'Ожидаем подтверждения…';

  @override
  String get desktopLockedFailed => 'Не удалось подтвердить личность.';

  @override
  String get desktopLockedNoService => 'Служба проверки личности недоступна на этом компьютере. Перезапустите Secretly или компьютер. Если не поможет — напишите в поддержку с телефона.';

  @override
  String get desktopEmojiTabEmoji => 'Эмодзи';

  @override
  String get desktopEmojiTabStickers => 'Стикеры';

  @override
  String get desktopEmojiRecents => 'Недавние';

  @override
  String get desktopEmojiNothingFound => 'Ничего не нашлось';

  @override
  String get desktopEmojiSearchHint => 'Поиск эмодзи';

  @override
  String get desktopStickersSearchHint => 'Поиск стикеров';

  @override
  String get desktopGifSearchHint => 'Поиск GIF';

  @override
  String get desktopGifUnavailable => 'GIF недоступны в этом окне';

  @override
  String get desktopStickerPacksSoon => 'Стикерпаки скоро';

  @override
  String get desktopCallFullscreen => 'Во весь экран';

  @override
  String get desktopCallExitFullscreen => 'Выйти из полноэкранного';

  @override
  String get desktopCallDialing => 'Вызов…';

  @override
  String get desktopCallEnded => 'Завершено';

  @override
  String desktopCallEncryptedFor(Object duration) {
    return 'Зашифровано · $duration';
  }

  @override
  String get desktopCallReturn => 'Вернуться';

  @override
  String get desktopCallInProgress => 'Идёт созвон';

  @override
  String desktopCallInProgressWith(Object title) {
    return 'Идёт созвон · $title';
  }

  @override
  String get desktopCallAnswer => 'Ответить';

  @override
  String get desktopCallAnswerVideo => 'Ответить с видео';

  @override
  String get desktopCallAnswerText => 'Текстом';

  @override
  String get desktopTimeYesterday => 'вчера';

  @override
  String get desktopForwardTitle => 'Переслать в…';

  @override
  String get desktopForwardSearchHint => 'Поиск чата или комнаты';

  @override
  String get desktopForwardNoChats => 'Нет доступных чатов';

  @override
  String get desktopForwardKindDirect => 'Личный чат';

  @override
  String get desktopContactsSearchHint => 'Поиск контактов';

  @override
  String get desktopContactsEmpty => 'Пока никого. Добавьте контакт по ID или ссылке-приглашению.';

  @override
  String desktopContactsNothingFor(Object query) {
    return 'Ничего не найдено по запросу «$query».';
  }

  @override
  String get desktopContactsPick => 'Выберите контакт';

  @override
  String get desktopContactsCardRight => 'Карточка появится справа.';

  @override
  String get desktopContactsWrite => 'Написать сообщение';

  @override
  String get desktopVideoTitle => 'Видео';

  @override
  String get desktopViewerCloseEsc => 'Закрыть  Esc';

  @override
  String get desktopVideoPlayFailed => 'Не удалось воспроизвести видео';

  @override
  String get desktopKeySpace => 'Пробел';

  @override
  String get desktopWindowMinimize => 'Свернуть';

  @override
  String get desktopWindowMaximize => 'Развернуть';

  @override
  String get desktopWindowClose => 'Закрыть';

  @override
  String get desktopWindowBack => 'Назад';

  @override
  String get desktopWindowForward => 'Вперёд';

  @override
  String get desktopSearchEverything => 'Чаты, люди, сообщения, файлы';

  @override
  String get desktopUnitB => 'Б';

  @override
  String get desktopUnitKb => 'КБ';

  @override
  String get desktopUnitMb => 'МБ';

  @override
  String get desktopUnitGb => 'ГБ';

  @override
  String get desktopUnitTb => 'ТБ';

  @override
  String get desktopSyncDone => 'Синхронизировано';

  @override
  String get desktopSyncSyncing => 'Синхронизация…';

  @override
  String get desktopSyncReconnecting => 'Переподключение…';

  @override
  String get desktopDetailsShare => 'Поделиться';

  @override
  String get desktopDetailsHide => 'Скрыть';

  @override
  String get desktopDetailsMore => 'Дополнительно';

  @override
  String get desktopDetailsChangeCover => 'Сменить обложку';

  @override
  String desktopDetailsFrame(Object name) {
    return 'Рамка «$name»';
  }

  @override
  String get desktopApply => 'Применить';

  @override
  String get desktopAccentAppliesTo => 'Кнопки, выделения и кольца. Пузырь остаётся на своём стиле — он выбирается ниже.';

  @override
  String get desktopTranslateUnknownSource => 'Не удалось определить язык сообщения';

  @override
  String get desktopTranslateUnsupported => 'Системный переводчик не знает этой пары языков';

  @override
  String get desktopTranslateNeedsDownload => 'Язык не скачан. Системные настройки → Основные → Язык и регион → Языки перевода';

  @override
  String get desktopTranslateFailed => 'Перевести не удалось';

  @override
  String get desktopNewChatSearchHint => 'Поиск по контактам';

  @override
  String get desktopNewChatNoContacts => 'Контактов пока нет';

  @override
  String get desktopNewChatNobodyFound => 'Никого не нашлось';

  @override
  String get desktopMentionEveryone => 'Все участники';

  @override
  String get desktopMentionAdmins => 'Администраторы';

  @override
  String get desktopMentionEveryoneHint => 'Позвать всех в комнате';

  @override
  String get desktopMentionAdminsHint => 'Позвать владельца и администраторов';

  @override
  String desktopClearForPeer(Object name) {
    return 'Очистить историю у собеседника ($name)';
  }

  @override
  String get desktopClearForPeerHint => 'Сообщения пропадут и на его устройстве, и на всех ваших. Отменить это нельзя.';

  @override
  String get desktopGifNoKey => 'GIF недоступны: сборка без ключа GIPHY';

  @override
  String get desktopGifConnectionLost => 'Связь прервалась. Попробуйте ещё раз';

  @override
  String get desktopNotesHint => 'Что запомнить из этого разговора…';

  @override
  String get desktopNotesPrivate => 'Видно только вам. Не отправляется, не попадает в переписку и не входит в резервную копию — живёт на этом компьютере, в той же зашифрованной базе, что и сообщения.';

  @override
  String get desktopEmojiSearchShort => 'Поиск эмодзи…';

  @override
  String get desktopNotifOpen => 'Открыть';

  @override
  String get desktopLinkPreviewLoading => 'Превью ссылки…';

  @override
  String get desktopLinkPreviewOff => 'Без превью';

  @override
  String get desktopDropToSend => 'Отпустите, чтобы отправить';

  @override
  String get desktopDropEncrypted => 'Файлы будут зашифрованы перед отправкой';

  @override
  String get desktopDetailsPickChat => 'Выберите чат';

  @override
  String get desktopDetailsEmptyHint => 'Сведения о собеседнике или комнате\nпоявятся здесь.';

  @override
  String get desktopMemberWrite => 'Написать';

  @override
  String get desktopShowPanel => 'Показать панель';

  @override
  String get desktopHidePanel => 'Скрыть панель';

  @override
  String get desktopNotifOff => 'Уведомления выключены';

  @override
  String get desktopSettingsSearchHint => 'Найти настройку';

  @override
  String get desktopUnlockPrompt => 'Разблокировать Secretly';

  @override
  String get desktopEnableLockPrompt => 'Подтвердите, чтобы включить блокировку Secretly';

  @override
  String get desktopRoomsNoneHintDot => 'Создайте комнату с телефона — она появится здесь автоматически.';

  @override
  String get desktopSplashLoading => 'Загрузка профиля…';

  @override
  String get desktopOutgoingOnePhoto => 'Фото';

  @override
  String get desktopOutgoingOneVideo => 'Видео';

  @override
  String get desktopOutgoingOneAudio => 'Аудио';

  @override
  String get desktopOutgoingOneFile => 'Файл';

  @override
  String get desktopMenuSettings => 'Настройки…';

  @override
  String get desktopMenuEdit => 'Правка';

  @override
  String get desktopMenuUndo => 'Отменить';

  @override
  String get desktopMenuRedo => 'Повторить';

  @override
  String get desktopMenuCut => 'Вырезать';

  @override
  String get desktopMenuPaste => 'Вставить';

  @override
  String get desktopMenuSelectAll => 'Выбрать все';

  @override
  String get desktopMenuView => 'Вид';

  @override
  String get desktopMenuWindow => 'Окно';

  @override
  String get desktopMenuHelp => 'Справка';

  @override
  String get desktopMenuWebsite => 'Сайт Secretly';

  @override
  String get desktopContactsAddHint => 'ID в Secretly или ссылка-приглашение';

  @override
  String get desktopContactsAdded => 'Контакт добавлен';

  @override
  String get desktopContactsRenamed => 'Имя сохранено';

  @override
  String get desktopMenuCheckUpdates => 'Проверить обновления…';

  @override
  String get desktopNotifBlockedTitle => 'Система не показывает уведомления Secretly';

  @override
  String get desktopNotifBlockedBody => 'Переключатели ниже работают, но показать их некому: уведомления приложения запрещены в настройках системы. Окно часто скрыто, и уведомление — единственный способ узнать о новом сообщении.';

  @override
  String get desktopNotifBlockedAction => 'Открыть настройки системы';

  @override
  String get backupPwRequirements => 'Минимум 8 символов, латиница/ASCII, одна заглавная буква и один спецсимвол. Без пробелов в начале или конце.';

  @override
  String backupPwTooShort(int count) {
    return 'Пароль должен быть не короче $count символов.';
  }

  @override
  String backupPwTooLong(int count) {
    return 'Пароль должен быть не длиннее $count символов.';
  }

  @override
  String get backupPwNonAscii => 'Используйте только латиницу, цифры и ASCII-символы.';

  @override
  String get backupPwOuterSpace => 'Уберите пробелы в начале или конце пароля.';

  @override
  String get backupPwNeedUpper => 'Добавьте хотя бы одну заглавную букву A-Z.';

  @override
  String get backupPwNeedSpecial => 'Добавьте хотя бы один спецсимвол, например !, # или ?.';

  @override
  String get desktopAuthGateTitle => 'Secretly на этом компьютере';

  @override
  String get desktopAuthGateSubtitle => 'Выберите, как войти';

  @override
  String get desktopAuthPhoneTitle => 'Войти через телефон';

  @override
  String get desktopAuthPhoneBody => 'Если Secretly уже стоит на телефоне. Переписка и контакты переедут сюда.';

  @override
  String get desktopAuthCreateTitle => 'Создать новый аккаунт';

  @override
  String get desktopAuthCreateBody => 'Аккаунт только на этом компьютере. Подписку можно оформить лишь в приложении на телефоне.';

  @override
  String get desktopAuthRestoreTitle => 'Восстановить';

  @override
  String get desktopAuthRestoreBody => 'Из набора восстановления или из копии на сервере.';

  @override
  String get desktopAuthBack => 'Назад';

  @override
  String get desktopAuthNameTitle => 'Как вас зовут?';

  @override
  String get desktopAuthNameBody => 'Это имя увидят те, кому вы напишете. Его можно поменять в любой момент.';

  @override
  String get desktopAuthCreating => 'Создаём аккаунт…';

  @override
  String desktopAuthCreateFailed(Object error) {
    return 'Не удалось создать аккаунт: $error';
  }

  @override
  String get desktopAuthCheckClock => 'Проверьте часы компьютера: при расхождении сервер отклоняет запрос.';

  @override
  String get desktopAuthKitTitle => 'Сохраните набор восстановления';

  @override
  String get desktopAuthKitBody => 'Это единственный способ вернуть аккаунт, если компьютер сломается или потеряется. У Secretly нет ни почты, ни номера телефона: без набора аккаунт не вернёт никто, включая нас.';

  @override
  String get desktopAuthKitAction => 'Создать набор восстановления';

  @override
  String get desktopAuthKitSaved => 'Набор сохранён. Теперь аккаунт можно вернуть.';

  @override
  String get desktopAuthContinue => 'Продолжить';

  @override
  String get desktopAuthKitOptionTitle => 'У меня есть набор восстановления';

  @override
  String get desktopAuthKitOptionBody => 'Самый простой путь: в наборе уже записан ваш Secretly ID.';

  @override
  String get desktopAuthKitPasteHint => 'Вставьте содержимое набора';

  @override
  String get desktopAuthServerOptionTitle => 'Копия на сервере';

  @override
  String get desktopAuthServerOptionBody => 'Понадобятся ваш Secretly ID и пароль копии.';

  @override
  String get desktopAuthRestoring => 'Восстанавливаем…';

  @override
  String desktopAuthRestoreFailed(Object error) {
    return 'Не удалось восстановить: $error';
  }

  @override
  String get desktopAuthBackupNotFound => 'Копии для этого Secretly ID на сервере нет.';

  @override
  String get desktopGeneralLaunchAtLogin => 'Запускать при входе в систему';

  @override
  String get desktopGeneralLaunchAtLoginOn => 'Secretly запустится сам и будет получать сообщения';

  @override
  String get desktopGeneralLaunchAtLoginOff => 'Пока Secretly не запущен, сообщения на этот компьютер не приходят';

  @override
  String get desktopGeneralLaunchNeedsApproval => 'Автозапуск выключен в системных настройках, в разделе «Объекты входа»';

  @override
  String get desktopA11yStatusSending => 'Отправляется';

  @override
  String get desktopA11yStatusScheduled => 'Запланировано';

  @override
  String get desktopA11yStatusSent => 'Отправлено';

  @override
  String get desktopA11yStatusDelivered => 'Доставлено';

  @override
  String get desktopA11yStatusRead => 'Прочитано';

  @override
  String get desktopA11yStatusFailed => 'Не отправлено';

  @override
  String get desktopA11yVoiceProgress => 'Воспроизведение голосового';

  @override
  String get desktopViewerPagePrev => 'Предыдущая страница';

  @override
  String get desktopViewerPageNext => 'Следующая страница';

  @override
  String get desktopReactionsMore => 'Больше эмодзи';

  @override
  String get desktopReactionsCollapse => 'Свернуть';

  @override
  String get desktopThreadScrollToBottom => 'К последним сообщениям';

  @override
  String get desktopViewerPrev => 'Предыдущее';

  @override
  String get desktopViewerNext => 'Следующее';

  @override
  String get desktopA11yPlay => 'Воспроизвести';

  @override
  String get desktopA11yPause => 'Пауза';

  @override
  String get desktopA11yAudioProgress => 'Воспроизведение';

  @override
  String get desktopPlayerClose => 'Закрыть плеер';

  @override
  String get desktopPlayerOpenSource => 'Перейти к сообщению';

  @override
  String desktopPlayerNowPlaying(String title) {
    return 'Сейчас играет: $title';
  }

  @override
  String get desktopPlayerPrevious => 'Предыдущий';

  @override
  String get desktopPlayerNext => 'Следующий';

  @override
  String get desktopPlayerMore => 'Ещё в этом чате';

  @override
  String get desktopPlayerSpeed => 'Скорость воспроизведения';

  @override
  String get desktopPlayerSpeedNormal => 'Обычная';

  @override
  String get desktopPlayerVolume => 'Громкость';

  @override
  String get desktopUpdateNow => 'Обновить';

  @override
  String desktopUpdateAvailable(String version) {
    return 'Доступна версия $version';
  }

  @override
  String get desktopCallExpand => 'Развернуть звонок';

  @override
  String get desktopCallMinimiseHint => 'Свернуть в мини-окно';

  @override
  String get desktopCallOpenChat => 'Свернуть звонок и открыть чат';

  @override
  String get desktopCallScreenShareFailed => 'Не удалось показать экран';

  @override
  String get desktopCallScreenShareFailedMac => 'Не удалось показать экран. Разрешите Secretly запись экрана: Системные настройки → Конфиденциальность и безопасность → Запись экрана';

  @override
  String get desktopCallMediaCameraUnavailable => 'Камера недоступна — её занимает другое приложение или не выдано разрешение в настройках системы';

  @override
  String get desktopCallMediaMicUnavailable => 'Микрофон недоступен — проверьте разрешение в настройках системы';

  @override
  String get desktopCallMediaScreenStopped => 'Показ экрана остановлен';

  @override
  String desktopCallMediaProblem(String detail) {
    return 'Сбой звука или видео: $detail';
  }

  @override
  String desktopCallEndedAfter(String duration) {
    return 'Звонок завершён · $duration';
  }

  @override
  String desktopCallDirectWith(String name) {
    return 'Идёт звонок · $name';
  }

  @override
  String get desktopCallLeaveFailed => 'Не удалось выйти из созвона: сервер не ответил. Попробуйте ещё раз.';

  @override
  String get desktopCallToggleFailed => 'Не удалось переключить: сервер не ответил. Попробуйте ещё раз.';

  @override
  String get desktopDiagTitle => 'Диагностика доставки';

  @override
  String get desktopDiagHint => 'На что смотреть, когда сообщения не идут, и что прислать нам';

  @override
  String get desktopDiagQueues => 'ОЧЕРЕДИ';

  @override
  String get desktopDiagOutbox => 'Ждут отправки';

  @override
  String get desktopDiagStuck => 'Застряли на входе';

  @override
  String get desktopDiagReceipts => 'Подтверждения в очереди';

  @override
  String get desktopDiagNothingStuck => 'Ничего не застряло';

  @override
  String get desktopDiagConditions => 'УСЛОВИЯ ДОСТАВКИ';

  @override
  String get desktopDiagClockOk => 'Часы компьютера сходятся с сервером';

  @override
  String desktopDiagClockSkew(Object delta) {
    return 'Часы компьютера сбиты на $delta — сервер может отказывать в приёме';
  }

  @override
  String get desktopDiagCopy => 'Скопировать для поддержки';

  @override
  String get desktopAppearanceTextSize => 'Размер текста';

  @override
  String get desktopAppearanceTextSizeHint => 'Действует на всё окно. Отступы и значки остаются как нарисованы';

  @override
  String get desktopThreadGoToDate => 'Перейти к дате';

  @override
  String get desktopHotkeyGlobalShow => 'Показывать Secretly откуда угодно';

  @override
  String get desktopHotkeyGlobalHint => 'По умолчанию выключено: сочетание общесистемное и отняло бы его у другой программы';

  @override
  String get desktopHotkeyGlobalTaken => 'Это сочетание уже занято другой программой';
}
