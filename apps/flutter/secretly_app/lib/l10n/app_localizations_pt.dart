// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Secretly';

  @override
  String get starting => 'Iniciando…';

  @override
  String get encrypting => 'Criptografando…';

  @override
  String errorPrefix(Object error) {
    return 'Erro: $error';
  }

  @override
  String get settingsTitle => 'Configurações';

  @override
  String get notificationsSection => 'Notificações';

  @override
  String get languageSection => 'Idioma';

  @override
  String get comingSoon => 'Em breve';

  @override
  String get idsTitle => 'IDs';

  @override
  String get profileIdLabel => 'ID do perfil';

  @override
  String get deviceIdLabel => 'ID do dispositivo';

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
  String get openMyId => 'Abrir meu ID';

  @override
  String get close => 'Fechar';

  @override
  String get tabChats => 'Conversas';

  @override
  String get tabGroups => 'Salas';

  @override
  String get tabContacts => 'Contatos';

  @override
  String get tabProfile => 'Perfil';

  @override
  String get accountSection => 'Conta';

  @override
  String get chatsSection => 'Conversas';

  @override
  String get privacySection => 'Privacidade';

  @override
  String get devicesSection => 'Dispositivos';

  @override
  String get systemSection => 'Sistema';

  @override
  String get languageSystemDefault => 'Padrão do sistema';

  @override
  String languageSystemCurrent(Object language) {
    return 'Sistema ($language)';
  }

  @override
  String get languageChooseAppLanguage => 'Escolher idioma do app';

  @override
  String get languageAvailableWave1 => 'Disponível: inglês, russo, ucraniano, espanhol, português (Brasil), francês e alemão. Você também pode seguir o idioma do sistema.';

  @override
  String get languageMessageTranslation => 'Tradução de mensagens';

  @override
  String get languageShowTranslateButton => 'Mostrar botão Traduzir';

  @override
  String get languageTranslateWholeChats => 'Traduzir conversas inteiras';

  @override
  String get favoritesTitle => 'Favoritos';

  @override
  String get favoritesSubtitle => 'Suas notas pessoais';

  @override
  String get favoritesEmptyTitle => 'Ainda não há favoritos';

  @override
  String get favoritesEmptySubtitle => 'Envie mensagens, arquivos e notas para cá para mantê-los privados nos seus dispositivos.';

  @override
  String get favoritesPersonalNotebookLabel => 'Notas pessoais';

  @override
  String get more => 'Mais';

  @override
  String get stickersRecent => 'Stickers recentes';

  @override
  String get searchStickers => 'Buscar stickers';

  @override
  String get noStickersFound => 'Nenhum sticker encontrado';

  @override
  String get noRecentStickers => 'Seus stickers recentes aparecerão aqui';

  @override
  String get cancelSelection => 'Cancelar seleção';

  @override
  String get chatsTitle => 'Conversas';

  @override
  String get newChat => 'Nova conversa';

  @override
  String get openContactsToStartChat => 'Abra Contatos para iniciar uma conversa';

  @override
  String get noChatsYet => 'Ainda não há conversas';

  @override
  String get openDemoChat => 'Abrir conversa de demonstração';

  @override
  String get archive => 'Arquivar';

  @override
  String get unarchive => 'Desarquivar';

  @override
  String get pin => 'Fixar';

  @override
  String get unpin => 'Desafixar';

  @override
  String get clearHistory => 'Limpar histórico';

  @override
  String archiveHeader(Object count) {
    return 'Arquivo ($count)';
  }

  @override
  String deleteChatsConfirmTitle(Object count) {
    return 'Excluir $count conversa(s)?';
  }

  @override
  String get deleteChatsConfirmBody => 'Isso remove as conversas apenas deste dispositivo.';

  @override
  String clearHistoryConfirmTitle(Object count) {
    return 'Limpar histórico de $count conversa(s)?';
  }

  @override
  String get clearHistoryConfirmBody => 'Isso remove as mensagens apenas deste dispositivo.';

  @override
  String get contactsTitle => 'Contatos';

  @override
  String get contactsTab => 'Contatos';

  @override
  String get requestsTab => 'Solicitações';

  @override
  String get addContact => 'Adicionar contato';

  @override
  String get deleteContact => 'Excluir contato';

  @override
  String get noContactsYet => 'Ainda não há contatos';

  @override
  String get noRequests => 'Nenhuma solicitação';

  @override
  String get secretlyIdLabel => 'Secretly ID';

  @override
  String get secretlyIdHint => 'XXXX-XXXX-...-CHECK';

  @override
  String get nameOptionalLabel => 'Nome (opcional)';

  @override
  String get scanContactQrTitle => 'Escanear QR do contato';

  @override
  String get qrMissingSecretlyId => 'O QR não contém um Secretly ID';

  @override
  String get differentServerTitle => 'Servidor diferente';

  @override
  String differentServerBody(Object qrServer, Object appServer) {
    return 'Este QR pertence a outro servidor.\n\nServidor do QR: $qrServer\nEste app: $appServer\n\nInstale o mesmo APK/servidor nos dois telefones.';
  }

  @override
  String get contactActionProfileNotFound => 'O Secretly ID não foi encontrado neste servidor.';

  @override
  String get contactActionTransportBlocked => 'Esta ação está indisponível porque o app está vinculado a outro servidor.';

  @override
  String get contactActionServiceUnavailable => 'O servidor está indisponível agora. Tente novamente em instantes.';

  @override
  String get contactActionCallsDisabled => 'As chamadas estão desativadas nas configurações de privacidade.';

  @override
  String get contactActionCallsDisabledForContact => 'As chamadas estão desativadas para este contato.';

  @override
  String get callServiceUnavailable => 'O serviço de chamadas está indisponível agora.';

  @override
  String get callAlreadyInProgress => 'Outra chamada já está em andamento.';

  @override
  String get callIceUnavailable => 'A configuração segura da chamada está indisponível agora. Tente novamente em instantes.';

  @override
  String get callPermissionDenied => 'O acesso ao microfone ou à câmera está bloqueado. Permita o acesso e tente novamente.';

  @override
  String get callNegotiationFailed => 'Não foi possível estabelecer a chamada segura. Tente novamente.';

  @override
  String get callConnectionInterrupted => 'A conexão da chamada foi interrompida. Tente novamente.';

  @override
  String get callActionGeneric => 'Não foi possível iniciar a chamada. Tente novamente.';

  @override
  String get callEncryptedBadge => 'Criptografia de ponta a ponta';

  @override
  String get incomingVideoCall => 'Chamada de vídeo recebida';

  @override
  String get incomingVoiceCall => 'Chamada de voz recebida';

  @override
  String get callDecline => 'Recusar';

  @override
  String get callConnectionUnstable => 'Conexão instável';

  @override
  String get callNetworkVeryWeak => 'Sinal de rede muito fraco';

  @override
  String get callNetworkWeak => 'Sinal de rede fraco';

  @override
  String get callEnded => 'Chamada encerrada';

  @override
  String get callReplacedByNewerAttempt => 'A chamada foi substituída por uma tentativa mais recente';

  @override
  String get callDeclined => 'Chamada recusada';

  @override
  String get callYouDeclined => 'Você recusou';

  @override
  String get callNoAnswer => 'Sem resposta';

  @override
  String get callConnectionError => 'Erro de conexão';

  @override
  String get callVideoUnavailable => 'Vídeo indisponível';

  @override
  String get callWaitingForRemoteVideo => 'Aguardando vídeo remoto...';

  @override
  String get callAttachingRemoteVideo => 'Anexando vídeo remoto...';

  @override
  String get callStartingRemoteVideo => 'Iniciando vídeo remoto...';

  @override
  String get callRemoteVideoNotArriving => 'O vídeo remoto não está chegando';

  @override
  String get callRemoteVideoBindFailed => 'Não foi possível vincular o fluxo de vídeo remoto';

  @override
  String get callRemoteVideoNoFrames => 'O vídeo remoto foi anexado, mas os quadros não estão sendo renderizados';

  @override
  String get callMinimize => 'Minimizar';

  @override
  String get callStatusCalling => 'Chamando...';

  @override
  String get callStatusIncoming => 'Recebendo...';

  @override
  String get callStatusConnecting => 'Conectando...';

  @override
  String get callStatusReconnecting => 'Reconectando...';

  @override
  String get callStatusEnded => 'Encerrada';

  @override
  String get callVideoCall => 'Chamada de vídeo';

  @override
  String get callControlMute => 'Silenciar';

  @override
  String get callControlSpeaker => 'Alto-falante';

  @override
  String get callControlCamera => 'Câmera';

  @override
  String get callControlFlip => 'Alternar';

  @override
  String get callControlStop => 'Parar';

  @override
  String get callControlShare => 'Compartilhar';

  @override
  String get callControlEnd => 'Encerrar';

  @override
  String get contactActionGeneric => 'Não foi possível concluir a ação. Tente novamente.';

  @override
  String get notificationTitleRoom => 'Sala';

  @override
  String get notificationTitleRequest => 'Solicitação';

  @override
  String get notificationTitleChat => 'Conversa';

  @override
  String get notificationBodyNewMessage => 'Nova mensagem';

  @override
  String get contactLookupUnavailable => 'A busca está indisponível agora. Tente novamente em instantes.';

  @override
  String addContactFailed(Object error) {
    return 'Falha ao adicionar contato: $error';
  }

  @override
  String deleteContactsConfirmTitle(Object count) {
    return 'Excluir $count contato(s)?';
  }

  @override
  String get deleteContactsConfirmBody => 'As conversas não são excluídas.';

  @override
  String get privacyTitle => 'Privacidade';

  @override
  String get blockedUsersSubtitle => 'Usuários bloqueados não podem entregar mensagens para você (aplicado pelo servidor).';

  @override
  String get noBlockedUsers => 'Nenhum usuário bloqueado';

  @override
  String unblockFailed(Object error) {
    return 'Falha ao desbloquear: $error';
  }

  @override
  String get diagIdentity => 'Identidade';

  @override
  String get diagEndpoints => 'Endpoints';

  @override
  String get diagServerBinding => 'Vinculação ao servidor';

  @override
  String get diagMismatch => 'Incompatibilidade: o perfil pertence a outro servidor. Use Configurações → Redefinir perfil.';

  @override
  String get diagStatus => 'Status';

  @override
  String get diagTimestamps => 'Marcas de tempo';

  @override
  String get diagTips => 'Dicas';

  @override
  String get diagTipsBody => 'Se as mensagens falharem com \"profile not found\":\n1) Verifique se os dois telefones usam o mesmo APK/servidor\n2) Adicione o contato novamente escaneando o QR\n3) Se os endpoints mudaram, use Redefinir perfil\n';

  @override
  String get secretlyUser => 'Usuário do Secretly';

  @override
  String get onlineStatus => 'online';

  @override
  String get edit => 'Editar';

  @override
  String get removePhoto => 'Remover foto';

  @override
  String get profileSectionTitle => 'Perfil';

  @override
  String get myNicknameLabel => 'Meu apelido';

  @override
  String get myNicknameHint => 'ex.: Alex';

  @override
  String get includeNicknameInQr => 'Incluir meu apelido no meu QR';

  @override
  String get includeNicknameInQrSubtitle => 'Desativado por padrão para privacidade. Se ativado, quem escanear poderá atribuir um nome automaticamente a você.';

  @override
  String verifyTitle(Object title) {
    return 'Verificar: $title';
  }

  @override
  String get scanVerifyQrTitle => 'Escanear QR de verificação';

  @override
  String qrBelongsAnotherServer(Object server) {
    return 'O QR pertence a outro servidor: $server';
  }

  @override
  String get qrSecretlyIdMismatch => 'O Secretly ID do QR não corresponde a este contato';

  @override
  String get qrMissingDeviceKeyInfo => 'O QR não contém informações do dispositivo/chave';

  @override
  String get deviceNotCachedTapRefresh => 'Dispositivo não armazenado em cache. Toque em Atualizar primeiro.';

  @override
  String get identityKeyMismatch => 'A identity key não corresponde. Não verifique.';

  @override
  String get verifiedSuccess => 'Verificado ✅';

  @override
  String get refreshKeys => 'Atualizar Keys';

  @override
  String get keysOfflineCannotFetch => 'O serviço Keys está offline. Não é possível obter as chaves do contato agora.';

  @override
  String get devicesLabel => 'Dispositivos';

  @override
  String get noDeviceKeysCachedYet => 'Ainda não há chaves de dispositivos em cache.';

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
  String get unverifiedLower => 'não verificado';

  @override
  String get keysOfflineIdTemporary => 'O serviço Keys está offline. O ID pode ser temporário no modo de desenvolvimento.';

  @override
  String get serverKeysLabel => 'Servidor (Keys)';

  @override
  String get nicknameLabel => 'Apelido';

  @override
  String get identityFingerprintLabel => 'Impressão digital de identidade';

  @override
  String get scanToAddVerifyContact => 'Escaneie para adicionar/verificar este contato';

  @override
  String get mySecretlyId => 'Meu Secretly ID';

  @override
  String get deviceId => 'ID do dispositivo';

  @override
  String get recoveryKit => 'Recovery Kit';

  @override
  String get safeBackupTitle => 'Safe Backup';

  @override
  String get safeBackupSubtitle => 'Safe Backup criptografado armazenado no servidor';

  @override
  String get safeBackupIntro => 'Crie uma cópia criptografada localmente ou no servidor. Você poderá restaurá-la depois a partir de um arquivo ou Secretly ID.';

  @override
  String get safeBackupUploadNow => 'Enviar backup agora';

  @override
  String get safeBackupRestoreFromServer => 'Restaurar do servidor';

  @override
  String get safeBackupRestoreTitle => 'Restaurar do backup no servidor';

  @override
  String get safeBackupRestoreConfirmTitle => 'Restaurar conta?';

  @override
  String get safeBackupRestoreConfirmBody => 'Isso removerá conversas/contatos locais deste dispositivo e restaurará a conta a partir do backup selecionado. O app será reiniciado automaticamente.';

  @override
  String get safeBackupUploaded => 'Backup enviado';

  @override
  String get safeBackupUploadFailed => 'Falha ao enviar backup';

  @override
  String safeBackupUploadFailedWithError(Object error) {
    return 'Falha ao enviar backup: $error';
  }

  @override
  String get safeBackupNotFound => 'Nenhum backup no servidor foi encontrado para este Secretly ID';

  @override
  String get exportRecoveryKit => 'Exportar Recovery Kit';

  @override
  String get exportRecoveryKitSubtitle => 'QR criptografado para recuperação da conta';

  @override
  String get restoreRecoveryKit => 'Restaurar pelo Recovery Kit';

  @override
  String get restoreRecoveryKitSubtitle => 'Apaga os dados locais e restaura este Secretly ID';

  @override
  String get recoveryPasswordTitle => 'Senha do Recovery Kit';

  @override
  String get password => 'Senha';

  @override
  String get confirmPassword => 'Confirmar senha';

  @override
  String get export => 'Exportar';

  @override
  String get scanQr => 'Escanear QR';

  @override
  String get invalidRecoveryKit => 'Recovery Kit inválido';

  @override
  String get wrongPassword => 'Senha incorreta';

  @override
  String get restoreConfirmTitle => 'Restaurar conta?';

  @override
  String get restoreConfirmBody => 'Isso removerá conversas/contatos locais deste dispositivo e restaurará a conta pelo Recovery Kit.';

  @override
  String get restore => 'Restaurar';

  @override
  String get darkTheme => 'Tema escuro';

  @override
  String get darkThemeSubtitle => 'Usar o mesmo tom de destaque no modo escuro.';

  @override
  String get blockUnverified => 'Bloquear envio para contatos não verificados';

  @override
  String get blockUnverifiedSubtitle => 'Modo estrito: em conversas individuais, enviar apenas a contatos cujas chaves você mesmo conferiu. Não se aplica a grupos.';

  @override
  String get blockedUsers => 'Usuários bloqueados';

  @override
  String get resetProfile => 'Redefinir perfil';

  @override
  String get resetProfileSubtitle => 'Corrige incompatibilidade de servidor/conta criando um novo Secretly ID';

  @override
  String get resetProfileDialogTitle => 'Redefinir perfil?';

  @override
  String get resetProfileDialogBody => 'Isso removerá conversas/contatos/solicitações locais deste dispositivo e criará um novo Secretly ID.\n\nUse isto quando você trocar de APK/servidor e as mensagens começarem a falhar.';

  @override
  String get cancel => 'Cancelar';

  @override
  String get ok => 'OK';

  @override
  String get add => 'Adicionar';

  @override
  String get delete => 'Excluir';

  @override
  String get clear => 'Limpar';

  @override
  String get block => 'Bloquear';

  @override
  String get unblock => 'Desbloquear';

  @override
  String get accept => 'Aceitar';

  @override
  String get verify => 'Verificar';

  @override
  String get menu => 'Menu';

  @override
  String get search => 'Buscar';

  @override
  String get queryLabel => 'Consulta';

  @override
  String get messageHint => 'Mensagem';

  @override
  String get notificationActionMarkRead => 'Marcar como lida';

  @override
  String get addCaption => 'Adicionar legenda';

  @override
  String get uploadCanceled => 'Envio cancelado';

  @override
  String get attachmentFinalizeTimeout => 'A rede está instável: o envio terminou, mas a confirmação expirou. Tente novamente.';

  @override
  String get attachmentTransferUnavailable => 'Não foi possível transferir o anexo agora. Verifique internet/servidor e tente novamente.';

  @override
  String get attachmentSendUnavailable => 'O envio de anexos ainda não está pronto. Tente novamente.';

  @override
  String get attachmentContactSyncPending => 'Aguardando sincronização da identidade do contato. Peça ao contato para enviar mais uma mensagem e tente novamente.';

  @override
  String get attachmentContactBlocked => 'Este contato está bloqueado.';

  @override
  String get attachmentRecipientNotFound => 'O perfil do destinatário não foi encontrado neste servidor. Verifique o Secretly ID e confirme se os dois dispositivos usam o mesmo servidor.';

  @override
  String get attachmentRecipientNoDevices => 'O destinatário ainda não tem dispositivos registrados. Peça ao contato para abrir o Secretly e tente novamente.';

  @override
  String get attachmentNoDeliverableDevices => 'Não foi possível entregar o anexo a nenhum dispositivo do destinatário. Tente novamente.';

  @override
  String get attachmentActionGeneric => 'Não foi possível enviar o anexo. Tente novamente.';

  @override
  String get send => 'Enviar';

  @override
  String get attach => 'Anexar';

  @override
  String get photo => 'Foto';

  @override
  String get video => 'Vídeo';

  @override
  String get file => 'Arquivo';

  @override
  String get music => 'Música';

  @override
  String get attachment => 'Anexo';

  @override
  String get downloading => 'Baixando…';

  @override
  String downloadFailed(Object error) {
    return 'Falha no download: $error';
  }

  @override
  String savedTo(Object path) {
    return 'Salvo em: $path';
  }

  @override
  String get noMessagesYet => 'Ainda não há mensagens';

  @override
  String get decrypting => 'Descriptografando…';

  @override
  String get uploading => 'Enviando…';

  @override
  String get uploadTimedOut => 'O envio excedeu o tempo limite. Verifique internet/servidor e tente novamente.';

  @override
  String uploadingBytes(Object sent, Object total) {
    return 'Enviados $sent / $total bytes';
  }

  @override
  String get requestsInfo => 'Esta conversa está em Solicitações. Aceite para responder ou bloqueie para ignorar.';

  @override
  String get verifyRequired => 'Verificação obrigatória';

  @override
  String get verifyContact => 'Verificar contato';

  @override
  String get muteNotifications => 'Silenciar notificações';

  @override
  String get unmuteNotifications => 'Ativar notificações';

  @override
  String get setContactPhoto => 'Definir foto do contato';

  @override
  String get removeContactPhoto => 'Remover foto do contato';

  @override
  String get blockUser => 'Bloquear usuário';

  @override
  String get unblockUser => 'Desbloquear usuário';

  @override
  String get deleteChat => 'Excluir conversa';

  @override
  String get missingRecipient => 'Destinatário ausente';

  @override
  String get contactNotVerified => 'O código de segurança mudou. Confira-o para continuar a escrever.';

  @override
  String get safetyNumberChangedTitle => 'O código de segurança mudou';

  @override
  String get safetyNumberChangedBody => 'Você já tinha conferido o código deste contato. Agora as chaves são novas — costuma acontecer depois de reinstalar o app ou trocar de telefone. A conversa continua criptografada de qualquer forma. Compare o código de novo se quiser ter certeza de que ainda é a mesma pessoa.';

  @override
  String get safetyNumberStrictBody => 'Você ativou “Bloquear envio a não verificados”. Compare o código deste contato para enviar mensagens.';

  @override
  String get sendAnyway => 'Enviar mesmo assim';

  @override
  String get alsoDeleteChat => 'Excluir conversa também';

  @override
  String get unblockUserConfirmTitle => 'Desbloquear usuário?';

  @override
  String get blockUserConfirmTitle => 'Bloquear usuário?';

  @override
  String get deleteChatConfirmTitle => 'Excluir conversa?';

  @override
  String get deleteChatConfirmBody => 'Isso remove a conversa apenas deste dispositivo.';

  @override
  String attachFailed(Object error) {
    return 'Falha ao anexar: $error';
  }

  @override
  String sendFailed(Object error) {
    return 'Falha ao enviar: $error';
  }

  @override
  String actionFailed(Object error) {
    return 'Falha na ação: $error';
  }

  @override
  String get roomPolicyNotMember => 'Você não é mais participante desta sala.';

  @override
  String get roomPolicyAdminsOnly => 'Apenas proprietários e administradores da sala podem fazer isso.';

  @override
  String get roomPolicyTextMessagesDisabled => 'Seu papel não pode enviar mensagens de texto nesta sala.';

  @override
  String get roomPolicyMediaDisabled => 'Seu papel não pode enviar mídia nesta sala.';

  @override
  String get roomPolicyReactionsDisabled => 'As reações estão desativadas nesta sala.';

  @override
  String get roomPolicyReactionNotAllowed => 'Esta reação não é permitida nesta sala.';

  @override
  String get roomPolicyPinDenied => 'Apenas administradores podem fixar mensagens nesta sala.';

  @override
  String get roomPolicyAddMembersDenied => 'Apenas administradores podem adicionar participantes a esta sala.';

  @override
  String get roomPolicyChangeInfoDenied => 'Apenas administradores podem alterar o perfil do grupo.';

  @override
  String roomPolicySlowMode(Object seconds) {
    return 'O modo lento está ativado. Tente novamente em ${seconds}s.';
  }

  @override
  String get noMatches => 'Nenhum resultado';

  @override
  String attachmentTooLarge(Object mb) {
    return 'O anexo é grande demais ($mb MB).';
  }

  @override
  String get attachmentFileMissing => 'O arquivo não está mais disponível.';

  @override
  String foundPrefix(Object hit) {
    return 'Encontrado: $hit';
  }

  @override
  String get contactDetailsChat => 'Conversa';

  @override
  String get contactDetailsSound => 'Som';

  @override
  String get contactDetailsCall => 'Chamada';

  @override
  String get contactDetailsVideo => 'Vídeo';

  @override
  String get contactDetailsUsernameLabel => 'Nome de usuário';

  @override
  String get contactDetailsAddToContacts => 'Adicionar aos contatos';

  @override
  String get contactDetailsMediaTab => 'Mídia';

  @override
  String get contactDetailsFilesTab => 'Arquivos';

  @override
  String get contactDetailsNoMedia => 'Sem mídia';

  @override
  String get contactDetailsNoFiles => 'Sem arquivos';

  @override
  String get contactDetailsStatusRecently => 'visto recentemente';

  @override
  String contactDetailsStatusAt(Object time) {
    return 'visto às $time';
  }

  @override
  String get contactDetailsAutoDelete => 'Exclusão automática';

  @override
  String get contactDetailsShareContact => 'Compartilhar contato';

  @override
  String get contactDetailsEditContact => 'Editar contato';

  @override
  String get contactDetailsDeleteContact => 'Excluir contato';

  @override
  String get contactDetailsSendGift => 'Enviar presente';

  @override
  String get contactDetailsStartSecretChat => 'Iniciar conversa secreta';

  @override
  String get contactDetailsCreateShortcut => 'Criar atalho';

  @override
  String get contactDetailsNameLabel => 'Nome';

  @override
  String get contactDetailsSave => 'Salvar';

  @override
  String get contactDetailsDeleteConfirmTitle => 'Excluir contato?';

  @override
  String get contactAutoDeleteOff => 'Desativado';

  @override
  String get contactAutoDelete1Day => '24 horas';

  @override
  String get contactAutoDelete7Days => '7 dias';

  @override
  String get contactAutoDelete30Days => '30 dias';

  @override
  String get contactEditTitle => 'Editar contato';

  @override
  String get contactEditDone => 'CONCLUÍDO';

  @override
  String get contactEditNameLabel => 'Nome';

  @override
  String get contactEditAssignEmoji => 'Atribuir emoji';

  @override
  String get contactEditClearEmoji => 'Limpar emoji';

  @override
  String get contactEditSetPhoto => 'Definir foto';

  @override
  String get chatMenuReply => 'Responder';

  @override
  String get chatMenuCopy => 'Copiar';

  @override
  String get chatMenuForward => 'Encaminhar';

  @override
  String get chatMenuPin => 'Fixar';

  @override
  String get chatMenuDelete => 'Excluir';

  @override
  String get reset => 'Redefinir';

  @override
  String get diagnostics => 'Diagnóstico';

  @override
  String get diagnosticsSubtitle => 'Status, vinculação, marcas de tempo';

  @override
  String get sendLater => 'Enviar mais tarde';

  @override
  String get sendSilently => 'Enviar sem som';

  @override
  String scheduledSendToday(Object time) {
    return 'Enviar hoje às $time';
  }

  @override
  String scheduledSendOn(Object date, Object time) {
    return 'Enviar em $date às $time';
  }

  @override
  String get repeatNever => 'Nunca';

  @override
  String get repeat => 'Repetir';

  @override
  String get onboardingBackTooltip => 'Voltar';

  @override
  String get onboardingWelcomeTitle => 'Bem-vindo!';

  @override
  String get onboardingWelcomeSubtitle => 'Um mensageiro de nova geração.\nPrivacidade total. Sem compromissos.';

  @override
  String get onboardingCreateAccount => 'Criar nova conta';

  @override
  String get onboardingAlreadyHaveAccount => 'Já tenho uma conta';

  @override
  String get onboardingFeatureE2eTitle => 'Cifragem E2E';

  @override
  String get onboardingFeatureE2eBody => 'As mensagens são cifradas no seu dispositivo. Só você tem as chaves.';

  @override
  String get onboardingFeaturePrivacyTitle => 'Anonimato total';

  @override
  String get onboardingFeaturePrivacyBody => 'Sem número de telefone. Sem ligação a dados pessoais.';

  @override
  String get onboardingFeatureRelayTitle => 'Sem intermediários';

  @override
  String get onboardingFeatureRelayBody => 'O servidor relay não guarda mensagens. Apenas as encaminha.';

  @override
  String get onboardingProfileTitle => 'O seu perfil';

  @override
  String get onboardingProfileSubtitle => 'Como outros utilizadores o verão';

  @override
  String get onboardingProfileNameSection => 'Nome do perfil';

  @override
  String get onboardingProfileNameHint => 'O seu nome ou pseudónimo';

  @override
  String get onboardingNotificationsSection => 'Notificações';

  @override
  String get onboardingMessageNotificationsTitle => 'Notificações de mensagens';

  @override
  String get onboardingMessageNotificationsSubtitle => 'Receber notificações push do Secretly';

  @override
  String get onboardingIncomingCallsTitle => 'Chamadas recebidas';

  @override
  String get onboardingIncomingCallsSubtitle => 'Aceitar chamadas de contactos';

  @override
  String get continueAction => 'Continuar';

  @override
  String get onboardingBackupSaveFailed => 'Não foi possível guardar as definições da cópia de segurança';

  @override
  String get backupPasswordRequirements => 'Use pelo menos 8 caracteres ASCII, uma letra maiúscula e um carácter especial. Sem espaços no início ou no fim.';

  @override
  String backupPasswordTooShort(Object minLength) {
    return 'A palavra-passe deve ter pelo menos $minLength caracteres.';
  }

  @override
  String backupPasswordTooLong(Object maxLength) {
    return 'A palavra-passe não deve ter mais de $maxLength caracteres.';
  }

  @override
  String get backupPasswordNonAscii => 'Use apenas letras latinas, dígitos e símbolos ASCII.';

  @override
  String get backupPasswordOuterWhitespace => 'Remova espaços no início ou no fim da palavra-passe.';

  @override
  String get backupPasswordMissingUppercase => 'Adicione pelo menos uma letra maiúscula A-Z.';

  @override
  String get backupPasswordMissingSpecial => 'Adicione pelo menos um carácter especial, como !, # ou ?.';

  @override
  String get onboardingBackupPasswordTitle => 'Palavra-passe da cópia de segurança';

  @override
  String get onboardingPasswordsDoNotMatch => 'As palavras-passe não coincidem';

  @override
  String get onboardingBackupTitle => 'Cópias de segurança';

  @override
  String get onboardingBackupSubtitle => 'Proteja as suas conversas contra perda de dados.\nMesmo ao mudar de dispositivo.';

  @override
  String get onboardingAutoBackupSection => 'Cópia automática';

  @override
  String get onboardingAutoBackupTitle => 'Cópia automática';

  @override
  String get onboardingAutoBackupSubtitle => 'Guardar automaticamente uma cópia de segurança';

  @override
  String get onboardingStorageTypeSection => 'Tipo de armazenamento';

  @override
  String get onboardingBackupMediaTitle => 'Guardar multimédia';

  @override
  String get onboardingBackupMediaSubtitle => 'Fotografias, vídeos, ficheiros e avatares são incluídos apenas em cópias locais';

  @override
  String get onboardingFrequencySection => 'Frequência';

  @override
  String get onboardingEnterSecretly => 'Entrar no Secretly';

  @override
  String get onboardingSkipBackup => 'Ignorar configuração da cópia';

  @override
  String get onboardingSecretlyIdCopied => 'Secretly ID copiado';

  @override
  String get onboardingRegistrationCompleteTitle => 'Registo concluído';

  @override
  String get onboardingRegistrationCompleteSubtitle => 'Guarde agora o seu Secretly ID. Vai precisar dele para restaurar a conta e a cópia de segurança num novo dispositivo.';

  @override
  String get onboardingYourSecretlyId => 'O seu Secretly ID';

  @override
  String get onboardingCopyId => 'Copiar ID';

  @override
  String get onboardingRecoveryWarning => 'Sem o Secretly ID e a palavra-passe da cópia, será impossível restaurar a cópia do servidor. Guarde o ID num local seguro e não se esqueça da palavra-passe.';

  @override
  String get onboardingStorageCloud => 'Nuvem';

  @override
  String get onboardingStorageCloudSubtitle => 'No servidor Secretly';

  @override
  String get onboardingStorageLocal => 'Local';

  @override
  String get onboardingStorageLocalSubtitle => 'Neste dispositivo';

  @override
  String get onboardingInterval6Hours => '6 horas';

  @override
  String get onboardingInterval12Hours => '12 horas';

  @override
  String get onboardingIntervalEveryDay => 'Todos os dias';

  @override
  String get onboardingIntervalEvery3Days => 'A cada 3 dias';

  @override
  String get onboardingIntervalWeekly => 'Uma vez por semana';

  @override
  String get onboardingBackupLocalCandidate => 'Cópia local do Secretly';

  @override
  String get onboardingDownloads => 'Transferências';

  @override
  String get onboardingDeviceFolder => 'Pasta do dispositivo';

  @override
  String get onboardingNoBackupsFound => 'Não foram encontradas cópias neste dispositivo';

  @override
  String get onboardingFoundBackups => 'Cópias encontradas';

  @override
  String get onboardingNoBackupsFoundBody => 'O Secretly verificou as cópias locais da app e a pasta Transferências. Se o ficheiro estiver noutro local, escolha-o manualmente.';

  @override
  String get chooseManually => 'Escolher manualmente';

  @override
  String get onboardingChooseBackupFileTitle => 'Escolha um ficheiro de cópia do Secretly';

  @override
  String get onboardingReadBackupFailed => 'Não foi possível ler o ficheiro da cópia';

  @override
  String get onboardingServerBackupNotFound => 'A cópia não foi encontrada no servidor';

  @override
  String get onboardingRestoreThisBackupTitle => 'Restaurar esta cópia?';

  @override
  String get onboardingRestoreThisBackupBody => 'Os dados locais atuais neste dispositivo serão substituídos.';

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
    return 'Mensagens: $count';
  }

  @override
  String onboardingChatsSummary(Object count) {
    return 'Conversas: $count';
  }

  @override
  String onboardingMediaFilesSummary(Object count) {
    return 'Ficheiros multimédia: $count';
  }

  @override
  String get onboardingBrokenBackup => 'Ficheiro de cópia danificado ou inválido';

  @override
  String get onboardingRestoreFailed => 'Falha ao restaurar. Tente novamente.';

  @override
  String get onboardingRestoreLoginTitle => 'Entrar na sua conta';

  @override
  String get onboardingRestoreLoginSubtitle => 'Restaure conversas e definições\na partir de uma cópia criada anteriormente.';

  @override
  String get onboardingRestoreMediaSubtitle => 'Para futuras cópias locais: fotografias, vídeos, ficheiros e avatares serão adicionados apenas se isto estiver ativo.';

  @override
  String get onboardingRestoreFromCloudTitle => 'Da nuvem Secretly';

  @override
  String get onboardingRestoreFromCloudSubtitle => 'Introduza o Secretly ID e a palavra-passe da cópia; os dados serão transferidos do servidor';

  @override
  String get onboardingRestoreFromDeviceTitle => 'Encontrar cópia neste dispositivo';

  @override
  String get onboardingRestoreFromDeviceSubtitle => 'O Secretly verificará automaticamente cópias locais e Transferências';

  @override
  String get onboardingRestoring => 'A restaurar...';

  @override
  String get onboardingRestoreFromServerTitle => 'Restaurar do servidor';

  @override
  String get callRecordOutgoingVideoCall => 'Videochamada efetuada';

  @override
  String get callRecordOutgoingCall => 'Chamada efetuada';

  @override
  String get callRecordIncomingVideoCall => 'Videochamada recebida';

  @override
  String get callRecordIncomingCall => 'Chamada recebida';

  @override
  String get callRecordMissedCall => 'Chamada perdida';

  @override
  String get callRecordDeclinedCall => 'Chamada recusada';

  @override
  String get callRecordBusy => 'Ocupado';

  @override
  String get callRecordFailed => 'Falha na chamada';

  @override
  String get callRecordCanceled => 'Chamada cancelada';

  @override
  String get callRecordOngoing => 'Chamada em curso';

  @override
  String get safeBackupInvalidBackup => 'Backup do Secretly inválido';

  @override
  String get recoveryKitPrepareFailed => 'Não foi possível preparar um Recovery Kit neste dispositivo.';

  @override
  String safeBackupPreviewProfileId(String profileId) {
    return 'ID no Secretly: $profileId';
  }

  @override
  String safeBackupPreviewContacts(int count) {
    return 'Contatos: $count';
  }

  @override
  String safeBackupPreviewServer(String server) {
    return 'Servidor: $server';
  }

  @override
  String get safeBackupPreviewTitle => 'Pré-visualização do backup:';

  @override
  String get safeBackupSavedToFiles => 'Backup salvo em Arquivos do Secretly';

  @override
  String get safeBackupExportCanceled => 'Exportação do backup cancelada';

  @override
  String safeBackupExportFailed(Object error) {
    return 'Falha ao exportar o backup: $error';
  }

  @override
  String get safeBackupCreateDialogTitle => 'Criar backup';

  @override
  String get safeBackupServerDestination => 'Backup no servidor';

  @override
  String get safeBackupLocalDestination => 'Backup local';

  @override
  String get safeBackupRestoreDialogTitle => 'Restaurar backup';

  @override
  String get safeBackupRestoreFromDevice => 'Restaurar do dispositivo';

  @override
  String get safeBackupDownloadsLocation => 'Downloads';

  @override
  String get safeBackupDeviceFolderLocation => 'Pasta do dispositivo';

  @override
  String get safeBackupChooseManualHint => 'O Secretly verificou automaticamente os backups locais do app e a pasta Downloads. Se o arquivo estiver em outro lugar, você pode escolhê-lo manualmente.';

  @override
  String get safeBackupChooseManually => 'Escolher manualmente';

  @override
  String safeBackupReadFileFailed(Object error) {
    return 'Não foi possível ler o arquivo de backup: $error';
  }

  @override
  String get safeBackupFrequencyTitle => 'Frequência de salvamento';

  @override
  String get saveAction => 'Salvar';

  @override
  String get safeBackupEnableAutoTitle => 'Ativar backup automático';

  @override
  String get safeBackupEnableAutoSubtitle => 'Roda no app quando há conexão; criptografado com sua senha';

  @override
  String get safeBackupUploadToServer => 'Enviar ao servidor';

  @override
  String get safeBackupSaveOnDevice => 'Salvar neste dispositivo';

  @override
  String get safeBackupPasswordConfigured => 'Senha do backup automático: configurada';

  @override
  String get safeBackupPasswordNotSet => 'Senha do backup automático: não definida';

  @override
  String get safeBackupPasswordSaved => 'Senha do backup automático salva';

  @override
  String genericFailed(Object error) {
    return 'Falha: $error';
  }

  @override
  String get safeBackupSetPassword => 'Definir senha';

  @override
  String get safeBackupPasswordRemoved => 'Senha do backup automático removida';

  @override
  String get safeBackupClearPassword => 'Limpar senha';

  @override
  String get safeBackupRunRequested => 'Backup automático solicitado';

  @override
  String get safeBackupRunNow => 'Executar backup automático agora';

  @override
  String safeBackupLastAutoBackup(String time) {
    return 'Último backup automático: $time';
  }

  @override
  String get safeBackupLastAutoBackupNever => 'Último backup automático: nunca';

  @override
  String safeBackupLastDeviceBackup(String time) {
    return 'Último backup do dispositivo: $time';
  }

  @override
  String safeBackupLastAutoBackupError(Object error) {
    return 'Erro do backup automático: $error';
  }

  @override
  String get securityScopeAppObject => 'o app';

  @override
  String get securityScopePersonalObject => 'conversas pessoais';

  @override
  String get securityUnlockAppTitle => 'Desbloqueie o app';

  @override
  String get securityUnlockPersonalTitle => 'Desbloqueie as conversas pessoais';

  @override
  String get securityUnlockFingerprintAutoSubtitle => 'O desbloqueio por impressão digital começa automaticamente. Se necessário, use sua senha abaixo.';

  @override
  String get securityUnlockBiometricPatternAutoSubtitle => 'A biometria nativa começa automaticamente primeiro. Se necessário, use seu padrão abaixo.';

  @override
  String get securityUnlockNativeSubtitle => 'Confirme o acesso com a autenticação nativa do dispositivo.';

  @override
  String securityUnlockPasswordSubtitle(String scopeName) {
    return 'Digite sua senha para abrir $scopeName.';
  }

  @override
  String securityUnlockPatternSubtitle(String scopeName) {
    return 'Desenhe seu padrão para acessar $scopeName.';
  }

  @override
  String get securityUnlockBiometricSubtitle => 'Confirme sua identidade com a autenticação nativa do dispositivo.';

  @override
  String get securityUnlockAppBiometricReason => 'Autentique-se para desbloquear o app';

  @override
  String get securityUnlockPersonalBiometricReason => 'Autentique-se para abrir as conversas pessoais';

  @override
  String get securityUnlockPasswordMismatch => 'A senha não corresponde. Tente novamente.';

  @override
  String get securityUnlockPatternMismatch => 'O padrão não corresponde.';

  @override
  String get securityUnlockNativeIncomplete => 'A autenticação nativa não foi concluída.';

  @override
  String get securityPasswordContinueHint => 'Digite sua senha para continuar';

  @override
  String get securityUseFingerprint => 'Usar impressão digital';

  @override
  String get securityUsePassword => 'Usar senha';

  @override
  String get securityClearPattern => 'Limpar padrão';

  @override
  String get securityConnectFourDots => 'Conecte pelo menos 4 pontos.';

  @override
  String get securityPasswordMinFourChars => 'Use pelo menos 4 caracteres.';

  @override
  String get securityPasswordsMismatchFull => 'As senhas não correspondem.';

  @override
  String securityPasswordSetupTitle(String scopeName) {
    return 'Senha para $scopeName';
  }

  @override
  String get securityPasswordSetupDescription => 'A senha é armazenada apenas no cofre seguro do dispositivo.';

  @override
  String get securityNewPassword => 'Nova senha';

  @override
  String get securityRepeatPassword => 'Repita a senha';

  @override
  String get securitySavePassword => 'Salvar senha';

  @override
  String get securityPatternSetupInstruction => 'Desenhe um padrão com pelo menos 4 pontos.';

  @override
  String get securityPatternSetupRepeat => 'Repita o padrão para confirmar.';

  @override
  String get securityPatternMinFourDots => 'Use pelo menos 4 pontos.';

  @override
  String get securityPatternMismatchStartOver => 'Os padrões não correspondem. Comece novamente.';

  @override
  String securityPatternSetupTitle(String scopeName) {
    return 'Padrão para $scopeName';
  }

  @override
  String get securityStartOver => 'Começar novamente';

  @override
  String get securityTitle => 'Segurança';

  @override
  String get securityNativeAuthentication => 'Autenticação nativa';

  @override
  String get securityReady => 'Pronto';

  @override
  String get securityUnavailable => 'Indisponível';

  @override
  String get securityNativeAvailableDescription => 'Usada para Face ID, impressão digital e autenticação nativa do dispositivo.';

  @override
  String get securityNativeUnavailableDescription => 'A biometria ou autenticação nativa do dispositivo não está disponível agora.';

  @override
  String get securityAppLockTitle => 'Bloqueio do app';

  @override
  String get securityAppLockDescription => 'Protege a entrada no app e pode bloquear novamente quando o app é ocultado.';

  @override
  String get securityPersonalChatsTitle => 'Conversas pessoais';

  @override
  String get securityPersonalChatsDescription => 'Protege a seção Pessoal oculta e a entrada direta em conversas pessoais.';

  @override
  String get securityAuthEnableAppLockReason => 'Autentique-se para ativar o bloqueio do app';

  @override
  String get securityAuthChangeSettingsReason => 'Autentique-se para alterar as configurações de segurança';

  @override
  String get securityAuthProtectPersonalReason => 'Autentique-se para proteger conversas pessoais';

  @override
  String get securityAuthChangePersonalReason => 'Autentique-se para alterar a proteção das conversas pessoais';

  @override
  String get securityNativeUnavailableError => 'A autenticação nativa não está disponível neste dispositivo.';

  @override
  String get securityBiometricCancelled => 'A confirmação biométrica foi cancelada.';

  @override
  String get securityProtectionMode => 'Modo de proteção';

  @override
  String get securityProtectionModeSubtitle => 'Escolha como o acesso deve ser protegido.';

  @override
  String get securityProtectionModeDescription => 'Senhas e padrões são armazenados apenas como hashes fortes no secure storage. A biometria usa a tela nativa do sistema.';

  @override
  String get securityProtectionOff => 'Desativado';

  @override
  String get securityProtectionOffDescription => 'Acesso sem proteção extra.';

  @override
  String get securityPasswordModeDescription => 'Uma senha dedicada para desbloquear o acesso.';

  @override
  String get securityPatternModeTitle => 'Padrão';

  @override
  String get securityPatternModeDescription => 'Um padrão de pontos semelhante ao bloqueio do Android.';

  @override
  String get securityNativePromptDescription => 'A tela nativa de Face ID, impressão digital ou autenticação do sistema do dispositivo.';

  @override
  String get securityRelockAfterHidden => 'Bloquear novamente quando o app for ocultado';

  @override
  String get securityRelockAfterHiddenDescription => 'Se desativado, a proteção só volta após reiniciar totalmente o app.';

  @override
  String get securityGracePeriod => 'Período antes de bloquear novamente';

  @override
  String get securityGraceUnavailable => 'Indisponível enquanto o bloqueio em segundo plano estiver desativado.';

  @override
  String securityAllowQuickUnlockWith(String method) {
    return 'Permitir desbloqueio rápido com $method';
  }

  @override
  String get securityQuickUnlockSubtitle => 'Mantém a senha ou o padrão como principal método reserva.';

  @override
  String get securityChangePassword => 'Alterar senha';

  @override
  String get securityChangePattern => 'Alterar padrão';

  @override
  String get securityChangeCredentialSubtitle => 'A proteção atual será atualizada assim que o novo segredo for confirmado.';

  @override
  String get securityProtectionActivated => 'A proteção foi ativada imediatamente.';

  @override
  String get securityLockNow => 'Bloquear agora';

  @override
  String get securitySaveChanges => 'Salvar alterações';

  @override
  String get securityGraceImmediately => 'Imediatamente';

  @override
  String securityGraceAfterSeconds(int seconds) {
    return 'Depois de $seconds s';
  }

  @override
  String securityGraceAfterMinutes(int minutes) {
    return 'Depois de $minutes min';
  }

  @override
  String get securityStatusLocked => 'Bloqueado';

  @override
  String get securityStatusUnlocked => 'Desbloqueado';

  @override
  String get securityAfterHide => 'Ao ocultar';

  @override
  String securityGracePill(int seconds) {
    return 'Espera $seconds s';
  }

  @override
  String get securityNoProtection => 'Sem proteção';

  @override
  String get securityNativeBiometrics => 'Biometria nativa';

  @override
  String get securityBiometricFaceFingerprint => 'Face ID / impressão digital';

  @override
  String get securityBiometricFingerprint => 'Impressão digital';

  @override
  String get securityBiometricNativeDeviceAuthentication => 'Autenticação nativa do dispositivo';

  @override
  String get devicesLinkOpenFailed => 'Não foi possível abrir o link no navegador.';

  @override
  String get devicesDesktopDescriptionPrefix => 'Você pode entrar no ';

  @override
  String get devicesDesktopAppLink => 'app Secretly para desktop';

  @override
  String get devicesDesktopDescriptionSuffix => ' usando um código QR.';

  @override
  String get devicesFailureTransportBlocked => 'O transporte está bloqueado para o servidor atual. Coloque telefone e desktop no mesmo servidor e tente novamente.';

  @override
  String get devicesFailureIdentityNotServerBacked => 'A identidade do desktop ainda não está registrada no servidor. Tente novamente em alguns segundos.';

  @override
  String get devicesFailureProfileUnavailable => 'O perfil do desktop ainda não está visível no servidor. Mantenha o app aberto e tente novamente.';

  @override
  String get devicesFailureDeviceUnavailable => 'O dispositivo desktop ainda não está visível no servidor. Mantenha o app aberto, atualize o QR e tente novamente.';

  @override
  String get devicesFailureCompanionRequired => 'O acesso companion para desktop não está ativado para este perfil. Ative no telefone principal e tente novamente.';

  @override
  String get devicesFailureCompanionLimit => 'O limite de dispositivos desktop já está em uso para este perfil. Remova um desktop antigo ou aumente os lugares disponíveis.';

  @override
  String get devicesFailurePrimaryRequired => 'Crie a conta principal no telefone primeiro e depois vincule o desktop com QR.';

  @override
  String get devicesFailureInvalidQr => 'Este QR não é um código de autorização de dispositivo.';

  @override
  String get devicesFailureQrExpired => 'O código QR expirou. Gere um novo no desktop.';

  @override
  String get devicesFailureServerMismatch => 'Este QR pertence a outro servidor. Coloque telefone e desktop no mesmo servidor e tente novamente.';

  @override
  String get devicesFailureProfileMismatch => 'O pacote de sincronização aponta para outro perfil. Gere um novo QR e tente novamente.';

  @override
  String get devicesFailureRequestNotFound => 'A solicitação de sincronização do desktop não foi encontrada ou já expirou. Gere um novo QR.';

  @override
  String get devicesFailureSessionExpired => 'A sessão QR expirou. Gere um novo QR e tente novamente.';

  @override
  String get devicesFailureSessionValidation => 'A validação da sessão QR falhou. Gere um novo QR e tente novamente.';

  @override
  String get devicesFailureStateMismatch => 'O estado da solicitação de sincronização não corresponde mais. Gere um novo QR e tente novamente.';

  @override
  String get devicesFailureDeviceMismatch => 'O pacote de sincronização aponta para outro dispositivo. Gere um novo QR e tente novamente.';

  @override
  String get devicesFailureDeclined => 'A entrada foi recusada no telefone principal. Gere um novo QR para tentar novamente.';

  @override
  String get devicesFailureInvalidPayload => 'Pacote de sincronização do desktop inválido. Gere um novo QR e tente novamente.';

  @override
  String get devicesFailureInterrupted => 'A sincronização segura foi interrompida antes de terminar. Gere um novo QR e tente novamente.';

  @override
  String get devicesNewUser => 'Novo usuário';

  @override
  String get devicesNewUserDesktopConfirm => 'Limpar dados locais e preparar este dispositivo desktop para entrada por QR a partir do telefone principal?';

  @override
  String get devicesNewUserMobileConfirm => 'Limpar o perfil local atual e registrar um novo usuário neste dispositivo?';

  @override
  String get devicesCreateAction => 'Criar';

  @override
  String get devicesScanDeviceQr => 'Escanear QR do dispositivo';

  @override
  String get devicesRequestApproved => 'Solicitação aprovada. Pacote de sincronização enviado ao desktop.';

  @override
  String get devicesRequestDeclined => 'Solicitação recusada. O desktop continuará não autenticado.';

  @override
  String get devicesApproveSignInTitle => 'Aprovar entrada neste dispositivo?';

  @override
  String get devicesConfirmSyncPrimary => 'Confirme a sincronização a partir do dispositivo principal (telefone).';

  @override
  String devicesApprovalDeviceOnly(String name) {
    return 'Dispositivo: $name. A aprovação só é permitida a partir do telefone principal.';
  }

  @override
  String get devicesSyncChats => 'Sincronizar conversas';

  @override
  String get devicesSyncSettings => 'Sincronizar configurações';

  @override
  String get devicesSyncMedia => 'Sincronizar mídia';

  @override
  String get devicesDeclineSignIn => 'Recusar entrada';

  @override
  String get devicesApprove => 'Aprovar';

  @override
  String get devicesTitle => 'Dispositivos';

  @override
  String get devicesConnectDevice => 'Conectar dispositivo';

  @override
  String get devicesPrimaryDeviceTitle => 'Este é o dispositivo principal';

  @override
  String get devicesPrimaryDeviceSubtitle => 'A permissão para sincronizar conversas, configurações e mídia é concedida apenas aqui.';

  @override
  String get devicesQrSessionExpiredNewCode => 'A sessão QR expirou. Gere um novo código.';

  @override
  String devicesQrExpiresIn(String time) {
    return 'QR expira em $time';
  }

  @override
  String get devicesWaitingQrScan => 'Aguardando leitura do QR no telefone.';

  @override
  String get devicesQrScannedConfirm => 'QR lido. Confirme a entrada no telefone.';

  @override
  String get devicesApplyingSecureBundle => 'Aplicando pacote de sincronização segura…';

  @override
  String get devicesAuthorizationFailed => 'Falha na autorização. Tente novamente.';

  @override
  String get devicesUnauthenticatedChooseAction => 'Você não está autenticado. Escolha uma ação abaixo.';

  @override
  String get devicesAuthenticated => 'Dispositivo autenticado.';

  @override
  String get devicesDesktopWebAuthorization => 'Autorização Desktop/Web';

  @override
  String get devicesDesktopModeDescription => 'Escolha o modo: registrar um novo usuário ou entrar por QR com aprovação no telefone.';

  @override
  String get devicesCancelQr => 'Cancelar QR';

  @override
  String get devicesRefreshQr => 'Atualizar QR';

  @override
  String get devicesSignInViaQr => 'Entrar por QR';

  @override
  String get devicesOpenPrimaryInstruction => 'Abra o Secretly no telefone principal → Configurações → Dispositivos → Conectar dispositivo.';

  @override
  String get storageSection => 'Armazenamento';

  @override
  String get storageSectionSubtitle => 'Cache e transferências neste dispositivo';

  @override
  String get storageUsageTitle => 'Utilização do armazenamento';

  @override
  String get storageCategoryMedia => 'Cache de multimédia';

  @override
  String get storageCategoryVoiceTranscripts => 'Transcrições de voz';

  @override
  String get storageCategoryVoiceModel => 'Modelo de voz offline';

  @override
  String get storageCategoryStickers => 'Autocolantes';

  @override
  String get storageCategoryEmoji => 'Emojis animados';

  @override
  String get storageCategoryProfileMedia => 'A minha galeria e avatares';

  @override
  String get storageCategoryRecents => 'Ficheiros recentes';

  @override
  String get storageTotal => 'Total';

  @override
  String get storageCalculating => 'A calcular…';

  @override
  String get storageClearCache => 'Limpar cache';

  @override
  String get storageClearCacheHint => 'Remove multimédia em cache, avatares de contactos e emojis animados. A sua galeria, autocolantes e conversas são mantidos; a multimédia é transferida novamente ao visualizar.';

  @override
  String get storageClearing => 'A limpar cache…';

  @override
  String get storageClearedToast => 'Cache limpa';

  @override
  String get storageRemoveVoiceModel => 'Remover modelo de voz offline (140 MB)';

  @override
  String get storageRemoveVoiceModelHint => 'Liberta o modelo de reconhecimento de voz no dispositivo. É transferido novamente de forma automática da próxima vez que transcrever uma mensagem de voz.';

  @override
  String get storageRemoveVoiceModelConfirmTitle => 'Remover modelo de voz?';

  @override
  String get storageRemoveVoiceModelConfirmBody => 'O modelo de reconhecimento de voz de 140 MB será eliminado do dispositivo. É transferido novamente de forma automática da próxima vez que transcrever uma mensagem de voz.';

  @override
  String get storageRemoveVoiceModelConfirm => 'Remover';

  @override
  String get storageVoiceModelNotInstalled => 'Não está instalado nenhum modelo de voz';

  @override
  String get storageVoiceModelRemovedToast => 'Modelo de voz removido';

  @override
  String get backupStateProtected => 'O seu histórico está protegido';

  @override
  String get backupStateUnprotected => 'O seu histórico não está protegido';

  @override
  String get backupStateFailing => 'As cópias estão a falhar';

  @override
  String get backupStateStale => 'A cópia está desatualizada';

  @override
  String get backupStateNone => 'Ainda sem cópia';

  @override
  String backupLastAt(Object time) {
    return 'Última cópia: $time';
  }

  @override
  String get backupIntroHint => 'Uma cópia permite trazer as suas conversas para um novo dispositivo';

  @override
  String get backupAccessUpgradeTitle => 'Guarde a cópia novamente';

  @override
  String get backupAccessUpgradeBody => 'A sua cópia no servidor foi criada no formato antigo: pode ser transferida por quem souber o identificador do perfil. O conteúdo permanece cifrado com a sua palavra-passe, mas uma segunda barreira não faz mal. Guardar novamente acrescenta uma verificação de palavra-passe no próprio servidor.';

  @override
  String get backupAccessUpgradeAction => 'Guardar novamente';

  @override
  String get backupSectionAutomatic => 'Automático';

  @override
  String get backupAutoToggle => 'Copiar automaticamente';

  @override
  String get backupPassword => 'Palavra-passe';

  @override
  String get backupPasswordSet => 'Definida';

  @override
  String get backupPasswordNotSet => 'Por definir';

  @override
  String get backupPasswordSaved => 'Palavra-passe guardada';

  @override
  String get backupWhere => 'Onde';

  @override
  String get backupHowOften => 'Com que frequência';

  @override
  String get backupIncludeMedia => 'Incluir multimédia';

  @override
  String get backupAutoFooter => 'A cópia é cifrada com a sua palavra-passe. Sem ela nada pode ser restaurado — guarde-a em segurança. A multimédia nunca é enviada para o servidor.';

  @override
  String get backupNow => 'Copiar agora';

  @override
  String get backupSectionRestore => 'Restaurar';

  @override
  String get backupRestoreAction => 'Restaurar a partir de uma cópia';

  @override
  String get backupRestoreFooter => 'Substitui as conversas e definições deste dispositivo pelo conteúdo da cópia.';

  @override
  String get backupSectionKey => 'Chave do Secretly ID';

  @override
  String get backupKeyShow => 'Mostrar a chave';

  @override
  String get backupKeyRestore => 'Restaurar com uma chave';

  @override
  String get backupKeyFooter => 'Restaura apenas o seu Secretly ID — não contém conversas. Restaurar com uma chave apaga os dados locais.';

  @override
  String get backupDestServerDevice => 'Servidor e dispositivo';

  @override
  String get backupDestServer => 'Servidor';

  @override
  String get backupDestDevice => 'Dispositivo';

  @override
  String get backupDestNone => 'Por escolher';

  @override
  String get backupDestServerOnly => 'Apenas servidor';

  @override
  String get backupDestDeviceOnly => 'Apenas dispositivo';

  @override
  String get backupTileOff => 'Desligado — o seu histórico não está protegido';

  @override
  String get backupTilePending => 'Ligado, mas ainda não foi executado';

  @override
  String get backupTileFailing => 'Não está a funcionar — verifique';

  @override
  String get backupTileStale => 'Sem atualização há algum tempo';

  @override
  String get backupPasswordChange => 'Alterar palavra-passe';

  @override
  String get backupPasswordRemove => 'Remover palavra-passe';

  @override
  String get chatUndecryptablePending => 'Chegou uma mensagem, mas ainda não pode ser lida — a restaurar a sessão segura…';

  @override
  String get liquidGlassTitle => 'Vidro líquido';

  @override
  String get liquidGlassSubtitle => 'Barras e ilhas com refração. Desligue para o material simples — gasta menos energia e aquece menos.';

  @override
  String get billingPendingTitle => 'A aguardar o pagamento';

  @override
  String get billingPendingBody => 'O pedido foi criado, mas o pagamento ainda não está confirmado. Conclua o pagamento com o método escolhido — o Premium será ativado sozinho.';

  @override
  String get callsHideAddressTitle => 'Ocultar o meu endereço nas chamadas';

  @override
  String get callsHideAddressSubtitle => 'Através do nosso servidor: a outra pessoa não verá o seu endereço IP, mas o atraso pode aumentar';

  @override
  String get desktopJoinRoomByLink => 'Entrar por link';

  @override
  String get desktopJoinRoomLinkHint => 'Cole o link do convite';

  @override
  String get desktopJoinRoomLinkInvalid => 'Este não é um link de convite para uma sala';

  @override
  String get desktopOfflineLockTitle => 'Pedir a palavra-passe após muito tempo sem ligação';

  @override
  String get desktopOfflineLockDescription => 'Se este computador não contactar o servidor durante mais tempo do que o indicado, pede a palavra-passe ao arrancar. Um computador perdido nunca recebe o encerramento remoto, mas atinge este limite.';

  @override
  String get desktopOfflineLockNever => 'Nunca';

  @override
  String get desktopOfflineLockDays7 => '7 dias';

  @override
  String get desktopOfflineLockDays14 => '14 dias';

  @override
  String get desktopOfflineLockDays30 => '30 dias';

  @override
  String get desktopPollTitle => 'Sondagem';

  @override
  String get desktopPollAnonymous => 'Sondagem anónima';

  @override
  String get desktopPollClosed => 'Encerrada';

  @override
  String desktopPollVoters(Object count) {
    return 'Votaram: $count';
  }

  @override
  String get desktopPollMultipleHint => 'Podes escolher várias';

  @override
  String get desktopPollCloseAction => 'Encerrar a sondagem';

  @override
  String get desktopEventTitle => 'Evento';

  @override
  String get desktopEventGoing => 'Vou';

  @override
  String get desktopEventMaybe => 'Talvez';

  @override
  String get desktopEventNo => 'Não vou';

  @override
  String get desktopPollNewTitle => 'Nova sondagem';

  @override
  String get desktopPollQuestionHint => 'Pergunta';

  @override
  String desktopPollOptionHint(Object index) {
    return 'Opção $index';
  }

  @override
  String get desktopPollAddOption => 'Adicionar opção';

  @override
  String get desktopPollCreateAction => 'Criar';

  @override
  String get desktopPollNeedTwo => 'É precisa uma pergunta e pelo menos duas opções';

  @override
  String get desktopPollMultipleLabel => 'Várias respostas';

  @override
  String get desktopPollAnonymousLabel => 'Anónima';

  @override
  String get desktopEventNewTitle => 'Novo evento';

  @override
  String get desktopEventTitleHint => 'Título';

  @override
  String get desktopEventDescriptionHint => 'Descrição';

  @override
  String get desktopEventLocationHint => 'Local';

  @override
  String get desktopEventPickWhen => 'Escolher data e hora';

  @override
  String get desktopEventNeedTitleAndDate => 'São precisos um título e uma data';

  @override
  String get desktopViewerOpenExternally => 'Abrir noutra aplicação';

  @override
  String get desktopViewerSaveAs => 'Guardar como…';

  @override
  String desktopViewerPage(Object page, Object total) {
    return 'Página $page de $total';
  }

  @override
  String get desktopViewerFailed => 'Não foi possível mostrar o ficheiro';

  @override
  String get desktopViewerTooLarge => 'O ficheiro é grande demais para mostrar aqui';

  @override
  String get desktopSupportAttach => 'Anexar um ficheiro';

  @override
  String desktopSupportAttachHint(Object limit) {
    return 'Uma captura de ecrã ou um ficheiro de registo — até $limit. O anexo é cifrado juntamente com a mensagem.';
  }

  @override
  String desktopSupportTooLarge(Object limit) {
    return 'O ficheiro é maior do que $limit e não pode ser enviado';
  }

  @override
  String get desktopSupportUnreadable => 'Não foi possível ler o ficheiro';

  @override
  String get desktopSupportRemoveAttachment => 'Remover o anexo';

  @override
  String desktopSupportMegabytes(Object value) {
    return '$value MB';
  }

  @override
  String get desktopSupportYou => 'Você';

  @override
  String get desktopSupportShrunk => 'A imagem foi reduzida para caber';

  @override
  String get desktopStickerPackTitle => 'Pacote de autocolantes';

  @override
  String get desktopStickerPackAddPlain => 'Adicionar o pacote';

  @override
  String get desktopStickerPackInstalled => 'Instalado';

  @override
  String get desktopStickerPackInstalling => 'A instalar…';

  @override
  String get desktopStickerPackOwn => 'Este é o seu próprio pacote';

  @override
  String get desktopStickerPackNoAuthor => 'O autor do pacote é desconhecido — abra o mesmo autocolante numa conversa individual';

  @override
  String desktopStickerPackInstallingProgress(Object done, Object total) {
    return 'A instalar… $done/$total';
  }

  @override
  String desktopStickerPackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count autocolantes',
      one: '$count autocolante',
    );
    return '$_temp0';
  }

  @override
  String desktopStickerPackAdd(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Adicionar $count autocolantes',
      one: 'Adicionar $count autocolante',
    );
    return '$_temp0';
  }

  @override
  String get desktopPairingTitle => 'Ligue o Secretly Desktop';

  @override
  String get desktopPairingHowTo => 'No telemóvel abra Secretly → Definições → Dispositivos → «Ligar dispositivo» e leia este código QR.';

  @override
  String get desktopPairingPreparingQr => 'A preparar o QR…';

  @override
  String get desktopPairingQrUnavailable => 'QR indisponível';

  @override
  String get desktopPairingCodeExpired => 'O código expirou — a atualizar…';

  @override
  String desktopPairingCodeValidFor(Object time) {
    return 'O código é válido por mais $time';
  }

  @override
  String get desktopPairingPrepareFailed => 'Não foi possível preparar o código. Verifique a sua ligação à internet e tente novamente.';

  @override
  String get desktopPairingRevoked => 'Este dispositivo foi removido da conta, por isso não é criado nenhum código.\nLigue o computador de novo — receberá uma nova identidade de dispositivo e a antiga continua revogada. Só uma confirmação a partir do telemóvel dá acesso às conversas.';

  @override
  String get desktopPairingPreparingNew => 'A preparar uma nova ligação…';

  @override
  String get desktopPairingConnectAsNew => 'Ligar como novo dispositivo';

  @override
  String get desktopPairingIdentityResetFailed => 'Não foi possível recriar a identidade do dispositivo. Reinicie a aplicação e tente novamente.';

  @override
  String get desktopPairingWaitingConfirm => 'A aguardar confirmação…';

  @override
  String get desktopPairingNewQr => 'Gerar um novo QR';

  @override
  String get desktopPairingCreatingRequest => 'A criar o pedido…';

  @override
  String get desktopPairingReadyToScan => 'Pronto para ler';

  @override
  String get desktopPairingWaitingScan => 'A aguardar a leitura no telemóvel…';

  @override
  String get desktopPairingScannedConfirmOnPhone => 'QR lido — confirme no telemóvel.';

  @override
  String get desktopPairingFetchingProfile => 'A obter o perfil e as chaves…';

  @override
  String get desktopPairingConnectedLoading => 'Ligado. A carregar…';

  @override
  String get desktopPairingConnectionError => 'Erro de ligação. Tente novamente.';

  @override
  String get desktopMenuReaction => 'Reação';

  @override
  String get desktopMenuContinueInTopic => 'Continuar num tópico';

  @override
  String get desktopMenuCopySelection => 'Copiar a seleção';

  @override
  String get desktopMenuCopyText => 'Copiar o texto';

  @override
  String get desktopMenuCopyLink => 'Copiar a ligação';

  @override
  String get desktopMenuTranslate => 'Traduzir';

  @override
  String get desktopMenuHideTranslation => 'Ocultar a tradução';

  @override
  String get desktopMenuSelect => 'Selecionar';

  @override
  String get desktopMenuPhotoOrVideo => 'Foto ou vídeo';

  @override
  String get desktopMenuContact => 'Contacto';

  @override
  String get desktopMenuLocation => 'Localização';

  @override
  String get desktopListPinned => 'AFIXADOS';

  @override
  String get desktopListToday => 'HOJE';

  @override
  String get desktopListYesterday => 'ONTEM';

  @override
  String get desktopListThisWeek => 'ESTA SEMANA';

  @override
  String get desktopListEarlier => 'ANTES';

  @override
  String get desktopListNothingFound => 'Nada encontrado';

  @override
  String get desktopListAddFavourite => 'Adicionar aos favoritos';

  @override
  String get desktopListRemoveFavourite => 'Remover dos favoritos';

  @override
  String get desktopListMute => 'Silenciar';

  @override
  String get desktopListMarkRead => 'Marcar como lida';

  @override
  String get desktopListArchive => 'Arquivar';

  @override
  String get desktopListFolders => 'Pastas';

  @override
  String get desktopListCreate => 'Criar';

  @override
  String get desktopListTyping => 'a escrever';

  @override
  String get desktopListDraftPrefix => 'Rascunho: ';

  @override
  String desktopListDiscussion(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Conversa · $count participantes',
      one: 'Conversa · $count participante',
    );
    return '$_temp0';
  }

  @override
  String get desktopCallServerSilent => 'O servidor não respondeu. Tente novamente ou saia da chamada.';

  @override
  String get desktopCallRoomMissing => 'A sala não está disponível no servidor — não é possível iniciar uma chamada nela.';

  @override
  String get desktopCallNoServer => 'Sem ligação ao servidor. Verifique a sua ligação.';

  @override
  String get desktopCallJoinFailed => 'Não foi possível entrar na chamada. Verifique a ligação e tente novamente.';

  @override
  String desktopCallSharingScreen(Object name) {
    return '$name está a partilhar o ecrã';
  }

  @override
  String get desktopCallRoomEmpty => 'Ainda não foi escrito nada na sala';

  @override
  String get desktopCallMessageHint => 'Mensagem para a sala…';

  @override
  String get desktopCallSendToRoom => 'Enviar para a sala';

  @override
  String desktopCallParticipantsTab(Object count) {
    return 'Participantes · $count';
  }

  @override
  String get desktopCallNotesTab => 'Notas';

  @override
  String get desktopCallLinkCopied => 'Ligação copiada';

  @override
  String get desktopCallFailed => 'Não foi possível';

  @override
  String desktopCallFailedWith(Object error) {
    return 'Não foi possível: $error';
  }

  @override
  String get desktopCallMicOn => 'Ligar o microfone';

  @override
  String get desktopCallMicOff => 'Desligar o microfone';

  @override
  String get desktopCallCamOn => 'Ligar a câmara';

  @override
  String get desktopCallCamOff => 'Desligar a câmara';

  @override
  String get desktopCallNoMediaVideo => 'O servidor não forneceu canal de media — o vídeo está indisponível';

  @override
  String get desktopCallLayoutSingle => 'Um';

  @override
  String get desktopCallLayoutGrid => 'Grelha';

  @override
  String get desktopCallShowOneLarge => 'Mostrar uma pessoa em grande';

  @override
  String get desktopCallShowGrid => 'Mostrar todos em grelha';

  @override
  String get desktopCallScreen => 'Ecrã';

  @override
  String get desktopCallShareStop => 'Parar a partilha do ecrã';

  @override
  String get desktopCallShareStart => 'Partilhar o ecrã';

  @override
  String get desktopCallNoMediaScreen => 'O servidor não forneceu canal de media — a partilha de ecrã está indisponível';

  @override
  String get desktopCallLeave => 'Sair';

  @override
  String get desktopCallLeaveCall => 'Sair da chamada';

  @override
  String get desktopCallNoMediaBoth => 'O servidor não forneceu canal de media: esta chamada não terá som nem vídeo';

  @override
  String get desktopCallMinimise => 'Minimizar a chamada';

  @override
  String get desktopCallDiscussion => 'Conversa';

  @override
  String desktopCallDiscussionOf(Object title) {
    return 'Conversa · $title';
  }

  @override
  String get desktopCallEncrypted => 'A chamada é cifrada de ponta a ponta';

  @override
  String desktopCallDurationOnAir(Object duration, Object count) {
    return '$duration · $count no ar';
  }

  @override
  String get desktopCallExitFullScreen => 'Sair do ecrã inteiro';

  @override
  String get desktopCallFullScreen => 'Ecrã inteiro';

  @override
  String get desktopCallDemoRoom => 'Sala de demonstração';

  @override
  String get desktopCallNoCallYet => 'Ainda não há chamada';

  @override
  String get desktopCallDemoExplain => 'Existe apenas neste computador e não está no servidor — não é possível iniciar uma chamada. Numa sala real o botão funciona.';

  @override
  String get desktopCallStartHint => 'Comece — os outros verão o convite na sala';

  @override
  String get desktopCallVoiceOnly => 'Só voz';

  @override
  String get desktopCallWithCamera => 'Com câmara';

  @override
  String get desktopCallConnecting => 'A ligar…';

  @override
  String get desktopCallOngoing => 'Está a decorrer uma conversa';

  @override
  String desktopCallOnAir(Object count) {
    return '$count no ar';
  }

  @override
  String get desktopCallJoin => 'Juntar-se';

  @override
  String get desktopCallFullScreenShort => 'Ecrã inteiro';

  @override
  String get desktopCallReconnecting => 'a religar';

  @override
  String get desktopCallCannotHear => 'não ouve';

  @override
  String get desktopCallSharingShort => 'está a partilhar o ecrã';

  @override
  String get desktopCallCameraOn => 'câmara ligada';

  @override
  String get desktopCallPickDevice => 'Escolher um dispositivo';

  @override
  String get desktopCallPreparingLink => 'A preparar a ligação…';

  @override
  String get desktopCallInvite => 'Convidar';

  @override
  String desktopCallFps(Object fps) {
    return '$fps f/s';
  }

  @override
  String get desktopSettingsTitle => 'Definições';

  @override
  String get desktopSettingsGroupApp => 'Aplicação';

  @override
  String get desktopSettingsGroupPrivacy => 'Privacidade e segurança';

  @override
  String get desktopSettingsGroupAccount => 'Conta e dados';

  @override
  String get desktopSettingsGeneralLabel => 'Geral';

  @override
  String get desktopSettingsGeneralSubtitle => 'Idioma, comportamento da aplicação';

  @override
  String get desktopSettingsGeneralKeywords => 'idioma, região, enter, envio, entrada';

  @override
  String get desktopSettingsAppearanceLabel => 'Aspeto';

  @override
  String get desktopSettingsAppearanceSubtitle => 'Tema, acento, fundo da conversa';

  @override
  String get desktopSettingsAppearanceKeywords => 'tema, acento, fundo, balões, cor, escuro, marcas, animação';

  @override
  String get desktopSettingsShortcutsLabel => 'Atalhos de teclado';

  @override
  String get desktopSettingsShortcutsSubtitle => 'O que premir para ser mais rápido';

  @override
  String get desktopSettingsShortcutsKeywords => 'teclas, atalhos, rápido, cmd, ctrl';

  @override
  String get desktopSettingsPowerLabel => 'Consumo de energia';

  @override
  String get desktopSettingsPowerSubtitle => 'O que gasta a bateria';

  @override
  String get desktopSettingsPowerKeywords => 'bateria, animação, molduras, vidro, desempenho, calor';

  @override
  String get desktopSettingsNotificationsLabel => 'Notificações';

  @override
  String get desktopSettingsNotificationsSubtitle => 'Sons, pré-visualização, silêncio';

  @override
  String get desktopSettingsNotificationsKeywords => 'som, pré-visualização, silêncio, não incomodar, faixa, texto';

  @override
  String get desktopSettingsCallsLabel => 'Chamadas';

  @override
  String get desktopSettingsCallsSubtitle => 'Receber chamadas e partilhar o ecrã';

  @override
  String get desktopSettingsCallsKeywords => 'chamadas, recebidas, partilha de ecrã, vídeo, áudio';

  @override
  String get desktopSettingsMediaLabel => 'Som e vídeo';

  @override
  String get desktopSettingsMediaSubtitle => 'Câmara e microfone para chamadas';

  @override
  String get desktopSettingsMediaKeywords => 'câmara, microfone, dispositivo, webcam, auscultadores, som, vídeo';

  @override
  String get desktopSettingsPrivacyLabel => 'Privacidade';

  @override
  String get desktopSettingsPrivacySubtitle => 'Quem vê o quê sobre si';

  @override
  String get desktopSettingsPrivacyKeywords => 'quem vê, visto por último, foto, chamadas, mensagens, reencaminhar, alcunha, procura, desconhecidos';

  @override
  String get desktopSettingsSecurityLabel => 'Segurança';

  @override
  String get desktopSettingsSecuritySubtitle => 'Cifra e dispositivos verificados';

  @override
  String get desktopSettingsSecurityKeywords => 'cifra, e2ee, verificados, bloqueio, palavra-passe, touch id, verificação';

  @override
  String get desktopSettingsBackupLabel => 'Cópia de segurança';

  @override
  String get desktopSettingsBackupSubtitle => 'O que salva o histórico das conversas';

  @override
  String get desktopSettingsBackupKeywords => 'cópia, backup, restauro, safe backup, palavra-passe, media';

  @override
  String get desktopSettingsBlockedLabel => 'Bloqueados';

  @override
  String get desktopSettingsBlockedSubtitle => 'A quem está vedado o acesso';

  @override
  String get desktopSettingsBlockedKeywords => 'bloqueio, bloqueados, desbloquear, lista negra, spam';

  @override
  String get desktopSettingsDevicesLabel => 'Sessões e dispositivos';

  @override
  String get desktopSettingsDevicesSubtitle => 'Sessões ativas';

  @override
  String get desktopSettingsDevicesKeywords => 'dispositivos, sessões, qr, ligação, terminar sessão, cópia';

  @override
  String get desktopSettingsAccountLabel => 'Conta';

  @override
  String get desktopSettingsAccountSubtitle => 'Perfil e terminar sessão';

  @override
  String get desktopSettingsAccountKeywords => 'nome, sobre mim, id, terminar sessão, repor';

  @override
  String get desktopSettingsStorageLabel => 'Armazenamento';

  @override
  String get desktopSettingsStorageSubtitle => 'Cache, transferências';

  @override
  String get desktopSettingsStorageKeywords => 'cache, espaço, limpar, media, transferências';

  @override
  String get desktopSettingsSupportLabel => 'Apoio';

  @override
  String get desktopSettingsSupportSubtitle => 'Uma conversa cifrada connosco';

  @override
  String get desktopSettingsSupportKeywords => 'apoio, ajuda, problema, erro, escrever';

  @override
  String get desktopSettingsAboutLabel => 'Acerca';

  @override
  String get desktopSettingsAboutKeywords => 'versão, compilação, licenças, site';

  @override
  String get desktopSettingsDangerLabel => 'Eliminar a conta';

  @override
  String get desktopSettingsEndCallFirst => 'Termine primeiro a chamada ativa.';

  @override
  String get desktopSettingsSignOutTitle => 'Terminar sessão neste computador?';

  @override
  String get desktopSettingsSignOutBody => 'Deste computador serão removidas as conversas, as chaves e a cache. A conta e o histórico no telemóvel não são afetados — o computador pode ser ligado de novo por código QR.';

  @override
  String get desktopSettingsSignOut => 'Terminar sessão';

  @override
  String desktopSettingsSignOutFailed(Object error) {
    return 'Não foi possível terminar a sessão: $error';
  }

  @override
  String get desktopSettingsActive => 'ativo';
}

