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
  String get startupRetry => 'Повторити';

  @override
  String get onboardingBackupLater => 'Резервну копію ще не ввімкнено — профіль ще створюється. Увімкніть її пізніше в Налаштуваннях.';

  @override
  String get keepMediaTitle => 'Зберігати медіа на пристрої';

  @override
  String get keepMediaForever => 'Завжди';

  @override
  String get keepMediaMonth => '1 місяць';

  @override
  String get keepMediaWeek => '1 тиждень';

  @override
  String get keepMediaHint => 'Завантажені фото, відео та файли, старші за строк, видаляються з телефона. Повідомлення лишаються; медіа, якого вже немає на сервері (старше 7 днів), і надіслані вами видаляться назавжди.';

  @override
  String get chatMediaTitle => 'Медіа за чатами';

  @override
  String get chatMediaShow => 'Порахувати за чатами';

  @override
  String chatMediaFilesCount(int count) {
    return '$count файлів';
  }

  @override
  String get chatMediaDeleteTitle => 'Видалити медіа чату?';

  @override
  String get chatMediaDeleteBody => 'Завантажені фото, відео та файли цього чату видаляться з телефона, повідомлення лишаться. Те, що ще є на сервері (до 7 днів), можна буде завантажити знову; решта — надіслане вами й старіше — видалиться назавжди.';

  @override
  String get chatMediaDeleteConfirm => 'Видалити';

  @override
  String get chatMediaEmpty => 'Завантажених медіа в чатах немає';

  @override
  String galleryShowMore(int count) {
    return 'Показати ще (залишилось $count)';
  }

  @override
  String get autoDownloadCellularTitle => 'Автозавантаження в мобільній мережі';

  @override
  String get autoDownloadEverything => 'Усе';

  @override
  String get autoDownloadUpTo15Mb => 'Фото, відео та файли до 15 МБ';

  @override
  String get autoDownloadPhotosOnly => 'Лише фото';

  @override
  String get autoDownloadNothing => 'Нічого, крім голосових';

  @override
  String get autoDownloadHint => 'Через Wi-Fi завантажується все. Відкладене завантажиться при підключенні до Wi-Fi або коли ви його відкриєте. Файли зберігаються на сервері 7 днів.';

  @override
  String get uploadNotSentTapToRetry => 'Не надіслано — торкніться, щоб повторити';

  @override
  String get uploadRetry => 'Повторити';

  @override
  String get attachmentExpiredOnServer => 'Файлу більше немає на сервері: він зберігається 7 днів.';

  @override
  String get attachmentServerRejectedSize => 'Файл завеликий для сервера. Надішліть менший файл або розділіть його.';

  @override
  String get attachmentServerStorageFull => 'На сервері зараз мало місця. Спробуйте пізніше.';

  @override
  String get attachmentUploadQuotaExceeded => 'Досягнуто межі обсягу файлів. Файли зберігаються 7 днів — спробуйте пізніше.';

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
  String get onboardingWelcomeSubtitle => 'Месенджер нового покоління.\nПриватність за замовчуванням.';

  @override
  String get onboardingCreateAccount => 'Створити новий акаунт';

  @override
  String get onboardingAlreadyHaveAccount => 'Уже є акаунт';

  @override
  String get onboardingFeatureE2eTitle => 'E2E-шифрування';

  @override
  String get onboardingFeatureE2eBody => 'Повідомлення шифруються на вашому пристрої. Ключі є лише у вас.';

  @override
  String get onboardingFeaturePrivacyTitle => 'Без особистих даних';

  @override
  String get onboardingFeaturePrivacyBody => 'Без номера телефону. Без прив’язки до особистих даних.';

  @override
  String get onboardingFeatureRelayTitle => 'Сервер не читає';

  @override
  String get onboardingFeatureRelayBody => 'Сервер лише передає зашифровані повідомлення й видаляє їх після доставки.';

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
  String get desktopRoomLimitTitle => 'Досягнуто межі кімнат';

  @override
  String desktopRoomLimitCreate(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Можна створити не більше $count кімнати.',
      many: 'Можна створити не більше $count кімнат.',
      few: 'Можна створити не більше $count кімнат.',
      one: 'Можна створити не більше $count кімнати.',
    );
    return '$_temp0';
  }

  @override
  String desktopRoomLimitJoin(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Можна бути не більше ніж у $count кімнатах. Щоб вступити в нову, вийдіть з однієї з попередніх.',
      many: 'Можна бути не більше ніж у $count кімнатах. Щоб вступити в нову, вийдіть з однієї з попередніх.',
      few: 'Можна бути не більше ніж у $count кімнатах. Щоб вступити в нову, вийдіть з однієї з попередніх.',
      one: 'Можна бути не більше ніж у $count кімнаті. Щоб вступити в нову, вийдіть з однієї з попередніх.',
    );
    return '$_temp0';
  }

  @override
  String get desktopRoomLimitPremium => 'У Premium ця межа вища — підписку оформлюють у застосунку на телефоні.';

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
  String get desktopViewerPageFailed => 'Не вдалося показати цю сторінку';

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
  String desktopPairingHowTo(String settings, String devices, String button) {
    return 'На телефоні відкрийте Secretly → $settings → $devices → «$button» і відскануйте цей QR-код.';
  }

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
  String get desktopGeneralDoubleClickReply => 'Відповідь подвійним клацанням';

  @override
  String get desktopGeneralDoubleClickReplyHint => 'Подвійне клацання по повідомленню — відповісти на нього. По тексту — виділити слово';

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
  String get desktopNotifInSystem => 'У сповіщеннях і віконцях';

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
  String get desktopNotifWhileFocused => 'Коли вікно відкрите';

  @override
  String get desktopNotifWhileFocusedHint => 'Повідомлення з інших чатів — теж сповіщенням. Про відкритий чат — ніколи';

  @override
  String get desktopNotifOwnWindows => 'Сповіщення як у Telegram';

  @override
  String get desktopNotifOwnWindowsHint => 'Власні віконця в куті екрана: не забирають фокус і чекають, поки над ними миша. Вимкнено — системні сповіщення Windows.';

  @override
  String get desktopNotifDnd => 'Не турбувати';

  @override
  String get desktopNotifDndHint => 'Вимкнути всі сповіщення';

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
  String get desktopWallpaperMidnight => 'Нічний';

  @override
  String get desktopAppearanceHint => 'Схема цього вікна. Телефон живе зі своєю — це налаштування нікуди не їде.';

  @override
  String get desktopAppearanceScheme => 'Схема';

  @override
  String get desktopAppearanceDark => 'Темна';

  @override
  String get desktopAppearanceLight => 'Світла';

  @override
  String get desktopAppearanceAccent => 'Акцент інтерфейсу';

  @override
  String get desktopAppearanceAccentHint => 'Кнопки, власні бульбашки та виділення в усьому застосунку.';

  @override
  String get desktopAppearanceWallpaper => 'Шпалери чату';

  @override
  String get desktopAppearanceWallPulse => 'Шпалери проводять повідомлення';

  @override
  String get desktopAppearanceWallPulseHint => 'Хвиля світла йде візерунком: вгору — коли надсилаєте, вниз — коли отримуєте.';

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
  String get desktopAppearanceTabTheme => 'Тема і текст';

  @override
  String get desktopAppearanceTabWallpaper => 'Фон чату';

  @override
  String get desktopAppearanceTabMessages => 'Повідомлення';

  @override
  String get desktopAppearanceReset => 'За замовчуванням';

  @override
  String get desktopAppearanceResetDone => 'Оформлення повернуто до початкового';

  @override
  String get desktopAppearanceResetUndo => 'Повернути';

  @override
  String get desktopAppearanceAutosave => 'Зберігається автоматично';

  @override
  String get desktopAppearancePremiumOnly => 'Це — у Premium; підписку оформлюють у застосунку на телефоні';

  @override
  String get desktopAppearancePresets => 'Готові набори';

  @override
  String get desktopAppearancePresetsHint => 'Акцент, шпалери, бульбашки й індикатори — одним натисканням';

  @override
  String get desktopAppearancePresetClassic => 'Класика';

  @override
  String get desktopAppearancePresetOcean => 'Океан';

  @override
  String get desktopAppearancePresetSunset => 'Захід сонця';

  @override
  String get desktopAppearancePresetForest => 'Ліс';

  @override
  String get desktopAppearancePresetNight => 'Ніч';

  @override
  String get desktopAppearanceSystem => 'Системна';

  @override
  String get desktopAppearanceDensity => 'Щільність повідомлень';

  @override
  String get desktopAppearanceDensityCozy => 'Затишна';

  @override
  String get desktopAppearanceDensityCompact => 'Компактна';

  @override
  String get desktopAppearanceWallpaperAllChats => 'Фон для всіх розмов. Живі — з м’яким переливом';

  @override
  String get desktopAppearanceStatic => 'Статичні';

  @override
  String get desktopAppearanceLive => 'Живі';

  @override
  String get desktopAppearanceLiveBadge => 'LIVE';

  @override
  String get desktopAppearanceDim => 'Затемнення';

  @override
  String get desktopAppearanceAnimPattern => 'Анімація візерунка';

  @override
  String get desktopAppearanceLiveOnlyBadge => 'лише для живих шпалер';

  @override
  String get desktopWallAnimShortContinuous => 'Постійно';

  @override
  String get desktopWallAnimShortOnEnter => 'При відкритті';

  @override
  String get desktopWallAnimShortTap => 'За кліком';

  @override
  String get desktopWallAnimShortOff => 'Вимк.';

  @override
  String desktopAppearanceGoLive(Object link) {
    return 'Оберіть $link, щоб налаштувати анімацію.';
  }

  @override
  String get desktopAppearanceGoLiveLink => 'живі шпалери';

  @override
  String get desktopAppearanceShape => 'Форма';

  @override
  String get desktopAppearanceShapeSharp => 'Гострі';

  @override
  String get desktopAppearanceShapeMedium => 'Середні';

  @override
  String get desktopAppearanceShapeRound => 'Круглі';

  @override
  String get desktopAppearanceNamesMulti => 'Різнокольорові';

  @override
  String get desktopAppearanceIndicatorHint => 'Позначки прочитання у списку чатів, посилання й виділення тексту';

  @override
  String get desktopAppearanceSummaryPrefix => 'Зараз:';

  @override
  String get desktopAppearanceSummaryDark => 'темна схема';

  @override
  String get desktopAppearanceSummaryLight => 'світла схема';

  @override
  String get desktopAppearanceSummarySystem => 'системна схема';

  @override
  String desktopAppearanceSummaryBubbles(Object name) {
    return 'бульбашки «$name»';
  }

  @override
  String desktopAppearanceSummaryText(Object size) {
    return 'текст $size';
  }

  @override
  String get desktopAppearancePreview => 'Попередній перегляд';

  @override
  String get desktopAppearancePreviewReplay => 'Перевідкрити';

  @override
  String get desktopAppearancePreviewReplayHint => 'Перевідкрити чат, щоб побачити анімацію';

  @override
  String get desktopAppearancePreviewIncoming => 'Вхідне';

  @override
  String get desktopAppearancePreviewIncomingHint => 'Отримати повідомлення';

  @override
  String get desktopAppearancePreviewChat => 'Дизайн-команда';

  @override
  String get desktopAppearancePreviewMembers => '5 учасників, 3 в мережі';

  @override
  String desktopAppearancePreviewTyping(Object name) {
    return '$name друкує…';
  }

  @override
  String get desktopAppearancePreviewAnna => 'Аня';

  @override
  String get desktopAppearancePreviewMax => 'Максим';

  @override
  String get desktopAppearancePreviewLiza => 'Ліза';

  @override
  String get desktopAppearancePreviewMsg1 => 'Оновила шпалери в нашому чаті — оцініть';

  @override
  String get desktopAppearancePreviewMsg2 => 'Живі просто вогонь. Особливо хвиля, коли пишеш';

  @override
  String get desktopAppearancePreviewMsg3 => 'Зараз спробую поставити такі самі';

  @override
  String get desktopAppearancePreviewMsg4 => 'А розмір тексту теж можна змінити?';

  @override
  String get desktopAppearancePreviewMsg5 => 'Так, у «Вигляді». Докладніше — на www.secretlyapp.com';

  @override
  String get desktopAppearancePreviewOwnDefault => 'Перевіряю, як виглядають нові налаштування';

  @override
  String get desktopAppearancePreviewReply1 => 'Виглядає чудово!';

  @override
  String get desktopAppearancePreviewReply2 => 'О, так значно краще';

  @override
  String get desktopAppearancePreviewReply3 => 'Скинь потім, які шпалери обрав';

  @override
  String get desktopAppearancePreviewReply4 => 'Цей колір бульбашок тобі пасує';

  @override
  String get desktopAppearancePreviewReply5 => 'Ставлю собі такі самі';

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
  String get desktopPrivacyEncryptionHint => 'Повідомлення, файли та дзвінки один на один захищено наскрізним шифруванням; ключі — лише на ваших пристроях. Наскрізне шифрування групових дзвінків вмикається поступово: замок у дзвінку показує, що воно працює, а без нього дзвінок шифрується лише під час передавання.';

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
  String get desktopSecurityE2eeHint => 'Повідомлення, файли та дзвінки один на один шифруються на вашому пристрої, ключі не залишають ваші пристрої. Сервер не читає вміст, але бачить службові дані — наприклад, хто кому пише і коли. Наскрізне шифрування групових дзвінків вмикається поступово: замок у дзвінку показує, що воно працює, а без нього дзвінок шифрується лише під час передавання.';

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
  String get desktopMuteMenu => 'Без звуку…';

  @override
  String get desktopMuteFor1h => 'На 1 годину';

  @override
  String get desktopMuteFor8h => 'На 8 годин';

  @override
  String get desktopMuteFor2d => 'На 2 дні';

  @override
  String get desktopMuteForever => 'Доки не ввімкну';

  @override
  String get desktopMuteMentionsOnly => 'Лише згадки';

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
  String get desktopRoomDeleteLeaveMenu => 'Видалити й вийти';

  @override
  String desktopRoomDeleteLeaveTitle(String title) {
    return 'Видалити й вийти з «$title»?';
  }

  @override
  String get desktopRoomDeleteLeaveBody => 'Ви вийдете з кімнати й перестанете отримувати її повідомлення, а листування видалиться з цього комп’ютера. Повернутися можна лише за новим запрошенням.';

  @override
  String get desktopRoomDeleteLeaveAction => 'Вийти й видалити';

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
  String get desktopFileRiskTitle => 'Відкрити цей файл?';

  @override
  String desktopFileRiskExtension(Object ext) {
    return 'Файл має розширення $ext: такий файл може запустити програму й зашкодити комп’ютеру. Відкривайте його, лише якщо довіряєте відправникові.';
  }

  @override
  String get desktopFileRiskNoExtension => 'Файл не має розширення: комп’ютер може запустити його як програму. Відкривайте його, лише якщо довіряєте відправникові.';

  @override
  String desktopFileRiskMismatch(Object ext) {
    return 'Відправник видав цей файл за знімок, звук, відео чи PDF, але насправді його розширення — $ext. Так маскують небезпечні файли — відкривайте його, лише якщо довіряєте відправникові.';
  }

  @override
  String get desktopFileRiskShowInFolder => 'Показати в теці';

  @override
  String get desktopFileRiskOpenAnyway => 'Усе одно відкрити';

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
  String get desktopRoomInviteCardTitle => 'Запрошення до кімнати';

  @override
  String get desktopRoomInviteCardHint => 'Відкрийте картку, щоб переглянути кімнату й приєднатися.';

  @override
  String get desktopRoomInviteAlreadyMember => 'Ви вже в кімнаті';

  @override
  String get desktopRoomInviteApprovalRequired => 'Потрібне схвалення';

  @override
  String get desktopRoomInviteDirectJoin => 'Прямий вхід';

  @override
  String get desktopRoomInviteWithHistory => 'з історією';

  @override
  String get desktopRoomInviteWithoutHistory => 'без історії';

  @override
  String desktopRoomInviteInvitedBy(String name) {
    return 'Запрошує: $name';
  }

  @override
  String get desktopRoomInviteHistoryOn => 'Історія для нових учасників увімкнена';

  @override
  String get desktopRoomInviteHistoryOff => 'Історія для нових учасників вимкнена';

  @override
  String get desktopRoomInviteJoin => 'Приєднатися';

  @override
  String get desktopRoomInviteRequestAccess => 'Запросити доступ';

  @override
  String get desktopRoomInviteOpenRequest => 'Відкрити заявку';

  @override
  String get desktopRoomInviteOpenRoom => 'Відкрити кімнату';

  @override
  String desktopRoomInviteReplyQuote(String title) {
    return 'Запрошення до «$title»';
  }

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
  String get desktopRoomShowAllMembers => 'Показати всіх';

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
  String get desktopProfileEmojiStatusPremiumOnly => 'Емодзі-статус — у Premium; підписка оформлюється в застосунку на телефоні';

  @override
  String get desktopProfileCosmeticPremiumOnly => 'Ця рамка чи обкладинка — у Premium; підписка оформлюється в застосунку на телефоні';

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
  String get desktopAvatarOpen => 'Відкрити фото';

  @override
  String get desktopAvatarCropTitle => 'Кадрувати фото';

  @override
  String get desktopAvatarCropHint => 'Перетягніть знімок; коліщатко миші — масштаб';

  @override
  String get desktopAvatarRemoveConfirmTitle => 'Видалити фото?';

  @override
  String get desktopAvatarRemoveConfirmBody => 'Замість фото будуть літери імені.';

  @override
  String get desktopAvatarRemoveOnPhone => 'Видалити можна на телефоні';

  @override
  String get desktopRoomPhotoUpdated => 'Фото групи оновлено';

  @override
  String get desktopRoomPhotoRemoved => 'Фото групи видалено';

  @override
  String desktopRoomPhotoFailed(String error) {
    return 'Не вдалося змінити фото групи: $error';
  }

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
  String get desktopGalleryLoadFailed => 'Не вдалося завантажити вкладення';

  @override
  String get desktopGalleryRetry => 'Повторити';

  @override
  String get desktopSendMediaDroppedOnSwitch => 'Файли не надіслано — вікно надсилання закрилося під час зміни чату.';

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
  String get desktopComposerVoiceUnsupported => 'Записувати голосові на цьому комп’ютері не вийде.';

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
  String get desktopShortcutsUnread => 'Попередній / наступний непрочитаний';

  @override
  String get desktopShortcutsFolders => 'Попередня / наступна папка';

  @override
  String get desktopShortcutsMute => 'Вимкнути / увімкнути звук чату';

  @override
  String get desktopShortcutsCloseChat => 'Закрити панель, потім чат';

  @override
  String get desktopChatMutedToast => 'Звук чату вимкнено';

  @override
  String get desktopChatUnmutedToast => 'Звук чату увімкнено';

  @override
  String get desktopChatsFolderReadAll => 'Прочитати все';

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
  String get desktopCallPinWindow => 'Поверх усіх вікон';

  @override
  String get desktopCallUnpinWindow => 'Не тримати поверх вікон';

  @override
  String get desktopCallsOwnWindow => 'Дзвінок в окремому вікні';

  @override
  String get desktopCallsOwnWindowHint => 'Дзвінок відкривається власним вікном: його можна перенести на інший екран або закріпити поверх інших програм.';

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
  String get desktopRoomClearForAll => 'І в усіх учасників кімнати';

  @override
  String get desktopRoomClearForAllHint => 'Повідомлення зникнуть і в інших. Скасувати не можна.';

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
  String get desktopStartupFailedTitle => 'Не вдалося запустити Secretly';

  @override
  String get desktopStartupFailedBody => 'Спробуйте ще раз. Якщо помилка повториться, причину підкаже журнал запуску.';

  @override
  String get desktopStartupSlowTitle => 'Запуск триває довше, ніж зазвичай';

  @override
  String get desktopStartupSlowBody => 'Можна зачекати ще або почати запуск заново.';

  @override
  String get desktopStartupRetry => 'Повторити';

  @override
  String get desktopStartupOpenLogs => 'Відкрити теку журналу';

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
  String desktopUpdateDownloading(int percent) {
    return 'Завантаження $percent%';
  }

  @override
  String get desktopUpdateVerifying => 'Перевірка…';

  @override
  String get desktopUpdateInstalling => 'Встановлення…';

  @override
  String get desktopUpdateManual => 'Завантажити з сайту';

  @override
  String get desktopUpdateFailedHint => 'Не вдалося оновитися автоматично. Інсталятор є на сайті.';

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
  String get desktopCallRemoveParticipant => 'Прибрати з дзвінка';

  @override
  String desktopCallRemoveParticipantTitle(String name) {
    return 'Прибрати $name з дзвінка?';
  }

  @override
  String get desktopCallRemoveParticipantBody => 'Людина вийде з дзвінка. Повернутися зможе, приєднавшись знову.';

  @override
  String get desktopCallRemoveFailed => 'Не вдалося прибрати з дзвінка';

  @override
  String get desktopCallLeaveTitle => 'Вийти з дзвінка?';

  @override
  String get desktopCallEndForAll => 'Завершити дзвінок для всіх';

  @override
  String get desktopCallEndForAllHint => 'Інші учасники теж вийдуть із дзвінка.';

  @override
  String get desktopCallEndForAllFailed => 'Не вдалося завершити дзвінок для всіх';

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
  String get desktopThreadGoToDate => 'Перейти до дати';

  @override
  String get desktopHotkeyGlobalShow => 'Показувати Secretly звідусіль';

  @override
  String get desktopHotkeyGlobalHint => 'Типово вимкнено: сполучення загальносистемне і відібрало б його в іншої програми';

  @override
  String get desktopHotkeyGlobalTaken => 'Це сполучення вже зайняте іншою програмою';

  @override
  String get desktopTrayOpen => 'Відкрити Secretly';

  @override
  String desktopTrayUnread(int count) {
    return 'Непрочитаних: $count';
  }

  @override
  String get desktopTrayMute => 'Без звуку';

  @override
  String get desktopTrayMuteHour => 'На 1 годину';

  @override
  String get desktopTrayMuteEightHours => 'На 8 годин';

  @override
  String get desktopTrayMuteForever => 'Поки не ввімкну';

  @override
  String get desktopTrayUnmute => 'Увімкнути сповіщення';

  @override
  String desktopTrayMutedUntil(String time) {
    return 'Без звуку до $time';
  }

  @override
  String get desktopTrayQuit => 'Вийти з Secretly';

  @override
  String get desktopTrayHintTitle => 'Secretly працює у фоні';

  @override
  String get desktopTrayHintBody => 'Повідомлення і дзвінки надходитимуть. Значок — біля годинника: закріпіть його, щоб він завжди був на виду.';

  @override
  String get desktopDevicesMicrophone => 'Мікрофон';

  @override
  String get desktopDevicesSpeakers => 'Динаміки й навушники';

  @override
  String get desktopDevicesNoSpeakers => 'Динаміки й навушники не знайдено';

  @override
  String get desktopDevicesCamera => 'Камера';

  @override
  String get desktopCallsSystemTitle => 'Система';

  @override
  String get desktopCallsSystemSound => 'Налаштування звуку системи';

  @override
  String get desktopCallsSystemSoundHint => 'Гучність, пристрій за замовчуванням і доступ до мікрофона';

  @override
  String get desktopCallsOpenSystem => 'Відкрити';

  @override
  String get desktopMicLevel => 'Рівень мікрофона';

  @override
  String get desktopMicLevelHint => 'Скажіть щось — смужка має рухатися. Мікрофон увімкнено, лише поки відкрито цей розділ, і звук нікуди не йде.';

  @override
  String get desktopMicNeedsAccess => 'Застосунку ще не дозволили користуватися мікрофоном.';

  @override
  String get desktopMicAllow => 'Дозволити';

  @override
  String get desktopMicNoAccess => 'Немає доступу до мікрофона. Дозвольте його в налаштуваннях системи.';

  @override
  String get desktopMicOpenFailed => 'Не вдалося відкрити мікрофон. Можливо, він зайнятий іншою програмою або доступ до нього закрито.';

  @override
  String get desktopMicSystemFallback => 'Вибраний мікрофон не вдалося відкрити для перевірки — показуємо мікрофон системи.';

  @override
  String get desktopMediaOpenPrivacy => 'Відкрити налаштування';

  @override
  String get desktopMicTest => 'Перевірити мікрофон';

  @override
  String get desktopMicTestHint => 'Запишемо 5 секунд і одразу програємо у вибраних динаміках.';

  @override
  String get desktopMediaCheck => 'Перевірити';

  @override
  String get desktopMediaCheckStop => 'Зупинити';

  @override
  String desktopMicTestRecording(int seconds) {
    return 'Триває запис — говоріть… $seconds с';
  }

  @override
  String get desktopMicTestPlaying => 'Програємо запис…';

  @override
  String get desktopMediaPlaybackFailed => 'Не вдалося програти звук.';

  @override
  String get desktopMediaPlaybackSystemOnly => 'Звук пролунав у пристрої системи за замовчуванням: вибраний не вдалося відкрити для перевірки.';

  @override
  String get desktopMediaBusyInCall => 'Триває дзвінок — перевірки вимкнено, щоб не заважати розмові.';

  @override
  String get desktopSpeakerTest => 'Перевірити динаміки';

  @override
  String get desktopSpeakerTestHint => 'Короткий сигнал у вибраному пристрої.';

  @override
  String get desktopSpeakerTestPlaying => 'Звучить…';

  @override
  String get desktopCameraPreview => 'Перевірити камеру';

  @override
  String get desktopCameraPreviewHint => 'Камера вмикається, лише поки відкрито попередній перегляд.';

  @override
  String get desktopCameraPreviewShow => 'Показати';

  @override
  String get desktopCameraPreviewHide => 'Сховати';

  @override
  String get desktopCameraPreviewFailed => 'Не вдалося увімкнути камеру. Можливо, вона зайнята іншою програмою або доступ до неї закрито.';

  @override
  String get desktopCameraMirror => 'Віддзеркалювати моє відео';

  @override
  String get desktopCameraMirrorHint => 'Лише на вашому екрані — як у дзеркалі. Співрозмовники бачать вас як зазвичай.';

  @override
  String get desktopRingtoneTitle => 'Мелодія дзвінка';

  @override
  String get desktopRingtoneVolume => 'Гучність';

  @override
  String get desktopRingtoneVolumeHint => 'Наскільки гучно звучить вхідний дзвінок на цьому комп’ютері.';

  @override
  String get desktopRingtoneListen => 'Послухати';

  @override
  String get desktopRingtoneSilent => 'Без звуку — про дзвінок повідомить лише вікно.';

  @override
  String get desktopRoomEditTitle => 'Змінити групу';

  @override
  String get desktopRoomEditName => 'Назва';

  @override
  String get desktopRoomEditNameHint => 'Назва групи';

  @override
  String get desktopRoomEditNameEmpty => 'Введіть назву';

  @override
  String get desktopRoomEditDescription => 'Опис';

  @override
  String get desktopRoomEditDescriptionHint => 'Про що ця група';

  @override
  String get desktopRoomEditPhotoChoose => 'Вибрати фото…';

  @override
  String get desktopRoomEditPhotoRemove => 'Видалити фото';

  @override
  String get desktopRoomEditSaved => 'Групу оновлено';

  @override
  String get desktopRoomPermissionsMenu => 'Дозволи';

  @override
  String get desktopRoomPermissionsTitle => 'Дозволи учасників';

  @override
  String get desktopRoomPermissionsSaved => 'Дозволи збережено';

  @override
  String get desktopRoomPermMembersSection => 'Що можуть учасники';

  @override
  String get desktopRoomPermSendText => 'Писати повідомлення';

  @override
  String get desktopRoomPermSendMedia => 'Надсилати фото, відео та файли';

  @override
  String get desktopRoomPermPin => 'Закріплювати повідомлення';

  @override
  String get desktopRoomPermAddMembers => 'Додавати учасників';

  @override
  String get desktopRoomAddMembers => 'Додати учасників';

  @override
  String get desktopRoomAddMembersSearch => 'Ім’я або Secretly ID';

  @override
  String get desktopRoomAddMembersAlready => 'Уже в кімнаті';

  @override
  String get desktopRoomAddMembersNone => 'Нікого не знайдено';

  @override
  String get desktopRoomAddMembersNoContacts => 'Контактів поки немає. Запросіть людей посиланням.';

  @override
  String desktopRoomAddMembersAction(int count) {
    return 'Додати: $count';
  }

  @override
  String desktopRoomMembersAdded(int count) {
    return 'Додано учасників: $count';
  }

  @override
  String get desktopRoomInviteLinksMenu => 'Посилання-запрошення';

  @override
  String get desktopRoomAuditLog => 'Нещодавні дії';

  @override
  String get desktopRoomAuditLogEmpty => 'Поки нічого не відбувалося';

  @override
  String get desktopRoomAuditLogHint => 'Вступи, виходи, ролі й налаштування — як їх бачив цей комп’ютер.';

  @override
  String get desktopRoomPermChangeInfo => 'Змінювати назву, фото й опис';

  @override
  String get desktopRoomPermChangeTag => 'Змінювати свою мітку';

  @override
  String get desktopRoomPermJoinSection => 'Вступ';

  @override
  String get desktopRoomPermApproval => 'Вступ лише після схвалення';

  @override
  String get desktopRoomPermHistory => 'Історія для нових учасників';

  @override
  String get desktopRoomPermHistoryHint => 'Нові учасники бачать повідомлення, надіслані до них';

  @override
  String get desktopRoomPermReactions => 'Реакції';

  @override
  String get desktopRoomReactionsAll => 'Усі';

  @override
  String get desktopRoomReactionsSome => 'Вибрані';

  @override
  String get desktopRoomReactionsNone => 'Жодних';

  @override
  String get desktopRoomPermSlowMode => 'Повільний режим';

  @override
  String get desktopRoomPermSlowModeHint => 'Як часто кожен учасник може надсилати повідомлення';

  @override
  String get desktopRoomSlowOff => 'Вимк.';

  @override
  String desktopRoomSlowSeconds(int count) {
    return '$count с';
  }

  @override
  String desktopRoomSlowMinutes(int count) {
    return '$count хв';
  }

  @override
  String desktopRoomSlowHours(int count) {
    return '$count год';
  }

  @override
  String get desktopRoomDelete => 'Видалити групу';

  @override
  String get desktopRoomDeleteTitle => 'Видалити групу для всіх?';

  @override
  String desktopRoomDeleteBody(String title) {
    return '«$title» зникне в усіх учасників разом із листуванням. Це не можна скасувати.';
  }

  @override
  String get desktopRoomDeleted => 'Групу видалено';

  @override
  String get desktopRoomOwnerLeaveTitle => 'Ви власник групи';

  @override
  String get desktopRoomOwnerLeaveBody => 'Перед виходом передайте групу іншому учасникові — або видаліть її для всіх.';

  @override
  String get desktopRoomOwnerLeaveNoMembers => 'У групі більше нікого немає — її можна лише видалити.';

  @override
  String get desktopRoomOwnerLeaveTransfer => 'Передати й вийти';

  @override
  String get desktopComposerSendHintShift => 'Надіслати · Shift+Enter\nПрава кнопка — надіслати пізніше';

  @override
  String get desktopWallpaperUseDefault => 'Як у налаштуваннях';

  @override
  String get desktopWallpaperClassic => 'Класика';

  @override
  String get desktopWallpaperStandard => 'Стандартні';

  @override
  String desktopWallpaperProfilePhoto(int n) {
    return 'Фото $n';
  }

  @override
  String get desktopChatWallpaperTitle => 'Шпалери чату';

  @override
  String get desktopChatWallpaperMenu => 'Шпалери чату…';

  @override
  String get desktopChatWallpaperSaved => 'Шпалери цього чату збережено';

  @override
  String get desktopWallpaperPremiumOnly => 'Ці шпалери — у Premium; підписку оформлюють у застосунку на телефоні';

  @override
  String get desktopGeneralStartMinimized => 'Запускати згорнутим';

  @override
  String get desktopGeneralStartMinimizedHint => 'Під час входу вікно не відкривається — Secretly чекає в треї';

  @override
  String get desktopGeneralCloseToTray => 'Закривати в трей';

  @override
  String get desktopGeneralCloseToTrayOn => 'Хрестик ховає вікно — повідомлення і дзвінки надходять далі';

  @override
  String get desktopGeneralCloseToTrayOff => 'Хрестик закриває Secretly — нічого не надійде, доки не відкриєте знову';

  @override
  String get desktopGeneralLaunchNeedsApprovalWindows => 'Автозапуск вимкнено в «Диспетчері завдань» → «Автозавантаження» — увімкніть Secretly там';

  @override
  String get desktopSupportAttachLog => 'Додати журнал';

  @override
  String get desktopSupportLogEmpty => 'Журнал поки порожній';

  @override
  String get desktopDevicesAddComputerTitle => 'Ще один комп’ютер';

  @override
  String get desktopDevicesAddComputerHint => 'Комп’ютер підключають із телефона. Установіть Secretly на інший комп’ютер і виберіть там «Увійти через телефон», потім на телефоні відкрийте Налаштування → Пристрої → «Підключити пристрій» і відскануйте QR-код з екрана того комп’ютера.';

  @override
  String get desktopSettingsSignOutBodyOnlyDevice => 'Цей комп’ютер — єдиний пристрій із цим обліковим записом. Після виходу обліковий запис можна повернути лише набором відновлення — без нього його не поверне ніхто, навіть ми. Спершу переконайтеся, що набір збережено.';

  @override
  String get desktopSettingsSignOutBodyUnknown => 'З цього комп’ютера буде видалено листування, ключі та кеш. Якщо обліковий запис є й на іншому пристрої, там він залишиться. Якщо цей комп’ютер — його єдиний пристрій, повернути обліковий запис можна буде лише набором відновлення.';

  @override
  String desktopPairingRetryIn(Object seconds) {
    return 'Наступна спроба через $seconds с';
  }

  @override
  String get desktopKitReadyTitle => 'Набір відновлення готовий';

  @override
  String get desktopKitReadyBody => 'Зберігайте його поза цим комп’ютером — на флешці, у менеджері паролів або на папері. Набір разом із паролем відкриває обліковий запис, тож тримайте їх окремо.';

  @override
  String get desktopKitSaveToFile => 'Зберегти у файл…';

  @override
  String get desktopKitSaveDialogTitle => 'Зберегти набір відновлення';

  @override
  String desktopKitSavedTo(Object path) {
    return 'Збережено у файл: $path';
  }

  @override
  String desktopKitSaveFailed(Object error) {
    return 'Не вдалося зберегти файл: $error';
  }

  @override
  String get desktopKitShowQr => 'Показати QR-код і текст';

  @override
  String get desktopKitSavedElsewhere => 'Збережено іншим способом';

  @override
  String get desktopKitConfirmTitle => 'Набір точно збережено?';

  @override
  String get desktopKitConfirmBody => 'Підтверджуйте, лише якщо ви скопіювали текст набору або сфотографували його QR-код і поклали в надійне місце поза цим комп’ютером. Без набору обліковий запис не відновити.';

  @override
  String get desktopKitConfirmYes => 'Так, збережено';

  @override
  String get desktopAuthKitConfirmed => 'Ви підтвердили, що набір зберігається в надійному місці. За ним обліковий запис можна повернути.';

  @override
  String get desktopAboutSourceCode => 'Вихідний код';

  @override
  String desktopAboutLicenseLine(Object url) {
    return 'Ліцензія: GNU AGPL-3.0. Вихідний код: $url';
  }

  @override
  String get desktopProfileLinkTitle => 'Відкрити цей чат?';

  @override
  String desktopProfileLinkBody(String name, String id) {
    return 'Посилання веде до листування. Співрозмовник: $name ($id).';
  }

  @override
  String desktopProfileLinkBodyUnknown(String id) {
    return 'Посилання веде до листування з профілем $id.';
  }

  @override
  String get desktopProfileLinkOpen => 'Відкрити чат';

  @override
  String desktopUpdateAttemptFailed(String reason) {
    return 'Оновлення не встановилося: $reason';
  }

  @override
  String get desktopUpdateFailureDownload => 'файл не завантажився';

  @override
  String get desktopUpdateFailureVerification => 'завантажений файл не пройшов перевірку й видалений без запуску';

  @override
  String get desktopUpdateFailureLaunch => 'інсталятор не запустився';

  @override
  String get desktopUpdateFailureNotInstalled => 'після інсталятора працює попередня версія';

  @override
  String get desktopUpdateRetry => 'Повторити';

  @override
  String get desktopRestoreTakeOverTitle => 'Комп\'ютер стане пристроєм, який зробив копію';

  @override
  String get desktopRestoreTakeOverBody => 'Копію зробив інший пристрій — наприклад, ваш телефон. Після відновлення комп\'ютер займе його місце. Якщо той пристрій ще працює, повідомлення надходитимуть лише на один із двох, а другий може перестати розшифровувати чати або втратити зв\'язок із сервером. Відновлюйте так, лише якщо того пристрою більше немає. Щоб користуватися комп\'ютером разом із телефоном, поверніться назад і прив\'яжіть комп\'ютер за QR-кодом.';

  @override
  String get desktopRestoreTakeOverConfirm => 'Все одно відновити';

  @override
  String get desktopServerBackupReplaceTitle => 'Замінити копію на сервері?';

  @override
  String get desktopServerBackupReplaceBody => 'На сервері зберігається одна копія на акаунт. Копія з цього комп\'ютера замінить ту, що зробив телефон або інший ваш пристрій, і попередню повернути буде неможливо. До неї ввійде лише історія, яка є на цьому комп\'ютері.';

  @override
  String get desktopServerBackupReplaceConfirm => 'Замінити';

  @override
  String get desktopBackupAutoPasswordMissing => 'не задано пароль копії';

  @override
  String get desktopBackupAutoPasswordWeak => 'пароль копії більше не відповідає вимогам';

  @override
  String get desktopBackupSetPassword => 'Задати пароль копії';

  @override
  String get desktopSupportLogConfirmTitle => 'Додати журнал?';

  @override
  String desktopSupportLogConfirmBody(String size) {
    return '$size службових записів програми за останній час. Перегляньте, що в них, перш ніж додавати: журнал піде до підтримки разом із листом.';
  }

  @override
  String get desktopSupportLogView => 'Переглянути';

  @override
  String get desktopSupportLogAttachConfirm => 'Додати';

  @override
  String get desktopSupportLogViewTitle => 'Що в журналі';

  @override
  String get desktopDevicesEndNotConfirmed => 'сервер цього не підтвердив. Спробуйте пізніше.';

  @override
  String get desktopPrivacyScreenCaptureTitle => 'Захист від знімків екрана';

  @override
  String get desktopPrivacyScreenCaptureSwitch => 'Приховувати вікна Secretly від знімків і запису екрана';

  @override
  String get desktopPrivacyScreenCaptureHint => 'Знімки, запис і демонстрація екрана — зокрема ваша власна демонстрація в дзвінку — не покажуть вміст вікон Secretly. Сфотографувати екран це не заважає, а деякі програми захоплення й версії системи можуть цього не дотримуватися.';

  @override
  String get desktopPrivacyScreenCaptureFailed => 'Система не прийняла захист від знімків екрана.';

  @override
  String get desktopSoundMessagesTitle => 'Звук повідомлень';

  @override
  String get desktopSoundMessagesHint => 'Звучить разом зі сповіщенням про повідомлення на цьому комп’ютері.';

  @override
  String get desktopSoundMutedNote => 'Звук сповіщень вимкнено вище — вибраний звук не пролунає.';

  @override
  String get desktopSoundInChatTitle => 'Звук у відкритому чаті';

  @override
  String get desktopSoundInChatSwitch => 'Нові повідомлення у відкритому чаті';

  @override
  String get desktopSoundInChatHint => 'Тихий звук замість сповіщення, поки чат відкрито в активному вікні.';

  @override
  String get desktopSoundNameBubble => 'Бульбашка';

  @override
  String get desktopSoundNameBubbles => 'Бульбашки';

  @override
  String get desktopSoundNameDrip => 'Капання';

  @override
  String get desktopSoundNamePing => 'Пінг';

  @override
  String get desktopSoundNameSplash => 'Сплеск';

  @override
  String get desktopSoundNameDrop => 'Крапля';

  @override
  String get desktopSoundNameTone => 'Тон';

  @override
  String get desktopSoundNameKey => 'Клавіша';

  @override
  String get desktopSoundNameClick => 'Клацання';

  @override
  String get desktopSoundNameSwitch => 'Перемикач';

  @override
  String get desktopSoundNameMelody => 'Мелодія';

  @override
  String get desktopSoundNamePulse => 'Пульс';

  @override
  String get desktopSoundNameDefault => 'За замовчуванням';

  @override
  String get roomCallE2eeOn => 'Наскрізне шифрування';

  @override
  String get roomCallE2eeOnHint => 'Звук, відео та екран бачать лише учасники — наш сервер не бачить.';

  @override
  String get roomCallE2eeConnecting => 'Вмикаємо шифрування…';

  @override
  String get roomCallE2eeFailed => 'Не вдалося ввімкнути шифрування. З цього пристрою увійти не можна.';

  @override
  String get roomCallE2eeUnsupported => 'Захищені групові дзвінки поки недоступні на цьому пристрої.';

  @override
  String get roomCallE2eeWaitingKey => 'Чекаємо ключ';

  @override
  String get roomCallE2eeFailing => 'Не вдається розшифрувати — можливо, стара версія';

  @override
  String roomCallE2eeUnknownParticipants(int count) {
    return 'Невідомих учасників не чути: $count';
  }

  @override
  String get roomCallOpenBanner => 'Без наскрізного шифрування — сервер може бачити й чути дзвінок';

  @override
  String get roomCallJoinOpenTitle => 'Увійти в дзвінок без шифрування?';

  @override
  String get roomCallJoinOpenBody => 'Цей дзвінок без наскрізного шифрування: його почали в старій версії Secretly. Сервер може бачити й чути його.';

  @override
  String get roomCallJoinOpenAction => 'Все одно увійти';

  @override
  String get roomCallStartChoiceTitle => 'Почати захищений дзвінок?';

  @override
  String roomCallStartChoiceBody(String names) {
    return 'Стара версія Secretly — не зможуть увійти: $names.';
  }

  @override
  String get roomCallStartChoiceNotify => 'Написати в чат, що треба оновитися';

  @override
  String get roomCallStartEncrypted => 'Почати захищений';

  @override
  String get roomCallStartOpen => 'Почати без шифрування';

  @override
  String get roomCallUpdateNotice => 'Триває захищений дзвінок. Щоб увійти, оновіть Secretly.';

  @override
  String get roomCallE2eeScreenShareIos => 'Показ екрана з iPhone у захищеному дзвінку поки недоступний';

  @override
  String get roomCallFull => 'У захищеному дзвінку немає місць';

  @override
  String get roomPrivateTopicNew => 'Нова тема';

  @override
  String get roomPrivateTopicOpen => 'Відкрита';

  @override
  String get roomPrivateTopicOpenHint => 'Бачать усі учасники кімнати';

  @override
  String get roomPrivateTopicClosed => 'Закрита';

  @override
  String get roomPrivateTopicClosedHint => 'Лише запрошені. Інші не дізнаються про неї';

  @override
  String get roomPrivateTopicTitleHint => 'Назва теми';

  @override
  String get roomPrivateTopicMembers => 'Кого запросити';

  @override
  String get roomPrivateTopicOnlyYou => 'Поки лише ви — людей можна додати потім';

  @override
  String get roomPrivateTopicCreate => 'Створити';

  @override
  String get roomPrivateTopicFailed => 'Не вдалося створити закриту тему';

  @override
  String roomPrivateTopicLimit(int count) {
    return 'Досягнуто межі закритих тем: $count';
  }

  @override
  String get roomPrivateTopicLabel => 'Закрита тема';

  @override
  String roomPrivateTopicInRoom(String room) {
    return 'Закрита тема · $room';
  }

  @override
  String get roomPrivateTopicAllowMembers => 'Створювати закриті теми';

  @override
  String get spaceGateEnterCode => 'Введіть код';

  @override
  String get spaceGateWrongCode => 'Код не підходить. Спробуйте ще раз.';

  @override
  String spaceGateWaitSeconds(int seconds) {
    return 'Почекайте $seconds с';
  }

  @override
  String get spaceGateUnlock => 'Відкрити';

  @override
  String get spaceGateUseBiometrics => 'Біометрія';

  @override
  String get spaceGateBiometricReason => 'Розблокуйте Secretly';

  @override
  String get duressSetupTitle => 'Код примусу';

  @override
  String get duressSetupDescription => 'Цей код відкриває окремий порожній профіль замість вашого. Він має відрізнятися від справжнього коду. Хто побачить, як ви його вводите, побачить щойно встановлений месенджер.';

  @override
  String get duressSectionTitle => 'Код примусу';

  @override
  String get duressSectionSubtitleSet => 'Налаштовано. Другий код відкриває окремий порожній профіль.';

  @override
  String get duressSectionSubtitleUnset => 'Другий код, який відкриває окремий порожній профіль замість вашого.';

  @override
  String get duressSectionChange => 'Змінити';

  @override
  String get duressSectionSetUp => 'Задати';

  @override
  String get duressWipeMainTitle => 'Стирати основний профіль під час введення коду';

  @override
  String get duressWipeMainSubtitle => 'Необоротно. Відновлення — лише з Recovery Kit або резервної копії.';

  @override
  String get duressRemoveCode => 'Вилучити код примусу';

  @override
  String duressWipeAfterAttemptsTitle(int attempts) {
    return 'Стирати все після $attempts невірних спроб';
  }

  @override
  String get duressWipeAfterAttemptsSubtitle => 'Обидва профілі й сам замок. Після 3 невірних спроб уже діє затримка.';

  @override
  String get duressSectionFootnote => 'Захищає під час огляду «покажи телефон», але не під час експертизи пристрою. Біометрія завжди відкриває основний профіль. Щоб повернутися до нього з приманки, закрийте застосунок і введіть справжній код.';

  @override
  String get duressSaveFailed => 'Не вдалося зберегти налаштування.';

  @override
  String get netSettingsImportNoNewMessages => 'Нових повідомлень для цього пристрою немає.';

  @override
  String netSettingsImportReceived(int count) {
    return 'Отримано повідомлень: $count';
  }

  @override
  String get netSettingsImportNotEnvelopeFile => 'Це не файл повідомлень Secretly або він змінений.';

  @override
  String get netSettingsImportCouldNotOpen => 'Не вдалося відкрити файл.';

  @override
  String get netSettingsImportCouldNotRead => 'Не вдалося прочитати файл. Відкрийте його в Secretly: Налаштування → Без інтернету → «Відкрити файл повідомлень».';

  @override
  String get netSettingsPathDirect => 'Напряму';

  @override
  String get netSettingsPathFallback => 'За резервною адресою';

  @override
  String get netSettingsPathMirror => 'Через дзеркало';

  @override
  String get netSettingsPathCdn => 'Через CDN';

  @override
  String get netSettingsPathProxy => 'Через проксі';

  @override
  String get netSettingsPathSocks => 'Через SOCKS';

  @override
  String get netSettingsPathTor => 'Через Tor';

  @override
  String get netSettingsProxyHostError => 'Потрібне ім’я сервера, наприклад proxy.example.org';

  @override
  String get netSettingsSocksAddressError => 'Потрібна адреса вигляду 127.0.0.1:9050';

  @override
  String get netSettingsNoContactsYet => 'Контактів поки немає.';

  @override
  String get netSettingsPickRecipientTitle => 'Кому файл';

  @override
  String get netSettingsNothingToCarry => 'За тиждень цьому співрозмовнику нічого переносити.';

  @override
  String get netSettingsCouldNotCreateFile => 'Не вдалося створити файл.';

  @override
  String get netSettingsTitle => 'Мережа';

  @override
  String get netSettingsPathToServersTitle => 'Шлях до серверів';

  @override
  String get netSettingsPathDirectOff => 'Напряму. Обхідні шляхи вимкнені або недоступні.';

  @override
  String get netSettingsTryAlternativeTitle => 'Шукати обхідні шляхи';

  @override
  String get netSettingsTryAlternativeSubtitle => 'Коли прямий шлях закритий, застосунок сам пробує резервні адреси, дзеркала та проксі. Вміст і далі шифрується наскрізно.';

  @override
  String get netSettingsVolunteerProxyTitle => 'Проксі волонтера';

  @override
  String get netSettingsVolunteerProxyDescription => 'Посилання вигляду secretly://proxy#host. Власник проксі не бачить вмісту, але бачить, що ви користуєтеся Secretly.';

  @override
  String get netSettingsSocksTitle => 'SOCKS5 (наприклад, Tor через Orbot)';

  @override
  String get netSettingsSendWithoutNetworkTitle => 'Надіслати без мережі';

  @override
  String get netSettingsSendWithoutNetworkSubtitle => 'Файл з вашими зашифрованими повідомленнями співрозмовнику за тиждень. Передайте його будь-як — флешкою, Bluetooth, іншим месенджером.';

  @override
  String get netSettingsOpenMessageFileTitle => 'Відкрити файл повідомлень';

  @override
  String get netSettingsOpenMessageFileSubtitle => 'Файл .secretly від співрозмовника. Чужі та вже отримані повідомлення пропускаються.';

  @override
  String get netSettingsDeliveryReportsTitle => 'Знеособлені звіти про доставку';

  @override
  String get netSettingsDeliveryReportsSubtitle => 'Раз на добу: платформа, тип мережі, яким шляхом дійшло і які шляхи не працювали, країна за мовою системи. Без ідентифікаторів і адрес.';

  @override
  String get netSettingsOrbotTitle => 'Через Orbot (Tor)';

  @override
  String get netSettingsOrbotSubtitle => 'Підставить адресу SOCKS для Orbot — 127.0.0.1:9050. Установіть Orbot і запустіть його; перевірити, чи він працює, Secretly не може.';

  @override
  String get netSettingsOrbotDone => 'Адресу SOCKS виставлено на Orbot. Запустіть Orbot і повернїться.';

  @override
  String get netSettingsTorTitle => 'Tor як останній шлях';

  @override
  String get netSettingsTorSubtitle => 'Повільніше й витрачає батарею; увімкнеться лише тоді, коли все інше закрито.';

  @override
  String get socialRecoveryGuardiansTitle => 'Хранителі';

  @override
  String get socialRecoveryEntryGuardiansSubtitle => 'Друзі, які разом допоможуть повернути ваш профіль, якщо телефон втрачено. Поодинці вони не можуть нічого.';

  @override
  String get socialRecoveryHelpSomeoneTitle => 'Допомогти відновити';

  @override
  String get socialRecoveryHelpSomeoneSubtitle => 'Якщо ви чийсь хранитель.';

  @override
  String get socialRecoveryRecoverMineTitle => 'Відновити свій профіль';

  @override
  String get socialRecoveryRecoverMineSubtitle => 'На новому телефоні — за допомогою ваших хранителів.';

  @override
  String get socialRecoveryNeedTwoGuardians => 'Потрібно щонайменше двох хранителів.';

  @override
  String get socialRecoverySendSharesFailed => 'Не вдалося розіслати частки. Перевірте зв’язок.';

  @override
  String get socialRecoveryOwnerIntro => 'Ваш профіль ділиться на частини між хранителями. Щоб повернути його, потрібно стільки з них, скільки ви виберете. Вибирайте людей, яких ви впізнаєте за голосом і з якими ви звірили код безпеки.';

  @override
  String get socialRecoveryIsSetUp => 'Відновлення налаштовано';

  @override
  String get socialRecoveryWaitingConfirmations => 'Чекаємо підтверджень';

  @override
  String socialRecoveryConfirmedProgress(int accepted, int total, int threshold) {
    return 'Підтвердили $accepted з $total. Потрібно $threshold для відновлення.';
  }

  @override
  String get socialRecoveryGuardianHoldsPart => 'Зберігає частину';

  @override
  String get socialRecoveryGuardianNotSent => 'Не надіслано';

  @override
  String get socialRecoveryGuardianSentWaiting => 'Надіслано, чекаємо';

  @override
  String socialRecoveryPickContacts(int max) {
    return 'Виберіть від 2 до $max контактів';
  }

  @override
  String get socialRecoveryNoContactsYet => 'Контактів поки немає.';

  @override
  String socialRecoveryThresholdLabel(int threshold, int total) {
    return 'Скільки хранителів потрібно для відновлення: $threshold з $total';
  }

  @override
  String get socialRecoveryThresholdWarning => 'Стільки хранителів, змовившись, можуть відновити ваш профіль і без вас. Не вибирайте людей, які знають одне одного занадто добре.';

  @override
  String get socialRecoverySendParts => 'Розіслати частини';

  @override
  String get socialRecoveryUpdateGuardians => 'Оновити хранителів';

  @override
  String get socialRecoveryTurnOff => 'Вимкнути відновлення';

  @override
  String get socialRecoveryCodeScanTitle => 'Код відновлення';

  @override
  String get socialRecoveryNotRecoveryCode => 'Це не код відновлення.';

  @override
  String get socialRecoveryNoCodeInClipboard => 'У буфері немає коду відновлення.';

  @override
  String get socialRecoverySendFailed => 'Не вдалося надіслати. Перевірте зв’язок.';

  @override
  String get socialRecoveryHelpRecoverTitle => 'Допомогти відновити';

  @override
  String get socialRecoveryNotGuardianYet => 'Ви поки що нічий хранитель. Коли хтось вибере вас, тут з’явиться його ім’я.';

  @override
  String get socialRecoveryWhoAreYouHelping => 'Кому допомагаєте';

  @override
  String socialRecoveryThresholdOfGuardians(int threshold, int guardians) {
    return 'Потрібно $threshold з $guardians хранителів';
  }

  @override
  String get socialRecoveryScanCode => 'Сканувати код';

  @override
  String get socialRecoveryPasteCode => 'Вставити код';

  @override
  String get socialRecoveryCheckWordsByVoice => 'Звірте слова голосом';

  @override
  String get socialRecoveryCheckWordsExplanation => 'Зателефонуйте людині або зустріньтеся особисто. Попросіть прочитати слова з її екрана. Якщо хоч одне не збігається або ви не впевнені, що це вона, — не надсилайте. Саме так зловмисник може отримати чужий профіль.';

  @override
  String get socialRecoveryHeardWordsConfirm => 'Я почув ці слова від цієї людини';

  @override
  String get socialRecoverySent => 'Надіслано';

  @override
  String get socialRecoverySendMyPart => 'Надіслати свою частину';

  @override
  String get socialRecoveryRecoverProfileTitle => 'Відновити профіль';

  @override
  String get socialRecoveryRecoverIntro => 'Цей телефон замінить профіль, який зараз на ньому відкритий, вашим попереднім профілем. Хранителі надішлють свої частини, і щойно їх буде достатньо, застосунок перезапуститься вже з вашим профілем.';

  @override
  String get socialRecoveryShowCodeToGuardians => 'Показати код хранителям';

  @override
  String get socialRecoveryShowCodeHint => 'Покажіть код хранителю або надішліть текстом, а потім прочитайте йому ці слова голосом.';

  @override
  String get socialRecoveryCopyCode => 'Скопіювати код';

  @override
  String get socialRecoveryWaitingGuardians => 'Чекаємо хранителів';

  @override
  String socialRecoveryReceivedProgress(int received, int threshold) {
    return 'Отримано $received з $threshold';
  }

  @override
  String get socialRecoveryPartDidNotFit => 'Одна з частин не підійшла. Попросіть іншого хранителя.';

  @override
  String socialRecoveryAssembleFailed(String error) {
    return 'Не вдалося зібрати профіль ($error).';
  }

  @override
  String get socialRecoveryCancel => 'Скасувати';

  @override
  String get disappearingTitle => 'Зникаючі повідомлення';

  @override
  String disappearingSubtitleOn(Object duration) {
    return '$duration · у всіх учасників';
  }

  @override
  String get disappearingDialogHint => 'Повідомлення видаляються з пристроїв усіх учасників, коли спливає строк. Це не захищає від знімків екрана та від пристроїв зі старою версією застосунку.';

  @override
  String get disappearingCustom => 'Свій строк…';

  @override
  String get disappearingCustomTitle => 'Свій строк';

  @override
  String disappearingCustomHint(Object min, Object max) {
    return 'Від $min до $max';
  }

  @override
  String get disappearingUnitSeconds => 'секунд';

  @override
  String get disappearingUnitMinutes => 'хвилин';

  @override
  String get disappearingUnitHours => 'годин';

  @override
  String get disappearingUnitDays => 'днів';

  @override
  String get disappearingCustomInvalid => 'Введіть число в допустимих межах';

  @override
  String disappearingBannerOn(Object duration) {
    return 'Зникаючі повідомлення: $duration';
  }

  @override
  String get disappearingPeerOutdated => 'У співрозмовника стара версія застосунку — у нього повідомлення не зникнуть.';

  @override
  String get disappearingOwnOutdated => 'На одному з ваших пристроїв стара версія застосунку — там повідомлення не зникнуть.';

  @override
  String get disappearingSupportUnknown => 'Не вдалося перевірити версію застосунку співрозмовника.';

  @override
  String get disappearingChipTooltip => 'Зникаючі повідомлення — у всіх учасників';

  @override
  String get disappearingUpdated => 'Таймер зникаючих повідомлень змінено';

  @override
  String get disappearingSetFailed => 'Не вдалося змінити таймер';

  @override
  String get disappearingAdminOnly => 'Змінювати таймер можуть власник і адміністратори';

  @override
  String get disappearingRoomOutdated => 'У частини учасників стара версія застосунку — у них повідомлення не зникнуть.';

  @override
  String get disappearingQuoteGone => 'Повідомлення зникло';

  @override
  String get serverAuthAlertTitle => 'Відповідь сервера не пройшла перевірку';

  @override
  String get serverAuthAlertBody => 'Схоже, хтось між вами та сервером Secretly підміняє дані. Відкриті чати захищені й продовжують працювати. Нові контакти й пристрої не приймаються, доки це не мине. Спробуйте іншу мережу або проксі.';

  @override
  String get serverAuthAlertDismiss => 'Зрозуміло';

  @override
  String get stickerPackAccessTitle => 'Хто може додати набір';

  @override
  String get stickerPackAccessOpen => 'Відкритий';

  @override
  String get stickerPackAccessOpenHint => 'Той, кому ви надішлете стікер, зможе додати собі весь набір. На сервер набір не потрапляє.';

  @override
  String get stickerPackAccessClosed => 'Закритий';

  @override
  String get stickerPackAccessClosedHint => 'Набір буде лише у вас. Співрозмовники побачать надіслані стікери, але не зможуть додати набір. Надіслані стікери все одно залишаються на їхньому пристрої — знімку екрана це не завадить.';

  @override
  String get stickerPackClosedExistingNote => 'У тих, хто вже додав набір, він залишиться.';

  @override
  String get stickerPackClosedLabel => 'Закритий набір';

  @override
  String get stickerPackClosedNote => 'Автор не дозволив додавати цей набір';

  @override
  String get stickerCreateFromPhoto => 'З фото';

  @override
  String get stickerCreateTextOnly => 'Текстовий стікер';

  @override
  String stickerCreateFailed(String error) {
    return 'Не вдалося створити стікер: $error';
  }

  @override
  String stickerPackMissingNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ще $count стікера не передалося — можливо, в автора стара версія застосунку',
      many: 'Ще $count стікерів не передалося — можливо, в автора стара версія застосунку',
      few: 'Ще $count стікери не передалися — можливо, в автора стара версія застосунку',
      one: 'Ще $count стікер не передався — можливо, в автора стара версія застосунку',
    );
    return '$_temp0';
  }

  @override
  String get stickerAddedToPack => 'Стікер додано до набору';

  @override
  String stickerSaveFailed(String error) {
    return 'Не вдалося зберегти: $error';
  }

  @override
  String get stickerFavoritesPackTitle => 'Обране';

  @override
  String get stickerAddedToFavorites => 'Стікер додано в обране';

  @override
  String get stickerAnimationUnavailable => 'Анімація недоступна на цьому пристрої';

  @override
  String get stickerMotionPickTitle => 'Оберіть ефект руху';

  @override
  String get stickerMotionSlow => 'Повільно';

  @override
  String get stickerMotionNormal => 'Звичайно';

  @override
  String get stickerMotionFast => 'Швидко';

  @override
  String get stickerMotionPulse => 'Пульс';

  @override
  String get stickerMotionBounce => 'Стрибок';

  @override
  String get stickerMotionWobble => 'Хитання';

  @override
  String get stickerMotionTada => 'Та-да';

  @override
  String get stickerReadyTitle => 'Готовий стікер';

  @override
  String get stickerPickEmojiHint => 'Оберіть емодзі, що відповідають стікеру';

  @override
  String get stickerSend => 'Надіслати стікер';

  @override
  String get stickerAnimating => 'Оживляємо…';

  @override
  String get stickerChangeMotion => 'Змінити рух';

  @override
  String get stickerAnimatePremium => 'Оживити · Premium';

  @override
  String get stickerMakeFavorite => 'Додати в обране';

  @override
  String get stickerAddToPack => 'Додати до набору';

  @override
  String get stickerBack => 'Назад';

  @override
  String get stickerNewPack => 'Новий набір';

  @override
  String get stickerNewPackHint => 'Придумайте назву для набору.';

  @override
  String get stickerCreate => 'Створити';

  @override
  String get stickerEditorObjectNotFound => 'Об\'єкт не розпізнано';

  @override
  String get stickerEditorPickObject => 'Оберіть об\'єкт';

  @override
  String get stickerEditorText => 'Текст';

  @override
  String get stickerEditorSelectObject => 'Виділіть об\'єкт';

  @override
  String get stickerWord => 'Стікер';

  @override
  String get stickerEditorUndo => 'Скасувати';

  @override
  String get stickerEditorRedo => 'Повернути';

  @override
  String get stickerEditorDelete => 'Видалити';

  @override
  String get stickerEditorDone => 'Готово';

  @override
  String get stickerEditorBgNone => 'Без фону';

  @override
  String get stickerEditorBgSolid => 'Заливка';

  @override
  String get stickerEditorBgPill => 'Плашка';

  @override
  String get stickerEditorOutline => 'Контур';

  @override
  String get stickerEditorBackground => 'Фон';

  @override
  String get stickerEditorRecut => 'Вирізати знову';

  @override
  String get stickerEditorCut => 'Вирізати об\'єкт';

  @override
  String get stickerEditorDraw => 'Малюнок';

  @override
  String get stickerEditorAdjust => 'Корекція';

  @override
  String get stickerEditorEmoji => 'Емодзі';

  @override
  String get stickerEditorExposure => 'Експозиція';

  @override
  String get stickerEditorContrast => 'Контраст';

  @override
  String get stickerEditorSaturation => 'Насиченість';

  @override
  String get stickerEditorTapObjects => 'Натисніть на об\'єкти, які залишити';

  @override
  String get stickerEditorObjectSelected => 'Об\'єкт виділено';

  @override
  String stickerPackInstallFailed(String error) {
    return 'Не вдалося встановити стікерпак: $error';
  }

  @override
  String stickerPackRemoveFailed(String error) {
    return 'Не вдалося видалити стікерпак: $error';
  }

  @override
  String get stickerPackRemoveTitle => 'Видалити стікерпак?';

  @override
  String stickerPackRemoveBody(String title) {
    return 'Пак \"$title\" залишиться в каталозі, але локальні файли буде видалено.';
  }

  @override
  String get stickerPackRemoveAction => 'Видалити';

  @override
  String stickerPackRemovedSnack(String title) {
    return 'Стікерпак \"$title\" видалено з пристрою.';
  }

  @override
  String get stickerPackEdit => 'змінити';

  @override
  String get stickerPackCoverUpdated => 'Обкладинку набору оновлено';

  @override
  String stickerPackFull(int max) {
    return 'У наборі вже $max стікерів — створіть новий';
  }

  @override
  String get settingsGroupProfile => 'Профіль';

  @override
  String get settingsGroupRecovery => 'Відновлення';

  @override
  String get settingsCaptionAccountRestore => 'ID і резервна копія потрібні, щоб повернути акаунт на новому телефоні. Запишіть ID і зберігайте його окремо від телефона.';

  @override
  String get settingsGroupLeave => 'Вихід і видалення';

  @override
  String get settingsCaptionLeave => 'Вихід стирає дані лише на цьому пристрої. Видалення стирає профіль і на сервері — повернути його буде неможливо.';

  @override
  String get settingsGroupGeneral => 'Головне';

  @override
  String get settingsGroupMessages => 'Повідомлення';

  @override
  String get settingsCaptionMessages => 'Текст та ім’я в сповіщенні може побачити будь-хто, у кого в руках ваш телефон.';

  @override
  String get settingsGroupCalls => 'Дзвінки';

  @override
  String get settingsGroupInApp => 'Усередині застосунку';

  @override
  String get settingsCaptionInApp => 'Звуки й вібрація, поки Secretly відкритий.';

  @override
  String get settingsGroupNotificationLook => 'Який вигляд має сповіщення';

  @override
  String get settingsGroupBackground => 'Робота у фоні';

  @override
  String get settingsGroupQr => 'QR-код';

  @override
  String get settingsGroupPersonal => 'Особисте';

  @override
  String get settingsGroupWhoCan => 'Хто бачить і хто може писати';

  @override
  String get settingsGroupNewChats => 'Нові чати';

  @override
  String get settingsGroupSearchBlocking => 'Пошук і блокування';

  @override
  String get settingsGroupPhoneContacts => 'Контакти телефона';

  @override
  String get settingsGroupInactive => 'Якщо мене довго немає';

  @override
  String get settingsCaptionInactive => 'Якщо ви стільки часу не заходите в Secretly, акаунт видалиться сам.';

  @override
  String get settingsGroupAppLanguage => 'Мова застосунку';

  @override
  String get settingsGroupTranslation => 'Переклад';

  @override
  String get settingsGroupStatus => 'Стан';

  @override
  String get settingsGroupBlocked => 'Якщо Secretly заблоковано';

  @override
  String get settingsCaptionBlocked => 'Зазвичай нічого налаштовувати не треба. Проксі та Orbot — на випадок, якщо обхідні шляхи не допомогли.';

  @override
  String get settingsGroupOwnProxy => 'Власний проксі';

  @override
  String get settingsGroupOffline => 'Без інтернету';

  @override
  String get settingsCaptionOffline => 'Це файл, а не живий зв’язок: співрозмовник прочитає повідомлення, коли відкриє файл.';

  @override
  String get settingsGroupHelpDelivery => 'Допомогти покращити доставку';

  @override
  String get netHowItWorksTitle => 'Як це працює';

  @override
  String get netHowItWorksSubtitle => 'Простими словами: обхід блокувань і зв’язок без інтернету';

  @override
  String get netHowStep1Title => 'Як повідомлення доходить';

  @override
  String get netHowStep1Body => 'Телефон шифрує повідомлення до надсилання. Сервер зберігає його зашифрованим, поки співрозмовник не в мережі, і віддає, коли той з’явиться. Прочитати повідомлення сервер не може.';

  @override
  String get netHowStep2Title => 'Якщо Secretly заблоковано';

  @override
  String get netHowStep2Body => '«Шукати обхідні шляхи» увімкнено від початку. Застосунок сам пробує запасну адресу, копію сервера («дзеркало») і великі мережі доставки («CDN»), які важко заблокувати повністю. Перше підключення може тривати довше.';

  @override
  String get netHowStep3Title => 'Якщо й це не допомогло';

  @override
  String get netHowStep3Body => 'Попросіть у людини, якій довіряєте, посилання на проксі й вставте його в «Проксі волонтера». Можна встановити Orbot — застосунок мережі Tor. Це повільніше, і Orbot витрачає батарею.';

  @override
  String get netHowStep4Title => 'Зовсім без інтернету';

  @override
  String get netHowStep4Body => 'Натисніть «Надіслати без мережі», виберіть співрозмовника й передайте файл будь-яким способом: флешкою, AirDrop, Bluetooth. Він відкриє його в Secretly. У файл потрапляють лише вже написані повідомлення за останній тиждень. Живого зв’язку через Bluetooth або сусідні телефони поки немає.';

  @override
  String get netHowStep5Title => 'Дзвінки';

  @override
  String get netHowStep5Body => 'У «Приватності» можна приховати свою адресу в дзвінках: дзвінок піде через наш сервер, і співрозмовник не побачить вашу IP-адресу. Затримка може трохи зрости.';

  @override
  String get netHowStep6Title => 'Щоб повідомлення не запізнювалися';

  @override
  String get netHowStep6Body => 'Система телефона може «приспати» Secretly, і тоді повідомлення прийдуть, лише коли ви відкриєте застосунок. Що заважає доставці, видно в розділі «Надійність».';

  @override
  String get settingsHelpGotIt => 'Зрозуміло';

  @override
  String get settingsHelpTip => 'Порада';

  @override
  String get settingsHelpButton => 'Пояснення';

  @override
  String get settingsHubAccountGroup => 'Акаунт і захист';

  @override
  String get settingsHubTalkGroup => 'Спілкування';

  @override
  String get settingsHubConnectionGroup => 'Зв’язок';

  @override
  String get settingsHubPhoneGroup => 'Телефон';

  @override
  String get settingsHubMoreGroup => 'Ще';

  @override
  String get settingsHubAccountSub => 'Ім’я, Secretly ID, QR, резервна копія';

  @override
  String get settingsHubPrivacySub => 'Хто бачить вас і може написати';

  @override
  String get settingsHubSecuritySub => 'Блокування застосунку, особисті чати';

  @override
  String get settingsHubDevicesSub => 'Де відкрито ваш акаунт';

  @override
  String get settingsHubNotificationsSub => 'Повідомлення, кімнати, дзвінки';

  @override
  String get settingsHubChatsSub => 'Тема, фони, бульбашки, іконка';

  @override
  String get settingsHubLanguageSub => 'Мова застосунку і переклад';

  @override
  String get settingsHubNetworkSub => 'Як Secretly дістається серверів';

  @override
  String get settingsHubOfflineSub => 'Передати повідомлення файлом';

  @override
  String get settingsHubReliabilitySub => 'Що може затримувати доставлення';

  @override
  String get settingsHubSystemSub => 'Скидання і службові повідомлення';

  @override
  String get settingsHubInviteSub => 'Поділитися посиланням';

  @override
  String get settingsHubDonateSub => 'Допомогти проєкту';

  @override
  String get settingsHubSupportSub => 'Написати нам';

  @override
  String get settingsHubPolicySub => 'Що зберігається і де';

  @override
  String get settingsHubAboutSub => 'Версія і ліцензії';

  @override
  String get settingsIntroAccount => 'Як вас бачать інші і як не втратити доступ до листування.';

  @override
  String get settingsIntroPrivacy => 'Вирішіть, хто бачить ваші дані і хто може з вами зв’язатися.';

  @override
  String get settingsIntroSecurity => 'Захист від сторонніх, якщо телефон потрапив у чужі руки.';

  @override
  String get settingsIntroNotifications => 'Що і як вам повідомляти. Почніть із головного перемикача.';

  @override
  String get settingsIntroLanguage => 'Якою мовою з вами говорить Secretly.';

  @override
  String get settingsIntroNetwork => 'Як Secretly з’єднується із серверами. Зазвичай тут нічого не треба змінювати.';

  @override
  String get settingsIntroOffline => 'Якщо інтернету немає зовсім, повідомлення можна передати файлом — флешкою, через Bluetooth або інший месенджер.';

  @override
  String get settingsIntroReliability => 'Перевіряємо, чи не заважає система отримувати повідомлення і дзвінки вчасно.';

  @override
  String get settingsIntroPower => 'Вимкніть ефекти, якщо телефон гріється чи швидко сідає.';

  @override
  String get settingsIntroStorage => 'Скільки місця займає Secretly на телефоні.';

  @override
  String get settingsIntroSystem => 'Службові дії. Користуйтеся, лише якщо щось пішло не так.';

  @override
  String get settingsGroupShare => 'Поділитися';

  @override
  String get settingsGroupMedia => 'Медіа';

  @override
  String get settingsGroupData => 'Дані';

  @override
  String get settingsGroupLock => 'Блокування';

  @override
  String get settingsGroupManual => 'Ручне налаштування';

  @override
  String get settingsHelpManual => 'Потрібне, лише якщо обхідні шляхи не допомогли. Оберіть один спосіб: проксі від знайомого волонтера, SOCKS5 або Tor через Orbot.';

  @override
  String get settingsGroupConnection => 'З’єднання';

  @override
  String get settingsGroupSend => 'Надіслати';

  @override
  String get settingsGroupReceive => 'Отримати';

  @override
  String get settingsOpenPersonalChats => 'Відкрити особисті чати';

  @override
  String get settingsOpenPersonalChatsSub => 'Ваша прихована добірка чатів';

  @override
  String get offlineStep1Title => 'Створіть файл';

  @override
  String get offlineStep1Body => 'Оберіть співрозмовника — у файл потраплять ваші зашифровані повідомлення йому за останній тиждень.';

  @override
  String get offlineStep2Title => 'Передайте будь-яким способом';

  @override
  String get offlineStep2Body => 'Флешка, Bluetooth, AirDrop, інший месенджер. Прочитати повідомлення зможе лише одержувач.';

  @override
  String get offlineStep3Title => 'Співрозмовник відкриває файл';

  @override
  String get offlineStep3Body => 'У Secretly: «Без інтернету» → «Відкрити файл повідомлень». Повідомлення з’являться в чаті.';

  @override
  String get translateSameLanguage => 'Повідомлення вже цією мовою';

  @override
  String get translateUndetected => 'Не вдалося визначити мову. Оберіть мову оригіналу в Налаштуваннях → Мова.';

  @override
  String get translateUnsupported => 'Цієї мови перекладач на телефоні поки не знає';

  @override
  String get translateDownloadFailed => 'Не вдалося завантажити мовний пакет. Перевірте інтернет і натисніть ще раз.';

  @override
  String get translateFailed => 'Не вдалося перекласти. Натисніть ще раз.';

  @override
  String get translateNothing => 'Тут нічого перекладати';

  @override
  String get translateDownloading => 'Завантажуємо мовний пакет — це потрібно один раз';

  @override
  String get translateButtonTooltip => 'Перекласти';

  @override
  String get attachmentMetadataScrubFailed => 'Не вдалося прибрати з файлу місце зйомки й дані телефона, тому його не надіслано. Спробуйте інший знімок або надішліть його як файл.';

  @override
  String get backupServerWrongPassword => 'Пароль не підходить або копії з таким номером профілю немає. Перевірте номер, розкладку й регістр літер.';

  @override
  String backupServerLocked(String time) {
    return 'Забагато неправильних паролів із цієї мережі. Спробуйте після $time або з іншої мережі.';
  }

  @override
  String get backupServerSection => 'Копія на сервері';

  @override
  String get backupServerDelete => 'Видалити копію з сервера';

  @override
  String get backupServerDeleteFooter => 'Зашифрована копія зникне із сервера. Копії на цьому пристрої та у файлах залишаться.';

  @override
  String get backupServerDeleteConfirmTitle => 'Видалити копію з сервера?';

  @override
  String get backupServerDeleteConfirmBody => 'Відновити листування із сервера на новому телефоні буде неможливо. Автокопія на сервер вимкнеться. Скасувати це не можна.';

  @override
  String get backupServerDeleteConfirm => 'Видалити';

  @override
  String get backupServerDeleteDone => 'Копію видалено із сервера';

  @override
  String get backupServerDeleteNone => 'На сервері копії не було';

  @override
  String get backupServerDeleteFailed => 'Не вдалося видалити копію. Перевірте інтернет і спробуйте ще раз.';

  @override
  String get backupAutoErrorNoPassword => 'Автокопія не створюється: не задано пароль копії. Задайте його — без пароля копію нічим зашифрувати.';

  @override
  String get backupAutoErrorWeakPassword => 'Автокопія не створюється: пароль копії більше не відповідає вимогам. Задайте новий.';

  @override
  String backupKeystoreUnreadable(String slot) {
    return 'Не вдається прочитати ключ «$slot» із захищеного сховища телефона, тому копію не створено. Листування на телефоні ціле. Напишіть у підтримку — це виправляється без втрати даних.';
  }

  @override
  String get stickerDeleteTitle => 'Видалити стікер?';

  @override
  String stickerDeleteBody(String title) {
    return 'Стікер зникне з набору «$title». Уже надіслані в листування залишаться.';
  }

  @override
  String get stickerDeleteLastTitle => 'Видалити весь набір?';

  @override
  String stickerDeleteLastBody(String title) {
    return 'Це останній стікер у «$title». Разом із ним видалиться весь набір.';
  }

  @override
  String get stickerDeleteAction => 'Видалити';

  @override
  String get stickerPackSettings => 'Налаштування набору';

  @override
  String get stickerMore => 'Ще';

  @override
  String get stickerPackRemoveFromMine => 'Прибрати з моїх наборів';

  @override
  String stickerPackRemoveFromMineBody(String title) {
    return '«$title» зникне з вашої панелі. В автора та інших набір залишиться — додати його знову можна, натиснувши на стікер із нього в листуванні.';
  }

  @override
  String get stickerPackDeleteWhole => 'Видалити набір';

  @override
  String get stickerPackDeleteWholeTitle => 'Видалити набір?';

  @override
  String stickerPackDeleteWholeBody(String title) {
    return 'Набір «$title» буде видалено з цього пристрою. Уже надіслані стікери залишаться в листуванні.';
  }

  @override
  String get stickerMakeCover => 'Зробити обкладинкою';

  @override
  String get stickerRemoveFromFavorites => 'Прибрати з обраного';

  @override
  String get stickerRemovedFromFavorites => 'Стікер прибрано з обраного';

  @override
  String stickerAddToThisPack(String title) {
    return 'Додати до «$title»';
  }

  @override
  String get stickerAddSticker => 'Додати стікер';

  @override
  String get welcomeTagline => 'Без номера й пошти. Акаунт — це ключ, що живе лише на ваших пристроях.';

  @override
  String get welcomeCreateAccount => 'Створити акаунт';

  @override
  String get welcomeHaveAccount => 'У мене вже є акаунт';

  @override
  String welcomeTermsNotice(String terms, String privacy) {
    return 'Продовжуючи, ви приймаєте $terms і $privacy';
  }

  @override
  String get welcomeTermsLink => 'умови';

  @override
  String get welcomePrivacyLink => 'політику конфіденційності';

  @override
  String get welcomeNameTitle => 'Як вас звати?';

  @override
  String get welcomeNameBody => 'Це ім’я побачать співрозмовники. Його можна змінити.';

  @override
  String get welcomeNameHint => 'Ім’я або псевдонім';

  @override
  String get welcomeKeysStepIdentity => 'Створюємо ключ особи';

  @override
  String get welcomeKeysStepPrekeys => 'Готуємо ключі для перших повідомлень';

  @override
  String get welcomeKeysStepStorage => 'Шифруємо сховище';

  @override
  String get welcomeKeysReady => 'Ключі готові';

  @override
  String get welcomeKeysNote => 'Ключі створюються на цьому пристрої — сервер їх не бачить';

  @override
  String get welcomeBackupTitle => 'Резервна копія';

  @override
  String get welcomeBackupBodyCloud => 'Листування переживе втрату телефона. Копія шифрується паролем, який знаєте лише ви.';

  @override
  String get welcomeBackupBodyDevice => 'Копія зберігається на цьому пристрої. Перенесіть її на новий разом із паролем.';

  @override
  String get welcomeBackupInCloud => 'У хмарі';

  @override
  String get welcomeBackupOnDevice => 'На пристрої';

  @override
  String get welcomeBackupPasswordHint => 'Придумайте пароль';

  @override
  String get welcomeBackupPasswordRepeatHint => 'Повторіть пароль';

  @override
  String get welcomePasswordShow => 'Показати';

  @override
  String get welcomePasswordHide => 'Сховати';

  @override
  String get welcomePasswordStrong => 'Надійний';

  @override
  String get welcomePasswordVeryStrong => 'Дуже надійний';

  @override
  String get welcomeBackupEnable => 'Увімкнути копію';

  @override
  String get welcomeBackupLater => 'Налаштувати пізніше';

  @override
  String get welcomeBackupOnTitle => 'Копію увімкнено';

  @override
  String welcomeBackupOnBody(String schedule) {
    return '$schedule. Змінити можна в налаштуваннях.';
  }

  @override
  String get welcomeNotifyTitle => 'Не пропускайте повідомлення';

  @override
  String get welcomeNotifyBody => 'Apple і Google передають лише сигнал про нове повідомлення — сам текст через них не йде.';

  @override
  String get welcomeNotifyPreviewMessage => 'Нове повідомлення';

  @override
  String get welcomeNotifyPreviewCall => 'Вхідний дзвінок';

  @override
  String get welcomeNotifyNow => 'зараз';

  @override
  String get welcomeNotifyAllow => 'Дозволити сповіщення';

  @override
  String get welcomeNotifyNotNow => 'Не зараз';

  @override
  String welcomeDoneTitle(String name) {
    return 'Ласкаво просимо, $name';
  }

  @override
  String get welcomeDoneTitleNoName => 'Ласкаво просимо';

  @override
  String get welcomeDoneBody => 'Акаунт створено. Запросіть тих, з ким хочете листуватися.';

  @override
  String get welcomeDoneIdCaption => 'Ваш Secretly ID — за ним вас знаходять і відновлюють акаунт. Збережіть його.';

  @override
  String get welcomeCopy => 'Копіювати';

  @override
  String get welcomeCopied => 'Скопійовано';

  @override
  String get welcomeOpenApp => 'Відкрити Secretly';

  @override
  String get welcomeRestoreTitle => 'Відновлення';

  @override
  String get welcomeRestoreSubtitle => 'Звідки повернути акаунт?';

  @override
  String get welcomeRestoreCloudTitle => 'Копія в хмарі';

  @override
  String get welcomeRestoreCloudBody => 'Потрібні Secretly ID і пароль копії';

  @override
  String get welcomeRestoreCloudFormBody => 'Введіть Secretly ID і пароль копії.';

  @override
  String get welcomeRestoreBackupPasswordHint => 'Пароль копії';

  @override
  String get welcomeRestoreFileTitle => 'Файл на пристрої';

  @override
  String get welcomeRestoreFileFormTitle => 'Файл резервної копії';

  @override
  String get welcomeRestoreFileFormBody => 'Виберіть копію і введіть її пароль.';

  @override
  String get welcomeRestoreFilePick => 'Знайти копію на пристрої';

  @override
  String get welcomeRestoreFileChosen => 'Вибраний файл';

  @override
  String get welcomeRestoreFileOther => 'Інший';

  @override
  String get welcomeRestoreStepDownload => 'Завантажуємо копію';

  @override
  String get welcomeRestoreStepDecrypt => 'Перевіряємо пароль і розшифровуємо';

  @override
  String get welcomeRestoreStepApply => 'Повертаємо чати й контакти';

  @override
  String get welcomeRestoreNote => 'Копія розшифровується на цьому пристрої. Сервер не бачить її вмісту.';

  @override
  String get welcomeNewLoginTitle => 'Це ви входите?';

  @override
  String get welcomeNewLoginBody => 'Новий пристрій просить доступ до вашого акаунта. Дозволяйте, лише якщо це ваш пристрій.';

  @override
  String get welcomeNewLoginUnknownDevice => 'Новий пристрій';

  @override
  String welcomeNewLoginTime(String time) {
    return 'Сьогодні о $time';
  }

  @override
  String get welcomeNewLoginSyncSection => 'Що перенести на новий пристрій';

  @override
  String get welcomeNewLoginApprove => 'Так, це я';

  @override
  String get welcomeNewLoginDecline => 'Ні — відхилити вхід';

  @override
  String get welcomeStart => 'Почати';

  @override
  String get welcomeDesktopChooseTitle => 'Підключіть цей комп’ютер';

  @override
  String get welcomeDesktopChooseBody => 'Найшвидше — через телефон, де вже є Secretly. Усе листування переїде сюди.';

  @override
  String get welcomeOr => 'або';

  @override
  String get welcomeDesktopNewAccount => 'Новий акаунт';

  @override
  String get welcomeMoreInfo => 'Докладніше';

  @override
  String get welcomeDesktopQrTitle => 'Відскануйте телефоном';

  @override
  String welcomeDesktopUsePhonePrompt(String link) {
    return 'Телефон із Secretly під рукою? $link — так телефон не втратить доступ.';
  }

  @override
  String get welcomeDesktopUsePhoneLink => 'Увійдіть через нього';

  @override
  String get welcomeDesktopTakeOverUsePhone => 'Підключити через телефон';

  @override
  String get welcomeDesktopKitKeepApart => 'Зберігайте його окремо від комп’ютера — на флешці або в хмарі.';

  @override
  String get pickerDone => 'Готово';

  @override
  String get chatSwipeMute => 'Без звуку';

  @override
  String get chatSwipeUnmute => 'Зі звуком';

  @override
  String get iconStyleClassic => 'Класика';

  @override
  String get iconStyleGlossy => 'Глянець';

  @override
  String get iconStyleClay => 'Об’єм';

  @override
  String get iconStyleFrost => 'Матове скло';

  @override
  String get iconStylePastel => 'Пастель';

  @override
  String get iconStyleNeon => 'Неон';

  @override
  String get iconStyleAurora => 'Аврора';

  @override
  String get iconStyleCircles => 'Кола';

  @override
  String get iconStyleStickers => 'Стікери';

  @override
  String get iconStyleMono => 'Моноліт';

  @override
  String get iconStyleGlass => 'Liquid Glass';

  @override
  String get settingsRowReliability => 'Надійність';

  @override
  String get settingsRowNeedsAttention => 'Потребує уваги';

  @override
  String get settingsRowPower => 'Енергоспоживання';

  @override
  String get settingsRowPowerSub => 'Менше нагрівання та витрати батареї';

  @override
  String get settingsRowSystemNotice => 'Є системне повідомлення';

  @override
  String get settingsRowInvite => 'Запросити друзів';

  @override
  String get settingsRowDonate => 'Підтримати Secretly';

  @override
  String get settingsRowSupport => 'Підтримка';

  @override
  String get settingsRowPolicy => 'Політика конфіденційності';

  @override
  String get settingsRowAbout => 'Про Secretly';

  @override
  String get settingsProfileCardSub => 'Secretly ID, QR-профіль';

  @override
  String get settingsProfileQr => 'QR-код профілю';

  @override
  String settingsSearchNoResults(String query) {
    return 'За запитом «$query» нічого не знайдено';
  }

  @override
  String get settingsPremiumTeaser => 'Більше лімітів, теми, рамки й багато іншого';

  @override
  String get appearanceTitle => 'Оформлення';

  @override
  String get appearanceResetTitle => 'Скинути оформлення?';

  @override
  String get appearanceResetBody => 'Режим, тема, тло, шпалери, бульбашки, розмір тексту, кольори та стиль значків повернуться до стандартних. Налаштування захисту та значок застосунку не зміняться.';

  @override
  String get appearanceTabTheme => 'Тема';

  @override
  String get appearanceTabThemeDesc => 'Режим і кольори інтерфейсу';

  @override
  String get appearanceTabWallpaper => 'Шпалери';

  @override
  String get appearanceTabWallpaperDesc => 'Тло всередині листування';

  @override
  String get appearanceTabBubbles => 'Бульбашки';

  @override
  String get appearanceTabIcons => 'Іконки';

  @override
  String get appearanceTabIconsDesc => 'Стиль значків у налаштуваннях';

  @override
  String get appearanceTabAppIcon => 'Значок';

  @override
  String get appearanceTabAppIconDesc => 'Значок на головному екрані';

  @override
  String get appearanceTabBehavior => 'Поведінка';

  @override
  String get appearanceTabBehaviorDesc => 'Захист і видимість';

  @override
  String get appearanceModeLight => 'Світла';

  @override
  String get appearanceModeDark => 'Темна';

  @override
  String get appearanceModeAuto => 'Авто';

  @override
  String get appearanceAllWallpapers => 'Ще';

  @override
  String get appearanceNickColors => 'Колір імен у відповідях';

  @override
  String get appearanceIndicatorColors => 'Колір галочок та індикаторів';

  @override
  String appearanceTabPosition(int current, int total) {
    return 'Категорія $current з $total';
  }

  @override
  String get appearancePrevTab => 'Попередня категорія';

  @override
  String get appearanceNextTab => 'Наступна категорія';

  @override
  String get appearanceModified => 'змінено';

  @override
  String get appearanceHideScreen => 'Приховувати вміст екрана';

  @override
  String get appearanceHideScreenAndroid => 'Знімок і запис екрана недоступні, у списку застосунків порожньо. Демонстрація екрана та частина засобів доступності перестануть працювати.';

  @override
  String get appearanceHideScreenIos => 'Вміст приховано у списку застосунків. Заборонити знімки екрана iOS застосункам не дозволяє.';

  @override
  String get appearanceHideScreenRefused => 'Система не прийняла налаштування — вміст екрана не приховано.';

  @override
  String get appearanceAppIconAndroidNote => 'Значок зміниться, коли оновиться головний екран, — це може зайняти кілька секунд.';

  @override
  String get desktopAppearanceIconStyle => 'Стиль значків';

  @override
  String get desktopAppearanceIconStyleHint => 'Значки розділів налаштувань. Кожен пристрій пам’ятає свій вибір.';

  @override
  String get appearanceTabText => 'Текст';

  @override
  String get appearanceTabTextDesc => 'Розмір, імена, галочки';

  @override
  String get appearanceTabBackground => 'Тло';

  @override
  String get appearanceTabBackgroundDesc => 'М’які розмиті тла для темної та світлої теми';

  @override
  String get appearanceTabBubblesShapeDesc => 'Колір і форма повідомлень';

  @override
  String get appearanceTextSize => 'Розмір тексту';

  @override
  String get appearanceBubbleRadius => 'Заокруглення кутів';

  @override
  String get appBackdropTheme => 'За темою';

  @override
  String get appBackdropDusk => 'Сутінки';

  @override
  String get appBackdropOcean => 'Океан';

  @override
  String get appBackdropSunset => 'Захід';

  @override
  String get appBackdropMint => 'М’ята';

  @override
  String get appBackdropLavender => 'Лаванда';

  @override
  String get appBackdropPeach => 'Персик';

  @override
  String get appBackdropAurora => 'Аврора';

  @override
  String get appBackdropBerry => 'Ягоди';

  @override
  String get appBackdropAmber => 'Бурштин';

  @override
  String mvCounter(int current, int total) {
    return '$current з $total';
  }

  @override
  String get mvReply => 'Відповісти';

  @override
  String get mvForward => 'Переслати';

  @override
  String get mvEdit => 'Змінити';

  @override
  String get mvShare => 'Поділитися';

  @override
  String get mvDelete => 'Видалити';

  @override
  String get mvMenu => 'Ще';

  @override
  String get mvSaveToGallery => 'Зберегти в галерею';

  @override
  String get mvSaveAsFile => 'Зберегти як файл';

  @override
  String get mvShowInChat => 'Показати в чаті';

  @override
  String get mvAllMedia => 'Усі медіа';

  @override
  String mvAllMediaCount(int count) {
    return 'Усі медіа · $count';
  }

  @override
  String get mvCopy => 'Копіювати';

  @override
  String get mvCopied => 'Скопійовано';

  @override
  String get mvShowFullCaption => 'Показати повністю';

  @override
  String get mvDeletePhotoTitle => 'Видалити фото?';

  @override
  String get mvDeleteVideoTitle => 'Видалити відео?';

  @override
  String get mvDeleteOwnHint => 'Можна видалити лише в себе або одразу в обох.';

  @override
  String get mvDeleteOwnGroupHint => 'Можна видалити лише в себе або одразу в усіх.';

  @override
  String get mvDeleteTheirsHint => 'Чужі фото й відео видаляються лише у вас.';

  @override
  String get mvDeleteLocalHint => 'Видалиться лише на цьому пристрої.';

  @override
  String mvDeleteForBoth(String name) {
    return 'Видалити в мене і в співрозмовника';
  }

  @override
  String get mvDeleteForEveryone => 'Видалити в усіх';

  @override
  String get mvDeleteForMeOnly => 'Видалити лише в мене';

  @override
  String get mvDeleteForMe => 'Видалити в мене';

  @override
  String get mvPhotoDeleted => 'Фото видалено';

  @override
  String get mvVideoDeleted => 'Відео видалено';

  @override
  String get mvSavedToGallery => 'Збережено в галерею';

  @override
  String get mvChangesSaved => 'Зміни збережено';

  @override
  String get mvYou => 'Ви';

  @override
  String get mvPlay => 'Відтворити';

  @override
  String get mvPause => 'Пауза';

  @override
  String get mvReplay => 'Дивитися знову';

  @override
  String get mvMute => 'Вимкнути звук';

  @override
  String get mvUnmute => 'Увімкнути звук';

  @override
  String get mvSpeed => 'Швидкість';

  @override
  String get mvSeekBack => '−5 с';

  @override
  String get mvSeekForward => '+5 с';

  @override
  String get meDone => 'Готово';

  @override
  String get meTabCrop => 'Кадр';

  @override
  String get meTabDraw => 'Малюнок';

  @override
  String get meTabAdjust => 'Корекція';

  @override
  String get meAspectFree => 'Вільно';

  @override
  String get meAspectOriginal => 'Оригінал';

  @override
  String get meReset => 'Скинути';

  @override
  String get meRotate => 'Повернути';

  @override
  String get meFlip => 'Віддзеркалити';

  @override
  String get meStraighten => 'Вирівняти';

  @override
  String get meToolPen => 'Ручка';

  @override
  String get meToolMarker => 'Маркер';

  @override
  String get meToolNeon => 'Неон';

  @override
  String get meToolEraser => 'Гумка';

  @override
  String get meToolText => 'Текст';

  @override
  String get meBrushSize => 'Товщина';

  @override
  String get meHintDraw => 'Малюйте пальцем просто по фото';

  @override
  String get meHintText => 'Торкніться фото, щоб додати текст';

  @override
  String get meHintEraser => 'Проведіть по лінії, щоб стерти її';

  @override
  String get meTextPlaceholder => 'Введіть текст';

  @override
  String get meTextBackground => 'Підкладка';

  @override
  String get meTextHelp => 'Текст можна перетягнути по фото. Дотик до нього — редагування.';

  @override
  String get meBrightness => 'Яскравість';

  @override
  String get meContrast => 'Контраст';

  @override
  String get meSaturation => 'Насиченість';

  @override
  String get meWarmth => 'Тепло';

  @override
  String get meVignette => 'Віньєтка';

  @override
  String get meCompare => 'Порівняти';

  @override
  String get meUndo => 'Скасувати';

  @override
  String get meRedo => 'Повторити';

  @override
  String get meDiscardTitle => 'Скасувати зміни?';

  @override
  String get meDiscardBody => 'Зміни цього фото не збережуться.';

  @override
  String get meDiscardAction => 'Скасувати зміни';

  @override
  String mvDateToday(String time) {
    return 'сьогодні, $time';
  }

  @override
  String mvDateYesterday(String time) {
    return 'учора, $time';
  }

  @override
  String get vnZoom => 'Наближення';

  @override
  String vnNoteTitle(String name) {
    return '$name · відеонотатка';
  }

  @override
  String get vnScrubHint => 'Тягніть убік, щоб перемотати';

  @override
  String get composerEmoji => 'Емодзі, стікери та GIF';

  @override
  String get emojiPanelKeyboard => 'Клавіатура';

  @override
  String get emojiPanelExpand => 'Розгорнути панель';

  @override
  String get emojiPanelSearchHint => 'Пошук емодзі: сміх, кіт, кава';

  @override
  String get emojiPanelResults => 'Результати';

  @override
  String get emojiPanelNothingFound => 'Нічого не знайшлося. Спробуйте «сміх», «кіт» або «кава».';

  @override
  String get emojiPanelFavoritesEmpty => 'Утримуйте стікер і додайте його в обране';

  @override
  String get emojiPanelPreviewHint => 'Ведіть по стікерах, відпустіть — з’явиться меню';

  @override
  String get emojiPanelGifTrending => 'У тренді';

  @override
  String get emojiPanelGifNotFound => 'GIF не знайдено';

  @override
  String get emojiPanelGifLaugh => 'Сміх';

  @override
  String get emojiPanelGifLove => 'Кохання';

  @override
  String get emojiPanelGifApproval => 'Схвалення';

  @override
  String get emojiPanelGifHello => 'Привіт';

  @override
  String get emojiPanelGifHug => 'Обійми';

  @override
  String get emojiPanelGifCrying => 'Сльози';

  @override
  String get emojiPanelGifExcited => 'Захват';

  @override
  String get emojiPanelGifThinking => 'Роздуми';

  @override
  String get emojiPanelGifSleepy => 'Сон';

  @override
  String get emojiPanelGifAngry => 'Злість';

  @override
  String get emojiPanelGifShocked => 'Шок';

  @override
  String get emojiPanelGifDance => 'Танці';

  @override
  String get emojiPanelGifParty => 'Свято';

  @override
  String get emojiPanelGifCats => 'Коти';

  @override
  String get emojiPanelGifDogs => 'Собаки';

  @override
  String get emojiPanelGifFire => 'Вогонь';

  @override
  String get emojiPanelGifFood => 'Їжа';

  @override
  String get emojiPanelGifSport => 'Спорт';

  @override
  String emojiPanelStickerCount(int count) {
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
  String get chatListTimeNow => 'зараз';

  @override
  String chatListTimeMinutes(int count) {
    return '$count хв';
  }

  @override
  String get chatListCallInProgress => 'Триває дзвінок';

  @override
  String get chatListCallRinging => 'Дзвінок…';

  @override
  String get eliteBadgeTeamTitle => 'Команда Secretly';

  @override
  String get eliteBadgeTeamBody => 'Ця галочка підтверджує, що користувач входить до складу розробників Secretly.';

  @override
  String get eliteBadgeStatusLabel => 'Статус';

  @override
  String get eliteBadgeRoleFounder => 'Засновник';

  @override
  String get eliteBadgeRoleTester => 'Тестувальник';

  @override
  String get mvEditedTitle => 'Відредаговане фото';

  @override
  String get mvEditedHint => 'Оригінал не зміниться — надішлеться копія з правками.';

  @override
  String get mvEditedSend => 'Надіслати копію';

  @override
  String get mvEditedDiscard => 'Скасувати правки';

  @override
  String get mvEditedSent => 'Відредаговане фото надіслано';

  @override
  String get chatTranslateMenuItem => 'Переклад';

  @override
  String get chatTranslateSheetTitle => 'Переклад у цьому чаті';

  @override
  String get chatTranslateModeLabel => 'Режим';

  @override
  String get chatTranslateModeInherit => 'Як у налаштуваннях';

  @override
  String get chatTranslateModeOff => 'Вимкнено';

  @override
  String get chatTranslateModeButton => 'Кнопка «Перекласти»';

  @override
  String get chatTranslateModeAuto => 'Перекладати автоматично';

  @override
  String get chatTranslateFrom => 'Перекладати з мови';

  @override
  String get chatTranslateTo => 'Перекладати на мову';

  @override
  String get chatTranslateAutoDetect => 'Визначати автоматично';

  @override
  String get chatTranslateAppLanguage => 'Мова застосунку';

  @override
  String get chatTranslateReset => 'Скинути до налаштувань';

  @override
  String get chatTranslateSameLanguagePair => 'Мови «з» і «на» збігаються';

  @override
  String get chatTranslateAllLanguages => 'Усі мови';

  @override
  String get chatTranslatePrivacyNote => 'Переклад виконується на телефоні — текст нікуди не надсилається. Мовний пакет завантажується один раз.';

  @override
  String get pinnedMessageUnavailable => 'Повідомлення недоступне на цьому пристрої';

  @override
  String get reactionAllEmoji => 'Усі емодзі';

  @override
  String get composerRecordVoice => 'Голосове повідомлення';

  @override
  String get composerRecordVideo => 'Відеоповідомлення';

  @override
  String get composerRecordHint => 'Утримуйте для запису, дотик — перемкнути';

  @override
  String get videoNoteHintTooShort => 'Занадто коротко — утримуйте довше';

  @override
  String get videoNoteHintLimitReached => 'Досягнуто ліміту — 1 хвилина';

  @override
  String get videoNoteHintRetake => 'Утримуйте кнопку, щоб зняти знову';

  @override
  String get videoNoteHintNoPermission => 'Для відео потрібні камера та мікрофон';

  @override
  String get videoNoteHintCameraFailed => 'Камера недоступна — спробуйте ще раз';

  @override
  String get videoNoteRecSlideToCancel => 'Вліво — скасувати';

  @override
  String get videoNoteRecReleaseToDelete => 'Відпустіть — видалити';

  @override
  String get videoNoteRecPause => 'Пауза';

  @override
  String get videoNoteRecResume => 'Продовжити';

  @override
  String get videoNoteRecStop => 'Зупинити й переглянути';

  @override
  String get videoNoteRecDelete => 'Видалити';

  @override
  String get videoNoteRecRetake => 'Перезняти';

  @override
  String get videoNoteRecLooped => 'по колу';

  @override
  String get videoNoteRecFlip => 'Змінити камеру';

  @override
  String get videoNoteRecLight => 'Підсвітка';

  @override
  String get videoNoteRecPlay => 'Дивитися';

  @override
  String get videoNoteRecTrimStart => 'Початок ролика';

  @override
  String get videoNoteRecTrimEnd => 'Кінець ролика';

  @override
  String get videoNoteRecCameraUnavailable => 'Камера недоступна';

  @override
  String get voiceHintHoldToRecord => 'Утримуйте, щоб записати голосове';

  @override
  String get voiceHintTooShort => 'Занадто коротко — утримуйте довше';

  @override
  String get voiceHintNoPermission => 'Немає доступу до мікрофона';

  @override
  String get voiceHintFailed => 'Не вдалося записати голосове';

  @override
  String get voiceRecSlideToCancel => 'Вліво — скасувати';

  @override
  String get voiceRecReleaseToDelete => 'Відпустіть — видалити';

  @override
  String get voiceRecDeleted => 'Запис видалено';

  @override
  String get voiceRecStop => 'Зупинити й прослухати';

  @override
  String get voiceRecPlay => 'Прослухати';

  @override
  String get voiceRecPause => 'Пауза';

  @override
  String get emojiCategorySmileys => 'Смайли та емоції';

  @override
  String get emojiCategoryPeople => 'Люди та жести';

  @override
  String get emojiCategoryAnimals => 'Тварини та природа';

  @override
  String get emojiCategoryFood => 'Їжа та напої';

  @override
  String get emojiCategoryTravel => 'Подорожі та місця';

  @override
  String get emojiCategoryActivities => 'Активності';

  @override
  String get emojiCategoryObjects => 'Об’єкти';

  @override
  String get emojiCategorySymbols => 'Символи';

  @override
  String get emojiCategoryFlags => 'Прапори';

  @override
  String get voicePlaybackSpeed => 'Швидкість відтворення';

  @override
  String get mvVideoOpenFailed => 'Не вдалося відкрити відео';

  @override
  String get mvRetry => 'Повторити';

  @override
  String get mvVideoBuffering => 'Відео завантажується…';

  @override
  String get appIconChangeFailed => 'Не вдалося змінити значок застосунку. Спробуйте ще раз.';

  @override
  String get chatUnreadMessagesDivider => 'Непрочитані повідомлення';

  @override
  String get premiumHubTitle => 'Premium';

  @override
  String get premiumHubRestore => 'Відновити';

  @override
  String get premiumHubChipFree => 'Безкоштовний тариф';

  @override
  String get premiumHubChipActive => 'Premium активний';

  @override
  String get premiumHubHeroFree => 'Secretly Premium';

  @override
  String get premiumHubHeroPremium => 'Вітаємо!';

  @override
  String get premiumHubSubFree => 'Рамки, живі шпалери, розшифрування голосових і великі ліміти. Ось що відкриє підписка.';

  @override
  String get premiumHubSubPremium => 'Усі функції нижче вже відкриті. Дякуємо, що підтримуєте Secretly.';

  @override
  String get premiumHubSeenAs => 'Так вас бачать у чатах';

  @override
  String get premiumHubPlan => 'Тариф';

  @override
  String get premiumHubPlanPremium => 'Premium';

  @override
  String get premiumHubPlanLifetime => 'Premium · Назавжди';

  @override
  String get premiumHubPlanTeam => 'Premium · Команда';

  @override
  String get premiumHubPlanLegacy => 'Premium · Рання підтримка';

  @override
  String get premiumHubRenews => 'Наступне продовження';

  @override
  String get premiumHubPayment => 'Оплата';

  @override
  String get premiumHubOneTime => 'разовий платіж';

  @override
  String get premiumHubManage => 'Керувати підпискою';

  @override
  String get premiumHubFramesCovers => 'РАМКИ ТА ОБКЛАДИНКИ';

  @override
  String get premiumHubAll => 'Усі';

  @override
  String get premiumHubFramesNote => 'Частина рамок і обкладинок безкоштовна. Решту відкриє Premium.';

  @override
  String get premiumHubGroupProfile => 'ПРОФІЛЬ';

  @override
  String get premiumHubGroupChats => 'ЧАТИ Й ОФОРМЛЕННЯ';

  @override
  String get premiumHubGroupFeatures => 'МОЖЛИВОСТІ';

  @override
  String get premiumHubStatusName => 'Емодзі-статус';

  @override
  String get premiumHubStatusDesc => 'Емодзі поруч з іменем у чатах і профілі';

  @override
  String get premiumHubBadgeName => 'Значок Premium';

  @override
  String get premiumHubBadgeDesc => 'Знак Premium поруч із вашим іменем';

  @override
  String get premiumHubVideoName => 'Відеоаватар';

  @override
  String get premiumHubVideoDesc => 'Коротке відео замість фото';

  @override
  String get premiumHubCoverName => 'Своя обкладинка';

  @override
  String get premiumHubCoverDesc => 'Фото або відео на обкладинці профілю';

  @override
  String get premiumHubWallpaperName => 'Живі шпалери';

  @override
  String get premiumHubWallpaperDesc => 'Анімовані шпалери й преміум-теми';

  @override
  String get premiumHubStickersName => 'Преміум-стікери';

  @override
  String get premiumHubStickersDesc => 'Преміум-набори стікерів';

  @override
  String get premiumHubAppIconName => 'Іконка застосунку';

  @override
  String get premiumHubAppIconDesc => 'Преміум-іконки на головному екрані';

  @override
  String get premiumHubRingtonesName => 'Рингтони';

  @override
  String get premiumHubRingtonesDesc => 'Власні звуки виклику й повідомлень';

  @override
  String get premiumHubVoiceName => 'ШІ: голос у текст';

  @override
  String get premiumHubVoiceDesc => 'Розшифрування голосових прямо на пристрої';

  @override
  String get premiumHubVoiceSample => 'Буду о 7';

  @override
  String get premiumHubDevicesName => 'Кілька пристроїв';

  @override
  String get premiumHubDevicesDesc => 'Secretly на комп’ютері та інших пристроях';

  @override
  String premiumHubFilesName(String size) {
    return 'Файли до $size';
  }

  @override
  String premiumHubFilesDesc(String size) {
    return 'Замість $size на безкоштовному тарифі';
  }

  @override
  String premiumHubCallsName(int count) {
    return 'Дзвінки до $count учасників';
  }

  @override
  String premiumHubCallsDesc(int count) {
    return 'Замість $count на безкоштовному тарифі';
  }

  @override
  String get premiumHubGroupsName => 'Більше власних груп і кімнат';

  @override
  String premiumHubGroupsDesc(int premium, int free) {
    return 'До $premium замість $free, участь без ліміту';
  }

  @override
  String get premiumHubLimits => 'ЛІМІТИ: FREE І PREMIUM';

  @override
  String get premiumHubColFree => 'Free';

  @override
  String get premiumHubColPremium => 'Premium';

  @override
  String get premiumHubLimitFiles => 'Файли';

  @override
  String get premiumHubLimitCalls => 'Учасники дзвінка';

  @override
  String get premiumHubLimitOwnGroups => 'Власні групи й кімнати';

  @override
  String get premiumHubLimitJoinedGroups => 'Групи, де ви учасник';

  @override
  String get premiumHubLimitDevices => 'Пристрої';

  @override
  String get premiumHubLimitCosmetics => 'Рамки та обкладинки';

  @override
  String get premiumHubUnlimited => 'без ліміту';

  @override
  String get premiumHubSeveral => 'кілька';

  @override
  String get premiumHubSome => 'частина';

  @override
  String get premiumHubAllValue => 'усі';

  @override
  String get premiumHubSoon => 'НЕЗАБАРОМ У PREMIUM';

  @override
  String get premiumHubSoonChip => 'Незабаром';

  @override
  String get premiumHubSoonSpaces => 'Spaces — канали та спільноти';

  @override
  String get premiumHubSoonStickers => 'Власні стікерпаки й створення стікерів';

  @override
  String get premiumHubSoonStories => 'Історії, що зникають';

  @override
  String get premiumHubSoonWatch => 'Спільний перегляд відео у дзвінках';

  @override
  String get premiumHubSoonHd => 'HD-відеодзвінки й шумозаглушення';

  @override
  String get premiumHubGet => 'Отримати Premium';

  @override
  String premiumHubSizeMb(int n) {
    return '$n МБ';
  }

  @override
  String premiumHubSizeGb(int n) {
    return '$n ГБ';
  }

  @override
  String get premiumHubLogoHint => 'Знак Secretly зі світлячків. Нахиляйте пальцем.';

  @override
  String get translucentCardsTitle => 'Прозорі плашки';

  @override
  String get translucentCardsSubtitle => 'Плашки налаштувань, профілів і вікон злегка просвічують тло. Вимкніть — стануть щільними.';

  @override
  String get teamCoversTitle => 'Команда Secretly';

  @override
  String get teamCoversSubtitle => 'Закриті обкладинки. Їх немає в каталозі: вибрати можна лише зі знаком команди, а бачать їх усі — у вашому профілі.';

  @override
  String get settingsStyleSection => 'Стиль';

  @override
  String get whatsNewTitle => 'Зустрічайте Secretly 1.9';

  @override
  String get whatsNewSubtitle => 'Швидше, тихіше й ще професійніше.';

  @override
  String get whatsNewOpen => 'Що нового';

  @override
  String get whatsNewLater => 'Пізніше';

  @override
  String get whatsNewHeader => 'Що нового в 1.9';

  @override
  String get whatsNewNext => 'Далі';

  @override
  String get whatsNewStart => 'Почати';

  @override
  String get whatsNewClose => 'Закрити';

  @override
  String get whatsNewCard1Title => 'Миттєво зі сповіщення';

  @override
  String get whatsNewCard1Body => 'Натиснули на сповіщення — чат відкрито на першому непрочитаному.';

  @override
  String get whatsNewCard2Title => 'Новий вигляд';

  @override
  String get whatsNewCard2Body => 'Острівці, панелі й смуга папок — спокійніше й чистіше.';

  @override
  String get whatsNewCard3Title => 'Ваш стиль';

  @override
  String get whatsNewCard3Body => 'Тема, фон, бульбашки й значок — у розділі «Стиль».';

  @override
  String get whatsNewCard4Title => 'Профіль, що живе';

  @override
  String get whatsNewCard4Body => 'Живі обкладинки й рамки, перехід у профіль одним рухом.';

  @override
  String get whatsNewCard5Title => 'Повідомлення';

  @override
  String get whatsNewCard5Body => 'Нове поле вводу, емодзі, голосові, кружечки й редактор фото.';

  @override
  String get whatsNewCard6Title => 'Емоції';

  @override
  String get whatsNewCard6Body => 'Реакції з польотом і 63 емодзі з ефектом на весь екран.';

  @override
  String get whatsNewDemoSender => 'Аліса';

  @override
  String get whatsNewDemoMessage => 'Подивишся ввечері?';

  @override
  String get whatsNewDemoNow => 'зараз';

  @override
  String get whatsNewSettingsRow => 'Що нового в 1.9';

  @override
  String get penHintSearch => 'Пошук за ніком і контактами';

  @override
  String get penHintStyle => 'Тема, фон, бульбашки, значок';

  @override
  String get penHintPanels => 'Прозоро чи щільно';

  @override
  String get penHintCovers => 'Живі обкладинки';

  @override
  String get penHintEmoji => 'Емодзі, стікери, GIF';

  @override
  String get penHintReactions => 'Реакції — довгим натисканням';

  @override
  String get stickerPremiumPackSafe => 'Секретний сейф';

  @override
  String get stickerPremiumPackPixel => 'Pixel';

  @override
  String get stickerPremiumSubtitle => 'Анімовані стікери для передплатників Premium';

  @override
  String get stickerPremiumUnlock => 'Відкрити з Premium';

  @override
  String get stickerPackKids => 'Дітки';

  @override
  String get meToolArrow => 'Стрілка';
}
