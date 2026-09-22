// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Secretly';

  @override
  String get starting => 'Iniciando…';

  @override
  String get encrypting => 'Cifrando…';

  @override
  String errorPrefix(Object error) {
    return 'Error: $error';
  }

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get notificationsSection => 'Notificaciones';

  @override
  String get languageSection => 'Idioma';

  @override
  String get comingSoon => 'Próximamente';

  @override
  String get idsTitle => 'IDs';

  @override
  String get profileIdLabel => 'ID de perfil';

  @override
  String get deviceIdLabel => 'ID de dispositivo';

  @override
  String get profileIdShort => 'Perfil';

  @override
  String get deviceIdShort => 'Dispositivo';

  @override
  String get copy => 'Copiar';

  @override
  String get copied => 'Copiado';

  @override
  String get copyBoth => 'Copiar ambos';

  @override
  String get openMyId => 'Abrir mi ID';

  @override
  String get close => 'Cerrar';

  @override
  String get tabChats => 'Chats';

  @override
  String get tabGroups => 'Salas';

  @override
  String get tabContacts => 'Contactos';

  @override
  String get tabProfile => 'Perfil';

  @override
  String get accountSection => 'Cuenta';

  @override
  String get chatsSection => 'Chats';

  @override
  String get privacySection => 'Privacidad';

  @override
  String get devicesSection => 'Dispositivos';

  @override
  String get systemSection => 'Sistema';

  @override
  String get languageSystemDefault => 'Predeterminado del sistema';

  @override
  String languageSystemCurrent(Object language) {
    return 'Sistema ($language)';
  }

  @override
  String get languageChooseAppLanguage => 'Elegir idioma de la app';

  @override
  String get languageAvailableWave1 => 'Disponible: inglés, ruso, ucraniano, español, portugués (Brasil), francés y alemán. También puedes usar el idioma del sistema.';

  @override
  String get languageMessageTranslation => 'Traducción de mensajes';

  @override
  String get languageShowTranslateButton => 'Mostrar botón Traducir';

  @override
  String get languageTranslateWholeChats => 'Traducir chats completos';

  @override
  String get favoritesTitle => 'Favoritos';

  @override
  String get favoritesSubtitle => 'Tus notas personales';

  @override
  String get favoritesEmptyTitle => 'Aún no hay favoritos';

  @override
  String get favoritesEmptySubtitle => 'Envía mensajes, archivos y notas aquí para mantenerlos privados en tus dispositivos.';

  @override
  String get favoritesPersonalNotebookLabel => 'Notas personales';

  @override
  String get more => 'Más';

  @override
  String get stickersRecent => 'Stickers recientes';

  @override
  String get searchStickers => 'Buscar stickers';

  @override
  String get noStickersFound => 'No se encontraron stickers';

  @override
  String get noRecentStickers => 'Tus stickers recientes aparecerán aquí';

  @override
  String get cancelSelection => 'Cancelar selección';

  @override
  String get chatsTitle => 'Chats';

  @override
  String get newChat => 'Nuevo chat';

  @override
  String get openContactsToStartChat => 'Abre Contactos para iniciar un chat';

  @override
  String get noChatsYet => 'Aún no hay chats';

  @override
  String get openDemoChat => 'Abrir chat de demostración';

  @override
  String get archive => 'Archivar';

  @override
  String get unarchive => 'Desarchivar';

  @override
  String get pin => 'Fijar';

  @override
  String get unpin => 'Desfijar';

  @override
  String get clearHistory => 'Borrar historial';

  @override
  String archiveHeader(Object count) {
    return 'Archivo ($count)';
  }

  @override
  String deleteChatsConfirmTitle(Object count) {
    return '¿Eliminar $count chat(s)?';
  }

  @override
  String get deleteChatsConfirmBody => 'Esto elimina los chats solo de este dispositivo.';

  @override
  String clearHistoryConfirmTitle(Object count) {
    return '¿Borrar el historial de $count chat(s)?';
  }

  @override
  String get clearHistoryConfirmBody => 'Esto elimina los mensajes solo de este dispositivo.';

  @override
  String get contactsTitle => 'Contactos';

  @override
  String get contactsTab => 'Contactos';

  @override
  String get requestsTab => 'Solicitudes';

  @override
  String get addContact => 'Añadir contacto';

  @override
  String get deleteContact => 'Eliminar contacto';

  @override
  String get noContactsYet => 'Aún no hay contactos';

  @override
  String get noRequests => 'No hay solicitudes';

  @override
  String get secretlyIdLabel => 'Secretly ID';

  @override
  String get secretlyIdHint => 'XXXX-XXXX-...-CHECK';

  @override
  String get nameOptionalLabel => 'Nombre (opcional)';

  @override
  String get scanContactQrTitle => 'Escanear QR de contacto';

  @override
  String get qrMissingSecretlyId => 'El QR no contiene un Secretly ID';

  @override
  String get differentServerTitle => 'Servidor diferente';

  @override
  String differentServerBody(Object qrServer, Object appServer) {
    return 'Este QR pertenece a otro servidor.\n\nServidor del QR: $qrServer\nEsta app: $appServer\n\nInstala el mismo APK/servidor en ambos teléfonos.';
  }

  @override
  String get contactActionProfileNotFound => 'No se encontró ese Secretly ID en este servidor.';

  @override
  String get contactActionTransportBlocked => 'Esta acción no está disponible porque la app está vinculada a otro servidor.';

  @override
  String get contactActionServiceUnavailable => 'El servidor no está disponible ahora. Inténtalo de nuevo en un momento.';

  @override
  String get contactActionCallsDisabled => 'Las llamadas están desactivadas en los ajustes de privacidad.';

  @override
  String get contactActionCallsDisabledForContact => 'Las llamadas están desactivadas para este contacto.';

  @override
  String get callServiceUnavailable => 'El servicio de llamadas no está disponible ahora.';

  @override
  String get callAlreadyInProgress => 'Ya hay otra llamada en curso.';

  @override
  String get callIceUnavailable => 'La configuración segura de la llamada no está disponible ahora. Inténtalo de nuevo en un momento.';

  @override
  String get callPermissionDenied => 'El acceso al micrófono o a la cámara está bloqueado. Concede permisos e inténtalo de nuevo.';

  @override
  String get callNegotiationFailed => 'No se pudo establecer la llamada segura. Inténtalo de nuevo.';

  @override
  String get callConnectionInterrupted => 'La conexión de la llamada se interrumpió. Inténtalo de nuevo.';

  @override
  String get callActionGeneric => 'No se pudo iniciar la llamada. Inténtalo de nuevo.';

  @override
  String get callEncryptedBadge => 'Cifrado de extremo a extremo';

  @override
  String get incomingVideoCall => 'Videollamada entrante';

  @override
  String get incomingVoiceCall => 'Llamada de voz entrante';

  @override
  String get callDecline => 'Rechazar';

  @override
  String get callConnectionUnstable => 'Conexión inestable';

  @override
  String get callNetworkVeryWeak => 'Señal de red muy débil';

  @override
  String get callNetworkWeak => 'Señal de red débil';

  @override
  String get callEnded => 'Llamada finalizada';

  @override
  String get callReplacedByNewerAttempt => 'La llamada fue reemplazada por un intento más reciente';

  @override
  String get callDeclined => 'Llamada rechazada';

  @override
  String get callYouDeclined => 'Rechazaste';

  @override
  String get callNoAnswer => 'Sin respuesta';

  @override
  String get callConnectionError => 'Error de conexión';

  @override
  String get callVideoUnavailable => 'Video no disponible';

  @override
  String get callWaitingForRemoteVideo => 'Esperando el video remoto...';

  @override
  String get callAttachingRemoteVideo => 'Adjuntando video remoto...';

  @override
  String get callStartingRemoteVideo => 'Iniciando video remoto...';

  @override
  String get callRemoteVideoNotArriving => 'El video remoto no está llegando';

  @override
  String get callRemoteVideoBindFailed => 'No se pudo vincular el flujo de video remoto';

  @override
  String get callRemoteVideoNoFrames => 'El video remoto está adjunto, pero no se renderizan fotogramas';

  @override
  String get callMinimize => 'Minimizar';

  @override
  String get callStatusCalling => 'Llamando...';

  @override
  String get callStatusIncoming => 'Entrante...';

  @override
  String get callStatusConnecting => 'Conectando...';

  @override
  String get callStatusReconnecting => 'Reconectando...';

  @override
  String get callStatusEnded => 'Finalizada';

  @override
  String get callVideoCall => 'Videollamada';

  @override
  String get callControlMute => 'Silenciar';

  @override
  String get callControlSpeaker => 'Altavoz';

  @override
  String get callControlCamera => 'Cámara';

  @override
  String get callControlFlip => 'Cambiar';

  @override
  String get callControlStop => 'Detener';

  @override
  String get callControlShare => 'Compartir';

  @override
  String get callControlEnd => 'Finalizar';

  @override
  String get contactActionGeneric => 'No se pudo completar la acción. Inténtalo de nuevo.';

  @override
  String get notificationTitleRoom => 'Sala';

  @override
  String get notificationTitleRequest => 'Solicitud';

  @override
  String get notificationTitleChat => 'Chat';

  @override
  String get notificationBodyNewMessage => 'Nuevo mensaje';

  @override
  String get contactLookupUnavailable => 'La búsqueda no está disponible ahora. Inténtalo de nuevo en un momento.';

  @override
  String addContactFailed(Object error) {
    return 'No se pudo añadir el contacto: $error';
  }

  @override
  String deleteContactsConfirmTitle(Object count) {
    return '¿Eliminar $count contacto(s)?';
  }

  @override
  String get deleteContactsConfirmBody => 'Los chats no se eliminan.';

  @override
  String get privacyTitle => 'Privacidad';

  @override
  String get blockedUsersSubtitle => 'Los usuarios bloqueados no pueden entregarte mensajes (aplicado por el servidor).';

  @override
  String get noBlockedUsers => 'No hay usuarios bloqueados';

  @override
  String unblockFailed(Object error) {
    return 'No se pudo desbloquear: $error';
  }

  @override
  String get diagIdentity => 'Identidad';

  @override
  String get diagEndpoints => 'Endpoints';

  @override
  String get diagServerBinding => 'Vinculación del servidor';

  @override
  String get diagMismatch => 'No coincide: el perfil pertenece a otro servidor. Usa Ajustes → Restablecer perfil.';

  @override
  String get diagStatus => 'Estado';

  @override
  String get diagTimestamps => 'Marcas de tiempo';

  @override
  String get diagTips => 'Consejos';

  @override
  String get diagTipsBody => 'Si los mensajes fallan con \"profile not found\":\n1) Asegúrate de que ambos teléfonos usen el mismo APK/servidor\n2) Vuelve a añadir el contacto escaneando el QR\n3) Si cambiaron los endpoints, usa Restablecer perfil\n';

  @override
  String get secretlyUser => 'Usuario de Secretly';

  @override
  String get onlineStatus => 'en línea';

  @override
  String get edit => 'Editar';

  @override
  String get removePhoto => 'Eliminar foto';

  @override
  String get profileSectionTitle => 'Perfil';

  @override
  String get myNicknameLabel => 'Mi apodo';

  @override
  String get myNicknameHint => 'p. ej., Alex';

  @override
  String get includeNicknameInQr => 'Incluir mi apodo en mi QR';

  @override
  String get includeNicknameInQrSubtitle => 'Desactivado de forma predeterminada por privacidad. Si se activa, quienes escaneen pueden asignarte un nombre automáticamente.';

  @override
  String verifyTitle(Object title) {
    return 'Verificar: $title';
  }

  @override
  String get scanVerifyQrTitle => 'Escanear QR de verificación';

  @override
  String qrBelongsAnotherServer(Object server) {
    return 'El QR pertenece a otro servidor: $server';
  }

  @override
  String get qrSecretlyIdMismatch => 'El Secretly ID del QR no coincide con este contacto';

  @override
  String get qrMissingDeviceKeyInfo => 'El QR no incluye información del dispositivo/clave';

  @override
  String get deviceNotCachedTapRefresh => 'El dispositivo no está en caché. Toca Actualizar primero.';

  @override
  String get identityKeyMismatch => 'La identity key no coincide. No verifiques.';

  @override
  String get verifiedSuccess => 'Verificado ✅';

  @override
  String get refreshKeys => 'Actualizar Keys';

  @override
  String get keysOfflineCannotFetch => 'El servicio Keys está sin conexión. No se pueden obtener las claves del contacto ahora.';

  @override
  String get devicesLabel => 'Dispositivos';

  @override
  String get noDeviceKeysCachedYet => 'Aún no hay claves de dispositivos en caché.';

  @override
  String deviceTitle(Object deviceId) {
    return 'Dispositivo $deviceId';
  }

  @override
  String deviceFpStatus(Object fp, Object status) {
    return 'fp: $fp\n$status';
  }

  @override
  String get verifiedLower => 'verificado';

  @override
  String get unverifiedLower => 'sin verificar';

  @override
  String get keysOfflineIdTemporary => 'El servicio Keys está sin conexión. El ID puede ser temporal en modo de desarrollo.';

  @override
  String get serverKeysLabel => 'Servidor (Keys)';

  @override
  String get nicknameLabel => 'Apodo';

  @override
  String get identityFingerprintLabel => 'Huella de identidad';

  @override
  String get scanToAddVerifyContact => 'Escanea para añadir/verificar este contacto';

  @override
  String get mySecretlyId => 'Mi Secretly ID';

  @override
  String get deviceId => 'ID de dispositivo';

  @override
  String get recoveryKit => 'Recovery Kit';

  @override
  String get safeBackupTitle => 'Safe Backup';

  @override
  String get safeBackupSubtitle => 'Safe Backup cifrado almacenado en el servidor';

  @override
  String get safeBackupIntro => 'Crea una copia cifrada localmente o en el servidor. Podrás restaurarla más tarde desde un archivo o un Secretly ID.';

  @override
  String get safeBackupUploadNow => 'Subir copia ahora';

  @override
  String get safeBackupRestoreFromServer => 'Restaurar desde el servidor';

  @override
  String get safeBackupRestoreTitle => 'Restaurar desde copia del servidor';

  @override
  String get safeBackupRestoreConfirmTitle => '¿Restaurar cuenta?';

  @override
  String get safeBackupRestoreConfirmBody => 'Esto eliminará los chats/contactos locales de este dispositivo y restaurará la cuenta desde la copia seleccionada. La app se reiniciará automáticamente.';

  @override
  String get safeBackupUploaded => 'Copia subida';

  @override
  String get safeBackupUploadFailed => 'No se pudo subir la copia';

  @override
  String safeBackupUploadFailedWithError(Object error) {
    return 'No se pudo subir la copia: $error';
  }

  @override
  String get safeBackupNotFound => 'No se encontró una copia en el servidor para este Secretly ID';

  @override
  String get exportRecoveryKit => 'Exportar Recovery Kit';

  @override
  String get exportRecoveryKitSubtitle => 'QR cifrado para recuperación de cuenta';

  @override
  String get restoreRecoveryKit => 'Restaurar desde Recovery Kit';

  @override
  String get restoreRecoveryKitSubtitle => 'Borra los datos locales y restaura este Secretly ID';

  @override
  String get recoveryPasswordTitle => 'Contraseña de Recovery Kit';

  @override
  String get password => 'Contraseña';

  @override
  String get confirmPassword => 'Confirmar contraseña';

  @override
  String get export => 'Exportar';

  @override
  String get scanQr => 'Escanear QR';

  @override
  String get invalidRecoveryKit => 'Recovery Kit no válido';

  @override
  String get wrongPassword => 'Contraseña incorrecta';

  @override
  String get restoreConfirmTitle => '¿Restaurar cuenta?';

  @override
  String get restoreConfirmBody => 'Esto eliminará los chats/contactos locales de este dispositivo y restaurará la cuenta desde el Recovery Kit.';

  @override
  String get restore => 'Restaurar';

  @override
  String get darkTheme => 'Tema oscuro';

  @override
  String get darkThemeSubtitle => 'Usar el mismo tono de acento en modo oscuro.';

  @override
  String get blockUnverified => 'Bloquear envío a contactos sin verificar';

  @override
  String get blockUnverifiedSubtitle => 'Modo estricto: en chats individuales, enviar solo a contactos cuyas claves hayas comprobado tú mismo. No se aplica a los grupos.';

  @override
  String get blockedUsers => 'Usuarios bloqueados';

  @override
  String get resetProfile => 'Restablecer perfil';

  @override
  String get resetProfileSubtitle => 'Corrige la discrepancia de servidor/cuenta creando un nuevo Secretly ID';

  @override
  String get resetProfileDialogTitle => '¿Restablecer perfil?';

  @override
  String get resetProfileDialogBody => 'Esto eliminará chats/contactos/solicitudes locales de este dispositivo y creará un nuevo Secretly ID.\n\nÚsalo si cambiaste de APK/servidor y los mensajes empezaron a fallar.';

  @override
  String get cancel => 'Cancelar';

  @override
  String get ok => 'OK';

  @override
  String get add => 'Añadir';

  @override
  String get delete => 'Eliminar';

  @override
  String get clear => 'Borrar';

  @override
  String get block => 'Bloquear';

  @override
  String get unblock => 'Desbloquear';

  @override
  String get accept => 'Aceptar';

  @override
  String get verify => 'Verificar';

  @override
  String get menu => 'Menú';

  @override
  String get search => 'Buscar';

  @override
  String get queryLabel => 'Consulta';

  @override
  String get messageHint => 'Mensaje';

  @override
  String get notificationActionMarkRead => 'Marcar como leído';

  @override
  String get addCaption => 'Añadir un título';

  @override
  String get uploadCanceled => 'Carga cancelada';

  @override
  String get attachmentFinalizeTimeout => 'La red es inestable: la carga terminó, pero expiró la confirmación de envío. Inténtalo de nuevo.';

  @override
  String get attachmentTransferUnavailable => 'No se pudo transferir el adjunto ahora. Revisa internet/servidor e inténtalo de nuevo.';

  @override
  String get attachmentSendUnavailable => 'El envío de adjuntos aún no está listo. Inténtalo de nuevo.';

  @override
  String get attachmentContactSyncPending => 'Esperando la sincronización de identidad del contacto. Pídele al contacto que envíe un mensaje más e inténtalo de nuevo.';

  @override
  String get attachmentContactBlocked => 'Este contacto está bloqueado.';

  @override
  String get attachmentRecipientNotFound => 'No se encontró el perfil del destinatario en este servidor. Revisa el Secretly ID y asegúrate de que ambos dispositivos usen el mismo servidor.';

  @override
  String get attachmentRecipientNoDevices => 'El destinatario aún no tiene dispositivos registrados. Pídele que abra Secretly e inténtalo de nuevo.';

  @override
  String get attachmentNoDeliverableDevices => 'No se pudo entregar el adjunto a ningún dispositivo del destinatario. Inténtalo de nuevo.';

  @override
  String get attachmentActionGeneric => 'No se pudo enviar el adjunto. Inténtalo de nuevo.';

  @override
  String get send => 'Enviar';

  @override
  String get attach => 'Adjuntar';

  @override
  String get photo => 'Foto';

  @override
  String get video => 'Video';

  @override
  String get file => 'Archivo';

  @override
  String get music => 'Música';

  @override
  String get attachment => 'Adjunto';

  @override
  String get downloading => 'Descargando…';

  @override
  String downloadFailed(Object error) {
    return 'Falló la descarga: $error';
  }

  @override
  String savedTo(Object path) {
    return 'Guardado en: $path';
  }

  @override
  String get noMessagesYet => 'Aún no hay mensajes';

  @override
  String get decrypting => 'Descifrando…';

  @override
  String get uploading => 'Subiendo…';

  @override
  String get uploadTimedOut => 'La carga agotó el tiempo de espera. Revisa internet/servidor e inténtalo de nuevo.';

  @override
  String uploadingBytes(Object sent, Object total) {
    return 'Subidos $sent / $total bytes';
  }

  @override
  String get requestsInfo => 'Este chat está en Solicitudes. Acepta para responder o bloquea para ignorarlo.';

  @override
  String get verifyRequired => 'Verificación requerida';

  @override
  String get verifyContact => 'Verificar contacto';

  @override
  String get muteNotifications => 'Silenciar notificaciones';

  @override
  String get unmuteNotifications => 'Activar notificaciones';

  @override
  String get setContactPhoto => 'Establecer foto del contacto';

  @override
  String get removeContactPhoto => 'Eliminar foto del contacto';

  @override
  String get blockUser => 'Bloquear usuario';

  @override
  String get unblockUser => 'Desbloquear usuario';

  @override
  String get deleteChat => 'Eliminar chat';

  @override
  String get missingRecipient => 'Falta el destinatario';

  @override
  String get contactNotVerified => 'El código de seguridad cambió. Compruébalo para seguir escribiendo.';

  @override
  String get safetyNumberChangedTitle => 'El código de seguridad cambió';

  @override
  String get safetyNumberChangedBody => 'Ya habías comprobado el código de este contacto. Ahora sus claves son nuevas: suele ocurrir tras reinstalar la app o cambiar de teléfono. El chat sigue cifrado en cualquier caso. Compara el código otra vez si quieres asegurarte de que sigue siendo esa persona.';

  @override
  String get safetyNumberStrictBody => 'Tienes activado «Bloquear envío a no verificados». Compara el código de este contacto para enviarle mensajes.';

  @override
  String get sendAnyway => 'Enviar de todos modos';

  @override
  String get alsoDeleteChat => 'Eliminar también el chat';

  @override
  String get unblockUserConfirmTitle => '¿Desbloquear usuario?';

  @override
  String get blockUserConfirmTitle => '¿Bloquear usuario?';

  @override
  String get deleteChatConfirmTitle => '¿Eliminar chat?';

  @override
  String get deleteChatConfirmBody => 'Esto elimina el chat solo de este dispositivo.';

  @override
  String attachFailed(Object error) {
    return 'No se pudo adjuntar: $error';
  }

  @override
  String sendFailed(Object error) {
    return 'No se pudo enviar: $error';
  }

  @override
  String actionFailed(Object error) {
    return 'La acción falló: $error';
  }

  @override
  String get roomPolicyNotMember => 'Ya no participas en esta sala.';

  @override
  String get roomPolicyAdminsOnly => 'Solo propietarios y administradores de la sala pueden hacer eso.';

  @override
  String get roomPolicyTextMessagesDisabled => 'Tu rol no puede enviar mensajes de texto en esta sala.';

  @override
  String get roomPolicyMediaDisabled => 'Tu rol no puede enviar contenido multimedia en esta sala.';

  @override
  String get roomPolicyReactionsDisabled => 'Las reacciones están desactivadas en esta sala.';

  @override
  String get roomPolicyReactionNotAllowed => 'Esta reacción no está permitida en esta sala.';

  @override
  String get roomPolicyPinDenied => 'Solo los administradores pueden fijar mensajes en esta sala.';

  @override
  String get roomPolicyAddMembersDenied => 'Solo los administradores pueden añadir participantes a esta sala.';

  @override
  String get roomPolicyChangeInfoDenied => 'Solo los administradores pueden cambiar el perfil del grupo.';

  @override
  String roomPolicySlowMode(Object seconds) {
    return 'El modo lento está activado. Inténtalo de nuevo en $seconds s.';
  }

  @override
  String get noMatches => 'No hay coincidencias';

  @override
  String attachmentTooLarge(Object mb) {
    return 'El adjunto es demasiado grande ($mb MB).';
  }

  @override
  String get attachmentFileMissing => 'El archivo ya no está disponible.';

  @override
  String foundPrefix(Object hit) {
    return 'Encontrado: $hit';
  }

  @override
  String get contactDetailsChat => 'Chat';

  @override
  String get contactDetailsSound => 'Sonido';

  @override
  String get contactDetailsCall => 'Llamada';

  @override
  String get contactDetailsVideo => 'Video';

  @override
  String get contactDetailsUsernameLabel => 'Nombre de usuario';

  @override
  String get contactDetailsAddToContacts => 'Añadir a contactos';

  @override
  String get contactDetailsMediaTab => 'Multimedia';

  @override
  String get contactDetailsFilesTab => 'Archivos';

  @override
  String get contactDetailsNoMedia => 'No hay multimedia';

  @override
  String get contactDetailsNoFiles => 'No hay archivos';

  @override
  String get contactDetailsStatusRecently => 'visto recientemente';

  @override
  String contactDetailsStatusAt(Object time) {
    return 'visto a las $time';
  }

  @override
  String get contactDetailsAutoDelete => 'Eliminación automática';

  @override
  String get contactDetailsShareContact => 'Compartir contacto';

  @override
  String get contactDetailsEditContact => 'Editar contacto';

  @override
  String get contactDetailsDeleteContact => 'Eliminar contacto';

  @override
  String get contactDetailsSendGift => 'Enviar regalo';

  @override
  String get contactDetailsStartSecretChat => 'Iniciar chat secreto';

  @override
  String get contactDetailsCreateShortcut => 'Crear acceso directo';

  @override
  String get contactDetailsNameLabel => 'Nombre';

  @override
  String get contactDetailsSave => 'Guardar';

  @override
  String get contactDetailsDeleteConfirmTitle => '¿Eliminar contacto?';

  @override
  String get contactAutoDeleteOff => 'Desactivado';

  @override
  String get contactAutoDelete1Day => '24 horas';

  @override
  String get contactAutoDelete7Days => '7 días';

  @override
  String get contactAutoDelete30Days => '30 días';

  @override
  String get contactEditTitle => 'Editar contacto';

  @override
  String get contactEditDone => 'LISTO';

  @override
  String get contactEditNameLabel => 'Nombre';

  @override
  String get contactEditAssignEmoji => 'Asignar emoji';

  @override
  String get contactEditClearEmoji => 'Borrar emoji';

  @override
  String get contactEditSetPhoto => 'Establecer foto';

  @override
  String get chatMenuReply => 'Responder';

  @override
  String get chatMenuCopy => 'Copiar';

  @override
  String get chatMenuForward => 'Reenviar';

  @override
  String get chatMenuPin => 'Fijar';

  @override
  String get chatMenuDelete => 'Eliminar';

  @override
  String get reset => 'Restablecer';

  @override
  String get diagnostics => 'Diagnóstico';

  @override
  String get diagnosticsSubtitle => 'Estado, vinculación, marcas de tiempo';

  @override
  String get sendLater => 'Enviar más tarde';

  @override
  String get sendSilently => 'Enviar sin sonido';

  @override
  String scheduledSendToday(Object time) {
    return 'Enviar hoy a las $time';
  }

  @override
  String scheduledSendOn(Object date, Object time) {
    return 'Enviar el $date a las $time';
  }

  @override
  String get repeatNever => 'Nunca';

  @override
  String get repeat => 'Repetir';

  @override
  String get onboardingBackTooltip => 'Atrás';

  @override
  String get onboardingWelcomeTitle => '¡Bienvenido!';

  @override
  String get onboardingWelcomeSubtitle => 'Un mensajero de nueva generación.\nPrivacidad total. Sin concesiones.';

  @override
  String get onboardingCreateAccount => 'Crear cuenta nueva';

  @override
  String get onboardingAlreadyHaveAccount => 'Ya tengo una cuenta';

  @override
  String get onboardingFeatureE2eTitle => 'Cifrado E2E';

  @override
  String get onboardingFeatureE2eBody => 'Los mensajes se cifran en tu dispositivo. Solo tú tienes las claves.';

  @override
  String get onboardingFeaturePrivacyTitle => 'Anonimato completo';

  @override
  String get onboardingFeaturePrivacyBody => 'Sin número de teléfono. Sin vinculación a datos personales.';

  @override
  String get onboardingFeatureRelayTitle => 'Sin intermediarios';

  @override
  String get onboardingFeatureRelayBody => 'El servidor relay no guarda mensajes. Solo los transmite.';

  @override
  String get onboardingProfileTitle => 'Tu perfil';

  @override
  String get onboardingProfileSubtitle => 'Cómo te verán otros usuarios';

  @override
  String get onboardingProfileNameSection => 'Nombre del perfil';

  @override
  String get onboardingProfileNameHint => 'Tu nombre o seudónimo';

  @override
  String get onboardingNotificationsSection => 'Notificaciones';

  @override
  String get onboardingMessageNotificationsTitle => 'Notificaciones de mensajes';

  @override
  String get onboardingMessageNotificationsSubtitle => 'Recibir notificaciones push de Secretly';

  @override
  String get onboardingIncomingCallsTitle => 'Llamadas entrantes';

  @override
  String get onboardingIncomingCallsSubtitle => 'Aceptar llamadas de contactos';

  @override
  String get continueAction => 'Continuar';

  @override
  String get onboardingBackupSaveFailed => 'No se pudieron guardar los ajustes de copia de seguridad';

  @override
  String get backupPasswordRequirements => 'Usa al menos 8 caracteres ASCII, una letra mayúscula y un carácter especial. Sin espacios al inicio ni al final.';

  @override
  String backupPasswordTooShort(Object minLength) {
    return 'La contraseña debe tener al menos $minLength caracteres.';
  }

  @override
  String backupPasswordTooLong(Object maxLength) {
    return 'La contraseña no debe superar $maxLength caracteres.';
  }

  @override
  String get backupPasswordNonAscii => 'Usa solo letras latinas, dígitos y símbolos ASCII.';

  @override
  String get backupPasswordOuterWhitespace => 'Quita los espacios al inicio o al final de la contraseña.';

  @override
  String get backupPasswordMissingUppercase => 'Añade al menos una letra mayúscula A-Z.';

  @override
  String get backupPasswordMissingSpecial => 'Añade al menos un carácter especial, como !, # o ?.';

  @override
  String get onboardingBackupPasswordTitle => 'Contraseña de la copia de seguridad';

  @override
  String get onboardingPasswordsDoNotMatch => 'Las contraseñas no coinciden';

  @override
  String get onboardingBackupTitle => 'Copias de seguridad';

  @override
  String get onboardingBackupSubtitle => 'Protege tus chats contra la pérdida de datos.\nIncluso al cambiar de dispositivo.';

  @override
  String get onboardingAutoBackupSection => 'Copia automática';

  @override
  String get onboardingAutoBackupTitle => 'Copia automática';

  @override
  String get onboardingAutoBackupSubtitle => 'Guardar automáticamente una copia de seguridad';

  @override
  String get onboardingStorageTypeSection => 'Tipo de almacenamiento';

  @override
  String get onboardingBackupMediaTitle => 'Incluir multimedia';

  @override
  String get onboardingBackupMediaSubtitle => 'Fotos, videos, archivos y avatares se incluyen solo en copias locales';

  @override
  String get onboardingFrequencySection => 'Frecuencia';

  @override
  String get onboardingEnterSecretly => 'Entrar en Secretly';

  @override
  String get onboardingSkipBackup => 'Omitir configuración de copia';

  @override
  String get onboardingSecretlyIdCopied => 'Secretly ID copiado';

  @override
  String get onboardingRegistrationCompleteTitle => 'Registro completado';

  @override
  String get onboardingRegistrationCompleteSubtitle => 'Guarda ahora tu Secretly ID. Lo necesitarás para restaurar tu cuenta y la copia de seguridad en un dispositivo nuevo.';

  @override
  String get onboardingYourSecretlyId => 'Tu Secretly ID';

  @override
  String get onboardingCopyId => 'Copiar ID';

  @override
  String get onboardingRecoveryWarning => 'Sin tu Secretly ID y la contraseña de la copia, no será posible restaurar la copia del servidor. Guarda el ID en un lugar seguro y no olvides la contraseña.';

  @override
  String get onboardingStorageCloud => 'Nube';

  @override
  String get onboardingStorageCloudSubtitle => 'En el servidor de Secretly';

  @override
  String get onboardingStorageLocal => 'Local';

  @override
  String get onboardingStorageLocalSubtitle => 'En este dispositivo';

  @override
  String get onboardingInterval6Hours => '6 horas';

  @override
  String get onboardingInterval12Hours => '12 horas';

  @override
  String get onboardingIntervalEveryDay => 'Cada día';

  @override
  String get onboardingIntervalEvery3Days => 'Cada 3 días';

  @override
  String get onboardingIntervalWeekly => 'Una vez por semana';

  @override
  String get onboardingBackupLocalCandidate => 'Copia local de Secretly';

  @override
  String get onboardingDownloads => 'Descargas';

  @override
  String get onboardingDeviceFolder => 'Carpeta del dispositivo';

  @override
  String get onboardingNoBackupsFound => 'No se encontraron copias en este dispositivo';

  @override
  String get onboardingFoundBackups => 'Copias encontradas';

  @override
  String get onboardingNoBackupsFoundBody => 'Secretly revisó las copias locales de la app y la carpeta Descargas. Si el archivo está en otro lugar, elígelo manualmente.';

  @override
  String get chooseManually => 'Elegir manualmente';

  @override
  String get onboardingChooseBackupFileTitle => 'Elige un archivo de copia de Secretly';

  @override
  String get onboardingReadBackupFailed => 'No se pudo leer el archivo de copia';

  @override
  String get onboardingServerBackupNotFound => 'No se encontró una copia en el servidor';

  @override
  String get onboardingRestoreThisBackupTitle => '¿Restaurar esta copia?';

  @override
  String get onboardingRestoreThisBackupBody => 'Los datos locales actuales de este dispositivo serán reemplazados.';

  @override
  String onboardingSecretlyIdSummary(Object profileId) {
    return 'Secretly ID: $profileId';
  }

  @override
  String onboardingContactsSummary(Object count) {
    return 'Contactos: $count';
  }

  @override
  String onboardingMessagesSummary(Object count) {
    return 'Mensajes: $count';
  }

  @override
  String onboardingChatsSummary(Object count) {
    return 'Chats: $count';
  }

  @override
  String onboardingMediaFilesSummary(Object count) {
    return 'Archivos multimedia: $count';
  }

  @override
  String get onboardingBrokenBackup => 'Archivo de copia dañado o no válido';

  @override
  String get onboardingRestoreFailed => 'La restauración falló. Inténtalo de nuevo.';

  @override
  String get onboardingRestoreLoginTitle => 'Iniciar sesión en tu cuenta';

  @override
  String get onboardingRestoreLoginSubtitle => 'Restaura chats y ajustes\ndesde una copia creada anteriormente.';

  @override
  String get onboardingRestoreMediaSubtitle => 'Para futuras copias locales: fotos, videos, archivos y avatares se añadirán solo si esto está activado.';

  @override
  String get onboardingRestoreFromCloudTitle => 'Desde la nube de Secretly';

  @override
  String get onboardingRestoreFromCloudSubtitle => 'Introduce tu Secretly ID y la contraseña de copia; los datos se descargarán del servidor';

  @override
  String get onboardingRestoreFromDeviceTitle => 'Buscar copia en este dispositivo';

  @override
  String get onboardingRestoreFromDeviceSubtitle => 'Secretly revisará automáticamente las copias locales y Descargas';

  @override
  String get onboardingRestoring => 'Restaurando...';

  @override
  String get onboardingRestoreFromServerTitle => 'Restaurar desde servidor';

  @override
  String get callRecordOutgoingVideoCall => 'Videollamada saliente';

  @override
  String get callRecordOutgoingCall => 'Llamada saliente';

  @override
  String get callRecordIncomingVideoCall => 'Videollamada entrante';

  @override
  String get callRecordIncomingCall => 'Llamada entrante';

  @override
  String get callRecordMissedCall => 'Llamada perdida';

  @override
  String get callRecordDeclinedCall => 'Llamada rechazada';

  @override
  String get callRecordBusy => 'Ocupado';

  @override
  String get callRecordFailed => 'Error de llamada';

  @override
  String get callRecordCanceled => 'Llamada cancelada';

  @override
  String get callRecordOngoing => 'Llamada en curso';

  @override
  String get safeBackupInvalidBackup => 'Copia de seguridad de Secretly no válida';

  @override
  String get recoveryKitPrepareFailed => 'No se pudo preparar un Recovery Kit en este dispositivo.';

  @override
  String safeBackupPreviewProfileId(String profileId) {
    return 'ID de Secretly: $profileId';
  }

  @override
  String safeBackupPreviewContacts(int count) {
    return 'Contactos: $count';
  }

  @override
  String safeBackupPreviewServer(String server) {
    return 'Servidor: $server';
  }

  @override
  String get safeBackupPreviewTitle => 'Vista previa de la copia:';

  @override
  String get safeBackupSavedToFiles => 'Copia guardada en Secretly Files';

  @override
  String get safeBackupExportCanceled => 'Exportación de copia cancelada';

  @override
  String safeBackupExportFailed(Object error) {
    return 'No se pudo exportar la copia: $error';
  }

  @override
  String get safeBackupCreateDialogTitle => 'Crear copia';

  @override
  String get safeBackupServerDestination => 'Copia en servidor';

  @override
  String get safeBackupLocalDestination => 'Copia local';

  @override
  String get safeBackupRestoreDialogTitle => 'Restaurar copia';

  @override
  String get safeBackupRestoreFromDevice => 'Restaurar desde el dispositivo';

  @override
  String get safeBackupDownloadsLocation => 'Descargas';

  @override
  String get safeBackupDeviceFolderLocation => 'Carpeta del dispositivo';

  @override
  String get safeBackupChooseManualHint => 'Secretly comprobó automáticamente las copias locales de la app y Descargas. Si el archivo está en otro lugar, puedes elegirlo manualmente.';

  @override
  String get safeBackupChooseManually => 'Elegir manualmente';

  @override
  String safeBackupReadFileFailed(Object error) {
    return 'No se pudo leer el archivo de copia: $error';
  }

  @override
  String get safeBackupFrequencyTitle => 'Frecuencia de guardado';

  @override
  String get saveAction => 'Guardar';

  @override
  String get safeBackupEnableAutoTitle => 'Activar copia automática';

  @override
  String get safeBackupEnableAutoSubtitle => 'Se ejecuta en la app cuando hay conexión; se cifra con tu contraseña';

  @override
  String get safeBackupUploadToServer => 'Subir al servidor';

  @override
  String get safeBackupSaveOnDevice => 'Guardar en este dispositivo';

  @override
  String get safeBackupPasswordConfigured => 'Contraseña de copia automática: configurada';

  @override
  String get safeBackupPasswordNotSet => 'Contraseña de copia automática: no definida';

  @override
  String get safeBackupPasswordSaved => 'Contraseña de copia automática guardada';

  @override
  String genericFailed(Object error) {
    return 'Error: $error';
  }

  @override
  String get safeBackupSetPassword => 'Definir contraseña';

  @override
  String get safeBackupPasswordRemoved => 'Contraseña de copia automática eliminada';

  @override
  String get safeBackupClearPassword => 'Borrar contraseña';

  @override
  String get safeBackupRunRequested => 'Copia automática iniciada';

  @override
  String get safeBackupRunNow => 'Ejecutar copia automática ahora';

  @override
  String safeBackupLastAutoBackup(String time) {
    return 'Última copia automática: $time';
  }

  @override
  String get safeBackupLastAutoBackupNever => 'Última copia automática: nunca';

  @override
  String safeBackupLastDeviceBackup(String time) {
    return 'Última copia del dispositivo: $time';
  }

  @override
  String safeBackupLastAutoBackupError(Object error) {
    return 'Error de copia automática: $error';
  }

  @override
  String get securityScopeAppObject => 'la app';

  @override
  String get securityScopePersonalObject => 'chats personales';

  @override
  String get securityUnlockAppTitle => 'Desbloquea la app';

  @override
  String get securityUnlockPersonalTitle => 'Desbloquea los chats personales';

  @override
  String get securityUnlockFingerprintAutoSubtitle => 'El desbloqueo con huella se inicia automáticamente. Si hace falta, puedes usar tu contraseña abajo.';

  @override
  String get securityUnlockBiometricPatternAutoSubtitle => 'La biometría nativa se inicia primero automáticamente. Si hace falta, puedes usar tu patrón abajo.';

  @override
  String get securityUnlockNativeSubtitle => 'Confirma el acceso con la autenticación nativa del dispositivo.';

  @override
  String securityUnlockPasswordSubtitle(String scopeName) {
    return 'Introduce tu contraseña para abrir $scopeName.';
  }

  @override
  String securityUnlockPatternSubtitle(String scopeName) {
    return 'Dibuja tu patrón para acceder a $scopeName.';
  }

  @override
  String get securityUnlockBiometricSubtitle => 'Confirma tu identidad con la autenticación nativa del dispositivo.';

  @override
  String get securityUnlockAppBiometricReason => 'Autentícate para desbloquear la app';

  @override
  String get securityUnlockPersonalBiometricReason => 'Autentícate para abrir los chats personales';

  @override
  String get securityUnlockPasswordMismatch => 'La contraseña no coincide. Inténtalo de nuevo.';

  @override
  String get securityUnlockPatternMismatch => 'El patrón no coincide.';

  @override
  String get securityUnlockNativeIncomplete => 'La autenticación nativa no se completó.';

  @override
  String get securityPasswordContinueHint => 'Introduce tu contraseña para continuar';

  @override
  String get securityUseFingerprint => 'Usar huella';

  @override
  String get securityUsePassword => 'Usar contraseña';

  @override
  String get securityClearPattern => 'Borrar patrón';

  @override
  String get securityConnectFourDots => 'Conecta al menos 4 puntos.';

  @override
  String get securityPasswordMinFourChars => 'Usa al menos 4 caracteres.';

  @override
  String get securityPasswordsMismatchFull => 'Las contraseñas no coinciden.';

  @override
  String securityPasswordSetupTitle(String scopeName) {
    return 'Contraseña para $scopeName';
  }

  @override
  String get securityPasswordSetupDescription => 'La contraseña se guarda solo en el almacén seguro del dispositivo.';

  @override
  String get securityNewPassword => 'Nueva contraseña';

  @override
  String get securityRepeatPassword => 'Repite la contraseña';

  @override
  String get securitySavePassword => 'Guardar contraseña';

  @override
  String get securityPatternSetupInstruction => 'Dibuja un patrón con al menos 4 puntos.';

  @override
  String get securityPatternSetupRepeat => 'Repite el patrón para confirmarlo.';

  @override
  String get securityPatternMinFourDots => 'Usa al menos 4 puntos.';

  @override
  String get securityPatternMismatchStartOver => 'Los patrones no coinciden. Empieza de nuevo.';

  @override
  String securityPatternSetupTitle(String scopeName) {
    return 'Patrón para $scopeName';
  }

  @override
  String get securityStartOver => 'Empezar de nuevo';

  @override
  String get securityTitle => 'Seguridad';

  @override
  String get securityNativeAuthentication => 'Autenticación nativa';

  @override
  String get securityReady => 'Listo';

  @override
  String get securityUnavailable => 'No disponible';

  @override
  String get securityNativeAvailableDescription => 'Se usa para Face ID, huella y autenticación nativa del dispositivo.';

  @override
  String get securityNativeUnavailableDescription => 'La biometría o autenticación nativa no está disponible en este dispositivo ahora mismo.';

  @override
  String get securityAppLockTitle => 'Bloqueo de la app';

  @override
  String get securityAppLockDescription => 'Protege la entrada a la app y puede volver a bloquearla cuando se oculta.';

  @override
  String get securityPersonalChatsTitle => 'Chats personales';

  @override
  String get securityPersonalChatsDescription => 'Protege la sección Personal oculta y la entrada directa a chats personales.';

  @override
  String get securityAuthEnableAppLockReason => 'Autentícate para activar el bloqueo de la app';

  @override
  String get securityAuthChangeSettingsReason => 'Autentícate para cambiar la configuración de seguridad';

  @override
  String get securityAuthProtectPersonalReason => 'Autentícate para proteger los chats personales';

  @override
  String get securityAuthChangePersonalReason => 'Autentícate para cambiar la protección de chats personales';

  @override
  String get securityNativeUnavailableError => 'La autenticación nativa no está disponible en este dispositivo.';

  @override
  String get securityBiometricCancelled => 'Se canceló la confirmación biométrica.';

  @override
  String get securityProtectionMode => 'Modo de protección';

  @override
  String get securityProtectionModeSubtitle => 'Elige cómo se debe proteger el acceso.';

  @override
  String get securityProtectionModeDescription => 'Las contraseñas y patrones se guardan solo como hashes fuertes en secure storage. La biometría usa el aviso nativo del sistema.';

  @override
  String get securityProtectionOff => 'Desactivado';

  @override
  String get securityProtectionOffDescription => 'Acceso sin protección adicional.';

  @override
  String get securityPasswordModeDescription => 'Una contraseña dedicada para desbloquear el acceso.';

  @override
  String get securityPatternModeTitle => 'Patrón';

  @override
  String get securityPatternModeDescription => 'Un patrón de puntos similar al bloqueo de Android.';

  @override
  String get securityNativePromptDescription => 'El aviso nativo de Face ID, huella o autenticación del sistema del dispositivo.';

  @override
  String get securityRelockAfterHidden => 'Volver a bloquear al ocultar la app';

  @override
  String get securityRelockAfterHiddenDescription => 'Si está desactivado, la protección solo vuelve tras reiniciar completamente la app.';

  @override
  String get securityGracePeriod => 'Periodo de espera antes de bloquear';

  @override
  String get securityGraceUnavailable => 'No disponible mientras el bloqueo en segundo plano esté desactivado.';

  @override
  String securityAllowQuickUnlockWith(String method) {
    return 'Permitir desbloqueo rápido con $method';
  }

  @override
  String get securityQuickUnlockSubtitle => 'Mantiene la contraseña o el patrón como método principal de respaldo.';

  @override
  String get securityChangePassword => 'Cambiar contraseña';

  @override
  String get securityChangePattern => 'Cambiar patrón';

  @override
  String get securityChangeCredentialSubtitle => 'La protección actual se actualizará en cuanto se confirme el nuevo secreto.';

  @override
  String get securityProtectionActivated => 'La protección se activó inmediatamente.';

  @override
  String get securityLockNow => 'Bloquear ahora';

  @override
  String get securitySaveChanges => 'Guardar cambios';

  @override
  String get securityGraceImmediately => 'Inmediatamente';

  @override
  String securityGraceAfterSeconds(int seconds) {
    return 'Después de $seconds s';
  }

  @override
  String securityGraceAfterMinutes(int minutes) {
    return 'Después de $minutes min';
  }

  @override
  String get securityStatusLocked => 'Bloqueado';

  @override
  String get securityStatusUnlocked => 'Desbloqueado';

  @override
  String get securityAfterHide => 'Al ocultar';

  @override
  String securityGracePill(int seconds) {
    return 'Espera $seconds s';
  }

  @override
  String get securityNoProtection => 'Sin protección';

  @override
  String get securityNativeBiometrics => 'Biometría nativa';

  @override
  String get securityBiometricFaceFingerprint => 'Face ID / huella';

  @override
  String get securityBiometricFingerprint => 'Huella';

  @override
  String get securityBiometricNativeDeviceAuthentication => 'Autenticación nativa del dispositivo';

  @override
  String get devicesLinkOpenFailed => 'No se pudo abrir el enlace en un navegador.';

  @override
  String get devicesDesktopDescriptionPrefix => 'Puedes iniciar sesión en la ';

  @override
  String get devicesDesktopAppLink => 'app de Secretly para escritorio';

  @override
  String get devicesDesktopDescriptionSuffix => ' usando un código QR.';

  @override
  String get devicesFailureTransportBlocked => 'El transporte está bloqueado para el servidor actual. Usa el mismo servidor en el teléfono y el escritorio e inténtalo de nuevo.';

  @override
  String get devicesFailureIdentityNotServerBacked => 'La identidad de escritorio aún no está respaldada por el servidor. Reinténtalo en unos segundos.';

  @override
  String get devicesFailureProfileUnavailable => 'El perfil de escritorio aún no aparece en el servidor. Mantén la app abierta e inténtalo de nuevo.';

  @override
  String get devicesFailureDeviceUnavailable => 'El dispositivo de escritorio aún no aparece en el servidor. Mantén la app abierta, actualiza el QR e inténtalo de nuevo.';

  @override
  String get devicesFailureCompanionRequired => 'El acceso companion de escritorio no está activado para este perfil. Actívalo en el teléfono principal e inténtalo de nuevo.';

  @override
  String get devicesFailureCompanionLimit => 'El límite de dispositivos de escritorio ya está en uso para este perfil. Elimina un dispositivo antiguo o aumenta los cupos disponibles.';

  @override
  String get devicesFailurePrimaryRequired => 'Primero crea la cuenta principal en un teléfono y luego enlaza el escritorio con QR.';

  @override
  String get devicesFailureInvalidQr => 'Este QR no es un código de autorización de dispositivo.';

  @override
  String get devicesFailureQrExpired => 'El código QR caducó. Genera uno nuevo en el escritorio.';

  @override
  String get devicesFailureServerMismatch => 'Este QR pertenece a otro servidor. Usa el mismo servidor en el teléfono y el escritorio e inténtalo de nuevo.';

  @override
  String get devicesFailureProfileMismatch => 'El paquete de sincronización apunta a otro perfil. Genera un QR nuevo e inténtalo de nuevo.';

  @override
  String get devicesFailureRequestNotFound => 'La solicitud de sincronización de escritorio no se encontró o ya caducó. Genera un QR nuevo.';

  @override
  String get devicesFailureSessionExpired => 'La sesión QR caducó. Genera un QR nuevo e inténtalo de nuevo.';

  @override
  String get devicesFailureSessionValidation => 'Falló la validación de la sesión QR. Genera un QR nuevo e inténtalo de nuevo.';

  @override
  String get devicesFailureStateMismatch => 'El estado de la solicitud de sincronización ya no coincide. Genera un QR nuevo e inténtalo de nuevo.';

  @override
  String get devicesFailureDeviceMismatch => 'El paquete de sincronización apunta a otro dispositivo. Genera un QR nuevo e inténtalo de nuevo.';

  @override
  String get devicesFailureDeclined => 'El inicio de sesión fue rechazado en el teléfono principal. Genera un QR nuevo para reintentarlo.';

  @override
  String get devicesFailureInvalidPayload => 'Paquete de sincronización de escritorio no válido. Genera un QR nuevo e inténtalo de nuevo.';

  @override
  String get devicesFailureInterrupted => 'La sincronización segura se interrumpió antes de completarse. Genera un QR nuevo e inténtalo de nuevo.';

  @override
  String get devicesNewUser => 'Nuevo usuario';

  @override
  String get devicesNewUserDesktopConfirm => '¿Borrar los datos locales y preparar este dispositivo de escritorio para iniciar sesión por QR desde el teléfono principal?';

  @override
  String get devicesNewUserMobileConfirm => '¿Borrar el perfil local actual y registrar un nuevo usuario en este dispositivo?';

  @override
  String get devicesCreateAction => 'Crear';

  @override
  String get devicesScanDeviceQr => 'Escanear QR del dispositivo';

  @override
  String get devicesRequestApproved => 'Solicitud aprobada. Paquete de sincronización enviado al escritorio.';

  @override
  String get devicesRequestDeclined => 'Solicitud rechazada. El escritorio seguirá sin autenticar.';

  @override
  String get devicesApproveSignInTitle => '¿Aprobar inicio de sesión en este dispositivo?';

  @override
  String get devicesConfirmSyncPrimary => 'Confirma la sincronización desde el dispositivo principal (teléfono).';

  @override
  String devicesApprovalDeviceOnly(String name) {
    return 'Dispositivo: $name. La aprobación solo se permite desde el teléfono principal.';
  }

  @override
  String get devicesSyncChats => 'Sincronizar chats';

  @override
  String get devicesSyncSettings => 'Sincronizar ajustes';

  @override
  String get devicesSyncMedia => 'Sincronizar medios';

  @override
  String get devicesDeclineSignIn => 'Rechazar inicio';

  @override
  String get devicesApprove => 'Aprobar';

  @override
  String get devicesTitle => 'Dispositivos';

  @override
  String get devicesConnectDevice => 'Conectar dispositivo';

  @override
  String get devicesPrimaryDeviceTitle => 'Este es el dispositivo principal';

  @override
  String get devicesPrimaryDeviceSubtitle => 'El permiso para sincronizar chats, ajustes y medios solo se concede aquí.';

  @override
  String get devicesQrSessionExpiredNewCode => 'La sesión QR caducó. Genera un código nuevo.';

  @override
  String devicesQrExpiresIn(String time) {
    return 'El QR caduca en $time';
  }

  @override
  String get devicesWaitingQrScan => 'Esperando escaneo QR en el teléfono.';

  @override
  String get devicesQrScannedConfirm => 'QR escaneado. Confirma el inicio en el teléfono.';

  @override
  String get devicesApplyingSecureBundle => 'Aplicando paquete de sincronización segura…';

  @override
  String get devicesAuthorizationFailed => 'Error de autorización. Inténtalo de nuevo.';

  @override
  String get devicesUnauthenticatedChooseAction => 'No estás autenticado. Elige una acción abajo.';

  @override
  String get devicesAuthenticated => 'Dispositivo autenticado.';

  @override
  String get devicesDesktopWebAuthorization => 'Autorización Desktop/Web';

  @override
  String get devicesDesktopModeDescription => 'Elige modo: registrar un nuevo usuario o entrar por QR con aprobación del teléfono.';

  @override
  String get devicesCancelQr => 'Cancelar QR';

  @override
  String get devicesRefreshQr => 'Actualizar QR';

  @override
  String get devicesSignInViaQr => 'Entrar por QR';

  @override
  String get devicesOpenPrimaryInstruction => 'Abre Secretly en el teléfono principal → Ajustes → Dispositivos → Conectar dispositivo.';

  @override
  String get storageSection => 'Almacenamiento';

  @override
  String get storageSectionSubtitle => 'Caché y descargas en este dispositivo';

  @override
  String get storageUsageTitle => 'Uso de almacenamiento';

  @override
  String get storageCategoryMedia => 'Caché de medios';

  @override
  String get storageCategoryVoiceTranscripts => 'Transcripciones de voz';

  @override
  String get storageCategoryVoiceModel => 'Modelo de voz sin conexión';

  @override
  String get storageCategoryStickers => 'Stickers';

  @override
  String get storageCategoryEmoji => 'Emojis animados';

  @override
  String get storageCategoryProfileMedia => 'Mi galería y avatares';

  @override
  String get storageCategoryRecents => 'Archivos recientes';

  @override
  String get storageTotal => 'Total';

  @override
  String get storageCalculating => 'Calculando…';

  @override
  String get storageClearCache => 'Borrar caché';

  @override
  String get storageClearCacheHint => 'Elimina los medios en caché, los avatares de contactos y los emojis animados. Tu galería, stickers y chats se conservan; los medios se vuelven a descargar al verlos.';

  @override
  String get storageClearing => 'Borrando caché…';

  @override
  String get storageClearedToast => 'Caché borrada';

  @override
  String get storageRemoveVoiceModel => 'Eliminar el modelo de voz sin conexión (140 MB)';

  @override
  String get storageRemoveVoiceModelHint => 'Libera el modelo de reconocimiento de voz del dispositivo. Se vuelve a descargar automáticamente la próxima vez que transcribas un mensaje de voz.';

  @override
  String get storageRemoveVoiceModelConfirmTitle => '¿Eliminar el modelo de voz?';

  @override
  String get storageRemoveVoiceModelConfirmBody => 'El modelo de reconocimiento de voz de 140 MB se eliminará del dispositivo. Se vuelve a descargar automáticamente la próxima vez que transcribas un mensaje de voz.';

  @override
  String get storageRemoveVoiceModelConfirm => 'Eliminar';

  @override
  String get storageVoiceModelNotInstalled => 'No hay ningún modelo de voz instalado';

  @override
  String get storageVoiceModelRemovedToast => 'Modelo de voz eliminado';

  @override
  String get backupStateProtected => 'Tu historial está protegido';

  @override
  String get backupStateUnprotected => 'Tu historial no está protegido';

  @override
  String get backupStateFailing => 'Las copias están fallando';

  @override
  String get backupStateStale => 'La copia está desactualizada';

  @override
  String get backupStateNone => 'Aún no hay copia';

  @override
  String backupLastAt(Object time) {
    return 'Última copia: $time';
  }

  @override
  String get backupIntroHint => 'Una copia te permite llevar tus chats a un dispositivo nuevo';

  @override
  String get backupAccessUpgradeTitle => 'Vuelve a guardar la copia';

  @override
  String get backupAccessUpgradeBody => 'Tu copia en el servidor se creó con el formato antiguo: puede descargarla quien conozca el identificador del perfil. El contenido sigue cifrado con tu contraseña, pero una segunda barrera no sobra. Volver a guardarla añade una comprobación de contraseña en el propio servidor.';

  @override
  String get backupAccessUpgradeAction => 'Volver a guardar';

  @override
  String get backupSectionAutomatic => 'Automático';

  @override
  String get backupAutoToggle => 'Copiar automáticamente';

  @override
  String get backupPassword => 'Contraseña';

  @override
  String get backupPasswordSet => 'Definida';

  @override
  String get backupPasswordNotSet => 'Sin definir';

  @override
  String get backupPasswordSaved => 'Contraseña guardada';

  @override
  String get backupWhere => 'Dónde';

  @override
  String get backupHowOften => 'Con qué frecuencia';

  @override
  String get backupIncludeMedia => 'Incluir multimedia';

  @override
  String get backupAutoFooter => 'La copia está cifrada con tu contraseña. Sin ella no se puede restaurar nada: guárdala en un lugar seguro. Los archivos multimedia nunca se suben al servidor.';

  @override
  String get backupNow => 'Copiar ahora';

  @override
  String get backupSectionRestore => 'Restaurar';

  @override
  String get backupRestoreAction => 'Restaurar desde una copia';

  @override
  String get backupRestoreFooter => 'Reemplaza los chats y ajustes de este dispositivo con el contenido de la copia.';

  @override
  String get backupSectionKey => 'Clave de Secretly ID';

  @override
  String get backupKeyShow => 'Mostrar la clave';

  @override
  String get backupKeyRestore => 'Restaurar con una clave';

  @override
  String get backupKeyFooter => 'Restaura solo tu Secretly ID: no contiene chats. Restaurar con una clave borra los datos locales.';

  @override
  String get backupDestServerDevice => 'Servidor y dispositivo';

  @override
  String get backupDestServer => 'Servidor';

  @override
  String get backupDestDevice => 'Dispositivo';

  @override
  String get backupDestNone => 'Sin elegir';

  @override
  String get backupDestServerOnly => 'Solo servidor';

  @override
  String get backupDestDeviceOnly => 'Solo dispositivo';

  @override
  String get backupTileOff => 'Desactivado: tu historial no está protegido';

  @override
  String get backupTilePending => 'Activado, pero aún no se ha ejecutado';

  @override
  String get backupTileFailing => 'No se ejecuta: revísalo';

  @override
  String get backupTileStale => 'Sin actualizar desde hace tiempo';

  @override
  String get backupPasswordChange => 'Cambiar contraseña';

  @override
  String get backupPasswordRemove => 'Eliminar contraseña';

  @override
  String get chatUndecryptablePending => 'Ha llegado un mensaje, pero aún no se puede leer: restaurando la sesión segura…';

  @override
  String get liquidGlassTitle => 'Cristal líquido';

  @override
  String get liquidGlassSubtitle => 'Barras e islas con refracción. Desactívalo para el material sencillo: gasta menos batería y calienta menos.';

  @override
  String get billingPendingTitle => 'Esperando el pago';

  @override
  String get billingPendingBody => 'El pedido se creó pero el pago aún no está confirmado. Completa el pago con el método elegido: Premium se activará solo.';

  @override
  String get callsHideAddressTitle => 'Ocultar mi dirección en las llamadas';

  @override
  String get callsHideAddressSubtitle => 'A través de nuestro servidor: la otra persona no verá tu dirección IP, pero el retraso puede aumentar';

  @override
  String get desktopJoinRoomByLink => 'Unirse con un enlace';

  @override
  String get desktopJoinRoomLinkHint => 'Pega el enlace de invitación';

  @override
  String get desktopJoinRoomLinkInvalid => 'Este no es un enlace de invitación a una sala';

  @override
  String get desktopOfflineLockTitle => 'Pedir la contraseña tras mucho tiempo sin conexión';

  @override
  String get desktopOfflineLockDescription => 'Si este ordenador no contacta con el servidor durante más tiempo del indicado, pedirá la contraseña al iniciarse. Un ordenador perdido nunca recibe el cierre de sesión remoto, pero sí alcanza este límite.';

  @override
  String get desktopOfflineLockNever => 'Nunca';

  @override
  String get desktopOfflineLockDays7 => '7 días';

  @override
  String get desktopOfflineLockDays14 => '14 días';

  @override
  String get desktopOfflineLockDays30 => '30 días';

  @override
  String get desktopPollTitle => 'Encuesta';

  @override
  String get desktopPollAnonymous => 'Encuesta anónima';

  @override
  String get desktopPollClosed => 'Cerrada';

  @override
  String desktopPollVoters(Object count) {
    return 'Han votado: $count';
  }

  @override
  String get desktopPollMultipleHint => 'Puedes elegir varias';

  @override
  String get desktopPollCloseAction => 'Cerrar la encuesta';

  @override
  String get desktopEventTitle => 'Evento';

  @override
  String get desktopEventGoing => 'Voy';

  @override
  String get desktopEventMaybe => 'Quizá';

  @override
  String get desktopEventNo => 'No voy';

  @override
  String get desktopPollNewTitle => 'Nueva encuesta';

  @override
  String get desktopPollQuestionHint => 'Pregunta';

  @override
  String desktopPollOptionHint(Object index) {
    return 'Opción $index';
  }

  @override
  String get desktopPollAddOption => 'Añadir opción';

  @override
  String get desktopPollCreateAction => 'Crear';

  @override
  String get desktopPollNeedTwo => 'Hace falta una pregunta y al menos dos opciones';

  @override
  String get desktopPollMultipleLabel => 'Varias respuestas';

  @override
  String get desktopPollAnonymousLabel => 'Anónima';

  @override
  String get desktopEventNewTitle => 'Nuevo evento';

  @override
  String get desktopEventTitleHint => 'Título';

  @override
  String get desktopEventDescriptionHint => 'Descripción';

  @override
  String get desktopEventLocationHint => 'Lugar';

  @override
  String get desktopEventPickWhen => 'Elegir fecha y hora';

  @override
  String get desktopEventNeedTitleAndDate => 'Hacen falta un título y una fecha';

  @override
  String get desktopViewerOpenExternally => 'Abrir en otra app';

  @override
  String get desktopViewerSaveAs => 'Guardar como…';

  @override
  String desktopViewerPage(Object page, Object total) {
    return 'Página $page de $total';
  }

  @override
  String get desktopViewerFailed => 'No se ha podido mostrar el archivo';

  @override
  String get desktopViewerTooLarge => 'El archivo es demasiado grande para mostrarlo aquí';

  @override
  String get desktopSupportAttach => 'Adjuntar un archivo';

  @override
  String desktopSupportAttachHint(Object limit) {
    return 'Una captura de pantalla o un archivo de registro: hasta $limit. El adjunto se cifra junto con el mensaje.';
  }

  @override
  String desktopSupportTooLarge(Object limit) {
    return 'El archivo supera $limit y no se puede enviar';
  }

  @override
  String get desktopSupportUnreadable => 'No se pudo leer el archivo';

  @override
  String get desktopSupportRemoveAttachment => 'Quitar el adjunto';

  @override
  String desktopSupportMegabytes(Object value) {
    return '$value MB';
  }

  @override
  String get desktopSupportYou => 'Tú';

  @override
  String get desktopSupportShrunk => 'La imagen se redujo para que quepa';

  @override
  String get desktopStickerPackTitle => 'Paquete de pegatinas';

  @override
  String get desktopStickerPackAddPlain => 'Añadir el paquete';

  @override
  String get desktopStickerPackInstalled => 'Instalado';

  @override
  String get desktopStickerPackInstalling => 'Instalando…';

  @override
  String get desktopStickerPackOwn => 'Este es tu propio paquete';

  @override
  String get desktopStickerPackNoAuthor => 'Se desconoce el autor del paquete: abre la misma pegatina en un chat individual';

  @override
  String desktopStickerPackInstallingProgress(Object done, Object total) {
    return 'Instalando… $done/$total';
  }

  @override
  String desktopStickerPackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pegatinas',
      one: '$count pegatina',
    );
    return '$_temp0';
  }

  @override
  String desktopStickerPackAdd(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Añadir $count pegatinas',
      one: 'Añadir $count pegatina',
    );
    return '$_temp0';
  }

  @override
  String get desktopPairingTitle => 'Conecta Secretly Desktop';

  @override
  String get desktopPairingHowTo => 'En el teléfono abre Secretly → Ajustes → Dispositivos → «Vincular dispositivo» y escanea este código QR.';

  @override
  String get desktopPairingPreparingQr => 'Preparando el QR…';

  @override
  String get desktopPairingQrUnavailable => 'QR no disponible';

  @override
  String get desktopPairingCodeExpired => 'El código ha caducado: actualizando…';

  @override
  String desktopPairingCodeValidFor(Object time) {
    return 'El código es válido $time más';
  }

  @override
  String get desktopPairingPrepareFailed => 'No se pudo preparar el código. Comprueba tu conexión a internet e inténtalo de nuevo.';

  @override
  String get desktopPairingRevoked => 'Este dispositivo se eliminó de la cuenta, por eso no se crea ningún código.\nVuelve a conectar el ordenador: recibirá una identidad de dispositivo nueva y la anterior seguirá revocada. Solo una confirmación desde el teléfono da acceso a las conversaciones.';

  @override
  String get desktopPairingPreparingNew => 'Preparando una conexión nueva…';

  @override
  String get desktopPairingConnectAsNew => 'Conectar como dispositivo nuevo';

  @override
  String get desktopPairingIdentityResetFailed => 'No se pudo recrear la identidad del dispositivo. Reinicia la aplicación e inténtalo de nuevo.';

  @override
  String get desktopPairingWaitingConfirm => 'Esperando la confirmación…';

  @override
  String get desktopPairingNewQr => 'Generar un QR nuevo';

  @override
  String get desktopPairingCreatingRequest => 'Creando la solicitud…';

  @override
  String get desktopPairingReadyToScan => 'Listo para escanear';

  @override
  String get desktopPairingWaitingScan => 'Esperando el escaneo en el teléfono…';

  @override
  String get desktopPairingScannedConfirmOnPhone => 'QR escaneado: confírmalo en el teléfono.';

  @override
  String get desktopPairingFetchingProfile => 'Obteniendo el perfil y las claves…';

  @override
  String get desktopPairingConnectedLoading => 'Conectado. Cargando…';

  @override
  String get desktopPairingConnectionError => 'Error de conexión. Inténtalo de nuevo.';

  @override
  String get desktopMenuReaction => 'Reacción';

  @override
  String get desktopMenuContinueInTopic => 'Continuar en un tema';

  @override
  String get desktopMenuCopySelection => 'Copiar la selección';

  @override
  String get desktopMenuCopyText => 'Copiar el texto';

  @override
  String get desktopMenuCopyLink => 'Copiar el enlace';

  @override
  String get desktopMenuTranslate => 'Traducir';

  @override
  String get desktopMenuHideTranslation => 'Ocultar la traducción';

  @override
  String get desktopMenuSelect => 'Seleccionar';

  @override
  String get desktopMenuPhotoOrVideo => 'Foto o vídeo';

  @override
  String get desktopMenuContact => 'Contacto';

  @override
  String get desktopMenuLocation => 'Ubicación';

  @override
  String get desktopListPinned => 'FIJADOS';

  @override
  String get desktopListToday => 'HOY';

  @override
  String get desktopListYesterday => 'AYER';

  @override
  String get desktopListThisWeek => 'ESTA SEMANA';

  @override
  String get desktopListEarlier => 'ANTES';

  @override
  String get desktopListNothingFound => 'No se ha encontrado nada';

  @override
  String get desktopListAddFavourite => 'Añadir a favoritos';

  @override
  String get desktopListRemoveFavourite => 'Quitar de favoritos';

  @override
  String get desktopListMute => 'Silenciar';

  @override
  String get desktopListMarkRead => 'Marcar como leído';

  @override
  String get desktopListArchive => 'Archivar';

  @override
  String get desktopListFolders => 'Carpetas';

  @override
  String get desktopListCreate => 'Crear';

  @override
  String get desktopListTyping => 'escribiendo';

  @override
  String get desktopListDraftPrefix => 'Borrador: ';

  @override
  String desktopListDiscussion(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Conversación · $count participantes',
      one: 'Conversación · $count participante',
    );
    return '$_temp0';
  }

  @override
  String get desktopCallServerSilent => 'El servidor no respondió. Inténtalo de nuevo o sal de la llamada.';

  @override
  String get desktopCallRoomMissing => 'La sala no está disponible en el servidor: no se puede iniciar una llamada en ella.';

  @override
  String get desktopCallNoServer => 'Sin conexión con el servidor. Comprueba tu conexión.';

  @override
  String get desktopCallJoinFailed => 'No se pudo entrar en la llamada. Comprueba la conexión e inténtalo de nuevo.';

  @override
  String desktopCallSharingScreen(Object name) {
    return '$name está compartiendo la pantalla';
  }

  @override
  String get desktopCallRoomEmpty => 'Aún no se ha escrito nada en la sala';

  @override
  String get desktopCallMessageHint => 'Mensaje a la sala…';

  @override
  String get desktopCallSendToRoom => 'Enviar a la sala';

  @override
  String desktopCallParticipantsTab(Object count) {
    return 'Participantes · $count';
  }

  @override
  String get desktopCallNotesTab => 'Notas';

  @override
  String get desktopCallLinkCopied => 'Enlace copiado';

  @override
  String get desktopCallFailed => 'No se pudo';

  @override
  String desktopCallFailedWith(Object error) {
    return 'No se pudo: $error';
  }

  @override
  String get desktopCallMicOn => 'Activar el micrófono';

  @override
  String get desktopCallMicOff => 'Desactivar el micrófono';

  @override
  String get desktopCallCamOn => 'Activar la cámara';

  @override
  String get desktopCallCamOff => 'Desactivar la cámara';

  @override
  String get desktopCallNoMediaVideo => 'El servidor no facilitó un canal de medios: el vídeo no está disponible';

  @override
  String get desktopCallLayoutSingle => 'Uno';

  @override
  String get desktopCallLayoutGrid => 'Cuadrícula';

  @override
  String get desktopCallShowOneLarge => 'Mostrar a una persona en grande';

  @override
  String get desktopCallShowGrid => 'Mostrar a todos en cuadrícula';

  @override
  String get desktopCallScreen => 'Pantalla';

  @override
  String get desktopCallShareStop => 'Dejar de compartir la pantalla';

  @override
  String get desktopCallShareStart => 'Compartir la pantalla';

  @override
  String get desktopCallNoMediaScreen => 'El servidor no facilitó un canal de medios: no se puede compartir la pantalla';

  @override
  String get desktopCallLeave => 'Salir';

  @override
  String get desktopCallLeaveCall => 'Salir de la llamada';

  @override
  String get desktopCallNoMediaBoth => 'El servidor no facilitó un canal de medios: esta llamada no tendrá ni sonido ni vídeo';

  @override
  String get desktopCallMinimise => 'Minimizar la llamada';

  @override
  String get desktopCallDiscussion => 'Conversación';

  @override
  String desktopCallDiscussionOf(Object title) {
    return 'Conversación · $title';
  }

  @override
  String get desktopCallEncrypted => 'La llamada está cifrada de extremo a extremo';

  @override
  String desktopCallDurationOnAir(Object duration, Object count) {
    return '$duration · $count en directo';
  }

  @override
  String get desktopCallExitFullScreen => 'Salir de pantalla completa';

  @override
  String get desktopCallFullScreen => 'Pantalla completa';

  @override
  String get desktopCallDemoRoom => 'Sala de demostración';

  @override
  String get desktopCallNoCallYet => 'Todavía no hay llamada';

  @override
  String get desktopCallDemoExplain => 'Solo existe en este ordenador y no está en el servidor, así que no se puede iniciar una llamada. En una sala real el botón funciona.';

  @override
  String get desktopCallStartHint => 'Empieza: los demás verán la invitación en la sala';

  @override
  String get desktopCallVoiceOnly => 'Solo voz';

  @override
  String get desktopCallWithCamera => 'Con cámara';

  @override
  String get desktopCallConnecting => 'Conectando…';

  @override
  String get desktopCallOngoing => 'Hay una conversación en curso';

  @override
  String desktopCallOnAir(Object count) {
    return '$count en directo';
  }

  @override
  String get desktopCallJoin => 'Unirse';

  @override
  String get desktopCallFullScreenShort => 'Pantalla completa';

  @override
  String get desktopCallReconnecting => 'reconectando';

  @override
  String get desktopCallCannotHear => 'no oye';

  @override
  String get desktopCallSharingShort => 'comparte la pantalla';

  @override
  String get desktopCallCameraOn => 'cámara encendida';

  @override
  String get desktopCallPickDevice => 'Elegir un dispositivo';

  @override
  String get desktopCallPreparingLink => 'Preparando el enlace…';

  @override
  String get desktopCallInvite => 'Invitar';

  @override
  String desktopCallFps(Object fps) {
    return '$fps f/s';
  }

  @override
  String get desktopSettingsTitle => 'Ajustes';

  @override
  String get desktopSettingsGroupApp => 'Aplicación';

  @override
  String get desktopSettingsGroupPrivacy => 'Privacidad y seguridad';

  @override
  String get desktopSettingsGroupAccount => 'Cuenta y datos';

  @override
  String get desktopSettingsGeneralLabel => 'General';

  @override
  String get desktopSettingsGeneralSubtitle => 'Idioma, comportamiento de la app';

  @override
  String get desktopSettingsGeneralKeywords => 'idioma, configuración regional, enter, envío, entrada';

  @override
  String get desktopSettingsAppearanceLabel => 'Apariencia';

  @override
  String get desktopSettingsAppearanceSubtitle => 'Tema, acento, fondo del chat';

  @override
  String get desktopSettingsAppearanceKeywords => 'tema, acento, fondo, burbujas, color, oscuro, marcas, animación';

  @override
  String get desktopSettingsShortcutsLabel => 'Atajos de teclado';

  @override
  String get desktopSettingsShortcutsSubtitle => 'Qué pulsar para ir más rápido';

  @override
  String get desktopSettingsShortcutsKeywords => 'teclas, atajos, rápido, cmd, ctrl';

  @override
  String get desktopSettingsPowerLabel => 'Consumo de energía';

  @override
  String get desktopSettingsPowerSubtitle => 'Qué gasta la batería';

  @override
  String get desktopSettingsPowerKeywords => 'batería, animación, marcos, cristal, rendimiento, calor';

  @override
  String get desktopSettingsNotificationsLabel => 'Notificaciones';

  @override
  String get desktopSettingsNotificationsSubtitle => 'Sonidos, vista previa, silencio';

  @override
  String get desktopSettingsNotificationsKeywords => 'sonido, vista previa, silencio, no molestar, banner, texto';

  @override
  String get desktopSettingsCallsLabel => 'Llamadas';

  @override
  String get desktopSettingsCallsSubtitle => 'Recibir llamadas y compartir pantalla';

  @override
  String get desktopSettingsCallsKeywords => 'llamadas, entrantes, compartir pantalla, vídeo, audio';

  @override
  String get desktopSettingsMediaLabel => 'Sonido y vídeo';

  @override
  String get desktopSettingsMediaSubtitle => 'Cámara y micrófono para las llamadas';

  @override
  String get desktopSettingsMediaKeywords => 'cámara, micrófono, dispositivo, webcam, auriculares, sonido, vídeo';

  @override
  String get desktopSettingsPrivacyLabel => 'Privacidad';

  @override
  String get desktopSettingsPrivacySubtitle => 'Quién ve qué sobre ti';

  @override
  String get desktopSettingsPrivacyKeywords => 'quién ve, última vez, foto, llamadas, mensajes, reenvío, apodo, búsqueda, desconocidos';

  @override
  String get desktopSettingsSecurityLabel => 'Seguridad';

  @override
  String get desktopSettingsSecuritySubtitle => 'Cifrado y dispositivos verificados';

  @override
  String get desktopSettingsSecurityKeywords => 'cifrado, e2ee, verificados, bloqueo, contraseña, touch id, verificación';

  @override
  String get desktopSettingsBackupLabel => 'Copia de seguridad';

  @override
  String get desktopSettingsBackupSubtitle => 'Lo que salvará tu historial';

  @override
  String get desktopSettingsBackupKeywords => 'copia, respaldo, restaurar, safe backup, contraseña, medios';

  @override
  String get desktopSettingsBlockedLabel => 'Bloqueados';

  @override
  String get desktopSettingsBlockedSubtitle => 'A quién se le cierra el acceso';

  @override
  String get desktopSettingsBlockedKeywords => 'bloqueo, bloqueados, desbloquear, lista negra, spam';

  @override
  String get desktopSettingsDevicesLabel => 'Sesiones y dispositivos';

  @override
  String get desktopSettingsDevicesSubtitle => 'Sesiones activas';

  @override
  String get desktopSettingsDevicesKeywords => 'dispositivos, sesiones, qr, vinculación, cerrar sesión, copia';

  @override
  String get desktopSettingsAccountLabel => 'Cuenta';

  @override
  String get desktopSettingsAccountSubtitle => 'Perfil y cierre de sesión';

  @override
  String get desktopSettingsAccountKeywords => 'nombre, sobre mí, id, cerrar sesión, restablecer';

  @override
  String get desktopSettingsStorageLabel => 'Almacenamiento';

  @override
  String get desktopSettingsStorageSubtitle => 'Caché, descargas';

  @override
  String get desktopSettingsStorageKeywords => 'caché, espacio, borrar, medios, descargas';

  @override
  String get desktopSettingsSupportLabel => 'Soporte';

  @override
  String get desktopSettingsSupportSubtitle => 'Una conversación cifrada con nosotros';

  @override
  String get desktopSettingsSupportKeywords => 'soporte, ayuda, problema, error, escribir';

  @override
  String get desktopSettingsAboutLabel => 'Acerca de';

  @override
  String get desktopSettingsAboutKeywords => 'versión, compilación, licencias, sitio web';

  @override
  String get desktopSettingsDangerLabel => 'Eliminar la cuenta';

  @override
  String get desktopSettingsEndCallFirst => 'Termina primero la llamada activa.';

  @override
  String get desktopSettingsSignOutTitle => '¿Cerrar la sesión en este ordenador?';

  @override
  String get desktopSettingsSignOutBody => 'De este ordenador se eliminarán las conversaciones, las claves y la caché. La cuenta y el historial del teléfono no se tocan: el ordenador se puede vincular de nuevo con un código QR.';

  @override
  String get desktopSettingsSignOut => 'Cerrar sesión';

  @override
  String desktopSettingsSignOutFailed(Object error) {
    return 'No se pudo cerrar la sesión: $error';
  }

  @override
  String get desktopSettingsActive => 'activo';

  @override
  String get desktopGeneralSystemLanguage => 'Del sistema';

  @override
  String get desktopGeneralInterfaceLanguage => 'Idioma de la interfaz';

  @override
  String get desktopGeneralAppliesAtOnce => 'Se aplica de inmediato';

  @override
  String get desktopGeneralBehaviour => 'Comportamiento';

  @override
  String get desktopGeneralEnterSends => 'Enter envía el mensaje';

  @override
  String get desktopGeneralShiftEnterNewline => 'Shift+Enter inserta un salto de línea';

  @override
  String get desktopGeneralEnterNewline => 'Enter inserta un salto de línea, Shift+Enter envía';

  @override
  String get desktopGeneralHoverMenu => 'Menú al pasar el cursor sobre un mensaje';

  @override
  String get desktopGeneralHoverMenuOn => 'Encima del mensaje aparecen reacciones y acciones';

  @override
  String get desktopGeneralHoverMenuOff => 'Las acciones están en el botón derecho';

  @override
  String get desktopGeneralLinkPreviews => 'Vistas previas de enlaces';

  @override
  String get desktopGeneralLinkPreviewsOn => 'La tarjeta del enlace se envía junto con el mensaje';

  @override
  String get desktopGeneralLinkPreviewsOff => 'Los enlaces se envían sin tarjeta y no se abre ninguna página';

  @override
  String get desktopPowerAnimations => 'Animaciones';

  @override
  String get desktopPowerAnimationsHint => 'Todo está activado por defecto. Desactiva de arriba abajo si el portátil se calienta o se agota la batería.';

  @override
  String get desktopPowerFramesTitle => 'Animación de marcos y estados';

  @override
  String get desktopPowerFramesHint => 'Marcos de avatar animados y estados con emoji de los demás. La más costosa de las tres: desactívala primero.';

  @override
  String get desktopPowerGlassBubbles => 'Burbujas de cristal';

  @override
  String get desktopPowerGlassBubblesHint => 'Desenfoque detrás de los mensajes entrantes';

  @override
  String get desktopPowerMattePanels => 'Paneles mates';

  @override
  String get desktopPowerMattePanelsHint => 'Desenfoque en paneles y ventanas emergentes';

  @override
  String get desktopPowerNotAffectedTitle => 'Lo que esto no afecta';

  @override
  String get desktopPowerNotAffectedHint => 'La entrega de mensajes, el cifrado y las notificaciones funcionan igual con cualquier valor. Estos ajustes solo afectan al dibujado.';

  @override
  String get desktopNotifHidden => 'Oculto';

  @override
  String get desktopNotifSenderOnly => 'Solo el remitente';

  @override
  String get desktopNotifSenderAndText => 'Remitente y texto';

  @override
  String get desktopNotifUnavailableHere => 'No disponible en esta plataforma.';

  @override
  String get desktopNotifShowPreview => 'Mostrar una vista previa del mensaje';

  @override
  String get desktopNotifInSystem => 'En las notificaciones del sistema';

  @override
  String get desktopNotifDirectChats => 'Chats individuales';

  @override
  String get desktopNotifDirectChatsHint => 'Avisos de los mensajes individuales';

  @override
  String get desktopNotifRooms => 'Salas';

  @override
  String get desktopNotifRoomsHint => 'Avisos de los mensajes en las salas';

  @override
  String get desktopNotifSound => 'Sonido';

  @override
  String get desktopNotifDnd => 'No molestar';

  @override
  String get desktopNotifDndHint => 'Desactivar todas las notificaciones';

  @override
  String get desktopWallAnimContinuous => 'Siempre';

  @override
  String get desktopWallAnimOnEnter => 'Al abrir un chat';

  @override
  String get desktopWallAnimTap => 'Al hacer clic en el fondo';

  @override
  String get desktopWallAnimOff => 'No animar';

  @override
  String get desktopWallpaperNavy => 'Azul noche';

  @override
  String get desktopWallpaperGraphite => 'Grafito';

  @override
  String get desktopWallpaperTeal => 'Turquesa';

  @override
  String get desktopWallpaperPlum => 'Ciruela';

  @override
  String get desktopWallpaperWine => 'Vino';

  @override
  String get desktopWallpaperMint => 'Menta';

  @override
  String get desktopWallpaperLavender => 'Lavanda';

  @override
  String get desktopWallpaperSunset => 'Atardecer';

  @override
  String get desktopWallpaperPeach => 'Melocotón';

  @override
  String get desktopWallpaperSky => 'Cielo';

  @override
  String get desktopWallpaperMidnight => 'Medianoche';

  @override
  String get desktopAppearanceTitle => 'Apariencia';

  @override
  String get desktopAppearanceHint => 'El esquema de esta ventana. El teléfono tiene el suyo: este ajuste no viaja a ninguna parte.';

  @override
  String get desktopAppearanceScheme => 'Esquema';

  @override
  String get desktopAppearanceSchemeHint => 'Oscuro, claro o según el sistema';

  @override
  String get desktopAppearanceDark => 'Oscuro';

  @override
  String get desktopAppearanceLight => 'Claro';

  @override
  String get desktopAppearanceAuto => 'Auto';

  @override
  String get desktopAppearanceAccent => 'Acento de la interfaz';

  @override
  String get desktopAppearanceAccentHint => 'Botones, tus burbujas y las selecciones en toda la aplicación.';

  @override
  String get desktopAppearanceWallpaper => 'Fondo del chat';

  @override
  String get desktopAppearanceWallpaperHint => 'El fondo del chat para todas las conversaciones.';

  @override
  String get desktopAppearanceLiveWallpaper => 'Fondo animado';

  @override
  String get desktopAppearanceLiveWallpaperHint => 'Un patrón con un brillo suave. El mismo conjunto que en el teléfono.';

  @override
  String get desktopAppearanceAnimBehaviour => 'Comportamiento de la animación';

  @override
  String get desktopAppearanceAnimBehaviourHint => 'Cuándo cobra vida el patrón.';

  @override
  String get desktopAppearanceWallPulse => 'El fondo acompaña al mensaje';

  @override
  String get desktopAppearanceWallPulseHint => 'Una onda de luz recorre el patrón: hacia arriba al enviar, hacia abajo al recibir.';

  @override
  String get desktopAppearanceEnable => 'Activar';

  @override
  String get desktopAppearanceLiveOnly => 'Solo funciona con el fondo animado';

  @override
  String get desktopAppearanceBubbleStyle => 'Estilo de las burbujas';

  @override
  String get desktopAppearanceBubbleStyleHint => 'El color de tus mensajes salientes en todos los chats.';

  @override
  String get desktopAppearanceSenderColour => 'Color del nombre del remitente';

  @override
  String get desktopAppearanceSenderColourHint => 'El color del apodo de la otra persona en los chats de grupo.';

  @override
  String get desktopAppearanceIndicatorColour => 'Color de los indicadores';

  @override
  String get desktopAppearanceIndicatorColourHint => 'Las marcas de entrega y el punto de no leído.';

  @override
  String get desktopAppearanceDemoMode => 'Modo de demostración';

  @override
  String get desktopAppearanceDemoHint => 'Los cambios de apariencia se guardarán cuando haya un perfil vinculado.';

  @override
  String get desktopAppearanceCurrentChoice => 'Selección actual';

  @override
  String desktopAppearanceThemeIs(Object name) {
    return 'Tema: $name';
  }

  @override
  String get desktopBackupEvery6h => 'Cada 6 horas';

  @override
  String get desktopBackupEvery12h => 'Cada 12 horas';

  @override
  String get desktopBackupDaily => 'Una vez al día';

  @override
  String get desktopBackupWeekly => 'Una vez por semana';

  @override
  String get desktopBackupOffWarning => 'La copia automática está desactivada: no habrá nada con lo que restaurar el historial';

  @override
  String get desktopBackupNeverRan => 'Activada, pero todavía no se ha ejecutado';

  @override
  String desktopBackupLastFailedWith(Object error) {
    return 'La última copia falló: $error';
  }

  @override
  String get desktopBackupLastFailed => 'La última copia falló';

  @override
  String get desktopBackupStale => 'La copia lleva tiempo sin actualizarse';

  @override
  String get desktopBackupFresh => 'La copia está al día';

  @override
  String get desktopBackupState => 'Estado';

  @override
  String get desktopBackupAutomatic => 'Copia automática';

  @override
  String get desktopBackupAutomaticHint => 'La copia está cifrada con tu contraseña. Sin ella no podemos restaurarla ni nosotros ni nadie más, así que hay que recordarla.';

  @override
  String get desktopBackupCreateAuto => 'Crear automáticamente';

  @override
  String get desktopBackupUploadServer => 'Subir al servidor';

  @override
  String get desktopBackupUploadServerHint => 'Disponible desde cualquier dispositivo';

  @override
  String get desktopBackupKeepLocal => 'Guardar en este ordenador';

  @override
  String get desktopBackupKeepLocalHint => 'No depende de la red';

  @override
  String get desktopBackupIncludeMedia => 'Incluir los medios';

  @override
  String get desktopBackupIncludeMediaHint => 'La copia será bastante más grande';

  @override
  String get desktopBackupFrequency => 'Frecuencia';

  @override
  String get desktopBackupNowhereTitle => 'La copia no se guarda en ninguna parte';

  @override
  String get desktopBackupNowhereHint => 'La copia automática está activada pero ambos destinos están desactivados, así que no se crea ninguna copia. Activa el servidor o este ordenador.';

  @override
  String get desktopBackupRecoveryKey => 'Clave de recuperación';

  @override
  String get desktopBackupCreateRecoveryKey => 'Crear una clave de recuperación';

  @override
  String get desktopBackupRecoveryKeyHint => 'Lo necesitarás si no queda ningún dispositivo con Secretly. Guárdala aparte de la contraseña.';

  @override
  String desktopBackupKeyFailed(Object error) {
    return 'No se pudo crear la clave: $error';
  }

  @override
  String get desktopBackupKeyPassword => 'Contraseña de la clave de recuperación';

  @override
  String get desktopBackupPasswordsDiffer => 'Las contraseñas no coinciden.';

  @override
  String get desktopBackupKeyPasswordHint => 'Esta contraseña cifra la clave en sí. No sustituye a la de la aplicación y no se guarda en ninguna parte: no se puede recuperar.';

  @override
  String get desktopBackupPasswordAgain => 'Otra vez';

  @override
  String desktopUnblockTitle(Object name) {
    return '¿Desbloquear a $name?';
  }

  @override
  String get desktopUnblockBody => 'Esta persona podrá volver a escribirte y llamarte.';

  @override
  String get desktopUnblockAction => 'Desbloquear';

  @override
  String get desktopPrivacyLastSeen => 'Última vez';

  @override
  String get desktopPrivacyProfilePhoto => 'Fotos de perfil';

  @override
  String get desktopPrivacyForwarding => 'Reenvío de mensajes';

  @override
  String get desktopPrivacyCalls => 'Llamadas';

  @override
  String get desktopPrivacyVoice => 'Mensajes de voz';

  @override
  String get desktopPrivacyMessages => 'Mensajes';

  @override
  String get desktopPrivacyNobody => 'Nadie';

  @override
  String get desktopPrivacyEverybody => 'Todos';

  @override
  String get desktopPrivacyContacts => 'Contactos';

  @override
  String get desktopPrivacyEncryption => 'Cifrado';

  @override
  String get desktopPrivacyEncryptionHint => 'Todos los mensajes y llamadas están cifrados de extremo a extremo. Las claves solo están en tus dispositivos.';

  @override
  String get desktopPrivacyE2eeActive => 'El cifrado de extremo a extremo está activo';

  @override
  String get desktopPrivacyWhoSees => 'Quién ve';

  @override
  String get desktopPrivacyWhoSeesHint => 'Los mismos ajustes de visibilidad que en la aplicación móvil.';

  @override
  String get desktopPrivacyVisibility => 'Visibilidad';

  @override
  String get desktopPrivacyByNickname => 'Visibilidad por apodo';

  @override
  String get desktopPrivacyByNicknameHint => 'Permitir que te encuentren por tu apodo';

  @override
  String get desktopPrivacySuggest => 'Sugerir personas en la búsqueda';

  @override
  String get desktopPrivacyStrangers => 'Chats nuevos de desconocidos';

  @override
  String get desktopPrivacyStrangersHint => 'Al archivo y sin notificaciones';

  @override
  String get desktopPrivacyAutoDelete => 'Eliminar mi cuenta';

  @override
  String get desktopPrivacyAutoDeleteHint => 'Si no inicias sesión durante más tiempo del elegido, la cuenta y todos los mensajes se eliminan automáticamente. La cuenta atrás se reinicia con cada inicio de sesión.';

  @override
  String get desktopPrivacyIfAbsent => 'Si no inicio sesión';

  @override
  String get desktopPrivacyIn1Month => 'Al cabo de 1 mes';

  @override
  String get desktopPrivacyIn3Months => 'Al cabo de 3 meses';

  @override
  String get desktopPrivacyIn6Months => 'Al cabo de 6 meses';

  @override
  String get desktopPrivacyIn1Year => 'Al cabo de un año';

  @override
  String get desktopPrivacyIn2Years => 'Al cabo de 2 años';

  @override
  String get desktopLockImmediately => 'En cuanto se pierde el foco';

  @override
  String desktopLockSeconds(Object value) {
    return '$value s';
  }

  @override
  String desktopLockMinutes(Object value) {
    return '$value min';
  }

  @override
  String desktopLockHours(Object value) {
    return '$value h';
  }

  @override
  String get desktopLockNoIdentityService => 'El servicio de verificación de identidad no está disponible: el bloqueo no se ha activado.';

  @override
  String get desktopLockNotConfirmed => 'El bloqueo no se activó: la confirmación no se completó.';

  @override
  String get desktopLockTitle => 'Bloqueo de la aplicación';

  @override
  String get desktopLockTouchIdHint => 'Pedir Touch ID para volver a entrar tras perder el foco.';

  @override
  String get desktopLockPasswordHint => 'Pedir la contraseña del dispositivo para volver a entrar tras perder el foco.';

  @override
  String get desktopLockEnableTouchId => 'Activar Touch ID';

  @override
  String get desktopLockEnableLock => 'Activar el bloqueo';

  @override
  String get desktopLockDevicePassword => 'Contraseña del dispositivo';

  @override
  String get desktopLockAfter => 'Bloquear al cabo de';

  @override
  String get desktopLockNow => 'Bloquear ahora';

  @override
  String get desktopDevicesEndSessionTitle => '¿Cerrar la sesión?';

  @override
  String desktopDevicesEndSessionBody(Object id) {
    return 'El dispositivo $id se desconectará de tu perfil. Para recuperar el acceso hará falta escanear el QR de nuevo. ¿Continuar?';
  }

  @override
  String get desktopDevicesEnd => 'Cerrar';

  @override
  String desktopDevicesEndFailed(Object error) {
    return 'No se pudo cerrar la sesión: $error';
  }

  @override
  String get desktopDevicesEnded => 'La sesión del dispositivo se ha cerrado.';

  @override
  String get desktopDevicesActiveSessions => 'Sesiones activas';

  @override
  String get desktopDevicesDemoHint => 'Modo de demostración · los dispositivos reales aparecerán al conectar un perfil';

  @override
  String get desktopDevicesThisComputer => 'macOS · Este ordenador';

  @override
  String get desktopDevicesDemoMac => 'MacBook Pro · Activo ahora';

  @override
  String get desktopDevicesDemoIphone => 'iOS 18.2 · hace 2 horas (demo)';

  @override
  String get desktopDevicesDemoIpad => 'iPadOS 18 · ayer (demo)';

  @override
  String get desktopDevicesThisDevice => 'Este dispositivo';

  @override
  String get desktopDevicesRemoteDevice => 'Dispositivo remoto';

  @override
  String get desktopDevicesDisconnect => 'Desconectar';

  @override
  String get desktopDevicesTitle => 'Dispositivos';

  @override
  String desktopDevicesTitleCount(Object count) {
    return 'Dispositivos · $count';
  }

  @override
  String get desktopDevicesHint => 'Los dispositivos vinculados a este perfil en el servidor de claves.';

  @override
  String get desktopDevicesLoadFailed => 'No se pudo cargar';

  @override
  String get desktopDevicesRetry => 'Reintentar';

  @override
  String get desktopDevicesNone => 'No se han encontrado dispositivos';

  @override
  String get desktopDevicesNotLinked => 'El perfil aún no está vinculado al servidor.';

  @override
  String get desktopDevicesRefresh => 'Actualizar la lista';

  @override
  String get desktopAccentCustom => 'Color propio';

  @override
  String get desktopAccentCustomChange => 'Color propio: cambiar';

  @override
  String get desktopPairTitle => 'Vincular un dispositivo';

  @override
  String get desktopPairHint => 'Muestra el código QR en el dispositivo nuevo o escanéalo desde el teléfono';

  @override
  String get desktopPairRequestFailed => 'No se pudo crear la solicitud de vinculación';

  @override
  String get desktopPairCodeCopied => 'Se ha copiado el contenido del QR';

  @override
  String get desktopPairNewTitle => 'Vincular un dispositivo nuevo';

  @override
  String get desktopPairNewHint => 'En el dispositivo nuevo abre Secretly y elige «Conectar por QR». Luego escanea el código de abajo.';

  @override
  String get desktopPairClose => 'Cerrar';

  @override
  String get desktopPairCopyCode => 'Copiar el código';

  @override
  String get desktopPairRefreshQr => 'Actualizar el QR';

  @override
  String desktopSyncPulled(Object count) {
    return 'Eventos nuevos descargados: $count';
  }

  @override
  String get desktopSyncTooOften => 'Demasiadas solicitudes: inténtalo más tarde';

  @override
  String get desktopSyncNothingNew => 'Listo · no hay eventos nuevos';

  @override
  String get desktopSyncDemoUnavailable => 'No disponible en el modo de demostración';

  @override
  String desktopSyncBlobsPulled(Object blobs, Object convos) {
    return 'Adjuntos descargados: $blobs (chats: $convos)';
  }

  @override
  String desktopSyncNoBlobs(Object convos) {
    return 'Listo · no hay adjuntos nuevos (chats: $convos)';
  }

  @override
  String get desktopSyncTitle => 'Historial de otros dispositivos';

  @override
  String get desktopSyncHint => 'Pedir al móvil el historial reciente de chats. Se usa si el ordenador ha estado sin conexión más de 7 días o se acaba de vincular por QR.';

  @override
  String get desktopSyncRunning => 'Sincronizando…';

  @override
  String get desktopSyncAskHistory => 'Pedir el historial';

  @override
  String get desktopSyncAsk => 'Pedir';

  @override
  String get desktopSyncBlobsRunning => 'Descargando adjuntos…';

  @override
  String get desktopSyncBlobsAction => 'Descargar los adjuntos';

  @override
  String get desktopSyncBlobsHint => 'Descarga los medios de los chats recientes cuando faltan los archivos en local (tras volver a vincular o un tiempo largo sin conexión).';

  @override
  String get desktopSyncBlobsShort => 'Descargar';

  @override
  String desktopServerBackupOk(Object stamp, Object size, Object profile) {
    return 'Copia en el servidor ✓ · $stamp · $size KB · perfil $profile';
  }

  @override
  String get desktopServerBackupPassword => 'Contraseña de la copia';

  @override
  String get desktopServerBackupPasswordHint => 'Con esta contraseña se cifra la copia y se restaura en cualquier dispositivo. Recuérdala: sin ella la copia no sirve y no se puede recuperar.';

  @override
  String get desktopServerBackupRepeat => 'Repite la contraseña';

  @override
  String get desktopServerBackupCreate => 'Crear la copia';

  @override
  String get desktopServerBackupTitle => 'Copia de seguridad en el servidor';

  @override
  String get desktopServerBackupHint => 'Una copia cifrada de la cuenta en el servidor de Secretly. Se restaura en cualquier dispositivo con «Restaurar desde el servidor» usando tu Secretly ID y la contraseña.';

  @override
  String get desktopServerBackupLoading => 'Subiendo…';

  @override
  String get desktopServerBackupCreateOnServer => 'Crear una copia en el servidor';

  @override
  String get desktopServerBackupUpdate => 'Actualizar la copia';

  @override
  String desktopFailedWith(Object error) {
    return 'No se pudo: $error';
  }

  @override
  String get desktopStorageDeleteModelTitle => '¿Eliminar el modelo de reconocimiento?';

  @override
  String get desktopStorageDeleteModelBody => 'La transcripción de los mensajes de voz dejará de funcionar hasta que el modelo se descargue de nuevo.';

  @override
  String get desktopStorageModelDeleted => 'Se ha eliminado el modelo';

  @override
  String desktopStorageDeleteFailed(Object error) {
    return 'No se pudo eliminar: $error';
  }

  @override
  String desktopStorageKb(Object value) {
    return '$value KB';
  }

  @override
  String desktopStorageMb(Object value) {
    return '$value MB';
  }

  @override
  String desktopStorageGb(Object value) {
    return '$value GB';
  }

  @override
  String get desktopStorageUsage => 'Uso';

  @override
  String get desktopStorageUsageHint => 'Caché y medios en este dispositivo';

  @override
  String desktopStorageClearHint(Object size) {
    return 'Se liberarán $size. Los mensajes, los archivos que enviaste y los recientes no se eliminan: no habría de dónde recuperarlos.';
  }

  @override
  String get desktopStorageClear => 'Borrar la caché';

  @override
  String get desktopStorageCounting => 'Calculando…';

  @override
  String get desktopStorageSpeechModel => 'Modelo de reconocimiento de voz';

  @override
  String get desktopStorageSpeechModelHint => 'Se usa para transcribir los mensajes de voz en este ordenador, sin enviar el audio a ninguna parte. Un borrado normal de la caché NO lo elimina: es grande y se descarga aparte.';

  @override
  String get desktopStorageDeleteModel => 'Eliminar el modelo';

  @override
  String desktopStorageMedia(Object size) {
    return 'Medios · $size';
  }

  @override
  String desktopStorageVoice(Object size) {
    return 'Voz · $size';
  }

  @override
  String desktopStorageOther(Object size) {
    return 'Otros · $size';
  }

  @override
  String get desktopStorageFree => 'Libre';

  @override
  String desktopStorageTotal(Object size) {
    return 'Total · $size';
  }

  @override
  String desktopAboutVersion(Object version, Object build) {
    return 'Versión $version · compilación $build';
  }

  @override
  String get desktopAboutTagline => 'Un mensajero seguro con cifrado de extremo a extremo. Sin nube. Sin publicidad. Código abierto.';

  @override
  String get desktopAboutLicences => 'Licencias';

  @override
  String get desktopAboutWebsite => 'Sitio web';

  @override
  String get desktopDangerTitle => '¿Eliminar la cuenta de forma irreversible?';

  @override
  String get desktopDangerBody => 'El perfil, las claves, los datos locales y el historial de mensajes se eliminarán en este y otros dispositivos. No hay vuelta atrás.';

  @override
  String get desktopDangerDeleting => 'Eliminando la cuenta…';

  @override
  String desktopDangerFailed(Object error) {
    return 'No se pudo eliminar la cuenta: $error';
  }

  @override
  String get desktopDangerSection => 'Eliminación de la cuenta';

  @override
  String get desktopDangerDemo => 'Modo de demostración · no se puede eliminar sin un perfil conectado.';

  @override
  String get desktopDangerEnterId => 'Escribe tu Secretly ID para confirmar';

  @override
  String desktopDangerEnterIdExact(Object id) {
    return 'Escribe $id para confirmar';
  }

  @override
  String get desktopDangerAction => 'Eliminar la cuenta';

  @override
  String get desktopDangerIrreversible => 'Esta acción es irreversible. Se eliminarán todos tus datos, el historial de mensajes y las claves. No hay vuelta atrás.';

  @override
  String get desktopSecurityE2ee => 'Cifrado de extremo a extremo';

  @override
  String get desktopSecurityE2eeHint => 'Todos los mensajes, llamadas y archivos se cifran en tu dispositivo. Las claves nunca salen de tus dispositivos: el servidor solo ve texto cifrado.';

  @override
  String get desktopSecurityVerifiedDevices => 'Dispositivos verificados';

  @override
  String get desktopSecurityVerifiedHint => 'Mientras esté activado, los mensajes no se envían a los dispositivos no confirmados de la otra persona. Protege frente a suplantaciones, pero un mensaje puede no llegar hasta que confirme uno nuevo. Solo chats individuales: no se aplica a los grupos.';

  @override
  String get desktopSecurityOnlyVerified => 'Solo dispositivos verificados';

  @override
  String get desktopSecurityBlocked => 'Los dispositivos no verificados se bloquean';

  @override
  String get desktopSecurityAllDevices => 'Los mensajes van a todos los dispositivos de la otra persona';

  @override
  String get desktopSecurityAppEntry => 'Entrada a la aplicación';

  @override
  String get desktopSecurityAppEntryHint => 'Una contraseña al abrir Secretly y después de que la ventana haya estado oculta más de un minuto. Se aplica a este ordenador.';

  @override
  String get desktopSecurityPersonalScopeHint => 'Una contraseña aparte para la categoría «Personales». Sin ella, los chats personales quedan abiertos a cualquiera que acceda a un ordenador desbloqueado.';

  @override
  String get desktopCallsInApp => 'Llamadas en la aplicación';

  @override
  String get desktopCallsInAppHint => 'Desactívalo para deshabilitar las llamadas por completo';

  @override
  String get desktopCallsAccept => 'Aceptar llamadas entrantes';

  @override
  String get desktopCallsAcceptHint => 'Podrán llamarte';

  @override
  String get desktopCallsDisabledHint => 'No disponible mientras las llamadas estén desactivadas';

  @override
  String get desktopCallsScreenShare => 'Compartir pantalla';

  @override
  String get desktopCallsScreenShareHint => 'Recibir la pantalla de otra persona es un permiso aparte: puede aparecer algo que no esperabas ver.';

  @override
  String get desktopCallsAcceptScreenShare => 'Aceptar pantalla compartida';

  @override
  String get desktopAccountIdCopied => 'Se ha copiado el Secretly ID';

  @override
  String get desktopAccountIdHint => 'Este identificador es lo que compartes para que te encuentren. No contiene ni número de teléfono ni correo.';

  @override
  String get desktopAccountCopy => 'Copiar';

  @override
  String get desktopAccountProfile => 'Perfil';

  @override
  String get desktopAccountProfileHint => 'Nombre, foto, estado';

  @override
  String get desktopAccountOpenProfile => 'Abrir la página del perfil';

  @override
  String desktopScopePasswordFor(Object name) {
    return 'Contraseña para «$name»';
  }

  @override
  String get desktopScopeMin4 => 'Al menos 4 caracteres';

  @override
  String get desktopScopeOn => 'La protección está activada';

  @override
  String desktopScopeOnFailed(Object error) {
    return 'No se pudo activar: $error';
  }

  @override
  String get desktopScopeOff => 'La protección está desactivada';

  @override
  String desktopScopeOffFailed(Object error) {
    return 'No se pudo desactivar: $error';
  }

  @override
  String get desktopScopePasswordsDiffer => 'Las contraseñas no coinciden';

  @override
  String get desktopScopeTitle => 'Protección con contraseña';

  @override
  String get desktopScopeOnWithPassword => 'Activada: contraseña';

  @override
  String get desktopScopeEnabled => 'Activada';

  @override
  String get desktopScopeDisabled => 'Desactivada';

  @override
  String get desktopScopeChangePassword => 'Cambiar la contraseña';

  @override
  String get desktopScopeLockNow => 'Bloquear';

  @override
  String desktopBlockedUnblocked(Object name) {
    return 'Se ha desbloqueado a $name';
  }

  @override
  String desktopBlockedUnblockFailed(Object error) {
    return 'No se pudo desbloquear: $error';
  }

  @override
  String get desktopBlockedTitle => 'Bloqueados';

  @override
  String get desktopBlockedEmptyHint => 'La lista está vacía. Se bloquea desde el menú de un chat.';

  @override
  String get desktopBlockedHint => 'Estas personas no pueden escribirte ni llamarte.';

  @override
  String get desktopBlockedNone => 'No hay nadie bloqueado';

  @override
  String get desktopSupportSent => 'Se ha enviado el mensaje';

  @override
  String get desktopSupportSendFailed => 'No se pudo enviar. Comprueba tu conexión.';

  @override
  String get desktopSupportUnavailable => 'El soporte no está disponible';

  @override
  String get desktopSupportUnavailableHint => 'El servicio de soporte está desactivado ahora mismo. Inténtalo más tarde o escribe desde el teléfono.';

  @override
  String get desktopSupportThread => 'La conversación con soporte';

  @override
  String get desktopSupportThreadHint => 'Los mensajes se cifran en tu dispositivo. El servidor solo guarda texto cifrado: únicamente el soporte puede leer la conversación.';

  @override
  String get desktopSupportNoReplies => 'Todavía no hay respuestas. Describe el problema: la respuesta llegará aquí.';

  @override
  String get desktopSupportWrite => 'Escribir a soporte';

  @override
  String get desktopSupportWriteHint => 'Se adjuntan automáticamente la versión de la compilación y el identificador del dispositivo: sin ellos el problema es casi imposible de reproducir.';

  @override
  String get desktopSupportDescribe => 'Describe qué ha pasado';

  @override
  String get desktopSupportSending => 'Enviando…';

  @override
  String get desktopSupportSend => 'Enviar';

  @override
  String get desktopChatsEmptyHint => 'Empieza a conversar desde el teléfono: los chats se sincronizan solos con el ordenador';

  @override
  String get desktopChatsPickOne => 'Elige un chat a la izquierda';

  @override
  String desktopChatsSendFailed(Object error) {
    return 'No se pudo enviar: $error';
  }

  @override
  String desktopChatsSendingTo(Object title) {
    return 'Enviando a «$title»';
  }

  @override
  String get desktopChatsFilterAll => 'Todos';

  @override
  String get desktopChatsFilterUnread => 'No leídos';

  @override
  String get desktopChatsFilterGroups => 'Grupos';

  @override
  String get desktopChatsFilterArchive => 'Archivo';

  @override
  String get desktopChatsFilterPersonal => 'Personales';

  @override
  String get desktopChatsRenameFolder => 'Cambiar el nombre de la carpeta';

  @override
  String get desktopChatsDeleteFolder => 'Eliminar la carpeta';

  @override
  String desktopChatsRenameFailed(Object error) {
    return 'No se pudo renombrar: $error';
  }

  @override
  String desktopChatsDeleteFolderTitle(Object name) {
    return '¿Eliminar la carpeta «$name»?';
  }

  @override
  String get desktopChatsDeleteFolderBody => 'Los chats se quedan donde están: solo se elimina la carpeta.';

  @override
  String desktopChatsDeleteFailed(Object error) {
    return 'No se pudo eliminar: $error';
  }

  @override
  String desktopChatsAddedToFolder(Object name) {
    return 'Añadido a «$name»';
  }

  @override
  String desktopChatsRemovedFromFolder(Object name) {
    return 'Quitado de «$name»';
  }

  @override
  String desktopChatsFolderChangeFailed(Object error) {
    return 'No se pudo cambiar la carpeta: $error';
  }

  @override
  String desktopChatsFolderCreated(Object name) {
    return 'Se ha creado la carpeta «$name»';
  }

  @override
  String desktopChatsFolderCreateFailed(Object error) {
    return 'No se pudo crear la carpeta: $error';
  }

  @override
  String get desktopChatsNewFolder => 'Carpeta nueva';

  @override
  String get desktopChatsFolderName => 'Nombre de la carpeta';

  @override
  String desktopChatsRemoveFromFolder(Object name) {
    return 'Quitar de «$name»';
  }

  @override
  String desktopChatsAddToFolder(Object name) {
    return 'A la carpeta «$name»';
  }

  @override
  String get desktopChatsNewFolderWithChat => 'Carpeta nueva con este chat…';

  @override
  String get desktopChatsRemoveFromPersonal => 'Quitar de personales';

  @override
  String get desktopChatsAddToPersonal => 'A personales';

  @override
  String get desktopChatsArchiveEmpty => 'El archivo está vacío';

  @override
  String get desktopChatsNoPersonal => 'No hay chats personales';

  @override
  String get desktopChatsPersonalLocked => 'Los chats personales están protegidos con contraseña';

  @override
  String get desktopChatsAllRead => 'Todo leído';

  @override
  String get desktopChatsFolderEmpty => 'Esta carpeta está vacía por ahora';

  @override
  String get desktopChatsNewChat => 'Chat nuevo';

  @override
  String get desktopChatsNewRoom => 'Sala nueva';

  @override
  String get desktopChatsStartFailed => 'No se pudo iniciar el chat: el perfil no está disponible';

  @override
  String get desktopChatsPhoto => 'Foto';

  @override
  String get desktopChatsVideo => 'Vídeo';

  @override
  String get desktopChatsAudio => 'Audio';

  @override
  String get desktopChatsVoiceMessage => 'Mensaje de voz';

  @override
  String get desktopChatsVoiceShort => 'Voz';

  @override
  String get desktopChatsLink => 'Enlace';

  @override
  String get desktopChatsSticker => 'Pegatina';

  @override
  String desktopChatsStickerWith(Object label) {
    return 'Pegatina $label';
  }

  @override
  String desktopChatsPoll(Object question) {
    return '📊 Encuesta: $question';
  }

  @override
  String get desktopChatsUnknown => 'desconocido';

  @override
  String get desktopChatsMember => 'Miembro';

  @override
  String get desktopChatsSoundOn => 'Activar el sonido';

  @override
  String get desktopChatsSoundOff => 'Sin sonido';

  @override
  String get desktopChatsClearHistoryTitle => '¿Borrar el historial?';

  @override
  String desktopChatsClearHistoryBody(Object title) {
    return 'Se eliminarán todos los mensajes del chat «$title» en este dispositivo.';
  }

  @override
  String get desktopChatsClear => 'Borrar';

  @override
  String get desktopChatsHistoryClearedBoth => 'El historial se ha borrado en ambos lados';

  @override
  String get desktopChatsHistoryCleared => 'Se ha borrado el historial';

  @override
  String get desktopChatsDeleteChatTitle => '¿Eliminar el chat?';

  @override
  String desktopChatsDeleteChatBody(Object title) {
    return 'El chat «$title» se eliminará por completo de este dispositivo.';
  }

  @override
  String get desktopChatsRooms => 'Salas';

  @override
  String get desktopChatsGeneralTopic => 'General';

  @override
  String get desktopChatsNewTopicEllipsis => 'Tema nuevo…';

  @override
  String desktopChatsBranch(Object title) {
    return 'Rama «$title»';
  }

  @override
  String get desktopChatsRename => 'Renombrar';

  @override
  String get desktopChatsIcon => 'Icono';

  @override
  String get desktopChatsDeleteBranch => 'Eliminar la rama';

  @override
  String get desktopChatsBranchIcon => 'Icono de la rama';

  @override
  String get desktopChatsBranchIconHint => 'El icono sustituye a la almohadilla delante del nombre. Los de color prometen lo que hay dentro: verde una llamada, rojo algo urgente. El resto son grises para no competir con el nombre.';

  @override
  String get desktopChatsHash => 'Almohadilla';

  @override
  String desktopChatsBranchFailed(Object error) {
    return 'No se pudieron cambiar las ramas: $error';
  }

  @override
  String get desktopChatsNewTopic => 'Tema nuevo';

  @override
  String get desktopChatsRenameTopic => 'Cambiar el nombre del tema';

  @override
  String get desktopChatsTopicName => 'Nombre del tema';

  @override
  String desktopChatsReactionFailed(Object error) {
    return 'No se pudo guardar la reacción: $error';
  }

  @override
  String desktopChatsReactionLocal(Object error) {
    return 'La reacción se aplicó en local pero no llegó a la otra persona: $error';
  }

  @override
  String get desktopChatsRevealFailed => 'No se pudo mostrar el archivo en Finder';

  @override
  String desktopChatsVideoOpenFailed(Object error) {
    return 'No se pudo abrir el vídeo: $error';
  }

  @override
  String get desktopChatsVideoUnavailable => 'El vídeo no está disponible';

  @override
  String desktopChatsFileFetchFailed(Object error) {
    return 'No se pudo obtener el archivo: $error';
  }

  @override
  String get desktopChatsSaveAttachment => 'Guardar el adjunto';

  @override
  String get desktopChatsFileUnavailable => 'El archivo no está disponible';

  @override
  String desktopChatsSaveFailed(Object error) {
    return 'No se pudo guardar: $error';
  }

  @override
  String desktopChatsOpenFailedWith(Object error) {
    return 'No se pudo abrir el archivo: $error';
  }

  @override
  String get desktopChatsOpenFailed => 'No se pudo abrir el archivo';

  @override
  String desktopChatsOpenFailedShort(Object error) {
    return 'No se pudo abrir: $error';
  }

  @override
  String desktopChatsPlayFailed(Object error) {
    return 'No se pudo reproducir: $error';
  }

  @override
  String get desktopChatsNoCallPeer => 'No se pudo determinar a quién llamar.';

  @override
  String get desktopChatsCallsNotReady => 'El servicio de llamadas no está listo.';

  @override
  String get desktopChatsCallInProgress => 'Ya hay una llamada en curso.';

  @override
  String get desktopChatsEditFailed => 'No se pudo editar el mensaje.';

  @override
  String get desktopChatsNoRecipient => 'No se pudo determinar el destinatario.';

  @override
  String get desktopChatsDeleteMessageTitle => '¿Eliminar el mensaje?';

  @override
  String get desktopChatsDeleteMessagesTitle => '¿Eliminar los mensajes seleccionados?';

  @override
  String get desktopChatsDeleteOthersHint => 'Los mensajes de otras personas se eliminarán solo para ti.';

  @override
  String get desktopChatsDeleteForAll => 'Eliminar para todos';

  @override
  String get desktopChatsDeleteForMeOnly => 'Eliminar solo para mí';

  @override
  String get desktopChatsDeleteForMe => 'Eliminar para mí';

  @override
  String get desktopChatsSavePrivacyBlocked => 'Este mensaje no se puede guardar por restricciones de privacidad.';

  @override
  String get desktopChatsNothingToSave => 'El adjunto no se ha descargado: no hay nada que guardar';

  @override
  String get desktopChatsSavedPartly => 'Guardado en Favoritos, pero no todo';

  @override
  String get desktopChatsSaved => 'Guardado en Favoritos';

  @override
  String get desktopChatsForwardPrivacyBlocked => 'Este mensaje no se puede reenviar por restricciones de privacidad.';

  @override
  String desktopChatsForwardFailed(Object error) {
    return 'No se pudo reenviar: $error';
  }

  @override
  String get desktopChatsNothingToForward => 'El adjunto no se ha descargado: no hay nada que reenviar';

  @override
  String desktopChatsForwardedPartly(Object title) {
    return 'Reenviado a «$title», pero no todo';
  }

  @override
  String desktopChatsForwarded(Object title) {
    return 'Reenviado a «$title»';
  }

  @override
  String desktopChatsFileNotSentElsewhere(Object text) {
    return 'El archivo no se ha enviado a la otra conversación: $text';
  }

  @override
  String get desktopChatsFileSendFailed => 'No se pudo enviar el archivo.';

  @override
  String desktopChatsPremiumFiles(Object text) {
    return '$text Con Premium puedes enviar archivos de hasta 1 GB.';
  }

  @override
  String get desktopChatsTypingEllipsis => 'escribiendo…';

  @override
  String get desktopChatsOnline => 'en línea';

  @override
  String desktopChatsSomeoneTyping(Object name) {
    return '$name está escribiendo';
  }

  @override
  String get desktopChatsLoadingList => 'Cargando la lista desde el almacenamiento local.';

  @override
  String get desktopChatsWillAppear => 'Los mensajes y las llamadas aparecerán aquí en cuanto abras un chat.';

  @override
  String get desktopRoomNoOpenHere => 'Desde aquí no se puede abrir una conversación';

  @override
  String get desktopRoomIdCopied => 'Se ha copiado el ID';

  @override
  String get desktopRoomAwaiting => 'Esperando aprobación';

  @override
  String get desktopRoomBlocked => 'Bloqueado';

  @override
  String get desktopRoomCopied => 'Copiado';

  @override
  String get desktopRoomChangeRole => 'Cambiar el rol';

  @override
  String get desktopRoomTransfer => 'Transferir la propiedad';

  @override
  String get desktopRoomBlockMember => 'Bloquear';

  @override
  String get desktopRoomKick => 'Expulsar';

  @override
  String get desktopRoomKickTitle => '¿Expulsar al miembro?';

  @override
  String desktopRoomKickBody(Object name) {
    return '$name perderá el acceso a la sala. Una invitación nueva lo devuelve.';
  }

  @override
  String get desktopRoomBlockTitle => '¿Bloquear al miembro?';

  @override
  String desktopRoomBlockBody(Object name) {
    return '$name no podrá volver a la sala ni con invitación hasta que se quite el bloqueo.';
  }

  @override
  String get desktopRoomTransferTitle => '¿Transferir la propiedad de la sala?';

  @override
  String desktopRoomTransferBody(Object name) {
    return '$name pasa a ser propietario y tú administrador. Solo el nuevo propietario puede deshacerlo.';
  }

  @override
  String get desktopRoomTransferAction => 'Transferir';

  @override
  String get desktopRoomClearTitle => '¿Borrar el historial?';

  @override
  String get desktopRoomClearBody => 'Se eliminarán todos los mensajes de la sala en este dispositivo.';

  @override
  String get desktopRoomLeaveTitle => '¿Salir de la sala?';

  @override
  String get desktopRoomLeaveBody => 'Dejarás de recibir mensajes. Para volver hará falta una invitación nueva.';

  @override
  String get desktopRoomLeave => 'Salir';

  @override
  String get desktopRoomInvite => 'Invitar';

  @override
  String get desktopRoomCopyId => 'Copiar el ID de la sala';

  @override
  String get desktopRoomMuteOff => 'Desactivar las notificaciones';

  @override
  String get desktopRoomUnarchive => 'Sacar del archivo';

  @override
  String get desktopRoomLeaveRoom => 'Salir de la sala';

  @override
  String get desktopRoomUntitled => 'Sin nombre';

  @override
  String get desktopRoomCopyInvite => 'Copiar la invitación';

  @override
  String get desktopRoomSound => 'Sonido';

  @override
  String get desktopRoomTabInfo => 'Info';

  @override
  String get desktopRoomTabMembers => 'Miembros';

  @override
  String get desktopRoomTabMedia => 'Medios';

  @override
  String get desktopRoomTopics => 'TEMAS';

  @override
  String desktopRoomTopicsCount(Object count) {
    return 'TEMAS · $count';
  }

  @override
  String get desktopRoomDescription => 'Descripción';

  @override
  String get desktopRoomNotes => 'NOTAS';

  @override
  String get desktopRoomInformation => 'Información';

  @override
  String get desktopRoomId => 'ID de la sala';

  @override
  String get desktopRoomInviteLink => 'Enlace de invitación · haz clic para copiar';

  @override
  String get desktopRoomFavouriteHint => 'Una ficha en la barra y un lugar arriba en la lista';

  @override
  String get desktopRoomArchiveHint => 'Ocultar la sala de la lista principal';

  @override
  String get desktopRoomNoMembers => 'Sin miembros';

  @override
  String desktopRoomMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count miembros',
      one: '$count miembro',
    );
    return '$_temp0';
  }

  @override
  String get desktopRoomNobodyFound => 'No se ha encontrado a nadie';

  @override
  String get desktopRoomMembersUnavailable => 'La lista de miembros no está disponible.';

  @override
  String get desktopRoomInCall => 'EN LA LLAMADA';

  @override
  String get desktopRoomOnline => 'EN LÍNEA';

  @override
  String get desktopRoomOffline => 'SIN CONEXIÓN';

  @override
  String desktopRoomMoreHidden(Object count) {
    return '$count más: usa la búsqueda de arriba';
  }

  @override
  String get desktopRoomSearchMember => 'Buscar un miembro';

  @override
  String get desktopRoomJoinRequests => 'Solicitudes de acceso';

  @override
  String get desktopRoomAccept => 'Aceptar';

  @override
  String get desktopRoomDecline => 'Rechazar';

  @override
  String get desktopRoomRoleOwner => 'Propietario';

  @override
  String get desktopRoomRoleAdmin => 'Administrador';

  @override
  String get desktopRoomRoleModerator => 'Moderador';

  @override
  String get desktopRoomRoleRestricted => 'Restringido';

  @override
  String get desktopRoomRoleGuest => 'Invitado';

  @override
  String get desktopContactBlockTitle => '¿Bloquear?';

  @override
  String get desktopContactUnblockTitle => '¿Desbloquear?';

  @override
  String get desktopContactBlockBody => 'Esta persona ya no podrá enviarte mensajes ni llamarte.';

  @override
  String get desktopContactUnblockBody => 'Esta persona podrá volver a contactarte.';

  @override
  String get desktopContactBlock => 'Bloquear';

  @override
  String get desktopContactCallsNotReady => 'El servicio de llamadas todavía no está listo';

  @override
  String get desktopContactCallInProgress => 'Ya hay una llamada en curso';

  @override
  String desktopContactCallFailed(Object error) {
    return 'No se pudo iniciar la llamada: $error';
  }

  @override
  String get desktopContactAutoDelete => 'Eliminación automática de mensajes';

  @override
  String get desktopContactAutoDeleteUpdated => 'Se ha actualizado la eliminación automática';

  @override
  String get desktopContactClearBody => 'Se eliminarán todos los mensajes de este chat en este dispositivo.';

  @override
  String get desktopContactDeleteBody => 'El chat se eliminará por completo de este dispositivo.';

  @override
  String get desktopContactOff => 'Desactivado';

  @override
  String get desktopContactDisable => 'Desactivar';

  @override
  String get desktopContactDay1 => '1 día';

  @override
  String get desktopContactDays7 => '7 días';

  @override
  String get desktopContactDays30 => '30 días';

  @override
  String get desktopContactHour1 => '1 hora';

  @override
  String desktopContactMinutes(Object value) {
    return '$value min';
  }

  @override
  String get desktopContactOffline => 'sin conexión';

  @override
  String desktopContactSeenAt(Object time) {
    return 'visto a las $time';
  }

  @override
  String get desktopContactSeenYesterday => 'visto ayer';

  @override
  String desktopContactSeenOn(Object date) {
    return 'visto el $date';
  }

  @override
  String get desktopContactCopyId => 'Copiar el ID';

  @override
  String get desktopContactCopyIdShort => 'Copiar ID';

  @override
  String get desktopContactDisappearing => 'Mensajes que desaparecen';

  @override
  String get desktopContactDeleteChat => 'Eliminar el chat';

  @override
  String get desktopContactCall => 'Llamada';

  @override
  String get desktopContactBlockShort => 'Bloq.';

  @override
  String get desktopContactSecurity => 'Seguridad';

  @override
  String get desktopContactVerify => 'Verificar el contacto';

  @override
  String get desktopContactArchiveHint => 'Ocultar el chat de la lista principal';

  @override
  String get desktopThreadMessageHint => 'Mensaje…';

  @override
  String get desktopThreadPasteFailed => 'No se pudo pegar la imagen';

  @override
  String get desktopThreadNoScheduleEdit => 'Una edición no se puede programar: cambia algo ya enviado';

  @override
  String desktopThreadWillLeave(Object when) {
    return 'Saldrá $when';
  }

  @override
  String desktopThreadSeconds(Object value) {
    return '$value s';
  }

  @override
  String desktopThreadMinutes(Object value) {
    return '$value min';
  }

  @override
  String desktopThreadHours(Object value) {
    return '$value h';
  }

  @override
  String desktopThreadDays(Object value) {
    return '$value d';
  }

  @override
  String desktopThreadWeeks(Object value) {
    return '$value sem';
  }

  @override
  String desktopThreadSelected(Object count) {
    return 'Seleccionados: $count';
  }

  @override
  String get desktopThreadDisappearingOn => 'Los mensajes que desaparecen están activados';

  @override
  String get desktopThreadCallAction => 'Llamar';

  @override
  String get desktopThreadCallRoom => 'Llamada grupal';

  @override
  String get desktopThreadVideoCall => 'Videollamada';

  @override
  String get desktopThreadSearchShortcut => 'Buscar en el chat  Cmd F';

  @override
  String get desktopThreadHideDetails => 'Ocultar los detalles';

  @override
  String get desktopThreadShowDetails => 'Mostrar los detalles';

  @override
  String get desktopThreadMore => 'Más';

  @override
  String get desktopThreadPinned => 'Mensaje fijado';

  @override
  String get desktopThreadNoMatches => 'sin coincidencias';

  @override
  String get desktopThreadSearchHint => 'Buscar en el chat…';

  @override
  String get desktopThreadPrevMatch => 'Anterior (Mayús F3)';

  @override
  String get desktopThreadNextMatch => 'Siguiente (F3)';

  @override
  String get desktopThreadCloseEsc => 'Cerrar (Esc)';

  @override
  String get desktopThreadNewMessages => 'Mensajes nuevos';

  @override
  String desktopThreadUnreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sin leer',
      one: '$count sin leer',
    );
    return '$_temp0';
  }

  @override
  String get desktopThreadToday => 'Hoy';

  @override
  String get desktopThreadYesterday => 'Ayer';

  @override
  String get desktopProfileEmojiStatus => 'Estado con emoji';

  @override
  String get desktopProfileClearStatus => 'Quitar el estado';

  @override
  String desktopProfileApplyFailed(Object error) {
    return 'No se pudo aplicar: $error';
  }

  @override
  String get desktopProfileAvatarFrame => 'Marco del avatar';

  @override
  String get desktopProfileCover => 'Portada del perfil';

  @override
  String get desktopProfileNoFrame => 'Sin marco';

  @override
  String get desktopProfileNoCover => 'Sin portada';

  @override
  String get desktopProfileReadFailed => 'No se pudo leer el archivo';

  @override
  String get desktopProfilePhotoUpdated => 'Se ha actualizado la foto de perfil';

  @override
  String desktopProfilePhotoFailed(Object error) {
    return 'No se pudo actualizar la foto: $error';
  }

  @override
  String desktopProfilePhotoRemoveFailed(Object error) {
    return 'No se pudo quitar la foto: $error';
  }

  @override
  String get desktopProfileMine => 'Mi perfil';

  @override
  String get desktopProfileEdit => 'Editar';

  @override
  String get desktopProfileName => 'Nombre';

  @override
  String get desktopProfileChangePhoto => 'Cambiar la foto';

  @override
  String get desktopProfileFrameShort => 'Marco';

  @override
  String get desktopProfileCoverShort => 'Portada';

  @override
  String get desktopProfileStatus => 'Estado';

  @override
  String get desktopProfileAppearanceHint => 'Tema, acento y fondo del chat';

  @override
  String get desktopProfileAbout => 'Sobre mí';

  @override
  String get desktopProfileEmpty => 'Sin rellenar';

  @override
  String get desktopProfilePhoto => 'Foto de perfil';

  @override
  String get desktopProfileReplacePhoto => 'Sustituir la foto';

  @override
  String get desktopProfilePickPhoto => 'Elegir una foto';

  @override
  String get desktopProfilePickedHere => 'Elegida en este ordenador';

  @override
  String get desktopProfileSyncedWithPhone => 'Sincronizada con el teléfono';

  @override
  String get desktopProfileNotPicked => 'Sin elegir';

  @override
  String get desktopProfileRemovePhoto => 'Quitar la foto';

  @override
  String get desktopProfileInitialsStay => 'Quedarán las iniciales';

  @override
  String get desktopProfileAccount => 'Cuenta';

  @override
  String get desktopProfileRecovery => 'Recuperación';

  @override
  String get desktopProfileRecoveryHint => 'Este ordenador está vinculado al teléfono y no guarda su propia frase de recuperación: la copia y la clave de recuperación devuelven la cuenta.';

  @override
  String get desktopProfileDevicesHint => 'Ordenadores y teléfonos conectados';

  @override
  String get desktopProfileFrameCaps => 'MARCO DEL AVATAR';

  @override
  String get desktopGalleryMedia => 'Medios';

  @override
  String get desktopGalleryFiles => 'Archivos';

  @override
  String get desktopGalleryLinks => 'Enlaces';

  @override
  String get desktopGalleryNoMedia => 'Sin medios';

  @override
  String get desktopGalleryNoFiles => 'Sin archivos';

  @override
  String get desktopGalleryNoAudio => 'Sin audio';

  @override
  String get desktopGalleryNoLinks => 'Sin enlaces';

  @override
  String get desktopGalleryPathCopied => 'Se ha copiado la ruta';

  @override
  String get desktopGalleryOpen => 'Abrir';

  @override
  String get desktopGalleryView => 'Ver';

  @override
  String get desktopGalleryOpenInSystem => 'Abrir en el sistema';

  @override
  String get desktopGalleryRevealFinder => 'Mostrar en Finder';

  @override
  String get desktopGalleryRevealExplorer => 'Mostrar en el Explorador';

  @override
  String get desktopGalleryOpenFolder => 'Abrir la carpeta';

  @override
  String get desktopGalleryCopyPath => 'Copiar la ruta';

  @override
  String desktopGalleryBytes(Object value) {
    return '$value B';
  }

  @override
  String get desktopGalleryZeroBytes => '0 B';

  @override
  String desktopOutgoingFolderSingle(Object name) {
    return 'la carpeta «$name» no se puede enviar';
  }

  @override
  String get desktopOutgoingFoldersMany => 'las carpetas no se pueden enviar';

  @override
  String desktopOutgoingTooLargeOne(Object name, Object limit) {
    return '«$name» supera $limit MB';
  }

  @override
  String desktopOutgoingTooLargeMany(int count, Object limit) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos superan $limit MB',
      one: '$count archivo supera $limit MB',
    );
    return '$_temp0';
  }

  @override
  String desktopOutgoingEmptyOne(Object name) {
    return '«$name» está vacío';
  }

  @override
  String desktopOutgoingEmptyMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos están vacíos',
      one: '$count archivo está vacío',
    );
    return '$_temp0';
  }

  @override
  String desktopOutgoingUnreadableOne(Object name) {
    return 'no se pudo leer «$name»';
  }

  @override
  String desktopOutgoingUnreadableMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'no se pudieron leer $count archivos',
      one: 'no se pudo leer $count archivo',
    );
    return '$_temp0';
  }

  @override
  String get desktopOutgoingSending => 'Envío';

  @override
  String desktopOutgoingPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fotos',
      one: '$count fotos',
    );
    return '$_temp0';
  }

  @override
  String desktopOutgoingVideos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vídeos',
      one: '$count vídeos',
    );
    return '$_temp0';
  }

  @override
  String desktopOutgoingMedia(Object count) {
    return '$count medios';
  }

  @override
  String desktopOutgoingAudios(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count audios',
      one: '$count audios',
    );
    return '$_temp0';
  }

  @override
  String desktopOutgoingFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos',
      one: '$count archivos',
    );
    return '$_temp0';
  }

  @override
  String get desktopCallsPickOne => 'Elige una llamada a la izquierda';

  @override
  String get desktopCallsPickHint => 'Aquí aparecerán los detalles y un botón para devolver la llamada';

  @override
  String get desktopCallsNone => 'Todavía no hay llamadas';

  @override
  String get desktopCallsNoneHint => 'El historial aparecerá tras la primera llamada';

  @override
  String get desktopCallsOutgoing => 'Saliente';

  @override
  String get desktopCallsIncoming => 'Entrante';

  @override
  String get desktopCallsGroup => 'grupal';

  @override
  String get desktopCallsVideoKind => 'vídeo';

  @override
  String get desktopCallsAudioKind => 'audio';

  @override
  String get desktopCallsMissed => 'perdida';

  @override
  String desktopPhotoCopyFailed(Object error) {
    return 'No se pudo copiar: $error';
  }

  @override
  String get desktopPhotoSave => 'Guardar la foto';

  @override
  String get desktopPhotoSaved => 'Guardado';

  @override
  String desktopPhotoRevealFailed(Object error) {
    return 'No se pudo mostrar en Finder: $error';
  }

  @override
  String get desktopPhotoLoadFailed => 'No se pudo cargar';

  @override
  String get desktopPhotoZoomOut => 'Alejar';

  @override
  String get desktopPhotoZoomReset => 'Restablecer el zoom';

  @override
  String get desktopPhotoZoomIn => 'Acercar';

  @override
  String get desktopPhotoCopy => 'Copiar';

  @override
  String desktopBubbleForwardedFrom(Object from) {
    return 'Reenviado de $from';
  }

  @override
  String get desktopBubbleAudioFile => 'Archivo de audio';

  @override
  String get desktopBubbleTranslating => 'Traduciendo…';

  @override
  String get desktopBubbleTranslation => 'TRADUCCIÓN';

  @override
  String get desktopBubbleEdited => 'editado';

  @override
  String get desktopBubbleMoreReactions => 'Más reacciones';

  @override
  String get desktopBubbleRoleOwner => 'propietario';

  @override
  String get desktopBubbleRoleAdmin => 'admin';

  @override
  String get desktopBubbleRoleMod => 'mod';

  @override
  String get desktopBubbleSpeed => 'Velocidad de reproducción';

  @override
  String get desktopSpotlightGoChats => 'Ir a los chats';

  @override
  String get desktopSpotlightGoRooms => 'Ir a las salas';

  @override
  String get desktopSpotlightGoContacts => 'Ir a los contactos';

  @override
  String get desktopSpotlightGoCalls => 'Ir a las llamadas';

  @override
  String get desktopSpotlightSelect => 'seleccionar';

  @override
  String get desktopSpotlightOpen => 'abrir';

  @override
  String get desktopSpotlightClose => 'cerrar';

  @override
  String get desktopSpotlightRoom => 'Sala';

  @override
  String get desktopSpotlightMessage => 'Mensaje';

  @override
  String get desktopSpotlightCommand => 'Comando';

  @override
  String get desktopComposerCancelRec => 'Cancelar la grabación';

  @override
  String desktopComposerRecording(Object time) {
    return 'Grabando  $time';
  }

  @override
  String get desktopComposerSendVoice => 'Enviar el mensaje de voz';

  @override
  String get desktopComposerAttach => 'Adjuntar';

  @override
  String get desktopComposerEmoji => 'Emojis y pegatinas';

  @override
  String get desktopComposerRecordVoice => 'Grabar un mensaje de voz';

  @override
  String get desktopComposerEnterSends => 'Enter envía · Shift+Enter salta de línea';

  @override
  String get desktopComposerEnterNewline => 'Enter salta de línea · Shift+Enter envía';

  @override
  String get desktopComposerEditing => 'Edición';

  @override
  String desktopComposerReplyTo(Object name) {
    return 'Respuesta · $name';
  }

  @override
  String get desktopComposerCancelAction => 'Cancelar';

  @override
  String get desktopComposerSendHint => 'Enviar · Enter\nClic derecho para enviar más tarde';

  @override
  String get desktopComposerWriteFirst => 'Escribe primero un mensaje';

  @override
  String desktopComposerToTopic(Object title) {
    return 'al tema «$title»';
  }

  @override
  String get desktopShortcutsNavigation => 'Navegación';

  @override
  String get desktopShortcutsTabs => 'Chats · Salas · Llamadas · Contactos';

  @override
  String get desktopShortcutsSearchAll => 'Buscar en chats y mensajes';

  @override
  String get desktopShortcutsPrevNext => 'Chat anterior / siguiente';

  @override
  String get desktopShortcutsInChat => 'En una conversación';

  @override
  String get desktopShortcutsFindHere => 'Buscar en esta conversación';

  @override
  String get desktopShortcutsSend => 'Enviar (configurable)';

  @override
  String get desktopShortcutsNewline => 'Salto de línea';

  @override
  String get desktopShortcutsPaste => 'Pegar una imagen del portapapeles';

  @override
  String get desktopShortcutsApp => 'Aplicación';

  @override
  String get desktopShortcutsThisHelp => 'Esta ayuda';

  @override
  String get desktopShortcutsCloseWindow => 'Cerrar la ventana o la búsqueda';

  @override
  String get desktopShortcutsTray => 'Minimizar a la bandeja';

  @override
  String get desktopShortcutsTitle => 'Atajos de teclado';

  @override
  String get desktopMediaCancelSend => 'Cancelar el envío';

  @override
  String get desktopMediaSending => 'Enviando…';

  @override
  String desktopMediaSendingOf(Object total) {
    return 'Enviando… · $total';
  }

  @override
  String get desktopMediaRetryDownload => 'Reintentar la descarga';

  @override
  String get desktopMediaImage => 'Imagen';

  @override
  String desktopMediaDownloading(Object size) {
    return 'Descargando… · $size';
  }

  @override
  String get desktopMediaDownload => 'Descargar';

  @override
  String get desktopSendAsMedia => 'Enviar como medios';

  @override
  String get desktopSendAsFiles => 'Enviar como archivos';

  @override
  String get desktopSendUngroup => 'No agrupar';

  @override
  String get desktopSendGroup => 'Agrupar';

  @override
  String get desktopSendAddFiles => 'Añadir archivos…';

  @override
  String get desktopSendDropHere => 'Suelta para añadir';

  @override
  String get desktopSendCloseEsc => 'Cerrar · Esc';

  @override
  String desktopSendToDestination(Object destination) {
    return 'a «$destination»';
  }

  @override
  String get desktopSendCaptionHint => 'Añadir un pie…';

  @override
  String get desktopSendEmoji => 'Emojis';

  @override
  String get desktopSendRemove => 'Quitar';

  @override
  String get desktopSendEnter => 'Enviar · Enter';

  @override
  String get desktopSendShiftEnter => 'Enviar · Shift+Enter';

  @override
  String get desktopCallCtlMicOff => 'Desactivar el micrófono   ⌘D';

  @override
  String get desktopCallCtlMicOn => 'Activar el micrófono   ⌘D';

  @override
  String get desktopCallCtlCamOff => 'Desactivar la cámara   ⌘E';

  @override
  String get desktopCallCtlCamOn => 'Activar la cámara   ⌘E';

  @override
  String get desktopCallCtlShareStop => 'Detener la pantalla compartida';

  @override
  String get desktopCallCtlShare => 'Compartir pantalla';

  @override
  String get desktopCallCtlHandDown => 'Bajar la mano';

  @override
  String get desktopCallCtlHandUp => 'Levantar la mano';

  @override
  String get desktopCallCtlHangUp => 'Colgar   ⌘W';

  @override
  String desktopAbsenceDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count días',
      one: '$count día',
    );
    return '$_temp0';
  }

  @override
  String desktopAbsencePastFanout(Object days) {
    return 'Este ordenador lleva $days sin conectarse. En ese tiempo los remitentes dejaron de cifrar mensajes para él, y parte del historial no llegará aquí. En el teléfono está intacto: abre allí los chats que necesites y el historial reciente se sincronizará.';
  }

  @override
  String desktopAbsenceWithinWindow(Object days) {
    return 'Este ordenador lleva $days sin conectarse. Los mensajes se guardan una semana en el servidor, así que algunos pueden no haberse conservado para él. En el teléfono están intactos.';
  }

  @override
  String get desktopAbsenceGotIt => 'Entendido';

  @override
  String get desktopNavContacts => 'Contactos';

  @override
  String get desktopChatNotFound => 'No se ha encontrado la conversación';

  @override
  String desktopUnreadTitle(Object count) {
    return 'Secretly — $count sin leer';
  }

  @override
  String get desktopRoomsNone => 'Todavía no hay salas';

  @override
  String get desktopRoomsNoneHint => 'Crea una sala desde el teléfono: aparecerá aquí automáticamente';

  @override
  String get desktopRoomsPickOne => 'Elige una sala a la izquierda';

  @override
  String get desktopScheduleTitle => 'Enviar más tarde';

  @override
  String get desktopScheduleInHour => 'Dentro de una hora';

  @override
  String get desktopScheduleTonight => 'Hoy a las 19:00';

  @override
  String get desktopScheduleTomorrow => 'Mañana a las 9:00';

  @override
  String get desktopScheduleInWeek => 'Dentro de una semana';

  @override
  String desktopScheduleTodayAt(Object time) {
    return 'hoy a las $time';
  }

  @override
  String desktopScheduleTomorrowAt(Object time) {
    return 'mañana a las $time';
  }

  @override
  String desktopScheduleOnAt(Object date, Object time) {
    return '$date a las $time';
  }

  @override
  String get desktopScheduleHint => 'El mensaje se enviará solo a la hora elegida: incluso con la ventana cerrada, saldrá en el siguiente arranque.';

  @override
  String get desktopSchedulePickTime => 'Elegir la hora…';

  @override
  String get desktopDevicesSearching => 'Buscando dispositivos…';

  @override
  String get desktopDevicesNoCameras => 'No se han encontrado cámaras. Puede que la aplicación no tenga acceso en los ajustes del sistema.';

  @override
  String get desktopDevicesNoMics => 'No se han encontrado micrófonos. Puede que la aplicación no tenga acceso en los ajustes del sistema.';

  @override
  String get desktopDevicesOutputHint => 'A dónde sale el sonido se elige dentro de la llamada, con el chevrón junto a «Micrófono». Ahí mismo la aplicación cambia sola a los auriculares cuando se conectan.';

  @override
  String get desktopDevicesSystemDefault => 'Según el sistema';

  @override
  String get desktopRailSettings => 'Ajustes   Cmd ,';

  @override
  String get desktopRailConnected => 'Conectado';

  @override
  String get desktopRailConnecting => 'Conectando…';

  @override
  String get desktopRailOffline => 'Sin conexión';

  @override
  String desktopRailProfile(Object status) {
    return 'Perfil   Cmd P   ·   $status';
  }

  @override
  String get desktopEmojiSmileys => 'Caritas y emociones';

  @override
  String get desktopEmojiPeople => 'Personas y cuerpo';

  @override
  String get desktopEmojiNature => 'Naturaleza';

  @override
  String get desktopEmojiFood => 'Comida y bebida';

  @override
  String get desktopEmojiTravel => 'Viajes';

  @override
  String get desktopEmojiActivities => 'Actividades';

  @override
  String get desktopEmojiObjects => 'Objetos';

  @override
  String get desktopEmojiSymbols => 'Símbolos';

  @override
  String get desktopEmojiFlags => 'Banderas';

  @override
  String get desktopEmojiOther => 'Otros';

  @override
  String get desktopLockedTitle => 'Secretly está bloqueado';

  @override
  String get desktopLockedTouchIdPrompt => 'Confirma tu identidad con Touch ID para continuar.';

  @override
  String get desktopLockedPasswordPrompt => 'Confirma con la contraseña del dispositivo para continuar.';

  @override
  String get desktopLockedUnlock => 'Desbloquear';

  @override
  String get desktopLockedWaiting => 'Esperando confirmación…';

  @override
  String get desktopLockedFailed => 'No se pudo confirmar tu identidad.';

  @override
  String get desktopLockedNoService => 'El servicio de identidad no está disponible en este ordenador. Reinicia Secretly o el ordenador. Si no ayuda, escribe a soporte desde el teléfono.';

  @override
  String get desktopEmojiTabEmoji => 'Emojis';

  @override
  String get desktopEmojiTabStickers => 'Stickers';

  @override
  String get desktopEmojiRecents => 'Recientes';

  @override
  String get desktopEmojiNothingFound => 'No se encontró nada';

  @override
  String get desktopEmojiSearchHint => 'Buscar emojis';

  @override
  String get desktopStickersSearchHint => 'Buscar stickers';

  @override
  String get desktopGifSearchHint => 'Buscar GIF';

  @override
  String get desktopGifUnavailable => 'Los GIF no están disponibles en esta ventana';

  @override
  String get desktopStickerPacksSoon => 'Packs de stickers muy pronto';

  @override
  String get desktopCallFullscreen => 'Pantalla completa';

  @override
  String get desktopCallExitFullscreen => 'Salir de pantalla completa';

  @override
  String get desktopCallDialing => 'Llamando…';

  @override
  String get desktopCallEnded => 'Finalizada';

  @override
  String desktopCallEncryptedFor(Object duration) {
    return 'Cifrada · $duration';
  }

  @override
  String get desktopCallReturn => 'Volver';

  @override
  String get desktopCallInProgress => 'Llamada en curso';

  @override
  String desktopCallInProgressWith(Object title) {
    return 'Llamada en curso · $title';
  }

  @override
  String get desktopCallAnswer => 'Responder';

  @override
  String get desktopCallAnswerVideo => 'Responder con vídeo';

  @override
  String get desktopCallAnswerText => 'Por texto';

  @override
  String get desktopTimeYesterday => 'ayer';

  @override
  String get desktopForwardTitle => 'Reenviar a…';

  @override
  String get desktopForwardSearchHint => 'Buscar chat o sala';

  @override
  String get desktopForwardNoChats => 'No hay chats disponibles';

  @override
  String get desktopForwardKindDirect => 'Chat directo';

  @override
  String get desktopContactsSearchHint => 'Buscar contactos';

  @override
  String get desktopContactsEmpty => 'Los contactos aparecerán tras la sincronización.';

  @override
  String desktopContactsNothingFor(Object query) {
    return 'No se encontró nada para «$query».';
  }

  @override
  String get desktopContactsPick => 'Elige un contacto';

  @override
  String get desktopContactsCardRight => 'La ficha aparecerá a la derecha.';

  @override
  String get desktopContactsWrite => 'Enviar mensaje';

  @override
  String get desktopVideoTitle => 'Vídeo';

  @override
  String get desktopViewerCloseEsc => 'Cerrar  Esc';

  @override
  String get desktopVideoPlayFailed => 'No se pudo reproducir el vídeo';

  @override
  String get desktopKeySpace => 'Espacio';

  @override
  String get desktopWindowMinimize => 'Minimizar';

  @override
  String get desktopWindowMaximize => 'Maximizar';

  @override
  String get desktopWindowClose => 'Cerrar';

  @override
  String get desktopWindowBack => 'Atrás';

  @override
  String get desktopWindowForward => 'Adelante';

  @override
  String get desktopSearchEverything => 'Chats, personas, mensajes, archivos';

  @override
  String get desktopUnitB => 'B';

  @override
  String get desktopUnitKb => 'KB';

  @override
  String get desktopUnitMb => 'MB';

  @override
  String get desktopUnitGb => 'GB';

  @override
  String get desktopUnitTb => 'TB';

  @override
  String get desktopSyncDone => 'Sincronizado';

  @override
  String get desktopSyncSyncing => 'Sincronizando…';

  @override
  String get desktopSyncReconnecting => 'Reconectando…';

  @override
  String get desktopDetailsShare => 'Compartir';

  @override
  String get desktopDetailsHide => 'Ocultar';

  @override
  String get desktopDetailsMore => 'Más';

  @override
  String get desktopDetailsChangeCover => 'Cambiar portada';

  @override
  String desktopDetailsFrame(Object name) {
    return 'Marco «$name»';
  }

  @override
  String get desktopApply => 'Aplicar';

  @override
  String get desktopAccentAppliesTo => 'Botones, selecciones y anillos. La burbuja conserva su propio estilo: se elige más abajo.';

  @override
  String get desktopTranslateUnknownSource => 'No se pudo detectar el idioma del mensaje';

  @override
  String get desktopTranslateUnsupported => 'El traductor del sistema no conoce este par de idiomas';

  @override
  String get desktopTranslateNeedsDownload => 'El idioma no está descargado. Ajustes del Sistema → General → Idioma y región → Idiomas de traducción';

  @override
  String get desktopTranslateFailed => 'No se pudo traducir';

  @override
  String get desktopNewChatSearchHint => 'Buscar en contactos';

  @override
  String get desktopNewChatNoContacts => 'Aún no hay contactos';

  @override
  String get desktopNewChatNobodyFound => 'No se encontró a nadie';

  @override
  String get desktopMentionEveryone => 'Todos los participantes';

  @override
  String get desktopMentionAdmins => 'Administradores';

  @override
  String get desktopMentionEveryoneHint => 'Llamar a todos en la sala';

  @override
  String get desktopMentionAdminsHint => 'Llamar al propietario y a los administradores';

  @override
  String desktopClearForPeer(Object name) {
    return 'Borrar también el historial de $name';
  }

  @override
  String get desktopClearForPeerHint => 'Los mensajes desaparecerán en su dispositivo y en todos los tuyos. Esto no se puede deshacer.';

  @override
  String get desktopGifNoKey => 'GIF no disponibles: compilación sin clave de GIPHY';

  @override
  String get desktopGifConnectionLost => 'Se perdió la conexión. Inténtalo de nuevo';

  @override
  String get desktopNotesHint => 'Qué recordar de esta conversación…';

  @override
  String get desktopNotesPrivate => 'Solo tú lo ves. No se envía, no aparece en la conversación y no entra en la copia de seguridad: vive en este ordenador, en la misma base cifrada que los mensajes.';

  @override
  String get desktopEmojiSearchShort => 'Buscar emojis…';

  @override
  String get desktopNotifOpen => 'Abrir';

  @override
  String get desktopLinkPreviewLoading => 'Vista previa del enlace…';

  @override
  String get desktopLinkPreviewOff => 'Sin vista previa';

  @override
  String get desktopDropToSend => 'Suelta para enviar';

  @override
  String get desktopDropEncrypted => 'Los archivos se cifran antes de enviarse';

  @override
  String get desktopDetailsPickChat => 'Elige un chat';

  @override
  String get desktopDetailsEmptyHint => 'Los datos de la persona o la sala\naparecerán aquí.';

  @override
  String get desktopMemberWrite => 'Escribir';

  @override
  String get desktopShowPanel => 'Mostrar el panel';

  @override
  String get desktopHidePanel => 'Ocultar el panel';

  @override
  String get desktopNotifOff => 'Las notificaciones están desactivadas';

  @override
  String get desktopSettingsSearchHint => 'Buscar un ajuste';

  @override
  String get desktopUnlockPrompt => 'Desbloquear Secretly';

  @override
  String get desktopEnableLockPrompt => 'Confirma para activar el bloqueo de Secretly';

  @override
  String get desktopRoomsNoneHintDot => 'Crea una sala desde el teléfono: aparecerá aquí sola.';

  @override
  String get desktopSplashLoading => 'Cargando el perfil…';

  @override
  String get desktopOutgoingOnePhoto => 'Foto';

  @override
  String get desktopOutgoingOneVideo => 'Vídeo';

  @override
  String get desktopOutgoingOneAudio => 'Audio';

  @override
  String get desktopOutgoingOneFile => 'Archivo';

  @override
  String get desktopMenuSettings => 'Ajustes…';

  @override
  String get desktopMenuEdit => 'Edición';

  @override
  String get desktopMenuUndo => 'Deshacer';

  @override
  String get desktopMenuRedo => 'Rehacer';

  @override
  String get desktopMenuCut => 'Cortar';

  @override
  String get desktopMenuPaste => 'Pegar';

  @override
  String get desktopMenuSelectAll => 'Seleccionar todo';

  @override
  String get desktopMenuView => 'Visualización';

  @override
  String get desktopMenuWindow => 'Ventana';

  @override
  String get desktopMenuHelp => 'Ayuda';

  @override
  String get desktopMenuWebsite => 'Sitio web de Secretly';
}