/// The translations for Portuguese, as used in Brazil (`pt_BR`).
class AppLocalizationsPtBr extends AppLocalizationsPt {
  AppLocalizationsPtBr(): super('pt_BR');

  @override
  String get appTitle => 'Secretly';

  @override
  String get starting => 'Iniciando…';

  @override
  String get encrypting => 'Criptografando…';

  @override
  String errorPrefix(Object error) {
    return 'Erro: $error';
  }

  @override
  String get settingsTitle => 'Configurações';

  @override
  String get notificationsSection => 'Notificações';

  @override
  String get languageSection => 'Idioma';

  @override
  String get comingSoon => 'Em breve';

  @override
  String get idsTitle => 'IDs';

  @override
  String get profileIdLabel => 'ID do perfil';

  @override
  String get deviceIdLabel => 'ID do dispositivo';

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
  String get openMyId => 'Abrir meu ID';

  @override
  String get close => 'Fechar';

  @override
  String get tabChats => 'Conversas';

  @override
  String get tabGroups => 'Salas';

  @override
  String get tabContacts => 'Contatos';

  @override
  String get tabProfile => 'Perfil';

  @override
  String get accountSection => 'Conta';

  @override
  String get chatsSection => 'Conversas';

  @override
  String get privacySection => 'Privacidade';

