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
}
