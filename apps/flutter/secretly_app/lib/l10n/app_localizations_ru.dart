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
  String get startupRetry => 'Повторить';

  @override
  String get onboardingBackupLater => 'Резервная копия пока не включена — профиль ещё создаётся. Включите её позже в Настройках.';

  @override
  String get keepMediaTitle => 'Хранить медиа на устройстве';

  @override
  String get keepMediaForever => 'Всегда';

  @override
  String get keepMediaMonth => '1 месяц';

  @override
  String get keepMediaWeek => '1 неделя';

  @override
  String get keepMediaHint => 'Скачанные фото, видео и файлы старше срока удаляются с телефона. Сообщения остаются; медиа, которого уже нет на сервере (старше 7 дней) и ваши отправленные, удалятся насовсем.';

  @override
  String get chatMediaTitle => 'Медиа по чатам';

  @override
  String get chatMediaShow => 'Посчитать по чатам';

  @override
  String chatMediaFilesCount(int count) {
    return '$count файлов';
  }

  @override
  String get chatMediaDeleteTitle => 'Удалить медиа чата?';

  @override
  String get chatMediaDeleteBody => 'Скачанные фото, видео и файлы этого чата удалятся с телефона, сообщения останутся. То, что ещё есть на сервере (до 7 дней), можно будет скачать снова; остальное — ваши отправленные и более старые — удалится насовсем.';

  @override
  String get chatMediaDeleteConfirm => 'Удалить';

  @override
  String get chatMediaEmpty => 'Скачанных медиа в чатах нет';

  @override
  String galleryShowMore(int count) {
    return 'Показать ещё (осталось $count)';
  }

  @override
  String get autoDownloadCellularTitle => 'Автозагрузка по мобильной сети';

  @override
  String get autoDownloadEverything => 'Всё';

  @override
  String get autoDownloadUpTo15Mb => 'Фото, видео и файлы до 15 МБ';

  @override
  String get autoDownloadPhotosOnly => 'Только фото';

  @override
  String get autoDownloadNothing => 'Ничего, кроме голосовых';

  @override
  String get autoDownloadHint => 'Через Wi-Fi скачивается всё. Отложенное скачается при подключении к Wi-Fi или когда вы его откроете. Файлы хранятся на сервере 7 дней.';

  @override
  String get uploadNotSentTapToRetry => 'Не отправлено — нажмите, чтобы повторить';

  @override
  String get uploadRetry => 'Повторить';

  @override
  String get attachmentExpiredOnServer => 'Файла больше нет на сервере: он хранится 7 дней.';

  @override
  String get attachmentServerRejectedSize => 'Файл слишком большой для сервера. Отправьте файл поменьше или разделите его.';

  @override
  String get attachmentServerStorageFull => 'На сервере сейчас мало места. Попробуйте позже.';

  @override
  String get attachmentUploadQuotaExceeded => 'Достигнут предел объёма файлов. Файлы хранятся 7 дней — попробуйте позже.';

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
  String get onboardingWelcomeSubtitle => 'Мессенджер нового поколения.\nПриватность по умолчанию.';

  @override
  String get onboardingCreateAccount => 'Создать новый аккаунт';

  @override
  String get onboardingAlreadyHaveAccount => 'Уже есть аккаунт';

  @override
  String get onboardingFeatureE2eTitle => 'Шифрование E2E';

  @override
  String get onboardingFeatureE2eBody => 'Сообщения шифруются на устройстве. Ключи — только у вас.';

  @override
  String get onboardingFeaturePrivacyTitle => 'Без личных данных';

  @override
  String get onboardingFeaturePrivacyBody => 'Без номера телефона. Без привязки к личным данным.';

  @override
  String get onboardingFeatureRelayTitle => 'Сервер не читает';

  @override
  String get onboardingFeatureRelayBody => 'Сервер только передаёт зашифрованные сообщения и удаляет их после доставки.';

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
  String get desktopRoomLimitTitle => 'Достигнут предел комнат';

  @override
  String desktopRoomLimitCreate(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Можно создать не больше $count комнаты.',
      many: 'Можно создать не больше $count комнат.',
      few: 'Можно создать не больше $count комнат.',
      one: 'Можно создать не больше $count комнаты.',
    );
    return '$_temp0';
  }

  @override
  String desktopRoomLimitJoin(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Можно состоять не больше чем в $count комнатах. Чтобы вступить в новую, выйдите из одной из прежних.',
      many: 'Можно состоять не больше чем в $count комнатах. Чтобы вступить в новую, выйдите из одной из прежних.',
      few: 'Можно состоять не больше чем в $count комнатах. Чтобы вступить в новую, выйдите из одной из прежних.',
      one: 'Можно состоять не больше чем в $count комнате. Чтобы вступить в новую, выйдите из одной из прежних.',
    );
    return '$_temp0';
  }

  @override
  String get desktopRoomLimitPremium => 'В Premium этот предел выше — подписка оформляется в приложении на телефоне.';

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
  String get desktopViewerPageFailed => 'Не удалось показать эту страницу';

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
  String desktopPairingHowTo(String settings, String devices, String button) {
    return 'На телефоне откройте Secretly → $settings → $devices → «$button» и отсканируйте этот QR-код.';
  }

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
  String get desktopRoomCallTransportEncrypted => 'Шифруется при передаче до нашего медиасервера — пока не сквозное';

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
  String get desktopGeneralDoubleClickReply => 'Ответ двойным щелчком';

  @override
  String get desktopGeneralDoubleClickReplyHint => 'Двойной щелчок по сообщению — ответить на него. По тексту — выделить слово';

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
  String get desktopNotifInSystem => 'В уведомлениях и окошках';

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
  String get desktopNotifWhileFocused => 'Когда окно открыто';

  @override
  String get desktopNotifWhileFocusedHint => 'Сообщения из других чатов — тоже уведомлением. Об открытом чате — никогда';

  @override
  String get desktopNotifOwnWindows => 'Уведомления как в Telegram';

  @override
  String get desktopNotifOwnWindowsHint => 'Свои окошки в углу экрана: не забирают фокус и ждут, пока над ними мышь. Выключено — системные уведомления Windows.';

  @override
  String get desktopNotifDnd => 'Не беспокоить';

  @override
  String get desktopNotifDndHint => 'Отключить все уведомления';

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
  String get desktopWallpaperMidnight => 'Ночной';

  @override
  String get desktopAppearanceHint => 'Схема этого окна. Телефон живёт со своей — эта настройка никуда не уезжает.';

  @override
  String get desktopAppearanceScheme => 'Схема';

  @override
  String get desktopAppearanceDark => 'Тёмная';

  @override
  String get desktopAppearanceLight => 'Светлая';

  @override
  String get desktopAppearanceAccent => 'Акцент интерфейса';

  @override
  String get desktopAppearanceAccentHint => 'Кнопки, свои пузыри и выделения во всём приложении.';

  @override
  String get desktopAppearanceWallpaper => 'Обои чата';

  @override
  String get desktopAppearanceWallPulse => 'Обои проводят сообщение';

  @override
  String get desktopAppearanceWallPulseHint => 'Волна света идёт по узору: вверх — когда отправляете, вниз — когда получаете.';

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
  String get desktopAppearanceTabTheme => 'Тема и текст';

  @override
  String get desktopAppearanceTabWallpaper => 'Фон чата';

  @override
  String get desktopAppearanceTabMessages => 'Сообщения';

  @override
  String get desktopAppearanceReset => 'По умолчанию';

  @override
  String get desktopAppearanceResetDone => 'Оформление вернулось к исходному';

  @override
  String get desktopAppearanceResetUndo => 'Вернуть';

  @override
  String get desktopAppearanceAutosave => 'Сохраняется автоматически';

  @override
  String get desktopAppearancePremiumOnly => 'Это — в Premium; подписка оформляется в приложении на телефоне';

  @override
  String get desktopAppearancePresets => 'Готовые наборы';

  @override
  String get desktopAppearancePresetsHint => 'Акцент, обои, пузыри и индикаторы — одним нажатием';

  @override
  String get desktopAppearancePresetClassic => 'Классика';

  @override
  String get desktopAppearancePresetOcean => 'Океан';

  @override
  String get desktopAppearancePresetSunset => 'Закат';

  @override
  String get desktopAppearancePresetForest => 'Лес';

  @override
  String get desktopAppearancePresetNight => 'Ночь';

  @override
  String get desktopAppearanceSystem => 'Системная';

  @override
  String get desktopAppearanceDensity => 'Плотность сообщений';

  @override
  String get desktopAppearanceDensityCozy => 'Уютная';

  @override
  String get desktopAppearanceDensityCompact => 'Компактная';

  @override
  String get desktopAppearanceWallpaperAllChats => 'Фон для всех бесед. Живые — с мягким переливом';

  @override
  String get desktopAppearanceStatic => 'Статичные';

  @override
  String get desktopAppearanceLive => 'Живые';

  @override
  String get desktopAppearanceLiveBadge => 'LIVE';

  @override
  String get desktopAppearanceDim => 'Затемнение';

  @override
  String get desktopAppearanceAnimPattern => 'Анимация узора';

  @override
  String get desktopAppearanceLiveOnlyBadge => 'только для живых обоев';

  @override
  String get desktopWallAnimShortContinuous => 'Постоянно';

  @override
  String get desktopWallAnimShortOnEnter => 'При открытии';

  @override
  String get desktopWallAnimShortTap => 'По клику';

  @override
  String get desktopWallAnimShortOff => 'Выкл.';

  @override
  String desktopAppearanceGoLive(Object link) {
    return 'Выберите $link, чтобы настроить анимацию.';
  }

  @override
  String get desktopAppearanceGoLiveLink => 'живые обои';

  @override
  String get desktopAppearanceShape => 'Форма';

  @override
  String get desktopAppearanceShapeSharp => 'Острые';

  @override
  String get desktopAppearanceShapeMedium => 'Средние';

  @override
  String get desktopAppearanceShapeRound => 'Круглые';

  @override
  String get desktopAppearanceNamesMulti => 'Разноцветные';

  @override
  String get desktopAppearanceIndicatorHint => 'Галочки прочтения в списке чатов, ссылки и выделение текста';

  @override
  String get desktopAppearanceSummaryPrefix => 'Сейчас:';

  @override
  String get desktopAppearanceSummaryDark => 'тёмная схема';

  @override
  String get desktopAppearanceSummaryLight => 'светлая схема';

  @override
  String get desktopAppearanceSummarySystem => 'системная схема';

  @override
  String desktopAppearanceSummaryBubbles(Object name) {
    return 'пузыри «$name»';
  }

  @override
  String desktopAppearanceSummaryText(Object size) {
    return 'текст $size';
  }

  @override
  String get desktopAppearancePreview => 'Предпросмотр';

  @override
  String get desktopAppearancePreviewReplay => 'Переоткрыть';

  @override
  String get desktopAppearancePreviewReplayHint => 'Переоткрыть чат, чтобы увидеть анимацию';

  @override
  String get desktopAppearancePreviewIncoming => 'Входящее';

  @override
  String get desktopAppearancePreviewIncomingHint => 'Получить сообщение';

  @override
  String get desktopAppearancePreviewChat => 'Дизайн-команда';

  @override
  String get desktopAppearancePreviewMembers => '5 участников, 3 в сети';

  @override
  String desktopAppearancePreviewTyping(Object name) {
    return '$name печатает…';
  }

  @override
  String get desktopAppearancePreviewAnna => 'Аня';

  @override
  String get desktopAppearancePreviewMax => 'Максим';

  @override
  String get desktopAppearancePreviewLiza => 'Лиза';

  @override
  String get desktopAppearancePreviewMsg1 => 'Обновила обои в нашем чате — оцените';

  @override
  String get desktopAppearancePreviewMsg2 => 'Живые прям огонь. Особенно волна, когда пишешь';

  @override
  String get desktopAppearancePreviewMsg3 => 'Сейчас попробую поставить такие же';

  @override
  String get desktopAppearancePreviewMsg4 => 'А размер текста тоже можно поменять?';

  @override
  String get desktopAppearancePreviewMsg5 => 'Да, во «Внешнем виде». Подробнее — на www.secretlyapp.com';

  @override
  String get desktopAppearancePreviewOwnDefault => 'Проверяю, как смотрятся новые настройки';

  @override
  String get desktopAppearancePreviewReply1 => 'Выглядит отлично!';

  @override
  String get desktopAppearancePreviewReply2 => 'О, так гораздо лучше';

  @override
  String get desktopAppearancePreviewReply3 => 'Скинь потом, какие обои выбрал';

  @override
  String get desktopAppearancePreviewReply4 => 'Этот цвет пузырей тебе идёт';

  @override
  String get desktopAppearancePreviewReply5 => 'Ставлю себе такие же';

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
  String get desktopPrivacyEncryptionHint => 'Сообщения, файлы и звонки один на один защищены сквозным шифрованием; ключи — только на ваших устройствах. Сквозное шифрование групповых звонков включается постепенно: замок в звонке показывает, что оно работает, а без него звонок шифруется только при передаче.';

  @override
  String get desktopPrivacyE2eeActive => 'Сквозное шифрование активно';

  @override
  String get desktopPrivacyWhoSees => 'Кто видит';

  @override
  String get desktopPrivacyWhoSeesHint => 'Те же настройки видимости, что и в телефоне. «Контакты» соблюдает приложение; сервер гарантирует только «Никто».';

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
  String get desktopPrivacyAutoDeleteHint => 'Если вы не заходите дольше выбранного срока, с наших серверов удаляются аккаунт, ключи, серверная копия и очереди сообщений. Отсчёт сбрасывается при каждом входе.';

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
  String get desktopAboutTagline => 'Мессенджер со сквозным шифрованием. Без рекламы. Исходный код — AGPL-3.0.';

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
  String get desktopSecurityE2eeHint => 'Сообщения, файлы и звонки один на один шифруются на вашем устройстве, ключи не покидают ваши устройства. Сервер не читает содержимое, но видит служебные данные — например, кто кому пишет и когда. Сквозное шифрование групповых звонков включается постепенно: замок в звонке показывает, что оно работает, а без него звонок шифруется только при передаче.';

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
  String get desktopMuteMenu => 'Без звука…';

  @override
  String get desktopMuteFor1h => 'На 1 час';

  @override
  String get desktopMuteFor8h => 'На 8 часов';

  @override
  String get desktopMuteFor2d => 'На 2 дня';

  @override
  String get desktopMuteForever => 'Пока не включу';

  @override
  String get desktopMuteMentionsOnly => 'Только упоминания';

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
  String get desktopRoomDeleteLeaveMenu => 'Удалить и покинуть';

  @override
  String desktopRoomDeleteLeaveTitle(String title) {
    return 'Удалить и покинуть «$title»?';
  }

  @override
  String get desktopRoomDeleteLeaveBody => 'Вы выйдете из комнаты и перестанете получать её сообщения, а переписка удалится с этого компьютера. Вернуться можно только по новому приглашению.';

  @override
  String get desktopRoomDeleteLeaveAction => 'Выйти и удалить';

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
  String get desktopFileRiskTitle => 'Открыть этот файл?';

  @override
  String desktopFileRiskExtension(Object ext) {
    return 'У файла расширение $ext: такой файл может запустить программу и навредить компьютеру. Открывайте его, только если доверяете отправителю.';
  }

  @override
  String get desktopFileRiskNoExtension => 'У файла нет расширения: компьютер может запустить его как программу. Открывайте его, только если доверяете отправителю.';

  @override
  String desktopFileRiskMismatch(Object ext) {
    return 'Отправитель выдал этот файл за снимок, звук, видео или PDF, но на деле у него расширение $ext. Так маскируют опасные файлы — открывайте его, только если доверяете отправителю.';
  }

  @override
  String get desktopFileRiskShowInFolder => 'Показать в папке';

  @override
  String get desktopFileRiskOpenAnyway => 'Всё равно открыть';

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
  String get desktopRoomInviteCardTitle => 'Приглашение в комнату';

  @override
  String get desktopRoomInviteCardHint => 'Откройте карточку, чтобы посмотреть комнату и вступить.';

  @override
  String get desktopRoomInviteAlreadyMember => 'Вы уже в комнате';

  @override
  String get desktopRoomInviteApprovalRequired => 'Вход по одобрению';

  @override
  String get desktopRoomInviteDirectJoin => 'Вход сразу';

  @override
  String get desktopRoomInviteWithHistory => 'с историей';

  @override
  String get desktopRoomInviteWithoutHistory => 'без истории';

  @override
  String desktopRoomInviteInvitedBy(String name) {
    return 'Приглашает: $name';
  }

  @override
  String get desktopRoomInviteHistoryOn => 'История для новых участников включена';

  @override
  String get desktopRoomInviteHistoryOff => 'История для новых участников отключена';

  @override
  String get desktopRoomInviteJoin => 'Вступить';

  @override
  String get desktopRoomInviteRequestAccess => 'Запросить доступ';

  @override
  String get desktopRoomInviteOpenRequest => 'Открыть заявку';

  @override
  String get desktopRoomInviteOpenRoom => 'Открыть комнату';

  @override
  String desktopRoomInviteReplyQuote(String title) {
    return 'Приглашение в «$title»';
  }

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
  String get desktopRoomShowAllMembers => 'Показать всех';

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
  String get desktopContactDisappearing => 'Автоудаление на моих устройствах';

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
  String get desktopThreadDisappearingOn => 'Автоудаление включено — только на моих устройствах';

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
  String get desktopProfileEmojiStatusPremiumOnly => 'Эмодзи-статус — в Premium; подписка оформляется в приложении на телефоне';

  @override
  String get desktopProfileCosmeticPremiumOnly => 'Эта рамка или обложка — в Premium; подписка оформляется в приложении на телефоне';

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
  String get desktopAvatarOpen => 'Открыть фото';

  @override
  String get desktopAvatarCropTitle => 'Кадрировать фото';

  @override
  String get desktopAvatarCropHint => 'Перетащите снимок; колёсико мыши — масштаб';

  @override
  String get desktopAvatarRemoveConfirmTitle => 'Удалить фото?';

  @override
  String get desktopAvatarRemoveConfirmBody => 'Вместо фото будут буквы имени.';

  @override
  String get desktopAvatarRemoveOnPhone => 'Удалить можно на телефоне';

  @override
  String get desktopRoomPhotoUpdated => 'Фото группы обновлено';

  @override
  String get desktopRoomPhotoRemoved => 'Фото группы удалено';

  @override
  String desktopRoomPhotoFailed(String error) {
    return 'Не удалось изменить фото группы: $error';
  }

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
  String get desktopGalleryLoadFailed => 'Не удалось загрузить вложения';

  @override
  String get desktopGalleryRetry => 'Повторить';

  @override
  String get desktopSendMediaDroppedOnSwitch => 'Файлы не отправлены — окно отправки закрылось при смене чата.';

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
  String get desktopComposerVoiceUnsupported => 'Записывать голосовые на этом компьютере не получится.';

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
  String get desktopShortcutsUnread => 'Предыдущий / следующий непрочитанный';

  @override
  String get desktopShortcutsFolders => 'Предыдущая / следующая папка';

  @override
  String get desktopShortcutsMute => 'Выключить / включить звук чата';

  @override
  String get desktopShortcutsCloseChat => 'Закрыть панель, затем чат';

  @override
  String get desktopChatMutedToast => 'Звук чата выключен';

  @override
  String get desktopChatUnmutedToast => 'Звук чата включён';

  @override
  String get desktopChatsFolderReadAll => 'Прочитать все';

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
  String get desktopCallPinWindow => 'Поверх всех окон';

  @override
  String get desktopCallUnpinWindow => 'Не держать поверх окон';

  @override
  String get desktopCallsOwnWindow => 'Звонок в отдельном окне';

  @override
  String get desktopCallsOwnWindowHint => 'Звонок открывается своим окном: его можно увести на другой экран или закрепить поверх других программ.';

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
  String get desktopRoomClearForAll => 'И у всех участников комнаты';

  @override
  String get desktopRoomClearForAllHint => 'Сообщения исчезнут и у остальных. Отменить нельзя.';

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
  String get desktopStartupFailedTitle => 'Не удалось запустить Secretly';

  @override
  String get desktopStartupFailedBody => 'Попробуйте ещё раз. Если ошибка повторится, причину подскажет журнал запуска.';

  @override
  String get desktopStartupSlowTitle => 'Запуск идёт дольше обычного';

  @override
  String get desktopStartupSlowBody => 'Можно подождать ещё или начать запуск заново.';

  @override
  String get desktopStartupRetry => 'Повторить';

  @override
  String get desktopStartupOpenLogs => 'Открыть папку журнала';

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
  String desktopUpdateDownloading(int percent) {
    return 'Загрузка $percent%';
  }

  @override
  String get desktopUpdateVerifying => 'Проверка…';

  @override
  String get desktopUpdateInstalling => 'Установка…';

  @override
  String get desktopUpdateManual => 'Скачать с сайта';

  @override
  String get desktopUpdateFailedHint => 'Не удалось обновиться автоматически. Установщик есть на сайте.';

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
  String get desktopCallRemoveParticipant => 'Убрать из созвона';

  @override
  String desktopCallRemoveParticipantTitle(String name) {
    return 'Убрать $name из созвона?';
  }

  @override
  String get desktopCallRemoveParticipantBody => 'Человек выйдет из созвона. Вернуться он сможет, присоединившись снова.';

  @override
  String get desktopCallRemoveFailed => 'Не удалось убрать из созвона';

  @override
  String get desktopCallLeaveTitle => 'Выйти из созвона?';

  @override
  String get desktopCallEndForAll => 'Завершить созвон для всех';

  @override
  String get desktopCallEndForAllHint => 'Остальные участники тоже выйдут из созвона.';

  @override
  String get desktopCallEndForAllFailed => 'Не удалось завершить созвон для всех';

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
  String get desktopThreadGoToDate => 'Перейти к дате';

  @override
  String get desktopHotkeyGlobalShow => 'Показывать Secretly откуда угодно';

  @override
  String get desktopHotkeyGlobalHint => 'По умолчанию выключено: сочетание общесистемное и отняло бы его у другой программы';

  @override
  String get desktopHotkeyGlobalTaken => 'Это сочетание уже занято другой программой';

  @override
  String get desktopTrayOpen => 'Открыть Secretly';

  @override
  String desktopTrayUnread(int count) {
    return 'Непрочитанных: $count';
  }

  @override
  String get desktopTrayMute => 'Без звука';

  @override
  String get desktopTrayMuteHour => 'На 1 час';

  @override
  String get desktopTrayMuteEightHours => 'На 8 часов';

  @override
  String get desktopTrayMuteForever => 'Пока не включу';

  @override
  String get desktopTrayUnmute => 'Включить уведомления';

  @override
  String desktopTrayMutedUntil(String time) {
    return 'Без звука до $time';
  }

  @override
  String get desktopTrayQuit => 'Выйти из Secretly';

  @override
  String get desktopTrayHintTitle => 'Secretly работает в фоне';

  @override
  String get desktopTrayHintBody => 'Сообщения и звонки будут приходить. Значок — у часов: закрепите его, чтобы он всегда был на виду.';

  @override
  String get desktopDevicesMicrophone => 'Микрофон';

  @override
  String get desktopDevicesSpeakers => 'Динамики и наушники';

  @override
  String get desktopDevicesNoSpeakers => 'Динамики и наушники не найдены';

  @override
  String get desktopDevicesCamera => 'Камера';

  @override
  String get desktopCallsSystemTitle => 'Система';

  @override
  String get desktopCallsSystemSound => 'Настройки звука системы';

  @override
  String get desktopCallsSystemSoundHint => 'Громкость, устройство по умолчанию и доступ к микрофону';

  @override
  String get desktopCallsOpenSystem => 'Открыть';

  @override
  String get desktopMicLevel => 'Уровень микрофона';

  @override
  String get desktopMicLevelHint => 'Скажите что-нибудь — полоска должна двигаться. Микрофон включён, только пока открыт этот раздел, и звук никуда не уходит.';

  @override
  String get desktopMicNeedsAccess => 'Приложению ещё не разрешили пользоваться микрофоном.';

  @override
  String get desktopMicAllow => 'Разрешить';

  @override
  String get desktopMicNoAccess => 'Нет доступа к микрофону. Разрешите его в настройках системы.';

  @override
  String get desktopMicOpenFailed => 'Не удалось открыть микрофон. Возможно, он занят другой программой или к нему закрыт доступ.';

  @override
  String get desktopMicSystemFallback => 'Выбранный микрофон не удалось открыть для проверки — показываем микрофон системы.';

  @override
  String get desktopMediaOpenPrivacy => 'Открыть настройки';

  @override
  String get desktopMicTest => 'Проверить микрофон';

  @override
  String get desktopMicTestHint => 'Запишем 5 секунд и сразу проиграем в выбранных динамиках.';

  @override
  String get desktopMediaCheck => 'Проверить';

  @override
  String get desktopMediaCheckStop => 'Остановить';

  @override
  String desktopMicTestRecording(int seconds) {
    return 'Идёт запись — говорите… $seconds с';
  }

  @override
  String get desktopMicTestPlaying => 'Проигрываем запись…';

  @override
  String get desktopMediaPlaybackFailed => 'Не удалось проиграть звук.';

  @override
  String get desktopMediaPlaybackSystemOnly => 'Прозвучало в устройстве системы по умолчанию: выбранное открыть для проверки не удалось.';

  @override
  String get desktopMediaBusyInCall => 'Идёт звонок — проверки выключены, чтобы не мешать разговору.';

  @override
  String get desktopSpeakerTest => 'Проверить динамики';

  @override
  String get desktopSpeakerTestHint => 'Короткий сигнал в выбранном устройстве.';

  @override
  String get desktopSpeakerTestPlaying => 'Звучит…';

  @override
  String get desktopCameraPreview => 'Проверить камеру';

  @override
  String get desktopCameraPreviewHint => 'Камера включается, только пока показано превью.';

  @override
  String get desktopCameraPreviewShow => 'Показать';

  @override
  String get desktopCameraPreviewHide => 'Скрыть';

  @override
  String get desktopCameraPreviewFailed => 'Не удалось включить камеру. Возможно, она занята другой программой или к ней закрыт доступ.';

  @override
  String get desktopCameraMirror => 'Зеркалить моё видео';

  @override
  String get desktopCameraMirrorHint => 'Только у вас на экране — как в зеркале. Собеседники видят вас как обычно.';

  @override
  String get desktopRingtoneTitle => 'Мелодия звонка';

  @override
  String get desktopRingtoneVolume => 'Громкость';

  @override
  String get desktopRingtoneVolumeHint => 'Насколько громко звучит входящий звонок на этом компьютере.';

  @override
  String get desktopRingtoneListen => 'Послушать';

  @override
  String get desktopRingtoneSilent => 'Без звука — о звонке скажет только окно.';

  @override
  String get desktopRoomEditTitle => 'Изменить группу';

  @override
  String get desktopRoomEditName => 'Название';

  @override
  String get desktopRoomEditNameHint => 'Название группы';

  @override
  String get desktopRoomEditNameEmpty => 'Введите название';

  @override
  String get desktopRoomEditDescription => 'Описание';

  @override
  String get desktopRoomEditDescriptionHint => 'О чём эта группа';

  @override
  String get desktopRoomEditPhotoChoose => 'Выбрать фото…';

  @override
  String get desktopRoomEditPhotoRemove => 'Удалить фото';

  @override
  String get desktopRoomEditSaved => 'Группа обновлена';

  @override
  String get desktopRoomPermissionsMenu => 'Разрешения';

  @override
  String get desktopRoomPermissionsTitle => 'Разрешения участников';

  @override
  String get desktopRoomPermissionsSaved => 'Разрешения сохранены';

  @override
  String get desktopRoomPermMembersSection => 'Что могут участники';

  @override
  String get desktopRoomPermSendText => 'Писать сообщения';

  @override
  String get desktopRoomPermSendMedia => 'Отправлять фото, видео и файлы';

  @override
  String get desktopRoomPermPin => 'Закреплять сообщения';

  @override
  String get desktopRoomPermAddMembers => 'Добавлять участников';

  @override
  String get desktopRoomAddMembers => 'Добавить участников';

  @override
  String get desktopRoomAddMembersSearch => 'Имя или Secretly ID';

  @override
  String get desktopRoomAddMembersAlready => 'Уже в комнате';

  @override
  String get desktopRoomAddMembersNone => 'Никого не нашлось';

  @override
  String get desktopRoomAddMembersNoContacts => 'Контактов пока нет. Пригласите людей ссылкой.';

  @override
  String desktopRoomAddMembersAction(int count) {
    return 'Добавить: $count';
  }

  @override
  String desktopRoomMembersAdded(int count) {
    return 'Добавлено участников: $count';
  }

  @override
  String get desktopRoomInviteLinksMenu => 'Ссылки-приглашения';

  @override
  String get desktopRoomAuditLog => 'Недавние действия';

  @override
  String get desktopRoomAuditLogEmpty => 'Пока ничего не происходило';

  @override
  String get desktopRoomAuditLogHint => 'Вступления, выходы, роли и настройки — как их видел этот компьютер.';

  @override
  String get desktopRoomPermChangeInfo => 'Менять название, фото и описание';

  @override
  String get desktopRoomPermChangeTag => 'Менять свою метку';

  @override
  String get desktopRoomPermJoinSection => 'Вступление';

  @override
  String get desktopRoomPermApproval => 'Вступление только после одобрения';

  @override
  String get desktopRoomPermHistory => 'История для новых участников';

  @override
  String get desktopRoomPermHistoryHint => 'Новые участники видят сообщения, отправленные до них';

  @override
  String get desktopRoomPermReactions => 'Реакции';

  @override
  String get desktopRoomReactionsAll => 'Все';

  @override
  String get desktopRoomReactionsSome => 'Избранные';

  @override
  String get desktopRoomReactionsNone => 'Никаких';

  @override
  String get desktopRoomPermSlowMode => 'Медленный режим';

  @override
  String get desktopRoomPermSlowModeHint => 'Как часто каждый участник может отправлять сообщение';

  @override
  String get desktopRoomSlowOff => 'Выкл.';

  @override
  String desktopRoomSlowSeconds(int count) {
    return '$count с';
  }

  @override
  String desktopRoomSlowMinutes(int count) {
    return '$count мин';
  }

  @override
  String desktopRoomSlowHours(int count) {
    return '$count ч';
  }

  @override
  String get desktopRoomDelete => 'Удалить группу';

  @override
  String get desktopRoomDeleteTitle => 'Удалить группу для всех?';

  @override
  String desktopRoomDeleteBody(String title) {
    return '«$title» исчезнет у всех участников вместе с перепиской. Это нельзя отменить.';
  }

  @override
  String get desktopRoomDeleted => 'Группа удалена';

  @override
  String get desktopRoomOwnerLeaveTitle => 'Вы владелец группы';

  @override
  String get desktopRoomOwnerLeaveBody => 'Перед выходом передайте группу другому участнику — или удалите её для всех.';

  @override
  String get desktopRoomOwnerLeaveNoMembers => 'В группе больше никого нет — её можно только удалить.';

  @override
  String get desktopRoomOwnerLeaveTransfer => 'Передать и выйти';

  @override
  String get desktopComposerSendHintShift => 'Отправить · Shift+Enter\nПравая кнопка — отправить позже';

  @override
  String get desktopWallpaperUseDefault => 'Как в настройках';

  @override
  String get desktopWallpaperClassic => 'Классика';

  @override
  String get desktopWallpaperStandard => 'Стандартные';

  @override
  String desktopWallpaperProfilePhoto(int n) {
    return 'Фото $n';
  }

  @override
  String get desktopChatWallpaperTitle => 'Обои чата';

  @override
  String get desktopChatWallpaperMenu => 'Обои чата…';

  @override
  String get desktopChatWallpaperSaved => 'Обои этого чата сохранены';

  @override
  String get desktopWallpaperPremiumOnly => 'Эти обои — в Premium; подписка оформляется в приложении на телефоне';

  @override
  String get desktopGeneralStartMinimized => 'Запускать свёрнутым';

  @override
  String get desktopGeneralStartMinimizedHint => 'При входе в систему окно не открывается — Secretly ждёт в трее';

  @override
  String get desktopGeneralCloseToTray => 'Закрывать в трей';

  @override
  String get desktopGeneralCloseToTrayOn => 'Крестик прячет окно — сообщения и звонки продолжают приходить';

  @override
  String get desktopGeneralCloseToTrayOff => 'Крестик закрывает Secretly — ничего не придёт, пока не откроете снова';

  @override
  String get desktopGeneralLaunchNeedsApprovalWindows => 'Автозапуск выключен в «Диспетчере задач» → «Автозагрузка» — включите Secretly там';

  @override
  String get desktopSupportAttachLog => 'Приложить журнал';

  @override
  String get desktopSupportLogEmpty => 'Журнал пока пуст';

  @override
  String get desktopDevicesAddComputerTitle => 'Ещё один компьютер';

  @override
  String get desktopDevicesAddComputerHint => 'Компьютер подключают с телефона. Установите Secretly на другой компьютер и выберите там «Войти через телефон», затем на телефоне откройте Настройки → Устройства → «Подключить устройство» и отсканируйте QR-код с экрана того компьютера.';

  @override
  String get desktopSettingsSignOutBodyOnlyDevice => 'Этот компьютер — единственное устройство с этим аккаунтом. После выхода аккаунт можно вернуть только набором восстановления — без него его не вернёт никто, включая нас. Сначала убедитесь, что набор сохранён.';

  @override
  String get desktopSettingsSignOutBodyUnknown => 'С этого компьютера будут удалены переписка, ключи и кэш. Если аккаунт есть и на другом устройстве, там он останется. Если этот компьютер — его единственное устройство, вернуть аккаунт можно будет только набором восстановления.';

  @override
  String desktopPairingRetryIn(Object seconds) {
    return 'Следующая попытка через $seconds с';
  }

  @override
  String get desktopKitReadyTitle => 'Набор восстановления готов';

  @override
  String get desktopKitReadyBody => 'Храните его вне этого компьютера — на флешке, в менеджере паролей или на бумаге. Набор вместе с паролем открывает аккаунт, поэтому держите их раздельно.';

  @override
  String get desktopKitSaveToFile => 'Сохранить в файл…';

  @override
  String get desktopKitSaveDialogTitle => 'Сохранить набор восстановления';

  @override
  String desktopKitSavedTo(Object path) {
    return 'Сохранено в файл: $path';
  }

  @override
  String desktopKitSaveFailed(Object error) {
    return 'Не удалось сохранить файл: $error';
  }

  @override
  String get desktopKitShowQr => 'Показать QR-код и текст';

  @override
  String get desktopKitSavedElsewhere => 'Сохранено другим способом';

  @override
  String get desktopKitConfirmTitle => 'Набор точно сохранён?';

  @override
  String get desktopKitConfirmBody => 'Подтверждайте, только если вы скопировали текст набора или сфотографировали его QR-код и убрали в надёжное место вне этого компьютера. Без набора аккаунт не восстановить.';

  @override
  String get desktopKitConfirmYes => 'Да, сохранён';

  @override
  String get desktopAuthKitConfirmed => 'Вы подтвердили, что набор хранится в надёжном месте. По нему аккаунт можно вернуть.';

  @override
  String get desktopAboutSourceCode => 'Исходный код';

  @override
  String desktopAboutLicenseLine(Object url) {
    return 'Лицензия: GNU AGPL-3.0. Исходный код: $url';
  }

  @override
  String get desktopProfileLinkTitle => 'Открыть этот чат?';

  @override
  String desktopProfileLinkBody(String name, String id) {
    return 'Ссылка ведёт в переписку. Собеседник: $name ($id).';
  }

  @override
  String desktopProfileLinkBodyUnknown(String id) {
    return 'Ссылка ведёт в переписку с профилем $id.';
  }

  @override
  String get desktopProfileLinkOpen => 'Открыть чат';

  @override
  String desktopUpdateAttemptFailed(String reason) {
    return 'Обновление не установилось: $reason';
  }

  @override
  String get desktopUpdateFailureDownload => 'файл не скачался';

  @override
  String get desktopUpdateFailureVerification => 'скачанный файл не прошёл проверку и удалён, не запускаясь';

  @override
  String get desktopUpdateFailureLaunch => 'установщик не запустился';

  @override
  String get desktopUpdateFailureNotInstalled => 'после установщика работает прежняя версия';

  @override
  String get desktopUpdateRetry => 'Повторить';

  @override
  String get desktopRestoreTakeOverTitle => 'Компьютер станет устройством, сделавшим копию';

  @override
  String get desktopRestoreTakeOverBody => 'Копию сделало другое устройство — например, ваш телефон. После восстановления компьютер займёт его место. Если то устройство ещё работает, сообщения будут приходить только на одно из двух, а второе может перестать расшифровывать чаты или потерять связь с сервером. Восстанавливайте так, только если того устройства больше нет. Чтобы пользоваться компьютером вместе с телефоном, вернитесь назад и привяжите компьютер по QR-коду.';

  @override
  String get desktopRestoreTakeOverConfirm => 'Всё равно восстановить';

  @override
  String get desktopServerBackupReplaceTitle => 'Заменить копию на сервере?';

  @override
  String get desktopServerBackupReplaceBody => 'На сервере хранится одна копия на аккаунт. Копия с этого компьютера заменит ту, что сделал телефон или другое ваше устройство, и прежнюю вернуть будет нельзя. В неё войдёт только история, которая есть на этом компьютере.';

  @override
  String get desktopServerBackupReplaceConfirm => 'Заменить';

  @override
  String get desktopBackupAutoPasswordMissing => 'не задан пароль копии';

  @override
  String get desktopBackupAutoPasswordWeak => 'пароль копии больше не отвечает требованиям';

  @override
  String get desktopBackupSetPassword => 'Задать пароль копии';

  @override
  String get desktopSupportLogConfirmTitle => 'Приложить журнал?';

  @override
  String desktopSupportLogConfirmBody(String size) {
    return '$size служебных записей программы за последнее время. Посмотрите, что в них, прежде чем прикладывать: журнал уйдёт в поддержку вместе с письмом.';
  }

  @override
  String get desktopSupportLogView => 'Посмотреть';

  @override
  String get desktopSupportLogAttachConfirm => 'Приложить';

  @override
  String get desktopSupportLogViewTitle => 'Что в журнале';

  @override
  String get desktopDevicesEndNotConfirmed => 'сервер этого не подтвердил. Попробуйте позже.';

  @override
  String get desktopPrivacyScreenCaptureTitle => 'Защита от снимков экрана';

  @override
  String get desktopPrivacyScreenCaptureSwitch => 'Скрывать окна Secretly от снимков и записи экрана';

  @override
  String get desktopPrivacyScreenCaptureHint => 'Снимки, запись и демонстрация экрана — в том числе ваша собственная демонстрация в звонке — не покажут содержимое окон Secretly. Сфотографировать экран это не мешает, а некоторые программы захвата и версии системы могут эту просьбу не соблюдать.';

  @override
  String get desktopPrivacyScreenCaptureFailed => 'Система не приняла защиту от снимков экрана.';

  @override
  String get desktopSoundMessagesTitle => 'Звук сообщений';

  @override
  String get desktopSoundMessagesHint => 'Звучит вместе с уведомлением о сообщении на этом компьютере.';

  @override
  String get desktopSoundMutedNote => 'Звук уведомлений выключен выше — выбранный звук не прозвучит.';

  @override
  String get desktopSoundInChatTitle => 'Звук в открытом чате';

  @override
  String get desktopSoundInChatSwitch => 'Новые сообщения в открытом чате';

  @override
  String get desktopSoundInChatHint => 'Тихий звук вместо уведомления, пока чат открыт в активном окне.';

  @override
  String get desktopSoundNameBubble => 'Пузырёк';

  @override
  String get desktopSoundNameBubbles => 'Пузыри';

  @override
  String get desktopSoundNameDrip => 'Капель';

  @override
  String get desktopSoundNamePing => 'Пинг';

  @override
  String get desktopSoundNameSplash => 'Всплеск';

  @override
  String get desktopSoundNameDrop => 'Капля';

  @override
  String get desktopSoundNameTone => 'Тон';

  @override
  String get desktopSoundNameKey => 'Клавиша';

  @override
  String get desktopSoundNameClick => 'Щелчок';

  @override
  String get desktopSoundNameSwitch => 'Тумблер';

  @override
  String get desktopSoundNameMelody => 'Мелодия';

  @override
  String get desktopSoundNamePulse => 'Пульс';

  @override
  String get desktopSoundNameDefault => 'По умолчанию';

  @override
  String get roomCallE2eeOn => 'Сквозное шифрование';

  @override
  String get roomCallE2eeOnHint => 'Звук, видео и экран видят только участники — наш сервер не видит.';

  @override
  String get roomCallE2eeConnecting => 'Подключаем шифрование…';

  @override
  String get roomCallE2eeFailed => 'Не удалось включить шифрование. С этого устройства войти нельзя.';

  @override
  String get roomCallE2eeUnsupported => 'Защищённые созвоны пока недоступны на этом устройстве.';

  @override
  String get roomCallE2eeWaitingKey => 'Ждём ключ';

  @override
  String get roomCallE2eeFailing => 'Не удаётся расшифровать — возможно, старая версия';

  @override
  String roomCallE2eeUnknownParticipants(int count) {
    return 'Неизвестных участников не слышно: $count';
  }

  @override
  String get roomCallOpenBanner => 'Без сквозного шифрования — сервер может видеть и слышать созвон';

  @override
  String get roomCallJoinOpenTitle => 'Войти в созвон без шифрования?';

  @override
  String get roomCallJoinOpenBody => 'Этот созвон без сквозного шифрования: его начали в старой версии Secretly. Сервер может видеть и слышать его.';

  @override
  String get roomCallJoinOpenAction => 'Всё равно войти';

  @override
  String get roomCallStartChoiceTitle => 'Начать защищённый созвон?';

  @override
  String roomCallStartChoiceBody(String names) {
    return 'Старая версия Secretly — не смогут войти: $names.';
  }

  @override
  String get roomCallStartChoiceNotify => 'Написать в чат, что нужно обновиться';

  @override
  String get roomCallStartEncrypted => 'Начать защищённый';

  @override
  String get roomCallStartOpen => 'Начать без шифрования';

  @override
  String get roomCallUpdateNotice => 'Идёт защищённый созвон. Чтобы войти, обновите Secretly.';

  @override
  String get roomCallE2eeScreenShareIos => 'Показ экрана с iPhone в защищённом созвоне пока недоступен';

  @override
  String get roomCallFull => 'В защищённом созвоне нет мест';

  @override
  String get roomPrivateTopicNew => 'Новая тема';

  @override
  String get roomPrivateTopicOpen => 'Открытая';

  @override
  String get roomPrivateTopicOpenHint => 'Видят все участники комнаты';

  @override
  String get roomPrivateTopicClosed => 'Закрытая';

  @override
  String get roomPrivateTopicClosedHint => 'Только приглашённые. Остальные не узнают о ней';

  @override
  String get roomPrivateTopicTitleHint => 'Название темы';

  @override
  String get roomPrivateTopicMembers => 'Кого пригласить';

  @override
  String get roomPrivateTopicOnlyYou => 'Пока только вы — людей можно добавить потом';

  @override
  String get roomPrivateTopicCreate => 'Создать';

  @override
  String get roomPrivateTopicFailed => 'Не удалось создать закрытую тему';

  @override
  String roomPrivateTopicLimit(int count) {
    return 'Достигнут предел закрытых тем: $count';
  }

  @override
  String get roomPrivateTopicLabel => 'Закрытая тема';

  @override
  String roomPrivateTopicInRoom(String room) {
    return 'Закрытая тема · $room';
  }

  @override
  String get roomPrivateTopicAllowMembers => 'Создавать закрытые темы';

  @override
  String get spaceGateEnterCode => 'Введите код';

  @override
  String get spaceGateWrongCode => 'Код не подходит. Попробуйте ещё раз.';

  @override
  String spaceGateWaitSeconds(int seconds) {
    return 'Подождите $seconds с';
  }

  @override
  String get spaceGateUnlock => 'Открыть';

  @override
  String get spaceGateUseBiometrics => 'Биометрия';

  @override
  String get spaceGateBiometricReason => 'Разблокируйте Secretly';

  @override
  String get duressSetupTitle => 'Код принуждения';

  @override
  String get duressSetupDescription => 'Этот код открывает отдельный пустой профиль вместо вашего. Он должен отличаться от настоящего кода. Кто увидит, как вы его вводите, увидит только что установленный мессенджер.';

  @override
  String get duressSectionTitle => 'Код принуждения';

  @override
  String get duressSectionSubtitleSet => 'Настроен. Второй код открывает отдельный пустой профиль.';

  @override
  String get duressSectionSubtitleUnset => 'Второй код, который открывает отдельный пустой профиль вместо вашего.';

  @override
  String get duressSectionChange => 'Сменить';

  @override
  String get duressSectionSetUp => 'Задать';

  @override
  String get duressWipeMainTitle => 'Стирать основной профиль при вводе кода';

  @override
  String get duressWipeMainSubtitle => 'Необратимо. Восстановление — только из набора восстановления или копии.';

  @override
  String get duressRemoveCode => 'Убрать код принуждения';

  @override
  String duressWipeAfterAttemptsTitle(int attempts) {
    return 'Стирать всё после $attempts неверных попыток';
  }

  @override
  String get duressWipeAfterAttemptsSubtitle => 'Оба профиля и сам замок. После 3 неверных попыток уже действует задержка.';

  @override
  String get duressSectionFootnote => 'Защищает при досмотре «покажи телефон», но не при экспертизе устройства. Биометрия всегда открывает основной профиль. Чтобы вернуться в него из обманки, закройте приложение и введите настоящий код.';

  @override
  String get duressSaveFailed => 'Не удалось сохранить настройку.';

  @override
  String get netSettingsImportNoNewMessages => 'Новых сообщений для этого устройства нет.';

  @override
  String netSettingsImportReceived(int count) {
    return 'Принято сообщений: $count';
  }

  @override
  String get netSettingsImportNotEnvelopeFile => 'Это не файл сообщений Secretly или он изменён.';

  @override
  String get netSettingsImportCouldNotOpen => 'Не удалось открыть файл.';

  @override
  String get netSettingsImportCouldNotRead => 'Не удалось прочитать файл. Откройте его в Secretly: Настройки → Без интернета → «Открыть файл сообщений».';

  @override
  String get netSettingsPathDirect => 'Напрямую';

  @override
  String get netSettingsPathFallback => 'По запасному адресу';

  @override
  String get netSettingsPathMirror => 'Через зеркало';

  @override
  String get netSettingsPathCdn => 'Через CDN';

  @override
  String get netSettingsPathProxy => 'Через прокси';

  @override
  String get netSettingsPathSocks => 'Через SOCKS';

  @override
  String get netSettingsPathTor => 'Через Tor';

  @override
  String get netSettingsProxyHostError => 'Нужно имя сервера, например proxy.example.org';

  @override
  String get netSettingsSocksAddressError => 'Нужен адрес вида 127.0.0.1:9050';

  @override
  String get netSettingsNoContactsYet => 'Контактов пока нет.';

  @override
  String get netSettingsPickRecipientTitle => 'Кому файл';

  @override
  String get netSettingsNothingToCarry => 'За неделю этому собеседнику нечего переносить.';

  @override
  String get netSettingsCouldNotCreateFile => 'Не удалось создать файл.';

  @override
  String get netSettingsTitle => 'Сеть';

  @override
  String get netSettingsPathToServersTitle => 'Путь к серверам';

  @override
  String get netSettingsPathDirectOff => 'Напрямую. Обходные пути выключены или недоступны.';

  @override
  String get netSettingsTryAlternativeTitle => 'Искать обходные пути';

  @override
  String get netSettingsTryAlternativeSubtitle => 'Когда прямой путь закрыт, приложение само пробует запасные адреса, зеркала и прокси. Содержимое по-прежнему шифруется сквозным образом.';

  @override
  String get netSettingsVolunteerProxyTitle => 'Прокси волонтёра';

  @override
  String get netSettingsVolunteerProxyDescription => 'Ссылка вида secretly://proxy#имя. Владелец прокси не видит содержимое, но видит, что вы пользуетесь Secretly.';

  @override
  String get netSettingsSocksTitle => 'SOCKS5 (например, Tor через Orbot)';

  @override
  String get netSettingsSendWithoutNetworkTitle => 'Отправить без сети';

  @override
  String get netSettingsSendWithoutNetworkSubtitle => 'Файл с вашими зашифрованными сообщениями собеседнику за неделю. Передайте его как угодно — флешкой, Bluetooth, другим мессенджером.';

  @override
  String get netSettingsOpenMessageFileTitle => 'Открыть файл сообщений';

  @override
  String get netSettingsOpenMessageFileSubtitle => 'Файл .secretly от собеседника. Чужие и уже полученные сообщения пропускаются.';

  @override
  String get netSettingsDeliveryReportsTitle => 'Обезличенные отчёты о доставке';

  @override
  String get netSettingsDeliveryReportsSubtitle => 'Раз в сутки: платформа, тип сети, каким путём дошло и какие пути не работали, страна по языку системы. Без идентификаторов и адресов.';

  @override
  String get netSettingsOrbotTitle => 'Через Orbot (Tor)';

  @override
  String get netSettingsOrbotSubtitle => 'Подставит адрес SOCKS у Orbot — 127.0.0.1:9050. Установите Orbot и запустите его; проверить, работает ли он, Secretly не может.';

  @override
  String get netSettingsOrbotDone => 'Адрес SOCKS выставлен на Orbot. Запустите Orbot и вернитесь.';

  @override
  String get netSettingsTorTitle => 'Tor как последний путь';

  @override
  String get netSettingsTorSubtitle => 'Медленнее и расходует батарею; включается, только когда всё остальное закрыто.';

  @override
  String get socialRecoveryGuardiansTitle => 'Хранители';

  @override
  String get socialRecoveryEntryGuardiansSubtitle => 'Друзья, которые вместе помогут вернуть ваш профиль, если телефон потерян. По одному они не могут ничего.';

  @override
  String get socialRecoveryHelpSomeoneTitle => 'Помочь восстановить';

  @override
  String get socialRecoveryHelpSomeoneSubtitle => 'Если вы чей-то хранитель.';

  @override
  String get socialRecoveryRecoverMineTitle => 'Восстановить свой профиль';

  @override
  String get socialRecoveryRecoverMineSubtitle => 'На новом телефоне — с помощью ваших хранителей.';

  @override
  String get socialRecoveryNeedTwoGuardians => 'Нужно минимум два хранителя.';

  @override
  String get socialRecoverySendSharesFailed => 'Не удалось разослать доли. Проверьте связь.';

  @override
  String get socialRecoveryOwnerIntro => 'Ваш профиль делится на части между хранителями. Чтобы вернуть его, нужно столько из них, сколько вы выберете. Выбирайте людей, которых узнаете по голосу, и с которыми вы сверили номер безопасности.';

  @override
  String get socialRecoveryIsSetUp => 'Восстановление настроено';

  @override
  String get socialRecoveryWaitingConfirmations => 'Ждём подтверждений';

  @override
  String socialRecoveryConfirmedProgress(int accepted, int total, int threshold) {
    return 'Подтвердили $accepted из $total. Нужно $threshold для восстановления.';
  }

  @override
  String get socialRecoveryGuardianHoldsPart => 'Хранит часть';

  @override
  String get socialRecoveryGuardianNotSent => 'Не отправлено';

  @override
  String get socialRecoveryGuardianSentWaiting => 'Отправлено, ждём';

  @override
  String socialRecoveryPickContacts(int max) {
    return 'Выберите от 2 до $max контактов';
  }

  @override
  String get socialRecoveryNoContactsYet => 'Контактов пока нет.';

  @override
  String socialRecoveryThresholdLabel(int threshold, int total) {
    return 'Сколько хранителей нужно для восстановления: $threshold из $total';
  }

  @override
  String get socialRecoveryThresholdWarning => 'Столько хранителей, сговорившись, могут восстановить ваш профиль и без вас. Не выбирайте людей, которые знают друг друга слишком хорошо.';

  @override
  String get socialRecoverySendParts => 'Разослать части';

  @override
  String get socialRecoveryUpdateGuardians => 'Обновить хранителей';

  @override
  String get socialRecoveryTurnOff => 'Отключить восстановление';

  @override
  String get socialRecoveryCodeScanTitle => 'Код восстановления';

  @override
  String get socialRecoveryNotRecoveryCode => 'Это не код восстановления.';

  @override
  String get socialRecoveryNoCodeInClipboard => 'В буфере нет кода восстановления.';

  @override
  String get socialRecoverySendFailed => 'Не удалось отправить. Проверьте связь.';

  @override
  String get socialRecoveryHelpRecoverTitle => 'Помочь восстановить';

  @override
  String get socialRecoveryNotGuardianYet => 'Вы пока ничей не хранитель. Когда кто-то выберет вас, здесь появится его имя.';

  @override
  String get socialRecoveryWhoAreYouHelping => 'Кому помогаете';

  @override
  String socialRecoveryThresholdOfGuardians(int threshold, int guardians) {
    return 'Нужно $threshold из $guardians хранителей';
  }

  @override
  String get socialRecoveryScanCode => 'Сканировать код';

  @override
  String get socialRecoveryPasteCode => 'Вставить код';

  @override
  String get socialRecoveryCheckWordsByVoice => 'Сверьте слова голосом';

  @override
  String get socialRecoveryCheckWordsExplanation => 'Позвоните человеку или встретьтесь лично. Попросите прочитать слова с его экрана. Если хоть одно не совпадает или вы не уверены, что это он, — не отправляйте. Так злоумышленник может получить чужой профиль.';

  @override
  String get socialRecoveryHeardWordsConfirm => 'Я услышал эти слова от этого человека';

  @override
  String get socialRecoverySent => 'Отправлено';

  @override
  String get socialRecoverySendMyPart => 'Отправить свою часть';

  @override
  String get socialRecoveryRecoverProfileTitle => 'Восстановить профиль';

  @override
  String get socialRecoveryRecoverIntro => 'Этот телефон заменит профиль, который сейчас на нём открыт, вашим прежним профилем. Хранители отправят свои части, и как только их будет достаточно, приложение перезапустится уже с вашим профилем.';

  @override
  String get socialRecoveryShowCodeToGuardians => 'Показать код хранителям';

  @override
  String get socialRecoveryShowCodeHint => 'Покажите код хранителю или пришлите текстом, а потом прочитайте ему эти слова голосом.';

  @override
  String get socialRecoveryCopyCode => 'Скопировать код';

  @override
  String get socialRecoveryWaitingGuardians => 'Ждём хранителей';

  @override
  String socialRecoveryReceivedProgress(int received, int threshold) {
    return 'Получено $received из $threshold';
  }

  @override
  String get socialRecoveryPartDidNotFit => 'Одна из частей не подошла. Попросите другого хранителя.';

  @override
  String socialRecoveryAssembleFailed(String error) {
    return 'Не удалось собрать профиль ($error).';
  }

  @override
  String get socialRecoveryCancel => 'Отменить';

  @override
  String get disappearingTitle => 'Исчезающие сообщения';

  @override
  String disappearingSubtitleOn(Object duration) {
    return '$duration · у всех участников';
  }

  @override
  String get disappearingDialogHint => 'Сообщения удаляются с устройств всех участников, когда истекает срок. Это не защищает от снимков экрана и от устройств со старой версией приложения.';

  @override
  String get disappearingCustom => 'Свой срок…';

  @override
  String get disappearingCustomTitle => 'Свой срок';

  @override
  String disappearingCustomHint(Object min, Object max) {
    return 'От $min до $max';
  }

  @override
  String get disappearingUnitSeconds => 'секунд';

  @override
  String get disappearingUnitMinutes => 'минут';

  @override
  String get disappearingUnitHours => 'часов';

  @override
  String get disappearingUnitDays => 'дней';

  @override
  String get disappearingCustomInvalid => 'Введите число в допустимых пределах';

  @override
  String disappearingBannerOn(Object duration) {
    return 'Исчезающие сообщения: $duration';
  }

  @override
  String get disappearingPeerOutdated => 'У собеседника старая версия приложения — у него сообщения не исчезнут.';

  @override
  String get disappearingOwnOutdated => 'На одном из ваших устройств старая версия приложения — там сообщения не исчезнут.';

  @override
  String get disappearingSupportUnknown => 'Не удалось проверить версию приложения собеседника.';

  @override
  String get disappearingChipTooltip => 'Исчезающие сообщения — у всех участников';

  @override
  String get disappearingUpdated => 'Таймер исчезающих сообщений изменён';

  @override
  String get disappearingSetFailed => 'Не удалось изменить таймер';

  @override
  String get disappearingAdminOnly => 'Менять таймер могут владелец и администраторы';

  @override
  String get disappearingRoomOutdated => 'У части участников старая версия приложения — у них сообщения не исчезнут.';

  @override
  String get disappearingQuoteGone => 'Сообщение исчезло';

  @override
  String get serverAuthAlertTitle => 'Ответ сервера не прошёл проверку';

  @override
  String get serverAuthAlertBody => 'Похоже, кто-то между вами и сервером Secretly подменяет данные. Открытые чаты защищены и продолжают работать. Новые контакты и устройства не принимаются, пока это не пройдёт. Попробуйте другую сеть или прокси.';

  @override
  String get serverAuthAlertDismiss => 'Понятно';

  @override
  String get stickerPackAccessTitle => 'Кто может добавить набор';

  @override
  String get stickerPackAccessOpen => 'Открытый';

  @override
  String get stickerPackAccessOpenHint => 'Тот, кому вы пришлёте стикер, сможет добавить себе весь набор. На сервер набор не попадает.';

  @override
  String get stickerPackAccessClosed => 'Закрытый';

  @override
  String get stickerPackAccessClosedHint => 'Набор будет только у вас. Собеседники увидят присланные стикеры, но не смогут добавить набор. Присланные стикеры всё равно остаются у них на устройстве — снимку экрана это не помешает.';

  @override
  String get stickerPackClosedExistingNote => 'У тех, кто уже добавил набор, он останется.';

  @override
  String get stickerPackClosedLabel => 'Закрытый набор';

  @override
  String get stickerPackClosedNote => 'Автор не разрешил добавлять этот набор';

  @override
  String get stickerCreateFromPhoto => 'Из фото';

  @override
  String get stickerCreateTextOnly => 'Текстовый стикер';

  @override
  String stickerCreateFailed(String error) {
    return 'Не удалось создать стикер: $error';
  }

  @override
  String stickerPackMissingNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ещё $count стикера не передались — возможно, у автора старая версия приложения',
      many: 'Ещё $count стикеров не передалось — возможно, у автора старая версия приложения',
      few: 'Ещё $count стикера не передались — возможно, у автора старая версия приложения',
      one: 'Ещё $count стикер не передался — возможно, у автора старая версия приложения',
    );
    return '$_temp0';
  }

  @override
  String get stickerAddedToPack => 'Стикер добавлен в набор';

  @override
  String stickerSaveFailed(String error) {
    return 'Не удалось сохранить: $error';
  }

  @override
  String get stickerFavoritesPackTitle => 'Избранное';

  @override
  String get stickerAddedToFavorites => 'Стикер добавлен в избранное';

  @override
  String get stickerAnimationUnavailable => 'Анимация недоступна на этом устройстве';

  @override
  String get stickerMotionPickTitle => 'Выберите эффект движения';

  @override
  String get stickerMotionSlow => 'Медленно';

  @override
  String get stickerMotionNormal => 'Обычно';

  @override
  String get stickerMotionFast => 'Быстро';

  @override
  String get stickerMotionPulse => 'Пульс';

  @override
  String get stickerMotionBounce => 'Прыжок';

  @override
  String get stickerMotionWobble => 'Качание';

  @override
  String get stickerMotionTada => 'Та-да';

  @override
  String get stickerReadyTitle => 'Готовый стикер';

  @override
  String get stickerPickEmojiHint => 'Выберите эмодзи, которые соответствуют стикеру';

  @override
  String get stickerSend => 'Отправить стикер';

  @override
  String get stickerAnimating => 'Оживляем…';

  @override
  String get stickerChangeMotion => 'Сменить движение';

  @override
  String get stickerAnimatePremium => 'Оживить · Premium';

  @override
  String get stickerMakeFavorite => 'Сделать избранным';

  @override
  String get stickerAddToPack => 'Добавить в набор';

  @override
  String get stickerBack => 'Назад';

  @override
  String get stickerNewPack => 'Новый набор';

  @override
  String get stickerNewPackHint => 'Придумайте название для набора.';

  @override
  String get stickerCreate => 'Создать';

  @override
  String get stickerEditorObjectNotFound => 'Объект не распознан';

  @override
  String get stickerEditorPickObject => 'Выберите объект';

  @override
  String get stickerEditorText => 'Текст';

  @override
  String get stickerEditorSelectObject => 'Выделите объект';

  @override
  String get stickerWord => 'Стикер';

  @override
  String get stickerEditorUndo => 'Отменить';

  @override
  String get stickerEditorRedo => 'Вернуть';

  @override
  String get stickerEditorDelete => 'Удалить';

  @override
  String get stickerEditorDone => 'Готово';

  @override
  String get stickerEditorBgNone => 'Без фона';

  @override
  String get stickerEditorBgSolid => 'Заливка';

  @override
  String get stickerEditorBgPill => 'Плашка';

  @override
  String get stickerEditorOutline => 'Контур';

  @override
  String get stickerEditorBackground => 'Фон';

  @override
  String get stickerEditorRecut => 'Вырезать заново';

  @override
  String get stickerEditorCut => 'Вырезать объект';

  @override
  String get stickerEditorDraw => 'Рисунок';

  @override
  String get stickerEditorAdjust => 'Коррекция';

  @override
  String get stickerEditorEmoji => 'Эмодзи';

  @override
  String get stickerEditorExposure => 'Экспозиция';

  @override
  String get stickerEditorContrast => 'Контраст';

  @override
  String get stickerEditorSaturation => 'Насыщенность';

  @override
  String get stickerEditorTapObjects => 'Нажмите на объекты, которые оставить';

  @override
  String get stickerEditorObjectSelected => 'Объект выделен';

  @override
  String stickerPackInstallFailed(String error) {
    return 'Не удалось установить стикерпак: $error';
  }

  @override
  String stickerPackRemoveFailed(String error) {
    return 'Не удалось удалить стикерпак: $error';
  }

  @override
  String get stickerPackRemoveTitle => 'Удалить стикерпак?';

  @override
  String stickerPackRemoveBody(String title) {
    return 'Пак \"$title\" останется в каталоге, но локальные файлы будут удалены.';
  }

  @override
  String get stickerPackRemoveAction => 'Удалить';

  @override
  String stickerPackRemovedSnack(String title) {
    return 'Стикерпак \"$title\" удалён с устройства.';
  }

  @override
  String get stickerPackEdit => 'изменить';

  @override
  String get stickerPackCoverUpdated => 'Обложка набора обновлена';

  @override
  String stickerPackFull(int max) {
    return 'В наборе уже $max стикеров — создайте новый';
  }

  @override
  String get settingsGroupProfile => 'Профиль';

  @override
  String get settingsGroupRecovery => 'Восстановление';

  @override
  String get settingsCaptionAccountRestore => 'ID и резервная копия нужны, чтобы вернуть аккаунт на новом телефоне. Запишите ID и храните его отдельно от телефона.';

  @override
  String get settingsGroupLeave => 'Выход и удаление';

  @override
  String get settingsCaptionLeave => 'Выход стирает данные только на этом устройстве. Удаление стирает профиль и на сервере — вернуть его будет нельзя.';

  @override
  String get settingsGroupGeneral => 'Главное';

  @override
  String get settingsGroupMessages => 'Сообщения';

  @override
  String get settingsCaptionMessages => 'Текст и имя в уведомлении может увидеть любой, у кого в руках ваш телефон.';

  @override
  String get settingsGroupCalls => 'Звонки';

  @override
  String get settingsGroupInApp => 'Внутри приложения';

  @override
  String get settingsCaptionInApp => 'Звуки и вибрация, пока Secretly открыт.';

  @override
  String get settingsGroupNotificationLook => 'Как выглядит уведомление';

  @override
  String get settingsGroupBackground => 'Работа в фоне';

  @override
  String get settingsGroupQr => 'QR-код';

  @override
  String get settingsGroupPersonal => 'Личное';

  @override
  String get settingsGroupWhoCan => 'Кто видит и кто может писать';

  @override
  String get settingsGroupNewChats => 'Новые чаты';

  @override
  String get settingsGroupSearchBlocking => 'Поиск и блокировки';

  @override
  String get settingsGroupPhoneContacts => 'Контакты телефона';

  @override
  String get settingsGroupInactive => 'Если меня долго нет';

  @override
  String get settingsCaptionInactive => 'Если вы столько времени не заходите в Secretly, аккаунт удалится сам.';

  @override
  String get settingsGroupAppLanguage => 'Язык приложения';

  @override
  String get settingsGroupTranslation => 'Перевод';

  @override
  String get settingsGroupStatus => 'Состояние';

  @override
  String get settingsGroupBlocked => 'Если Secretly заблокирован';

  @override
  String get settingsCaptionBlocked => 'Обычно ничего настраивать не нужно. Прокси и Orbot — на случай, если обходные пути не помогли.';

  @override
  String get settingsGroupOwnProxy => 'Свой прокси';

  @override
  String get settingsGroupOffline => 'Без интернета';

  @override
  String get settingsCaptionOffline => 'Это файл, а не живая связь: собеседник прочитает сообщения, когда откроет файл.';

  @override
  String get settingsGroupHelpDelivery => 'Помочь улучшить доставку';

  @override
  String get netHowItWorksTitle => 'Как это работает';

  @override
  String get netHowItWorksSubtitle => 'Простыми словами: обход блокировок и связь без интернета';

  @override
  String get netHowStep1Title => 'Как сообщение доходит';

  @override
  String get netHowStep1Body => 'Телефон шифрует сообщение до отправки. Сервер хранит его зашифрованным, пока собеседник не в сети, и отдаёт, когда он появится. Прочитать сообщение сервер не может.';

  @override
  String get netHowStep2Title => 'Если Secretly заблокирован';

  @override
  String get netHowStep2Body => '«Искать обходные пути» включено с самого начала. Приложение само пробует запасной адрес, копию сервера («зеркало») и большие сети доставки («CDN»), которые трудно заблокировать целиком. Первое подключение может занять больше времени.';

  @override
  String get netHowStep3Title => 'Если и это не помогло';

  @override
  String get netHowStep3Body => 'Попросите у человека, которому доверяете, ссылку на прокси и вставьте её в «Прокси волонтёра». Можно поставить Orbot — приложение сети Tor. Это медленнее, и Orbot расходует батарею.';

  @override
  String get netHowStep4Title => 'Совсем без интернета';

  @override
  String get netHowStep4Body => 'Нажмите «Отправить без сети», выберите собеседника и передайте файл любым способом: флешкой, AirDrop, Bluetooth. Он откроет его в Secretly. В файл попадают только уже написанные сообщения за последнюю неделю. Живой связи по Bluetooth или через соседние телефоны пока нет.';

  @override
  String get netHowStep5Title => 'Звонки';

  @override
  String get netHowStep5Body => 'В «Приватности» можно скрыть свой адрес в звонках: звонок пойдёт через наш сервер, и собеседник не увидит ваш IP-адрес. Задержка может немного вырасти.';

  @override
  String get netHowStep6Title => 'Чтобы сообщения не опаздывали';

  @override
  String get netHowStep6Body => 'Система телефона может «усыпить» Secretly, и тогда сообщения придут, только когда вы откроете приложение. Что мешает доставке, видно в разделе «Надёжность».';

  @override
  String get settingsHelpGotIt => 'Понятно';

  @override
  String get settingsHelpTip => 'Совет';

  @override
  String get settingsHelpButton => 'Пояснение';

  @override
  String get settingsHubAccountGroup => 'Аккаунт и защита';

  @override
  String get settingsHubTalkGroup => 'Общение';

  @override
  String get settingsHubConnectionGroup => 'Связь';

  @override
  String get settingsHubPhoneGroup => 'Телефон';

  @override
  String get settingsHubMoreGroup => 'Ещё';

  @override
  String get settingsHubAccountSub => 'Имя, Secretly ID, QR, резервная копия';

  @override
  String get settingsHubPrivacySub => 'Кто видит вас и может написать';

  @override
  String get settingsHubSecuritySub => 'Блокировка приложения, личные чаты';

  @override
  String get settingsHubDevicesSub => 'Где открыт ваш аккаунт';

  @override
  String get settingsHubNotificationsSub => 'Сообщения, комнаты, звонки';

  @override
  String get settingsHubChatsSub => 'Тема, фоны, пузыри, иконка';

  @override
  String get settingsHubLanguageSub => 'Язык приложения и перевод';

  @override
  String get settingsHubNetworkSub => 'Как Secretly доходит до серверов';

  @override
  String get settingsHubOfflineSub => 'Передать сообщения файлом';

  @override
  String get settingsHubReliabilitySub => 'Что может задерживать доставку';

  @override
  String get settingsHubSystemSub => 'Сброс и служебные сообщения';

  @override
  String get settingsHubInviteSub => 'Поделиться ссылкой';

  @override
  String get settingsHubDonateSub => 'Помочь проекту';

  @override
  String get settingsHubSupportSub => 'Написать нам';

  @override
  String get settingsHubPolicySub => 'Что хранится и где';

  @override
  String get settingsHubAboutSub => 'Версия и лицензии';

  @override
  String get settingsIntroAccount => 'Как вас видят другие и как не потерять доступ к переписке.';

  @override
  String get settingsIntroPrivacy => 'Решите, кто видит ваши данные и кто может с вами связаться.';

  @override
  String get settingsIntroSecurity => 'Защита от посторонних, если телефон попал в чужие руки.';

  @override
  String get settingsIntroNotifications => 'Что и как вам сообщать. Начните с главного переключателя.';

  @override
  String get settingsIntroLanguage => 'На каком языке с вами говорит Secretly.';

  @override
  String get settingsIntroNetwork => 'Как Secretly связывается с серверами. Обычно здесь ничего менять не нужно.';

  @override
  String get settingsIntroOffline => 'Если интернета нет совсем, сообщения можно передать файлом — флешкой, по Bluetooth или через другой мессенджер.';

  @override
  String get settingsIntroReliability => 'Проверяем, не мешает ли система получать сообщения и звонки вовремя.';

  @override
  String get settingsIntroPower => 'Отключите эффекты, если телефон греется или быстро садится.';

  @override
  String get settingsIntroStorage => 'Сколько места занимает Secretly на телефоне.';

  @override
  String get settingsIntroSystem => 'Служебные действия. Пользуйтесь, только если что-то пошло не так.';

  @override
  String get settingsGroupShare => 'Поделиться';

  @override
  String get settingsGroupMedia => 'Медиа';

  @override
  String get settingsGroupData => 'Данные';

  @override
  String get settingsGroupLock => 'Блокировка';

  @override
  String get settingsGroupManual => 'Ручная настройка';

  @override
  String get settingsHelpManual => 'Нужна, только если обходные пути не помогли. Выберите один способ: прокси от знакомого волонтёра, SOCKS5 или Tor через Orbot.';

  @override
  String get settingsGroupConnection => 'Соединение';

  @override
  String get settingsGroupSend => 'Отправить';

  @override
  String get settingsGroupReceive => 'Получить';

  @override
  String get settingsOpenPersonalChats => 'Открыть личные чаты';

  @override
  String get settingsOpenPersonalChatsSub => 'Ваша скрытая подборка чатов';

  @override
  String get offlineStep1Title => 'Создайте файл';

  @override
  String get offlineStep1Body => 'Выберите собеседника — в файл попадут ваши зашифрованные сообщения ему за последнюю неделю.';

  @override
  String get offlineStep2Title => 'Передайте любым способом';

  @override
  String get offlineStep2Body => 'Флешка, Bluetooth, AirDrop, другой мессенджер. Прочитать сообщения сможет только получатель.';

  @override
  String get offlineStep3Title => 'Собеседник открывает файл';

  @override
  String get offlineStep3Body => 'В Secretly: «Без интернета» → «Открыть файл сообщений». Сообщения появятся в чате.';

  @override
  String get translateSameLanguage => 'Сообщение уже на этом языке';

  @override
  String get translateUndetected => 'Не удалось определить язык. Выберите язык оригинала в Настройках → Язык.';

  @override
  String get translateUnsupported => 'Этот язык переводчик на телефоне пока не знает';

  @override
  String get translateDownloadFailed => 'Не удалось скачать языковой пакет. Проверьте интернет и нажмите ещё раз.';

  @override
  String get translateFailed => 'Не удалось перевести. Нажмите ещё раз.';

  @override
  String get translateNothing => 'Здесь нечего переводить';

  @override
  String get translateDownloading => 'Скачиваем языковой пакет — это нужно один раз';

  @override
  String get translateButtonTooltip => 'Перевести';

  @override
  String get attachmentMetadataScrubFailed => 'Не удалось убрать из файла место съёмки и данные телефона, поэтому он не отправлен. Попробуйте другой снимок или отправьте его как файл.';

  @override
  String get backupServerWrongPassword => 'Пароль не подходит или копии с таким номером профиля нет. Проверьте номер, раскладку и регистр букв.';

  @override
  String backupServerLocked(String time) {
    return 'Слишком много неверных паролей из этой сети. Попробуйте после $time или из другой сети.';
  }

  @override
  String get backupServerSection => 'Копия на сервере';

  @override
  String get backupServerDelete => 'Удалить копию с сервера';

  @override
  String get backupServerDeleteFooter => 'Зашифрованная копия удалится с сервера. Копии на этом устройстве и в файлах останутся.';

  @override
  String get backupServerDeleteConfirmTitle => 'Удалить копию с сервера?';

  @override
  String get backupServerDeleteConfirmBody => 'Восстановить переписку с сервера на новом телефоне будет нельзя. Автокопия на сервер выключится. Отменить это нельзя.';

  @override
  String get backupServerDeleteConfirm => 'Удалить';

  @override
  String get backupServerDeleteDone => 'Копия удалена с сервера';

  @override
  String get backupServerDeleteNone => 'На сервере копии не было';

  @override
  String get backupServerDeleteFailed => 'Не удалось удалить копию. Проверьте интернет и попробуйте ещё раз.';

  @override
  String get backupAutoErrorNoPassword => 'Автокопия не создаётся: не задан пароль копии. Задайте его — без пароля копию нечем зашифровать.';

  @override
  String get backupAutoErrorWeakPassword => 'Автокопия не создаётся: пароль копии больше не отвечает требованиям. Задайте новый.';

  @override
  String backupKeystoreUnreadable(String slot) {
    return 'Не удаётся прочитать ключ «$slot» из защищённого хранилища телефона, поэтому копия не создана. Переписка на телефоне цела. Напишите в поддержку — это чинится без потери данных.';
  }

  @override
  String get stickerDeleteTitle => 'Удалить стикер?';

  @override
  String stickerDeleteBody(String title) {
    return 'Стикер исчезнет из набора «$title». Уже отправленные в переписку останутся.';
  }

  @override
  String get stickerDeleteLastTitle => 'Удалить весь набор?';

  @override
  String stickerDeleteLastBody(String title) {
    return 'Это последний стикер в «$title». Вместе с ним удалится весь набор.';
  }

  @override
  String get stickerDeleteAction => 'Удалить';

  @override
  String get stickerPackSettings => 'Настройки набора';

  @override
  String get stickerMore => 'Ещё';

  @override
  String get stickerPackRemoveFromMine => 'Убрать из моих наборов';

  @override
  String stickerPackRemoveFromMineBody(String title) {
    return '«$title» исчезнет из вашей панели. У автора и у других набор останется — добавить его снова можно, нажав на стикер из него в переписке.';
  }

  @override
  String get stickerPackDeleteWhole => 'Удалить набор';

  @override
  String get stickerPackDeleteWholeTitle => 'Удалить набор?';

  @override
  String stickerPackDeleteWholeBody(String title) {
    return 'Набор «$title» будет удалён с этого устройства. Уже отправленные стикеры останутся в переписке.';
  }

  @override
  String get stickerMakeCover => 'Сделать обложкой';

  @override
  String get stickerRemoveFromFavorites => 'Убрать из избранного';

  @override
  String get stickerRemovedFromFavorites => 'Стикер убран из избранного';

  @override
  String stickerAddToThisPack(String title) {
    return 'Добавить в «$title»';
  }

  @override
  String get stickerAddSticker => 'Добавить стикер';

  @override
  String get welcomeTagline => 'Без номера и почты. Аккаунт — это ключ, который живёт только на ваших устройствах.';

  @override
  String get welcomeCreateAccount => 'Создать аккаунт';

  @override
  String get welcomeHaveAccount => 'У меня уже есть аккаунт';

  @override
  String welcomeTermsNotice(String terms, String privacy) {
    return 'Продолжая, вы принимаете $terms и $privacy';
  }

  @override
  String get welcomeTermsLink => 'условия';

  @override
  String get welcomePrivacyLink => 'политику конфиденциальности';

  @override
  String get welcomeNameTitle => 'Как вас зовут?';

  @override
  String get welcomeNameBody => 'Это имя увидят собеседники. Его можно изменить.';

  @override
  String get welcomeNameHint => 'Имя или псевдоним';

  @override
  String get welcomeKeysStepIdentity => 'Создаём ключ личности';

  @override
  String get welcomeKeysStepPrekeys => 'Готовим ключи для первых сообщений';

  @override
  String get welcomeKeysStepStorage => 'Шифруем хранилище';

  @override
  String get welcomeKeysReady => 'Ключи готовы';

  @override
  String get welcomeKeysNote => 'Ключи создаются на этом устройстве — сервер их не видит';

  @override
  String get welcomeBackupTitle => 'Резервная копия';

  @override
  String get welcomeBackupBodyCloud => 'Переписка переживёт потерю телефона. Копия шифруется паролем, который знаете только вы.';

  @override
  String get welcomeBackupBodyDevice => 'Копия хранится на этом устройстве. Перенесите её на новое вместе с паролем.';

  @override
  String get welcomeBackupInCloud => 'В облаке';

  @override
  String get welcomeBackupOnDevice => 'На устройстве';

  @override
  String get welcomeBackupPasswordHint => 'Придумайте пароль';

  @override
  String get welcomeBackupPasswordRepeatHint => 'Повторите пароль';

  @override
  String get welcomePasswordShow => 'Показать';

  @override
  String get welcomePasswordHide => 'Скрыть';

  @override
  String get welcomePasswordStrong => 'Надёжный';

  @override
  String get welcomePasswordVeryStrong => 'Очень надёжный';

  @override
  String get welcomeBackupEnable => 'Включить копию';

  @override
  String get welcomeBackupLater => 'Настроить позже';

  @override
  String get welcomeBackupOnTitle => 'Копия включена';

  @override
  String welcomeBackupOnBody(String schedule) {
    return '$schedule. Изменить можно в настройках.';
  }

  @override
  String get welcomeNotifyTitle => 'Не пропускайте сообщения';

  @override
  String get welcomeNotifyBody => 'Apple и Google передают только сигнал о новом сообщении — сам текст через них не идёт.';

  @override
  String get welcomeNotifyPreviewMessage => 'Новое сообщение';

  @override
  String get welcomeNotifyPreviewCall => 'Входящий звонок';

  @override
  String get welcomeNotifyNow => 'сейчас';

  @override
  String get welcomeNotifyAllow => 'Разрешить уведомления';

  @override
  String get welcomeNotifyNotNow => 'Не сейчас';

  @override
  String welcomeDoneTitle(String name) {
    return 'Добро пожаловать, $name';
  }

  @override
  String get welcomeDoneTitleNoName => 'Добро пожаловать';

  @override
  String get welcomeDoneBody => 'Аккаунт создан. Пригласите тех, с кем хотите переписываться.';

  @override
  String get welcomeDoneIdCaption => 'Ваш Secretly ID — по нему вас находят и восстанавливают аккаунт. Сохраните его.';

  @override
  String get welcomeCopy => 'Копировать';

  @override
  String get welcomeCopied => 'Скопировано';

  @override
  String get welcomeOpenApp => 'Открыть Secretly';

  @override
  String get welcomeRestoreTitle => 'Восстановление';

  @override
  String get welcomeRestoreSubtitle => 'Откуда вернуть аккаунт?';

  @override
  String get welcomeRestoreCloudTitle => 'Копия в облаке';

  @override
  String get welcomeRestoreCloudBody => 'Нужны Secretly ID и пароль копии';

  @override
  String get welcomeRestoreCloudFormBody => 'Введите Secretly ID и пароль копии.';

  @override
  String get welcomeRestoreBackupPasswordHint => 'Пароль копии';

  @override
  String get welcomeRestoreFileTitle => 'Файл на устройстве';

  @override
  String get welcomeRestoreFileFormTitle => 'Файл резервной копии';

  @override
  String get welcomeRestoreFileFormBody => 'Выберите копию и введите её пароль.';

  @override
  String get welcomeRestoreFilePick => 'Найти копию на устройстве';

  @override
  String get welcomeRestoreFileChosen => 'Выбранный файл';

  @override
  String get welcomeRestoreFileOther => 'Другой';

  @override
  String get welcomeRestoreStepDownload => 'Загружаем копию';

  @override
  String get welcomeRestoreStepDecrypt => 'Проверяем пароль и расшифровываем';

  @override
  String get welcomeRestoreStepApply => 'Возвращаем чаты и контакты';

  @override
  String get welcomeRestoreNote => 'Копия расшифровывается на этом устройстве. Сервер не видит её содержимого.';

  @override
  String get welcomeNewLoginTitle => 'Это вы входите?';

  @override
  String get welcomeNewLoginBody => 'Новое устройство просит доступ к вашему аккаунту. Разрешайте, только если это ваше устройство.';

  @override
  String get welcomeNewLoginUnknownDevice => 'Новое устройство';

  @override
  String welcomeNewLoginTime(String time) {
    return 'Сегодня в $time';
  }

  @override
  String get welcomeNewLoginSyncSection => 'Что перенести на новое устройство';

  @override
  String get welcomeNewLoginApprove => 'Да, это я';

  @override
  String get welcomeNewLoginDecline => 'Нет — отклонить вход';

  @override
  String get welcomeStart => 'Начать';

  @override
  String get welcomeDesktopChooseTitle => 'Подключите этот компьютер';

  @override
  String get welcomeDesktopChooseBody => 'Быстрее всего — через телефон, где уже есть Secretly. Вся переписка переедет сюда.';

  @override
  String get welcomeOr => 'или';

  @override
  String get welcomeDesktopNewAccount => 'Новый аккаунт';

  @override
  String get welcomeMoreInfo => 'Подробнее';

  @override
  String get welcomeDesktopQrTitle => 'Отсканируйте телефоном';

  @override
  String welcomeDesktopUsePhonePrompt(String link) {
    return 'Телефон с Secretly под рукой? $link — так телефон не потеряет доступ.';
  }

  @override
  String get welcomeDesktopUsePhoneLink => 'Войдите через него';

  @override
  String get welcomeDesktopTakeOverUsePhone => 'Подключить через телефон';

  @override
  String get welcomeDesktopKitKeepApart => 'Храните его отдельно от компьютера — на флешке или в облаке.';

  @override
  String get pickerDone => 'Готово';

  @override
  String get chatSwipeMute => 'Без звука';

  @override
  String get chatSwipeUnmute => 'Со звуком';
}