  @override
  String get devicesSection => 'Dispositivos';

  @override
  String get systemSection => 'Sistema';

  @override
  String get languageSystemDefault => 'Padrão do sistema';

  @override
  String languageSystemCurrent(Object language) {
    return 'Sistema ($language)';
  }

  @override
  String get languageChooseAppLanguage => 'Escolher idioma do app';

  @override
  String get languageAvailableWave1 => 'Disponível: inglês, russo, ucraniano, espanhol, português (Brasil), francês e alemão. Você também pode seguir o idioma do sistema.';

  @override
  String get languageMessageTranslation => 'Tradução de mensagens';

  @override
  String get languageShowTranslateButton => 'Mostrar botão Traduzir';

  @override
  String get languageTranslateWholeChats => 'Traduzir conversas inteiras';

  @override
  String get favoritesTitle => 'Favoritos';

  @override
  String get favoritesSubtitle => 'Suas notas pessoais';

  @override
  String get favoritesEmptyTitle => 'Ainda não há favoritos';

  @override
  String get favoritesEmptySubtitle => 'Envie mensagens, arquivos e notas para cá para mantê-los privados nos seus dispositivos.';

  @override
  String get favoritesPersonalNotebookLabel => 'Notas pessoais';

  @override
  String get more => 'Mais';

