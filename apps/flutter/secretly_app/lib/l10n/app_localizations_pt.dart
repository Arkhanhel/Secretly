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

  @override
  String get desktopGeneralSystemLanguage => 'Do sistema';

  @override
  String get desktopGeneralInterfaceLanguage => 'Idioma da interface';

  @override
  String get desktopGeneralAppliesAtOnce => 'Aplica-se de imediato';

  @override
  String get desktopGeneralBehaviour => 'Comportamento';

  @override
  String get desktopGeneralEnterSends => 'Enter envia a mensagem';

  @override
  String get desktopGeneralShiftEnterNewline => 'Shift+Enter inicia uma nova linha';

  @override
  String get desktopGeneralEnterNewline => 'Enter inicia uma nova linha, Shift+Enter envia';

  @override
  String get desktopGeneralHoverMenu => 'Menu ao passar sobre uma mensagem';

  @override
  String get desktopGeneralHoverMenuOn => 'Acima da mensagem aparecem reações e ações';

  @override
  String get desktopGeneralHoverMenuOff => 'As ações estão no botão direito';

  @override
  String get desktopGeneralLinkPreviews => 'Pré-visualização de ligações';

  @override
  String get desktopGeneralLinkPreviewsOn => 'O cartão da ligação segue com a mensagem';

  @override
  String get desktopGeneralLinkPreviewsOff => 'As ligações seguem sem cartão e nenhuma página é aberta';

  @override
  String get desktopPowerAnimations => 'Animações';

  @override
  String get desktopPowerAnimationsHint => 'Está tudo ligado por omissão. Desligue de cima para baixo se o portátil aquecer ou a bateria descer.';

  @override
  String get desktopPowerFramesTitle => 'Animação de molduras e estados';

  @override
  String get desktopPowerFramesHint => 'Molduras de avatar animadas e estados com emoji dos outros. A mais pesada das três — desligue primeiro.';

  @override
  String get desktopPowerGlassBubbles => 'Balões de vidro';

  @override
  String get desktopPowerGlassBubblesHint => 'Desfoque por trás das mensagens recebidas';

  @override
  String get desktopPowerMattePanels => 'Painéis mate';

  @override
  String get desktopPowerMattePanelsHint => 'Desfoque em painéis e janelas emergentes';

  @override
  String get desktopPowerNotAffectedTitle => 'O que isto não afeta';

  @override
  String get desktopPowerNotAffectedHint => 'A entrega de mensagens, a cifra e as notificações funcionam da mesma forma com qualquer valor. Estas opções afetam apenas o desenho.';

  @override
  String get desktopNotifHidden => 'Oculto';

  @override
  String get desktopNotifSenderOnly => 'Apenas o remetente';

  @override
  String get desktopNotifSenderAndText => 'Remetente e texto';

  @override
  String get desktopNotifUnavailableHere => 'Não disponível nesta plataforma.';

  @override
  String get desktopNotifShowPreview => 'Mostrar uma pré-visualização da mensagem';

  @override
  String get desktopNotifInSystem => 'Nas notificações do sistema';

  @override
  String get desktopNotifDirectChats => 'Conversas individuais';

  @override
  String get desktopNotifDirectChatsHint => 'Avisos de mensagens individuais';

  @override
  String get desktopNotifRooms => 'Salas';

  @override
  String get desktopNotifRoomsHint => 'Avisos de mensagens nas salas';

  @override
  String get desktopNotifSound => 'Som';

  @override
  String get desktopNotifDnd => 'Não incomodar';

  @override
  String get desktopNotifDndHint => 'Desligar todas as notificações';

  @override
  String get desktopWallAnimContinuous => 'Sempre';

  @override
  String get desktopWallAnimOnEnter => 'Ao abrir uma conversa';

  @override
  String get desktopWallAnimTap => 'Ao clicar no fundo';

  @override
  String get desktopWallAnimOff => 'Não animar';

  @override
  String get desktopWallpaperNavy => 'Azul-noite';

  @override
  String get desktopWallpaperGraphite => 'Grafite';

  @override
  String get desktopWallpaperTeal => 'Turquesa';

  @override
  String get desktopWallpaperPlum => 'Ameixa';

  @override
  String get desktopWallpaperWine => 'Vinho';

  @override
  String get desktopWallpaperMint => 'Menta';

  @override
  String get desktopWallpaperLavender => 'Lavanda';

  @override
  String get desktopWallpaperSunset => 'Pôr do sol';

  @override
  String get desktopWallpaperPeach => 'Pêssego';

  @override
  String get desktopWallpaperSky => 'Céu';

  @override
  String get desktopWallpaperMidnight => 'Meia-noite';

  @override
  String get desktopAppearanceTitle => 'Aspeto';

  @override
  String get desktopAppearanceHint => 'O esquema desta janela. O telemóvel tem o seu — esta definição não viaja para lado nenhum.';

  @override
  String get desktopAppearanceScheme => 'Esquema';

  @override
  String get desktopAppearanceSchemeHint => 'Escuro, claro ou conforme o sistema';

  @override
  String get desktopAppearanceDark => 'Escuro';

  @override
  String get desktopAppearanceLight => 'Claro';

  @override
  String get desktopAppearanceAuto => 'Auto';

  @override
  String get desktopAppearanceAccent => 'Acento da interface';

  @override
  String get desktopAppearanceAccentHint => 'Botões, os seus balões e as seleções em toda a aplicação.';

  @override
  String get desktopAppearanceWallpaper => 'Fundo da conversa';

  @override
  String get desktopAppearanceWallpaperHint => 'O fundo da conversa para todas as conversas.';

  @override
  String get desktopAppearanceLiveWallpaper => 'Fundo animado';

  @override
  String get desktopAppearanceLiveWallpaperHint => 'Um padrão com um brilho suave. O mesmo conjunto do telemóvel.';

  @override
  String get desktopAppearanceAnimBehaviour => 'Comportamento da animação';

  @override
  String get desktopAppearanceAnimBehaviourHint => 'Quando o padrão ganha vida.';

  @override
  String get desktopAppearanceWallPulse => 'O fundo acompanha a mensagem';

  @override
  String get desktopAppearanceWallPulseHint => 'Uma onda de luz percorre o padrão: para cima ao enviar, para baixo ao receber.';

  @override
  String get desktopAppearanceEnable => 'Ligar';

  @override
  String get desktopAppearanceLiveOnly => 'Só funciona com o fundo animado';

  @override
  String get desktopAppearanceBubbleStyle => 'Estilo dos balões';

  @override
  String get desktopAppearanceBubbleStyleHint => 'A cor das suas mensagens enviadas em todas as conversas.';

  @override
  String get desktopAppearanceSenderColour => 'Cor do nome do remetente';

  @override
  String get desktopAppearanceSenderColourHint => 'A cor da alcunha da outra pessoa nas conversas de grupo.';

  @override
  String get desktopAppearanceIndicatorColour => 'Cor dos indicadores';

  @override
  String get desktopAppearanceIndicatorColourHint => 'As marcas de entrega e o ponto de não lido.';

  @override
  String get desktopAppearanceDemoMode => 'Modo de demonstração';

  @override
  String get desktopAppearanceDemoHint => 'As alterações de aspeto serão guardadas quando um perfil estiver ligado.';

  @override
  String get desktopAppearanceCurrentChoice => 'Escolha atual';

  @override
  String desktopAppearanceThemeIs(Object name) {
    return 'Tema: $name';
  }

  @override
  String get desktopBackupEvery6h => 'A cada 6 horas';

  @override
  String get desktopBackupEvery12h => 'A cada 12 horas';

  @override
  String get desktopBackupDaily => 'Uma vez por dia';

  @override
  String get desktopBackupWeekly => 'Uma vez por semana';

  @override
  String get desktopBackupOffWarning => 'A cópia automática está desligada — não haverá nada para restaurar o histórico';

  @override
  String get desktopBackupNeverRan => 'Ligada, mas ainda nunca foi executada';

  @override
  String desktopBackupLastFailedWith(Object error) {
    return 'A última cópia falhou: $error';
  }

  @override
  String get desktopBackupLastFailed => 'A última cópia falhou';

  @override
  String get desktopBackupStale => 'A cópia há muito que não é atualizada';

  @override
  String get desktopBackupFresh => 'A cópia está atualizada';

  @override
  String get desktopBackupState => 'Estado';

  @override
  String get desktopBackupAutomatic => 'Cópia automática';

  @override
  String get desktopBackupAutomaticHint => 'A cópia está cifrada com a sua palavra-passe. Sem ela, nem nós nem ninguém a consegue restaurar — por isso é preciso lembrá-la.';

  @override
  String get desktopBackupCreateAuto => 'Criar automaticamente';

  @override
  String get desktopBackupUploadServer => 'Carregar para o servidor';

  @override
  String get desktopBackupUploadServerHint => 'Disponível a partir de qualquer dispositivo';

  @override
  String get desktopBackupKeepLocal => 'Guardar neste computador';

  @override
  String get desktopBackupKeepLocalHint => 'Não depende da rede';

  @override
  String get desktopBackupIncludeMedia => 'Incluir a media';

  @override
  String get desktopBackupIncludeMediaHint => 'A cópia ficará bastante maior';

  @override
  String get desktopBackupFrequency => 'Frequência';

  @override
  String get desktopBackupNowhereTitle => 'A cópia não é guardada em lado nenhum';

  @override
  String get desktopBackupNowhereHint => 'A cópia automática está ligada mas ambos os destinos estão desligados — ou seja, não é criada nenhuma cópia. Ligue o servidor ou este computador.';

  @override
  String get desktopBackupRecoveryKey => 'Chave de recuperação';

  @override
  String get desktopBackupCreateRecoveryKey => 'Criar uma chave de recuperação';

  @override
  String get desktopBackupRecoveryKeyHint => 'Vai precisar dela se não restar nenhum dispositivo com o Secretly. Guarde-a separada da palavra-passe.';

  @override
  String desktopBackupKeyFailed(Object error) {
    return 'Não foi possível criar a chave: $error';
  }

  @override
  String get desktopBackupKeyPassword => 'Palavra-passe da chave de recuperação';

  @override
  String get desktopBackupPasswordsDiffer => 'As palavras-passe não coincidem.';

  @override
  String get desktopBackupKeyPasswordHint => 'Esta palavra-passe cifra a própria chave. Não substitui a da aplicação e não é guardada em lado nenhum — não pode ser recuperada.';

  @override
  String get desktopBackupPasswordAgain => 'Outra vez';

  @override
  String desktopUnblockTitle(Object name) {
    return 'Desbloquear $name?';
  }

  @override
  String get desktopUnblockBody => 'Esta pessoa poderá voltar a escrever-lhe e a ligar-lhe.';

  @override
  String get desktopUnblockAction => 'Desbloquear';

  @override
  String get desktopPrivacyLastSeen => 'Visto por último';

  @override
  String get desktopPrivacyProfilePhoto => 'Fotos de perfil';

  @override
  String get desktopPrivacyForwarding => 'Reencaminhamento de mensagens';

  @override
  String get desktopPrivacyCalls => 'Chamadas';

  @override
  String get desktopPrivacyVoice => 'Mensagens de voz';

  @override
  String get desktopPrivacyMessages => 'Mensagens';

  @override
  String get desktopPrivacyNobody => 'Ninguém';

  @override
  String get desktopPrivacyEverybody => 'Todos';

  @override
  String get desktopPrivacyContacts => 'Contactos';

  @override
  String get desktopPrivacyEncryption => 'Cifra';

  @override
  String get desktopPrivacyEncryptionHint => 'Todas as mensagens e chamadas são cifradas de ponta a ponta. As chaves estão apenas nos seus dispositivos.';

  @override
  String get desktopPrivacyE2eeActive => 'A cifra de ponta a ponta está ativa';

  @override
  String get desktopPrivacyWhoSees => 'Quem vê';

  @override
  String get desktopPrivacyWhoSeesHint => 'As mesmas definições de visibilidade da aplicação móvel.';

  @override
  String get desktopPrivacyVisibility => 'Visibilidade';

  @override
  String get desktopPrivacyByNickname => 'Visível pela alcunha';

  @override
  String get desktopPrivacyByNicknameHint => 'Permitir que o encontrem pela alcunha';

  @override
  String get desktopPrivacySuggest => 'Sugerir pessoas na procura';

  @override
  String get desktopPrivacyStrangers => 'Conversas novas de desconhecidos';

  @override
  String get desktopPrivacyStrangersHint => 'Para o arquivo e sem notificações';

  @override
  String get desktopPrivacyAutoDelete => 'Eliminar a minha conta';

  @override
  String get desktopPrivacyAutoDeleteHint => 'Se não iniciar sessão durante mais tempo do que o prazo escolhido, a conta e todas as mensagens são eliminadas automaticamente. A contagem reinicia a cada início de sessão.';

  @override
  String get desktopPrivacyIfAbsent => 'Se não iniciar sessão';

  @override
  String get desktopPrivacyIn1Month => 'Ao fim de 1 mês';

  @override
  String get desktopPrivacyIn3Months => 'Ao fim de 3 meses';

  @override
  String get desktopPrivacyIn6Months => 'Ao fim de 6 meses';

  @override
  String get desktopPrivacyIn1Year => 'Ao fim de um ano';

  @override
  String get desktopPrivacyIn2Years => 'Ao fim de 2 anos';

  @override
  String get desktopLockImmediately => 'Assim que o foco é perdido';

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
  String get desktopLockNoIdentityService => 'O serviço de verificação de identidade está indisponível — o bloqueio não foi ligado.';

  @override
  String get desktopLockNotConfirmed => 'O bloqueio não foi ligado: a confirmação não passou.';

  @override
  String get desktopLockTitle => 'Bloqueio da aplicação';

  @override
  String get desktopLockTouchIdHint => 'Pedir Touch ID para voltar a entrar depois de perder o foco.';

  @override
  String get desktopLockPasswordHint => 'Pedir a palavra-passe do dispositivo para voltar a entrar depois de perder o foco.';

  @override
  String get desktopLockEnableTouchId => 'Ligar o Touch ID';

  @override
  String get desktopLockEnableLock => 'Ligar o bloqueio';

  @override
  String get desktopLockDevicePassword => 'Palavra-passe do dispositivo';

  @override
  String get desktopLockAfter => 'Bloquear ao fim de';

  @override
  String get desktopLockNow => 'Bloquear agora';

  @override
  String get desktopDevicesEndSessionTitle => 'Terminar a sessão?';

  @override
  String desktopDevicesEndSessionBody(Object id) {
    return 'O dispositivo $id será desligado do seu perfil. Para recuperar o acesso é preciso ler o QR outra vez. Continuar?';
  }

  @override
  String get desktopDevicesEnd => 'Terminar';

  @override
  String desktopDevicesEndFailed(Object error) {
    return 'Não foi possível terminar a sessão: $error';
  }

  @override
  String get desktopDevicesEnded => 'A sessão do dispositivo terminou.';

  @override
  String get desktopDevicesActiveSessions => 'Sessões ativas';

  @override
  String get desktopDevicesDemoHint => 'Modo de demonstração · os dispositivos reais aparecem depois de ligar um perfil';

  @override
  String get desktopDevicesThisComputer => 'macOS · Este computador';

  @override
  String get desktopDevicesDemoMac => 'MacBook Pro · Ativo agora';

  @override
  String get desktopDevicesDemoIphone => 'iOS 18.2 · há 2 horas (demo)';

  @override
  String get desktopDevicesDemoIpad => 'iPadOS 18 · ontem (demo)';

  @override
  String get desktopDevicesThisDevice => 'Este dispositivo';

  @override
  String get desktopDevicesRemoteDevice => 'Dispositivo remoto';

  @override
  String get desktopDevicesDisconnect => 'Desligar';

  @override
  String get desktopDevicesTitle => 'Dispositivos';

  @override
  String desktopDevicesTitleCount(Object count) {
    return 'Dispositivos · $count';
  }

  @override
  String get desktopDevicesHint => 'Os dispositivos associados a este perfil no servidor de chaves.';

  @override
  String get desktopDevicesLoadFailed => 'Não foi possível carregar';

  @override
  String get desktopDevicesRetry => 'Tentar de novo';

  @override
  String get desktopDevicesNone => 'Não foram encontrados dispositivos';

  @override
  String get desktopDevicesNotLinked => 'O perfil ainda não está associado ao servidor.';

  @override
  String get desktopDevicesRefresh => 'Atualizar a lista';

  @override
  String get desktopAccentCustom => 'Cor própria';

  @override
  String get desktopAccentCustomChange => 'Cor própria — alterar';

  @override
  String get desktopPairTitle => 'Ligar um dispositivo';

  @override
  String get desktopPairHint => 'Mostre o código QR no dispositivo novo ou leia-o a partir do telemóvel';

  @override
  String get desktopPairRequestFailed => 'Não foi possível criar o pedido de ligação';

  @override
  String get desktopPairCodeCopied => 'O conteúdo do QR foi copiado';

  @override
  String get desktopPairNewTitle => 'Ligar um novo dispositivo';

  @override
  String get desktopPairNewHint => 'No dispositivo novo abra o Secretly e escolha «Ligar por QR». Depois leia o código abaixo.';

  @override
  String get desktopPairClose => 'Fechar';

  @override
  String get desktopPairCopyCode => 'Copiar o código';

  @override
  String get desktopPairRefreshQr => 'Atualizar o QR';

  @override
  String desktopSyncPulled(Object count) {
    return 'Novos eventos obtidos: $count';
  }

  @override
  String get desktopSyncTooOften => 'Pedidos a mais — tente mais tarde';

  @override
  String get desktopSyncNothingNew => 'Concluído · não há eventos novos';

  @override
  String get desktopSyncDemoUnavailable => 'Não disponível no modo de demonstração';

  @override
  String desktopSyncBlobsPulled(Object blobs, Object convos) {
    return 'Anexos obtidos: $blobs (conversas: $convos)';
  }

  @override
  String desktopSyncNoBlobs(Object convos) {
    return 'Concluído · não há anexos novos (conversas: $convos)';
  }

  @override
  String get desktopSyncTitle => 'Histórico de outros dispositivos';

  @override
  String get desktopSyncHint => 'Pedir ao telemóvel o histórico recente das conversas. Usa-se se o computador esteve offline mais de 7 dias ou acabou de ser ligado por QR.';

  @override
  String get desktopSyncRunning => 'A sincronizar…';

  @override
  String get desktopSyncAskHistory => 'Pedir o histórico';

  @override
  String get desktopSyncAsk => 'Pedir';

  @override
  String get desktopSyncBlobsRunning => 'A transferir anexos…';

  @override
  String get desktopSyncBlobsAction => 'Obter os anexos';

  @override
  String get desktopSyncBlobsHint => 'Transfere a media das conversas recentes quando os ficheiros faltam localmente (após nova ligação ou muito tempo offline).';

  @override
  String get desktopSyncBlobsShort => 'Obter';

  @override
  String desktopServerBackupOk(Object stamp, Object size, Object profile) {
    return 'Cópia no servidor ✓ · $stamp · $size KB · perfil $profile';
  }

  @override
  String get desktopServerBackupPassword => 'Palavra-passe da cópia';

  @override
  String get desktopServerBackupPasswordHint => 'Com esta palavra-passe a cópia é cifrada e restaurada em qualquer dispositivo. Memorize-a — sem ela a cópia é inútil e não pode ser recuperada.';

  @override
  String get desktopServerBackupRepeat => 'Repita a palavra-passe';

  @override
  String get desktopServerBackupCreate => 'Criar a cópia';

  @override
  String get desktopServerBackupTitle => 'Cópia de segurança no servidor';

  @override
  String get desktopServerBackupHint => 'Uma cópia cifrada da conta no servidor do Secretly. Restaura-se em qualquer dispositivo através de «Restaurar do servidor» com o seu Secretly ID e a palavra-passe.';

  @override
  String get desktopServerBackupLoading => 'A carregar…';

  @override
  String get desktopServerBackupCreateOnServer => 'Criar uma cópia no servidor';

  @override
  String get desktopServerBackupUpdate => 'Atualizar a cópia';

  @override
  String desktopFailedWith(Object error) {
    return 'Não foi possível: $error';
  }

  @override
  String get desktopStorageDeleteModelTitle => 'Eliminar o modelo de reconhecimento?';

  @override
  String get desktopStorageDeleteModelBody => 'A transcrição de mensagens de voz deixará de funcionar até o modelo ser transferido de novo.';

  @override
  String get desktopStorageModelDeleted => 'O modelo foi eliminado';

  @override
  String desktopStorageDeleteFailed(Object error) {
    return 'Não foi possível eliminar: $error';
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
  String get desktopStorageUsage => 'Utilização';

  @override
  String get desktopStorageUsageHint => 'Cache e media neste dispositivo';

  @override
  String desktopStorageClearHint(Object size) {
    return 'Serão libertados $size. As mensagens, os ficheiros que enviou e os recentes não são eliminados — não haveria de onde os recuperar.';
  }

  @override
  String get desktopStorageClear => 'Limpar a cache';

  @override
  String get desktopStorageCounting => 'A calcular…';

  @override
  String get desktopStorageSpeechModel => 'Modelo de reconhecimento de fala';

  @override
  String get desktopStorageSpeechModelHint => 'Serve para transcrever mensagens de voz neste computador, sem enviar o áudio para lado nenhum. Uma limpeza normal da cache NÃO o remove — é grande e transfere-se à parte.';

  @override
  String get desktopStorageDeleteModel => 'Eliminar o modelo';

  @override
  String desktopStorageMedia(Object size) {
    return 'Media · $size';
  }

  @override
  String desktopStorageVoice(Object size) {
    return 'Voz · $size';
  }

  @override
  String desktopStorageOther(Object size) {
    return 'Outros · $size';
  }

  @override
  String get desktopStorageFree => 'Livre';

  @override
  String desktopStorageTotal(Object size) {
    return 'Total · $size';
  }

  @override
  String desktopAboutVersion(Object version, Object build) {
    return 'Versão $version · compilação $build';
  }

  @override
  String get desktopAboutTagline => 'Um mensageiro seguro com cifra de ponta a ponta. Sem nuvem. Sem publicidade. Código aberto.';

  @override
  String get desktopAboutLicences => 'Licenças';

  @override
  String get desktopAboutWebsite => 'Site';

  @override
  String get desktopDangerTitle => 'Eliminar a conta de forma irreversível?';

  @override
  String get desktopDangerBody => 'O perfil, as chaves, os dados locais e o histórico de mensagens serão eliminados neste e noutros dispositivos. Não há retorno.';

  @override
  String get desktopDangerDeleting => 'A eliminar a conta…';

  @override
  String desktopDangerFailed(Object error) {
    return 'Não foi possível eliminar a conta: $error';
  }

  @override
  String get desktopDangerSection => 'Eliminação da conta';

  @override
  String get desktopDangerDemo => 'Modo de demonstração · a eliminação não está disponível sem um perfil ligado.';

  @override
  String get desktopDangerEnterId => 'Escreva o seu Secretly ID para confirmar';

  @override
  String desktopDangerEnterIdExact(Object id) {
    return 'Escreva $id para confirmar';
  }

  @override
  String get desktopDangerAction => 'Eliminar a conta';

  @override
  String get desktopDangerIrreversible => 'Esta ação é irreversível. Serão eliminados todos os seus dados, o histórico de mensagens e as chaves. Não há retorno.';

  @override
  String get desktopSecurityE2ee => 'Cifra de ponta a ponta';

  @override
  String get desktopSecurityE2eeHint => 'Todas as mensagens, chamadas e ficheiros são cifrados no seu dispositivo. As chaves nunca saem dos seus dispositivos — o servidor vê apenas texto cifrado.';

  @override
  String get desktopSecurityVerifiedDevices => 'Dispositivos verificados';

  @override
  String get desktopSecurityVerifiedHint => 'Enquanto estiver ligado, as mensagens não seguem para os dispositivos não confirmados da outra pessoa. Protege contra substituição, mas uma mensagem pode não chegar até ela confirmar um novo. Só conversas individuais: não se aplica a grupos.';

  @override
  String get desktopSecurityOnlyVerified => 'Apenas dispositivos verificados';

  @override
  String get desktopSecurityBlocked => 'Os dispositivos não verificados são bloqueados';

  @override
  String get desktopSecurityAllDevices => 'As mensagens seguem para todos os dispositivos da outra pessoa';

  @override
  String get desktopSecurityAppEntry => 'Entrada na aplicação';

  @override
  String get desktopSecurityAppEntryHint => 'Uma palavra-passe ao abrir o Secretly e depois de a janela ter estado escondida mais de um minuto. Aplica-se a este computador.';

  @override
  String get desktopSecurityPersonalScopeHint => 'Uma palavra-passe à parte para a categoria «Pessoais». Sem ela, as conversas pessoais ficam abertas a quem tenha acesso a um computador desbloqueado.';

  @override
  String get desktopCallsInApp => 'Chamadas na aplicação';

  @override
  String get desktopCallsInAppHint => 'Desligue para desativar as chamadas por completo';

  @override
  String get desktopCallsAccept => 'Aceitar chamadas recebidas';

  @override
  String get desktopCallsAcceptHint => 'Poderão ligar-lhe';

  @override
  String get desktopCallsDisabledHint => 'Indisponível enquanto as chamadas estiverem desligadas';

  @override
  String get desktopCallsScreenShare => 'Partilha de ecrã';

  @override
  String get desktopCallsScreenShareHint => 'Receber o ecrã de outra pessoa é uma permissão à parte: pode aparecer algo que não esperava ver.';

  @override
  String get desktopCallsAcceptScreenShare => 'Aceitar partilha de ecrã';

  @override
  String get desktopAccountIdCopied => 'O Secretly ID foi copiado';

  @override
  String get desktopAccountIdHint => 'Este identificador é o que partilha para o encontrarem. Não contém número de telefone nem e-mail.';

  @override
  String get desktopAccountCopy => 'Copiar';

  @override
  String get desktopAccountProfile => 'Perfil';

  @override
  String get desktopAccountProfileHint => 'Nome, foto, estado';

  @override
  String get desktopAccountOpenProfile => 'Abrir a página do perfil';

  @override
  String desktopScopePasswordFor(Object name) {
    return 'Palavra-passe para «$name»';
  }

  @override
  String get desktopScopeMin4 => 'Pelo menos 4 caracteres';

  @override
  String get desktopScopeOn => 'A proteção está ligada';

  @override
  String desktopScopeOnFailed(Object error) {
    return 'Não foi possível ligar: $error';
  }

  @override
  String get desktopScopeOff => 'A proteção está desligada';

  @override
  String desktopScopeOffFailed(Object error) {
    return 'Não foi possível desligar: $error';
  }

  @override
  String get desktopScopePasswordsDiffer => 'As palavras-passe não coincidem';

  @override
  String get desktopScopeTitle => 'Proteção por palavra-passe';

  @override
  String get desktopScopeOnWithPassword => 'Ligada — palavra-passe';

  @override
  String get desktopScopeEnabled => 'Ligada';

  @override
  String get desktopScopeDisabled => 'Desligada';

  @override
  String get desktopScopeChangePassword => 'Mudar a palavra-passe';

  @override
  String get desktopScopeLockNow => 'Bloquear';

  @override
  String desktopBlockedUnblocked(Object name) {
    return '$name foi desbloqueado';
  }

  @override
  String desktopBlockedUnblockFailed(Object error) {
    return 'Não foi possível desbloquear: $error';
  }

  @override
  String get desktopBlockedTitle => 'Bloqueados';

  @override
  String get desktopBlockedEmptyHint => 'A lista está vazia. Bloqueia-se a partir do menu de uma conversa.';

  @override
  String get desktopBlockedHint => 'Estas pessoas não lhe podem escrever nem ligar.';

  @override
  String get desktopBlockedNone => 'Ninguém está bloqueado';

  @override
  String get desktopSupportSent => 'A mensagem foi enviada';

  @override
  String get desktopSupportSendFailed => 'Não foi possível enviar. Verifique a sua ligação.';

  @override
  String get desktopSupportUnavailable => 'O apoio está indisponível';

  @override
  String get desktopSupportUnavailableHint => 'O serviço de apoio está desligado neste momento. Tente mais tarde ou escreva do telemóvel.';

  @override
  String get desktopSupportThread => 'A conversa com o apoio';

  @override
  String get desktopSupportThreadHint => 'As mensagens são cifradas no seu dispositivo. O servidor guarda apenas texto cifrado — só o apoio pode ler a conversa.';

  @override
  String get desktopSupportNoReplies => 'Ainda não há respostas. Descreva o problema — a resposta chega aqui.';

  @override
  String get desktopSupportWrite => 'Escrever ao apoio';

  @override
  String get desktopSupportWriteHint => 'A versão da compilação e o identificador do dispositivo são anexados automaticamente — sem eles o problema é quase impossível de reproduzir.';

  @override
  String get desktopSupportDescribe => 'Descreva o que aconteceu';

  @override
  String get desktopSupportSending => 'A enviar…';

  @override
  String get desktopSupportSend => 'Enviar';

  @override
  String get desktopChatsEmptyHint => 'Comece a conversar no telemóvel — as conversas sincronizam sozinhas para o computador';

  @override
  String get desktopChatsPickOne => 'Escolha uma conversa à esquerda';

  @override
  String desktopChatsSendFailed(Object error) {
    return 'Não foi possível enviar: $error';
  }

  @override
  String desktopChatsSendingTo(Object title) {
    return 'A enviar para «$title»';
  }

  @override
  String get desktopChatsFilterAll => 'Todos';

  @override
  String get desktopChatsFilterUnread => 'Não lidos';

  @override
  String get desktopChatsFilterGroups => 'Grupos';

  @override
  String get desktopChatsFilterArchive => 'Arquivo';

  @override
  String get desktopChatsFilterPersonal => 'Pessoais';

  @override
  String get desktopChatsRenameFolder => 'Mudar o nome da pasta';

  @override
  String get desktopChatsDeleteFolder => 'Eliminar a pasta';

  @override
  String desktopChatsRenameFailed(Object error) {
    return 'Não foi possível mudar o nome: $error';
  }

  @override
  String desktopChatsDeleteFolderTitle(Object name) {
    return 'Eliminar a pasta «$name»?';
  }

  @override
  String get desktopChatsDeleteFolderBody => 'As conversas ficam onde estão — só a pasta é eliminada.';

  @override
  String desktopChatsDeleteFailed(Object error) {
    return 'Não foi possível eliminar: $error';
  }

  @override
  String desktopChatsAddedToFolder(Object name) {
    return 'Adicionado a «$name»';
  }

  @override
  String desktopChatsRemovedFromFolder(Object name) {
    return 'Removido de «$name»';
  }

  @override
  String desktopChatsFolderChangeFailed(Object error) {
    return 'Não foi possível mudar a pasta: $error';
  }

  @override
  String desktopChatsFolderCreated(Object name) {
    return 'A pasta «$name» foi criada';
  }

  @override
  String desktopChatsFolderCreateFailed(Object error) {
    return 'Não foi possível criar a pasta: $error';
  }

  @override
  String get desktopChatsNewFolder => 'Pasta nova';

  @override
  String get desktopChatsFolderName => 'Nome da pasta';

  @override
  String desktopChatsRemoveFromFolder(Object name) {
    return 'Remover de «$name»';
  }

  @override
  String desktopChatsAddToFolder(Object name) {
    return 'Para a pasta «$name»';
  }

  @override
  String get desktopChatsNewFolderWithChat => 'Pasta nova com esta conversa…';

  @override
  String get desktopChatsRemoveFromPersonal => 'Remover de pessoais';

  @override
  String get desktopChatsAddToPersonal => 'Para pessoais';

  @override
  String get desktopChatsArchiveEmpty => 'O arquivo está vazio';

  @override
  String get desktopChatsNoPersonal => 'Não há conversas pessoais';

  @override
  String get desktopChatsPersonalLocked => 'As conversas pessoais estão protegidas por palavra-passe';

  @override
  String get desktopChatsAllRead => 'Tudo lido';

  @override
  String get desktopChatsFolderEmpty => 'Esta pasta ainda está vazia';

  @override
  String get desktopChatsNewChat => 'Conversa nova';

  @override
  String get desktopChatsNewRoom => 'Sala nova';

  @override
  String get desktopChatsStartFailed => 'Não foi possível iniciar a conversa: o perfil está indisponível';

  @override
  String get desktopChatsPhoto => 'Foto';

  @override
  String get desktopChatsVideo => 'Vídeo';

  @override
  String get desktopChatsAudio => 'Áudio';

  @override
  String get desktopChatsVoiceMessage => 'Mensagem de voz';

  @override
  String get desktopChatsVoiceShort => 'Voz';

  @override
  String get desktopChatsLink => 'Ligação';

  @override
  String get desktopChatsSticker => 'Autocolante';

  @override
  String desktopChatsStickerWith(Object label) {
    return 'Autocolante $label';
  }

  @override
  String desktopChatsPoll(Object question) {
    return '📊 Sondagem: $question';
  }

  @override
  String get desktopChatsUnknown => 'desconhecido';

  @override
  String get desktopChatsMember => 'Membro';

  @override
  String get desktopChatsSoundOn => 'Ligar o som';

  @override
  String get desktopChatsSoundOff => 'Sem som';

  @override
  String get desktopChatsClearHistoryTitle => 'Limpar o histórico?';

  @override
  String desktopChatsClearHistoryBody(Object title) {
    return 'Todas as mensagens da conversa «$title» serão eliminadas neste dispositivo.';
  }

  @override
  String get desktopChatsClear => 'Limpar';

  @override
  String get desktopChatsHistoryClearedBoth => 'O histórico foi limpo em ambos';

  @override
  String get desktopChatsHistoryCleared => 'O histórico foi limpo';

  @override
  String get desktopChatsDeleteChatTitle => 'Eliminar a conversa?';

  @override
  String desktopChatsDeleteChatBody(Object title) {
    return 'A conversa «$title» será totalmente removida deste dispositivo.';
  }

  @override
  String get desktopChatsRooms => 'Salas';

  @override
  String get desktopChatsGeneralTopic => 'Geral';

  @override
  String get desktopChatsNewTopicEllipsis => 'Tópico novo…';

  @override
  String desktopChatsBranch(Object title) {
    return 'Ramo «$title»';
  }

  @override
  String get desktopChatsRename => 'Mudar o nome';

  @override
  String get desktopChatsIcon => 'Ícone';

  @override
  String get desktopChatsDeleteBranch => 'Eliminar o ramo';

  @override
  String get desktopChatsBranchIcon => 'Ícone do ramo';

  @override
  String get desktopChatsBranchIconHint => 'O ícone substitui o cardinal antes do nome. Os coloridos prometem o que há dentro: verde uma chamada, vermelho algo urgente. Os restantes são cinzentos para não competir com o nome.';

  @override
  String get desktopChatsHash => 'Cardinal';

  @override
  String desktopChatsBranchFailed(Object error) {
    return 'Não foi possível alterar os ramos: $error';
  }

  @override
  String get desktopChatsNewTopic => 'Tópico novo';

  @override
  String get desktopChatsRenameTopic => 'Mudar o nome do tópico';

  @override
  String get desktopChatsTopicName => 'Nome do tópico';

  @override
  String desktopChatsReactionFailed(Object error) {
    return 'Não foi possível guardar a reação: $error';
  }

  @override
  String desktopChatsReactionLocal(Object error) {
    return 'A reação foi aplicada localmente mas não chegou à outra pessoa: $error';
  }

  @override
  String get desktopChatsRevealFailed => 'Não foi possível mostrar o ficheiro no Finder';

  @override
  String desktopChatsVideoOpenFailed(Object error) {
    return 'Não foi possível abrir o vídeo: $error';
  }

  @override
  String get desktopChatsVideoUnavailable => 'O vídeo está indisponível';

  @override
  String desktopChatsFileFetchFailed(Object error) {
    return 'Não foi possível obter o ficheiro: $error';
  }

  @override
  String get desktopChatsSaveAttachment => 'Guardar o anexo';

  @override
  String get desktopChatsFileUnavailable => 'O ficheiro está indisponível';

  @override
  String desktopChatsSaveFailed(Object error) {
    return 'Não foi possível guardar: $error';
  }

  @override
  String desktopChatsOpenFailedWith(Object error) {
    return 'Não foi possível abrir o ficheiro: $error';
  }

  @override
  String get desktopChatsOpenFailed => 'Não foi possível abrir o ficheiro';

  @override
  String desktopChatsOpenFailedShort(Object error) {
    return 'Não foi possível abrir: $error';
  }

  @override
  String desktopChatsPlayFailed(Object error) {
    return 'Não foi possível reproduzir: $error';
  }

  @override
  String get desktopChatsNoCallPeer => 'Não foi possível determinar a quem ligar.';

  @override
  String get desktopChatsCallsNotReady => 'O serviço de chamadas não está pronto.';

  @override
  String get desktopChatsCallInProgress => 'Já está uma chamada a decorrer.';

  @override
  String get desktopChatsEditFailed => 'Não foi possível editar a mensagem.';

  @override
  String get desktopChatsNoRecipient => 'Não foi possível determinar o destinatário.';

  @override
  String get desktopChatsDeleteMessageTitle => 'Eliminar a mensagem?';

  @override
  String get desktopChatsDeleteMessagesTitle => 'Eliminar as mensagens selecionadas?';

  @override
  String get desktopChatsDeleteOthersHint => 'As mensagens de outras pessoas serão eliminadas apenas para si.';

  @override
  String get desktopChatsDeleteForAll => 'Eliminar para todos';

  @override
  String get desktopChatsDeleteForMeOnly => 'Eliminar apenas para mim';

  @override
  String get desktopChatsDeleteForMe => 'Eliminar para mim';

  @override
  String get desktopChatsSavePrivacyBlocked => 'Esta mensagem não pode ser guardada por restrições de privacidade.';

  @override
  String get desktopChatsNothingToSave => 'O anexo não foi transferido — não há nada para guardar';

  @override
  String get desktopChatsSavedPartly => 'Guardado nos Favoritos, mas não tudo';

  @override
  String get desktopChatsSaved => 'Guardado nos Favoritos';

  @override
  String get desktopChatsForwardPrivacyBlocked => 'Esta mensagem não pode ser reencaminhada por restrições de privacidade.';

  @override
  String desktopChatsForwardFailed(Object error) {
    return 'Não foi possível reencaminhar: $error';
  }

  @override
  String get desktopChatsNothingToForward => 'O anexo não foi transferido — não há nada para reencaminhar';

  @override
  String desktopChatsForwardedPartly(Object title) {
    return 'Reencaminhado para «$title», mas não tudo';
  }

  @override
  String desktopChatsForwarded(Object title) {
    return 'Reencaminhado para «$title»';
  }

  @override
  String desktopChatsFileNotSentElsewhere(Object text) {
    return 'O ficheiro não foi enviado para a outra conversa: $text';
  }

  @override
  String get desktopChatsFileSendFailed => 'Não foi possível enviar o ficheiro.';

  @override
  String desktopChatsPremiumFiles(Object text) {
    return '$text Com o Premium pode enviar ficheiros até 1 GB.';
  }

  @override
  String get desktopChatsTypingEllipsis => 'a escrever…';

  @override
  String get desktopChatsOnline => 'em linha';

  @override
  String desktopChatsSomeoneTyping(Object name) {
    return '$name está a escrever';
  }

  @override
  String get desktopChatsLoadingList => 'A obter a lista do armazenamento local.';

  @override
  String get desktopChatsWillAppear => 'As mensagens e chamadas aparecem aqui assim que abrir uma conversa.';

  @override
  String get desktopRoomNoOpenHere => 'Não é possível abrir uma conversa a partir daqui';

  @override
  String get desktopRoomIdCopied => 'O ID foi copiado';

  @override
  String get desktopRoomAwaiting => 'À espera de aprovação';

  @override
  String get desktopRoomBlocked => 'Bloqueado';

  @override
  String get desktopRoomCopied => 'Copiado';

  @override
  String get desktopRoomChangeRole => 'Mudar o papel';

  @override
  String get desktopRoomTransfer => 'Transferir a propriedade';

  @override
  String get desktopRoomBlockMember => 'Bloquear';

  @override
  String get desktopRoomKick => 'Remover';

  @override
  String get desktopRoomKickTitle => 'Remover o membro?';

  @override
  String desktopRoomKickBody(Object name) {
    return '$name perderá o acesso à sala. Um novo convite trá-lo de volta.';
  }

  @override
  String get desktopRoomBlockTitle => 'Bloquear o membro?';

  @override
  String desktopRoomBlockBody(Object name) {
    return '$name não poderá voltar à sala, mesmo com convite, enquanto o bloqueio durar.';
  }

  @override
  String get desktopRoomTransferTitle => 'Transferir a propriedade da sala?';

  @override
  String desktopRoomTransferBody(Object name) {
    return '$name passa a proprietário e você a administrador. Só o novo proprietário pode desfazer.';
  }

  @override
  String get desktopRoomTransferAction => 'Transferir';

  @override
  String get desktopRoomClearTitle => 'Limpar o histórico?';

  @override
  String get desktopRoomClearBody => 'Todas as mensagens da sala serão eliminadas neste dispositivo.';

  @override
  String get desktopRoomLeaveTitle => 'Sair da sala?';

  @override
  String get desktopRoomLeaveBody => 'Deixará de receber mensagens. Para voltar é preciso um novo convite.';

  @override
  String get desktopRoomLeave => 'Sair';

  @override
  String get desktopRoomInvite => 'Convidar';

  @override
  String get desktopRoomCopyId => 'Copiar o ID da sala';

  @override
  String get desktopRoomMuteOff => 'Desligar as notificações';

  @override
  String get desktopRoomUnarchive => 'Tirar do arquivo';

  @override
  String get desktopRoomLeaveRoom => 'Sair da sala';

  @override
  String get desktopRoomUntitled => 'Sem nome';

  @override
  String get desktopRoomCopyInvite => 'Copiar o convite';

  @override
  String get desktopRoomSound => 'Som';

  @override
  String get desktopRoomTabInfo => 'Info';

  @override
  String get desktopRoomTabMembers => 'Membros';

  @override
  String get desktopRoomTabMedia => 'Media';

  @override
  String get desktopRoomTopics => 'TÓPICOS';

  @override
  String desktopRoomTopicsCount(Object count) {
    return 'TÓPICOS · $count';
  }

  @override
  String get desktopRoomDescription => 'Descrição';

  @override
  String get desktopRoomNotes => 'NOTAS';

  @override
  String get desktopRoomInformation => 'Informação';

  @override
  String get desktopRoomId => 'ID da sala';

  @override
  String get desktopRoomInviteLink => 'Ligação de convite · clique para copiar';

  @override
  String get desktopRoomFavouriteHint => 'Um mosaico na barra e um lugar no topo da lista';

  @override
  String get desktopRoomArchiveHint => 'Ocultar a sala da lista principal';

  @override
  String get desktopRoomNoMembers => 'Sem membros';

  @override
  String desktopRoomMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membros',
      one: '$count membro',
    );
    return '$_temp0';
  }

  @override
  String get desktopRoomNobodyFound => 'Ninguém encontrado';

  @override
  String get desktopRoomMembersUnavailable => 'A lista de membros está indisponível.';

  @override
  String get desktopRoomInCall => 'NA CHAMADA';

  @override
  String get desktopRoomOnline => 'EM LINHA';

  @override
  String get desktopRoomOffline => 'SEM LIGAÇÃO';

  @override
  String desktopRoomMoreHidden(Object count) {
    return 'Mais $count — use a procura acima';
  }

  @override
  String get desktopRoomSearchMember => 'Procurar um membro';

  @override
  String get desktopRoomJoinRequests => 'Pedidos de adesão';

  @override
  String get desktopRoomAccept => 'Aceitar';

  @override
  String get desktopRoomDecline => 'Recusar';

  @override
  String get desktopRoomRoleOwner => 'Proprietário';

  @override
  String get desktopRoomRoleAdmin => 'Administrador';

  @override
  String get desktopRoomRoleModerator => 'Moderador';

  @override
  String get desktopRoomRoleRestricted => 'Restrito';

  @override
  String get desktopRoomRoleGuest => 'Convidado';

  @override
  String get desktopContactBlockTitle => 'Bloquear?';

  @override
  String get desktopContactUnblockTitle => 'Desbloquear?';

  @override
  String get desktopContactBlockBody => 'Esta pessoa deixará de poder enviar-lhe mensagens e ligar-lhe.';

  @override
  String get desktopContactUnblockBody => 'Esta pessoa poderá voltar a contactá-lo.';

  @override
  String get desktopContactBlock => 'Bloquear';

  @override
  String get desktopContactCallsNotReady => 'O serviço de chamadas ainda não está pronto';

  @override
  String get desktopContactCallInProgress => 'Já está uma chamada a decorrer';

  @override
  String desktopContactCallFailed(Object error) {
    return 'Não foi possível iniciar a chamada: $error';
  }

  @override
  String get desktopContactAutoDelete => 'Eliminação automática de mensagens';

  @override
  String get desktopContactAutoDeleteUpdated => 'A eliminação automática foi atualizada';

  @override
  String get desktopContactClearBody => 'Todas as mensagens desta conversa serão eliminadas neste dispositivo.';

  @override
  String get desktopContactDeleteBody => 'A conversa será totalmente removida deste dispositivo.';

  @override
  String get desktopContactOff => 'Desligado';

  @override
  String get desktopContactDisable => 'Desligar';

  @override
  String get desktopContactDay1 => '1 dia';

  @override
  String get desktopContactDays7 => '7 dias';

  @override
  String get desktopContactDays30 => '30 dias';

  @override
  String get desktopContactHour1 => '1 hora';

  @override
  String desktopContactMinutes(Object value) {
    return '$value min';
  }

  @override
  String get desktopContactOffline => 'sem ligação';

  @override
  String desktopContactSeenAt(Object time) {
    return 'visto às $time';
  }

  @override
  String get desktopContactSeenYesterday => 'visto ontem';

  @override
  String desktopContactSeenOn(Object date) {
    return 'visto a $date';
  }

  @override
  String get desktopContactCopyId => 'Copiar o ID';

  @override
  String get desktopContactCopyIdShort => 'Copiar ID';

  @override
  String get desktopContactDisappearing => 'Mensagens que desaparecem';

  @override
  String get desktopContactDeleteChat => 'Eliminar a conversa';

  @override
  String get desktopContactCall => 'Chamada';

  @override
  String get desktopContactBlockShort => 'Bloq.';

  @override
  String get desktopContactSecurity => 'Segurança';

  @override
  String get desktopContactVerify => 'Verificar o contacto';

  @override
  String get desktopContactArchiveHint => 'Ocultar a conversa da lista principal';

  @override
  String get desktopThreadMessageHint => 'Mensagem…';

  @override
  String get desktopThreadPasteFailed => 'Não foi possível colar a imagem';

  @override
  String get desktopThreadNoScheduleEdit => 'Uma edição não pode ser agendada — altera algo já enviado';

  @override
  String desktopThreadWillLeave(Object when) {
    return 'Sairá $when';
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
    return 'Selecionados: $count';
  }

  @override
  String get desktopThreadDisappearingOn => 'As mensagens que desaparecem estão ligadas';

  @override
  String get desktopThreadCallAction => 'Ligar';

  @override
  String get desktopThreadCallRoom => 'Chamada em grupo';

  @override
  String get desktopThreadVideoCall => 'Videochamada';

  @override
  String get desktopThreadSearchShortcut => 'Procurar na conversa  Cmd F';

  @override
  String get desktopThreadHideDetails => 'Ocultar os detalhes';

  @override
  String get desktopThreadShowDetails => 'Mostrar os detalhes';

  @override
  String get desktopThreadMore => 'Mais';

  @override
  String get desktopThreadPinned => 'Mensagem afixada';

  @override
  String get desktopThreadNoMatches => 'sem correspondências';

  @override
  String get desktopThreadSearchHint => 'Procurar na conversa…';

  @override
  String get desktopThreadPrevMatch => 'Anterior (Shift F3)';

  @override
  String get desktopThreadNextMatch => 'Seguinte (F3)';

  @override
  String get desktopThreadCloseEsc => 'Fechar (Esc)';

  @override
  String get desktopThreadNewMessages => 'Mensagens novas';

  @override
  String desktopThreadUnreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count por ler',
      one: '$count por ler',
    );
    return '$_temp0';
  }

  @override
  String get desktopThreadToday => 'Hoje';

  @override
  String get desktopThreadYesterday => 'Ontem';

  @override
  String get desktopProfileEmojiStatus => 'Estado com emoji';

  @override
  String get desktopProfileClearStatus => 'Remover o estado';

  @override
  String desktopProfileApplyFailed(Object error) {
    return 'Não foi possível aplicar: $error';
  }

  @override
  String get desktopProfileAvatarFrame => 'Moldura do avatar';

  @override
  String get desktopProfileCover => 'Capa do perfil';

  @override
  String get desktopProfileNoFrame => 'Sem moldura';

  @override
  String get desktopProfileNoCover => 'Sem capa';

  @override
  String get desktopProfileReadFailed => 'Não foi possível ler o ficheiro';

  @override
  String get desktopProfilePhotoUpdated => 'A foto de perfil foi atualizada';

  @override
  String desktopProfilePhotoFailed(Object error) {
    return 'Não foi possível atualizar a foto: $error';
  }

  @override
  String desktopProfilePhotoRemoveFailed(Object error) {
    return 'Não foi possível remover a foto: $error';
  }

  @override
  String get desktopProfileMine => 'O meu perfil';

  @override
  String get desktopProfileEdit => 'Editar';

  @override
  String get desktopProfileName => 'Nome';

  @override
  String get desktopProfileChangePhoto => 'Mudar a foto';

  @override
  String get desktopProfileFrameShort => 'Moldura';

  @override
  String get desktopProfileCoverShort => 'Capa';

  @override
  String get desktopProfileStatus => 'Estado';

  @override
  String get desktopProfileAppearanceHint => 'Tema, acento e fundo da conversa';

  @override
  String get desktopProfileAbout => 'Sobre mim';

  @override
  String get desktopProfileEmpty => 'Por preencher';

  @override
  String get desktopProfilePhoto => 'Foto de perfil';

  @override
  String get desktopProfileReplacePhoto => 'Substituir a foto';

  @override
  String get desktopProfilePickPhoto => 'Escolher uma foto';

  @override
  String get desktopProfilePickedHere => 'Escolhida neste computador';

  @override
  String get desktopProfileSyncedWithPhone => 'Sincronizada com o telemóvel';

  @override
  String get desktopProfileNotPicked => 'Por escolher';

  @override
  String get desktopProfileRemovePhoto => 'Remover a foto';

  @override
  String get desktopProfileInitialsStay => 'Ficam as iniciais';

  @override
  String get desktopProfileAccount => 'Conta';

  @override
  String get desktopProfileRecovery => 'Recuperação';

  @override
  String get desktopProfileRecoveryHint => 'Este computador está ligado ao telemóvel e não guarda a sua própria frase de recuperação: a cópia e a chave de recuperação devolvem a conta.';

  @override
  String get desktopProfileDevicesHint => 'Computadores e telemóveis ligados';

  @override
  String get desktopProfileFrameCaps => 'MOLDURA DO AVATAR';

  @override
  String get desktopGalleryMedia => 'Media';

  @override
  String get desktopGalleryFiles => 'Ficheiros';

  @override
  String get desktopGalleryLinks => 'Ligações';

  @override
  String get desktopGalleryNoMedia => 'Sem media';

  @override
  String get desktopGalleryNoFiles => 'Sem ficheiros';

  @override
  String get desktopGalleryNoAudio => 'Sem áudio';

  @override
  String get desktopGalleryNoLinks => 'Sem ligações';

  @override
  String get desktopGalleryPathCopied => 'O caminho foi copiado';

  @override
  String get desktopGalleryOpen => 'Abrir';

  @override
  String get desktopGalleryView => 'Ver';

  @override
  String get desktopGalleryOpenInSystem => 'Abrir no sistema';

  @override
  String get desktopGalleryRevealFinder => 'Mostrar no Finder';

  @override
  String get desktopGalleryRevealExplorer => 'Mostrar no Explorador';

  @override
  String get desktopGalleryOpenFolder => 'Abrir a pasta';

  @override
  String get desktopGalleryCopyPath => 'Copiar o caminho';

  @override
  String desktopGalleryBytes(Object value) {
    return '$value B';
  }

  @override
  String get desktopGalleryZeroBytes => '0 B';

  @override
  String desktopOutgoingFolderSingle(Object name) {
    return 'a pasta «$name» não pode ser enviada';
  }

  @override
  String get desktopOutgoingFoldersMany => 'as pastas não podem ser enviadas';

  @override
  String desktopOutgoingTooLargeOne(Object name, Object limit) {
    return '«$name» é maior do que $limit MB';
  }

  @override
  String desktopOutgoingTooLargeMany(int count, Object limit) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ficheiros são maiores do que $limit MB',
      one: '$count ficheiro é maior do que $limit MB',
    );
    return '$_temp0';
  }

  @override
  String desktopOutgoingEmptyOne(Object name) {
    return '«$name» está vazio';
  }

  @override
  String desktopOutgoingEmptyMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ficheiros estão vazios',
      one: '$count ficheiro está vazio',
    );
    return '$_temp0';
  }

  @override
  String desktopOutgoingUnreadableOne(Object name) {
    return 'não foi possível ler «$name»';
  }

  @override
  String desktopOutgoingUnreadableMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ficheiros não puderam ser lidos',
      one: '$count ficheiro não pôde ser lido',
    );
    return '$_temp0';
  }

  @override
  String get desktopOutgoingSending => 'Envio';

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
    return '$count media';
  }

  @override
  String desktopOutgoingAudios(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count áudios',
      one: '$count áudios',
    );
    return '$_temp0';
  }

  @override
  String desktopOutgoingFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ficheiros',
      one: '$count ficheiros',
    );
    return '$_temp0';
  }

  @override
  String get desktopCallsPickOne => 'Escolha uma chamada à esquerda';

  @override
  String get desktopCallsPickHint => 'Aqui aparecem os detalhes e um botão para ligar de volta';

  @override
  String get desktopCallsNone => 'Ainda não há chamadas';

  @override
  String get desktopCallsNoneHint => 'O histórico aparece depois da primeira chamada';

  @override
  String get desktopCallsOutgoing => 'Efetuada';

  @override
  String get desktopCallsIncoming => 'Recebida';

  @override
  String get desktopCallsGroup => 'em grupo';

  @override
  String get desktopCallsVideoKind => 'vídeo';

  @override
  String get desktopCallsAudioKind => 'áudio';

  @override
  String get desktopCallsMissed => 'perdida';

  @override
  String desktopPhotoCopyFailed(Object error) {
    return 'Não foi possível copiar: $error';
  }

  @override
  String get desktopPhotoSave => 'Guardar a foto';

  @override
  String get desktopPhotoSaved => 'Guardado';

  @override
  String desktopPhotoRevealFailed(Object error) {
    return 'Não foi possível mostrar no Finder: $error';
  }

  @override
  String get desktopPhotoLoadFailed => 'Não foi possível carregar';

  @override
  String get desktopPhotoZoomOut => 'Reduzir';

  @override
  String get desktopPhotoZoomReset => 'Repor o zoom';

  @override
  String get desktopPhotoZoomIn => 'Ampliar';

  @override
  String get desktopPhotoCopy => 'Copiar';

  @override
  String desktopBubbleForwardedFrom(Object from) {
    return 'Reencaminhado de $from';
  }

  @override
  String get desktopBubbleAudioFile => 'Ficheiro de áudio';

  @override
  String get desktopBubbleTranslating => 'A traduzir…';

  @override
  String get desktopBubbleTranslation => 'TRADUÇÃO';

  @override
  String get desktopBubbleEdited => 'editado';

  @override
  String get desktopBubbleMoreReactions => 'Mais reações';

  @override
  String get desktopBubbleRoleOwner => 'proprietário';

  @override
  String get desktopBubbleRoleAdmin => 'admin';

  @override
  String get desktopBubbleRoleMod => 'mod';

  @override
  String get desktopBubbleSpeed => 'Velocidade de reprodução';

  @override
  String get desktopSpotlightGoChats => 'Ir para as conversas';

  @override
  String get desktopSpotlightGoRooms => 'Ir para as salas';

  @override
  String get desktopSpotlightGoContacts => 'Ir para os contactos';

  @override
  String get desktopSpotlightGoCalls => 'Ir para as chamadas';

  @override
  String get desktopSpotlightSelect => 'selecionar';

  @override
  String get desktopSpotlightOpen => 'abrir';

  @override
  String get desktopSpotlightClose => 'fechar';

  @override
  String get desktopSpotlightRoom => 'Sala';

  @override
  String get desktopSpotlightMessage => 'Mensagem';

  @override
  String get desktopSpotlightCommand => 'Comando';

  @override
  String get desktopComposerCancelRec => 'Cancelar a gravação';

  @override
  String desktopComposerRecording(Object time) {
    return 'A gravar  $time';
  }

  @override
  String get desktopComposerSendVoice => 'Enviar a mensagem de voz';

  @override
  String get desktopComposerAttach => 'Anexar';

  @override
  String get desktopComposerEmoji => 'Emoji e autocolantes';

  @override
  String get desktopComposerRecordVoice => 'Gravar uma mensagem de voz';

  @override
  String get desktopComposerEnterSends => 'Enter envia · Shift+Enter quebra a linha';

  @override
  String get desktopComposerEnterNewline => 'Enter quebra a linha · Shift+Enter envia';

  @override
  String get desktopComposerEditing => 'Edição';

  @override
  String desktopComposerReplyTo(Object name) {
    return 'Resposta · $name';
  }

  @override
  String get desktopComposerCancelAction => 'Cancelar';

  @override
  String get desktopComposerSendHint => 'Enviar · Enter\nBotão direito para enviar mais tarde';

  @override
  String get desktopComposerWriteFirst => 'Escreva primeiro uma mensagem';

  @override
  String desktopComposerToTopic(Object title) {
    return 'para o tópico «$title»';
  }

  @override
  String get desktopShortcutsNavigation => 'Navegação';

  @override
  String get desktopShortcutsTabs => 'Conversas · Salas · Chamadas · Contactos';

  @override
  String get desktopShortcutsSearchAll => 'Procurar em conversas e mensagens';

  @override
  String get desktopShortcutsPrevNext => 'Conversa anterior / seguinte';

  @override
  String get desktopShortcutsInChat => 'Numa conversa';

  @override
  String get desktopShortcutsFindHere => 'Procurar nesta conversa';

  @override
  String get desktopShortcutsSend => 'Enviar (configurável)';

  @override
  String get desktopShortcutsNewline => 'Quebra de linha';

  @override
  String get desktopShortcutsPaste => 'Colar uma imagem da área de transferência';

  @override
  String get desktopShortcutsApp => 'Aplicação';

  @override
  String get desktopShortcutsThisHelp => 'Esta ajuda';

  @override
  String get desktopShortcutsCloseWindow => 'Fechar a janela ou a procura';

  @override
  String get desktopShortcutsTray => 'Minimizar para a bandeja';

  @override
  String get desktopShortcutsTitle => 'Atalhos de teclado';

  @override
  String get desktopMediaCancelSend => 'Cancelar o envio';

  @override
  String get desktopMediaSending => 'A enviar…';

  @override
  String desktopMediaSendingOf(Object total) {
    return 'A enviar… · $total';
  }

  @override
  String get desktopMediaRetryDownload => 'Repetir a transferência';

  @override
  String get desktopMediaImage => 'Imagem';

  @override
  String desktopMediaDownloading(Object size) {
    return 'A transferir… · $size';
  }

  @override
  String get desktopMediaDownload => 'Transferir';

  @override
  String get desktopSendAsMedia => 'Enviar como media';

  @override
  String get desktopSendAsFiles => 'Enviar como ficheiros';

  @override
  String get desktopSendUngroup => 'Não agrupar';

  @override
  String get desktopSendGroup => 'Agrupar';

  @override
  String get desktopSendAddFiles => 'Adicionar ficheiros…';

  @override
  String get desktopSendDropHere => 'Largue para adicionar';

  @override
  String get desktopSendCloseEsc => 'Fechar · Esc';

  @override
  String desktopSendToDestination(Object destination) {
    return 'para «$destination»';
  }

  @override
  String get desktopSendCaptionHint => 'Adicionar uma legenda…';

  @override
  String get desktopSendEmoji => 'Emoji';

  @override
  String get desktopSendRemove => 'Remover';

  @override
  String get desktopSendEnter => 'Enviar · Enter';

  @override
  String get desktopSendShiftEnter => 'Enviar · Shift+Enter';

  @override
  String get desktopCallCtlMicOff => 'Desligar o microfone   ⌘D';

  @override
  String get desktopCallCtlMicOn => 'Ligar o microfone   ⌘D';

  @override
  String get desktopCallCtlCamOff => 'Desligar a câmara   ⌘E';

  @override
  String get desktopCallCtlCamOn => 'Ligar a câmara   ⌘E';

  @override
  String get desktopCallCtlShareStop => 'Parar a partilha';

  @override
  String get desktopCallCtlShare => 'Partilha de ecrã';

  @override
  String get desktopCallCtlHandDown => 'Baixar a mão';

  @override
  String get desktopCallCtlHandUp => 'Levantar a mão';

  @override
  String get desktopCallCtlHangUp => 'Desligar   ⌘W';

  @override
  String desktopAbsenceDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dias',
      one: '$count dia',
    );
    return '$_temp0';
  }

  @override
  String desktopAbsencePastFanout(Object days) {
    return 'Este computador esteve sem ligação $days. Nesse tempo os remetentes deixaram de cifrar mensagens para ele, e parte do histórico não chegará aqui. No telemóvel está intacto — abra lá as conversas necessárias e o histórico recente é sincronizado.';
  }

  @override
  String desktopAbsenceWithinWindow(Object days) {
    return 'Este computador esteve sem ligação $days. As mensagens ficam uma semana no servidor, por isso parte delas pode não se ter conservado para ele. No telemóvel estão intactas.';
  }

  @override
  String get desktopAbsenceGotIt => 'Entendido';

  @override
  String get desktopNavContacts => 'Contactos';

  @override
  String get desktopChatNotFound => 'A conversa não foi encontrada';

  @override
  String desktopUnreadTitle(Object count) {
    return 'Secretly — $count por ler';
  }

  @override
  String get desktopRoomsNone => 'Ainda não há salas';

  @override
  String get desktopRoomsNoneHint => 'Crie uma sala no telemóvel — aparece aqui automaticamente';

  @override
  String get desktopRoomsPickOne => 'Escolha uma sala à esquerda';

  @override
  String get desktopScheduleTitle => 'Enviar mais tarde';

  @override
  String get desktopScheduleInHour => 'Daqui a uma hora';

  @override
  String get desktopScheduleTonight => 'Hoje às 19:00';

  @override
  String get desktopScheduleTomorrow => 'Amanhã às 9:00';

  @override
  String get desktopScheduleInWeek => 'Daqui a uma semana';

  @override
  String desktopScheduleTodayAt(Object time) {
    return 'hoje às $time';
  }

  @override
  String desktopScheduleTomorrowAt(Object time) {
    return 'amanhã às $time';
  }

  @override
  String desktopScheduleOnAt(Object date, Object time) {
    return '$date às $time';
  }

  @override
  String get desktopScheduleHint => 'A mensagem sai sozinha à hora escolhida — mesmo com a janela fechada, será enviada no próximo arranque.';

  @override
  String get desktopSchedulePickTime => 'Escolher a hora…';

  @override
  String get desktopDevicesSearching => 'A procurar dispositivos…';

  @override
  String get desktopDevicesNoCameras => 'Não foram encontradas câmaras. Talvez a aplicação não tenha acesso nas definições do sistema.';

  @override
  String get desktopDevicesNoMics => 'Não foram encontrados microfones. Talvez a aplicação não tenha acesso nas definições do sistema.';

  @override
  String get desktopDevicesOutputHint => 'Para onde sai o som escolhe-se dentro da chamada — pelo sinal junto a «Microfone». É aí que a aplicação muda sozinha para os auscultadores quando os ligam.';

  @override
  String get desktopDevicesSystemDefault => 'Como no sistema';

  @override
  String get desktopRailSettings => 'Definições   Cmd ,';

  @override
  String get desktopRailConnected => 'Ligado';

  @override
  String get desktopRailConnecting => 'A ligar…';

  @override
  String get desktopRailOffline => 'Sem ligação';

  @override
  String desktopRailProfile(Object status) {
    return 'Perfil   Cmd P   ·   $status';
  }

  @override
  String get desktopEmojiSmileys => 'Sorrisos e emoções';

  @override
  String get desktopEmojiPeople => 'Pessoas e corpo';

  @override
  String get desktopEmojiNature => 'Natureza';

  @override
  String get desktopEmojiFood => 'Comida e bebida';

  @override
  String get desktopEmojiTravel => 'Viagens';

  @override
  String get desktopEmojiActivities => 'Atividades';

  @override
  String get desktopEmojiObjects => 'Objetos';

  @override
  String get desktopEmojiSymbols => 'Símbolos';

  @override
  String get desktopEmojiFlags => 'Bandeiras';

  @override
  String get desktopEmojiOther => 'Outros';

  @override
  String get desktopLockedTitle => 'O Secretly está bloqueado';

  @override
  String get desktopLockedTouchIdPrompt => 'Confirme a sua identidade com o Touch ID para continuar.';

  @override
  String get desktopLockedPasswordPrompt => 'Confirme com a palavra-passe do dispositivo para continuar.';

  @override
  String get desktopLockedUnlock => 'Desbloquear';

  @override
  String get desktopLockedWaiting => 'A aguardar confirmação…';

  @override
  String get desktopLockedFailed => 'Não foi possível confirmar a sua identidade.';

  @override
  String get desktopLockedNoService => 'O serviço de identidade não está disponível neste computador. Reinicie o Secretly ou o computador. Se não resolver, escreva ao suporte a partir do telemóvel.';

  @override
  String get desktopEmojiTabEmoji => 'Emojis';

  @override
  String get desktopEmojiTabStickers => 'Autocolantes';

  @override
  String get desktopEmojiRecents => 'Recentes';

  @override
  String get desktopEmojiNothingFound => 'Nada encontrado';

  @override
  String get desktopEmojiSearchHint => 'Procurar emojis';

  @override
  String get desktopStickersSearchHint => 'Procurar autocolantes';

  @override
  String get desktopGifSearchHint => 'Procurar GIFs';

  @override
  String get desktopGifUnavailable => 'Os GIFs não estão disponíveis nesta janela';

  @override
  String get desktopStickerPacksSoon => 'Packs de autocolantes em breve';

  @override
  String get desktopCallFullscreen => 'Ecrã inteiro';

  @override
  String get desktopCallExitFullscreen => 'Sair do ecrã inteiro';

  @override
  String get desktopCallDialing => 'A chamar…';

  @override
  String get desktopCallEnded => 'Terminada';

  @override
  String desktopCallEncryptedFor(Object duration) {
    return 'Encriptada · $duration';
  }

  @override
  String get desktopCallReturn => 'Voltar';

  @override
  String get desktopCallInProgress => 'Chamada a decorrer';

  @override
  String desktopCallInProgressWith(Object title) {
    return 'Chamada a decorrer · $title';
  }

  @override
  String get desktopCallAnswer => 'Atender';

  @override
  String get desktopCallAnswerVideo => 'Atender com vídeo';

  @override
  String get desktopCallAnswerText => 'Por texto';

  @override
  String get desktopTimeYesterday => 'ontem';

  @override
  String get desktopForwardTitle => 'Reencaminhar para…';

  @override
  String get desktopForwardSearchHint => 'Procurar conversa ou sala';

  @override
  String get desktopForwardNoChats => 'Sem conversas disponíveis';

  @override
  String get desktopForwardKindDirect => 'Conversa direta';

  @override
  String get desktopContactsSearchHint => 'Procurar contactos';

  @override
  String get desktopContactsEmpty => 'Os contactos vão aparecer após a sincronização.';

  @override
  String desktopContactsNothingFor(Object query) {
    return 'Nada encontrado para «$query».';
  }

  @override
  String get desktopContactsPick => 'Escolha um contacto';

  @override
  String get desktopContactsCardRight => 'O cartão vai aparecer à direita.';

  @override
  String get desktopContactsWrite => 'Escrever mensagem';

  @override
  String get desktopVideoTitle => 'Vídeo';

  @override
  String get desktopViewerCloseEsc => 'Fechar  Esc';

  @override
  String get desktopVideoPlayFailed => 'Não foi possível reproduzir o vídeo';

  @override
  String get desktopKeySpace => 'Espaço';

  @override
  String get desktopWindowMinimize => 'Minimizar';

  @override
  String get desktopWindowMaximize => 'Maximizar';

  @override
  String get desktopWindowClose => 'Fechar';

  @override
  String get desktopWindowBack => 'Anterior';

  @override
  String get desktopWindowForward => 'Seguinte';

  @override
  String get desktopSearchEverything => 'Conversas, pessoas, mensagens, ficheiros';

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
  String get desktopSyncSyncing => 'A sincronizar…';

  @override
  String get desktopSyncReconnecting => 'A reconectar…';

  @override
  String get desktopDetailsShare => 'Partilhar';

  @override
  String get desktopDetailsHide => 'Ocultar';

  @override
  String get desktopDetailsMore => 'Mais';

  @override
  String get desktopDetailsChangeCover => 'Mudar a capa';

  @override
  String desktopDetailsFrame(Object name) {
    return 'Moldura «$name»';
  }

  @override
  String get desktopApply => 'Aplicar';

  @override
  String get desktopAccentAppliesTo => 'Botões, seleções e anéis. O balão mantém o seu estilo — escolhe-se abaixo.';

  @override
  String get desktopTranslateUnknownSource => 'Não foi possível detetar o idioma da mensagem';

  @override
  String get desktopTranslateUnsupported => 'O tradutor do sistema não conhece este par de idiomas';

  @override
  String get desktopTranslateNeedsDownload => 'O idioma não foi transferido. Definições do Sistema → Geral → Idioma e região → Idiomas de tradução';

  @override
  String get desktopTranslateFailed => 'Não foi possível traduzir';

  @override
  String get desktopNewChatSearchHint => 'Procurar nos contactos';

  @override
  String get desktopNewChatNoContacts => 'Ainda sem contactos';

  @override
  String get desktopNewChatNobodyFound => 'Ninguém encontrado';

  @override
  String get desktopMentionEveryone => 'Todos os participantes';

  @override
  String get desktopMentionAdmins => 'Administradores';

  @override
  String get desktopMentionEveryoneHint => 'Chamar todos na sala';

  @override
  String get desktopMentionAdminsHint => 'Chamar o dono e os administradores';

  @override
  String desktopClearForPeer(Object name) {
    return 'Limpar também o histórico de $name';
  }

  @override
  String get desktopClearForPeerHint => 'As mensagens vão desaparecer no dispositivo dele e em todos os seus. Isto não pode ser anulado.';

  @override
  String get desktopGifNoKey => 'GIFs indisponíveis: compilação sem chave GIPHY';

  @override
  String get desktopGifConnectionLost => 'A ligação caiu. Tente novamente';

  @override
  String get desktopNotesHint => 'O que reter desta conversa…';

  @override
  String get desktopNotesPrivate => 'Visível apenas para si. Não é enviado, não aparece na conversa e não entra na cópia de segurança — fica neste computador, na mesma base encriptada das mensagens.';

  @override
  String get desktopEmojiSearchShort => 'Procurar emojis…';

  @override
  String get desktopNotifOpen => 'Abrir';

  @override
  String get desktopLinkPreviewLoading => 'Pré-visualização do link…';

  @override
  String get desktopLinkPreviewOff => 'Sem pré-visualização';

  @override
  String get desktopDropToSend => 'Largue para enviar';

  @override
  String get desktopDropEncrypted => 'Os ficheiros são encriptados antes do envio';

  @override
  String get desktopDetailsPickChat => 'Escolha uma conversa';

  @override
  String get desktopDetailsEmptyHint => 'Os dados da pessoa ou da sala\nvão aparecer aqui.';

  @override
  String get desktopMemberWrite => 'Escrever';

  @override
  String get desktopShowPanel => 'Mostrar o painel';

  @override
  String get desktopHidePanel => 'Ocultar o painel';

  @override
  String get desktopNotifOff => 'As notificações estão desligadas';

  @override
  String get desktopSettingsSearchHint => 'Encontrar uma definição';

  @override
  String get desktopUnlockPrompt => 'Desbloquear o Secretly';

  @override
  String get desktopEnableLockPrompt => 'Confirme para ativar o bloqueio do Secretly';

  @override
  String get desktopRoomsNoneHintDot => 'Crie uma sala no telemóvel — vai aparecer aqui sozinha.';

  @override
  String get desktopSplashLoading => 'A carregar o perfil…';

  @override
  String get desktopOutgoingOnePhoto => 'Foto';

  @override
  String get desktopOutgoingOneVideo => 'Vídeo';

  @override
  String get desktopOutgoingOneAudio => 'Áudio';

  @override
  String get desktopOutgoingOneFile => 'Ficheiro';

  @override
  String get desktopMenuSettings => 'Definições…';

  @override
  String get desktopMenuEdit => 'Editar';

  @override
  String get desktopMenuUndo => 'Anular';

  @override
  String get desktopMenuRedo => 'Refazer';

  @override
  String get desktopMenuCut => 'Cortar';

  @override
  String get desktopMenuPaste => 'Colar';

  @override
  String get desktopMenuSelectAll => 'Selecionar tudo';

  @override
  String get desktopMenuView => 'Visualização';

  @override
  String get desktopMenuWindow => 'Janela';

  @override
  String get desktopMenuHelp => 'Ajuda';

  @override
  String get desktopMenuWebsite => 'Site do Secretly';
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

  @override
  String get desktopGeneralSystemLanguage => 'Do sistema';

  @override
  String get desktopGeneralInterfaceLanguage => 'Idioma da interface';

  @override
  String get desktopGeneralAppliesAtOnce => 'Aplica-se imediatamente';

  @override
  String get desktopGeneralBehaviour => 'Comportamento';

  @override
  String get desktopGeneralEnterSends => 'Enter envia a mensagem';

  @override
  String get desktopGeneralShiftEnterNewline => 'Shift+Enter inicia uma nova linha';

  @override
  String get desktopGeneralEnterNewline => 'Enter inicia uma nova linha, Shift+Enter envia';

  @override
  String get desktopGeneralHoverMenu => 'Menu ao passar sobre uma mensagem';

  @override
  String get desktopGeneralHoverMenuOn => 'Acima da mensagem aparecem reações e ações';

  @override
  String get desktopGeneralHoverMenuOff => 'As ações estão no botão direito';

  @override
  String get desktopGeneralLinkPreviews => 'Prévia de links';

  @override
  String get desktopGeneralLinkPreviewsOn => 'O cartão do link segue com a mensagem';

  @override
  String get desktopGeneralLinkPreviewsOff => 'Os links seguem sem cartão e nenhuma página é aberta';

  @override
  String get desktopPowerAnimations => 'Animações';

  @override
  String get desktopPowerAnimationsHint => 'Tudo está ligado por padrão. Desligue de cima para baixo se o notebook esquentar ou a bateria cair.';

  @override
  String get desktopPowerFramesTitle => 'Animação de molduras e status';

  @override
  String get desktopPowerFramesHint => 'Molduras de avatar animadas e status com emoji dos outros. A mais pesada das três — desligue primeiro.';

  @override
  String get desktopPowerGlassBubbles => 'Balões de vidro';

  @override
  String get desktopPowerGlassBubblesHint => 'Desfoque atrás das mensagens recebidas';

  @override
  String get desktopPowerMattePanels => 'Painéis foscos';

  @override
  String get desktopPowerMattePanelsHint => 'Desfoque em painéis e janelas pop-up';

  @override
  String get desktopPowerNotAffectedTitle => 'O que isto não afeta';

  @override
  String get desktopPowerNotAffectedHint => 'A entrega de mensagens, a criptografia e as notificações funcionam igual com qualquer valor. Estas opções afetam apenas o desenho.';

  @override
  String get desktopNotifHidden => 'Oculto';

  @override
  String get desktopNotifSenderOnly => 'Apenas o remetente';

  @override
  String get desktopNotifSenderAndText => 'Remetente e texto';

  @override
  String get desktopNotifUnavailableHere => 'Não disponível nesta plataforma.';

  @override
  String get desktopNotifShowPreview => 'Mostrar uma prévia da mensagem';

  @override
  String get desktopNotifInSystem => 'Nas notificações do sistema';

  @override
  String get desktopNotifDirectChats => 'Conversas individuais';

  @override
  String get desktopNotifDirectChatsHint => 'Avisos de mensagens individuais';

  @override
  String get desktopNotifRooms => 'Salas';

  @override
  String get desktopNotifRoomsHint => 'Avisos de mensagens nas salas';

  @override
  String get desktopNotifSound => 'Som';

  @override
  String get desktopNotifDnd => 'Não perturbe';

  @override
  String get desktopNotifDndHint => 'Desligar todas as notificações';

  @override
  String get desktopWallAnimContinuous => 'Sempre';

  @override
  String get desktopWallAnimOnEnter => 'Ao abrir uma conversa';

  @override
  String get desktopWallAnimTap => 'Ao clicar no fundo';

  @override
  String get desktopWallAnimOff => 'Não animar';

  @override
  String get desktopWallpaperNavy => 'Azul-noite';

  @override
  String get desktopWallpaperGraphite => 'Grafite';

  @override
  String get desktopWallpaperTeal => 'Turquesa';

  @override
  String get desktopWallpaperPlum => 'Ameixa';

  @override
  String get desktopWallpaperWine => 'Vinho';

  @override
  String get desktopWallpaperMint => 'Menta';

  @override
  String get desktopWallpaperLavender => 'Lavanda';

  @override
  String get desktopWallpaperSunset => 'Pôr do sol';

  @override
  String get desktopWallpaperPeach => 'Pêssego';

  @override
  String get desktopWallpaperSky => 'Céu';

  @override
  String get desktopWallpaperMidnight => 'Meia-noite';

  @override
  String get desktopAppearanceTitle => 'Aparência';

  @override
  String get desktopAppearanceHint => 'O esquema desta janela. O celular tem o seu — esta configuração não viaja para lugar nenhum.';

  @override
  String get desktopAppearanceScheme => 'Esquema';

  @override
  String get desktopAppearanceSchemeHint => 'Escuro, claro ou conforme o sistema';

  @override
  String get desktopAppearanceDark => 'Escuro';

  @override
  String get desktopAppearanceLight => 'Claro';

  @override
  String get desktopAppearanceAuto => 'Auto';

  @override
  String get desktopAppearanceAccent => 'Acento da interface';

  @override
  String get desktopAppearanceAccentHint => 'Botões, seus balões e as seleções em todo o aplicativo.';

  @override
  String get desktopAppearanceWallpaper => 'Papel de parede da conversa';

  @override
  String get desktopAppearanceWallpaperHint => 'O fundo da conversa para todas as conversas.';

  @override
  String get desktopAppearanceLiveWallpaper => 'Papel de parede animado';

  @override
  String get desktopAppearanceLiveWallpaperHint => 'Um padrão com brilho suave. O mesmo conjunto do celular.';

  @override
  String get desktopAppearanceAnimBehaviour => 'Comportamento da animação';

  @override
  String get desktopAppearanceAnimBehaviourHint => 'Quando o padrão ganha vida.';

  @override
  String get desktopAppearanceWallPulse => 'O fundo acompanha a mensagem';

  @override
  String get desktopAppearanceWallPulseHint => 'Uma onda de luz percorre o padrão: para cima ao enviar, para baixo ao receber.';

  @override
  String get desktopAppearanceEnable => 'Ligar';

  @override
  String get desktopAppearanceLiveOnly => 'Só funciona com o papel de parede animado';

  @override
  String get desktopAppearanceBubbleStyle => 'Estilo dos balões';

  @override
  String get desktopAppearanceBubbleStyleHint => 'A cor das suas mensagens enviadas em todas as conversas.';

  @override
  String get desktopAppearanceSenderColour => 'Cor do nome do remetente';

  @override
  String get desktopAppearanceSenderColourHint => 'A cor do apelido da outra pessoa nas conversas em grupo.';

  @override
  String get desktopAppearanceIndicatorColour => 'Cor dos indicadores';

  @override
  String get desktopAppearanceIndicatorColourHint => 'As marcas de entrega e o ponto de não lido.';

  @override
  String get desktopAppearanceDemoMode => 'Modo de demonstração';

  @override
  String get desktopAppearanceDemoHint => 'As mudanças de aparência serão salvas quando um perfil estiver conectado.';

  @override
  String get desktopAppearanceCurrentChoice => 'Escolha atual';

  @override
  String desktopAppearanceThemeIs(Object name) {
    return 'Tema: $name';
  }

  @override
  String get desktopBackupEvery6h => 'A cada 6 horas';

  @override
  String get desktopBackupEvery12h => 'A cada 12 horas';

  @override
  String get desktopBackupDaily => 'Uma vez por dia';

  @override
  String get desktopBackupWeekly => 'Uma vez por semana';

  @override
  String get desktopBackupOffWarning => 'O backup automático está desligado — não haverá nada para restaurar o histórico';

  @override
  String get desktopBackupNeverRan => 'Ligado, mas ainda nunca foi executado';

  @override
  String desktopBackupLastFailedWith(Object error) {
    return 'O último backup falhou: $error';
  }

  @override
  String get desktopBackupLastFailed => 'O último backup falhou';

  @override
  String get desktopBackupStale => 'O backup não é atualizado há um tempo';

  @override
  String get desktopBackupFresh => 'O backup está atualizado';

  @override
  String get desktopBackupState => 'Estado';

  @override
  String get desktopBackupAutomatic => 'Backup automático';

  @override
  String get desktopBackupAutomaticHint => 'O backup é criptografado com a sua senha. Sem ela, nem nós nem ninguém consegue restaurá-lo — por isso é preciso lembrá-la.';

  @override
  String get desktopBackupCreateAuto => 'Criar automaticamente';

  @override
  String get desktopBackupUploadServer => 'Enviar para o servidor';

  @override
  String get desktopBackupUploadServerHint => 'Disponível de qualquer dispositivo';

  @override
  String get desktopBackupKeepLocal => 'Salvar neste computador';

  @override
  String get desktopBackupKeepLocalHint => 'Não depende da rede';

  @override
  String get desktopBackupIncludeMedia => 'Incluir a mídia';

  @override
  String get desktopBackupIncludeMediaHint => 'O backup ficará bem maior';

  @override
  String get desktopBackupFrequency => 'Frequência';

  @override
  String get desktopBackupNowhereTitle => 'O backup não é salvo em lugar nenhum';

  @override
  String get desktopBackupNowhereHint => 'O backup automático está ligado mas ambos os destinos estão desligados — ou seja, nenhum backup é criado. Ligue o servidor ou este computador.';

  @override
  String get desktopBackupRecoveryKey => 'Chave de recuperação';

  @override
  String get desktopBackupCreateRecoveryKey => 'Criar uma chave de recuperação';

  @override
  String get desktopBackupRecoveryKeyHint => 'Você vai precisar dela se não restar nenhum dispositivo com o Secretly. Guarde-a separada da senha.';

  @override
  String desktopBackupKeyFailed(Object error) {
    return 'Não foi possível criar a chave: $error';
  }

  @override
  String get desktopBackupKeyPassword => 'Senha da chave de recuperação';

  @override
  String get desktopBackupPasswordsDiffer => 'As senhas não coincidem.';

  @override
  String get desktopBackupKeyPasswordHint => 'Esta senha criptografa a própria chave. Não substitui a do aplicativo e não é guardada em lugar nenhum — não pode ser recuperada.';

  @override
  String get desktopBackupPasswordAgain => 'De novo';

  @override
  String desktopUnblockTitle(Object name) {
    return 'Desbloquear $name?';
  }

  @override
  String get desktopUnblockBody => 'Esta pessoa poderá voltar a escrever e ligar para você.';

  @override
  String get desktopUnblockAction => 'Desbloquear';

  @override
  String get desktopPrivacyLastSeen => 'Visto por último';

  @override
  String get desktopPrivacyProfilePhoto => 'Fotos de perfil';

  @override
  String get desktopPrivacyForwarding => 'Encaminhamento de mensagens';

  @override
  String get desktopPrivacyCalls => 'Chamadas';

  @override
  String get desktopPrivacyVoice => 'Mensagens de voz';

  @override
  String get desktopPrivacyMessages => 'Mensagens';

  @override
  String get desktopPrivacyNobody => 'Ninguém';

  @override
  String get desktopPrivacyEverybody => 'Todos';

  @override
  String get desktopPrivacyContacts => 'Contatos';

  @override
  String get desktopPrivacyEncryption => 'Criptografia';

  @override
  String get desktopPrivacyEncryptionHint => 'Todas as mensagens e chamadas são criptografadas de ponta a ponta. As chaves ficam apenas nos seus dispositivos.';

  @override
  String get desktopPrivacyE2eeActive => 'A criptografia de ponta a ponta está ativa';

  @override
  String get desktopPrivacyWhoSees => 'Quem vê';

  @override
  String get desktopPrivacyWhoSeesHint => 'As mesmas configurações de visibilidade do aplicativo móvel.';

  @override
  String get desktopPrivacyVisibility => 'Visibilidade';

  @override
  String get desktopPrivacyByNickname => 'Visível pelo apelido';

  @override
  String get desktopPrivacyByNicknameHint => 'Permitir que encontrem você pelo apelido';

  @override
  String get desktopPrivacySuggest => 'Sugerir pessoas na busca';

  @override
  String get desktopPrivacyStrangers => 'Conversas novas de desconhecidos';

  @override
  String get desktopPrivacyStrangersHint => 'Para o arquivo e sem notificações';

  @override
  String get desktopPrivacyAutoDelete => 'Excluir minha conta';

  @override
  String get desktopPrivacyAutoDeleteHint => 'Se você não entrar por mais tempo que o prazo escolhido, a conta e todas as mensagens são excluídas automaticamente. A contagem reinicia a cada entrada.';

  @override
  String get desktopPrivacyIfAbsent => 'Se eu não entrar';

  @override
  String get desktopPrivacyIn1Month => 'Após 1 mês';

  @override
  String get desktopPrivacyIn3Months => 'Após 3 meses';

  @override
  String get desktopPrivacyIn6Months => 'Após 6 meses';

  @override
  String get desktopPrivacyIn1Year => 'Após um ano';

  @override
  String get desktopPrivacyIn2Years => 'Após 2 anos';

  @override
  String get desktopLockImmediately => 'Assim que o foco é perdido';

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
  String get desktopLockNoIdentityService => 'O serviço de verificação de identidade está indisponível — o bloqueio não foi ligado.';

  @override
  String get desktopLockNotConfirmed => 'O bloqueio não foi ligado: a confirmação não passou.';

  @override
  String get desktopLockTitle => 'Bloqueio do aplicativo';

  @override
  String get desktopLockTouchIdHint => 'Pedir Touch ID para voltar a entrar depois de perder o foco.';

  @override
  String get desktopLockPasswordHint => 'Pedir a senha do dispositivo para voltar a entrar depois de perder o foco.';

  @override
  String get desktopLockEnableTouchId => 'Ligar o Touch ID';

  @override
  String get desktopLockEnableLock => 'Ligar o bloqueio';

  @override
  String get desktopLockDevicePassword => 'Senha do dispositivo';

  @override
  String get desktopLockAfter => 'Bloquear após';

  @override
  String get desktopLockNow => 'Bloquear agora';

  @override
  String get desktopDevicesEndSessionTitle => 'Encerrar a sessão?';

  @override
  String desktopDevicesEndSessionBody(Object id) {
    return 'O dispositivo $id será desconectado do seu perfil. Para recuperar o acesso será preciso escanear o QR de novo. Continuar?';
  }

  @override
  String get desktopDevicesEnd => 'Encerrar';

  @override
  String desktopDevicesEndFailed(Object error) {
    return 'Não foi possível encerrar a sessão: $error';
  }

  @override
  String get desktopDevicesEnded => 'A sessão do dispositivo foi encerrada.';

  @override
  String get desktopDevicesActiveSessions => 'Sessões ativas';

  @override
  String get desktopDevicesDemoHint => 'Modo de demonstração · os dispositivos reais aparecem depois de conectar um perfil';

  @override
  String get desktopDevicesThisComputer => 'macOS · Este computador';

  @override
  String get desktopDevicesDemoMac => 'MacBook Pro · Ativo agora';

  @override
  String get desktopDevicesDemoIphone => 'iOS 18.2 · há 2 horas (demo)';

  @override
  String get desktopDevicesDemoIpad => 'iPadOS 18 · ontem (demo)';

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
  String get desktopDevicesHint => 'Os dispositivos vinculados a este perfil no servidor de chaves.';

  @override
  String get desktopDevicesLoadFailed => 'Não foi possível carregar';

  @override
  String get desktopDevicesRetry => 'Tentar de novo';

  @override
  String get desktopDevicesNone => 'Nenhum dispositivo encontrado';

  @override
  String get desktopDevicesNotLinked => 'O perfil ainda não está vinculado ao servidor.';

  @override
  String get desktopDevicesRefresh => 'Atualizar a lista';

  @override
  String get desktopAccentCustom => 'Cor própria';

  @override
  String get desktopAccentCustomChange => 'Cor própria — alterar';

  @override
  String get desktopPairTitle => 'Conectar um dispositivo';

  @override
  String get desktopPairHint => 'Mostre o QR code no dispositivo novo ou escaneie-o pelo celular';

  @override
  String get desktopPairRequestFailed => 'Não foi possível criar a solicitação de conexão';

  @override
  String get desktopPairCodeCopied => 'O conteúdo do QR foi copiado';

  @override
  String get desktopPairNewTitle => 'Conectar um novo dispositivo';

  @override
  String get desktopPairNewHint => 'No dispositivo novo abra o Secretly e escolha “Conectar por QR”. Depois escaneie o código abaixo.';

  @override
  String get desktopPairClose => 'Fechar';

  @override
  String get desktopPairCopyCode => 'Copiar o código';

  @override
  String get desktopPairRefreshQr => 'Atualizar o QR';

  @override
  String desktopSyncPulled(Object count) {
    return 'Novos eventos obtidos: $count';
  }

  @override
  String get desktopSyncTooOften => 'Solicitações demais — tente mais tarde';

  @override
  String get desktopSyncNothingNew => 'Concluído · não há eventos novos';

  @override
  String get desktopSyncDemoUnavailable => 'Não disponível no modo de demonstração';

  @override
  String desktopSyncBlobsPulled(Object blobs, Object convos) {
    return 'Anexos obtidos: $blobs (conversas: $convos)';
  }

  @override
  String desktopSyncNoBlobs(Object convos) {
    return 'Concluído · não há anexos novos (conversas: $convos)';
  }

  @override
  String get desktopSyncTitle => 'Histórico de outros dispositivos';

  @override
  String get desktopSyncHint => 'Pedir ao celular o histórico recente das conversas. Usado se o computador ficou offline mais de 7 dias ou acabou de ser conectado por QR.';

  @override
  String get desktopSyncRunning => 'Sincronizando…';

  @override
  String get desktopSyncAskHistory => 'Pedir o histórico';

  @override
  String get desktopSyncAsk => 'Pedir';

  @override
  String get desktopSyncBlobsRunning => 'Baixando anexos…';

  @override
  String get desktopSyncBlobsAction => 'Obter os anexos';

  @override
  String get desktopSyncBlobsHint => 'Baixa a mídia das conversas recentes quando os arquivos faltam localmente (após reconectar ou muito tempo offline).';

  @override
  String get desktopSyncBlobsShort => 'Obter';

  @override
  String desktopServerBackupOk(Object stamp, Object size, Object profile) {
    return 'Backup no servidor ✓ · $stamp · $size KB · perfil $profile';
  }

  @override
  String get desktopServerBackupPassword => 'Senha do backup';

  @override
  String get desktopServerBackupPasswordHint => 'Com esta senha o backup é criptografado e restaurado em qualquer dispositivo. Memorize-a — sem ela o backup é inútil e não pode ser recuperada.';

  @override
  String get desktopServerBackupRepeat => 'Repita a senha';

  @override
  String get desktopServerBackupCreate => 'Criar o backup';

  @override
  String get desktopServerBackupTitle => 'Backup no servidor';

  @override
  String get desktopServerBackupHint => 'Uma cópia criptografada da conta no servidor do Secretly. É restaurada em qualquer dispositivo por “Restaurar do servidor” com o seu Secretly ID e a senha.';

  @override
  String get desktopServerBackupLoading => 'Enviando…';

  @override
  String get desktopServerBackupCreateOnServer => 'Criar um backup no servidor';

  @override
  String get desktopServerBackupUpdate => 'Atualizar o backup';

  @override
  String desktopFailedWith(Object error) {
    return 'Não foi possível: $error';
  }

  @override
  String get desktopStorageDeleteModelTitle => 'Excluir o modelo de reconhecimento?';

  @override
  String get desktopStorageDeleteModelBody => 'A transcrição de mensagens de voz vai parar de funcionar até o modelo ser baixado de novo.';

  @override
  String get desktopStorageModelDeleted => 'O modelo foi excluído';

  @override
  String desktopStorageDeleteFailed(Object error) {
    return 'Não foi possível excluir: $error';
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
  String get desktopStorageUsageHint => 'Cache e mídia neste dispositivo';

  @override
  String desktopStorageClearHint(Object size) {
    return 'Serão liberados $size. As mensagens, os arquivos que você enviou e os recentes não são excluídos — não haveria de onde recuperá-los.';
  }

  @override
  String get desktopStorageClear => 'Limpar o cache';

  @override
  String get desktopStorageCounting => 'Calculando…';

  @override
  String get desktopStorageSpeechModel => 'Modelo de reconhecimento de fala';

  @override
  String get desktopStorageSpeechModelHint => 'Serve para transcrever mensagens de voz neste computador, sem enviar o áudio para lugar nenhum. Uma limpeza normal do cache NÃO o remove — é grande e é baixado à parte.';

  @override
  String get desktopStorageDeleteModel => 'Excluir o modelo';

  @override
  String desktopStorageMedia(Object size) {
    return 'Mídia · $size';
  }

  @override
  String desktopStorageVoice(Object size) {
    return 'Voz · $size';
  }

  @override
  String desktopStorageOther(Object size) {
    return 'Outros · $size';
  }

  @override
  String get desktopStorageFree => 'Livre';

  @override
  String desktopStorageTotal(Object size) {
    return 'Total · $size';
  }

  @override
  String desktopAboutVersion(Object version, Object build) {
    return 'Versão $version · compilação $build';
  }

  @override
  String get desktopAboutTagline => 'Um mensageiro seguro com criptografia de ponta a ponta. Sem nuvem. Sem publicidade. Código aberto.';

  @override
  String get desktopAboutLicences => 'Licenças';

  @override
  String get desktopAboutWebsite => 'Site';

  @override
  String get desktopDangerTitle => 'Excluir a conta de forma irreversível?';

  @override
  String get desktopDangerBody => 'O perfil, as chaves, os dados locais e o histórico de mensagens serão excluídos neste e em outros dispositivos. Não há volta.';

  @override
  String get desktopDangerDeleting => 'Excluindo a conta…';

  @override
  String desktopDangerFailed(Object error) {
    return 'Não foi possível excluir a conta: $error';
  }

  @override
  String get desktopDangerSection => 'Exclusão da conta';

  @override
  String get desktopDangerDemo => 'Modo de demonstração · a exclusão não está disponível sem um perfil conectado.';

  @override
  String get desktopDangerEnterId => 'Digite o seu Secretly ID para confirmar';

  @override
  String desktopDangerEnterIdExact(Object id) {
    return 'Digite $id para confirmar';
  }

  @override
  String get desktopDangerAction => 'Excluir a conta';

  @override
  String get desktopDangerIrreversible => 'Esta ação é irreversível. Serão excluídos todos os seus dados, o histórico de mensagens e as chaves. Não há volta.';

  @override
  String get desktopSecurityE2ee => 'Criptografia de ponta a ponta';

  @override
  String get desktopSecurityE2eeHint => 'Todas as mensagens, chamadas e arquivos são criptografados no seu dispositivo. As chaves nunca saem dos seus dispositivos — o servidor vê apenas texto cifrado.';

  @override
  String get desktopSecurityVerifiedDevices => 'Dispositivos verificados';

  @override
  String get desktopSecurityVerifiedHint => 'Enquanto estiver ligado, as mensagens não vão para os dispositivos não confirmados da outra pessoa. Protege contra substituição, mas uma mensagem pode não chegar até ela confirmar um novo. Só conversas individuais: não vale para grupos.';

  @override
  String get desktopSecurityOnlyVerified => 'Apenas dispositivos verificados';

  @override
  String get desktopSecurityBlocked => 'Os dispositivos não verificados são bloqueados';

  @override
  String get desktopSecurityAllDevices => 'As mensagens vão para todos os dispositivos da outra pessoa';

  @override
  String get desktopSecurityAppEntry => 'Entrada no aplicativo';

  @override
  String get desktopSecurityAppEntryHint => 'Uma senha ao abrir o Secretly e depois de a janela ficar escondida por mais de um minuto. Vale para este computador.';

  @override
  String get desktopSecurityPersonalScopeHint => 'Uma senha à parte para a categoria “Pessoais”. Sem ela, as conversas pessoais ficam abertas a quem tiver acesso a um computador desbloqueado.';

  @override
  String get desktopCallsInApp => 'Chamadas no aplicativo';

  @override
  String get desktopCallsInAppHint => 'Desligue para desativar as chamadas por completo';

  @override
  String get desktopCallsAccept => 'Aceitar chamadas recebidas';

  @override
  String get desktopCallsAcceptHint => 'Poderão ligar para você';

  @override
  String get desktopCallsDisabledHint => 'Indisponível enquanto as chamadas estiverem desligadas';

  @override
  String get desktopCallsScreenShare => 'Compartilhamento de tela';

  @override
  String get desktopCallsScreenShareHint => 'Receber a tela de outra pessoa é uma permissão à parte: pode aparecer algo que você não esperava ver.';

  @override
  String get desktopCallsAcceptScreenShare => 'Aceitar compartilhamento de tela';

  @override
  String get desktopAccountIdCopied => 'O Secretly ID foi copiado';

  @override
  String get desktopAccountIdHint => 'Este identificador é o que você compartilha para te encontrarem. Não contém número de telefone nem e-mail.';

  @override
  String get desktopAccountCopy => 'Copiar';

  @override
  String get desktopAccountProfile => 'Perfil';

  @override
  String get desktopAccountProfileHint => 'Nome, foto, status';

  @override
  String get desktopAccountOpenProfile => 'Abrir a página do perfil';

  @override
  String desktopScopePasswordFor(Object name) {
    return 'Senha para “$name”';
  }

  @override
  String get desktopScopeMin4 => 'Pelo menos 4 caracteres';

  @override
  String get desktopScopeOn => 'A proteção está ligada';

  @override
  String desktopScopeOnFailed(Object error) {
    return 'Não foi possível ligar: $error';
  }

  @override
  String get desktopScopeOff => 'A proteção está desligada';

  @override
  String desktopScopeOffFailed(Object error) {
    return 'Não foi possível desligar: $error';
  }

  @override
  String get desktopScopePasswordsDiffer => 'As senhas não coincidem';

  @override
  String get desktopScopeTitle => 'Proteção por senha';

  @override
  String get desktopScopeOnWithPassword => 'Ligada — senha';

  @override
  String get desktopScopeEnabled => 'Ligada';

  @override
  String get desktopScopeDisabled => 'Desligada';

  @override
  String get desktopScopeChangePassword => 'Trocar a senha';

  @override
  String get desktopScopeLockNow => 'Bloquear';

  @override
  String desktopBlockedUnblocked(Object name) {
    return '$name foi desbloqueado';
  }

  @override
  String desktopBlockedUnblockFailed(Object error) {
    return 'Não foi possível desbloquear: $error';
  }

  @override
  String get desktopBlockedTitle => 'Bloqueados';

  @override
  String get desktopBlockedEmptyHint => 'A lista está vazia. O bloqueio é feito pelo menu de uma conversa.';

  @override
  String get desktopBlockedHint => 'Estas pessoas não podem escrever nem ligar para você.';

  @override
  String get desktopBlockedNone => 'Ninguém está bloqueado';

  @override
  String get desktopSupportSent => 'A mensagem foi enviada';

  @override
  String get desktopSupportSendFailed => 'Não foi possível enviar. Verifique sua conexão.';

  @override
  String get desktopSupportUnavailable => 'O suporte está indisponível';

  @override
  String get desktopSupportUnavailableHint => 'O serviço de suporte está desligado agora. Tente mais tarde ou escreva pelo celular.';

  @override
  String get desktopSupportThread => 'A conversa com o suporte';

  @override
  String get desktopSupportThreadHint => 'As mensagens são criptografadas no seu dispositivo. O servidor guarda apenas texto cifrado — só o suporte pode ler a conversa.';

  @override
  String get desktopSupportNoReplies => 'Ainda não há respostas. Descreva o problema — a resposta chega aqui.';

  @override
  String get desktopSupportWrite => 'Escrever ao suporte';

  @override
  String get desktopSupportWriteHint => 'A versão da compilação e o identificador do dispositivo são anexados automaticamente — sem eles o problema é quase impossível de reproduzir.';

  @override
  String get desktopSupportDescribe => 'Descreva o que aconteceu';

  @override
  String get desktopSupportSending => 'Enviando…';

  @override
  String get desktopSupportSend => 'Enviar';

  @override
  String get desktopChatsEmptyHint => 'Comece a conversar no celular — as conversas sincronizam sozinhas para o computador';

  @override
  String get desktopChatsPickOne => 'Escolha uma conversa à esquerda';

  @override
  String desktopChatsSendFailed(Object error) {
    return 'Não foi possível enviar: $error';
  }

  @override
  String desktopChatsSendingTo(Object title) {
    return 'Enviando para “$title”';
  }

  @override
  String get desktopChatsFilterAll => 'Todos';

  @override
  String get desktopChatsFilterUnread => 'Não lidos';

  @override
  String get desktopChatsFilterGroups => 'Grupos';

  @override
  String get desktopChatsFilterArchive => 'Arquivo';

  @override
  String get desktopChatsFilterPersonal => 'Pessoais';

  @override
  String get desktopChatsRenameFolder => 'Renomear a pasta';

  @override
  String get desktopChatsDeleteFolder => 'Excluir a pasta';

  @override
  String desktopChatsRenameFailed(Object error) {
    return 'Não foi possível renomear: $error';
  }

  @override
  String desktopChatsDeleteFolderTitle(Object name) {
    return 'Excluir a pasta “$name”?';
  }

  @override
  String get desktopChatsDeleteFolderBody => 'As conversas ficam onde estão — só a pasta é excluída.';

  @override
  String desktopChatsDeleteFailed(Object error) {
    return 'Não foi possível excluir: $error';
  }

  @override
  String desktopChatsAddedToFolder(Object name) {
    return 'Adicionado a “$name”';
  }

  @override
  String desktopChatsRemovedFromFolder(Object name) {
    return 'Removido de “$name”';
  }

  @override
  String desktopChatsFolderChangeFailed(Object error) {
    return 'Não foi possível mudar a pasta: $error';
  }

  @override
  String desktopChatsFolderCreated(Object name) {
    return 'A pasta “$name” foi criada';
  }

  @override
  String desktopChatsFolderCreateFailed(Object error) {
    return 'Não foi possível criar a pasta: $error';
  }

  @override
  String get desktopChatsNewFolder => 'Pasta nova';

  @override
  String get desktopChatsFolderName => 'Nome da pasta';

  @override
  String desktopChatsRemoveFromFolder(Object name) {
    return 'Remover de “$name”';
  }

  @override
  String desktopChatsAddToFolder(Object name) {
    return 'Para a pasta “$name”';
  }

  @override
  String get desktopChatsNewFolderWithChat => 'Pasta nova com esta conversa…';

  @override
  String get desktopChatsRemoveFromPersonal => 'Remover de pessoais';

  @override
  String get desktopChatsAddToPersonal => 'Para pessoais';

  @override
  String get desktopChatsArchiveEmpty => 'O arquivo está vazio';

  @override
  String get desktopChatsNoPersonal => 'Não há conversas pessoais';

  @override
  String get desktopChatsPersonalLocked => 'As conversas pessoais estão protegidas por senha';

  @override
  String get desktopChatsAllRead => 'Tudo lido';

  @override
  String get desktopChatsFolderEmpty => 'Esta pasta ainda está vazia';

  @override
  String get desktopChatsNewChat => 'Conversa nova';

  @override
  String get desktopChatsNewRoom => 'Sala nova';

  @override
  String get desktopChatsStartFailed => 'Não foi possível iniciar a conversa: o perfil está indisponível';

  @override
  String get desktopChatsPhoto => 'Foto';

  @override
  String get desktopChatsVideo => 'Vídeo';

  @override
  String get desktopChatsAudio => 'Áudio';

  @override
  String get desktopChatsVoiceMessage => 'Mensagem de voz';

  @override
  String get desktopChatsVoiceShort => 'Voz';

  @override
  String get desktopChatsLink => 'Link';

  @override
  String get desktopChatsSticker => 'Figurinha';

  @override
  String desktopChatsStickerWith(Object label) {
    return 'Figurinha $label';
  }

  @override
  String desktopChatsPoll(Object question) {
    return '📊 Enquete: $question';
  }

  @override
  String get desktopChatsUnknown => 'desconhecido';

  @override
  String get desktopChatsMember => 'Membro';

  @override
  String get desktopChatsSoundOn => 'Ligar o som';

  @override
  String get desktopChatsSoundOff => 'Sem som';

  @override
  String get desktopChatsClearHistoryTitle => 'Limpar o histórico?';

  @override
  String desktopChatsClearHistoryBody(Object title) {
    return 'Todas as mensagens da conversa “$title” serão excluídas neste dispositivo.';
  }

  @override
  String get desktopChatsClear => 'Limpar';

  @override
  String get desktopChatsHistoryClearedBoth => 'O histórico foi limpo em ambos';

  @override
  String get desktopChatsHistoryCleared => 'O histórico foi limpo';

  @override
  String get desktopChatsDeleteChatTitle => 'Excluir a conversa?';

  @override
  String desktopChatsDeleteChatBody(Object title) {
    return 'A conversa “$title” será totalmente removida deste dispositivo.';
  }

  @override
  String get desktopChatsRooms => 'Salas';

  @override
  String get desktopChatsGeneralTopic => 'Geral';

  @override
  String get desktopChatsNewTopicEllipsis => 'Tópico novo…';

  @override
  String desktopChatsBranch(Object title) {
    return 'Ramo “$title”';
  }

  @override
  String get desktopChatsRename => 'Renomear';

  @override
  String get desktopChatsIcon => 'Ícone';

  @override
  String get desktopChatsDeleteBranch => 'Excluir o ramo';

  @override
  String get desktopChatsBranchIcon => 'Ícone do ramo';

  @override
  String get desktopChatsBranchIconHint => 'O ícone substitui a cerquilha antes do nome. Os coloridos prometem o que há dentro: verde uma chamada, vermelho algo urgente. Os demais são cinzas para não competir com o nome.';

  @override
  String get desktopChatsHash => 'Cerquilha';

  @override
  String desktopChatsBranchFailed(Object error) {
    return 'Não foi possível alterar os ramos: $error';
  }

  @override
  String get desktopChatsNewTopic => 'Tópico novo';

  @override
  String get desktopChatsRenameTopic => 'Renomear o tópico';

  @override
  String get desktopChatsTopicName => 'Nome do tópico';

  @override
  String desktopChatsReactionFailed(Object error) {
    return 'Não foi possível salvar a reação: $error';
  }

  @override
  String desktopChatsReactionLocal(Object error) {
    return 'A reação foi aplicada localmente mas não chegou à outra pessoa: $error';
  }

  @override
  String get desktopChatsRevealFailed => 'Não foi possível mostrar o arquivo no Finder';

  @override
  String desktopChatsVideoOpenFailed(Object error) {
    return 'Não foi possível abrir o vídeo: $error';
  }

  @override
  String get desktopChatsVideoUnavailable => 'O vídeo está indisponível';

  @override
  String desktopChatsFileFetchFailed(Object error) {
    return 'Não foi possível obter o arquivo: $error';
  }

  @override
  String get desktopChatsSaveAttachment => 'Salvar o anexo';

  @override
  String get desktopChatsFileUnavailable => 'O arquivo está indisponível';

  @override
  String desktopChatsSaveFailed(Object error) {
    return 'Não foi possível salvar: $error';
  }

  @override
  String desktopChatsOpenFailedWith(Object error) {
    return 'Não foi possível abrir o arquivo: $error';
  }

  @override
  String get desktopChatsOpenFailed => 'Não foi possível abrir o arquivo';

  @override
  String desktopChatsOpenFailedShort(Object error) {
    return 'Não foi possível abrir: $error';
  }

  @override
  String desktopChatsPlayFailed(Object error) {
    return 'Não foi possível reproduzir: $error';
  }

  @override
  String get desktopChatsNoCallPeer => 'Não foi possível determinar para quem ligar.';

  @override
  String get desktopChatsCallsNotReady => 'O serviço de chamadas não está pronto.';

  @override
  String get desktopChatsCallInProgress => 'Já há uma chamada em andamento.';

  @override
  String get desktopChatsEditFailed => 'Não foi possível editar a mensagem.';

  @override
  String get desktopChatsNoRecipient => 'Não foi possível determinar o destinatário.';

  @override
  String get desktopChatsDeleteMessageTitle => 'Excluir a mensagem?';

  @override
  String get desktopChatsDeleteMessagesTitle => 'Excluir as mensagens selecionadas?';

  @override
  String get desktopChatsDeleteOthersHint => 'As mensagens de outras pessoas serão excluídas apenas para você.';

  @override
  String get desktopChatsDeleteForAll => 'Excluir para todos';

  @override
  String get desktopChatsDeleteForMeOnly => 'Excluir apenas para mim';

  @override
  String get desktopChatsDeleteForMe => 'Excluir para mim';

  @override
  String get desktopChatsSavePrivacyBlocked => 'Esta mensagem não pode ser salva por restrições de privacidade.';

  @override
  String get desktopChatsNothingToSave => 'O anexo não foi baixado — não há nada para salvar';

  @override
  String get desktopChatsSavedPartly => 'Salvo nos Favoritos, mas não tudo';

  @override
  String get desktopChatsSaved => 'Salvo nos Favoritos';

  @override
  String get desktopChatsForwardPrivacyBlocked => 'Esta mensagem não pode ser encaminhada por restrições de privacidade.';

  @override
  String desktopChatsForwardFailed(Object error) {
    return 'Não foi possível encaminhar: $error';
  }

  @override
  String get desktopChatsNothingToForward => 'O anexo não foi baixado — não há nada para encaminhar';

  @override
  String desktopChatsForwardedPartly(Object title) {
    return 'Encaminhado para “$title”, mas não tudo';
  }

  @override
  String desktopChatsForwarded(Object title) {
    return 'Encaminhado para “$title”';
  }

  @override
  String desktopChatsFileNotSentElsewhere(Object text) {
    return 'O arquivo não foi enviado para a outra conversa: $text';
  }

  @override
  String get desktopChatsFileSendFailed => 'Não foi possível enviar o arquivo.';

  @override
  String desktopChatsPremiumFiles(Object text) {
    return '$text Com o Premium você pode enviar arquivos de até 1 GB.';
  }

  @override
  String get desktopChatsTypingEllipsis => 'digitando…';

  @override
  String get desktopChatsOnline => 'on-line';

  @override
  String desktopChatsSomeoneTyping(Object name) {
    return '$name está digitando';
  }

  @override
  String get desktopChatsLoadingList => 'Obtendo a lista do armazenamento local.';

  @override
  String get desktopChatsWillAppear => 'As mensagens e chamadas aparecem aqui assim que você abrir uma conversa.';

  @override
  String get desktopRoomNoOpenHere => 'Não é possível abrir uma conversa daqui';

  @override
  String get desktopRoomIdCopied => 'O ID foi copiado';

  @override
  String get desktopRoomAwaiting => 'Aguardando aprovação';

  @override
  String get desktopRoomBlocked => 'Bloqueado';

  @override
  String get desktopRoomCopied => 'Copiado';

  @override
  String get desktopRoomChangeRole => 'Mudar o papel';

  @override
  String get desktopRoomTransfer => 'Transferir a propriedade';

  @override
  String get desktopRoomBlockMember => 'Bloquear';

  @override
  String get desktopRoomKick => 'Remover';

  @override
  String get desktopRoomKickTitle => 'Remover o membro?';

  @override
  String desktopRoomKickBody(Object name) {
    return '$name perderá o acesso à sala. Um novo convite o traz de volta.';
  }

  @override
  String get desktopRoomBlockTitle => 'Bloquear o membro?';

  @override
  String desktopRoomBlockBody(Object name) {
    return '$name não poderá voltar à sala, mesmo com convite, enquanto o bloqueio durar.';
  }

  @override
  String get desktopRoomTransferTitle => 'Transferir a propriedade da sala?';

  @override
  String desktopRoomTransferBody(Object name) {
    return '$name passa a proprietário e você a administrador. Só o novo proprietário pode desfazer.';
  }

  @override
  String get desktopRoomTransferAction => 'Transferir';

  @override
  String get desktopRoomClearTitle => 'Limpar o histórico?';

  @override
  String get desktopRoomClearBody => 'Todas as mensagens da sala serão excluídas neste dispositivo.';

  @override
  String get desktopRoomLeaveTitle => 'Sair da sala?';

  @override
  String get desktopRoomLeaveBody => 'Você deixará de receber mensagens. Para voltar é preciso um novo convite.';

  @override
  String get desktopRoomLeave => 'Sair';

  @override
  String get desktopRoomInvite => 'Convidar';

  @override
  String get desktopRoomCopyId => 'Copiar o ID da sala';

  @override
  String get desktopRoomMuteOff => 'Desligar as notificações';

  @override
  String get desktopRoomUnarchive => 'Tirar do arquivo';

  @override
  String get desktopRoomLeaveRoom => 'Sair da sala';

  @override
  String get desktopRoomUntitled => 'Sem nome';

  @override
  String get desktopRoomCopyInvite => 'Copiar o convite';

  @override
  String get desktopRoomSound => 'Som';

  @override
  String get desktopRoomTabInfo => 'Info';

  @override
  String get desktopRoomTabMembers => 'Membros';

  @override
  String get desktopRoomTabMedia => 'Mídia';

  @override
  String get desktopRoomTopics => 'TÓPICOS';

  @override
  String desktopRoomTopicsCount(Object count) {
    return 'TÓPICOS · $count';
  }

  @override
  String get desktopRoomDescription => 'Descrição';

  @override
  String get desktopRoomNotes => 'NOTAS';

  @override
  String get desktopRoomInformation => 'Informação';

  @override
  String get desktopRoomId => 'ID da sala';

  @override
  String get desktopRoomInviteLink => 'Link de convite · clique para copiar';

  @override
  String get desktopRoomFavouriteHint => 'Um bloco na barra e um lugar no topo da lista';

  @override
  String get desktopRoomArchiveHint => 'Ocultar a sala da lista principal';

  @override
  String get desktopRoomNoMembers => 'Sem membros';

  @override
  String desktopRoomMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membros',
      one: '$count membro',
    );
    return '$_temp0';
  }

  @override
  String get desktopRoomNobodyFound => 'Ninguém encontrado';

  @override
  String get desktopRoomMembersUnavailable => 'A lista de membros está indisponível.';

  @override
  String get desktopRoomInCall => 'NA CHAMADA';

  @override
  String get desktopRoomOnline => 'ON-LINE';

  @override
  String get desktopRoomOffline => 'OFF-LINE';

  @override
  String desktopRoomMoreHidden(Object count) {
    return 'Mais $count — use a busca acima';
  }

  @override
  String get desktopRoomSearchMember => 'Buscar um membro';

  @override
  String get desktopRoomJoinRequests => 'Pedidos de entrada';

  @override
  String get desktopRoomAccept => 'Aceitar';

  @override
  String get desktopRoomDecline => 'Recusar';

  @override
  String get desktopRoomRoleOwner => 'Proprietário';

  @override
  String get desktopRoomRoleAdmin => 'Administrador';

  @override
  String get desktopRoomRoleModerator => 'Moderador';

  @override
  String get desktopRoomRoleRestricted => 'Restrito';

  @override
  String get desktopRoomRoleGuest => 'Convidado';

  @override
  String get desktopContactBlockTitle => 'Bloquear?';

  @override
  String get desktopContactUnblockTitle => 'Desbloquear?';

  @override
  String get desktopContactBlockBody => 'Esta pessoa não poderá mais enviar mensagens nem ligar para você.';

  @override
  String get desktopContactUnblockBody => 'Esta pessoa poderá voltar a falar com você.';

  @override
  String get desktopContactBlock => 'Bloquear';

  @override
  String get desktopContactCallsNotReady => 'O serviço de chamadas ainda não está pronto';

  @override
  String get desktopContactCallInProgress => 'Já há uma chamada em andamento';

  @override
  String desktopContactCallFailed(Object error) {
    return 'Não foi possível iniciar a chamada: $error';
  }

  @override
  String get desktopContactAutoDelete => 'Exclusão automática de mensagens';

  @override
  String get desktopContactAutoDeleteUpdated => 'A exclusão automática foi atualizada';

  @override
  String get desktopContactClearBody => 'Todas as mensagens desta conversa serão excluídas neste dispositivo.';

  @override
  String get desktopContactDeleteBody => 'A conversa será totalmente removida deste dispositivo.';

  @override
  String get desktopContactOff => 'Desligado';

  @override
  String get desktopContactDisable => 'Desligar';

  @override
  String get desktopContactDay1 => '1 dia';

  @override
  String get desktopContactDays7 => '7 dias';

  @override
  String get desktopContactDays30 => '30 dias';

  @override
  String get desktopContactHour1 => '1 hora';

  @override
  String desktopContactMinutes(Object value) {
    return '$value min';
  }

  @override
  String get desktopContactOffline => 'off-line';

  @override
  String desktopContactSeenAt(Object time) {
    return 'visto às $time';
  }

  @override
  String get desktopContactSeenYesterday => 'visto ontem';

  @override
  String desktopContactSeenOn(Object date) {
    return 'visto em $date';
  }

  @override
  String get desktopContactCopyId => 'Copiar o ID';

  @override
  String get desktopContactCopyIdShort => 'Copiar ID';

  @override
  String get desktopContactDisappearing => 'Mensagens que desaparecem';

  @override
  String get desktopContactDeleteChat => 'Excluir a conversa';

  @override
  String get desktopContactCall => 'Chamada';

  @override
  String get desktopContactBlockShort => 'Bloq.';

  @override
  String get desktopContactSecurity => 'Segurança';

  @override
  String get desktopContactVerify => 'Verificar o contato';

  @override
  String get desktopContactArchiveHint => 'Ocultar a conversa da lista principal';

  @override
  String get desktopThreadMessageHint => 'Mensagem…';

  @override
  String get desktopThreadPasteFailed => 'Não foi possível colar a imagem';

  @override
  String get desktopThreadNoScheduleEdit => 'Uma edição não pode ser agendada — altera algo já enviado';

  @override
  String desktopThreadWillLeave(Object when) {
    return 'Sairá $when';
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
    return 'Selecionados: $count';
  }

  @override
  String get desktopThreadDisappearingOn => 'As mensagens que desaparecem estão ligadas';

  @override
  String get desktopThreadCallAction => 'Ligar';

  @override
  String get desktopThreadCallRoom => 'Chamada em grupo';

  @override
  String get desktopThreadVideoCall => 'Videochamada';

  @override
  String get desktopThreadSearchShortcut => 'Buscar na conversa  Cmd F';

  @override
  String get desktopThreadHideDetails => 'Ocultar os detalhes';

  @override
  String get desktopThreadShowDetails => 'Mostrar os detalhes';

  @override
  String get desktopThreadMore => 'Mais';

  @override
  String get desktopThreadPinned => 'Mensagem fixada';

  @override
  String get desktopThreadNoMatches => 'sem correspondências';

  @override
  String get desktopThreadSearchHint => 'Buscar na conversa…';

  @override
  String get desktopThreadPrevMatch => 'Anterior (Shift F3)';

  @override
  String get desktopThreadNextMatch => 'Próximo (F3)';

  @override
  String get desktopThreadCloseEsc => 'Fechar (Esc)';

  @override
  String get desktopThreadNewMessages => 'Mensagens novas';

  @override
  String desktopThreadUnreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count não lidas',
      one: '$count não lida',
    );
    return '$_temp0';
  }

  @override
  String get desktopThreadToday => 'Hoje';

  @override
  String get desktopThreadYesterday => 'Ontem';

  @override
  String get desktopProfileEmojiStatus => 'Status com emoji';

  @override
  String get desktopProfileClearStatus => 'Remover o status';

  @override
  String desktopProfileApplyFailed(Object error) {
    return 'Não foi possível aplicar: $error';
  }

  @override
  String get desktopProfileAvatarFrame => 'Moldura do avatar';

  @override
  String get desktopProfileCover => 'Capa do perfil';

  @override
  String get desktopProfileNoFrame => 'Sem moldura';

  @override
  String get desktopProfileNoCover => 'Sem capa';

  @override
  String get desktopProfileReadFailed => 'Não foi possível ler o arquivo';

  @override
  String get desktopProfilePhotoUpdated => 'A foto de perfil foi atualizada';

  @override
  String desktopProfilePhotoFailed(Object error) {
    return 'Não foi possível atualizar a foto: $error';
  }

  @override
  String desktopProfilePhotoRemoveFailed(Object error) {
    return 'Não foi possível remover a foto: $error';
  }

  @override
  String get desktopProfileMine => 'Meu perfil';

  @override
  String get desktopProfileEdit => 'Editar';

  @override
  String get desktopProfileName => 'Nome';

  @override
  String get desktopProfileChangePhoto => 'Trocar a foto';

  @override
  String get desktopProfileFrameShort => 'Moldura';

  @override
  String get desktopProfileCoverShort => 'Capa';

  @override
  String get desktopProfileStatus => 'Status';

  @override
  String get desktopProfileAppearanceHint => 'Tema, acento e papel de parede da conversa';

  @override
  String get desktopProfileAbout => 'Sobre mim';

  @override
  String get desktopProfileEmpty => 'Não preenchido';

  @override
  String get desktopProfilePhoto => 'Foto de perfil';

  @override
  String get desktopProfileReplacePhoto => 'Substituir a foto';

  @override
  String get desktopProfilePickPhoto => 'Escolher uma foto';

  @override
  String get desktopProfilePickedHere => 'Escolhida neste computador';

  @override
  String get desktopProfileSyncedWithPhone => 'Sincronizada com o celular';

  @override
  String get desktopProfileNotPicked => 'Não escolhida';

  @override
  String get desktopProfileRemovePhoto => 'Remover a foto';

  @override
  String get desktopProfileInitialsStay => 'Ficam as iniciais';

  @override
  String get desktopProfileAccount => 'Conta';

  @override
  String get desktopProfileRecovery => 'Recuperação';

  @override
  String get desktopProfileRecoveryHint => 'Este computador está conectado ao celular e não guarda a própria frase de recuperação: o backup e a chave de recuperação devolvem a conta.';

  @override
  String get desktopProfileDevicesHint => 'Computadores e celulares conectados';

  @override
  String get desktopProfileFrameCaps => 'MOLDURA DO AVATAR';

  @override
  String get desktopGalleryMedia => 'Mídia';

  @override
  String get desktopGalleryFiles => 'Arquivos';

  @override
  String get desktopGalleryLinks => 'Links';

  @override
  String get desktopGalleryNoMedia => 'Sem mídia';

  @override
  String get desktopGalleryNoFiles => 'Sem arquivos';

  @override
  String get desktopGalleryNoAudio => 'Sem áudio';

  @override
  String get desktopGalleryNoLinks => 'Sem links';

  @override
  String get desktopGalleryPathCopied => 'O caminho foi copiado';

  @override
  String get desktopGalleryOpen => 'Abrir';

  @override
  String get desktopGalleryView => 'Ver';

  @override
  String get desktopGalleryOpenInSystem => 'Abrir no sistema';

  @override
  String get desktopGalleryRevealFinder => 'Mostrar no Finder';

  @override
  String get desktopGalleryRevealExplorer => 'Mostrar no Explorador';

  @override
  String get desktopGalleryOpenFolder => 'Abrir a pasta';

  @override
  String get desktopGalleryCopyPath => 'Copiar o caminho';

  @override
  String desktopGalleryBytes(Object value) {
    return '$value B';
  }

  @override
  String get desktopGalleryZeroBytes => '0 B';

  @override
  String desktopOutgoingFolderSingle(Object name) {
    return 'a pasta “$name” não pode ser enviada';
  }

  @override
  String get desktopOutgoingFoldersMany => 'as pastas não podem ser enviadas';

  @override
  String desktopOutgoingTooLargeOne(Object name, Object limit) {
    return '“$name” é maior que $limit MB';
  }

  @override
  String desktopOutgoingTooLargeMany(int count, Object limit) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count arquivos são maiores que $limit MB',
      one: '$count arquivo é maior que $limit MB',
    );
    return '$_temp0';
  }

  @override
  String desktopOutgoingEmptyOne(Object name) {
    return '“$name” está vazio';
  }

  @override
  String desktopOutgoingEmptyMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count arquivos estão vazios',
      one: '$count arquivo está vazio',
    );
    return '$_temp0';
  }

  @override
  String desktopOutgoingUnreadableOne(Object name) {
    return 'não foi possível ler “$name”';
  }

  @override
  String desktopOutgoingUnreadableMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count arquivos não puderam ser lidos',
      one: '$count arquivo não pôde ser lido',
    );
    return '$_temp0';
  }

  @override
  String get desktopOutgoingSending => 'Envio';

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
    return '$count mídias';
  }

  @override
  String desktopOutgoingAudios(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count áudios',
      one: '$count áudios',
    );
    return '$_temp0';
  }

  @override
  String desktopOutgoingFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count arquivos',
      one: '$count arquivos',
    );
    return '$_temp0';
  }

  @override
  String get desktopCallsPickOne => 'Escolha uma chamada à esquerda';

  @override
  String get desktopCallsPickHint => 'Aqui aparecem os detalhes e um botão para ligar de volta';

  @override
  String get desktopCallsNone => 'Ainda não há chamadas';

  @override
  String get desktopCallsNoneHint => 'O histórico aparece depois da primeira chamada';

  @override
  String get desktopCallsOutgoing => 'Efetuada';

  @override
  String get desktopCallsIncoming => 'Recebida';

  @override
  String get desktopCallsGroup => 'em grupo';

  @override
  String get desktopCallsVideoKind => 'vídeo';

  @override
  String get desktopCallsAudioKind => 'áudio';

  @override
  String get desktopCallsMissed => 'perdida';

  @override
  String desktopPhotoCopyFailed(Object error) {
    return 'Não foi possível copiar: $error';
  }

  @override
  String get desktopPhotoSave => 'Salvar a foto';

  @override
  String get desktopPhotoSaved => 'Salvo';

  @override
  String desktopPhotoRevealFailed(Object error) {
    return 'Não foi possível mostrar no Finder: $error';
  }

  @override
  String get desktopPhotoLoadFailed => 'Não foi possível carregar';

  @override
  String get desktopPhotoZoomOut => 'Reduzir';

  @override
  String get desktopPhotoZoomReset => 'Redefinir o zoom';

  @override
  String get desktopPhotoZoomIn => 'Ampliar';

  @override
  String get desktopPhotoCopy => 'Copiar';

  @override
  String desktopBubbleForwardedFrom(Object from) {
    return 'Encaminhado de $from';
  }

  @override
  String get desktopBubbleAudioFile => 'Arquivo de áudio';

  @override
  String get desktopBubbleTranslating => 'Traduzindo…';

  @override
  String get desktopBubbleTranslation => 'TRADUÇÃO';

  @override
  String get desktopBubbleEdited => 'editado';

  @override
  String get desktopBubbleMoreReactions => 'Mais reações';

  @override
  String get desktopBubbleRoleOwner => 'proprietário';

  @override
  String get desktopBubbleRoleAdmin => 'admin';

  @override
  String get desktopBubbleRoleMod => 'mod';

  @override
  String get desktopBubbleSpeed => 'Velocidade de reprodução';

  @override
  String get desktopSpotlightGoChats => 'Ir para as conversas';

  @override
  String get desktopSpotlightGoRooms => 'Ir para as salas';

  @override
  String get desktopSpotlightGoContacts => 'Ir para os contatos';

  @override
  String get desktopSpotlightGoCalls => 'Ir para as chamadas';

  @override
  String get desktopSpotlightSelect => 'selecionar';

  @override
  String get desktopSpotlightOpen => 'abrir';

  @override
  String get desktopSpotlightClose => 'fechar';

  @override
  String get desktopSpotlightRoom => 'Sala';

  @override
  String get desktopSpotlightMessage => 'Mensagem';

  @override
  String get desktopSpotlightCommand => 'Comando';

  @override
  String get desktopComposerCancelRec => 'Cancelar a gravação';

  @override
  String desktopComposerRecording(Object time) {
    return 'Gravando  $time';
  }

  @override
  String get desktopComposerSendVoice => 'Enviar a mensagem de voz';

  @override
  String get desktopComposerAttach => 'Anexar';

  @override
  String get desktopComposerEmoji => 'Emoji e figurinhas';

  @override
  String get desktopComposerRecordVoice => 'Gravar uma mensagem de voz';

  @override
  String get desktopComposerEnterSends => 'Enter envia · Shift+Enter quebra a linha';

  @override
  String get desktopComposerEnterNewline => 'Enter quebra a linha · Shift+Enter envia';

  @override
  String get desktopComposerEditing => 'Edição';

  @override
  String desktopComposerReplyTo(Object name) {
    return 'Resposta · $name';
  }

  @override
  String get desktopComposerCancelAction => 'Cancelar';

  @override
  String get desktopComposerSendHint => 'Enviar · Enter\nBotão direito para enviar depois';

  @override
  String get desktopComposerWriteFirst => 'Escreva primeiro uma mensagem';

  @override
  String desktopComposerToTopic(Object title) {
    return 'para o tópico “$title”';
  }

  @override
  String get desktopShortcutsNavigation => 'Navegação';

  @override
  String get desktopShortcutsTabs => 'Conversas · Salas · Chamadas · Contatos';

  @override
  String get desktopShortcutsSearchAll => 'Buscar em conversas e mensagens';

  @override
  String get desktopShortcutsPrevNext => 'Conversa anterior / próxima';

  @override
  String get desktopShortcutsInChat => 'Em uma conversa';

  @override
  String get desktopShortcutsFindHere => 'Buscar nesta conversa';

  @override
  String get desktopShortcutsSend => 'Enviar (configurável)';

  @override
  String get desktopShortcutsNewline => 'Quebra de linha';

  @override
  String get desktopShortcutsPaste => 'Colar uma imagem da área de transferência';

  @override
  String get desktopShortcutsApp => 'Aplicativo';

  @override
  String get desktopShortcutsThisHelp => 'Esta ajuda';

  @override
  String get desktopShortcutsCloseWindow => 'Fechar a janela ou a busca';

  @override
  String get desktopShortcutsTray => 'Minimizar para a bandeja';

  @override
  String get desktopShortcutsTitle => 'Atalhos de teclado';

  @override
  String get desktopMediaCancelSend => 'Cancelar o envio';

  @override
  String get desktopMediaSending => 'Enviando…';

  @override
  String desktopMediaSendingOf(Object total) {
    return 'Enviando… · $total';
  }

  @override
  String get desktopMediaRetryDownload => 'Repetir o download';

  @override
  String get desktopMediaImage => 'Imagem';

  @override
  String desktopMediaDownloading(Object size) {
    return 'Baixando… · $size';
  }

  @override
  String get desktopMediaDownload => 'Baixar';

  @override
  String get desktopSendAsMedia => 'Enviar como mídia';

  @override
  String get desktopSendAsFiles => 'Enviar como arquivos';

  @override
  String get desktopSendUngroup => 'Não agrupar';

  @override
  String get desktopSendGroup => 'Agrupar';

  @override
  String get desktopSendAddFiles => 'Adicionar arquivos…';

  @override
  String get desktopSendDropHere => 'Solte para adicionar';

  @override
  String get desktopSendCloseEsc => 'Fechar · Esc';

  @override
  String desktopSendToDestination(Object destination) {
    return 'para “$destination”';
  }

  @override
  String get desktopSendCaptionHint => 'Adicionar uma legenda…';

  @override
  String get desktopSendEmoji => 'Emoji';

  @override
  String get desktopSendRemove => 'Remover';

  @override
  String get desktopSendEnter => 'Enviar · Enter';

  @override
  String get desktopSendShiftEnter => 'Enviar · Shift+Enter';

  @override
  String get desktopCallCtlMicOff => 'Desligar o microfone   ⌘D';

  @override
  String get desktopCallCtlMicOn => 'Ligar o microfone   ⌘D';

  @override
  String get desktopCallCtlCamOff => 'Desligar a câmera   ⌘E';

  @override
  String get desktopCallCtlCamOn => 'Ligar a câmera   ⌘E';

  @override
  String get desktopCallCtlShareStop => 'Parar o compartilhamento';

  @override
  String get desktopCallCtlShare => 'Compartilhamento de tela';

  @override
  String get desktopCallCtlHandDown => 'Baixar a mão';

  @override
  String get desktopCallCtlHandUp => 'Levantar a mão';

  @override
  String get desktopCallCtlHangUp => 'Encerrar   ⌘W';

  @override
  String desktopAbsenceDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dias',
      one: '$count dia',
    );
    return '$_temp0';
  }

  @override
  String desktopAbsencePastFanout(Object days) {
    return 'Este computador ficou sem conexão $days. Nesse tempo os remetentes pararam de criptografar mensagens para ele, e parte do histórico não vai chegar aqui. No celular está intacto — abra lá as conversas necessárias e o histórico recente é sincronizado.';
  }

  @override
  String desktopAbsenceWithinWindow(Object days) {
    return 'Este computador ficou sem conexão $days. As mensagens ficam uma semana no servidor, então parte delas pode não ter sido preservada para ele. No celular estão intactas.';
  }

  @override
  String get desktopAbsenceGotIt => 'Entendi';

  @override
  String get desktopNavContacts => 'Contatos';

  @override
  String get desktopChatNotFound => 'A conversa não foi encontrada';

  @override
  String desktopUnreadTitle(Object count) {
    return 'Secretly — $count não lidas';
  }

  @override
  String get desktopRoomsNone => 'Ainda não há salas';

  @override
  String get desktopRoomsNoneHint => 'Crie uma sala no celular — ela aparece aqui automaticamente';

  @override
  String get desktopRoomsPickOne => 'Escolha uma sala à esquerda';

  @override
  String get desktopScheduleTitle => 'Enviar depois';

  @override
  String get desktopScheduleInHour => 'Daqui a uma hora';

  @override
  String get desktopScheduleTonight => 'Hoje às 19:00';

  @override
  String get desktopScheduleTomorrow => 'Amanhã às 9:00';

  @override
  String get desktopScheduleInWeek => 'Daqui a uma semana';

  @override
  String desktopScheduleTodayAt(Object time) {
    return 'hoje às $time';
  }

  @override
  String desktopScheduleTomorrowAt(Object time) {
    return 'amanhã às $time';
  }

  @override
  String desktopScheduleOnAt(Object date, Object time) {
    return '$date às $time';
  }

  @override
  String get desktopScheduleHint => 'A mensagem sai sozinha no horário escolhido — mesmo com a janela fechada, será enviada na próxima inicialização.';

  @override
  String get desktopSchedulePickTime => 'Escolher o horário…';

  @override
  String get desktopDevicesSearching => 'Procurando dispositivos…';

  @override
  String get desktopDevicesNoCameras => 'Nenhuma câmera encontrada. Talvez o aplicativo não tenha acesso nas configurações do sistema.';

  @override
  String get desktopDevicesNoMics => 'Nenhum microfone encontrado. Talvez o aplicativo não tenha acesso nas configurações do sistema.';

  @override
  String get desktopDevicesOutputHint => 'Para onde sai o som se escolhe dentro da chamada — pelo sinal ao lado de “Microfone”. É aí que o aplicativo muda sozinho para os fones quando são conectados.';

  @override
  String get desktopDevicesSystemDefault => 'Como no sistema';

  @override
  String get desktopRailSettings => 'Configurações   Cmd ,';

  @override
  String get desktopRailConnected => 'Conectado';

  @override
  String get desktopRailConnecting => 'Conectando…';

  @override
  String get desktopRailOffline => 'Sem conexão';

  @override
  String desktopRailProfile(Object status) {
    return 'Perfil   Cmd P   ·   $status';
  }

  @override
  String get desktopEmojiSmileys => 'Sorrisos e emoções';

  @override
  String get desktopEmojiPeople => 'Pessoas e corpo';

  @override
  String get desktopEmojiNature => 'Natureza';

  @override
  String get desktopEmojiFood => 'Comida e bebida';

  @override
  String get desktopEmojiTravel => 'Viagens';

  @override
  String get desktopEmojiActivities => 'Atividades';

  @override
  String get desktopEmojiObjects => 'Objetos';

  @override
  String get desktopEmojiSymbols => 'Símbolos';

  @override
  String get desktopEmojiFlags => 'Bandeiras';

  @override
  String get desktopEmojiOther => 'Outros';

  @override
  String get desktopLockedTitle => 'O Secretly está bloqueado';

  @override
  String get desktopLockedTouchIdPrompt => 'Confirme a sua identidade com o Touch ID para continuar.';

  @override
  String get desktopLockedPasswordPrompt => 'Confirme com a palavra-passe do dispositivo para continuar.';

  @override
  String get desktopLockedUnlock => 'Desbloquear';

  @override
  String get desktopLockedWaiting => 'A aguardar confirmação…';

  @override
  String get desktopLockedFailed => 'Não foi possível confirmar a sua identidade.';

  @override
  String get desktopLockedNoService => 'O serviço de identidade não está disponível neste computador. Reinicie o Secretly ou o computador. Se não resolver, escreva ao suporte a partir do telemóvel.';

  @override
  String get desktopEmojiTabEmoji => 'Emojis';

  @override
  String get desktopEmojiTabStickers => 'Autocolantes';

  @override
  String get desktopEmojiRecents => 'Recentes';

  @override
  String get desktopEmojiNothingFound => 'Nada encontrado';

  @override
  String get desktopEmojiSearchHint => 'Procurar emojis';

  @override
  String get desktopStickersSearchHint => 'Procurar autocolantes';

  @override
  String get desktopGifSearchHint => 'Procurar GIFs';

  @override
  String get desktopGifUnavailable => 'Os GIFs não estão disponíveis nesta janela';

  @override
  String get desktopStickerPacksSoon => 'Packs de autocolantes em breve';

  @override
  String get desktopCallFullscreen => 'Ecrã inteiro';

  @override
  String get desktopCallExitFullscreen => 'Sair do ecrã inteiro';

  @override
  String get desktopCallDialing => 'A chamar…';

  @override
  String get desktopCallEnded => 'Terminada';

  @override
  String desktopCallEncryptedFor(Object duration) {
    return 'Encriptada · $duration';
  }

  @override
  String get desktopCallReturn => 'Voltar';

  @override
  String get desktopCallInProgress => 'Chamada a decorrer';

  @override
  String desktopCallInProgressWith(Object title) {
    return 'Chamada a decorrer · $title';
  }

  @override
  String get desktopCallAnswer => 'Atender';

  @override
  String get desktopCallAnswerVideo => 'Atender com vídeo';

  @override
  String get desktopCallAnswerText => 'Por texto';

  @override
  String get desktopTimeYesterday => 'ontem';

  @override
  String get desktopForwardTitle => 'Reencaminhar para…';

  @override
  String get desktopForwardSearchHint => 'Procurar conversa ou sala';

  @override
  String get desktopForwardNoChats => 'Sem conversas disponíveis';

  @override
  String get desktopForwardKindDirect => 'Conversa direta';

  @override
  String get desktopContactsSearchHint => 'Procurar contactos';

  @override
  String get desktopContactsEmpty => 'Os contactos vão aparecer após a sincronização.';

  @override
  String desktopContactsNothingFor(Object query) {
    return 'Nada encontrado para «$query».';
  }

  @override
  String get desktopContactsPick => 'Escolha um contacto';

  @override
  String get desktopContactsCardRight => 'O cartão vai aparecer à direita.';

  @override
  String get desktopContactsWrite => 'Escrever mensagem';

  @override
  String get desktopVideoTitle => 'Vídeo';

  @override
  String get desktopViewerCloseEsc => 'Fechar  Esc';

  @override
  String get desktopVideoPlayFailed => 'Não foi possível reproduzir o vídeo';

  @override
  String get desktopKeySpace => 'Espaço';

  @override
  String get desktopWindowMinimize => 'Minimizar';

  @override
  String get desktopWindowMaximize => 'Maximizar';

  @override
  String get desktopWindowClose => 'Fechar';

  @override
  String get desktopWindowBack => 'Anterior';

  @override
  String get desktopWindowForward => 'Seguinte';

  @override
  String get desktopSearchEverything => 'Conversas, pessoas, mensagens, ficheiros';

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
  String get desktopSyncSyncing => 'A sincronizar…';

  @override
  String get desktopSyncReconnecting => 'A reconectar…';

  @override
  String get desktopDetailsShare => 'Partilhar';

  @override
  String get desktopDetailsHide => 'Ocultar';

  @override
  String get desktopDetailsMore => 'Mais';

  @override
  String get desktopDetailsChangeCover => 'Mudar a capa';

  @override
  String desktopDetailsFrame(Object name) {
    return 'Moldura «$name»';
  }

  @override
  String get desktopApply => 'Aplicar';

  @override
  String get desktopAccentAppliesTo => 'Botões, seleções e anéis. O balão mantém o seu estilo — escolhe-se abaixo.';

  @override
  String get desktopTranslateUnknownSource => 'Não foi possível detetar o idioma da mensagem';

  @override
  String get desktopTranslateUnsupported => 'O tradutor do sistema não conhece este par de idiomas';

  @override
  String get desktopTranslateNeedsDownload => 'O idioma não foi transferido. Definições do Sistema → Geral → Idioma e região → Idiomas de tradução';

  @override
  String get desktopTranslateFailed => 'Não foi possível traduzir';

  @override
  String get desktopNewChatSearchHint => 'Procurar nos contactos';

  @override
  String get desktopNewChatNoContacts => 'Ainda sem contactos';

  @override
  String get desktopNewChatNobodyFound => 'Ninguém encontrado';

  @override
  String get desktopMentionEveryone => 'Todos os participantes';

  @override
  String get desktopMentionAdmins => 'Administradores';

  @override
  String get desktopMentionEveryoneHint => 'Chamar todos na sala';

  @override
  String get desktopMentionAdminsHint => 'Chamar o dono e os administradores';

  @override
  String desktopClearForPeer(Object name) {
    return 'Limpar também o histórico de $name';
  }

  @override
  String get desktopClearForPeerHint => 'As mensagens vão desaparecer no dispositivo dele e em todos os seus. Isto não pode ser anulado.';

  @override
  String get desktopGifNoKey => 'GIFs indisponíveis: compilação sem chave GIPHY';

  @override
  String get desktopGifConnectionLost => 'A ligação caiu. Tente novamente';

  @override
  String get desktopNotesHint => 'O que reter desta conversa…';

  @override
  String get desktopNotesPrivate => 'Visível apenas para si. Não é enviado, não aparece na conversa e não entra na cópia de segurança — fica neste computador, na mesma base encriptada das mensagens.';

  @override
  String get desktopEmojiSearchShort => 'Procurar emojis…';

  @override
  String get desktopNotifOpen => 'Abrir';

  @override
  String get desktopLinkPreviewLoading => 'Pré-visualização do link…';

  @override
  String get desktopLinkPreviewOff => 'Sem pré-visualização';

  @override
  String get desktopDropToSend => 'Largue para enviar';

  @override
  String get desktopDropEncrypted => 'Os ficheiros são encriptados antes do envio';

  @override
  String get desktopDetailsPickChat => 'Escolha uma conversa';

  @override
  String get desktopDetailsEmptyHint => 'Os dados da pessoa ou da sala\nvão aparecer aqui.';

  @override
  String get desktopMemberWrite => 'Escrever';

  @override
  String get desktopShowPanel => 'Mostrar o painel';

  @override
  String get desktopHidePanel => 'Ocultar o painel';

  @override
  String get desktopNotifOff => 'As notificações estão desligadas';

  @override
  String get desktopSettingsSearchHint => 'Encontrar uma definição';

  @override
  String get desktopUnlockPrompt => 'Desbloquear o Secretly';

  @override
  String get desktopEnableLockPrompt => 'Confirme para ativar o bloqueio do Secretly';

  @override
  String get desktopRoomsNoneHintDot => 'Crie uma sala no telemóvel — vai aparecer aqui sozinha.';

  @override
  String get desktopSplashLoading => 'A carregar o perfil…';

  @override
  String get desktopOutgoingOnePhoto => 'Foto';

  @override
  String get desktopOutgoingOneVideo => 'Vídeo';

  @override
  String get desktopOutgoingOneAudio => 'Áudio';

  @override
  String get desktopOutgoingOneFile => 'Arquivo';

  @override
  String get desktopMenuSettings => 'Ajustes…';

  @override
  String get desktopMenuEdit => 'Editar';

  @override
  String get desktopMenuUndo => 'Desfazer';

  @override
  String get desktopMenuRedo => 'Refazer';

  @override
  String get desktopMenuCut => 'Recortar';

  @override
  String get desktopMenuPaste => 'Colar';

  @override
  String get desktopMenuSelectAll => 'Selecionar tudo';

  @override
  String get desktopMenuView => 'Visualizar';

  @override
  String get desktopMenuWindow => 'Janela';

  @override
  String get desktopMenuHelp => 'Ajuda';

  @override
  String get desktopMenuWebsite => 'Site do Secretly';
}
