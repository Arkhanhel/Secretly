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
  String get desktopCallDiscussion => 'Обговорення';

  @override
  String desktopCallDiscussionOf(Object title) {
    return 'Обговорення · $title';
  }

  @override
  String get desktopCallEncrypted => 'Дзвінок захищено наскрізним шифруванням';

  @override
  String get desktopRoomCallTransportEncrypted => 'Шифрується під час передавання до нашого медіасервера — поки не наскрізне';

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

  @override
  String get desktopGeneralSystemLanguage => 'Системна';

  @override
  String get desktopGeneralInterfaceLanguage => 'Мова інтерфейсу';

  @override
  String get desktopGeneralAppliesAtOnce => 'Застосовується одразу';

  @override
  String get desktopGeneralBehaviour => 'Поведінка';

  @override
  String get desktopGeneralEnterSends => 'Enter надсилає повідомлення';

  @override
  String get desktopGeneralShiftEnterNewline => 'Shift+Enter — новий рядок';

  @override
  String get desktopGeneralEnterNewline => 'Enter — новий рядок, Shift+Enter надсилає';

  @override
  String get desktopGeneralHoverMenu => 'Меню при наведенні на повідомлення';

  @override
  String get desktopGeneralHoverMenuOn => 'Над повідомленням з’являються реакції та дії';

  @override
  String get desktopGeneralHoverMenuOff => 'Дії — правою кнопкою миші';

  @override
  String get desktopGeneralLinkPreviews => 'Попередній перегляд посилань';

  @override
  String get desktopGeneralLinkPreviewsOn => 'Картка посилання йде разом із повідомленням';

  @override
  String get desktopGeneralLinkPreviewsOff => 'Посилання йдуть без картки, сторінки не відкриваються';

  @override
  String get desktopPowerAnimations => 'Анімації';

  @override
  String get desktopPowerAnimationsHint => 'Усе ввімкнено за умовчанням. Вимикайте згори вниз, якщо ноутбук гріється або сідає батарея.';

  @override
  String get desktopPowerFramesTitle => 'Анімація рамок і статусів';

  @override
  String get desktopPowerFramesHint => 'Живі рамки аватарів та емодзі-статуси у співрозмовників. Найдорожча з трьох — вимикайте першою.';

  @override
  String get desktopPowerGlassBubbles => 'Скляні бульбашки';

  @override
  String get desktopPowerGlassBubblesHint => 'Розмиття під вхідними повідомленнями';

  @override
  String get desktopPowerMattePanels => 'Матові панелі';

  @override
  String get desktopPowerMattePanelsHint => 'Розмиття панелей і спливних вікон';

  @override
  String get desktopPowerNotAffectedTitle => 'Чого це не торкається';

  @override
  String get desktopPowerNotAffectedHint => 'Доставляння повідомлень, шифрування та сповіщення працюють однаково за будь-яких значень. Ці налаштування впливають лише на відмальовування.';

  @override
  String get desktopNotifHidden => 'Приховано';

  @override
  String get desktopNotifSenderOnly => 'Лише відправник';

  @override
  String get desktopNotifSenderAndText => 'Відправник і текст';

  @override
  String get desktopNotifUnavailableHere => 'Недоступно на цій платформі.';

  @override
  String get desktopNotifShowPreview => 'Показувати попередній перегляд повідомлення';

  @override
  String get desktopNotifInSystem => 'У системних сповіщеннях';

  @override
  String get desktopNotifDirectChats => 'Особисті чати';

  @override
  String get desktopNotifDirectChatsHint => 'Сповіщення про повідомлення один на один';

  @override
  String get desktopNotifRooms => 'Кімнати';

  @override
  String get desktopNotifRoomsHint => 'Сповіщення про повідомлення в кімнатах';

  @override
  String get desktopNotifSound => 'Звук';

  @override
  String get desktopNotifDnd => 'Не турбувати';

  @override
  String get desktopNotifDndHint => 'Вимкнути всі сповіщення';

  @override
  String get desktopWallAnimContinuous => 'Постійно';

  @override
  String get desktopWallAnimOnEnter => 'Коли відкривається чат';

  @override
  String get desktopWallAnimTap => 'На клік по тлу';

  @override
  String get desktopWallAnimOff => 'Не анімувати';

  @override
  String get desktopWallpaperNavy => 'Нічний синій';

  @override
  String get desktopWallpaperGraphite => 'Графіт';

  @override
  String get desktopWallpaperTeal => 'Бірюза';

  @override
  String get desktopWallpaperPlum => 'Слива';

  @override
  String get desktopWallpaperWine => 'Вино';

  @override
  String get desktopWallpaperMint => 'М’ята';

  @override
  String get desktopWallpaperLavender => 'Лаванда';

  @override
  String get desktopWallpaperSunset => 'Захід сонця';

  @override
  String get desktopWallpaperPeach => 'Персик';

  @override
  String get desktopWallpaperSky => 'Небо';

  @override
  String get desktopWallpaperMidnight => 'Опівніч';

  @override
  String get desktopAppearanceTitle => 'Оформлення';

  @override
  String get desktopAppearanceHint => 'Схема цього вікна. Телефон живе зі своєю — це налаштування нікуди не їде.';

  @override
  String get desktopAppearanceScheme => 'Схема';

  @override
  String get desktopAppearanceSchemeHint => 'Темна, світла або за системною';

  @override
  String get desktopAppearanceDark => 'Темна';

  @override
  String get desktopAppearanceLight => 'Світла';

  @override
  String get desktopAppearanceAuto => 'Авто';

  @override
  String get desktopAppearanceAccent => 'Акцент інтерфейсу';

  @override
  String get desktopAppearanceAccentHint => 'Кнопки, власні бульбашки та виділення в усьому застосунку.';

  @override
  String get desktopAppearanceWallpaper => 'Шпалери чату';

  @override
  String get desktopAppearanceWallpaperHint => 'Тло чату для всіх бесід.';

  @override
  String get desktopAppearanceLiveWallpaper => 'Живі шпалери';

  @override
  String get desktopAppearanceLiveWallpaperHint => 'Візерунок із м’яким переливом. Той самий набір, що й на телефоні.';

  @override
  String get desktopAppearanceAnimBehaviour => 'Поведінка анімації';

  @override
  String get desktopAppearanceAnimBehaviourHint => 'Коли візерунок оживає.';

  @override
  String get desktopAppearanceWallPulse => 'Шпалери проводять повідомлення';

  @override
  String get desktopAppearanceWallPulseHint => 'Хвиля світла йде візерунком: вгору — коли надсилаєте, вниз — коли отримуєте.';

  @override
  String get desktopAppearanceEnable => 'Увімкнути';

  @override
  String get desktopAppearanceLiveOnly => 'Працює лише на живих шпалерах';

  @override
  String get desktopAppearanceBubbleStyle => 'Стиль бульбашок повідомлень';

  @override
  String get desktopAppearanceBubbleStyleHint => 'Колір ваших вихідних повідомлень в усіх чатах.';

  @override
  String get desktopAppearanceSenderColour => 'Колір імені відправника';

  @override
  String get desktopAppearanceSenderColourHint => 'Колір ніка співрозмовника в групових чатах.';

  @override
  String get desktopAppearanceIndicatorColour => 'Колір індикаторів';

  @override
  String get desktopAppearanceIndicatorColourHint => 'Галочки доставляння та крапка непрочитаного.';

  @override
  String get desktopAppearanceDemoMode => 'Демо-режим';

  @override
  String get desktopAppearanceDemoHint => 'Зміни вигляду збережуться, коли профіль буде прив’язано.';

  @override
  String get desktopAppearanceCurrentChoice => 'Поточний вибір';

  @override
  String desktopAppearanceThemeIs(Object name) {
    return 'Тема: $name';
  }

  @override
  String get desktopBackupEvery6h => 'Кожні 6 годин';

  @override
  String get desktopBackupEvery12h => 'Кожні 12 годин';

  @override
  String get desktopBackupDaily => 'Раз на добу';

  @override
  String get desktopBackupWeekly => 'Раз на тиждень';

  @override
  String get desktopBackupOffWarning => 'Автокопію вимкнено — відновити історію не буде з чого';

  @override
  String get desktopBackupNeverRan => 'Увімкнено, але ще жодного разу не виконувалася';

  @override
  String desktopBackupLastFailedWith(Object error) {
    return 'Остання копія не вдалася: $error';
  }

  @override
  String get desktopBackupLastFailed => 'Остання копія не вдалася';

  @override
  String get desktopBackupStale => 'Копія давно не оновлювалася';

  @override
  String get desktopBackupFresh => 'Копія актуальна';

  @override
  String get desktopBackupState => 'Стан';

  @override
  String get desktopBackupAutomatic => 'Автоматична копія';

  @override
  String get desktopBackupAutomaticHint => 'Копія зашифрована вашим паролем. Без пароля її не відновити ні нам, ні будь-кому іншому — тому пароль треба пам’ятати.';

  @override
  String get desktopBackupCreateAuto => 'Створювати автоматично';

  @override
  String get desktopBackupUploadServer => 'Вивантажувати на сервер';

  @override
  String get desktopBackupUploadServerHint => 'Доступна з будь-якого пристрою';

  @override
  String get desktopBackupKeepLocal => 'Зберігати на цьому комп’ютері';

  @override
  String get desktopBackupKeepLocalHint => 'Не залежить від мережі';

  @override
  String get desktopBackupIncludeMedia => 'Включати медіа';

  @override
  String get desktopBackupIncludeMediaHint => 'Копія стане помітно більшою';

  @override
  String get desktopBackupFrequency => 'Частота';

  @override
  String get desktopBackupNowhereTitle => 'Копія нікуди не зберігається';

  @override
  String get desktopBackupNowhereHint => 'Автокопію ввімкнено, але обидва місця призначення вимкнені — отже копія не створюється. Увімкніть сервер або цей комп’ютер.';

  @override
  String get desktopBackupRecoveryKey => 'Набір відновлення';

  @override
  String get desktopBackupCreateRecoveryKey => 'Створити набір відновлення';

  @override
  String get desktopBackupRecoveryKeyHint => 'Знадобиться, якщо не залишиться жодного пристрою із Secretly. Збережіть його окремо від пароля.';

  @override
  String desktopBackupKeyFailed(Object error) {
    return 'Не вдалося створити ключ: $error';
  }

  @override
  String get desktopBackupKeyPassword => 'Пароль набору відновлення';

  @override
  String get desktopBackupPasswordsDiffer => 'Паролі не збігаються.';

  @override
  String get desktopBackupKeyPasswordHint => 'Цим паролем шифрується сам набір. Він не замінює пароль від застосунку і не зберігається ніде — відновити його не можна.';

  @override
  String get desktopBackupPasswordAgain => 'Ще раз';

  @override
  String desktopUnblockTitle(Object name) {
    return 'Розблокувати $name?';
  }

  @override
  String get desktopUnblockBody => 'Ця людина знову зможе писати вам і дзвонити.';

  @override
  String get desktopUnblockAction => 'Розблокувати';

  @override
  String get desktopPrivacyLastSeen => 'Час входу';

  @override
  String get desktopPrivacyProfilePhoto => 'Фотографії профілю';

  @override
  String get desktopPrivacyForwarding => 'Пересилання повідомлень';

  @override
  String get desktopPrivacyCalls => 'Дзвінки';

  @override
  String get desktopPrivacyVoice => 'Голосові повідомлення';

  @override
  String get desktopPrivacyMessages => 'Повідомлення';

  @override
  String get desktopPrivacyNobody => 'Ніхто';

  @override
  String get desktopPrivacyEverybody => 'Усі';

  @override
  String get desktopPrivacyContacts => 'Контакти';

  @override
  String get desktopPrivacyEncryption => 'Шифрування';

  @override
  String get desktopPrivacyEncryptionHint => 'Повідомлення, файли та дзвінки один на один захищено наскрізним шифруванням; ключі — лише на ваших пристроях. Групові дзвінки поки шифруються лише під час передавання.';

  @override
  String get desktopPrivacyE2eeActive => 'Наскрізне шифрування активне';

  @override
  String get desktopPrivacyWhoSees => 'Хто бачить';

  @override
  String get desktopPrivacyWhoSeesHint => 'Ті самі налаштування видимості, що й у телефоні. «Контакти» враховує застосунок; сервер гарантує лише «Ніхто».';

  @override
  String get desktopPrivacyVisibility => 'Видимість';

  @override
  String get desktopPrivacyByNickname => 'Видимість за ніком';

  @override
  String get desktopPrivacyByNicknameHint => 'Дозволити знаходити вас за ніком';

  @override
  String get desktopPrivacySuggest => 'Підказка людей під час пошуку';

  @override
  String get desktopPrivacyStrangers => 'Нові чати з незнайомцями';

  @override
  String get desktopPrivacyStrangersHint => 'До архіву та без сповіщень';

  @override
  String get desktopPrivacyAutoDelete => 'Видалити мій обліковий запис';

  @override
  String get desktopPrivacyAutoDeleteHint => 'Якщо ви не заходите довше за обраний строк, з наших серверів видаляються обліковий запис, ключі, серверна копія та черги повідомлень. Відлік скидається за кожного входу.';

  @override
  String get desktopPrivacyIfAbsent => 'Якщо не заходжу';

  @override
  String get desktopPrivacyIn1Month => 'Через 1 місяць';

  @override
  String get desktopPrivacyIn3Months => 'Через 3 місяці';

  @override
  String get desktopPrivacyIn6Months => 'Через 6 місяців';

  @override
  String get desktopPrivacyIn1Year => 'Через рік';

  @override
  String get desktopPrivacyIn2Years => 'Через 2 роки';

  @override
  String get desktopLockImmediately => 'Одразу при втраті фокуса';

  @override
  String desktopLockSeconds(Object value) {
    return '$value с';
  }

  @override
  String desktopLockMinutes(Object value) {
    return '$value хв';
  }

  @override
  String desktopLockHours(Object value) {
    return '$value год';
  }

  @override
  String get desktopLockNoIdentityService => 'Служба перевірки особи недоступна — блокування не ввімкнено.';

  @override
  String get desktopLockNotConfirmed => 'Блокування не ввімкнено: підтвердження не пройдено.';

  @override
  String get desktopLockTitle => 'Блокування застосунку';

  @override
  String get desktopLockTouchIdHint => 'Запитувати Touch ID для входу після втрати фокуса.';

  @override
  String get desktopLockPasswordHint => 'Запитувати пароль пристрою для входу після втрати фокуса.';

  @override
  String get desktopLockEnableTouchId => 'Увімкнути Touch ID';

  @override
  String get desktopLockEnableLock => 'Увімкнути блокування';

  @override
  String get desktopLockDevicePassword => 'Пароль пристрою';

  @override
  String get desktopLockAfter => 'Блокувати через';

  @override
  String get desktopLockNow => 'Заблокувати зараз';

  @override
  String get desktopDevicesEndSessionTitle => 'Завершити сеанс?';

  @override
  String desktopDevicesEndSessionBody(Object id) {
    return 'Пристрій $id буде відключено від вашого профілю. Щоб повернути доступ, потрібне повторне сканування QR. Продовжити?';
  }

  @override
  String get desktopDevicesEnd => 'Завершити';

  @override
  String desktopDevicesEndFailed(Object error) {
    return 'Не вдалося завершити сеанс: $error';
  }

  @override
  String get desktopDevicesEnded => 'Сеанс пристрою завершено.';

  @override
  String get desktopDevicesActiveSessions => 'Активні сеанси';

  @override
  String get desktopDevicesDemoHint => 'Демо-режим · справжні пристрої з’являться після підключення профілю';

  @override
  String get desktopDevicesThisComputer => 'macOS · Цей комп’ютер';

  @override
  String get desktopDevicesDemoMac => 'MacBook Pro · Зараз активний';

  @override
  String get desktopDevicesDemoIphone => 'iOS 18.2 · 2 години тому (демо)';

  @override
  String get desktopDevicesDemoIpad => 'iPadOS 18 · вчора (демо)';

  @override
  String get desktopDevicesThisDevice => 'Цей пристрій';

  @override
  String get desktopDevicesRemoteDevice => 'Віддалений пристрій';

  @override
  String get desktopDevicesDisconnect => 'Відключити';

  @override
  String get desktopDevicesTitle => 'Пристрої';

  @override
  String desktopDevicesTitleCount(Object count) {
    return 'Пристрої · $count';
  }

  @override
  String get desktopDevicesHint => 'Перелік пристроїв, прив’язаних до цього профілю на сервері ключів.';

  @override
  String get desktopDevicesLoadFailed => 'Не вдалося завантажити';

  @override
  String get desktopDevicesRetry => 'Повторити';

  @override
  String get desktopDevicesNone => 'Пристроїв не знайдено';

  @override
  String get desktopDevicesNotLinked => 'Профіль ще не прив’язано до сервера.';

  @override
  String get desktopDevicesRefresh => 'Оновити перелік';

  @override
  String get desktopAccentCustom => 'Свій колір';

  @override
  String get desktopAccentCustomChange => 'Свій колір — змінити';

  @override
  String get desktopPairTitle => 'Підключити пристрій';

  @override
  String get desktopPairHint => 'Покажіть QR-код на новому пристрої або відскануйте його з телефона';

  @override
  String get desktopPairRequestFailed => 'Не вдалося створити запит на підключення';

  @override
  String get desktopPairCodeCopied => 'Вміст QR скопійовано';

  @override
  String get desktopPairNewTitle => 'Підключити новий пристрій';

  @override
  String get desktopPairNewHint => 'На новому пристрої відкрийте Secretly і виберіть «Підключитися за QR». Потім відскануйте код нижче.';

  @override
  String get desktopPairClose => 'Закрити';

  @override
  String get desktopPairCopyCode => 'Скопіювати код';

  @override
  String get desktopPairRefreshQr => 'Оновити QR';

  @override
  String desktopSyncPulled(Object count) {
    return 'Підвантажено нових подій: $count';
  }

  @override
  String get desktopSyncTooOften => 'Забагато запитів — спробуйте пізніше';

  @override
  String get desktopSyncNothingNew => 'Готово · нових подій немає';

  @override
  String get desktopSyncDemoUnavailable => 'Недоступно в демо-режимі';

  @override
  String desktopSyncBlobsPulled(Object blobs, Object convos) {
    return 'Підвантажено вкладень: $blobs (чатів: $convos)';
  }

  @override
  String desktopSyncNoBlobs(Object convos) {
    return 'Готово · нових вкладень немає (чатів: $convos)';
  }

  @override
  String get desktopSyncTitle => 'Історія з інших пристроїв';

  @override
  String get desktopSyncHint => 'Запитати нещодавню історію чатів у мобільного пристрою. Використовується, якщо комп’ютер був офлайн довше за 7 днів або щойно прив’язаний за QR.';

  @override
  String get desktopSyncRunning => 'Синхронізація…';

  @override
  String get desktopSyncAskHistory => 'Запитати історію';

  @override
  String get desktopSyncAsk => 'Запитати';

  @override
  String get desktopSyncBlobsRunning => 'Завантаження вкладень…';

  @override
  String get desktopSyncBlobsAction => 'Підвантажити вкладення';

  @override
  String get desktopSyncBlobsHint => 'Завантажує медіа з нещодавніх чатів, якщо файлів немає локально (після повторної прив’язки або довгого офлайну).';

  @override
  String get desktopSyncBlobsShort => 'Підвантажити';

  @override
  String desktopServerBackupOk(Object stamp, Object size, Object profile) {
    return 'Копія на сервері ✓ · $stamp · $size КБ · профіль $profile';
  }

  @override
  String get desktopServerBackupPassword => 'Пароль резервної копії';

  @override
  String get desktopServerBackupPasswordHint => 'Цим паролем копія шифрується і відновлюється на будь-якому пристрої. Запам’ятайте його — без пароля копія марна, відновити його не можна.';

  @override
  String get desktopServerBackupRepeat => 'Повторіть пароль';

  @override
  String get desktopServerBackupCreate => 'Створити копію';

  @override
  String get desktopServerBackupTitle => 'Резервна копія на сервер';

  @override
  String get desktopServerBackupHint => 'Зашифрована копія облікового запису на сервері Secretly. Відновлюється на будь-якому пристрої через «Відновити з сервера» за вашим Secretly ID і паролем.';

  @override
  String get desktopServerBackupLoading => 'Завантаження…';

  @override
  String get desktopServerBackupCreateOnServer => 'Створити копію на сервері';

  @override
  String get desktopServerBackupUpdate => 'Оновити копію';

  @override
  String desktopFailedWith(Object error) {
    return 'Не вдалося: $error';
  }

  @override
  String get desktopStorageDeleteModelTitle => 'Видалити модель розпізнавання?';

  @override
  String get desktopStorageDeleteModelBody => 'Розшифрування голосових повідомлень перестане працювати, доки модель не завантажиться знову.';

  @override
  String get desktopStorageModelDeleted => 'Модель видалено';

  @override
  String desktopStorageDeleteFailed(Object error) {
    return 'Не вдалося видалити: $error';
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
  String get desktopStorageUsage => 'Використання';

  @override
  String get desktopStorageUsageHint => 'Кеш і медіа на цьому пристрої';

  @override
  String desktopStorageClearHint(Object size) {
    return 'Звільниться $size. Повідомлення, надіслані вами файли та «нещодавні» не видаляються — їх немає звідки відновити.';
  }

  @override
  String get desktopStorageClear => 'Очистити кеш';

  @override
  String get desktopStorageCounting => 'Підрахунок…';

  @override
  String get desktopStorageSpeechModel => 'Модель розпізнавання мовлення';

  @override
  String get desktopStorageSpeechModelHint => 'Використовується для розшифрування голосових повідомлень на цьому комп’ютері, без надсилання звуку кудись. Звичайне очищення кешу її НЕ видаляє — вона велика й завантажується окремо.';

  @override
  String get desktopStorageDeleteModel => 'Видалити модель';

  @override
  String desktopStorageMedia(Object size) {
    return 'Медіа · $size';
  }

  @override
  String desktopStorageVoice(Object size) {
    return 'Голос · $size';
  }

  @override
  String desktopStorageOther(Object size) {
    return 'Інше · $size';
  }

  @override
  String get desktopStorageFree => 'Вільно';

  @override
  String desktopStorageTotal(Object size) {
    return 'Усього · $size';
  }

  @override
  String desktopAboutVersion(Object version, Object build) {
    return 'Версія $version · збірка $build';
  }

  @override
  String get desktopAboutTagline => 'Месенджер із наскрізним шифруванням. Без реклами. Вихідний код — AGPL-3.0.';

  @override
  String get desktopAboutLicences => 'Ліцензії';

  @override
  String get desktopAboutWebsite => 'Сайт';

  @override
  String get desktopDangerTitle => 'Видалити обліковий запис безповоротно?';

  @override
  String get desktopDangerBody => 'Профіль, ключі, локальні дані та історія повідомлень будуть видалені на цьому та інших пристроях. Відновлення неможливе.';

  @override
  String get desktopDangerDeleting => 'Видалення облікового запису…';

  @override
  String desktopDangerFailed(Object error) {
    return 'Не вдалося видалити обліковий запис: $error';
  }

  @override
  String get desktopDangerSection => 'Видалення облікового запису';

  @override
  String get desktopDangerDemo => 'Демо-режим · видалення недоступне без підключеного профілю.';

  @override
  String get desktopDangerEnterId => 'Введіть ваш Secretly ID для підтвердження';

  @override
  String desktopDangerEnterIdExact(Object id) {
    return 'Введіть $id для підтвердження';
  }

  @override
  String get desktopDangerAction => 'Видалити обліковий запис';

  @override
  String get desktopDangerIrreversible => 'Ця дія незворотна. Буде видалено всі ваші дані, історію повідомлень і ключі. Відновлення неможливе.';

  @override
  String get desktopSecurityE2ee => 'Наскрізне шифрування';

  @override
  String get desktopSecurityE2eeHint => 'Повідомлення, файли та дзвінки один на один шифруються на вашому пристрої, ключі не залишають ваші пристрої. Сервер не читає вміст, але бачить службові дані — наприклад, хто кому пише і коли. Групові дзвінки поки шифруються лише під час передавання.';

  @override
  String get desktopSecurityVerifiedDevices => 'Перевірені пристрої';

  @override
  String get desktopSecurityVerifiedHint => 'Доки налаштування ввімкнене, повідомлення не йдуть на непідтверджені пристрої співрозмовника. Це захист від підміни, але повідомлення може не дійти, доки він не підтвердить новий. Лише особисте листування: на групи не діє.';

  @override
  String get desktopSecurityOnlyVerified => 'Лише перевірені пристрої';

  @override
  String get desktopSecurityBlocked => 'Неперевірені пристрої блокуються';

  @override
  String get desktopSecurityAllDevices => 'Повідомлення йдуть на всі пристрої співрозмовника';

  @override
  String get desktopSecurityAppEntry => 'Вхід у застосунок';

  @override
  String get desktopSecurityAppEntryHint => 'Пароль під час відкриття Secretly і після того, як вікно було сховане довше за хвилину. Діє на цьому комп’ютері.';

  @override
  String get desktopSecurityPersonalScopeHint => 'Окремий пароль на категорію «Особисті». Без нього особисті чати відкриті будь-кому, хто має доступ до розблокованого комп’ютера.';

  @override
  String get desktopCallsInApp => 'Дзвінки в застосунку';

  @override
  String get desktopCallsInAppHint => 'Вимкніть, щоб повністю відключити дзвінки';

  @override
  String get desktopCallsAccept => 'Приймати вхідні';

  @override
  String get desktopCallsAcceptHint => 'Вам зможуть дзвонити';

  @override
  String get desktopCallsDisabledHint => 'Недоступно, доки дзвінки вимкнені';

  @override
  String get desktopCallsScreenShare => 'Показ екрана';

  @override
  String get desktopCallsScreenShareHint => 'Приймання чужого показу — окремий дозвіл: на екрані може опинитися те, чого ви не очікували побачити.';

  @override
  String get desktopCallsAcceptScreenShare => 'Приймати показ екрана';

  @override
  String get desktopAccountIdCopied => 'Secretly ID скопійовано';

  @override
  String get desktopAccountIdHint => 'Цим ідентифікатором діляться, щоб вас знайшли. Він не містить ні номера телефона, ні пошти.';

  @override
  String get desktopAccountCopy => 'Копіювати';

  @override
  String get desktopAccountProfile => 'Профіль';

  @override
  String get desktopAccountProfileHint => 'Ім’я, фото, статус';

  @override
  String get desktopAccountOpenProfile => 'Відкрити сторінку профілю';

  @override
  String desktopScopePasswordFor(Object name) {
    return 'Пароль для «$name»';
  }

  @override
  String get desktopScopeMin4 => 'Щонайменше 4 символи';

  @override
  String get desktopScopeOn => 'Захист увімкнено';

  @override
  String desktopScopeOnFailed(Object error) {
    return 'Не вдалося ввімкнути: $error';
  }

  @override
  String get desktopScopeOff => 'Захист вимкнено';

  @override
  String desktopScopeOffFailed(Object error) {
    return 'Не вдалося вимкнути: $error';
  }

  @override
  String get desktopScopePasswordsDiffer => 'Паролі не збігаються';

  @override
  String get desktopScopeTitle => 'Захист паролем';

  @override
  String get desktopScopeOnWithPassword => 'Увімкнено — пароль';

  @override
  String get desktopScopeEnabled => 'Увімкнено';

  @override
  String get desktopScopeDisabled => 'Вимкнено';

  @override
  String get desktopScopeChangePassword => 'Змінити пароль';

  @override
  String get desktopScopeLockNow => 'Заблокувати';

  @override
  String desktopBlockedUnblocked(Object name) {
    return '$name розблоковано';
  }

  @override
  String desktopBlockedUnblockFailed(Object error) {
    return 'Не вдалося розблокувати: $error';
  }

  @override
  String get desktopBlockedTitle => 'Заблоковані';

  @override
  String get desktopBlockedEmptyHint => 'Перелік порожній. Заблокувати можна з меню чату.';

  @override
  String get desktopBlockedHint => 'Ці люди не можуть писати вам і дзвонити.';

  @override
  String get desktopBlockedNone => 'Ніхто не заблокований';

  @override
  String get desktopSupportSent => 'Повідомлення надіслано';

  @override
  String get desktopSupportSendFailed => 'Не вдалося надіслати. Перевірте підключення.';

  @override
  String get desktopSupportUnavailable => 'Підтримка недоступна';

  @override
  String get desktopSupportUnavailableHint => 'Службу підтримки зараз вимкнено. Спробуйте пізніше або напишіть з телефона.';

  @override
  String get desktopSupportThread => 'Листування з підтримкою';

  @override
  String get desktopSupportThreadHint => 'Повідомлення шифруються на вашому пристрої. Сервер зберігає лише шифротекст — прочитати листування може лише підтримка.';

  @override
  String get desktopSupportNoReplies => 'Відповідей поки немає. Опишіть проблему — відповідь прийде сюди.';

  @override
  String get desktopSupportWrite => 'Написати в підтримку';

  @override
  String get desktopSupportWriteHint => 'До повідомлення автоматично додаються версія збірки та ідентифікатор пристрою — без них відтворити проблему майже неможливо.';

  @override
  String get desktopSupportDescribe => 'Опишіть, що сталося';

  @override
  String get desktopSupportSending => 'Надсилаємо…';

  @override
  String get desktopSupportSend => 'Надіслати';

  @override
  String get desktopChatsEmptyHint => 'Почніть спілкування з телефона — чати автоматично синхронізуються на комп’ютер';

  @override
  String get desktopChatsPickOne => 'Оберіть чат ліворуч';

  @override
  String desktopChatsSendFailed(Object error) {
    return 'Не вдалося надіслати: $error';
  }

  @override
  String desktopChatsSendingTo(Object title) {
    return 'Надсилається в «$title»';
  }

  @override
  String get desktopChatsFilterAll => 'Усі';

  @override
  String get desktopChatsFilterUnread => 'Непрочит.';

  @override
  String get desktopChatsFilterGroups => 'Групи';

  @override
  String get desktopChatsFilterArchive => 'Архів';

  @override
  String get desktopChatsFilterPersonal => 'Особисті';

  @override
  String get desktopChatsRenameFolder => 'Перейменувати теку';

  @override
  String get desktopChatsDeleteFolder => 'Видалити теку';

  @override
  String desktopChatsRenameFailed(Object error) {
    return 'Не вдалося перейменувати: $error';
  }

  @override
  String desktopChatsDeleteFolderTitle(Object name) {
    return 'Видалити теку «$name»?';
  }

  @override
  String get desktopChatsDeleteFolderBody => 'Чати залишаться на місці — видалиться лише тека.';

  @override
  String desktopChatsDeleteFailed(Object error) {
    return 'Не вдалося видалити: $error';
  }

  @override
  String desktopChatsAddedToFolder(Object name) {
    return 'Додано до «$name»';
  }

  @override
  String desktopChatsRemovedFromFolder(Object name) {
    return 'Прибрано з «$name»';
  }

  @override
  String desktopChatsFolderChangeFailed(Object error) {
    return 'Не вдалося змінити теку: $error';
  }

  @override
  String desktopChatsFolderCreated(Object name) {
    return 'Теку «$name» створено';
  }

  @override
  String desktopChatsFolderCreateFailed(Object error) {
    return 'Не вдалося створити теку: $error';
  }

  @override
  String get desktopChatsNewFolder => 'Нова тека';

  @override
  String get desktopChatsFolderName => 'Назва теки';

  @override
  String desktopChatsRemoveFromFolder(Object name) {
    return 'Прибрати з «$name»';
  }

  @override
  String desktopChatsAddToFolder(Object name) {
    return 'До теки «$name»';
  }

  @override
  String get desktopChatsNewFolderWithChat => 'Нова тека з цим чатом…';

  @override
  String get desktopChatsRemoveFromPersonal => 'Прибрати з особистих';

  @override
  String get desktopChatsAddToPersonal => 'До особистих';

  @override
  String get desktopChatsArchiveEmpty => 'В архіві порожньо';

  @override
  String get desktopChatsNoPersonal => 'Особистих чатів немає';

  @override
  String get desktopChatsPersonalLocked => 'Особисті чати захищено паролем';

  @override
  String get desktopChatsAllRead => 'Усе прочитано';

  @override
  String get desktopChatsFolderEmpty => 'У цій теці поки порожньо';

  @override
  String get desktopChatsNewChat => 'Новий чат';

  @override
  String get desktopChatsNewRoom => 'Нова кімната';

  @override
  String get desktopChatsStartFailed => 'Не вдалося почати чат: профіль недоступний';

  @override
  String get desktopChatsPhoto => 'Фото';

  @override
  String get desktopChatsVideo => 'Відео';

  @override
  String get desktopChatsAudio => 'Аудіо';

  @override
  String get desktopChatsVoiceMessage => 'Голосове повідомлення';

  @override
  String get desktopChatsVoiceShort => 'Голосове';

  @override
  String get desktopChatsLink => 'Посилання';

  @override
  String get desktopChatsSticker => 'Стікер';

  @override
  String desktopChatsStickerWith(Object label) {
    return 'Стікер $label';
  }

  @override
  String desktopChatsPoll(Object question) {
    return '📊 Опитування: $question';
  }

  @override
  String get desktopChatsUnknown => 'невідомо';

  @override
  String get desktopChatsMember => 'Учасник';

  @override
  String get desktopChatsSoundOn => 'Увімкнути звук';

  @override
  String get desktopChatsSoundOff => 'Без звуку';

  @override
  String get desktopChatsClearHistoryTitle => 'Очистити історію?';

  @override
  String desktopChatsClearHistoryBody(Object title) {
    return 'Усі повідомлення чату «$title» на цьому пристрої буде видалено.';
  }

  @override
  String get desktopChatsClear => 'Очистити';

  @override
  String get desktopChatsHistoryClearedBoth => 'Історію очищено в обох';

  @override
  String get desktopChatsHistoryCleared => 'Історію очищено';

  @override
  String get desktopChatsDeleteChatTitle => 'Видалити чат?';

  @override
  String desktopChatsDeleteChatBody(Object title) {
    return 'Чат «$title» повністю видалиться з цього пристрою.';
  }

  @override
  String get desktopChatsRooms => 'Кімнати';

  @override
  String get desktopChatsGeneralTopic => 'Загальний';

  @override
  String get desktopChatsNewTopicEllipsis => 'Нова тема…';

  @override
  String desktopChatsBranch(Object title) {
    return 'Гілка «$title»';
  }

  @override
  String get desktopChatsRename => 'Перейменувати';

  @override
  String get desktopChatsIcon => 'Значок';

  @override
  String get desktopChatsDeleteBranch => 'Видалити гілку';

  @override
  String get desktopChatsBranchIcon => 'Значок гілки';

  @override
  String get desktopChatsBranchIconHint => 'Значок замінює решітку перед назвою. Кольорові обіцяють, що всередині: зелений — дзвінок, червоний — термінове. Решта сірі, щоб не сперечатися з назвою.';

  @override
  String get desktopChatsHash => 'Решітка';

  @override
  String desktopChatsBranchFailed(Object error) {
    return 'Не вдалося змінити гілки: $error';
  }

  @override
  String get desktopChatsNewTopic => 'Нова тема';

  @override
  String get desktopChatsRenameTopic => 'Перейменувати тему';

  @override
  String get desktopChatsTopicName => 'Назва теми';

  @override
  String desktopChatsReactionFailed(Object error) {
    return 'Не вдалося зберегти реакцію: $error';
  }

  @override
  String desktopChatsReactionLocal(Object error) {
    return 'Реакцію застосовано локально, але не доставлено співрозмовнику: $error';
  }

  @override
  String get desktopChatsRevealFailed => 'Не вдалося показати файл у Finder';

  @override
  String desktopChatsVideoOpenFailed(Object error) {
    return 'Не вдалося відкрити відео: $error';
  }

  @override
  String get desktopChatsVideoUnavailable => 'Відео недоступне';

  @override
  String desktopChatsFileFetchFailed(Object error) {
    return 'Не вдалося отримати файл: $error';
  }

  @override
  String get desktopChatsSaveAttachment => 'Зберегти вкладення';

  @override
  String get desktopChatsFileUnavailable => 'Файл недоступний';

  @override
  String desktopChatsSaveFailed(Object error) {
    return 'Не вдалося зберегти: $error';
  }

  @override
  String desktopChatsOpenFailedWith(Object error) {
    return 'Не вдалося відкрити файл: $error';
  }

  @override
  String get desktopChatsOpenFailed => 'Не вдалося відкрити файл';

  @override
  String desktopChatsOpenFailedShort(Object error) {
    return 'Не вдалося відкрити: $error';
  }

  @override
  String desktopChatsPlayFailed(Object error) {
    return 'Не вдалося відтворити: $error';
  }

  @override
  String get desktopChatsNoCallPeer => 'Не вдалося визначити співрозмовника для дзвінка.';

  @override
  String get desktopChatsCallsNotReady => 'Служба дзвінків не готова.';

  @override
  String get desktopChatsCallInProgress => 'Дзвінок уже триває.';

  @override
  String get desktopChatsEditFailed => 'Не вдалося змінити повідомлення.';

  @override
  String get desktopChatsNoRecipient => 'Не вдалося визначити отримувача.';

  @override
  String get desktopChatsDeleteMessageTitle => 'Видалити повідомлення?';

  @override
  String get desktopChatsDeleteMessagesTitle => 'Видалити обрані повідомлення?';

  @override
  String get desktopChatsDeleteOthersHint => 'Чужі повідомлення видаляться лише у вас.';

  @override
  String get desktopChatsDeleteForAll => 'Видалити в усіх';

  @override
  String get desktopChatsDeleteForMeOnly => 'Видалити лише в мене';

  @override
  String get desktopChatsDeleteForMe => 'Видалити в мене';

  @override
  String get desktopChatsSavePrivacyBlocked => 'Це повідомлення не можна зберегти через обмеження приватності.';

  @override
  String get desktopChatsNothingToSave => 'Вкладення не завантажено — зберігати нічого';

  @override
  String get desktopChatsSavedPartly => 'Збережено в «Обране», але не все';

  @override
  String get desktopChatsSaved => 'Збережено в «Обране»';

  @override
  String get desktopChatsForwardPrivacyBlocked => 'Це повідомлення не можна переслати через обмеження приватності.';

  @override
  String desktopChatsForwardFailed(Object error) {
    return 'Не вдалося переслати: $error';
  }

  @override
  String get desktopChatsNothingToForward => 'Вкладення не завантажено — пересилати нічого';

  @override
  String desktopChatsForwardedPartly(Object title) {
    return 'Переслано в «$title», але не все';
  }

  @override
  String desktopChatsForwarded(Object title) {
    return 'Переслано в «$title»';
  }

  @override
  String desktopChatsFileNotSentElsewhere(Object text) {
    return 'Файл в інше листування не надіслано: $text';
  }

  @override
  String get desktopChatsFileSendFailed => 'Не вдалося надіслати файл.';

  @override
  String desktopChatsPremiumFiles(Object text) {
    return '$text З Premium можна надсилати файли до 1 ГБ.';
  }

  @override
  String get desktopChatsTypingEllipsis => 'пише…';

  @override
  String get desktopChatsOnline => 'у мережі';

  @override
  String desktopChatsSomeoneTyping(Object name) {
    return '$name пише';
  }

  @override
  String get desktopChatsLoadingList => 'Підтягуємо перелік із локального сховища.';

  @override
  String get desktopChatsWillAppear => 'Повідомлення та дзвінки з’являться тут, щойно ви відкриєте чат.';

  @override
  String get desktopRoomNoOpenHere => 'Відкрити листування звідси не можна';

  @override
  String get desktopRoomIdCopied => 'ID скопійовано';

  @override
  String get desktopRoomAwaiting => 'Чекає схвалення';

  @override
  String get desktopRoomBlocked => 'Заблокований';

  @override
  String get desktopRoomCopied => 'Скопійовано';

  @override
  String get desktopRoomChangeRole => 'Змінити роль';

  @override
  String get desktopRoomTransfer => 'Передати володіння';

  @override
  String get desktopRoomBlockMember => 'Заблокувати';

  @override
  String get desktopRoomKick => 'Виключити';

  @override
  String get desktopRoomKickTitle => 'Виключити учасника?';

  @override
  String desktopRoomKickBody(Object name) {
    return '$name втратить доступ до кімнати. Повернути його можна новим запрошенням.';
  }

  @override
  String get desktopRoomBlockTitle => 'Заблокувати учасника?';

  @override
  String desktopRoomBlockBody(Object name) {
    return '$name не зможе повернутися до кімнати навіть за запрошенням, доки блокування не знімуть.';
  }

  @override
  String get desktopRoomTransferTitle => 'Передати володіння кімнатою?';

  @override
  String desktopRoomTransferBody(Object name) {
    return '$name стане власником, а ви — адміністратором. Скасувати це зможе лише новий власник.';
  }

  @override
  String get desktopRoomTransferAction => 'Передати';

  @override
  String get desktopRoomClearTitle => 'Очистити історію?';

  @override
  String get desktopRoomClearBody => 'Усі повідомлення кімнати на цьому пристрої буде видалено.';

  @override
  String get desktopRoomLeaveTitle => 'Покинути кімнату?';

  @override
  String get desktopRoomLeaveBody => 'Ви перестанете отримувати повідомлення. Щоб повернутися, знадобиться нове запрошення.';

  @override
  String get desktopRoomLeave => 'Покинути';

  @override
  String get desktopRoomInvite => 'Запросити';

  @override
  String get desktopRoomCopyId => 'Копіювати ID кімнати';

  @override
  String get desktopRoomMuteOff => 'Вимкнути сповіщення';

  @override
  String get desktopRoomUnarchive => 'Повернути з архіву';

  @override
  String get desktopRoomLeaveRoom => 'Покинути кімнату';

  @override
  String get desktopRoomUntitled => 'Без назви';

  @override
  String get desktopRoomCopyInvite => 'Скопіювати запрошення';

  @override
  String get desktopRoomSound => 'Звук';

  @override
  String get desktopRoomTabInfo => 'Інфо';

  @override
  String get desktopRoomTabMembers => 'Учасники';

  @override
  String get desktopRoomTabMedia => 'Медіа';

  @override
  String get desktopRoomTopics => 'ТЕМИ';

  @override
  String desktopRoomTopicsCount(Object count) {
    return 'ТЕМИ · $count';
  }

  @override
  String get desktopRoomDescription => 'Опис';

  @override
  String get desktopRoomNotes => 'НОТАТКИ';

  @override
  String get desktopRoomInformation => 'Інформація';

  @override
  String get desktopRoomId => 'ID кімнати';

  @override
  String get desktopRoomInviteLink => 'Посилання-запрошення · натисніть, щоб скопіювати';

  @override
  String get desktopRoomFavouriteHint => 'Плитка на рейці та місце вгорі переліку';

  @override
  String get desktopRoomArchiveHint => 'Сховати кімнату з основного переліку';

  @override
  String get desktopRoomNoMembers => 'Немає учасників';

  @override
  String desktopRoomMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count учасника',
      many: '$count учасників',
      few: '$count учасники',
      one: '$count учасник',
    );
    return '$_temp0';
  }

  @override
  String get desktopRoomNobodyFound => 'Нікого не знайдено';

  @override
  String get desktopRoomMembersUnavailable => 'Перелік учасників недоступний.';

  @override
  String get desktopRoomInCall => 'У ДЗВІНКУ';

  @override
  String get desktopRoomOnline => 'У МЕРЕЖІ';

  @override
  String get desktopRoomOffline => 'НЕ В МЕРЕЖІ';

  @override
  String desktopRoomMoreHidden(Object count) {
    return 'Ще $count — знайдіть пошуком вище';
  }

  @override
  String get desktopRoomSearchMember => 'Пошук учасника';

  @override
  String get desktopRoomJoinRequests => 'Заявки на вступ';

  @override
  String get desktopRoomAccept => 'Прийняти';

  @override
  String get desktopRoomDecline => 'Відхилити';

  @override
  String get desktopRoomRoleOwner => 'Власник';

  @override
  String get desktopRoomRoleAdmin => 'Адміністратор';

  @override
  String get desktopRoomRoleModerator => 'Модератор';

  @override
  String get desktopRoomRoleRestricted => 'Обмежений';

  @override
  String get desktopRoomRoleGuest => 'Гість';

  @override
  String get desktopContactBlockTitle => 'Заблокувати?';

  @override
  String get desktopContactUnblockTitle => 'Розблокувати?';

  @override
  String get desktopContactBlockBody => 'Співрозмовник більше не зможе надсилати вам повідомлення й дзвонити.';

  @override
  String get desktopContactUnblockBody => 'Співрозмовник знову зможе з вами зв’язатися.';

  @override
  String get desktopContactBlock => 'Заблокувати';

  @override
  String get desktopContactCallsNotReady => 'Служба дзвінків ще не готова';

  @override
  String get desktopContactCallInProgress => 'Дзвінок уже триває';

  @override
  String desktopContactCallFailed(Object error) {
    return 'Не вдалося почати дзвінок: $error';
  }

  @override
  String get desktopContactAutoDelete => 'Автовидалення повідомлень';

  @override
  String get desktopContactAutoDeleteUpdated => 'Автовидалення оновлено';

  @override
  String get desktopContactClearBody => 'Усі повідомлення цього чату на цьому пристрої буде видалено.';

  @override
  String get desktopContactDeleteBody => 'Чат повністю видалиться з цього пристрою.';

  @override
  String get desktopContactOff => 'Вимкнено';

  @override
  String get desktopContactDisable => 'Вимкнути';

  @override
  String get desktopContactDay1 => '1 день';

  @override
  String get desktopContactDays7 => '7 днів';

  @override
  String get desktopContactDays30 => '30 днів';

  @override
  String get desktopContactHour1 => '1 година';

  @override
  String desktopContactMinutes(Object value) {
    return '$value хв';
  }

  @override
  String get desktopContactOffline => 'не в мережі';

  @override
  String desktopContactSeenAt(Object time) {
    return 'був(ла) о $time';
  }

  @override
  String get desktopContactSeenYesterday => 'був(ла) учора';

  @override
  String desktopContactSeenOn(Object date) {
    return 'був(ла) $date';
  }

  @override
  String get desktopContactCopyId => 'Копіювати ID';

  @override
  String get desktopContactCopyIdShort => 'Скопіювати ID';

  @override
  String get desktopContactDisappearing => 'Автовидалення на моїх пристроях';

  @override
  String get desktopContactDeleteChat => 'Видалити чат';

  @override
  String get desktopContactCall => 'Дзвінок';

  @override
  String get desktopContactBlockShort => 'Блок';

  @override
  String get desktopContactSecurity => 'Безпека';

  @override
  String get desktopContactVerify => 'Перевірити контакт';

  @override
  String get desktopContactArchiveHint => 'Сховати чат з основного переліку';

  @override
  String get desktopThreadMessageHint => 'Повідомлення…';

  @override
  String get desktopThreadPasteFailed => 'Не вдалося вставити зображення';

  @override
  String get desktopThreadNoScheduleEdit => 'Правку не можна відкласти — вона змінює вже надіслане';

  @override
  String desktopThreadWillLeave(Object when) {
    return 'Піде $when';
  }

  @override
  String desktopThreadSeconds(Object value) {
    return '$value с';
  }

  @override
  String desktopThreadMinutes(Object value) {
    return '$value хв';
  }

  @override
  String desktopThreadHours(Object value) {
    return '$value год';
  }

  @override
  String desktopThreadDays(Object value) {
    return '$value дн';
  }

  @override
  String desktopThreadWeeks(Object value) {
    return '$value тиж';
  }

  @override
  String desktopThreadSelected(Object count) {
    return 'Вибрано: $count';
  }

  @override
  String get desktopThreadDisappearingOn => 'Автовидалення ввімкнено — лише на моїх пристроях';

  @override
  String get desktopThreadCallAction => 'Подзвонити';

  @override
  String get desktopThreadCallRoom => 'Дзвінок';

  @override
  String get desktopThreadVideoCall => 'Відеодзвінок';

  @override
  String get desktopThreadSearchShortcut => 'Пошук у чаті  Cmd F';

  @override
  String get desktopThreadHideDetails => 'Сховати подробиці';

  @override
  String get desktopThreadShowDetails => 'Показати подробиці';

  @override
  String get desktopThreadMore => 'Ще';

  @override
  String get desktopThreadPinned => 'Закріплене повідомлення';

  @override
  String get desktopThreadNoMatches => 'немає збігів';

  @override
  String get desktopThreadSearchHint => 'Пошук у чаті…';

  @override
  String get desktopThreadPrevMatch => 'Попереднє (Shift F3)';

  @override
  String get desktopThreadNextMatch => 'Наступне (F3)';

  @override
  String get desktopThreadCloseEsc => 'Закрити (Esc)';

  @override
  String get desktopThreadNewMessages => 'Нові повідомлення';

  @override
  String desktopThreadUnreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count непрочитаних',
      many: '$count непрочитаних',
      few: '$count непрочитані',
      one: '$count непрочитане',
    );
    return '$_temp0';
  }

  @override
  String get desktopThreadToday => 'Сьогодні';

  @override
  String get desktopThreadYesterday => 'Вчора';

  @override
  String get desktopProfileEmojiStatus => 'Емодзі-статус';

  @override
  String get desktopProfileClearStatus => 'Прибрати статус';

  @override
  String desktopProfileApplyFailed(Object error) {
    return 'Не вдалося застосувати: $error';
  }

  @override
  String get desktopProfileAvatarFrame => 'Рамка аватара';

  @override
  String get desktopProfileCover => 'Обкладинка профілю';

  @override
  String get desktopProfileNoFrame => 'Без рамки';

  @override
  String get desktopProfileNoCover => 'Без обкладинки';

  @override
  String get desktopProfileReadFailed => 'Не вдалося прочитати файл';

  @override
  String get desktopProfilePhotoUpdated => 'Фото профілю оновлено';

  @override
  String desktopProfilePhotoFailed(Object error) {
    return 'Не вдалося оновити фото: $error';
  }

  @override
  String desktopProfilePhotoRemoveFailed(Object error) {
    return 'Не вдалося прибрати фото: $error';
  }

  @override
  String get desktopProfileMine => 'Мій профіль';

  @override
  String get desktopProfileEdit => 'Редагувати';

  @override
  String get desktopProfileName => 'Ім’я';

  @override
  String get desktopProfileChangePhoto => 'Змінити фото';

  @override
  String get desktopProfileFrameShort => 'Рамка';

  @override
  String get desktopProfileCoverShort => 'Обкладинка';

  @override
  String get desktopProfileStatus => 'Статус';

  @override
  String get desktopProfileAppearanceHint => 'Тема, акцент і шпалери чату';

  @override
  String get desktopProfileAbout => 'Про себе';

  @override
  String get desktopProfileEmpty => 'Не заповнено';

  @override
  String get desktopProfilePhoto => 'Фото профілю';

  @override
  String get desktopProfileReplacePhoto => 'Замінити фото';

  @override
  String get desktopProfilePickPhoto => 'Обрати фото';

  @override
  String get desktopProfilePickedHere => 'Обрано на цьому комп’ютері';

  @override
  String get desktopProfileSyncedWithPhone => 'Синхронізовано з телефоном';

  @override
  String get desktopProfileNotPicked => 'Не обрано';

  @override
  String get desktopProfileRemovePhoto => 'Прибрати фото';

  @override
  String get desktopProfileInitialsStay => 'Залишаться ініціали';

  @override
  String get desktopProfileAccount => 'Обліковий запис';

  @override
  String get desktopProfileRecovery => 'Відновлення';

  @override
  String get desktopProfileRecoveryHint => 'Цей комп’ютер підключений до телефона і своєї фрази відновлення не зберігає: обліковий запис повертає копія та набір відновлення.';

  @override
  String get desktopProfileDevicesHint => 'Підключені комп’ютери та телефони';

  @override
  String get desktopProfileFrameCaps => 'РАМКА АВАТАРА';

  @override
  String get desktopGalleryMedia => 'Медіа';

  @override
  String get desktopGalleryFiles => 'Файли';

  @override
  String get desktopGalleryLinks => 'Посилання';

  @override
  String get desktopGalleryNoMedia => 'Немає медіа';

  @override
  String get desktopGalleryNoFiles => 'Немає файлів';

  @override
  String get desktopGalleryNoAudio => 'Немає аудіо';

  @override
  String get desktopGalleryNoLinks => 'Немає посилань';

  @override
  String get desktopGalleryPathCopied => 'Шлях скопійовано';

  @override
  String get desktopGalleryOpen => 'Відкрити';

  @override
  String get desktopGalleryView => 'Перегляд';

  @override
  String get desktopGalleryOpenInSystem => 'Відкрити в системі';

  @override
  String get desktopGalleryRevealFinder => 'Показати у Finder';

  @override
  String get desktopGalleryRevealExplorer => 'Показати в провіднику';

  @override
  String get desktopGalleryOpenFolder => 'Відкрити теку';

  @override
  String get desktopGalleryCopyPath => 'Копіювати шлях';

  @override
  String desktopGalleryBytes(Object value) {
    return '$value Б';
  }

  @override
  String get desktopGalleryZeroBytes => '0 Б';

  @override
  String desktopOutgoingFolderSingle(Object name) {
    return 'теку «$name» надіслати не можна';
  }

  @override
  String get desktopOutgoingFoldersMany => 'теки надіслати не можна';

  @override
  String desktopOutgoingTooLargeOne(Object name, Object limit) {
    return '«$name» більше за $limit МБ';
  }

  @override
  String desktopOutgoingTooLargeMany(int count, Object limit) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count файла більші за $limit МБ',
      many: '$count файлів більші за $limit МБ',
      few: '$count файли більші за $limit МБ',
      one: '$count файл більший за $limit МБ',
    );
    return '$_temp0';
  }

  @override
  String desktopOutgoingEmptyOne(Object name) {
    return '«$name» порожній';
  }

  @override
  String desktopOutgoingEmptyMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count файла порожні',
      many: '$count файлів порожні',
      few: '$count файли порожні',
      one: '$count файл порожній',
    );
    return '$_temp0';
  }

  @override
  String desktopOutgoingUnreadableOne(Object name) {
    return '«$name» не вдалося прочитати';
  }

  @override
  String desktopOutgoingUnreadableMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count файла не вдалося прочитати',
      many: '$count файлів не вдалося прочитати',
      few: '$count файли не вдалося прочитати',
      one: '$count файл не вдалося прочитати',
    );
    return '$_temp0';
  }

  @override
  String get desktopOutgoingSending => 'Надсилання';

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
      other: '$count відео',
      one: '$count відео',
    );
    return '$_temp0';
  }

  @override
  String desktopOutgoingMedia(Object count) {
    return '$count медіа';
  }

  @override
  String desktopOutgoingAudios(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count аудіо',
      one: '$count аудіо',
    );
    return '$_temp0';
  }

  @override
  String desktopOutgoingFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count файла',
      many: '$count файлів',
      few: '$count файли',
      one: '$count файл',
    );
    return '$_temp0';
  }

  @override
  String get desktopCallsPickOne => 'Оберіть дзвінок ліворуч';

  @override
  String get desktopCallsPickHint => 'Тут з’являться подробиці та кнопка передзвонити';

  @override
  String get desktopCallsNone => 'Дзвінків поки немає';

  @override
  String get desktopCallsNoneHint => 'Історія з’явиться після першого дзвінка';

  @override
  String get desktopCallsOutgoing => 'Вихідний';

  @override
  String get desktopCallsIncoming => 'Вхідний';

  @override
  String get desktopCallsGroup => 'груповий';

  @override
  String get desktopCallsVideoKind => 'відео';

  @override
  String get desktopCallsAudioKind => 'аудіо';

  @override
  String get desktopCallsMissed => 'пропущений';

  @override
  String desktopPhotoCopyFailed(Object error) {
    return 'Не вдалося скопіювати: $error';
  }

  @override
  String get desktopPhotoSave => 'Зберегти фото';

  @override
  String get desktopPhotoSaved => 'Збережено';

  @override
  String desktopPhotoRevealFailed(Object error) {
    return 'Не вдалося показати у Finder: $error';
  }

  @override
  String get desktopPhotoLoadFailed => 'Не вдалося завантажити';

  @override
  String get desktopPhotoZoomOut => 'Зменшити';

  @override
  String get desktopPhotoZoomReset => 'Скинути масштаб';

  @override
  String get desktopPhotoZoomIn => 'Збільшити';

  @override
  String get desktopPhotoCopy => 'Скопіювати';

  @override
  String desktopBubbleForwardedFrom(Object from) {
    return 'Переслано від $from';
  }

  @override
  String get desktopBubbleAudioFile => 'Аудіофайл';

  @override
  String get desktopBubbleTranslating => 'Перекладаємо…';

  @override
  String get desktopBubbleTranslation => 'ПЕРЕКЛАД';

  @override
  String get desktopBubbleEdited => 'змінено';

  @override
  String get desktopBubbleMoreReactions => 'Більше реакцій';

  @override
  String get desktopBubbleRoleOwner => 'власник';

  @override
  String get desktopBubbleRoleAdmin => 'адмін';

  @override
  String get desktopBubbleRoleMod => 'модер';

  @override
  String get desktopBubbleSpeed => 'Швидкість відтворення';

  @override
  String get desktopSpotlightGoChats => 'Перейти до чатів';

  @override
  String get desktopSpotlightGoRooms => 'Перейти до кімнат';

  @override
  String get desktopSpotlightGoContacts => 'Перейти до контактів';

  @override
  String get desktopSpotlightGoCalls => 'Перейти до дзвінків';

  @override
  String get desktopSpotlightSelect => 'вибір';

  @override
  String get desktopSpotlightOpen => 'відкрити';

  @override
  String get desktopSpotlightClose => 'закрити';

  @override
  String get desktopSpotlightRoom => 'Кімната';

  @override
  String get desktopSpotlightMessage => 'Повідомлення';

  @override
  String get desktopSpotlightCommand => 'Команда';

  @override
  String get desktopComposerCancelRec => 'Скасувати запис';

  @override
  String desktopComposerRecording(Object time) {
    return 'Запис  $time';
  }

  @override
  String get desktopComposerSendVoice => 'Надіслати голосове';

  @override
  String get desktopComposerAttach => 'Прикріпити';

  @override
  String get desktopComposerEmoji => 'Емодзі та стікери';

  @override
  String get desktopComposerRecordVoice => 'Записати голосове';

  @override
  String get desktopComposerEnterSends => 'Enter — надіслати · Shift+Enter — перенос';

  @override
  String get desktopComposerEnterNewline => 'Enter — перенос · Shift+Enter — надіслати';

  @override
  String get desktopComposerEditing => 'Редагування';

  @override
  String desktopComposerReplyTo(Object name) {
    return 'Відповідь · $name';
  }

  @override
  String get desktopComposerCancelAction => 'Скасувати';

  @override
  String get desktopComposerSendHint => 'Надіслати · Enter\nПрава кнопка — надіслати пізніше';

  @override
  String get desktopComposerWriteFirst => 'Спочатку напишіть повідомлення';

  @override
  String desktopComposerToTopic(Object title) {
    return 'у тему «$title»';
  }

  @override
  String get desktopShortcutsNavigation => 'Навігація';

  @override
  String get desktopShortcutsTabs => 'Чати · Кімнати · Дзвінки · Контакти';

  @override
  String get desktopShortcutsSearchAll => 'Пошук по чатах і повідомленнях';

  @override
  String get desktopShortcutsPrevNext => 'Попередній / наступний чат';

  @override
  String get desktopShortcutsInChat => 'У листуванні';

  @override
  String get desktopShortcutsFindHere => 'Знайти в цьому листуванні';

  @override
  String get desktopShortcutsSend => 'Надіслати (налаштовується)';

  @override
  String get desktopShortcutsNewline => 'Перенос рядка';

  @override
  String get desktopShortcutsPaste => 'Вставити зображення з буфера';

  @override
  String get desktopShortcutsApp => 'Застосунок';

  @override
  String get desktopShortcutsThisHelp => 'Ця довідка';

  @override
  String get desktopShortcutsCloseWindow => 'Закрити вікно або пошук';

  @override
  String get desktopShortcutsTray => 'Згорнути в трей';

  @override
  String get desktopShortcutsTitle => 'Гарячі клавіші';

  @override
  String get desktopMediaCancelSend => 'Скасувати надсилання';

  @override
  String get desktopMediaSending => 'Надсилання…';

  @override
  String desktopMediaSendingOf(Object total) {
    return 'Надсилання… · $total';
  }

  @override
  String get desktopMediaRetryDownload => 'Повторити завантаження';

  @override
  String get desktopMediaImage => 'Зображення';

  @override
  String desktopMediaDownloading(Object size) {
    return 'Завантаження… · $size';
  }

  @override
  String get desktopMediaDownload => 'Завантажити';

  @override
  String get desktopSendAsMedia => 'Надіслати як медіа';

  @override
  String get desktopSendAsFiles => 'Надіслати як файли';

  @override
  String get desktopSendUngroup => 'Не групувати';

  @override
  String get desktopSendGroup => 'Групувати';

  @override
  String get desktopSendAddFiles => 'Додати файли…';

  @override
  String get desktopSendDropHere => 'Відпустіть, щоб додати';

  @override
  String get desktopSendCloseEsc => 'Закрити · Esc';

  @override
  String desktopSendToDestination(Object destination) {
    return 'у «$destination»';
  }

  @override
  String get desktopSendCaptionHint => 'Додати підпис…';

  @override
  String get desktopSendEmoji => 'Емодзі';

  @override
  String get desktopSendRemove => 'Прибрати';

  @override
  String get desktopSendEnter => 'Надіслати · Enter';

  @override
  String get desktopSendShiftEnter => 'Надіслати · Shift+Enter';

  @override
  String get desktopCallCtlShareStop => 'Зупинити демонстрацію';

  @override
  String get desktopCallCtlShare => 'Демонстрація екрана';

  @override
  String desktopAbsenceDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дня',
      many: '$count днів',
      few: '$count дні',
      one: '$count день',
    );
    return '$_temp0';
  }

  @override
  String desktopAbsencePastFanout(Object days) {
    return 'Цей комп’ютер не виходив на зв’язок $days. За цей час відправники перестали шифрувати повідомлення для нього, і частина листування сюди не прийде. Вона ціла на телефоні — відкрийте там потрібні чати, і свіжа історія підтягнеться.';
  }

  @override
  String desktopAbsenceWithinWindow(Object days) {
    return 'Цей комп’ютер не виходив на зв’язок $days. Повідомлення зберігаються на сервері тиждень, тому частина з них могла не зберегтися для нього. На телефоні вони цілі.';
  }

  @override
  String get desktopAbsenceGotIt => 'Зрозуміло';

  @override
  String get desktopNavContacts => 'Контакти';

  @override
  String get desktopChatNotFound => 'Листування не знайдено';

  @override
  String desktopUnreadTitle(Object count) {
    return 'Secretly — $count непрочитаних';
  }

  @override
  String get desktopRoomsNone => 'Кімнат поки немає';

  @override
  String get desktopRoomsNoneHint => 'Створіть кімнату з телефона — вона з’явиться тут автоматично';

  @override
  String get desktopRoomsPickOne => 'Оберіть кімнату ліворуч';

  @override
  String get desktopScheduleTitle => 'Надіслати пізніше';

  @override
  String get desktopScheduleInHour => 'Через годину';

  @override
  String get desktopScheduleTonight => 'Сьогодні о 19:00';

  @override
  String get desktopScheduleTomorrow => 'Завтра о 9:00';

  @override
  String get desktopScheduleInWeek => 'Через тиждень';

  @override
  String desktopScheduleTodayAt(Object time) {
    return 'сьогодні о $time';
  }

  @override
  String desktopScheduleTomorrowAt(Object time) {
    return 'завтра о $time';
  }

  @override
  String desktopScheduleOnAt(Object date, Object time) {
    return '$date о $time';
  }

  @override
  String get desktopScheduleHint => 'Повідомлення піде саме в обраний час — навіть якщо вікно закрите, воно надішлеться під час наступного запуску.';

  @override
  String get desktopSchedulePickTime => 'Обрати час…';

  @override
  String get desktopDevicesSearching => 'Шукаємо пристрої…';

  @override
  String get desktopDevicesNoCameras => 'Камер не знайдено. Можливо, застосунку не надали до них доступ у налаштуваннях системи.';

  @override
  String get desktopDevicesNoMics => 'Мікрофонів не знайдено. Можливо, застосунку не надали до них доступ у налаштуваннях системи.';

  @override
  String get desktopDevicesOutputHint => 'Куди виводити звук, обирається в самому дзвінку — шевроном біля «Мікрофона». Там же застосунок сам перемикається на навушники, коли їх під’єднують.';

  @override
  String get desktopDevicesSystemDefault => 'Як обрано в системі';

  @override
  String get desktopRailSettings => 'Налаштування   Cmd ,';

  @override
  String get desktopRailConnected => 'Підключено';

  @override
  String get desktopRailConnecting => 'Підключення…';

  @override
  String get desktopRailOffline => 'Немає з’єднання';

  @override
  String desktopRailProfile(Object status) {
    return 'Профіль   Cmd P   ·   $status';
  }

  @override
  String get desktopEmojiSmileys => 'Смайлики та емоції';

  @override
  String get desktopEmojiPeople => 'Люди й тіло';

  @override
  String get desktopEmojiNature => 'Природа';

  @override
  String get desktopEmojiFood => 'Їжа та напої';

  @override
  String get desktopEmojiTravel => 'Подорожі';

  @override
  String get desktopEmojiActivities => 'Активності';

  @override
  String get desktopEmojiObjects => 'Предмети';

  @override
  String get desktopEmojiSymbols => 'Символи';

  @override
  String get desktopEmojiFlags => 'Прапори';

  @override
  String get desktopEmojiOther => 'Інше';

  @override
  String get desktopLockedTitle => 'Secretly заблоковано';

  @override
  String get desktopLockedTouchIdPrompt => 'Підтвердьте особу через Touch ID, щоб продовжити.';

  @override
  String get desktopLockedPasswordPrompt => 'Підтвердьте паролем пристрою, щоб продовжити.';

  @override
  String get desktopLockedUnlock => 'Розблокувати';

  @override
  String get desktopLockedWaiting => 'Очікуємо підтвердження…';

  @override
  String get desktopLockedFailed => 'Не вдалося підтвердити особу.';

  @override
  String get desktopLockedNoService => 'Служба перевірки особи недоступна на цьому комп\'ютері. Перезапустіть Secretly або комп\'ютер. Якщо не допоможе — напишіть у підтримку з телефона.';

  @override
  String get desktopEmojiTabEmoji => 'Емодзі';

  @override
  String get desktopEmojiTabStickers => 'Стікери';

  @override
  String get desktopEmojiRecents => 'Нещодавні';

  @override
  String get desktopEmojiNothingFound => 'Нічого не знайшлося';

  @override
  String get desktopEmojiSearchHint => 'Пошук емодзі';

  @override
  String get desktopStickersSearchHint => 'Пошук стікерів';

  @override
  String get desktopGifSearchHint => 'Пошук GIF';

  @override
  String get desktopGifUnavailable => 'GIF недоступні в цьому вікні';

  @override
  String get desktopStickerPacksSoon => 'Стікерпаки скоро';

  @override
  String get desktopCallFullscreen => 'На весь екран';

  @override
  String get desktopCallExitFullscreen => 'Вийти з повноекранного';

  @override
  String get desktopCallDialing => 'Виклик…';

  @override
  String get desktopCallEnded => 'Завершено';

  @override
  String desktopCallEncryptedFor(Object duration) {
    return 'Зашифровано · $duration';
  }

  @override
  String get desktopCallReturn => 'Повернутися';

  @override
  String get desktopCallInProgress => 'Триває дзвінок';

  @override
  String desktopCallInProgressWith(Object title) {
    return 'Триває дзвінок · $title';
  }

  @override
  String get desktopCallAnswer => 'Відповісти';

  @override
  String get desktopCallAnswerVideo => 'Відповісти з відео';

  @override
  String get desktopCallAnswerText => 'Текстом';

  @override
  String get desktopTimeYesterday => 'учора';

  @override
  String get desktopForwardTitle => 'Переслати в…';

  @override
  String get desktopForwardSearchHint => 'Пошук чату або кімнати';

  @override
  String get desktopForwardNoChats => 'Немає доступних чатів';

  @override
  String get desktopForwardKindDirect => 'Особистий чат';

  @override
  String get desktopContactsSearchHint => 'Пошук контактів';

  @override
  String get desktopContactsEmpty => 'Поки нікого. Додайте контакт за ID або посиланням-запрошенням.';

  @override
  String desktopContactsNothingFor(Object query) {
    return 'Нічого не знайдено за запитом «$query».';
  }

  @override
  String get desktopContactsPick => 'Виберіть контакт';

  @override
  String get desktopContactsCardRight => 'Картка з\'явиться праворуч.';

  @override
  String get desktopContactsWrite => 'Написати повідомлення';

  @override
  String get desktopVideoTitle => 'Відео';

  @override
  String get desktopViewerCloseEsc => 'Закрити  Esc';

  @override
  String get desktopVideoPlayFailed => 'Не вдалося відтворити відео';

  @override
  String get desktopKeySpace => 'Пробіл';

  @override
  String get desktopWindowMinimize => 'Згорнути';

  @override
  String get desktopWindowMaximize => 'Розгорнути';

  @override
  String get desktopWindowClose => 'Закрити';

  @override
  String get desktopWindowBack => 'Назад';

  @override
  String get desktopWindowForward => 'Вперед';

  @override
  String get desktopSearchEverything => 'Чати, люди, повідомлення, файли';

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
  String get desktopSyncDone => 'Синхронізовано';

  @override
  String get desktopSyncSyncing => 'Синхронізація…';

  @override
  String get desktopSyncReconnecting => 'Перепідключення…';

  @override
  String get desktopDetailsShare => 'Поділитися';

  @override
  String get desktopDetailsHide => 'Сховати';

  @override
  String get desktopDetailsMore => 'Додатково';

  @override
  String get desktopDetailsChangeCover => 'Змінити обкладинку';

  @override
  String desktopDetailsFrame(Object name) {
    return 'Рамка «$name»';
  }

  @override
  String get desktopApply => 'Застосувати';

  @override
  String get desktopAccentAppliesTo => 'Кнопки, виділення та кільця. Бульбашка лишається у своєму стилі — він вибирається нижче.';

  @override
  String get desktopTranslateUnknownSource => 'Не вдалося визначити мову повідомлення';

  @override
  String get desktopTranslateUnsupported => 'Системний перекладач не знає цієї пари мов';

  @override
  String get desktopTranslateNeedsDownload => 'Мову не завантажено. Системні параметри → Основні → Мова й регіон → Мови перекладу';

  @override
  String get desktopTranslateFailed => 'Не вдалося перекласти';

  @override
  String get desktopNewChatSearchHint => 'Пошук за контактами';

  @override
  String get desktopNewChatNoContacts => 'Контактів поки немає';

  @override
  String get desktopNewChatNobodyFound => 'Нікого не знайшлося';

  @override
  String get desktopMentionEveryone => 'Усі учасники';

  @override
  String get desktopMentionAdmins => 'Адміністратори';

  @override
  String get desktopMentionEveryoneHint => 'Покликати всіх у кімнаті';

  @override
  String get desktopMentionAdminsHint => 'Покликати власника й адміністраторів';

  @override
  String desktopClearForPeer(Object name) {
    return 'Очистити історію в співрозмовника ($name)';
  }

  @override
  String get desktopClearForPeerHint => 'Повідомлення зникнуть і на його пристрої, і на всіх ваших. Скасувати це не можна.';

  @override
  String get desktopGifNoKey => 'GIF недоступні: збірка без ключа GIPHY';

  @override
  String get desktopGifConnectionLost => 'Зв\'язок перервався. Спробуйте ще раз';

  @override
  String get desktopNotesHint => 'Що запамʼятати з цієї розмови…';

  @override
  String get desktopNotesPrivate => 'Видно лише вам. Не надсилається, не потрапляє в листування і не входить до резервної копії — живе на цьому комп’ютері, у тій самій зашифрованій базі, що й повідомлення.';

  @override
  String get desktopEmojiSearchShort => 'Пошук емодзі…';

  @override
  String get desktopNotifOpen => 'Відкрити';

  @override
  String get desktopLinkPreviewLoading => 'Попередній перегляд посилання…';

  @override
  String get desktopLinkPreviewOff => 'Без перегляду';

  @override
  String get desktopDropToSend => 'Відпустіть, щоб надіслати';

  @override
  String get desktopDropEncrypted => 'Файли буде зашифровано перед надсиланням';

  @override
  String get desktopDetailsPickChat => 'Виберіть чат';

  @override
  String get desktopDetailsEmptyHint => 'Відомості про співрозмовника або кімнату\nзʼявляться тут.';

  @override
  String get desktopMemberWrite => 'Написати';

  @override
  String get desktopShowPanel => 'Показати панель';

  @override
  String get desktopHidePanel => 'Сховати панель';

  @override
  String get desktopNotifOff => 'Сповіщення вимкнено';

  @override
  String get desktopSettingsSearchHint => 'Знайти налаштування';

  @override
  String get desktopUnlockPrompt => 'Розблокувати Secretly';

  @override
  String get desktopEnableLockPrompt => 'Підтвердьте, щоб увімкнути блокування Secretly';

  @override
  String get desktopRoomsNoneHintDot => 'Створіть кімнату з телефона — вона зʼявиться тут автоматично.';

  @override
  String get desktopSplashLoading => 'Завантаження профілю…';

  @override
  String get desktopOutgoingOnePhoto => 'Фото';

  @override
  String get desktopOutgoingOneVideo => 'Відео';

  @override
  String get desktopOutgoingOneAudio => 'Аудіо';

  @override
  String get desktopOutgoingOneFile => 'Файл';

  @override
  String get desktopMenuSettings => 'Налаштування…';

  @override
  String get desktopMenuEdit => 'Редагування';

  @override
  String get desktopMenuUndo => 'Скасувати';

  @override
  String get desktopMenuRedo => 'Повторити';

  @override
  String get desktopMenuCut => 'Вирізати';

  @override
  String get desktopMenuPaste => 'Вставити';

  @override
  String get desktopMenuSelectAll => 'Вибрати все';

  @override
  String get desktopMenuView => 'Вигляд';

  @override
  String get desktopMenuWindow => 'Вікно';

  @override
  String get desktopMenuHelp => 'Довідка';

  @override
  String get desktopMenuWebsite => 'Сайт Secretly';

  @override
  String get desktopContactsAddHint => 'ID у Secretly або посилання-запрошення';

  @override
  String get desktopContactsAdded => 'Контакт додано';

  @override
  String get desktopContactsRenamed => 'Ім’я збережено';

  @override
  String get desktopMenuCheckUpdates => 'Перевірити оновлення…';

  @override
  String get desktopNotifBlockedTitle => 'Система не показує сповіщення Secretly';

  @override
  String get desktopNotifBlockedBody => 'Перемикачі нижче працюють, але показати їх нікому: сповіщення застосунку заборонені в налаштуваннях системи. Вікно часто приховане, і сповіщення — єдиний спосіб дізнатися про нове повідомлення.';

  @override
  String get desktopNotifBlockedAction => 'Відкрити налаштування системи';

  @override
  String get backupPwRequirements => 'Щонайменше 8 символів, латиниця/ASCII, одна велика літера й один спецсимвол. Без пробілів на початку та в кінці.';

  @override
  String backupPwTooShort(int count) {
    return 'Пароль має містити щонайменше $count символів.';
  }

  @override
  String backupPwTooLong(int count) {
    return 'Пароль має бути не довшим за $count символів.';
  }

  @override
  String get backupPwNonAscii => 'Використовуйте лише латиницю, цифри та ASCII-символи.';

  @override
  String get backupPwOuterSpace => 'Приберіть пробіли на початку або в кінці пароля.';

  @override
  String get backupPwNeedUpper => 'Додайте щонайменше одну велику літеру A-Z.';

  @override
  String get backupPwNeedSpecial => 'Додайте щонайменше один спецсимвол, наприклад !, # або ?.';

  @override
  String get desktopAuthGateTitle => 'Secretly на цьому комп’ютері';

  @override
  String get desktopAuthGateSubtitle => 'Виберіть, як увійти';

  @override
  String get desktopAuthPhoneTitle => 'Увійти через телефон';

  @override
  String get desktopAuthPhoneBody => 'Якщо Secretly уже є на телефоні. Листування та контакти переїдуть сюди.';

  @override
  String get desktopAuthCreateTitle => 'Створити новий акаунт';

  @override
  String get desktopAuthCreateBody => 'Акаунт лише на цьому комп’ютері. Передплату можна оформити тільки в застосунку на телефоні.';

  @override
  String get desktopAuthRestoreTitle => 'Відновити';

  @override
  String get desktopAuthRestoreBody => 'З набору відновлення або з копії на сервері.';

  @override
  String get desktopAuthBack => 'Назад';

  @override
  String get desktopAuthNameTitle => 'Як вас звати?';

  @override
  String get desktopAuthNameBody => 'Це ім’я побачать ті, кому ви напишете. Його можна змінити будь-коли.';

  @override
  String get desktopAuthCreating => 'Створюємо акаунт…';

  @override
  String desktopAuthCreateFailed(Object error) {
    return 'Не вдалося створити акаунт: $error';
  }

  @override
  String get desktopAuthCheckClock => 'Перевірте годинник комп’ютера: за розбіжності сервер відхиляє запит.';

  @override
  String get desktopAuthKitTitle => 'Збережіть набір відновлення';

  @override
  String get desktopAuthKitBody => 'Це єдиний спосіб повернути акаунт, якщо комп’ютер зламається або загубиться. У Secretly немає ні пошти, ні номера телефону: без набору акаунт не поверне ніхто, зокрема й ми.';

  @override
  String get desktopAuthKitAction => 'Створити набір відновлення';

  @override
  String get desktopAuthKitSaved => 'Набір збережено. Тепер акаунт можна повернути.';

  @override
  String get desktopAuthContinue => 'Продовжити';

  @override
  String get desktopAuthKitOptionTitle => 'У мене є набір відновлення';

  @override
  String get desktopAuthKitOptionBody => 'Найпростіший шлях: у наборі вже записано ваш Secretly ID.';

  @override
  String get desktopAuthKitPasteHint => 'Вставте вміст набору';

  @override
  String get desktopAuthServerOptionTitle => 'Копія на сервері';

  @override
  String get desktopAuthServerOptionBody => 'Знадобляться ваш Secretly ID і пароль копії.';

  @override
  String get desktopAuthRestoring => 'Відновлюємо…';

  @override
  String desktopAuthRestoreFailed(Object error) {
    return 'Не вдалося відновити: $error';
  }

  @override
  String get desktopAuthBackupNotFound => 'Копії для цього Secretly ID на сервері немає.';

  @override
  String get desktopGeneralLaunchAtLogin => 'Запускати під час входу в систему';

  @override
  String get desktopGeneralLaunchAtLoginOn => 'Secretly запуститься сам і отримуватиме повідомлення';

  @override
  String get desktopGeneralLaunchAtLoginOff => 'Поки Secretly не запущено, повідомлення на цей комп’ютер не надходять';

  @override
  String get desktopGeneralLaunchNeedsApproval => 'Автозапуск вимкнено в системних налаштуваннях, у розділі «Об’єкти входу»';

  @override
  String get desktopA11yStatusSending => 'Надсилається';

  @override
  String get desktopA11yStatusScheduled => 'Заплановано';

  @override
  String get desktopA11yStatusSent => 'Надіслано';

  @override
  String get desktopA11yStatusDelivered => 'Доставлено';

  @override
  String get desktopA11yStatusRead => 'Прочитано';

  @override
  String get desktopA11yStatusFailed => 'Не надіслано';

  @override
  String get desktopA11yVoiceProgress => 'Відтворення голосового';

  @override
  String get desktopViewerPagePrev => 'Попередня сторінка';

  @override
  String get desktopViewerPageNext => 'Наступна сторінка';

  @override
  String get desktopReactionsMore => 'Більше емодзі';

  @override
  String get desktopReactionsCollapse => 'Згорнути';

  @override
  String get desktopThreadScrollToBottom => 'До останніх повідомлень';

  @override
  String get desktopViewerPrev => 'Попереднє';

  @override
  String get desktopViewerNext => 'Наступне';

  @override
  String get desktopA11yPlay => 'Відтворити';

  @override
  String get desktopA11yPause => 'Пауза';

  @override
  String get desktopA11yAudioProgress => 'Відтворення';

  @override
  String get desktopPlayerClose => 'Закрити плеєр';

  @override
  String get desktopPlayerOpenSource => 'Перейти до повідомлення';

  @override
  String desktopPlayerNowPlaying(String title) {
    return 'Зараз грає: $title';
  }

  @override
  String get desktopPlayerPrevious => 'Попередній';

  @override
  String get desktopPlayerNext => 'Наступний';

  @override
  String get desktopPlayerMore => 'Ще в цьому чаті';

  @override
  String get desktopPlayerSpeed => 'Швидкість відтворення';

  @override
  String get desktopPlayerSpeedNormal => 'Звичайна';

  @override
  String get desktopPlayerVolume => 'Гучність';

  @override
  String get desktopUpdateNow => 'Оновити';

  @override
  String desktopUpdateAvailable(String version) {
    return 'Доступна версія $version';
  }

  @override
  String get desktopCallExpand => 'Розгорнути дзвінок';

  @override
  String get desktopCallMinimiseHint => 'Згорнути в міні-вікно';

  @override
  String get desktopCallOpenChat => 'Згорнути дзвінок і відкрити чат';

  @override
  String get desktopCallScreenShareFailed => 'Не вдалося показати екран';

  @override
  String get desktopCallScreenShareFailedMac => 'Не вдалося показати екран. Дозвольте Secretly запис екрана: Системні параметри → Конфіденційність і безпека → Запис екрана';

  @override
  String get desktopCallMediaCameraUnavailable => 'Камера недоступна — її використовує інша програма або немає дозволу в налаштуваннях системи';

  @override
  String get desktopCallMediaMicUnavailable => 'Мікрофон недоступний — перевірте дозвіл у налаштуваннях системи';

  @override
  String get desktopCallMediaScreenStopped => 'Показ екрана зупинено';

  @override
  String desktopCallMediaProblem(String detail) {
    return 'Збій звуку або відео: $detail';
  }

  @override
  String desktopCallEndedAfter(String duration) {
    return 'Дзвінок завершено · $duration';
  }

  @override
  String desktopCallDirectWith(String name) {
    return 'Триває дзвінок · $name';
  }

  @override
  String get desktopCallLeaveFailed => 'Не вдалося вийти з дзвінка: сервер не відповів. Спробуйте ще раз.';

  @override
  String get desktopCallToggleFailed => 'Не вдалося перемкнути: сервер не відповів. Спробуйте ще раз.';

  @override
  String get desktopDiagTitle => 'Діагностика доставки';

  @override
  String get desktopDiagHint => 'На що дивитися, коли повідомлення не йдуть, і що надіслати нам';

  @override
  String get desktopDiagQueues => 'ЧЕРГИ';

  @override
  String get desktopDiagOutbox => 'Чекають на відправлення';

  @override
  String get desktopDiagStuck => 'Застрягли на вході';

  @override
  String get desktopDiagReceipts => 'Підтвердження в черзі';

  @override
  String get desktopDiagNothingStuck => 'Нічого не застрягло';

  @override
  String get desktopDiagConditions => 'УМОВИ ДОСТАВКИ';

  @override
  String get desktopDiagClockOk => 'Годинник комп’ютера збігається із сервером';

  @override
  String desktopDiagClockSkew(Object delta) {
    return 'Годинник комп’ютера збито на $delta — сервер може відмовляти';
  }

  @override
  String get desktopDiagCopy => 'Скопіювати для підтримки';

  @override
  String get desktopAppearanceTextSize => 'Розмір тексту';

  @override
  String get desktopAppearanceTextSizeHint => 'Діє на все вікно. Відступи та значки лишаються як намальовані';

  @override
  String get desktopThreadGoToDate => 'Перейти до дати';

  @override
  String get desktopHotkeyGlobalShow => 'Показувати Secretly звідусіль';

  @override
  String get desktopHotkeyGlobalHint => 'Типово вимкнено: сполучення загальносистемне і відібрало б його в іншої програми';

  @override
  String get desktopHotkeyGlobalTaken => 'Це сполучення вже зайняте іншою програмою';
}