  @override
  String get stickersRecent => 'Stickers recentes';

  @override
  String get searchStickers => 'Buscar stickers';

  @override
  String get noStickersFound => 'Nenhum sticker encontrado';

  @override
  String get noRecentStickers => 'Seus stickers recentes aparecerão aqui';

  @override
  String get cancelSelection => 'Cancelar seleção';

  @override
  String get chatsTitle => 'Conversas';

  @override
  String get newChat => 'Nova conversa';

  @override
  String get openContactsToStartChat => 'Abra Contatos para iniciar uma conversa';

  @override
  String get noChatsYet => 'Ainda não há conversas';

  @override
  String get openDemoChat => 'Abrir conversa de demonstração';

  @override
  String get archive => 'Arquivar';

  @override
  String get unarchive => 'Desarquivar';

  @override
  String get pin => 'Fixar';

  @override
  String get unpin => 'Desafixar';

  @override
  String get clearHistory => 'Limpar histórico';

  @override
  String archiveHeader(Object count) {
    return 'Arquivo ($count)';
  }

  @override
  String deleteChatsConfirmTitle(Object count) {
    return 'Excluir $count conversa(s)?';
  }

  @override
  String get deleteChatsConfirmBody => 'Isso remove as conversas apenas deste dispositivo.';

  @override
  String clearHistoryConfirmTitle(Object count) {
    return 'Limpar histórico de $count conversa(s)?';
  }

