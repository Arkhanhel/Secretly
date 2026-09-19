// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get appTitle => 'Secretly';

  @override
  String get starting => 'Запуск…';

  @override
  String get encrypting => 'Шифрування…';

  @override
  String errorPrefix(Object error) {
    return 'Помилка: $error';
  }

  @override
  String get settingsTitle => 'Налаштування';

  @override
  String get notificationsSection => 'Сповіщення';

  @override
  String get languageSection => 'Мова';

  @override
  String get comingSoon => 'Незабаром';

  @override
  String get idsTitle => 'Ідентифікатори';

  @override
  String get profileIdLabel => 'ID профілю';

  @override
  String get deviceIdLabel => 'ID пристрою';

  @override
  String get profileIdShort => 'Профіль';

  @override
  String get deviceIdShort => 'Пристрій';

  @override
  String get copy => 'Копіювати';

  @override
  String get copied => 'Скопійовано';

  @override
  String get copyBoth => 'Копіювати обидва';

  @override
  String get openMyId => 'Відкрити мій ID';

  @override
  String get close => 'Закрити';

  @override
  String get tabChats => 'Чати';

  @override
  String get tabGroups => 'Кімнати';

  @override
  String get tabContacts => 'Контакти';

  @override
  String get tabProfile => 'Профіль';

  @override
  String get accountSection => 'Акаунт';

  @override
  String get chatsSection => 'Чати';

  @override
  String get privacySection => 'Приватність';

  @override
  String get devicesSection => 'Пристрої';

  @override
  String get systemSection => 'Система';

  @override
  String get languageSystemDefault => 'Системна мова';

  @override
  String languageSystemCurrent(Object language) {
    return 'Системна ($language)';
  }

  @override
  String get languageChooseAppLanguage => 'Виберіть мову застосунку';

  @override
  String get languageAvailableWave1 => 'Доступно: англійська, російська, українська, іспанська, португальська (Бразилія), французька та німецька. Також можна використовувати системну мову.';

  @override
  String get languageMessageTranslation => 'Переклад повідомлень';

  @override
  String get languageShowTranslateButton => 'Показувати кнопку «Перекласти»';

  @override
  String get languageTranslateWholeChats => 'Перекладати цілі чати';

  @override
  String get favoritesTitle => 'Вибране';

  @override
  String get favoritesSubtitle => 'Ваші особисті нотатки';

  @override
  String get favoritesEmptyTitle => 'У вибраному поки порожньо';

  @override
  String get favoritesEmptySubtitle => 'Надсилайте сюди повідомлення, файли й нотатки, щоб приватно зберігати їх на своїх пристроях.';

  @override
  String get favoritesPersonalNotebookLabel => 'Особисті нотатки';

  @override
  String get more => 'Ще';

  @override
  String get stickersRecent => 'Нещодавні стікери';

  @override
  String get searchStickers => 'Пошук стікерів';

  @override
  String get noStickersFound => 'Стікери не знайдено';

  @override
  String get noRecentStickers => 'Тут з’являться ваші нещодавні стікери';

  @override
  String get cancelSelection => 'Скасувати вибір';

  @override
  String get chatsTitle => 'Чати';

  @override
  String get newChat => 'Новий чат';

  @override
  String get openContactsToStartChat => 'Відкрийте «Контакти», щоб почати чат';

  @override
  String get noChatsYet => 'Чатів поки немає';

  @override
  String get openDemoChat => 'Відкрити демо-чат';

  @override
  String get archive => 'Архів';

  @override
  String get unarchive => 'Повернути з архіву';

  @override
  String get pin => 'Закріпити';

  @override
  String get unpin => 'Відкріпити';

  @override
  String get clearHistory => 'Очистити історію';

  @override
  String archiveHeader(Object count) {
    return 'Архів ($count)';
  }

  @override
  String deleteChatsConfirmTitle(Object count) {
    return 'Видалити чати ($count)?';
  }

  @override
  String get deleteChatsConfirmBody => 'Це видалить чати лише з цього пристрою.';

  @override
  String clearHistoryConfirmTitle(Object count) {
    return 'Очистити історію чатів ($count)?';
  }

  @override
  String get clearHistoryConfirmBody => 'Це видалить повідомлення лише з цього пристрою.';

  @override
  String get contactsTitle => 'Контакти';

  @override
  String get contactsTab => 'Контакти';

  @override
  String get requestsTab => 'Запити';

  @override
  String get addContact => 'Додати контакт';

  @override
  String get deleteContact => 'Видалити контакт';

  @override
  String get noContactsYet => 'Контактів поки немає';

  @override
  String get noRequests => 'Запитів немає';

  @override
  String get secretlyIdLabel => 'Secretly ID';

  @override
  String get secretlyIdHint => 'XXXX-XXXX-...-CHECK';

  @override
  String get nameOptionalLabel => 'Ім’я (необов’язково)';

  @override
  String get scanContactQrTitle => 'Сканувати QR контакту';

  @override
  String get qrMissingSecretlyId => 'QR не містить Secretly ID';

  @override
  String get differentServerTitle => 'Інший сервер';

  @override
  String differentServerBody(Object qrServer, Object appServer) {
    return 'Цей QR належить іншому серверу.\n\nQR-сервер: $qrServer\nЦей застосунок: $appServer\n\nУстановіть однаковий APK/сервер на обидва телефони.';
  }

  @override
  String get contactActionProfileNotFound => 'Secretly ID не знайдено на цьому сервері.';

  @override
  String get contactActionTransportBlocked => 'Ця дія недоступна, бо застосунок прив’язаний до іншого сервера.';

  @override
  String get contactActionServiceUnavailable => 'Сервер зараз недоступний. Спробуйте ще раз за мить.';

  @override
  String get contactActionCallsDisabled => 'Дзвінки вимкнено в налаштуваннях приватності.';

  @override
  String get contactActionCallsDisabledForContact => 'Дзвінки для цього контакту вимкнено.';

  @override
  String get callServiceUnavailable => 'Сервіс дзвінків зараз недоступний.';

  @override
  String get callAlreadyInProgress => 'Інший дзвінок уже триває.';

  @override
  String get callIceUnavailable => 'Захищене налаштування дзвінка зараз недоступне. Спробуйте ще раз за мить.';

  @override
  String get callPermissionDenied => 'Доступ до мікрофона або камери заблоковано. Надайте дозволи й спробуйте ще раз.';

  @override
  String get callNegotiationFailed => 'Не вдалося встановити захищений дзвінок. Спробуйте ще раз.';

  @override
  String get callConnectionInterrupted => 'З’єднання дзвінка було перервано. Спробуйте ще раз.';

  @override
  String get callActionGeneric => 'Не вдалося почати дзвінок. Спробуйте ще раз.';

  @override
  String get callEncryptedBadge => 'Наскрізне шифрування';

  @override
  String get incomingVideoCall => 'Вхідний відеодзвінок';

  @override
  String get incomingVoiceCall => 'Вхідний голосовий дзвінок';

  @override
  String get callDecline => 'Відхилити';

  @override
  String get callConnectionUnstable => 'З’єднання нестабільне';

  @override
  String get callNetworkVeryWeak => 'Дуже слабкий сигнал мережі';

  @override
  String get callNetworkWeak => 'Слабкий сигнал мережі';

  @override
  String get callEnded => 'Дзвінок завершено';

  @override
  String get callReplacedByNewerAttempt => 'Дзвінок замінено новішою спробою';

  @override
  String get callDeclined => 'Дзвінок відхилено';

  @override
  String get callYouDeclined => 'Ви відхилили';

  @override
  String get callNoAnswer => 'Немає відповіді';

  @override
  String get callConnectionError => 'Помилка з’єднання';

  @override
  String get callVideoUnavailable => 'Відео недоступне';

  @override
  String get callWaitingForRemoteVideo => 'Очікування відео співрозмовника...';

  @override
  String get callAttachingRemoteVideo => 'Підключення віддаленого відео...';

  @override
  String get callStartingRemoteVideo => 'Запуск віддаленого відео...';

  @override
  String get callRemoteVideoNotArriving => 'Відео співрозмовника не надходить';

  @override
  String get callRemoteVideoBindFailed => 'Не вдалося прив’язати віддалений відеопотік';

  @override
  String get callRemoteVideoNoFrames => 'Віддалене відео підключено, але кадри не відображаються';

  @override
  String get callMinimize => 'Згорнути';

  @override
  String get callStatusCalling => 'Виклик...';

  @override
  String get callStatusIncoming => 'Вхідний...';

  @override
  String get callStatusConnecting => 'Підключення...';

  @override
  String get callStatusReconnecting => 'Повторне підключення...';

  @override
  String get callStatusEnded => 'Завершено';

  @override
  String get callVideoCall => 'Відеодзвінок';

  @override
  String get callControlMute => 'Вимкнути звук';

  @override
  String get callControlSpeaker => 'Динамік';

  @override
  String get callControlCamera => 'Камера';

  @override
  String get callControlFlip => 'Перемкнути';

  @override
  String get callControlStop => 'Зупинити';

  @override
  String get callControlShare => 'Поділитися';

  @override
  String get callControlEnd => 'Завершити';

  @override
  String get contactActionGeneric => 'Не вдалося виконати дію. Спробуйте ще раз.';

  @override
  String get notificationTitleRoom => 'Кімната';

  @override
  String get notificationTitleRequest => 'Запит';

  @override
  String get notificationTitleChat => 'Чат';

  @override
  String get notificationBodyNewMessage => 'Нове повідомлення';

  @override
  String get contactLookupUnavailable => 'Пошук зараз недоступний. Спробуйте ще раз за мить.';

  @override
  String addContactFailed(Object error) {
    return 'Не вдалося додати контакт: $error';
  }

  @override
  String deleteContactsConfirmTitle(Object count) {
    return 'Видалити контакти ($count)?';
  }

  @override
  String get deleteContactsConfirmBody => 'Чати не буде видалено.';

  @override
  String get privacyTitle => 'Приватність';

  @override
  String get blockedUsersSubtitle => 'Заблоковані користувачі не зможуть доставляти вам повідомлення (застосовується сервером).';

  @override
  String get noBlockedUsers => 'Заблокованих користувачів немає';

  @override
  String unblockFailed(Object error) {
    return 'Не вдалося розблокувати: $error';
  }

  @override
  String get diagIdentity => 'Ідентичність';

  @override
  String get diagEndpoints => 'Ендпоїнти';

  @override
  String get diagServerBinding => 'Прив’язка до сервера';

  @override
  String get diagMismatch => 'Невідповідність: профіль належить іншому серверу. Використайте Налаштування → Скинути профіль.';

  @override
  String get diagStatus => 'Статус';

  @override
  String get diagTimestamps => 'Часові мітки';

  @override
  String get diagTips => 'Поради';

  @override
  String get diagTipsBody => 'Якщо повідомлення не надсилаються з помилкою \"profile not found\":\n1) Переконайтеся, що обидва телефони використовують той самий APK/сервер\n2) Додайте контакт повторно, відсканувавши QR\n3) Якщо ендпоїнти змінилися, скористайтеся скиданням профілю\n';

  @override
  String get secretlyUser => 'Користувач Secretly';

  @override
  String get onlineStatus => 'онлайн';

  @override
  String get edit => 'Редагувати';

  @override
  String get removePhoto => 'Видалити фото';

  @override
  String get profileSectionTitle => 'Профіль';

  @override
  String get myNicknameLabel => 'Мій нікнейм';

  @override
  String get myNicknameHint => 'наприклад, Олексій';

  @override
  String get includeNicknameInQr => 'Додавати нікнейм до мого QR';

  @override
  String get includeNicknameInQrSubtitle => 'Типово вимкнено для приватності. Якщо ввімкнути, сканери можуть автоматично назвати вас.';

  @override
  String verifyTitle(Object title) {
    return 'Перевірка: $title';
  }

  @override
  String get scanVerifyQrTitle => 'Сканувати QR для перевірки';

  @override
  String qrBelongsAnotherServer(Object server) {
    return 'QR належить іншому серверу: $server';
  }

  @override
  String get qrSecretlyIdMismatch => 'Secretly ID з QR не збігається з цим контактом';

  @override
  String get qrMissingDeviceKeyInfo => 'У QR немає даних пристрою/ключа';

  @override
  String get deviceNotCachedTapRefresh => 'Пристрій не кешовано. Спершу натисніть «Оновити».';

  @override
  String get identityKeyMismatch => 'Невідповідність identity key. Не підтверджуйте.';

  @override
  String get verifiedSuccess => 'Перевірено ✅';

  @override
  String get refreshKeys => 'Оновити Keys';

  @override
  String get keysOfflineCannotFetch => 'Сервіс Keys офлайн. Зараз неможливо отримати ключі контакту.';

  @override
  String get devicesLabel => 'Пристрої';

  @override
  String get noDeviceKeysCachedYet => 'Ключі пристроїв ще не кешовано.';

  @override
  String deviceTitle(Object deviceId) {
    return 'Пристрій $deviceId';
  }

  @override
  String deviceFpStatus(Object fp, Object status) {
    return 'fp: $fp\n$status';
  }

  @override
  String get verifiedLower => 'перевірено';

  @override
  String get unverifiedLower => 'не перевірено';

  @override
  String get keysOfflineIdTemporary => 'Сервіс Keys офлайн. ID може бути тимчасовим у режимі розробки.';

  @override
  String get serverKeysLabel => 'Сервер (Keys)';

  @override
  String get nicknameLabel => 'Нікнейм';

  @override
  String get identityFingerprintLabel => 'Відбиток ідентичності';

  @override
  String get scanToAddVerifyContact => 'Скануйте, щоб додати або перевірити цей контакт';

  @override
  String get mySecretlyId => 'Мій Secretly ID';

  @override
  String get deviceId => 'ID пристрою';

  @override
  String get recoveryKit => 'Recovery Kit';

  @override
  String get safeBackupTitle => 'Safe Backup';

  @override
  String get safeBackupSubtitle => 'Зашифрована резервна копія Safe Backup на сервері';

  @override
  String get safeBackupIntro => 'Створіть зашифровану резервну копію локально або на сервері. Пізніше її можна відновити з файлу або за Secretly ID.';

  @override
  String get safeBackupUploadNow => 'Завантажити резервну копію зараз';

  @override
  String get safeBackupRestoreFromServer => 'Відновити із сервера';

  @override
  String get safeBackupRestoreTitle => 'Відновлення з резервної копії на сервері';

  @override
  String get safeBackupRestoreConfirmTitle => 'Відновити акаунт?';

  @override
  String get safeBackupRestoreConfirmBody => 'Це видалить локальні чати/контакти на цьому пристрої та відновить акаунт із вибраної резервної копії. Застосунок автоматично перезапуститься.';

  @override
  String get safeBackupUploaded => 'Резервну копію завантажено';

  @override
  String get safeBackupUploadFailed => 'Не вдалося завантажити резервну копію';

  @override
  String safeBackupUploadFailedWithError(Object error) {
    return 'Не вдалося завантажити резервну копію: $error';
  }

  @override
  String get safeBackupNotFound => 'Для цього Secretly ID на сервері не знайдено резервної копії';

  @override
  String get exportRecoveryKit => 'Експортувати Recovery Kit';

  @override
  String get exportRecoveryKitSubtitle => 'Зашифрований QR для відновлення акаунта';

  @override
  String get restoreRecoveryKit => 'Відновити з Recovery Kit';

  @override
  String get restoreRecoveryKitSubtitle => 'Стирає локальні дані та відновлює цей Secretly ID';

  @override
  String get recoveryPasswordTitle => 'Пароль Recovery Kit';

  @override
  String get password => 'Пароль';

  @override
  String get confirmPassword => 'Підтвердьте пароль';

  @override
  String get export => 'Експортувати';

  @override
  String get scanQr => 'Сканувати QR';

  @override
  String get invalidRecoveryKit => 'Недійсний Recovery Kit';

  @override
  String get wrongPassword => 'Неправильний пароль';

  @override
  String get restoreConfirmTitle => 'Відновити акаунт?';

  @override
  String get restoreConfirmBody => 'Це видалить локальні чати/контакти на цьому пристрої та відновить акаунт із Recovery Kit.';

  @override
  String get restore => 'Відновити';

  @override
  String get darkTheme => 'Темна тема';

  @override
  String get darkThemeSubtitle => 'Використовувати той самий акцентний відтінок у темному режимі.';

  @override
  String get blockUnverified => 'Блокувати надсилання неперевіреним контактам';

  @override
  String get blockUnverifiedSubtitle => 'Суворий режим: в особистому листуванні писати лише тим, чиї ключі ви звірили особисто. На групи не поширюється.';

  @override
  String get blockedUsers => 'Заблоковані користувачі';

  @override
  String get resetProfile => 'Скинути профіль';

  @override
  String get resetProfileSubtitle => 'Виправити невідповідність сервера/акаунта, створивши новий Secretly ID';

  @override
  String get resetProfileDialogTitle => 'Скинути профіль?';

  @override
  String get resetProfileDialogBody => 'Це видалить локальні чати/контакти/запити на цьому пристрої та створить новий Secretly ID.\n\nВикористовуйте це, якщо ви змінили APK/сервер і повідомлення перестали надсилатися.';

  @override
  String get cancel => 'Скасувати';

  @override
  String get ok => 'OK';

  @override
  String get add => 'Додати';

  @override
  String get delete => 'Видалити';

  @override
  String get clear => 'Очистити';

  @override
  String get block => 'Заблокувати';

  @override
  String get unblock => 'Розблокувати';

  @override
  String get accept => 'Прийняти';

  @override
  String get verify => 'Перевірити';

  @override
  String get menu => 'Меню';

  @override
  String get search => 'Пошук';

  @override
  String get queryLabel => 'Запит';

  @override
  String get messageHint => 'Повідомлення';

  @override
  String get notificationActionMarkRead => 'Позначити прочитаним';

  @override
  String get addCaption => 'Додати підпис';

  @override
  String get uploadCanceled => 'Завантаження скасовано';

  @override
  String get attachmentFinalizeTimeout => 'Мережа нестабільна: файл завантажено, але час очікування підтвердження надсилання минув. Спробуйте ще раз.';

  @override
  String get attachmentTransferUnavailable => 'Зараз не вдалося передати вкладення. Перевірте інтернет/сервер і спробуйте ще раз.';

  @override
  String get attachmentSendUnavailable => 'Надсилання вкладень ще не готове. Спробуйте ще раз.';

  @override
  String get attachmentContactSyncPending => 'Очікується синхронізація ідентичності контакту. Попросіть контакт надіслати ще одне повідомлення й повторіть спробу.';

  @override
  String get attachmentContactBlocked => 'Цей контакт заблоковано.';

  @override
  String get attachmentRecipientNotFound => 'Профіль отримувача не знайдено на цьому сервері. Перевірте Secretly ID і переконайтеся, що обидва пристрої використовують той самий сервер.';

  @override
  String get attachmentRecipientNoDevices => 'В отримувача ще немає зареєстрованих пристроїв. Попросіть контакт відкрити Secretly і спробуйте ще раз.';

  @override
  String get attachmentNoDeliverableDevices => 'Не вдалося доставити вкладення на жоден пристрій отримувача. Спробуйте ще раз.';

  @override
  String get attachmentActionGeneric => 'Не вдалося надіслати вкладення. Спробуйте ще раз.';

  @override
  String get send => 'Надіслати';

  @override
  String get attach => 'Прикріпити';

  @override
  String get photo => 'Фото';

  @override
  String get video => 'Відео';

  @override
  String get file => 'Файл';

  @override
  String get music => 'Музика';

  @override
  String get attachment => 'Вкладення';

  @override
  String get downloading => 'Завантаження…';

  @override
  String downloadFailed(Object error) {
    return 'Не вдалося завантажити: $error';
  }

  @override
  String savedTo(Object path) {
    return 'Збережено в: $path';
  }

  @override
  String get noMessagesYet => 'Повідомлень поки немає';

  @override
  String get decrypting => 'Розшифрування…';

  @override
  String get uploading => 'Завантаження…';

  @override
  String get uploadTimedOut => 'Час очікування завантаження минув. Перевірте інтернет/сервер і спробуйте ще раз.';

  @override
  String uploadingBytes(Object sent, Object total) {
    return 'Завантажено $sent / $total байт';
  }

  @override
  String get requestsInfo => 'Цей чат у запитах. Прийміть його, щоб відповісти, або заблокуйте, щоб ігнорувати.';

  @override
  String get verifyRequired => 'Потрібна перевірка';

  @override
  String get verifyContact => 'Перевірити контакт';

  @override
  String get muteNotifications => 'Вимкнути сповіщення';

  @override
  String get unmuteNotifications => 'Увімкнути сповіщення';

  @override
  String get setContactPhoto => 'Установити фото контакту';

  @override
  String get removeContactPhoto => 'Видалити фото контакту';

  @override
  String get blockUser => 'Заблокувати користувача';

  @override
  String get unblockUser => 'Розблокувати користувача';

  @override
  String get deleteChat => 'Видалити чат';

  @override
  String get missingRecipient => 'Немає отримувача';

  @override
  String get contactNotVerified => 'Код безпеки співрозмовника змінився. Перевірте його, щоб писати далі.';

  @override
  String get safetyNumberChangedTitle => 'Код безпеки змінився';

  @override
  String get safetyNumberChangedBody => 'Раніше ви звіряли код із цією людиною. Зараз у неї нові ключі — зазвичай так буває після перевстановлення застосунку або зміни телефону. Листування в будь-якому разі залишається зашифрованим. Звірте код знову, якщо хочете переконатися, що це все ще вона.';

  @override
  String get safetyNumberStrictBody => 'У вас увімкнено «Блокувати надсилання неперевіреним». Звірте код цієї людини, щоб надсилати їй повідомлення.';

  @override
  String get sendAnyway => 'Надіслати все одно';

  @override
  String get alsoDeleteChat => 'Також видалити чат';

  @override
  String get unblockUserConfirmTitle => 'Розблокувати користувача?';

  @override
  String get blockUserConfirmTitle => 'Заблокувати користувача?';

  @override
  String get deleteChatConfirmTitle => 'Видалити чат?';

  @override
  String get deleteChatConfirmBody => 'Це видалить чат лише з цього пристрою.';

  @override
  String attachFailed(Object error) {
    return 'Не вдалося прикріпити: $error';
  }

  @override
  String sendFailed(Object error) {
    return 'Не вдалося надіслати: $error';
  }

  @override
  String actionFailed(Object error) {
    return 'Не вдалося виконати дію: $error';
  }

  @override
  String get roomPolicyNotMember => 'Ви більше не учасник цієї кімнати.';

  @override
  String get roomPolicyAdminsOnly => 'У цій кімнаті це можуть робити лише власники та адміністратори.';

  @override
  String get roomPolicyTextMessagesDisabled => 'Ваша роль не може надсилати текстові повідомлення в цій кімнаті.';

  @override
  String get roomPolicyMediaDisabled => 'Ваша роль не може надсилати медіа в цій кімнаті.';

  @override
  String get roomPolicyReactionsDisabled => 'Реакції в цій кімнаті вимкнено.';

  @override
  String get roomPolicyReactionNotAllowed => 'Ця реакція недоступна в цій кімнаті.';

  @override
  String get roomPolicyPinDenied => 'Лише адміністратори можуть закріплювати повідомлення в цій кімнаті.';

  @override
  String get roomPolicyAddMembersDenied => 'Лише адміністратори можуть додавати учасників до цієї кімнати.';

  @override
  String get roomPolicyChangeInfoDenied => 'Лише адміністратори можуть змінювати профіль групи.';

  @override
  String roomPolicySlowMode(Object seconds) {
    return 'Увімкнено повільний режим. Спробуйте ще раз через $seconds с.';
  }

  @override
  String get noMatches => 'Збігів немає';

  @override
  String attachmentTooLarge(Object mb) {
    return 'Вкладення завелике ($mb МБ).';
  }

  @override
  String get attachmentFileMissing => 'Файл більше недоступний.';

  @override
  String foundPrefix(Object hit) {
    return 'Знайдено: $hit';
  }

  @override
  String get contactDetailsChat => 'Чат';

  @override
  String get contactDetailsSound => 'Звук';

  @override
  String get contactDetailsCall => 'Дзвінок';

  @override
  String get contactDetailsVideo => 'Відео';

  @override
  String get contactDetailsUsernameLabel => 'Ім’я користувача';

  @override
  String get contactDetailsAddToContacts => 'Додати до контактів';

  @override
  String get contactDetailsMediaTab => 'Медіа';

  @override
  String get contactDetailsFilesTab => 'Файли';

  @override
  String get contactDetailsNoMedia => 'Немає медіа';

  @override
  String get contactDetailsNoFiles => 'Немає файлів';

  @override
  String get contactDetailsStatusRecently => 'був(-ла) нещодавно';

  @override
  String contactDetailsStatusAt(Object time) {
    return 'був(-ла) о $time';
  }

  @override
  String get contactDetailsAutoDelete => 'Автовидалення';

  @override
  String get contactDetailsShareContact => 'Поділитися контактом';

  @override
  String get contactDetailsEditContact => 'Редагувати контакт';

  @override
  String get contactDetailsDeleteContact => 'Видалити контакт';

  @override
  String get contactDetailsSendGift => 'Надіслати подарунок';

  @override
  String get contactDetailsStartSecretChat => 'Почати секретний чат';

  @override
  String get contactDetailsCreateShortcut => 'Створити ярлик';

  @override
  String get contactDetailsNameLabel => 'Ім’я';

  @override
  String get contactDetailsSave => 'Зберегти';

  @override
  String get contactDetailsDeleteConfirmTitle => 'Видалити контакт?';

  @override
  String get contactAutoDeleteOff => 'Вимкнено';

  @override
  String get contactAutoDelete1Day => '24 години';

  @override
  String get contactAutoDelete7Days => '7 днів';

  @override
  String get contactAutoDelete30Days => '30 днів';

  @override
  String get contactEditTitle => 'Редагувати контакт';

  @override
  String get contactEditDone => 'ГОТОВО';

  @override
  String get contactEditNameLabel => 'Ім’я';

  @override
  String get contactEditAssignEmoji => 'Призначити емодзі';

  @override
  String get contactEditClearEmoji => 'Очистити емодзі';

  @override
  String get contactEditSetPhoto => 'Установити фото';

  @override
  String get chatMenuReply => 'Відповісти';

  @override
  String get chatMenuCopy => 'Копіювати';

  @override
  String get chatMenuForward => 'Переслати';

  @override
  String get chatMenuPin => 'Закріпити';

  @override
  String get chatMenuDelete => 'Видалити';

  @override
  String get reset => 'Скинути';

  @override
  String get diagnostics => 'Діагностика';

  @override
  String get diagnosticsSubtitle => 'Статус, прив’язка, часові мітки';

  @override
  String get sendLater => 'Надіслати пізніше';

  @override
  String get sendSilently => 'Надіслати без звуку';

  @override
  String scheduledSendToday(Object time) {
    return 'Надіслати сьогодні о $time';
  }

  @override
  String scheduledSendOn(Object date, Object time) {
    return 'Надіслати $date о $time';
  }

  @override
  String get repeatNever => 'Ніколи';

  @override
  String get repeat => 'Повторювати';

  @override
  String get onboardingBackTooltip => 'Назад';

  @override
  String get onboardingWelcomeTitle => 'Вітаємо!';

  @override
  String get onboardingWelcomeSubtitle => 'Месенджер нового покоління.\nПовна приватність. Без компромісів.';

  @override
  String get onboardingCreateAccount => 'Створити новий акаунт';

  @override
  String get onboardingAlreadyHaveAccount => 'Уже є акаунт';

  @override
  String get onboardingFeatureE2eTitle => 'E2E-шифрування';

  @override
  String get onboardingFeatureE2eBody => 'Повідомлення шифруються на вашому пристрої. Ключі є лише у вас.';

  @override
  String get onboardingFeaturePrivacyTitle => 'Повна анонімність';

  @override
  String get onboardingFeaturePrivacyBody => 'Без номера телефону. Без прив’язки до особистих даних.';

  @override
  String get onboardingFeatureRelayTitle => 'Без посередників';

  @override
  String get onboardingFeatureRelayBody => 'Relay-сервер не зберігає повідомлення. Він лише передає їх.';

  @override
  String get onboardingProfileTitle => 'Ваш профіль';

  @override
  String get onboardingProfileSubtitle => 'Як вас бачитимуть інші користувачі';

  @override
  String get onboardingProfileNameSection => 'Ім’я профілю';

  @override
  String get onboardingProfileNameHint => 'Ваше ім’я або псевдонім';

  @override
  String get onboardingNotificationsSection => 'Сповіщення';

  @override
  String get onboardingMessageNotificationsTitle => 'Сповіщення про повідомлення';

  @override
  String get onboardingMessageNotificationsSubtitle => 'Отримувати push-сповіщення від Secretly';

  @override
  String get onboardingIncomingCallsTitle => 'Вхідні дзвінки';

  @override
  String get onboardingIncomingCallsSubtitle => 'Приймати дзвінки від контактів';

  @override
  String get continueAction => 'Продовжити';

  @override
  String get onboardingBackupSaveFailed => 'Не вдалося зберегти налаштування резервної копії';

  @override
  String get backupPasswordRequirements => 'Мінімум 8 символів, латиниця/ASCII, одна велика літера та один спецсимвол. Без пробілів на початку або в кінці.';

  @override
  String backupPasswordTooShort(Object minLength) {
    return 'Пароль має містити щонайменше $minLength символів.';
  }

  @override
  String backupPasswordTooLong(Object maxLength) {
    return 'Пароль має містити не більше $maxLength символів.';
  }

  @override
  String get backupPasswordNonAscii => 'Використовуйте лише латинські літери, цифри та ASCII-символи.';

  @override
  String get backupPasswordOuterWhitespace => 'Приберіть пробіли на початку або в кінці пароля.';

  @override
  String get backupPasswordMissingUppercase => 'Додайте хоча б одну велику літеру A-Z.';

  @override
  String get backupPasswordMissingSpecial => 'Додайте хоча б один спецсимвол, наприклад !, # або ?.';

  @override
  String get onboardingBackupPasswordTitle => 'Пароль резервної копії';

  @override
  String get onboardingPasswordsDoNotMatch => 'Паролі не збігаються';

  @override
  String get onboardingBackupTitle => 'Резервні копії';

  @override
  String get onboardingBackupSubtitle => 'Захистіть листування від втрати даних.\nНавіть під час зміни пристрою.';

  @override
  String get onboardingAutoBackupSection => 'Автоматична резервна копія';

  @override
  String get onboardingAutoBackupTitle => 'Автокопія';

  @override
  String get onboardingAutoBackupSubtitle => 'Автоматично зберігати резервну копію';

  @override
  String get onboardingStorageTypeSection => 'Тип сховища';

  @override
  String get onboardingBackupMediaTitle => 'Резервувати медіа';

  @override
  String get onboardingBackupMediaSubtitle => 'Фото, відео, файли та аватари додаються лише до локальних резервних копій';

  @override
  String get onboardingFrequencySection => 'Частота';

  @override
  String get onboardingEnterSecretly => 'Увійти в Secretly';

  @override
  String get onboardingSkipBackup => 'Пропустити налаштування резервної копії';

  @override
  String get onboardingSecretlyIdCopied => 'Secretly ID скопійовано';

  @override
  String get onboardingRegistrationCompleteTitle => 'Реєстрацію завершено';

  @override
  String get onboardingRegistrationCompleteSubtitle => 'Збережіть свій Secretly ID зараз. Він потрібен для відновлення акаунта й резервної копії на новому пристрої.';

  @override
  String get onboardingYourSecretlyId => 'Ваш Secretly ID';

  @override
  String get onboardingCopyId => 'Скопіювати ID';

  @override
  String get onboardingRecoveryWarning => 'Без Secretly ID і пароля резервної копії відновити серверну копію буде неможливо. Збережіть ID у надійному місці й не забувайте пароль.';

  @override
  String get onboardingStorageCloud => 'Хмара';

  @override
  String get onboardingStorageCloudSubtitle => 'На сервері Secretly';

  @override
  String get onboardingStorageLocal => 'Локально';

  @override
  String get onboardingStorageLocalSubtitle => 'На цьому пристрої';

  @override
  String get onboardingInterval6Hours => '6 годин';

  @override
  String get onboardingInterval12Hours => '12 годин';

  @override
  String get onboardingIntervalEveryDay => 'Щодня';

  @override
  String get onboardingIntervalEvery3Days => 'Кожні 3 дні';

  @override
  String get onboardingIntervalWeekly => 'Раз на тиждень';

  @override
  String get onboardingBackupLocalCandidate => 'Локальна резервна копія Secretly';

  @override
  String get onboardingDownloads => 'Завантаження';

  @override
  String get onboardingDeviceFolder => 'Папка пристрою';

  @override
  String get onboardingNoBackupsFound => 'Резервні копії на пристрої не знайдено';

  @override
  String get onboardingFoundBackups => 'Знайдені резервні копії';

  @override
  String get onboardingNoBackupsFoundBody => 'Secretly перевірив локальні резервні копії застосунку та папку Завантаження. Якщо файл в іншому місці, виберіть його вручну.';

  @override
  String get chooseManually => 'Вибрати вручну';

  @override
  String get onboardingChooseBackupFileTitle => 'Виберіть файл резервної копії Secretly';

  @override
  String get onboardingReadBackupFailed => 'Не вдалося прочитати файл резервної копії';

  @override
  String get onboardingServerBackupNotFound => 'Резервну копію не знайдено на сервері';

  @override
  String get onboardingRestoreThisBackupTitle => 'Відновити цю резервну копію?';

  @override
  String get onboardingRestoreThisBackupBody => 'Поточні локальні дані на цьому пристрої буде замінено.';

  @override
  String onboardingSecretlyIdSummary(Object profileId) {
    return 'Secretly ID: $profileId';
  }

  @override
  String onboardingContactsSummary(Object count) {
    return 'Контакти: $count';
  }

  @override
  String onboardingMessagesSummary(Object count) {
    return 'Повідомлення: $count';
  }

  @override
  String onboardingChatsSummary(Object count) {
    return 'Чати: $count';
  }

  @override
  String onboardingMediaFilesSummary(Object count) {
    return 'Медіафайли: $count';
  }

  @override
  String get onboardingBrokenBackup => 'Пошкоджений або неправильний файл резервної копії';

  @override
  String get onboardingRestoreFailed => 'Не вдалося відновити. Спробуйте ще раз.';

  @override
  String get onboardingRestoreLoginTitle => 'Увійти в акаунт';

  @override
  String get onboardingRestoreLoginSubtitle => 'Відновіть листування й налаштування\nз раніше створеної резервної копії.';

  @override
  String get onboardingRestoreMediaSubtitle => 'Для майбутніх локальних резервних копій: фото, відео, файли й аватари додаватимуться лише якщо це ввімкнено.';

  @override
  String get onboardingRestoreFromCloudTitle => 'З хмари Secretly';

  @override
  String get onboardingRestoreFromCloudSubtitle => 'Введіть Secretly ID і пароль резервної копії — дані завантажаться із сервера';

  @override
  String get onboardingRestoreFromDeviceTitle => 'Знайти резервну копію на пристрої';

  @override
  String get onboardingRestoreFromDeviceSubtitle => 'Secretly сам перевірить локальні резервні копії та Завантаження';

  @override
  String get onboardingRestoring => 'Відновлення...';

  @override
  String get onboardingRestoreFromServerTitle => 'Відновити із сервера';

  @override
  String get callRecordOutgoingVideoCall => 'Вихідний відеодзвінок';

  @override
  String get callRecordOutgoingCall => 'Вихідний дзвінок';

  @override
  String get callRecordIncomingVideoCall => 'Вхідний відеодзвінок';

  @override
  String get callRecordIncomingCall => 'Вхідний дзвінок';

  @override
  String get callRecordMissedCall => 'Пропущений дзвінок';

  @override
  String get callRecordDeclinedCall => 'Дзвінок відхилено';

  @override
  String get callRecordBusy => 'Абонент зайнятий';

  @override
  String get callRecordFailed => 'Помилка зв’язку';

  @override
  String get callRecordCanceled => 'Дзвінок скасовано';

  @override
  String get callRecordOngoing => 'Дзвінок триває';

  @override
  String get safeBackupInvalidBackup => 'Некоректна резервна копія Secretly';

  @override
  String get recoveryKitPrepareFailed => 'Не вдалося підготувати Recovery Kit на цьому пристрої.';

  @override
  String safeBackupPreviewProfileId(String profileId) {
    return 'ID у Secretly: $profileId';
  }

  @override
  String safeBackupPreviewContacts(int count) {
    return 'Контакти: $count';
  }

  @override
  String safeBackupPreviewServer(String server) {
    return 'Сервер: $server';
  }

  @override
  String get safeBackupPreviewTitle => 'Що буде відновлено:';

  @override
  String get safeBackupSavedToFiles => 'Резервну копію збережено у файли Secretly';

  @override
  String get safeBackupExportCanceled => 'Експорт резервної копії скасовано';

  @override
  String safeBackupExportFailed(Object error) {
    return 'Не вдалося експортувати резервну копію: $error';
  }

  @override
  String get safeBackupCreateDialogTitle => 'Створити резервну копію';

  @override
  String get safeBackupServerDestination => 'Резервна копія на сервер';

  @override
  String get safeBackupLocalDestination => 'Локальна резервна копія';

  @override
  String get safeBackupRestoreDialogTitle => 'Відновити резервну копію';

  @override
  String get safeBackupRestoreFromDevice => 'Відновити з пристрою';

  @override
  String get safeBackupDownloadsLocation => 'Завантаження';

  @override
  String get safeBackupDeviceFolderLocation => 'Папка пристрою';

  @override
  String get safeBackupChooseManualHint => 'Secretly автоматично перевірив локальні резервні копії застосунку та папку Завантаження. Якщо файл збережено в іншому місці, можна вибрати його вручну.';

  @override
  String get safeBackupChooseManually => 'Вибрати вручну';

  @override
  String safeBackupReadFileFailed(Object error) {
    return 'Не вдалося прочитати файл резервної копії: $error';
  }

  @override
  String get safeBackupFrequencyTitle => 'Частота збереження';

  @override
  String get saveAction => 'Зберегти';

  @override
  String get safeBackupEnableAutoTitle => 'Увімкнути автокопію';

  @override
  String get safeBackupEnableAutoSubtitle => 'Працює в застосунку за наявності мережі; шифрується вашим паролем';

  @override
  String get safeBackupUploadToServer => 'Завантажувати на сервер';

  @override
  String get safeBackupSaveOnDevice => 'Зберігати на цьому пристрої';

  @override
  String get safeBackupPasswordConfigured => 'Пароль автокопії: налаштовано';

  @override
  String get safeBackupPasswordNotSet => 'Пароль автокопії: не задано';

  @override
  String get safeBackupPasswordSaved => 'Пароль автокопії збережено';

  @override
  String genericFailed(Object error) {
    return 'Помилка: $error';
  }

  @override
  String get safeBackupSetPassword => 'Задати пароль';

  @override
  String get safeBackupPasswordRemoved => 'Пароль автокопії видалено';

  @override
  String get safeBackupClearPassword => 'Видалити пароль';

  @override
  String get safeBackupRunRequested => 'Автокопію запущено';

  @override
  String get safeBackupRunNow => 'Запустити автокопію зараз';

  @override
  String safeBackupLastAutoBackup(String time) {
    return 'Остання автокопія: $time';
  }

  @override
  String get safeBackupLastAutoBackupNever => 'Остання автокопія: ніколи';

  @override
  String safeBackupLastDeviceBackup(String time) {
    return 'Остання резервна копія на пристрої: $time';
  }

  @override
  String safeBackupLastAutoBackupError(Object error) {
    return 'Помилка автокопії: $error';
  }

  @override
  String get securityScopeAppObject => 'застосунок';

  @override
  String get securityScopePersonalObject => 'Особисті чати';

  @override
  String get securityUnlockAppTitle => 'Розблокуйте застосунок';

  @override
  String get securityUnlockPersonalTitle => 'Розблокуйте Особисті чати';

  @override
  String get securityUnlockFingerprintAutoSubtitle => 'Розблокування відбитком запускається автоматично. За потреби нижче можна використати пароль.';

  @override
  String get securityUnlockBiometricPatternAutoSubtitle => 'Спочатку запускається нативна біометрія. За потреби нижче можна відкрити екран графічного ключа.';

  @override
  String get securityUnlockNativeSubtitle => 'Підтвердьте доступ через нативну автентифікацію пристрою.';

  @override
  String securityUnlockPasswordSubtitle(String scopeName) {
    return 'Введіть пароль, щоб відкрити $scopeName.';
  }

  @override
  String securityUnlockPatternSubtitle(String scopeName) {
    return 'Намалюйте графічний ключ для доступу до $scopeName.';
  }

  @override
  String get securityUnlockBiometricSubtitle => 'Підтвердьте особу через нативну автентифікацію пристрою.';

  @override
  String get securityUnlockAppBiometricReason => 'Підтвердьте особу, щоб розблокувати застосунок';

  @override
  String get securityUnlockPersonalBiometricReason => 'Підтвердьте особу, щоб відкрити Особисті чати';

  @override
  String get securityUnlockPasswordMismatch => 'Пароль не збігається. Спробуйте ще раз.';

  @override
  String get securityUnlockPatternMismatch => 'Графічний ключ не збігається.';

  @override
  String get securityUnlockNativeIncomplete => 'Нативну автентифікацію не завершено.';

  @override
  String get securityPasswordContinueHint => 'Введіть пароль, щоб продовжити';

  @override
  String get securityUseFingerprint => 'Увійти за відбитком';

  @override
  String get securityUsePassword => 'Використати пароль';

  @override
  String get securityClearPattern => 'Скинути ключ';

  @override
  String get securityConnectFourDots => 'З’єднайте щонайменше 4 точки.';

  @override
  String get securityPasswordMinFourChars => 'Мінімум 4 символи.';

  @override
  String get securityPasswordsMismatchFull => 'Паролі не збігаються.';

  @override
  String securityPasswordSetupTitle(String scopeName) {
    return 'Пароль для $scopeName';
  }

  @override
  String get securityPasswordSetupDescription => 'Пароль зберігається лише в захищеному сховищі пристрою.';

  @override
  String get securityNewPassword => 'Новий пароль';

  @override
  String get securityRepeatPassword => 'Повторіть пароль';

  @override
  String get securitySavePassword => 'Зберегти пароль';

  @override
  String get securityPatternSetupInstruction => 'Намалюйте графічний ключ щонайменше з 4 точок.';

  @override
  String get securityPatternSetupRepeat => 'Повторіть графічний ключ для підтвердження.';

  @override
  String get securityPatternMinFourDots => 'Мінімум 4 точки.';

  @override
  String get securityPatternMismatchStartOver => 'Ключі не збіглися. Почніть заново.';

  @override
  String securityPatternSetupTitle(String scopeName) {
    return 'Графічний ключ для $scopeName';
  }

  @override
  String get securityStartOver => 'Почати заново';

  @override
  String get securityTitle => 'Безпека';

  @override
  String get securityNativeAuthentication => 'Нативна автентифікація';

  @override
  String get securityReady => 'Готово';

  @override
  String get securityUnavailable => 'Недоступно';

  @override
  String get securityNativeAvailableDescription => 'Використовується для Face ID, відбитка пальця та системної автентифікації пристрою.';

  @override
  String get securityNativeUnavailableDescription => 'Біометрія або системна автентифікація зараз недоступні на цьому пристрої.';

  @override
  String get securityAppLockTitle => 'Вхід у застосунок';

  @override
  String get securityAppLockDescription => 'Захищає вхід у застосунок і може повторно блокувати після приховування застосунку.';

  @override
  String get securityPersonalChatsTitle => 'Особисті чати';

  @override
  String get securityPersonalChatsDescription => 'Захищає прихований розділ Особисті та прямий вхід в особисті чати.';

  @override
  String get securityAuthEnableAppLockReason => 'Підтвердьте біометрію, щоб увімкнути захист входу в застосунок';

  @override
  String get securityAuthChangeSettingsReason => 'Підтвердьте біометрію, щоб змінити налаштування безпеки';

  @override
  String get securityAuthProtectPersonalReason => 'Підтвердьте біометрію, щоб захистити Особисті чати';

  @override
  String get securityAuthChangePersonalReason => 'Підтвердьте біометрію, щоб змінити захист Особистих чатів';

  @override
  String get securityNativeUnavailableError => 'Нативна автентифікація недоступна на цьому пристрої.';

  @override
  String get securityBiometricCancelled => 'Біометричне підтвердження скасовано.';

  @override
  String get securityProtectionMode => 'Режим захисту';

  @override
  String get securityProtectionModeSubtitle => 'Виберіть, як захищати доступ.';

  @override
  String get securityProtectionModeDescription => 'Паролі та графічні ключі зберігаються лише як стійкі хеші в secure storage. Біометрія використовує нативний системний екран.';

  @override
  String get securityProtectionOff => 'Вимкнено';

  @override
  String get securityProtectionOffDescription => 'Доступ без додаткового захисту.';

  @override
  String get securityPasswordModeDescription => 'Окремий пароль для розблокування доступу.';

  @override
  String get securityPatternModeTitle => 'Графічний ключ';

  @override
  String get securityPatternModeDescription => 'Рисунок із точок, як у блокуванні Android.';

  @override
  String get securityNativePromptDescription => 'Нативний системний екран Face ID, відбитка пальця або системної автентифікації пристрою.';

  @override
  String get securityRelockAfterHidden => 'Блокувати після приховування застосунку';

  @override
  String get securityRelockAfterHiddenDescription => 'Якщо вимкнено, захист повертається лише після повного перезапуску застосунку.';

  @override
  String get securityGracePeriod => 'Затримка перед повторним блокуванням';

  @override
  String get securityGraceUnavailable => 'Недоступно, коли фонове блокування вимкнено.';

  @override
  String securityAllowQuickUnlockWith(String method) {
    return 'Дозволити швидке розблокування через $method';
  }

  @override
  String get securityQuickUnlockSubtitle => 'Пароль або графічний ключ залишаються основним резервним способом.';

  @override
  String get securityChangePassword => 'Змінити пароль';

  @override
  String get securityChangePattern => 'Змінити графічний ключ';

  @override
  String get securityChangeCredentialSubtitle => 'Поточний захист оновиться одразу після підтвердження нового секрету.';

  @override
  String get securityProtectionActivated => 'Захист активовано одразу.';

  @override
  String get securityLockNow => 'Заблокувати зараз';

  @override
  String get securitySaveChanges => 'Зберегти';

  @override
  String get securityGraceImmediately => 'Одразу';

  @override
  String securityGraceAfterSeconds(int seconds) {
    return 'Через $seconds с';
  }

  @override
  String securityGraceAfterMinutes(int minutes) {
    return 'Через $minutes хв';
  }

  @override
  String get securityStatusLocked => 'Заблоковано';

  @override
  String get securityStatusUnlocked => 'Розблоковано';

  @override
  String get securityAfterHide => 'Одразу після приховування';

  @override
  String securityGracePill(int seconds) {
    return 'Затримка $seconds с';
  }

  @override
  String get securityNoProtection => 'Без захисту';

  @override
  String get securityNativeBiometrics => 'Нативна біометрія';

  @override
  String get securityBiometricFaceFingerprint => 'Face ID / відбиток';

  @override
  String get securityBiometricFingerprint => 'Відбиток пальця';

  @override
  String get securityBiometricNativeDeviceAuthentication => 'Системна автентифікація';

  @override
  String get devicesLinkOpenFailed => 'Не вдалося відкрити посилання в браузері.';

  @override
  String get devicesDesktopDescriptionPrefix => 'Ви можете увійти в ';

  @override
  String get devicesDesktopAppLink => 'Secretly для комп’ютера';

  @override
  String get devicesDesktopDescriptionSuffix => ' за допомогою QR-коду.';

  @override
  String get devicesFailureTransportBlocked => 'Транспорт заблоковано для поточного сервера. Перемкніть телефон і desktop на один сервер і повторіть.';

  @override
  String get devicesFailureIdentityNotServerBacked => 'Desktop-профіль ще не зареєстровано на сервері. Повторіть за кілька секунд.';

  @override
  String get devicesFailureProfileUnavailable => 'Desktop-профіль ще не видно на сервері. Тримайте застосунок відкритим і повторіть.';

  @override
  String get devicesFailureDeviceUnavailable => 'Desktop-пристрій ще не видно на сервері. Тримайте застосунок відкритим, оновіть QR і повторіть.';

  @override
  String get devicesFailureCompanionRequired => 'Для цього профілю не ввімкнено desktop companion. Активуйте доступ на основному телефоні й повторіть.';

  @override
  String get devicesFailureCompanionLimit => 'Ліміт desktop-пристроїв для цього профілю вже використано. Видаліть старий desktop-пристрій або збільште кількість місць.';

  @override
  String get devicesFailurePrimaryRequired => 'Спочатку створіть основний акаунт на телефоні, потім підключіть desktop через QR.';

  @override
  String get devicesFailureInvalidQr => 'Це не QR для авторизації пристрою.';

  @override
  String get devicesFailureQrExpired => 'Термін дії QR минув. Створіть новий код на desktop.';

  @override
  String get devicesFailureServerMismatch => 'Цей QR належить іншому серверу. Перемкніть телефон і desktop на один сервер і повторіть.';

  @override
  String get devicesFailureProfileMismatch => 'Пакет синхронізації призначений для іншого профілю. Створіть новий QR і повторіть.';

  @override
  String get devicesFailureRequestNotFound => 'Запит синхронізації не знайдено або він уже минув. Створіть новий QR.';

  @override
  String get devicesFailureSessionExpired => 'Сесія QR минула. Створіть новий QR і повторіть.';

  @override
  String get devicesFailureSessionValidation => 'Перевірка QR-сесії не пройшла. Створіть новий QR і повторіть.';

  @override
  String get devicesFailureStateMismatch => 'Стан запиту синхронізації вже не актуальний. Створіть новий QR і повторіть.';

  @override
  String get devicesFailureDeviceMismatch => 'Пакет синхронізації призначений для іншого пристрою. Створіть новий QR і повторіть.';

  @override
  String get devicesFailureDeclined => 'Вхід відхилено на основному телефоні. Створіть новий QR і повторіть.';

  @override
  String get devicesFailureInvalidPayload => 'Некоректний пакет desktop-синхронізації. Створіть новий QR і повторіть.';

  @override
  String get devicesFailureInterrupted => 'Захищену синхронізацію перервано до завершення. Створіть новий QR і повторіть.';

  @override
  String get devicesNewUser => 'Новий користувач';

  @override
  String get devicesNewUserDesktopConfirm => 'Очистити локальні дані та підготувати цей desktop-пристрій для входу через QR з основного телефона?';

  @override
  String get devicesNewUserMobileConfirm => 'Очистити поточний локальний профіль і зареєструвати нового користувача на цьому пристрої?';

  @override
  String get devicesCreateAction => 'Створити';

  @override
  String get devicesScanDeviceQr => 'Сканувати QR пристрою';

  @override
  String get devicesRequestApproved => 'Запит підтверджено. Пакет синхронізації надіслано на комп’ютер.';

  @override
  String get devicesRequestDeclined => 'Запит відхилено. Desktop залишиться неавторизованим.';

  @override
  String get devicesApproveSignInTitle => 'Дозволити вхід на пристрої?';

  @override
  String get devicesConfirmSyncPrimary => 'Підтвердьте синхронізацію з основного пристрою (телефона).';

  @override
  String devicesApprovalDeviceOnly(String name) {
    return 'Пристрій: $name. Підтвердження дозволено лише з основного телефона.';
  }

  @override
  String get devicesSyncChats => 'Синхронізувати чати';

  @override
  String get devicesSyncSettings => 'Синхронізувати налаштування';

  @override
  String get devicesSyncMedia => 'Синхронізувати медіа';

  @override
  String get devicesDeclineSignIn => 'Відхилити вхід';

  @override
  String get devicesApprove => 'Дозволити';

  @override
  String get devicesTitle => 'Пристрої';

  @override
  String get devicesConnectDevice => 'Підключити пристрій';

  @override
  String get devicesPrimaryDeviceTitle => 'Це основний пристрій';

  @override
  String get devicesPrimaryDeviceSubtitle => 'Дозвіл на синхронізацію чатів, налаштувань і медіа надається лише тут.';

  @override
  String get devicesQrSessionExpiredNewCode => 'Термін дії QR минув. Згенеруйте новий код.';

  @override
  String devicesQrExpiresIn(String time) {
    return 'QR діє ще $time';
  }

  @override
  String get devicesWaitingQrScan => 'Очікування сканування QR на телефоні.';

  @override
  String get devicesQrScannedConfirm => 'QR відскановано. Підтвердьте вхід на телефоні.';

  @override
  String get devicesApplyingSecureBundle => 'Застосовуємо захищений пакет синхронізації…';

  @override
  String get devicesAuthorizationFailed => 'Помилка авторизації. Повторіть спробу.';

  @override
  String get devicesUnauthenticatedChooseAction => 'Ви не авторизовані. Виберіть дію нижче.';

  @override
  String get devicesAuthenticated => 'Пристрій авторизовано.';

  @override
  String get devicesDesktopWebAuthorization => 'Авторизація Desktop/Web';

  @override
  String get devicesDesktopModeDescription => 'Виберіть режим: зареєструвати нового користувача або увійти через QR з підтвердженням на телефоні.';

  @override
  String get devicesCancelQr => 'Скасувати QR';

  @override
  String get devicesRefreshQr => 'Оновити QR';

  @override
  String get devicesSignInViaQr => 'Увійти через QR';

  @override
  String get devicesOpenPrimaryInstruction => 'Відкрийте Secretly на основному телефоні → Налаштування → Пристрої → Підключити пристрій.';

  @override
  String get storageSection => 'Сховище';

  @override
  String get storageSectionSubtitle => 'Кеш і завантаження на цьому пристрої';

  @override
  String get storageUsageTitle => 'Використання памʼяті';

  @override
  String get storageCategoryMedia => 'Кеш медіа';

  @override
  String get storageCategoryVoiceTranscripts => 'Розшифровки голосу';

  @override
  String get storageCategoryVoiceModel => 'Офлайн-модель голосу';

  @override
  String get storageCategoryStickers => 'Стікери';

  @override
  String get storageCategoryEmoji => 'Анімовані емодзі';

  @override
  String get storageCategoryProfileMedia => 'Моя галерея й аватари';

  @override
  String get storageCategoryRecents => 'Нещодавні файли';

  @override
  String get storageTotal => 'Усього';

  @override
  String get storageCalculating => 'Підрахунок…';

  @override
  String get storageClearCache => 'Очистити кеш';

  @override
  String get storageClearCacheHint => 'Видаляє кешовані медіа, аватари співрозмовників та анімовані емодзі. Ваша галерея, стікери й чати зберігаються; медіа завантажиться знову під час перегляду.';

  @override
  String get storageClearing => 'Очищення кешу…';

  @override
  String get storageClearedToast => 'Кеш очищено';

  @override
  String get storageRemoveVoiceModel => 'Видалити офлайн-модель голосу (140 МБ)';

  @override
  String get storageRemoveVoiceModelHint => 'Звільняє модель розпізнавання мовлення на пристрої. Вона завантажиться знову під час наступної розшифровки голосового повідомлення.';

  @override
  String get storageRemoveVoiceModelConfirmTitle => 'Видалити модель голосу?';

  @override
  String get storageRemoveVoiceModelConfirmBody => 'Модель розпізнавання мовлення (140 МБ) буде видалено з пристрою. Вона завантажиться знову під час наступної розшифровки голосового повідомлення.';

  @override
  String get storageRemoveVoiceModelConfirm => 'Видалити';

  @override
  String get storageVoiceModelNotInstalled => 'Модель голосу не встановлено';

  @override
  String get storageVoiceModelRemovedToast => 'Модель голосу видалено';

  @override
  String get backupStateProtected => 'Історію захищено';

  @override
  String get backupStateUnprotected => 'Історію не захищено';

  @override
  String get backupStateFailing => 'Копія не створюється';

  @override
  String get backupStateStale => 'Копія застаріла';

  @override
  String get backupStateNone => 'Копію ще не створено';

  @override
  String backupLastAt(Object time) {
    return 'Остання копія: $time';
  }

  @override
  String get backupIntroHint => 'Копія дозволяє повернути листування на новому пристрої';

  @override
  String get backupAccessUpgradeTitle => 'Збережіть копію ще раз';

  @override
  String get backupAccessUpgradeBody => 'Вашу копію на сервері створено в старому форматі: її можна завантажити, знаючи лише ідентифікатор профілю. Дані всередині зашифровані вашим паролем, але додатковий рубіж не завадить. Повторне збереження додасть перевірку пароля на самому сервері.';

  @override
  String get backupAccessUpgradeAction => 'Зберегти ще раз';

  @override
  String get backupSectionAutomatic => 'Автоматично';

  @override
  String get backupAutoToggle => 'Створювати копії';

  @override
  String get backupPassword => 'Пароль';

  @override
  String get backupPasswordSet => 'Задано';

  @override
  String get backupPasswordNotSet => 'Не задано';

  @override
  String get backupPasswordSaved => 'Пароль збережено';

  @override
  String get backupWhere => 'Куди';

  @override
  String get backupHowOften => 'Як часто';

  @override
  String get backupIncludeMedia => 'Включати медіа';

  @override
  String get backupAutoFooter => 'Копія зашифрована вашим паролем. Без нього відновити її неможливо — збережіть пароль окремо. Медіа не потрапляють у копію на сервері.';

  @override
  String get backupNow => 'Створити копію зараз';

  @override
  String get backupSectionRestore => 'Відновлення';

  @override
  String get backupRestoreAction => 'Відновити з копії';

  @override
  String get backupRestoreFooter => 'Замінить листування та налаштування на цьому пристрої даними з копії.';

  @override
  String get backupSectionKey => 'Ключ Secretly ID';

  @override
  String get backupKeyShow => 'Показати ключ';

  @override
  String get backupKeyRestore => 'Відновити за ключем';

  @override
  String get backupKeyFooter => 'Повертає лише ваш Secretly ID — листування в ключі немає. Відновлення за ключем стирає локальні дані.';

  @override
  String get backupDestServerDevice => 'Сервер і пристрій';

  @override
  String get backupDestServer => 'Сервер';

  @override
  String get backupDestDevice => 'Пристрій';

  @override
  String get backupDestNone => 'Не вибрано';

  @override
  String get backupDestServerOnly => 'Лише сервер';

  @override
  String get backupDestDeviceOnly => 'Лише пристрій';

  @override
  String get backupTileOff => 'Вимкнено — історію не захищено';

  @override
  String get backupTilePending => 'Увімкнено, але ще жодного разу не виконувався';

  @override
  String get backupTileFailing => 'Не виконується — потрібно перевірити';

  @override
  String get backupTileStale => 'Давно не оновлювався';

  @override
  String get backupPasswordChange => 'Змінити пароль';

  @override
  String get backupPasswordRemove => 'Видалити пароль';

  @override
  String get chatUndecryptablePending => 'Повідомлення надійшло, але поки не читається — відновлюємо захищену сесію…';

  @override
  String get liquidGlassTitle => 'Рідке скло';

  @override
  String get liquidGlassSubtitle => 'Панелі та острівці з заломленням. Вимкніть для звичайного матеріалу — він економніший і менше гріє.';

  @override
  String get billingPendingTitle => 'Очікуємо оплату';

  @override
  String get billingPendingBody => 'Замовлення створено, але платіж ще не підтверджено. Завершіть оплату вибраним способом — преміум увімкнеться сам.';

  @override
  String get callsHideAddressTitle => 'Приховувати мою адресу в дзвінках';

  @override
  String get callsHideAddressSubtitle => 'Через наш сервер: співрозмовник не побачить IP-адресу, але затримка може зрости';

  @override
  String get desktopJoinRoomByLink => 'Увійти за посиланням';

  @override
  String get desktopJoinRoomLinkHint => 'Вставте посилання-запрошення';

  @override
  String get desktopJoinRoomLinkInvalid => 'Це не посилання-запрошення до кімнати';

  @override
  String get desktopOfflineLockTitle => 'Пароль після тривалої відсутності зв’язку';

  @override
  String get desktopOfflineLockDescription => 'Комп’ютер не виходив на зв’язок довше за термін — під час запуску попросимо пароль входу. Загублений комп’ютер команди «вимкнути» не отримає, а термін отримає.';

  @override
  String get desktopOfflineLockNever => 'Ніколи';

  @override
  String get desktopOfflineLockDays7 => '7 днів';

  @override
  String get desktopOfflineLockDays14 => '14 днів';

  @override
  String get desktopOfflineLockDays30 => '30 днів';

  @override
  String get desktopPollTitle => 'Опитування';

  @override
  String get desktopPollAnonymous => 'Анонімне опитування';

  @override
  String get desktopPollClosed => 'Завершено';

  @override
  String desktopPollVoters(Object count) {
    return 'Проголосували: $count';
  }

  @override
  String get desktopPollMultipleHint => 'Можна обрати кілька';

  @override
  String get desktopPollCloseAction => 'Завершити опитування';

  @override
  String get desktopEventTitle => 'Подія';

  @override
  String get desktopEventGoing => 'Іду';

  @override
  String get desktopEventMaybe => 'Можливо';

  @override
  String get desktopEventNo => 'Не йду';

  @override
  String get desktopPollNewTitle => 'Нове опитування';

  @override
  String get desktopPollQuestionHint => 'Питання';

  @override
  String desktopPollOptionHint(Object index) {
    return 'Варіант $index';
  }

  @override
  String get desktopPollAddOption => 'Додати варіант';

  @override
  String get desktopPollCreateAction => 'Створити';

  @override
  String get desktopPollNeedTwo => 'Потрібні питання і щонайменше два варіанти';

  @override
  String get desktopPollMultipleLabel => 'Кілька відповідей';

  @override
  String get desktopPollAnonymousLabel => 'Анонімно';

  @override
  String get desktopEventNewTitle => 'Нова подія';

  @override
  String get desktopEventTitleHint => 'Назва';

  @override
  String get desktopEventDescriptionHint => 'Опис';

  @override
  String get desktopEventLocationHint => 'Місце';

  @override
  String get desktopEventPickWhen => 'Обрати дату й час';

  @override
  String get desktopEventNeedTitleAndDate => 'Потрібні назва і дата';

  @override
  String get desktopViewerOpenExternally => 'Відкрити у програмі';

  @override
  String get desktopViewerSaveAs => 'Зберегти як…';

  @override
  String desktopViewerPage(Object page, Object total) {
    return 'Сторінка $page з $total';
  }

  @override
  String get desktopViewerFailed => 'Не вдалося показати файл';

  @override
  String get desktopViewerTooLarge => 'Файл завеликий, щоб показати тут';

  @override
  String get desktopSupportAttach => 'Прикріпити файл';

  @override
  String desktopSupportAttachHint(Object limit) {
    return 'Знімок екрана або файл журналу — до $limit. Вкладення шифрується разом із повідомленням.';
  }

  @override
  String desktopSupportTooLarge(Object limit) {
    return 'Файл більший за $limit — такий не надіслати';
  }

  @override
  String get desktopSupportUnreadable => 'Не вдалося прочитати файл';

  @override
  String get desktopSupportRemoveAttachment => 'Прибрати вкладення';

  @override
  String desktopSupportMegabytes(Object value) {
    return '$value МБ';
  }

  @override
  String get desktopSupportYou => 'Ви';

  @override
  String get desktopSupportShrunk => 'Зображення стиснуто, щоб умістилося';

  @override
  String get desktopStickerPackTitle => 'Набір стікерів';

  @override
  String get desktopStickerPackAddPlain => 'Додати набір';

  @override
  String get desktopStickerPackInstalled => 'Встановлено';

  @override
  String get desktopStickerPackInstalling => 'Встановлення…';

  @override
  String get desktopStickerPackOwn => 'Це ваш набір';

  @override
  String get desktopStickerPackNoAuthor => 'Автор набору невідомий — відкрийте такий самий стікер в особистому листуванні';

  @override
  String desktopStickerPackInstallingProgress(Object done, Object total) {
    return 'Встановлення… $done/$total';
  }

  @override
  String desktopStickerPackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count стікера',
      many: '$count стікерів',
      few: '$count стікери',
      one: '$count стікер',
    );
    return '$_temp0';
  }

  @override
  String desktopStickerPackAdd(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Додати $count стікера',
      many: 'Додати $count стікерів',
      few: 'Додати $count стікери',
      one: 'Додати $count стікер',
    );
    return '$_temp0';
  }

  @override
  String get desktopPairingTitle => 'Під\'єднайте Secretly Desktop';

  @override
  String get desktopPairingHowTo => 'На телефоні відкрийте Secretly → Налаштування → Пристрої → «Підключити пристрій» і відскануйте цей QR-код.';

  @override
  String get desktopPairingPreparingQr => 'Готуємо QR…';

  @override
  String get desktopPairingQrUnavailable => 'QR недоступний';

  @override
  String get desktopPairingCodeExpired => 'Код застарів — оновлюємо…';

  @override
  String desktopPairingCodeValidFor(Object time) {
    return 'Код дійсний ще $time';
  }

  @override
  String get desktopPairingPrepareFailed => 'Не вдалося підготувати код. Перевірте підключення до інтернету та спробуйте ще раз.';

  @override
  String get desktopPairingRevoked => 'Цей пристрій видалили з облікового запису, тому код не створюється.\nПідключіть комп’ютер заново — він отримає нову особу пристрою, а стара лишиться відкликаною. Доступ до листувань дасть лише підтвердження з телефона.';

  @override
  String get desktopPairingPreparingNew => 'Готуємо нове підключення…';

  @override
  String get desktopPairingConnectAsNew => 'Підключити як новий пристрій';

  @override
  String get desktopPairingIdentityResetFailed => 'Не вдалося створити особу пристрою заново. Перезапустіть застосунок і спробуйте ще раз.';

  @override
  String get desktopPairingWaitingConfirm => 'Очікуємо підтвердження…';

  @override
  String get desktopPairingNewQr => 'Створити новий QR';

  @override
  String get desktopPairingCreatingRequest => 'Створюємо запит…';

  @override
  String get desktopPairingReadyToScan => 'Готово до сканування';

  @override
  String get desktopPairingWaitingScan => 'Очікуємо сканування на телефоні…';

  @override
  String get desktopPairingScannedConfirmOnPhone => 'QR відскановано — підтвердьте на телефоні.';

  @override
  String get desktopPairingFetchingProfile => 'Отримуємо профіль і ключі…';

  @override
  String get desktopPairingConnectedLoading => 'Підключено. Завантажуємо…';

  @override
  String get desktopPairingConnectionError => 'Помилка підключення. Спробуйте ще раз.';

  @override
  String get desktopMenuReaction => 'Реакція';

  @override
  String get desktopMenuContinueInTopic => 'Продовжити в темі';

  @override
  String get desktopMenuCopySelection => 'Копіювати виділене';

  @override
  String get desktopMenuCopyText => 'Копіювати текст';

  @override
  String get desktopMenuCopyLink => 'Копіювати посилання';

  @override
  String get desktopMenuTranslate => 'Перекласти';

  @override
  String get desktopMenuHideTranslation => 'Сховати переклад';

  @override
  String get desktopMenuSelect => 'Виділити';

  @override
  String get desktopMenuPhotoOrVideo => 'Фото або відео';

  @override
  String get desktopMenuContact => 'Контакт';

  @override
  String get desktopMenuLocation => 'Геопозиція';

  @override
  String get desktopListPinned => 'ЗАКРІПЛЕНІ';

  @override
  String get desktopListToday => 'СЬОГОДНІ';

  @override
  String get desktopListYesterday => 'ВЧОРА';

  @override
  String get desktopListThisWeek => 'ЦЬОГО ТИЖНЯ';

  @override
  String get desktopListEarlier => 'РАНІШЕ';

  @override
  String get desktopListNothingFound => 'Нічого не знайдено';

  @override
  String get desktopListAddFavourite => 'До обраного';

  @override
  String get desktopListRemoveFavourite => 'Прибрати з обраного';

  @override
  String get desktopListMute => 'Вимкнути звук';

  @override
  String get desktopListMarkRead => 'Позначити прочитаним';

  @override
  String get desktopListArchive => 'До архіву';

  @override
  String get desktopListFolders => 'Теки';

  @override
  String get desktopListCreate => 'Створити';

  @override
  String get desktopListTyping => 'пише';

  @override
  String get desktopListDraftPrefix => 'Чернетка: ';

  @override
  String desktopListDiscussion(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Обговорення · $count учасника',
      many: 'Обговорення · $count учасників',
      few: 'Обговорення · $count учасники',
      one: 'Обговорення · $count учасник',
    );
    return '$_temp0';
  }

  @override
  String get desktopCallServerSilent => 'Сервер не відповів. Спробуйте ще раз або вийдіть із дзвінка.';

  @override
  String get desktopCallRoomMissing => 'Кімната недоступна на сервері — дзвінок у ній не почати.';

  @override
  String get desktopCallNoServer => 'Немає зв’язку із сервером. Перевірте підключення.';

  @override
  String get desktopCallJoinFailed => 'Не вдалося приєднатися до дзвінка. Перевірте зв’язок і спробуйте ще раз.';

  @override
  String desktopCallSharingScreen(Object name) {
    return '$name показує екран';
  }

  @override
  String get desktopCallRoomEmpty => 'У кімнаті ще нічого не написано';

  @override
  String get desktopCallMessageHint => 'Повідомлення в кімнату…';

  @override
  String get desktopCallSendToRoom => 'Надіслати в кімнату';

  @override
  String desktopCallParticipantsTab(Object count) {
    return 'Учасники · $count';
  }

  @override
  String get desktopCallNotesTab => 'Нотатки';

  @override
  String get desktopCallLinkCopied => 'Посилання скопійовано';

  @override
  String get desktopCallFailed => 'Не вдалося';

  @override
  String desktopCallFailedWith(Object error) {
    return 'Не вдалося: $error';
  }

  @override
  String get desktopCallMicOn => 'Увімкнути мікрофон';

  @override
  String get desktopCallMicOff => 'Вимкнути мікрофон';

  @override
  String get desktopCallCamOn => 'Увімкнути камеру';

  @override
  String get desktopCallCamOff => 'Вимкнути камеру';

  @override
  String get desktopCallNoMediaVideo => 'Сервер не видав медіаканал — відео недоступне';

  @override
  String get desktopCallLayoutSingle => 'Один';

  @override
  String get desktopCallLayoutGrid => 'Сітка';

  @override
  String get desktopCallShowOneLarge => 'Показувати одного великим';

  @override
  String get desktopCallShowGrid => 'Показати всіх сіткою';

  @override
  String get desktopCallScreen => 'Екран';

  @override
  String get desktopCallShareStop => 'Зупинити показ екрана';

  @override
  String get desktopCallShareStart => 'Показати екран';

  @override
  String get desktopCallNoMediaScreen => 'Сервер не видав медіаканал — показ екрана недоступний';

  @override
  String get desktopCallLeave => 'Вийти';

  @override
  String get desktopCallLeaveCall => 'Вийти з дзвінка';

  @override
  String get desktopCallNoMediaBoth => 'Сервер не видав медіаканал: у цьому дзвінку не буде ні звуку, ні відео';

  @override
  String get desktopCallMinimise => 'Згорнути дзвінок';

  @override
  String get desktopCallDiscussion => 'Обговорення';

  @override
  String desktopCallDiscussionOf(Object title) {
    return 'Обговорення · $title';
  }

  @override
  String get desktopCallEncrypted => 'Дзвінок захищено наскрізним шифруванням';

  @override
  String desktopCallDurationOnAir(Object duration, Object count) {
    return '$duration · $count в ефірі';
  }

  @override
  String get desktopCallExitFullScreen => 'Вийти з повноекранного';

  @override
  String get desktopCallFullScreen => 'На весь екран';

  @override
  String get desktopCallDemoRoom => 'Демонстраційна кімната';

  @override
  String get desktopCallNoCallYet => 'Дзвінка ще немає';

  @override
  String get desktopCallDemoExplain => 'Вона живе лише на цьому комп’ютері, а на сервері її немає — дзвінок у ній не почати. У справжній кімнаті кнопка працює.';

  @override
  String get desktopCallStartHint => 'Почніть — інші побачать запрошення в кімнаті';

  @override
  String get desktopCallVoiceOnly => 'Голосом';

  @override
  String get desktopCallWithCamera => 'З камерою';

  @override
  String get desktopCallConnecting => 'Під’єднуємось…';

  @override
  String get desktopCallOngoing => 'Триває обговорення';

  @override
  String desktopCallOnAir(Object count) {
    return '$count в ефірі';
  }

  @override
  String get desktopCallJoin => 'Приєднатися';

  @override
  String get desktopCallFullScreenShort => 'На весь екран';

  @override
  String get desktopCallReconnecting => 'перепід’єднується';

  @override
  String get desktopCallCannotHear => 'не чує';

  @override
  String get desktopCallSharingShort => 'показує екран';

  @override
  String get desktopCallCameraOn => 'камера ввімкнена';

  @override
  String get desktopCallPickDevice => 'Обрати пристрій';

  @override
  String get desktopCallPreparingLink => 'Готуємо посилання…';

  @override
  String get desktopCallInvite => 'Запросити';

  @override
  String desktopCallFps(Object fps) {
    return '$fps к/с';
  }

  @override
  String get desktopSettingsTitle => 'Налаштування';

  @override
  String get desktopSettingsGroupApp => 'Застосунок';

  @override
  String get desktopSettingsGroupPrivacy => 'Приватність і безпека';

  @override
  String get desktopSettingsGroupAccount => 'Обліковий запис і дані';

  @override
  String get desktopSettingsGeneralLabel => 'Загальні';

  @override
  String get desktopSettingsGeneralSubtitle => 'Мова, поведінка застосунку';

  @override
  String get desktopSettingsGeneralKeywords => 'мова, локаль, enter, надсилання, введення';

  @override
  String get desktopSettingsAppearanceLabel => 'Вигляд';

  @override
  String get desktopSettingsAppearanceSubtitle => 'Тема, акцент, шпалери чату';

  @override
  String get desktopSettingsAppearanceKeywords => 'тема, акцент, шпалери, тло, бульбашки, колір, темна, галочки, анімація';

  @override
  String get desktopSettingsShortcutsLabel => 'Гарячі клавіші';

  @override
  String get desktopSettingsShortcutsSubtitle => 'Що натискати, щоб швидше';

  @override
  String get desktopSettingsShortcutsKeywords => 'клавіші, сполучення, швидко, cmd, ctrl';

  @override
  String get desktopSettingsPowerLabel => 'Енергоспоживання';

  @override
  String get desktopSettingsPowerSubtitle => 'Що витрачає батарею';

  @override
  String get desktopSettingsPowerKeywords => 'батарея, анімація, рамки, скло, панелі, продуктивність, нагрів';

  @override
  String get desktopSettingsNotificationsLabel => 'Сповіщення';

  @override
  String get desktopSettingsNotificationsSubtitle => 'Звуки, попередній перегляд, тиша';

  @override
  String get desktopSettingsNotificationsKeywords => 'звук, перегляд, тиша, не турбувати, банер, текст';

  @override
  String get desktopSettingsCallsLabel => 'Дзвінки';

  @override
  String get desktopSettingsCallsSubtitle => 'Приймання дзвінків і показ екрана';

  @override
  String get desktopSettingsCallsKeywords => 'дзвінки, вхідні, показ екрана, екран, відео, аудіо';

  @override
  String get desktopSettingsMediaLabel => 'Звук і відео';

  @override
  String get desktopSettingsMediaSubtitle => 'Камера та мікрофон для дзвінків';

  @override
  String get desktopSettingsMediaKeywords => 'камера, мікрофон, пристрій, вебкамера, гарнітура, навушники, звук, відео';

  @override
  String get desktopSettingsPrivacyLabel => 'Приватність';

  @override
  String get desktopSettingsPrivacySubtitle => 'Хто і що про вас бачить';

  @override
  String get desktopSettingsPrivacyKeywords => 'хто бачить, час входу, фото, дзвінки, повідомлення, пересилання, нікнейм, пошук, незнайомці';

  @override
  String get desktopSettingsSecurityLabel => 'Безпека';

  @override
  String get desktopSettingsSecuritySubtitle => 'Шифрування та перевірені пристрої';

  @override
  String get desktopSettingsSecurityKeywords => 'шифрування, e2ee, перевірені, неперевірені, блокування, пароль, touch id, звірка';

  @override
  String get desktopSettingsBackupLabel => 'Резервна копія';

  @override
  String get desktopSettingsBackupSubtitle => 'Що врятує історію листування';

  @override
  String get desktopSettingsBackupKeywords => 'резервна, копія, відновлення, safe backup, пароль копії, медіа';

  @override
  String get desktopSettingsBlockedLabel => 'Заблоковані';

  @override
  String get desktopSettingsBlockedSubtitle => 'Кому закрито доступ до вас';

  @override
  String get desktopSettingsBlockedKeywords => 'блок, заблоковані, розблокувати, чорний список, спам';

  @override
  String get desktopSettingsDevicesLabel => 'Сеанси та пристрої';

  @override
  String get desktopSettingsDevicesSubtitle => 'Активні сеанси';

  @override
  String get desktopSettingsDevicesKeywords => 'пристрої, сеанси, qr, прив’язка, вихід, резервна копія';

  @override
  String get desktopSettingsAccountLabel => 'Обліковий запис';

  @override
  String get desktopSettingsAccountSubtitle => 'Профіль і вихід';

  @override
  String get desktopSettingsAccountKeywords => 'ім’я, про себе, id, вийти, скинути';

  @override
  String get desktopSettingsStorageLabel => 'Сховище';

  @override
  String get desktopSettingsStorageSubtitle => 'Кеш, завантаження';

  @override
  String get desktopSettingsStorageKeywords => 'кеш, місце, очистити, медіа, завантаження';

  @override
  String get desktopSettingsSupportLabel => 'Підтримка';

  @override
  String get desktopSettingsSupportSubtitle => 'Зашифроване листування з нами';

  @override
  String get desktopSettingsSupportKeywords => 'підтримка, допомога, проблема, помилка, написати';

  @override
  String get desktopSettingsAboutLabel => 'Про програму';

  @override
  String get desktopSettingsAboutKeywords => 'версія, збірка, ліцензії, сайт';

  @override
  String get desktopSettingsDangerLabel => 'Видалити обліковий запис';

  @override
  String get desktopSettingsEndCallFirst => 'Спочатку завершіть активний дзвінок.';

  @override
  String get desktopSettingsSignOutTitle => 'Вийти з облікового запису на цьому комп’ютері?';

  @override
  String get desktopSettingsSignOutBody => 'З цього комп’ютера буде видалено листування, ключі та кеш. Обліковий запис та історія на телефоні не постраждають — комп’ютер можна прив’язати знову за QR-кодом.';

  @override
  String get desktopSettingsSignOut => 'Вийти';

  @override
  String desktopSettingsSignOutFailed(Object error) {
    return 'Не вдалося вийти: $error';
  }

  @override
  String get desktopSettingsActive => 'активно';
}