  @override
  String get clearHistoryConfirmBody => 'Isso remove as mensagens apenas deste dispositivo.';

  @override
  String get contactsTitle => 'Contatos';

  @override
  String get contactsTab => 'Contatos';

  @override
  String get requestsTab => 'Solicitações';

  @override
  String get addContact => 'Adicionar contato';

  @override
  String get deleteContact => 'Excluir contato';

  @override
  String get noContactsYet => 'Ainda não há contatos';

  @override
  String get noRequests => 'Nenhuma solicitação';

  @override
  String get secretlyIdLabel => 'Secretly ID';

  @override
  String get secretlyIdHint => 'XXXX-XXXX-...-CHECK';

  @override
  String get nameOptionalLabel => 'Nome (opcional)';

  @override
  String get scanContactQrTitle => 'Escanear QR do contato';

  @override
  String get qrMissingSecretlyId => 'O QR não contém um Secretly ID';

  @override
  String get differentServerTitle => 'Servidor diferente';

  @override
  String differentServerBody(Object qrServer, Object appServer) {
    return 'Este QR pertence a outro servidor.\n\nServidor do QR: $qrServer\nEste app: $appServer\n\nInstale o mesmo APK/servidor nos dois telefones.';
  }

  @override
  String get contactActionProfileNotFound => 'O Secretly ID não foi encontrado neste servidor.';

  @override
  String get contactActionTransportBlocked => 'Esta ação está indisponível porque o app está vinculado a outro servidor.';

  @override
  String get contactActionServiceUnavailable => 'O servidor está indisponível agora. Tente novamente em instantes.';

  @override
  String get contactActionCallsDisabled => 'As chamadas estão desativadas nas configurações de privacidade.';

  @override
  String get contactActionCallsDisabledForContact => 'As chamadas estão desativadas para este contato.';

  @override
  String get callServiceUnavailable => 'O serviço de chamadas está indisponível agora.';

  @override
  String get callAlreadyInProgress => 'Outra chamada já está em andamento.';

  @override
  String get callIceUnavailable => 'A configuração segura da chamada está indisponível agora. Tente novamente em instantes.';

  @override
  String get callPermissionDenied => 'O acesso ao microfone ou à câmera está bloqueado. Permita o acesso e tente novamente.';

  @override
  String get callNegotiationFailed => 'Não foi possível estabelecer a chamada segura. Tente novamente.';

  @override
  String get callConnectionInterrupted => 'A conexão da chamada foi interrompida. Tente novamente.';

  @override
  String get callActionGeneric => 'Não foi possível iniciar a chamada. Tente novamente.';

  @override
  String get callEncryptedBadge => 'Criptografia de ponta a ponta';

  @override
  String get incomingVideoCall => 'Chamada de vídeo recebida';

  @override
  String get incomingVoiceCall => 'Chamada de voz recebida';

  @override
  String get callDecline => 'Recusar';

  @override
  String get callConnectionUnstable => 'Conexão instável';

  @override
  String get callNetworkVeryWeak => 'Sinal de rede muito fraco';

  @override
  String get callNetworkWeak => 'Sinal de rede fraco';

  @override
  String get callEnded => 'Chamada encerrada';

  @override
  String get callReplacedByNewerAttempt => 'A chamada foi substituída por uma tentativa mais recente';

  @override
  String get callDeclined => 'Chamada recusada';

  @override
  String get callYouDeclined => 'Você recusou';

  @override
  String get callNoAnswer => 'Sem resposta';

  @override
  String get callConnectionError => 'Erro de conexão';

  @override
  String get callVideoUnavailable => 'Vídeo indisponível';

  @override
  String get callWaitingForRemoteVideo => 'Aguardando vídeo remoto...';

  @override
  String get callAttachingRemoteVideo => 'Anexando vídeo remoto...';

  @override
  String get callStartingRemoteVideo => 'Iniciando vídeo remoto...';

  @override
  String get callRemoteVideoNotArriving => 'O vídeo remoto não está chegando';

  @override
  String get callRemoteVideoBindFailed => 'Não foi possível vincular o fluxo de vídeo remoto';

  @override
  String get callRemoteVideoNoFrames => 'O vídeo remoto foi anexado, mas os quadros não estão sendo renderizados';

  @override
  String get callMinimize => 'Minimizar';

  @override
  String get callStatusCalling => 'Chamando...';

  @override
  String get callStatusIncoming => 'Recebendo...';

  @override
  String get callStatusConnecting => 'Conectando...';

  @override
  String get callStatusReconnecting => 'Reconectando...';

  @override
  String get callStatusEnded => 'Encerrada';

  @override
  String get callVideoCall => 'Chamada de vídeo';

  @override
  String get callControlMute => 'Silenciar';

  @override
  String get callControlSpeaker => 'Alto-falante';

  @override
  String get callControlCamera => 'Câmera';

  @override
  String get callControlFlip => 'Alternar';

  @override
  String get callControlStop => 'Parar';

  @override
  String get callControlShare => 'Compartilhar';

  @override
  String get callControlEnd => 'Encerrar';

  @override
  String get contactActionGeneric => 'Não foi possível concluir a ação. Tente novamente.';

  @override
  String get notificationTitleRoom => 'Sala';

  @override
  String get notificationTitleRequest => 'Solicitação';

  @override
  String get notificationTitleChat => 'Conversa';

  @override
  String get notificationBodyNewMessage => 'Nova mensagem';

  @override
  String get contactLookupUnavailable => 'A busca está indisponível agora. Tente novamente em instantes.';

  @override
  String addContactFailed(Object error) {
    return 'Falha ao adicionar contato: $error';
  }

  @override
  String deleteContactsConfirmTitle(Object count) {
    return 'Excluir $count contato(s)?';
  }

  @override
  String get deleteContactsConfirmBody => 'As conversas não são excluídas.';

  @override
  String get privacyTitle => 'Privacidade';

  @override
  String get blockedUsersSubtitle => 'Usuários bloqueados não podem entregar mensagens para você (aplicado pelo servidor).';

  @override
  String get noBlockedUsers => 'Nenhum usuário bloqueado';

  @override
  String unblockFailed(Object error) {
    return 'Falha ao desbloquear: $error';
  }

  @override
  String get diagIdentity => 'Identidade';

  @override
  String get diagEndpoints => 'Endpoints';

  @override
  String get diagServerBinding => 'Vinculação ao servidor';

  @override
  String get diagMismatch => 'Incompatibilidade: o perfil pertence a outro servidor. Use Configurações → Redefinir perfil.';

  @override
  String get diagStatus => 'Status';

  @override
  String get diagTimestamps => 'Marcas de tempo';

  @override
  String get diagTips => 'Dicas';

  @override
  String get diagTipsBody => 'Se as mensagens falharem com \"profile not found\":\n1) Verifique se os dois telefones usam o mesmo APK/servidor\n2) Adicione o contato novamente escaneando o QR\n3) Se os endpoints mudaram, use Redefinir perfil\n';

  @override
  String get secretlyUser => 'Usuário do Secretly';

  @override
  String get onlineStatus => 'online';

  @override
  String get edit => 'Editar';

  @override
  String get removePhoto => 'Remover foto';

  @override
  String get profileSectionTitle => 'Perfil';

  @override
  String get myNicknameLabel => 'Meu apelido';

  @override
  String get myNicknameHint => 'ex.: Alex';

  @override
  String get includeNicknameInQr => 'Incluir meu apelido no meu QR';

  @override
  String get includeNicknameInQrSubtitle => 'Desativado por padrão para privacidade. Se ativado, quem escanear poderá atribuir um nome automaticamente a você.';

  @override
  String verifyTitle(Object title) {
    return 'Verificar: $title';
  }

  @override
  String get scanVerifyQrTitle => 'Escanear QR de verificação';

  @override
  String qrBelongsAnotherServer(Object server) {
    return 'O QR pertence a outro servidor: $server';
  }

  @override
  String get qrSecretlyIdMismatch => 'O Secretly ID do QR não corresponde a este contato';

  @override
  String get qrMissingDeviceKeyInfo => 'O QR não contém informações do dispositivo/chave';

  @override
  String get deviceNotCachedTapRefresh => 'Dispositivo não armazenado em cache. Toque em Atualizar primeiro.';

  @override
  String get identityKeyMismatch => 'A identity key não corresponde. Não verifique.';

  @override
  String get verifiedSuccess => 'Verificado ✅';

  @override
  String get refreshKeys => 'Atualizar Keys';

  @override
  String get keysOfflineCannotFetch => 'O serviço Keys está offline. Não é possível obter as chaves do contato agora.';

  @override
  String get devicesLabel => 'Dispositivos';

  @override
  String get noDeviceKeysCachedYet => 'Ainda não há chaves de dispositivos em cache.';

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
  String get unverifiedLower => 'não verificado';

  @override
  String get keysOfflineIdTemporary => 'O serviço Keys está offline. O ID pode ser temporário no modo de desenvolvimento.';

  @override
  String get serverKeysLabel => 'Servidor (Keys)';

  @override
  String get nicknameLabel => 'Apelido';

  @override
  String get identityFingerprintLabel => 'Impressão digital de identidade';

  @override
  String get scanToAddVerifyContact => 'Escaneie para adicionar/verificar este contato';

  @override
  String get mySecretlyId => 'Meu Secretly ID';

  @override
  String get deviceId => 'ID do dispositivo';

  @override
  String get recoveryKit => 'Recovery Kit';

  @override
  String get safeBackupTitle => 'Safe Backup';

  @override
  String get safeBackupSubtitle => 'Safe Backup criptografado armazenado no servidor';

  @override
  String get safeBackupIntro => 'Crie uma cópia criptografada localmente ou no servidor. Você poderá restaurá-la depois a partir de um arquivo ou Secretly ID.';

  @override
  String get safeBackupUploadNow => 'Enviar backup agora';

  @override
  String get safeBackupRestoreFromServer => 'Restaurar do servidor';

  @override
  String get safeBackupRestoreTitle => 'Restaurar do backup no servidor';

  @override
  String get safeBackupRestoreConfirmTitle => 'Restaurar conta?';

  @override
  String get safeBackupRestoreConfirmBody => 'Isso removerá conversas/contatos locais deste dispositivo e restaurará a conta a partir do backup selecionado. O app será reiniciado automaticamente.';

  @override
  String get safeBackupUploaded => 'Backup enviado';

  @override
  String get safeBackupUploadFailed => 'Falha ao enviar backup';

  @override
  String safeBackupUploadFailedWithError(Object error) {
    return 'Falha ao enviar backup: $error';
  }

  @override
  String get safeBackupNotFound => 'Nenhum backup no servidor foi encontrado para este Secretly ID';

  @override
  String get exportRecoveryKit => 'Exportar Recovery Kit';

  @override
  String get exportRecoveryKitSubtitle => 'QR criptografado para recuperação da conta';

  @override
  String get restoreRecoveryKit => 'Restaurar pelo Recovery Kit';

  @override
  String get restoreRecoveryKitSubtitle => 'Apaga os dados locais e restaura este Secretly ID';

  @override
  String get recoveryPasswordTitle => 'Senha do Recovery Kit';

  @override
  String get password => 'Senha';

  @override
  String get confirmPassword => 'Confirmar senha';

  @override
  String get export => 'Exportar';

  @override
  String get scanQr => 'Escanear QR';

  @override
  String get invalidRecoveryKit => 'Recovery Kit inválido';

  @override
  String get wrongPassword => 'Senha incorreta';

  @override
  String get restoreConfirmTitle => 'Restaurar conta?';

  @override
  String get restoreConfirmBody => 'Isso removerá conversas/contatos locais deste dispositivo e restaurará a conta pelo Recovery Kit.';

  @override
  String get restore => 'Restaurar';

  @override
  String get darkTheme => 'Tema escuro';

  @override
  String get darkThemeSubtitle => 'Usar o mesmo tom de destaque no modo escuro.';

  @override
  String get blockUnverified => 'Bloquear envio para contatos não verificados';

  @override
  String get blockUnverifiedSubtitle => 'Modo estrito: em conversas individuais, enviar apenas a contatos cujas chaves você mesmo conferiu. Não se aplica a grupos.';

  @override
  String get blockedUsers => 'Usuários bloqueados';

  @override
  String get resetProfile => 'Redefinir perfil';

  @override
  String get resetProfileSubtitle => 'Corrige incompatibilidade de servidor/conta criando um novo Secretly ID';

  @override
  String get resetProfileDialogTitle => 'Redefinir perfil?';

  @override
  String get resetProfileDialogBody => 'Isso removerá conversas/contatos/solicitações locais deste dispositivo e criará um novo Secretly ID.\n\nUse isto quando você trocar de APK/servidor e as mensagens começarem a falhar.';

  @override
  String get cancel => 'Cancelar';

  @override
  String get ok => 'OK';

  @override
  String get add => 'Adicionar';

  @override
  String get delete => 'Excluir';

  @override
  String get clear => 'Limpar';

  @override
  String get block => 'Bloquear';

  @override
  String get unblock => 'Desbloquear';

  @override
  String get accept => 'Aceitar';

  @override
  String get verify => 'Verificar';

  @override
  String get menu => 'Menu';

  @override
  String get search => 'Buscar';

  @override
  String get queryLabel => 'Consulta';

  @override
  String get messageHint => 'Mensagem';

  @override
  String get notificationActionMarkRead => 'Marcar como lida';

  @override
  String get addCaption => 'Adicionar legenda';

  @override
  String get uploadCanceled => 'Envio cancelado';

  @override
  String get attachmentFinalizeTimeout => 'A rede está instável: o envio terminou, mas a confirmação expirou. Tente novamente.';

  @override
  String get attachmentTransferUnavailable => 'Não foi possível transferir o anexo agora. Verifique internet/servidor e tente novamente.';

  @override
  String get attachmentSendUnavailable => 'O envio de anexos ainda não está pronto. Tente novamente.';

  @override
  String get attachmentContactSyncPending => 'Aguardando sincronização da identidade do contato. Peça ao contato para enviar mais uma mensagem e tente novamente.';

  @override
  String get attachmentContactBlocked => 'Este contato está bloqueado.';

  @override
  String get attachmentRecipientNotFound => 'O perfil do destinatário não foi encontrado neste servidor. Verifique o Secretly ID e confirme se os dois dispositivos usam o mesmo servidor.';

  @override
  String get attachmentRecipientNoDevices => 'O destinatário ainda não tem dispositivos registrados. Peça ao contato para abrir o Secretly e tente novamente.';

  @override
  String get attachmentNoDeliverableDevices => 'Não foi possível entregar o anexo a nenhum dispositivo do destinatário. Tente novamente.';

  @override
  String get attachmentActionGeneric => 'Não foi possível enviar o anexo. Tente novamente.';

  @override
  String get send => 'Enviar';

  @override
  String get attach => 'Anexar';

  @override
  String get photo => 'Foto';

  @override
  String get video => 'Vídeo';

  @override
  String get file => 'Arquivo';

  @override
  String get music => 'Música';

  @override
  String get attachment => 'Anexo';

  @override
  String get downloading => 'Baixando…';

  @override
  String downloadFailed(Object error) {
    return 'Falha no download: $error';
  }

  @override
  String savedTo(Object path) {
    return 'Salvo em: $path';
  }

  @override
  String get noMessagesYet => 'Ainda não há mensagens';

  @override
  String get decrypting => 'Descriptografando…';

  @override
  String get uploading => 'Enviando…';

  @override
  String get uploadTimedOut => 'O envio excedeu o tempo limite. Verifique internet/servidor e tente novamente.';

  @override
  String uploadingBytes(Object sent, Object total) {
    return 'Enviados $sent / $total bytes';
  }

  @override
  String get requestsInfo => 'Esta conversa está em Solicitações. Aceite para responder ou bloqueie para ignorar.';

  @override
  String get verifyRequired => 'Verificação obrigatória';

  @override
  String get verifyContact => 'Verificar contato';

  @override
  String get muteNotifications => 'Silenciar notificações';

  @override
  String get unmuteNotifications => 'Ativar notificações';

  @override
  String get setContactPhoto => 'Definir foto do contato';

  @override
  String get removeContactPhoto => 'Remover foto do contato';

  @override
  String get blockUser => 'Bloquear usuário';

  @override
  String get unblockUser => 'Desbloquear usuário';

  @override
  String get deleteChat => 'Excluir conversa';

  @override
  String get missingRecipient => 'Destinatário ausente';

  @override
  String get contactNotVerified => 'O código de segurança mudou. Confira-o para continuar a escrever.';

  @override
  String get safetyNumberChangedTitle => 'O código de segurança mudou';

  @override
  String get safetyNumberChangedBody => 'Você já tinha conferido o código deste contato. Agora as chaves são novas — costuma acontecer depois de reinstalar o app ou trocar de telefone. A conversa continua criptografada de qualquer forma. Compare o código de novo se quiser ter certeza de que ainda é a mesma pessoa.';

  @override
  String get safetyNumberStrictBody => 'Você ativou “Bloquear envio a não verificados”. Compare o código deste contato para enviar mensagens.';

  @override
  String get sendAnyway => 'Enviar mesmo assim';

  @override
  String get alsoDeleteChat => 'Excluir conversa também';

  @override
  String get unblockUserConfirmTitle => 'Desbloquear usuário?';

  @override
  String get blockUserConfirmTitle => 'Bloquear usuário?';

  @override
  String get deleteChatConfirmTitle => 'Excluir conversa?';

  @override
  String get deleteChatConfirmBody => 'Isso remove a conversa apenas deste dispositivo.';

  @override
  String attachFailed(Object error) {
    return 'Falha ao anexar: $error';
  }

  @override
  String sendFailed(Object error) {
    return 'Falha ao enviar: $error';
  }

  @override
  String actionFailed(Object error) {
    return 'Falha na ação: $error';
  }

  @override
  String get roomPolicyNotMember => 'Você não é mais participante desta sala.';

  @override
  String get roomPolicyAdminsOnly => 'Apenas proprietários e administradores da sala podem fazer isso.';

  @override
  String get roomPolicyTextMessagesDisabled => 'Seu papel não pode enviar mensagens de texto nesta sala.';

  @override
  String get roomPolicyMediaDisabled => 'Seu papel não pode enviar mídia nesta sala.';

  @override
  String get roomPolicyReactionsDisabled => 'As reações estão desativadas nesta sala.';

  @override
  String get roomPolicyReactionNotAllowed => 'Esta reação não é permitida nesta sala.';

  @override
  String get roomPolicyPinDenied => 'Apenas administradores podem fixar mensagens nesta sala.';

  @override
  String get roomPolicyAddMembersDenied => 'Apenas administradores podem adicionar participantes a esta sala.';

  @override
  String get roomPolicyChangeInfoDenied => 'Apenas administradores podem alterar o perfil do grupo.';

  @override
  String roomPolicySlowMode(Object seconds) {
    return 'O modo lento está ativado. Tente novamente em ${seconds}s.';
  }

  @override
  String get noMatches => 'Nenhum resultado';

  @override
  String attachmentTooLarge(Object mb) {
    return 'O anexo é grande demais ($mb MB).';
  }

  @override
  String get attachmentFileMissing => 'O arquivo não está mais disponível.';

  @override
  String foundPrefix(Object hit) {
    return 'Encontrado: $hit';
  }

  @override
  String get contactDetailsChat => 'Conversa';

  @override
  String get contactDetailsSound => 'Som';

  @override
  String get contactDetailsCall => 'Chamada';

  @override
  String get contactDetailsVideo => 'Vídeo';

  @override
  String get contactDetailsUsernameLabel => 'Nome de usuário';

  @override
  String get contactDetailsAddToContacts => 'Adicionar aos contatos';

  @override
  String get contactDetailsMediaTab => 'Mídia';

  @override
  String get contactDetailsFilesTab => 'Arquivos';

  @override
  String get contactDetailsNoMedia => 'Sem mídia';

  @override
  String get contactDetailsNoFiles => 'Sem arquivos';

  @override
  String get contactDetailsStatusRecently => 'visto recentemente';

  @override
  String contactDetailsStatusAt(Object time) {
    return 'visto às $time';
  }

  @override
  String get contactDetailsAutoDelete => 'Exclusão automática';

  @override
  String get contactDetailsShareContact => 'Compartilhar contato';

  @override
  String get contactDetailsEditContact => 'Editar contato';

  @override
  String get contactDetailsDeleteContact => 'Excluir contato';

  @override
  String get contactDetailsSendGift => 'Enviar presente';

  @override
  String get contactDetailsStartSecretChat => 'Iniciar conversa secreta';

  @override
  String get contactDetailsCreateShortcut => 'Criar atalho';

  @override
  String get contactDetailsNameLabel => 'Nome';

  @override
  String get contactDetailsSave => 'Salvar';

  @override
  String get contactDetailsDeleteConfirmTitle => 'Excluir contato?';

  @override
  String get contactAutoDeleteOff => 'Desativado';

  @override
  String get contactAutoDelete1Day => '24 horas';

  @override
  String get contactAutoDelete7Days => '7 dias';

  @override
  String get contactAutoDelete30Days => '30 dias';

  @override
  String get contactEditTitle => 'Editar contato';

  @override
  String get contactEditDone => 'CONCLUÍDO';

  @override
  String get contactEditNameLabel => 'Nome';

  @override
  String get contactEditAssignEmoji => 'Atribuir emoji';

  @override
  String get contactEditClearEmoji => 'Limpar emoji';

  @override
  String get contactEditSetPhoto => 'Definir foto';

  @override
  String get chatMenuReply => 'Responder';

  @override
  String get chatMenuCopy => 'Copiar';

  @override
  String get chatMenuForward => 'Encaminhar';

  @override
  String get chatMenuPin => 'Fixar';

  @override
  String get chatMenuDelete => 'Excluir';

  @override
  String get reset => 'Redefinir';

  @override
  String get diagnostics => 'Diagnóstico';

  @override
  String get diagnosticsSubtitle => 'Status, vinculação, marcas de tempo';

  @override
  String get sendLater => 'Enviar mais tarde';

  @override
  String get sendSilently => 'Enviar sem som';

  @override
  String scheduledSendToday(Object time) {
    return 'Enviar hoje às $time';
  }

  @override
  String scheduledSendOn(Object date, Object time) {
    return 'Enviar em $date às $time';
  }

  @override
  String get repeatNever => 'Nunca';

  @override
  String get repeat => 'Repetir';

  @override
  String get onboardingBackTooltip => 'Voltar';

  @override
  String get onboardingWelcomeTitle => 'Bem-vindo!';

  @override
  String get onboardingWelcomeSubtitle => 'Um mensageiro de nova geração.\nPrivacidade total. Sem compromissos.';

  @override
  String get onboardingCreateAccount => 'Criar nova conta';

  @override
  String get onboardingAlreadyHaveAccount => 'Já tenho uma conta';

  @override
  String get onboardingFeatureE2eTitle => 'Criptografia E2E';

  @override
  String get onboardingFeatureE2eBody => 'As mensagens são criptografadas no seu dispositivo. Só você tem as chaves.';

  @override
  String get onboardingFeaturePrivacyTitle => 'Anonimato total';

  @override
  String get onboardingFeaturePrivacyBody => 'Sem número de telefone. Sem vínculo com dados pessoais.';

  @override
  String get onboardingFeatureRelayTitle => 'Sem intermediários';

  @override
  String get onboardingFeatureRelayBody => 'O servidor relay não armazena mensagens. Ele apenas as encaminha.';

  @override
  String get onboardingProfileTitle => 'Seu perfil';

  @override
  String get onboardingProfileSubtitle => 'Como outros usuários verão você';

  @override
  String get onboardingProfileNameSection => 'Nome do perfil';

  @override
  String get onboardingProfileNameHint => 'Seu nome ou apelido';

  @override
  String get onboardingNotificationsSection => 'Notificações';

  @override
  String get onboardingMessageNotificationsTitle => 'Notificações de mensagens';

  @override
  String get onboardingMessageNotificationsSubtitle => 'Receber notificações push do Secretly';

  @override
  String get onboardingIncomingCallsTitle => 'Chamadas recebidas';

  @override
  String get onboardingIncomingCallsSubtitle => 'Aceitar chamadas de contatos';

  @override
  String get continueAction => 'Continuar';

  @override
  String get onboardingBackupSaveFailed => 'Não foi possível salvar as configurações do backup';

  @override
  String get backupPasswordRequirements => 'Use pelo menos 8 caracteres ASCII, uma letra maiúscula e um caractere especial. Sem espaços no começo ou no fim.';

  @override
  String backupPasswordTooShort(Object minLength) {
    return 'A senha deve ter pelo menos $minLength caracteres.';
  }

  @override
  String backupPasswordTooLong(Object maxLength) {
    return 'A senha não deve ter mais de $maxLength caracteres.';
  }

  @override
  String get backupPasswordNonAscii => 'Use apenas letras latinas, dígitos e símbolos ASCII.';

  @override
  String get backupPasswordOuterWhitespace => 'Remova espaços no começo ou no fim da senha.';

  @override
  String get backupPasswordMissingUppercase => 'Adicione pelo menos uma letra maiúscula A-Z.';

  @override
  String get backupPasswordMissingSpecial => 'Adicione pelo menos um caractere especial, como !, # ou ?.';

  @override
  String get onboardingBackupPasswordTitle => 'Senha do backup';

  @override
  String get onboardingPasswordsDoNotMatch => 'As senhas não coincidem';

  @override
  String get onboardingBackupTitle => 'Cópias de segurança';

  @override
  String get onboardingBackupSubtitle => 'Proteja as suas conversas contra perda de dados.\nMesmo ao mudar de dispositivo.';

  @override
  String get onboardingAutoBackupSection => 'Cópia automática';

  @override
  String get onboardingAutoBackupTitle => 'Cópia automática';

  @override
  String get onboardingAutoBackupSubtitle => 'Guardar automaticamente uma cópia de segurança';

  @override
  String get onboardingStorageTypeSection => 'Tipo de armazenamento';

  @override
  String get onboardingBackupMediaTitle => 'Fazer backup de mídia';

  @override
  String get onboardingBackupMediaSubtitle => 'Fotos, vídeos, arquivos e avatares entram apenas em backups locais';

  @override
  String get onboardingFrequencySection => 'Frequência';

  @override
  String get onboardingEnterSecretly => 'Entrar no Secretly';

  @override
  String get onboardingSkipBackup => 'Pular configuração do backup';

  @override
  String get onboardingSecretlyIdCopied => 'Secretly ID copiado';

  @override
  String get onboardingRegistrationCompleteTitle => 'Cadastro concluído';

  @override
  String get onboardingRegistrationCompleteSubtitle => 'Salve seu Secretly ID agora. Você vai precisar dele para restaurar a conta e o backup em um novo dispositivo.';

  @override
  String get onboardingYourSecretlyId => 'Seu Secretly ID';

  @override
  String get onboardingCopyId => 'Copiar ID';

  @override
  String get onboardingRecoveryWarning => 'Sem o Secretly ID e a senha do backup, será impossível restaurar o backup do servidor. Salve o ID em um local seguro e não esqueça a senha.';

  @override
  String get onboardingStorageCloud => 'Nuvem';

  @override
  String get onboardingStorageCloudSubtitle => 'No servidor Secretly';

  @override
  String get onboardingStorageLocal => 'Local';

  @override
  String get onboardingStorageLocalSubtitle => 'Neste dispositivo';

  @override
  String get onboardingInterval6Hours => '6 horas';

  @override
  String get onboardingInterval12Hours => '12 horas';

  @override
  String get onboardingIntervalEveryDay => 'Todos os dias';

  @override
  String get onboardingIntervalEvery3Days => 'A cada 3 dias';

  @override
  String get onboardingIntervalWeekly => 'Uma vez por semana';

  @override
  String get onboardingBackupLocalCandidate => 'Cópia local do Secretly';

  @override
  String get onboardingDownloads => 'Downloads';

  @override
  String get onboardingDeviceFolder => 'Pasta do dispositivo';

  @override
  String get onboardingNoBackupsFound => 'Nenhum backup encontrado neste dispositivo';

  @override
  String get onboardingFoundBackups => 'Cópias encontradas';

  @override
  String get onboardingNoBackupsFoundBody => 'O Secretly verificou os backups locais do app e a pasta Downloads. Se o arquivo estiver em outro lugar, escolha manualmente.';

  @override
  String get chooseManually => 'Escolher manualmente';

  @override
  String get onboardingChooseBackupFileTitle => 'Escolha um arquivo de backup do Secretly';

  @override
  String get onboardingReadBackupFailed => 'Não foi possível ler o arquivo de backup';

  @override
  String get onboardingServerBackupNotFound => 'O backup não foi encontrado no servidor';

  @override
  String get onboardingRestoreThisBackupTitle => 'Restaurar este backup?';

  @override
  String get onboardingRestoreThisBackupBody => 'Os dados locais atuais neste dispositivo serão substituídos.';

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
    return 'Mensagens: $count';
  }

  @override
  String onboardingChatsSummary(Object count) {
    return 'Chats: $count';
  }

  @override
  String onboardingMediaFilesSummary(Object count) {
    return 'Arquivos de mídia: $count';
  }

  @override
  String get onboardingBrokenBackup => 'Arquivo de backup danificado ou inválido';

  @override
  String get onboardingRestoreFailed => 'Falha ao restaurar. Tente novamente.';

  @override
  String get onboardingRestoreLoginTitle => 'Entrar na sua conta';

  @override
  String get onboardingRestoreLoginSubtitle => 'Restaure conversas e definições\na partir de uma cópia criada anteriormente.';

  @override
  String get onboardingRestoreMediaSubtitle => 'Para futuros backups locais: fotos, vídeos, arquivos e avatares serão adicionados somente se isso estiver ativado.';

  @override
  String get onboardingRestoreFromCloudTitle => 'Da nuvem Secretly';

  @override
  String get onboardingRestoreFromCloudSubtitle => 'Digite o Secretly ID e a senha do backup; os dados serão baixados do servidor';

  @override
  String get onboardingRestoreFromDeviceTitle => 'Encontrar backup neste dispositivo';

  @override
  String get onboardingRestoreFromDeviceSubtitle => 'O Secretly verificará automaticamente backups locais e Downloads';

  @override
  String get onboardingRestoring => 'Restaurando...';

  @override
  String get onboardingRestoreFromServerTitle => 'Restaurar do servidor';

  @override
  String get callRecordOutgoingVideoCall => 'Videochamada enviada';

  @override
  String get callRecordOutgoingCall => 'Chamada enviada';

  @override
  String get callRecordIncomingVideoCall => 'Videochamada recebida';

  @override
  String get callRecordIncomingCall => 'Chamada recebida';

  @override
  String get callRecordMissedCall => 'Chamada perdida';

  @override
  String get callRecordDeclinedCall => 'Chamada recusada';

  @override
  String get callRecordBusy => 'Ocupado';

  @override
  String get callRecordFailed => 'Falha na chamada';

  @override
  String get callRecordCanceled => 'Chamada cancelada';

  @override
  String get callRecordOngoing => 'Chamada em andamento';

  @override
  String get safeBackupInvalidBackup => 'Backup do Secretly inválido';

  @override
  String get recoveryKitPrepareFailed => 'Não foi possível preparar um Recovery Kit neste dispositivo.';

  @override
  String safeBackupPreviewProfileId(String profileId) {
    return 'ID no Secretly: $profileId';
  }

  @override
  String safeBackupPreviewContacts(int count) {
    return 'Contatos: $count';
  }

  @override
  String safeBackupPreviewServer(String server) {
    return 'Servidor: $server';
  }

  @override
  String get safeBackupPreviewTitle => 'Pré-visualização do backup:';

  @override
  String get safeBackupSavedToFiles => 'Backup salvo em Arquivos do Secretly';

  @override
  String get safeBackupExportCanceled => 'Exportação do backup cancelada';

  @override
  String safeBackupExportFailed(Object error) {
    return 'Falha ao exportar o backup: $error';
  }

  @override
  String get safeBackupCreateDialogTitle => 'Criar backup';

  @override
  String get safeBackupServerDestination => 'Backup no servidor';

  @override
  String get safeBackupLocalDestination => 'Backup local';

  @override
  String get safeBackupRestoreDialogTitle => 'Restaurar backup';

  @override
  String get safeBackupRestoreFromDevice => 'Restaurar do dispositivo';

  @override
  String get safeBackupDownloadsLocation => 'Downloads';

  @override
  String get safeBackupDeviceFolderLocation => 'Pasta do dispositivo';

  @override
  String get safeBackupChooseManualHint => 'O Secretly verificou automaticamente os backups locais do app e a pasta Downloads. Se o arquivo estiver em outro lugar, você pode escolhê-lo manualmente.';

  @override
  String get safeBackupChooseManually => 'Escolher manualmente';

  @override
  String safeBackupReadFileFailed(Object error) {
    return 'Não foi possível ler o arquivo de backup: $error';
  }

  @override
  String get safeBackupFrequencyTitle => 'Frequência de salvamento';

  @override
  String get saveAction => 'Salvar';

  @override
  String get safeBackupEnableAutoTitle => 'Ativar backup automático';

  @override
  String get safeBackupEnableAutoSubtitle => 'Roda no app quando há conexão; criptografado com sua senha';

  @override
  String get safeBackupUploadToServer => 'Enviar ao servidor';

  @override
  String get safeBackupSaveOnDevice => 'Salvar neste dispositivo';

  @override
  String get safeBackupPasswordConfigured => 'Senha do backup automático: configurada';

  @override
  String get safeBackupPasswordNotSet => 'Senha do backup automático: não definida';

  @override
  String get safeBackupPasswordSaved => 'Senha do backup automático salva';

  @override
  String genericFailed(Object error) {
    return 'Falha: $error';
  }

  @override
  String get safeBackupSetPassword => 'Definir senha';

  @override
  String get safeBackupPasswordRemoved => 'Senha do backup automático removida';

  @override
  String get safeBackupClearPassword => 'Limpar senha';

  @override
  String get safeBackupRunRequested => 'Backup automático solicitado';

  @override
  String get safeBackupRunNow => 'Executar backup automático agora';

  @override
  String safeBackupLastAutoBackup(String time) {
    return 'Último backup automático: $time';
  }

  @override
  String get safeBackupLastAutoBackupNever => 'Último backup automático: nunca';

  @override
  String safeBackupLastDeviceBackup(String time) {
    return 'Último backup do dispositivo: $time';
  }

  @override
  String safeBackupLastAutoBackupError(Object error) {
    return 'Erro do backup automático: $error';
  }

  @override
  String get securityScopeAppObject => 'o app';

  @override
  String get securityScopePersonalObject => 'conversas pessoais';

  @override
  String get securityUnlockAppTitle => 'Desbloqueie o app';

  @override
  String get securityUnlockPersonalTitle => 'Desbloqueie as conversas pessoais';

  @override
  String get securityUnlockFingerprintAutoSubtitle => 'O desbloqueio por impressão digital começa automaticamente. Se necessário, use sua senha abaixo.';

  @override
  String get securityUnlockBiometricPatternAutoSubtitle => 'A biometria nativa começa automaticamente primeiro. Se necessário, use seu padrão abaixo.';

  @override
  String get securityUnlockNativeSubtitle => 'Confirme o acesso com a autenticação nativa do dispositivo.';

  @override
  String securityUnlockPasswordSubtitle(String scopeName) {
    return 'Digite sua senha para abrir $scopeName.';
  }

  @override
  String securityUnlockPatternSubtitle(String scopeName) {
    return 'Desenhe seu padrão para acessar $scopeName.';
  }

  @override
  String get securityUnlockBiometricSubtitle => 'Confirme sua identidade com a autenticação nativa do dispositivo.';

  @override
  String get securityUnlockAppBiometricReason => 'Autentique-se para desbloquear o app';

  @override
  String get securityUnlockPersonalBiometricReason => 'Autentique-se para abrir as conversas pessoais';

  @override
  String get securityUnlockPasswordMismatch => 'A senha não corresponde. Tente novamente.';

  @override
  String get securityUnlockPatternMismatch => 'O padrão não corresponde.';

  @override
  String get securityUnlockNativeIncomplete => 'A autenticação nativa não foi concluída.';

  @override
  String get securityPasswordContinueHint => 'Digite sua senha para continuar';

  @override
  String get securityUseFingerprint => 'Usar impressão digital';

  @override
  String get securityUsePassword => 'Usar senha';

  @override
  String get securityClearPattern => 'Limpar padrão';

  @override
  String get securityConnectFourDots => 'Conecte pelo menos 4 pontos.';

  @override
  String get securityPasswordMinFourChars => 'Use pelo menos 4 caracteres.';

  @override
  String get securityPasswordsMismatchFull => 'As senhas não correspondem.';

  @override
  String securityPasswordSetupTitle(String scopeName) {
    return 'Senha para $scopeName';
  }

  @override
  String get securityPasswordSetupDescription => 'A senha é armazenada apenas no cofre seguro do dispositivo.';

  @override
  String get securityNewPassword => 'Nova senha';

  @override
  String get securityRepeatPassword => 'Repita a senha';

  @override
  String get securitySavePassword => 'Salvar senha';

  @override
  String get securityPatternSetupInstruction => 'Desenhe um padrão com pelo menos 4 pontos.';

  @override
  String get securityPatternSetupRepeat => 'Repita o padrão para confirmar.';

  @override
  String get securityPatternMinFourDots => 'Use pelo menos 4 pontos.';

  @override
  String get securityPatternMismatchStartOver => 'Os padrões não correspondem. Comece novamente.';

  @override
  String securityPatternSetupTitle(String scopeName) {
    return 'Padrão para $scopeName';
  }

  @override
  String get securityStartOver => 'Começar novamente';

  @override
  String get securityTitle => 'Segurança';

  @override
  String get securityNativeAuthentication => 'Autenticação nativa';

  @override
  String get securityReady => 'Pronto';

  @override
  String get securityUnavailable => 'Indisponível';

  @override
  String get securityNativeAvailableDescription => 'Usada para Face ID, impressão digital e autenticação nativa do dispositivo.';

  @override
  String get securityNativeUnavailableDescription => 'A biometria ou autenticação nativa do dispositivo não está disponível agora.';

  @override
  String get securityAppLockTitle => 'Bloqueio do app';

  @override
  String get securityAppLockDescription => 'Protege a entrada no app e pode bloquear novamente quando o app é ocultado.';

  @override
  String get securityPersonalChatsTitle => 'Conversas pessoais';

  @override
  String get securityPersonalChatsDescription => 'Protege a seção Pessoal oculta e a entrada direta em conversas pessoais.';

  @override
  String get securityAuthEnableAppLockReason => 'Autentique-se para ativar o bloqueio do app';

  @override
  String get securityAuthChangeSettingsReason => 'Autentique-se para alterar as configurações de segurança';

  @override
  String get securityAuthProtectPersonalReason => 'Autentique-se para proteger conversas pessoais';

  @override
  String get securityAuthChangePersonalReason => 'Autentique-se para alterar a proteção das conversas pessoais';

  @override
  String get securityNativeUnavailableError => 'A autenticação nativa não está disponível neste dispositivo.';

  @override
  String get securityBiometricCancelled => 'A confirmação biométrica foi cancelada.';

  @override
  String get securityProtectionMode => 'Modo de proteção';

  @override
  String get securityProtectionModeSubtitle => 'Escolha como o acesso deve ser protegido.';

  @override
  String get securityProtectionModeDescription => 'Senhas e padrões são armazenados apenas como hashes fortes no secure storage. A biometria usa a tela nativa do sistema.';

  @override
  String get securityProtectionOff => 'Desativado';

  @override
  String get securityProtectionOffDescription => 'Acesso sem proteção extra.';

  @override
  String get securityPasswordModeDescription => 'Uma senha dedicada para desbloquear o acesso.';

  @override
  String get securityPatternModeTitle => 'Padrão';

  @override
  String get securityPatternModeDescription => 'Um padrão de pontos semelhante ao bloqueio do Android.';

  @override
  String get securityNativePromptDescription => 'A tela nativa de Face ID, impressão digital ou autenticação do sistema do dispositivo.';

  @override
  String get securityRelockAfterHidden => 'Bloquear novamente quando o app for ocultado';

  @override
  String get securityRelockAfterHiddenDescription => 'Se desativado, a proteção só volta após reiniciar totalmente o app.';

  @override
  String get securityGracePeriod => 'Período antes de bloquear novamente';

  @override
  String get securityGraceUnavailable => 'Indisponível enquanto o bloqueio em segundo plano estiver desativado.';

  @override
  String securityAllowQuickUnlockWith(String method) {
    return 'Permitir desbloqueio rápido com $method';
  }

  @override
  String get securityQuickUnlockSubtitle => 'Mantém a senha ou o padrão como principal método reserva.';

  @override
  String get securityChangePassword => 'Alterar senha';

  @override
  String get securityChangePattern => 'Alterar padrão';

  @override
  String get securityChangeCredentialSubtitle => 'A proteção atual será atualizada assim que o novo segredo for confirmado.';

  @override
  String get securityProtectionActivated => 'A proteção foi ativada imediatamente.';

  @override
  String get securityLockNow => 'Bloquear agora';

  @override
  String get securitySaveChanges => 'Salvar alterações';

  @override
  String get securityGraceImmediately => 'Imediatamente';

  @override
  String securityGraceAfterSeconds(int seconds) {
    return 'Depois de $seconds s';
  }

  @override
  String securityGraceAfterMinutes(int minutes) {
    return 'Depois de $minutes min';
  }

  @override
  String get securityStatusLocked => 'Bloqueado';

  @override
  String get securityStatusUnlocked => 'Desbloqueado';

  @override
  String get securityAfterHide => 'Ao ocultar';

  @override
  String securityGracePill(int seconds) {
    return 'Espera $seconds s';
  }

  @override
  String get securityNoProtection => 'Sem proteção';

  @override
  String get securityNativeBiometrics => 'Biometria nativa';

  @override
  String get securityBiometricFaceFingerprint => 'Face ID / impressão digital';

  @override
  String get securityBiometricFingerprint => 'Impressão digital';

  @override
  String get securityBiometricNativeDeviceAuthentication => 'Autenticação nativa do dispositivo';

  @override
  String get devicesLinkOpenFailed => 'Não foi possível abrir o link no navegador.';

  @override
  String get devicesDesktopDescriptionPrefix => 'Você pode entrar no ';

  @override
  String get devicesDesktopAppLink => 'app Secretly para desktop';

  @override
  String get devicesDesktopDescriptionSuffix => ' usando um código QR.';

  @override
  String get devicesFailureTransportBlocked => 'O transporte está bloqueado para o servidor atual. Coloque telefone e desktop no mesmo servidor e tente novamente.';

  @override
  String get devicesFailureIdentityNotServerBacked => 'A identidade do desktop ainda não está registrada no servidor. Tente novamente em alguns segundos.';

  @override
  String get devicesFailureProfileUnavailable => 'O perfil do desktop ainda não está visível no servidor. Mantenha o app aberto e tente novamente.';

  @override
  String get devicesFailureDeviceUnavailable => 'O dispositivo desktop ainda não está visível no servidor. Mantenha o app aberto, atualize o QR e tente novamente.';

  @override
  String get devicesFailureCompanionRequired => 'O acesso companion para desktop não está ativado para este perfil. Ative no telefone principal e tente novamente.';

  @override
  String get devicesFailureCompanionLimit => 'O limite de dispositivos desktop já está em uso para este perfil. Remova um desktop antigo ou aumente os lugares disponíveis.';

  @override
  String get devicesFailurePrimaryRequired => 'Crie a conta principal no telefone primeiro e depois vincule o desktop com QR.';

  @override
  String get devicesFailureInvalidQr => 'Este QR não é um código de autorização de dispositivo.';

  @override
  String get devicesFailureQrExpired => 'O código QR expirou. Gere um novo no desktop.';

  @override
  String get devicesFailureServerMismatch => 'Este QR pertence a outro servidor. Coloque telefone e desktop no mesmo servidor e tente novamente.';

  @override
  String get devicesFailureProfileMismatch => 'O pacote de sincronização aponta para outro perfil. Gere um novo QR e tente novamente.';

  @override
  String get devicesFailureRequestNotFound => 'A solicitação de sincronização do desktop não foi encontrada ou já expirou. Gere um novo QR.';

  @override
  String get devicesFailureSessionExpired => 'A sessão QR expirou. Gere um novo QR e tente novamente.';

  @override
  String get devicesFailureSessionValidation => 'A validação da sessão QR falhou. Gere um novo QR e tente novamente.';

  @override
  String get devicesFailureStateMismatch => 'O estado da solicitação de sincronização não corresponde mais. Gere um novo QR e tente novamente.';

  @override
  String get devicesFailureDeviceMismatch => 'O pacote de sincronização aponta para outro dispositivo. Gere um novo QR e tente novamente.';

  @override
  String get devicesFailureDeclined => 'A entrada foi recusada no telefone principal. Gere um novo QR para tentar novamente.';

  @override
  String get devicesFailureInvalidPayload => 'Pacote de sincronização do desktop inválido. Gere um novo QR e tente novamente.';

  @override
  String get devicesFailureInterrupted => 'A sincronização segura foi interrompida antes de terminar. Gere um novo QR e tente novamente.';

  @override
  String get devicesNewUser => 'Novo usuário';

  @override
  String get devicesNewUserDesktopConfirm => 'Limpar dados locais e preparar este dispositivo desktop para entrada por QR a partir do telefone principal?';

  @override
  String get devicesNewUserMobileConfirm => 'Limpar o perfil local atual e registrar um novo usuário neste dispositivo?';

  @override
  String get devicesCreateAction => 'Criar';

  @override
  String get devicesScanDeviceQr => 'Escanear QR do dispositivo';

  @override
  String get devicesRequestApproved => 'Solicitação aprovada. Pacote de sincronização enviado ao desktop.';

  @override
  String get devicesRequestDeclined => 'Solicitação recusada. O desktop continuará não autenticado.';

  @override
  String get devicesApproveSignInTitle => 'Aprovar entrada neste dispositivo?';

  @override
  String get devicesConfirmSyncPrimary => 'Confirme a sincronização a partir do dispositivo principal (telefone).';

  @override
  String devicesApprovalDeviceOnly(String name) {
    return 'Dispositivo: $name. A aprovação só é permitida a partir do telefone principal.';
  }

  @override
  String get devicesSyncChats => 'Sincronizar conversas';

  @override
  String get devicesSyncSettings => 'Sincronizar configurações';

  @override
  String get devicesSyncMedia => 'Sincronizar mídia';

  @override
  String get devicesDeclineSignIn => 'Recusar entrada';

  @override
  String get devicesApprove => 'Aprovar';

  @override
  String get devicesTitle => 'Dispositivos';

  @override
  String get devicesConnectDevice => 'Conectar dispositivo';

  @override
  String get devicesPrimaryDeviceTitle => 'Este é o dispositivo principal';

  @override
  String get devicesPrimaryDeviceSubtitle => 'A permissão para sincronizar conversas, configurações e mídia é concedida apenas aqui.';

  @override
  String get devicesQrSessionExpiredNewCode => 'A sessão QR expirou. Gere um novo código.';

  @override
  String devicesQrExpiresIn(String time) {
    return 'QR expira em $time';
  }

  @override
  String get devicesWaitingQrScan => 'Aguardando leitura do QR no telefone.';

  @override
  String get devicesQrScannedConfirm => 'QR lido. Confirme a entrada no telefone.';

  @override
  String get devicesApplyingSecureBundle => 'Aplicando pacote de sincronização segura…';

  @override
  String get devicesAuthorizationFailed => 'Falha na autorização. Tente novamente.';

  @override
  String get devicesUnauthenticatedChooseAction => 'Você não está autenticado. Escolha uma ação abaixo.';

  @override
  String get devicesAuthenticated => 'Dispositivo autenticado.';

  @override
  String get devicesDesktopWebAuthorization => 'Autorização Desktop/Web';

  @override
  String get devicesDesktopModeDescription => 'Escolha o modo: registrar um novo usuário ou entrar por QR com aprovação no telefone.';

  @override
  String get devicesCancelQr => 'Cancelar QR';

  @override
  String get devicesRefreshQr => 'Atualizar QR';

  @override
  String get devicesSignInViaQr => 'Entrar por QR';

  @override
  String get devicesOpenPrimaryInstruction => 'Abra o Secretly no telefone principal → Configurações → Dispositivos → Conectar dispositivo.';

  @override
  String get storageSection => 'Armazenamento';

  @override
  String get storageSectionSubtitle => 'Cache e downloads neste dispositivo';

  @override
  String get storageUsageTitle => 'Uso do armazenamento';

  @override
  String get storageCategoryMedia => 'Cache de mídia';

  @override
  String get storageCategoryVoiceTranscripts => 'Transcrições de voz';

  @override
  String get storageCategoryVoiceModel => 'Modelo de voz off-line';

  @override
  String get storageCategoryStickers => 'Figurinhas';

  @override
  String get storageCategoryEmoji => 'Emojis animados';

  @override
  String get storageCategoryProfileMedia => 'Minha galeria e avatares';

  @override
  String get storageCategoryRecents => 'Arquivos recentes';

  @override
  String get storageTotal => 'Total';

  @override
  String get storageCalculating => 'Calculando…';

  @override
  String get storageClearCache => 'Limpar cache';

  @override
  String get storageClearCacheHint => 'Remove mídia em cache, avatares de contatos e emojis animados. Sua galeria, figurinhas e conversas são mantidas; a mídia é baixada novamente ao visualizar.';

  @override
  String get storageClearing => 'Limpando cache…';

  @override
  String get storageClearedToast => 'Cache limpo';

  @override
  String get storageRemoveVoiceModel => 'Remover modelo de voz off-line (140 MB)';

  @override
  String get storageRemoveVoiceModelHint => 'Libera o modelo de reconhecimento de voz no dispositivo. Ele é baixado novamente automaticamente na próxima vez que você transcrever uma mensagem de voz.';

  @override
  String get storageRemoveVoiceModelConfirmTitle => 'Remover modelo de voz?';

  @override
  String get storageRemoveVoiceModelConfirmBody => 'O modelo de reconhecimento de voz de 140 MB será excluído do dispositivo. Ele é baixado novamente automaticamente na próxima vez que você transcrever uma mensagem de voz.';

  @override
  String get storageRemoveVoiceModelConfirm => 'Remover';

  @override
  String get storageVoiceModelNotInstalled => 'Nenhum modelo de voz está instalado';

  @override
  String get storageVoiceModelRemovedToast => 'Modelo de voz removido';

  @override
  String get backupStateProtected => 'Seu histórico está protegido';

  @override
  String get backupStateUnprotected => 'Seu histórico não está protegido';

  @override
  String get backupStateFailing => 'Os backups estão falhando';

  @override
  String get backupStateStale => 'O backup está desatualizado';

  @override
  String get backupStateNone => 'Ainda sem backup';

  @override
  String backupLastAt(Object time) {
    return 'Último backup: $time';
  }

  @override
  String get backupIntroHint => 'Um backup permite levar suas conversas para um novo aparelho';

  @override
  String get backupAccessUpgradeTitle => 'Salve a cópia novamente';

  @override
  String get backupAccessUpgradeBody => 'Sua cópia no servidor foi criada no formato antigo: ela pode ser baixada por quem souber o identificador do perfil. O conteúdo continua criptografado com sua senha, mas uma segunda barreira não faz mal. Salvar de novo adiciona uma verificação de senha no próprio servidor.';

  @override
  String get backupAccessUpgradeAction => 'Salvar novamente';

  @override
  String get backupSectionAutomatic => 'Automático';

  @override
  String get backupAutoToggle => 'Fazer backup automaticamente';

  @override
  String get backupPassword => 'Senha';

  @override
  String get backupPasswordSet => 'Definida';

  @override
  String get backupPasswordNotSet => 'Não definida';

  @override
  String get backupPasswordSaved => 'Senha salva';

  @override
  String get backupWhere => 'Onde';

  @override
  String get backupHowOften => 'Com que frequência';

  @override
  String get backupIncludeMedia => 'Incluir mídia';

  @override
  String get backupAutoFooter => 'O backup é criptografado com sua senha. Sem ela nada pode ser restaurado — guarde-a em segurança. A mídia nunca é enviada ao servidor.';

  @override
  String get backupNow => 'Fazer backup agora';

  @override
  String get backupSectionRestore => 'Restaurar';

  @override
  String get backupRestoreAction => 'Restaurar de um backup';

  @override
  String get backupRestoreFooter => 'Substitui as conversas e configurações deste aparelho pelo conteúdo do backup.';

  @override
  String get backupSectionKey => 'Chave do Secretly ID';

  @override
  String get backupKeyShow => 'Mostrar a chave';

  @override
  String get backupKeyRestore => 'Restaurar com uma chave';

  @override
  String get backupKeyFooter => 'Restaura apenas seu Secretly ID — não contém conversas. Restaurar com uma chave apaga os dados locais.';

  @override
  String get backupDestServerDevice => 'Servidor e aparelho';

  @override
  String get backupDestServer => 'Servidor';

  @override
  String get backupDestDevice => 'Aparelho';

  @override
  String get backupDestNone => 'Não escolhido';

  @override
  String get backupDestServerOnly => 'Somente servidor';

  @override
  String get backupDestDeviceOnly => 'Somente aparelho';

  @override
  String get backupTileOff => 'Desligado — seu histórico não está protegido';

  @override
  String get backupTilePending => 'Ligado, mas ainda não foi executado';

  @override
  String get backupTileFailing => 'Não está funcionando — verifique';

  @override
  String get backupTileStale => 'Sem atualização há algum tempo';

  @override
  String get backupPasswordChange => 'Alterar senha';

  @override
  String get backupPasswordRemove => 'Remover senha';

  @override
  String get chatUndecryptablePending => 'Chegou uma mensagem, mas ainda não pode ser lida — restaurando a sessão segura…';

  @override
  String get liquidGlassTitle => 'Vidro líquido';

  @override
  String get liquidGlassSubtitle => 'Barras e ilhas com refração. Desligue para o material simples — gasta menos energia e esquenta menos.';

  @override
  String get billingPendingTitle => 'Aguardando o pagamento';

  @override
  String get billingPendingBody => 'O pedido foi criado, mas o pagamento ainda não foi confirmado. Conclua o pagamento pelo método escolhido — o Premium será ativado sozinho.';

  @override
  String get callsHideAddressTitle => 'Ocultar meu endereço nas chamadas';

  @override
  String get callsHideAddressSubtitle => 'Pelo nosso servidor: a outra pessoa não verá seu endereço IP, mas a latência pode aumentar';

  @override
  String get desktopJoinRoomByLink => 'Entrar por link';

  @override
  String get desktopJoinRoomLinkHint => 'Cole o link do convite';

  @override
  String get desktopJoinRoomLinkInvalid => 'Este não é um link de convite para uma sala';

  @override
  String get desktopOfflineLockTitle => 'Pedir a senha após muito tempo sem conexão';

  @override
  String get desktopOfflineLockDescription => 'Se este computador não falar com o servidor por mais tempo que o limite, ele pede a senha ao iniciar. Um computador perdido nunca recebe a desconexão remota, mas alcança esse limite.';

  @override
  String get desktopOfflineLockNever => 'Nunca';

  @override
  String get desktopOfflineLockDays7 => '7 dias';

  @override
  String get desktopOfflineLockDays14 => '14 dias';

  @override
  String get desktopOfflineLockDays30 => '30 dias';

  @override
  String get desktopPollTitle => 'Enquete';

  @override
  String get desktopPollAnonymous => 'Enquete anônima';

  @override
  String get desktopPollClosed => 'Encerrada';

  @override
  String desktopPollVoters(Object count) {
    return 'Votaram: $count';
  }

  @override
  String get desktopPollMultipleHint => 'Você pode escolher várias';

  @override
  String get desktopPollCloseAction => 'Encerrar a enquete';

  @override
  String get desktopEventTitle => 'Evento';

  @override
  String get desktopEventGoing => 'Vou';

  @override
  String get desktopEventMaybe => 'Talvez';

  @override
  String get desktopEventNo => 'Não vou';

  @override
  String get desktopPollNewTitle => 'Nova enquete';

  @override
  String get desktopPollQuestionHint => 'Pergunta';

  @override
  String desktopPollOptionHint(Object index) {
    return 'Opção $index';
  }

  @override
  String get desktopPollAddOption => 'Adicionar opção';

  @override
  String get desktopPollCreateAction => 'Criar';

  @override
  String get desktopPollNeedTwo => 'É preciso uma pergunta e pelo menos duas opções';

  @override
  String get desktopPollMultipleLabel => 'Várias respostas';

  @override
  String get desktopPollAnonymousLabel => 'Anônima';

  @override
  String get desktopEventNewTitle => 'Novo evento';

  @override
  String get desktopEventTitleHint => 'Título';

  @override
  String get desktopEventDescriptionHint => 'Descrição';

  @override
  String get desktopEventLocationHint => 'Local';

  @override
  String get desktopEventPickWhen => 'Escolher data e hora';

  @override
  String get desktopEventNeedTitleAndDate => 'São necessários um título e uma data';

  @override
  String get desktopViewerOpenExternally => 'Abrir em outro app';

  @override
  String get desktopViewerSaveAs => 'Salvar como…';

  @override
  String desktopViewerPage(Object page, Object total) {
    return 'Página $page de $total';
  }

  @override
  String get desktopViewerFailed => 'Não foi possível mostrar o arquivo';

  @override
  String get desktopViewerTooLarge => 'O arquivo é grande demais para mostrar aqui';

  @override
  String get desktopSupportAttach => 'Anexar um arquivo';

  @override
  String desktopSupportAttachHint(Object limit) {
    return 'Uma captura de tela ou um arquivo de log — até $limit. O anexo é criptografado junto com a mensagem.';
  }

  @override
  String desktopSupportTooLarge(Object limit) {
    return 'O arquivo é maior que $limit e não pode ser enviado';
  }

  @override
  String get desktopSupportUnreadable => 'Não foi possível ler o arquivo';

  @override
  String get desktopSupportRemoveAttachment => 'Remover o anexo';

  @override
  String desktopSupportMegabytes(Object value) {
    return '$value MB';
  }

  @override
  String get desktopSupportYou => 'Você';

  @override
  String get desktopSupportShrunk => 'A imagem foi reduzida para caber';

  @override
  String get desktopStickerPackTitle => 'Pacote de figurinhas';

  @override
  String get desktopStickerPackAddPlain => 'Adicionar o pacote';

  @override
  String get desktopStickerPackInstalled => 'Instalado';

  @override
  String get desktopStickerPackInstalling => 'Instalando…';

  @override
  String get desktopStickerPackOwn => 'Este é o seu próprio pacote';

  @override
  String get desktopStickerPackNoAuthor => 'O autor do pacote é desconhecido — abra a mesma figurinha em uma conversa individual';

  @override
  String desktopStickerPackInstallingProgress(Object done, Object total) {
    return 'Instalando… $done/$total';
  }

  @override
  String desktopStickerPackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count figurinhas',
      one: '$count figurinha',
    );
    return '$_temp0';
  }

  @override
  String desktopStickerPackAdd(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Adicionar $count figurinhas',
      one: 'Adicionar $count figurinha',
    );
    return '$_temp0';
  }

  @override
  String get desktopPairingTitle => 'Conecte o Secretly Desktop';

  @override
  String get desktopPairingHowTo => 'No celular abra Secretly → Configurações → Dispositivos → “Conectar dispositivo” e escaneie este QR code.';

  @override
  String get desktopPairingPreparingQr => 'Preparando o QR…';

  @override
  String get desktopPairingQrUnavailable => 'QR indisponível';

  @override
  String get desktopPairingCodeExpired => 'O código expirou — atualizando…';

  @override
  String desktopPairingCodeValidFor(Object time) {
    return 'O código é válido por mais $time';
  }

  @override
  String get desktopPairingPrepareFailed => 'Não foi possível preparar o código. Verifique sua conexão com a internet e tente novamente.';

  @override
  String get desktopPairingRevoked => 'Este dispositivo foi removido da conta, por isso nenhum código é criado.\nConecte o computador novamente — ele receberá uma nova identidade de dispositivo, e a antiga continua revogada. Só uma confirmação pelo celular dá acesso às conversas.';

  @override
  String get desktopPairingPreparingNew => 'Preparando uma nova conexão…';

  @override
  String get desktopPairingConnectAsNew => 'Conectar como novo dispositivo';

  @override
  String get desktopPairingIdentityResetFailed => 'Não foi possível recriar a identidade do dispositivo. Reinicie o aplicativo e tente novamente.';

  @override
  String get desktopPairingWaitingConfirm => 'Aguardando confirmação…';

  @override
  String get desktopPairingNewQr => 'Gerar um novo QR';

  @override
  String get desktopPairingCreatingRequest => 'Criando a solicitação…';

  @override
  String get desktopPairingReadyToScan => 'Pronto para escanear';

  @override
  String get desktopPairingWaitingScan => 'Aguardando a leitura no celular…';

  @override
  String get desktopPairingScannedConfirmOnPhone => 'QR escaneado — confirme no celular.';

  @override
  String get desktopPairingFetchingProfile => 'Obtendo o perfil e as chaves…';

  @override
  String get desktopPairingConnectedLoading => 'Conectado. Carregando…';

  @override
  String get desktopPairingConnectionError => 'Erro de conexão. Tente novamente.';

  @override
  String get desktopMenuReaction => 'Reação';

  @override
  String get desktopMenuContinueInTopic => 'Continuar em um tópico';

  @override
  String get desktopMenuCopySelection => 'Copiar a seleção';

  @override
  String get desktopMenuCopyText => 'Copiar o texto';

  @override
  String get desktopMenuCopyLink => 'Copiar o link';

  @override
  String get desktopMenuTranslate => 'Traduzir';

  @override
  String get desktopMenuHideTranslation => 'Ocultar a tradução';

  @override
  String get desktopMenuSelect => 'Selecionar';

  @override
  String get desktopMenuPhotoOrVideo => 'Foto ou vídeo';

  @override
  String get desktopMenuContact => 'Contato';

  @override
  String get desktopMenuLocation => 'Localização';

  @override
  String get desktopListPinned => 'FIXADOS';

  @override
  String get desktopListToday => 'HOJE';

  @override
  String get desktopListYesterday => 'ONTEM';

  @override
  String get desktopListThisWeek => 'ESTA SEMANA';

  @override
  String get desktopListEarlier => 'ANTES';

  @override
  String get desktopListNothingFound => 'Nada encontrado';

  @override
  String get desktopListAddFavourite => 'Adicionar aos favoritos';

  @override
  String get desktopListRemoveFavourite => 'Remover dos favoritos';

  @override
  String get desktopListMute => 'Silenciar';

  @override
  String get desktopListMarkRead => 'Marcar como lida';

  @override
  String get desktopListArchive => 'Arquivar';

  @override
  String get desktopListFolders => 'Pastas';

  @override
  String get desktopListCreate => 'Criar';

  @override
  String get desktopListTyping => 'digitando';

  @override
  String get desktopListDraftPrefix => 'Rascunho: ';

  @override
  String desktopListDiscussion(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Conversa · $count participantes',
      one: 'Conversa · $count participante',
    );
    return '$_temp0';
  }

  @override
  String get desktopCallServerSilent => 'O servidor não respondeu. Tente novamente ou saia da chamada.';

  @override
  String get desktopCallRoomMissing => 'A sala não está disponível no servidor — não é possível iniciar uma chamada nela.';

  @override
  String get desktopCallNoServer => 'Sem conexão com o servidor. Verifique sua conexão.';

  @override
  String get desktopCallJoinFailed => 'Não foi possível entrar na chamada. Verifique a conexão e tente novamente.';

  @override
  String desktopCallSharingScreen(Object name) {
    return '$name está compartilhando a tela';
  }

  @override
  String get desktopCallRoomEmpty => 'Ainda não foi escrito nada na sala';

  @override
  String get desktopCallMessageHint => 'Mensagem para a sala…';

  @override
  String get desktopCallSendToRoom => 'Enviar para a sala';

  @override
  String desktopCallParticipantsTab(Object count) {
    return 'Participantes · $count';
  }

  @override
  String get desktopCallNotesTab => 'Notas';

  @override
  String get desktopCallLinkCopied => 'Link copiado';

  @override
  String get desktopCallFailed => 'Não foi possível';

  @override
  String desktopCallFailedWith(Object error) {
    return 'Não foi possível: $error';
  }

  @override
  String get desktopCallMicOn => 'Ligar o microfone';

  @override
  String get desktopCallMicOff => 'Desligar o microfone';

  @override
  String get desktopCallCamOn => 'Ligar a câmera';

  @override
  String get desktopCallCamOff => 'Desligar a câmera';

  @override
  String get desktopCallNoMediaVideo => 'O servidor não forneceu canal de mídia — o vídeo está indisponível';

  @override
  String get desktopCallLayoutSingle => 'Um';

  @override
  String get desktopCallLayoutGrid => 'Grade';

  @override
  String get desktopCallShowOneLarge => 'Mostrar uma pessoa em tamanho grande';

  @override
  String get desktopCallShowGrid => 'Mostrar todos em grade';

  @override
  String get desktopCallScreen => 'Tela';

  @override
  String get desktopCallShareStop => 'Parar o compartilhamento da tela';

  @override
  String get desktopCallShareStart => 'Compartilhar a tela';

  @override
  String get desktopCallNoMediaScreen => 'O servidor não forneceu canal de mídia — o compartilhamento de tela está indisponível';

  @override
  String get desktopCallLeave => 'Sair';

  @override
  String get desktopCallLeaveCall => 'Sair da chamada';

  @override
  String get desktopCallNoMediaBoth => 'O servidor não forneceu canal de mídia: esta chamada não terá som nem vídeo';

  @override
  String get desktopCallMinimise => 'Minimizar a chamada';

  @override
  String get desktopCallDiscussion => 'Conversa';

  @override
  String desktopCallDiscussionOf(Object title) {
    return 'Conversa · $title';
  }

  @override
  String get desktopCallEncrypted => 'A chamada é criptografada de ponta a ponta';

  @override
  String desktopCallDurationOnAir(Object duration, Object count) {
    return '$duration · $count no ar';
  }

  @override
  String get desktopCallExitFullScreen => 'Sair da tela cheia';

  @override
  String get desktopCallFullScreen => 'Tela cheia';

  @override
  String get desktopCallDemoRoom => 'Sala de demonstração';

  @override
  String get desktopCallNoCallYet => 'Ainda não há chamada';

  @override
  String get desktopCallDemoExplain => 'Existe apenas neste computador e não está no servidor — não é possível iniciar uma chamada. Em uma sala real o botão funciona.';

  @override
  String get desktopCallStartHint => 'Comece — os outros verão o convite na sala';

  @override
  String get desktopCallVoiceOnly => 'Só voz';

  @override
  String get desktopCallWithCamera => 'Com câmera';

  @override
  String get desktopCallConnecting => 'Conectando…';

  @override
  String get desktopCallOngoing => 'Há uma conversa em andamento';

  @override
  String desktopCallOnAir(Object count) {
    return '$count no ar';
  }

  @override
  String get desktopCallJoin => 'Entrar';

  @override
  String get desktopCallFullScreenShort => 'Tela cheia';

  @override
  String get desktopCallReconnecting => 'reconectando';

  @override
  String get desktopCallCannotHear => 'não ouve';

  @override
  String get desktopCallSharingShort => 'está compartilhando a tela';

  @override
  String get desktopCallCameraOn => 'câmera ligada';

  @override
  String get desktopCallPickDevice => 'Escolher um dispositivo';

  @override
  String get desktopCallPreparingLink => 'Preparando o link…';

  @override
  String get desktopCallInvite => 'Convidar';

  @override
  String desktopCallFps(Object fps) {
    return '$fps q/s';
  }

  @override
  String get desktopSettingsTitle => 'Configurações';

  @override
  String get desktopSettingsGroupApp => 'Aplicativo';

  @override
  String get desktopSettingsGroupPrivacy => 'Privacidade e segurança';

  @override
  String get desktopSettingsGroupAccount => 'Conta e dados';

  @override
  String get desktopSettingsGeneralLabel => 'Geral';

  @override
  String get desktopSettingsGeneralSubtitle => 'Idioma, comportamento do aplicativo';

  @override
  String get desktopSettingsGeneralKeywords => 'idioma, região, enter, envio, entrada';

  @override
  String get desktopSettingsAppearanceLabel => 'Aparência';

  @override
  String get desktopSettingsAppearanceSubtitle => 'Tema, acento, papel de parede da conversa';

  @override
  String get desktopSettingsAppearanceKeywords => 'tema, acento, fundo, balões, cor, escuro, marcas, animação';

  @override
  String get desktopSettingsShortcutsLabel => 'Atalhos de teclado';

  @override
  String get desktopSettingsShortcutsSubtitle => 'O que apertar para ser mais rápido';

  @override
  String get desktopSettingsShortcutsKeywords => 'teclas, atalhos, rápido, cmd, ctrl';

  @override
  String get desktopSettingsPowerLabel => 'Consumo de energia';

  @override
  String get desktopSettingsPowerSubtitle => 'O que gasta a bateria';

  @override
  String get desktopSettingsPowerKeywords => 'bateria, animação, molduras, vidro, desempenho, calor';

  @override
  String get desktopSettingsNotificationsLabel => 'Notificações';

  @override
  String get desktopSettingsNotificationsSubtitle => 'Sons, prévia, silêncio';

  @override
  String get desktopSettingsNotificationsKeywords => 'som, prévia, silêncio, não perturbe, faixa, texto';

  @override
  String get desktopSettingsCallsLabel => 'Chamadas';

  @override
  String get desktopSettingsCallsSubtitle => 'Receber chamadas e compartilhar a tela';

  @override
  String get desktopSettingsCallsKeywords => 'chamadas, recebidas, compartilhamento de tela, vídeo, áudio';

  @override
  String get desktopSettingsMediaLabel => 'Som e vídeo';

  @override
  String get desktopSettingsMediaSubtitle => 'Câmera e microfone para chamadas';

  @override
  String get desktopSettingsMediaKeywords => 'câmera, microfone, dispositivo, webcam, fones, som, vídeo';

  @override
  String get desktopSettingsPrivacyLabel => 'Privacidade';

  @override
  String get desktopSettingsPrivacySubtitle => 'Quem vê o que sobre você';

  @override
  String get desktopSettingsPrivacyKeywords => 'quem vê, visto por último, foto, chamadas, mensagens, encaminhar, apelido, busca, desconhecidos';

  @override
  String get desktopSettingsSecurityLabel => 'Segurança';

  @override
  String get desktopSettingsSecuritySubtitle => 'Criptografia e dispositivos verificados';

  @override
  String get desktopSettingsSecurityKeywords => 'criptografia, e2ee, verificados, bloqueio, senha, touch id, verificação';

  @override
  String get desktopSettingsBackupLabel => 'Backup';

  @override
  String get desktopSettingsBackupSubtitle => 'O que salva o histórico das conversas';

  @override
  String get desktopSettingsBackupKeywords => 'backup, cópia, restauração, safe backup, senha, mídia';

  @override
  String get desktopSettingsBlockedLabel => 'Bloqueados';

  @override
  String get desktopSettingsBlockedSubtitle => 'Quem não tem acesso a você';

  @override
  String get desktopSettingsBlockedKeywords => 'bloqueio, bloqueados, desbloquear, lista negra, spam';

  @override
  String get desktopSettingsDevicesLabel => 'Sessões e dispositivos';

  @override
  String get desktopSettingsDevicesSubtitle => 'Sessões ativas';

  @override
  String get desktopSettingsDevicesKeywords => 'dispositivos, sessões, qr, vínculo, sair, backup';

  @override
  String get desktopSettingsAccountLabel => 'Conta';

  @override
  String get desktopSettingsAccountSubtitle => 'Perfil e saída';

  @override
  String get desktopSettingsAccountKeywords => 'nome, sobre mim, id, sair, redefinir';

  @override
  String get desktopSettingsStorageLabel => 'Armazenamento';

  @override
  String get desktopSettingsStorageSubtitle => 'Cache, downloads';

  @override
  String get desktopSettingsStorageKeywords => 'cache, espaço, limpar, mídia, downloads';

  @override
  String get desktopSettingsSupportLabel => 'Suporte';

  @override
  String get desktopSettingsSupportSubtitle => 'Uma conversa criptografada conosco';

  @override
  String get desktopSettingsSupportKeywords => 'suporte, ajuda, problema, erro, escrever';

  @override
  String get desktopSettingsAboutLabel => 'Sobre';

  @override
  String get desktopSettingsAboutKeywords => 'versão, compilação, licenças, site';

  @override
  String get desktopSettingsDangerLabel => 'Excluir a conta';

  @override
  String get desktopSettingsEndCallFirst => 'Encerre primeiro a chamada ativa.';

  @override
  String get desktopSettingsSignOutTitle => 'Sair da conta neste computador?';

  @override
  String get desktopSettingsSignOutBody => 'Deste computador serão removidas as conversas, as chaves e o cache. A conta e o histórico no celular não são afetados — o computador pode ser conectado de novo por QR code.';

  @override
  String get desktopSettingsSignOut => 'Sair';

  @override
  String desktopSettingsSignOutFailed(Object error) {
    return 'Não foi possível sair: $error';
  }

  @override
  String get desktopSettingsActive => 'ativo';
}
