// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:secretly_app/ui/secretly_snackbar.dart';
import 'package:flutter/services.dart';

import '../app/app_controller.dart';
import '../diagnostics/diag_log.dart';
import '../security/app_security_manager.dart';
import '../security/backup_password_policy.dart';
import '../security/restore_error_classification.dart';
import '../security/safe_backup.dart';
import 'animations/animations.dart';
import 'icons/app_icons.dart';
import 'l10n.dart';
import 'recovery_kit_screen.dart';
import 'safe_backup_file_io.dart';
import 'security_lock_flow.dart';
import 'wave1_l10n.dart';
import 'widgets/frosted_top_bar.dart';

class SafeBackupScreen extends StatefulWidget {
  const SafeBackupScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<SafeBackupScreen> createState() => _SafeBackupScreenState();
}

enum _BackupCreateDestination { server, local }

enum _BackupRestoreSource { server, local }

class _SafeBackupScreenState extends State<SafeBackupScreen> {
  static final Object _manualBackupFilePick = Object();

  static const List<int> _freqOptionsMin = <int>[
    15,
    60,
    6 * 60,
    12 * 60,
    24 * 60,
    3 * 24 * 60,
    7 * 24 * 60,
  ];

  AppController get controller => widget.controller;

  /// Whether an auto-backup password is stored. Read once on open (and after
  /// the user changes it) instead of from a FutureBuilder inside the
  /// controller's change stream — that fired a keychain read for every
  /// incoming message, receipt and presence tick.
  bool? _passwordSet;

  @override
  void initState() {
    super.initState();
    _refreshPasswordState();
  }

  Future<void> _refreshPasswordState() async {
    final has = await controller.hasSafeBackupAutoPassword();
    if (!mounted) return;
    setState(() => _passwordSet = has);
  }

  String _label(
    BuildContext context, {
    required String ru,
    required String en,
  }) {
    final localeTag = wave1LocaleTagFromContext(context);
    if (localeTag == 'ru') return ru;
    if (localeTag == 'en') return en;

    final l10n = context.l10n;
    String suffix(String prefix) => en.substring(prefix.length);

    if (en.startsWith('Secretly ID: ')) {
      return l10n.safeBackupPreviewProfileId(suffix('Secretly ID: '));
    }
    if (en.startsWith('Contacts: ')) {
      final count = int.tryParse(suffix('Contacts: ')) ?? 0;
      return l10n.safeBackupPreviewContacts(count);
    }
    if (en.startsWith('Server: ')) {
      return l10n.safeBackupPreviewServer(suffix('Server: '));
    }
    if (en.startsWith('Backup export failed: ')) {
      return l10n.safeBackupExportFailed(suffix('Backup export failed: '));
    }
    if (en.startsWith('Could not read backup file: ')) {
      return l10n.safeBackupReadFileFailed(
        suffix('Could not read backup file: '),
      );
    }
    if (en.startsWith('Failed: ')) {
      return l10n.genericFailed(suffix('Failed: '));
    }
    if (en.startsWith('Last auto-backup error: ')) {
      return l10n.safeBackupLastAutoBackupError(
        suffix('Last auto-backup error: '),
      );
    }
    if (en == 'Last auto-backup: never') {
      return l10n.safeBackupLastAutoBackupNever;
    }
    if (en.startsWith('Last auto-backup: ')) {
      return l10n.safeBackupLastAutoBackup(suffix('Last auto-backup: '));
    }
    if (en.startsWith('Last device backup: ')) {
      return l10n.safeBackupLastDeviceBackup(suffix('Last device backup: '));
    }

    switch (en) {
      case 'Invalid safe backup':
        return l10n.safeBackupInvalidBackup;
      case 'Invalid recovery kit':
        return l10n.invalidRecoveryKit;
      case 'Failed to prepare a recovery kit on this device.':
        return l10n.recoveryKitPrepareFailed;
      case 'Backup preview:':
        return l10n.safeBackupPreviewTitle;
      case 'Backup saved to Secretly Files':
        return l10n.safeBackupSavedToFiles;
      case 'Backup export canceled':
        return l10n.safeBackupExportCanceled;
      case 'Create backup':
        return l10n.safeBackupCreateDialogTitle;
      case 'Server backup':
        return l10n.safeBackupServerDestination;
      case 'Local backup':
        return l10n.safeBackupLocalDestination;
      case 'Restore backup':
        return l10n.safeBackupRestoreDialogTitle;
      case 'Restore from device':
        return l10n.safeBackupRestoreFromDevice;
      case 'Restore from server':
        return l10n.safeBackupRestoreFromServer;
      case 'Secretly local backup':
        return l10n.onboardingBackupLocalCandidate;
      case 'Downloads':
        return l10n.safeBackupDownloadsLocation;
      case 'Device folder':
        return l10n.safeBackupDeviceFolderLocation;
      case 'Secretly checked local app backups and Downloads. You can still choose a file manually if it is stored elsewhere.':
        return l10n.safeBackupChooseManualHint;
      case 'Choose manually':
        return l10n.safeBackupChooseManually;
      case 'Choose a Secretly backup file':
        return l10n.onboardingChooseBackupFileTitle;
      case 'Save Frequency':
        return l10n.safeBackupFrequencyTitle;
      case 'Save':
        return l10n.saveAction;
      case 'Back up media':
        return l10n.onboardingBackupMediaTitle;
      case 'Adds photos, videos, files, and avatars to local backups. The file can become large.':
        return l10n.onboardingBackupMediaSubtitle;
      case 'Auto-backup':
        return l10n.onboardingAutoBackupTitle;
      case 'Enable auto-backup':
        return l10n.safeBackupEnableAutoTitle;
      case 'Runs in app while online; encrypted with your password':
        return l10n.safeBackupEnableAutoSubtitle;
      case 'Upload to server':
        return l10n.safeBackupUploadToServer;
      case 'Save on this device':
        return l10n.safeBackupSaveOnDevice;
      case 'Auto-backup password: configured':
        return l10n.safeBackupPasswordConfigured;
      case 'Auto-backup password: not set':
        return l10n.safeBackupPasswordNotSet;
      case 'Auto-backup password saved':
        return l10n.safeBackupPasswordSaved;
      case 'Set password':
        return l10n.safeBackupSetPassword;
      case 'Auto-backup password removed':
        return l10n.safeBackupPasswordRemoved;
      case 'Clear password':
        return l10n.safeBackupClearPassword;
      case 'Auto-backup run requested':
        return l10n.safeBackupRunRequested;
      case 'Run auto-backup now':
        return l10n.safeBackupRunNow;
      case 'Passwords do not match':
        return l10n.onboardingPasswordsDoNotMatch;
      case 'Continue':
        return l10n.continueAction;
      case 'Backup password':
        return l10n.onboardingBackupPasswordTitle;
      default:
        return en;
    }
  }

  String _invalidSafeBackupLabel(BuildContext context) {
    return _label(
      context,
      ru: 'Некорректная резервная копия Secretly',
      en: 'Invalid safe backup',
    );
  }

  String _invalidRecoveryKitLabel(BuildContext context) {
    return _label(
      context,
      ru: 'Некорректный Recovery Kit',
      en: 'Invalid recovery kit',
    );
  }

  String _restoreErrorMessage(
    BuildContext context,
    Object error, {
    required String invalidPayloadLabel,
  }) {
    final l10n = context.l10n;
    switch (classifyEncryptedRestoreError(error)) {
      case EncryptedRestoreFailureKind.wrongPassword:
        return l10n.wrongPassword;
      case EncryptedRestoreFailureKind.invalidPayload:
        return invalidPayloadLabel;
      case EncryptedRestoreFailureKind.networkUnavailable:
        // 🔴 Отдельный текст, а не «копия недействительна». Обрыв связи ничего
        // не говорит о копии, а прежний ответ пугал человека насчёт
        // единственного носителя его переписки — и мог заставить её удалить.
        return _label(
          context,
          ru: 'Нет связи с сервером. Копия цела — попробуйте ещё раз',
          en: 'No connection to the server. The backup is fine — try again',
        );
    }
  }

  String _safeBackupRestoreErrorMessage(BuildContext context, Object error) {
    return _restoreErrorMessage(
      context,
      error,
      invalidPayloadLabel: _invalidSafeBackupLabel(context),
    );
  }

  String _recoveryKitRestoreErrorMessage(BuildContext context, Object error) {
    return _restoreErrorMessage(
      context,
      error,
      invalidPayloadLabel: _invalidRecoveryKitLabel(context),
    );
  }

  String _recoveryKitExportFailedLabel(BuildContext context) {
    return _label(
      context,
      ru: 'Не удалось подготовить Recovery Kit на этом устройстве.',
      en: 'Failed to prepare a recovery kit on this device.',
    );
  }

  String _backupPasswordRequirementsLabel(BuildContext context) {
    return context.l10n.backupPasswordRequirements;
  }

  String _backupPasswordProblemText(
    BuildContext context,
    BackupPasswordValidation validation,
  ) {
    final l10n = context.l10n;
    return validation.problems
        .map((problem) {
          switch (problem) {
            case BackupPasswordProblem.tooShort:
              return l10n.backupPasswordTooShort(
                BackupPasswordPolicy.minLength,
              );
            case BackupPasswordProblem.tooLong:
              return l10n.backupPasswordTooLong(BackupPasswordPolicy.maxLength);
            case BackupPasswordProblem.nonAscii:
              return l10n.backupPasswordNonAscii;
            case BackupPasswordProblem.outerWhitespace:
              return l10n.backupPasswordOuterWhitespace;
            case BackupPasswordProblem.missingUppercase:
              return l10n.backupPasswordMissingUppercase;
            case BackupPasswordProblem.missingSpecial:
              return l10n.backupPasswordMissingSpecial;
          }
        })
        .join('\n');
  }

  void _showSnack(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SecretlySnackBar(content: Text(message)));
  }

  /// Runs [action] behind a non-dismissible progress dialog so a slow
  /// network upload/download/restore never looks like a dead tap.
  Future<T> _withProgressDialog<T>(
    BuildContext context,
    Future<T> Function() action,
  ) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      return await action();
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  int _snapshotRowCount(SafeBackupPlainV1 plain, String table) {
    final rows = plain.dbSnapshot?[table];
    return rows is List ? rows.length : 0;
  }

  int _safeBackupFilesBytes(SafeBackupPlainV1 plain) {
    final files = plain.filesB64ByRelativePath;
    if (files == null || files.isEmpty) return 0;
    var total = 0;
    for (final value in files.values) {
      try {
        total += base64Decode(value).length;
      } catch (_) {}
    }
    return total;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(gb >= 100 ? 0 : 1)} GB';
  }

  List<String> _safeBackupPreviewLines(
    BuildContext context,
    SafeBackupPlainV1 plain,
  ) {
    final fileCount = plain.filesB64ByRelativePath?.length ?? 0;
    final fileBytes = _safeBackupFilesBytes(plain);
    // 🔴 ВОЗРАСТ КОПИИ — ПЕРВОЙ СТРОКОЙ (07.08.2026).
    //
    // Восстановление это ПОЛНАЯ замена: таблицы очищаются и заливаются
    // снимком. Значит копия недельной давности возвращает удалённые тогда
    // чаты и стирает всё, что появилось после неё. Полевая жалоба звучала как
    // «восстанавливаются чаты, которые я давно удалил» — на самом деле человек
    // просто не мог узнать, что копия старая: диалог перечислял контакты,
    // сообщения и чаты, но не дату.
    //
    // Копии старше 07.08.2026 отметки не несут — тогда честно пишем, что
    // возраст неизвестен, вместо того чтобы подставлять «сегодня».
    final createdAtMs = plain.createdAtMs;
    final String ageLine;
    if (createdAtMs == null || createdAtMs <= 0) {
      ageLine = _label(
        context,
        ru: 'Когда снята: неизвестно (копия старого формата)',
        en: 'Taken: unknown (older backup format)',
      );
    } else {
      final when = DateTime.fromMillisecondsSinceEpoch(createdAtMs).toLocal();
      final ageDays = DateTime.now().difference(when).inDays;
      String two(int v) => v.toString().padLeft(2, '0');
      final stamp =
          '${two(when.day)}.${two(when.month)}.${when.year} ${two(when.hour)}:${two(when.minute)}';
      ageLine = ageDays >= 1
          ? _label(
              context,
              ru: 'Когда снята: $stamp — $ageDays дн. назад',
              en: 'Taken: $stamp — $ageDays day(s) ago',
            )
          : _label(context, ru: 'Когда снята: $stamp', en: 'Taken: $stamp');
    }
    return <String>[
      ageLine,
      _label(
        context,
        ru: 'ID в Secretly: ${plain.profileId}',
        en: 'Secretly ID: ${plain.profileId}',
      ),
      _label(
        context,
        ru: 'Контакты: ${plain.contacts.length}',
        en: 'Contacts: ${plain.contacts.length}',
      ),
      _label(
        context,
        ru: 'Сообщения: ${_snapshotRowCount(plain, 'events')}',
        en: 'Messages: ${_snapshotRowCount(plain, 'events')}',
      ),
      _label(
        context,
        ru: 'Чаты: ${_snapshotRowCount(plain, 'conversations')}',
        en: 'Chats: ${_snapshotRowCount(plain, 'conversations')}',
      ),
      _label(
        context,
        ru: 'Медиа-файлы: $fileCount${fileCount > 0 ? ' (${_formatBytes(fileBytes)})' : ''}',
        en: 'Media files: $fileCount${fileCount > 0 ? ' (${_formatBytes(fileBytes)})' : ''}',
      ),
      _label(
        context,
        ru: 'Сервер: ${plain.serverBinding}',
        en: 'Server: ${plain.serverBinding}',
      ),
    ];
  }

  Future<bool> _confirmSafeBackupRestore(
    BuildContext context,
    SafeBackupPlainV1 plain,
  ) async {
    final l10n = context.l10n;
    final lines = _safeBackupPreviewLines(context, plain);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.safeBackupRestoreConfirmTitle),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.safeBackupRestoreConfirmBody),
                  const SizedBox(height: 12),
                  // 🔴 Восстановление — ПОЛНАЯ замена, а не слияние
                  // (`importTables` очищает таблицу и заливает снимок). Всё,
                  // что появилось после копии, исчезает. Раньше это
                  // происходило молча, и человек узнавал постфактум.
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.errorContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _label(
                        context,
                        ru: 'Это замена, а не добавление. Переписка, контакты и '
                            'настройки, появившиеся ПОСЛЕ этой копии, будут '
                            'удалены с устройства.',
                        en: 'This replaces, not merges. Messages, contacts and '
                            'settings created AFTER this backup will be removed '
                            'from this device.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _label(
                      context,
                      ru: 'Что будет восстановлено:',
                      en: 'Backup preview:',
                    ),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  for (final line in lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('- $line'),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.restore),
            ),
          ],
        );
      },
    );
    return ok == true;
  }

  Future<SafeBackupPlainV1?> _decryptAndConfirmSafeBackupRestore(
    BuildContext context, {
    required String payload,
    required String password,
  }) async {
    late final SafeBackupPlainV1 plain;
    try {
      plain = await controller.decryptSafeBackupPayloadForRestore(
        payload: payload,
        password: password,
      );
    } catch (e) {
      if (!context.mounted) return null;
      _showSnack(context, _safeBackupRestoreErrorMessage(context, e));
      return null;
    }

    if (!context.mounted) return null;
    final confirmed = await _confirmSafeBackupRestore(context, plain);
    return confirmed ? plain : null;
  }

  Future<void> _exportSafeBackupFileFlow(BuildContext context) async {
    final authorized = await _authorizeSensitiveBackupAction(context);
    if (!context.mounted || !authorized) return;
    final password = await _promptPasswordConfirm(context);
    if (password == null) return;

    try {
      final path = await controller.saveSafeBackupToDevice(
        password: password,
        includeMedia: controller.safeBackupIncludeMedia,
      );
      final exported = await exportSafeBackupFile(
        sourcePath: path,
        suggestedFileName: safeBackupSuggestedFileName(),
        onSavedPath: (savedPath) async {
          await controller.rememberSafeBackupExternalFilePath(savedPath);
        },
      );
      if (!context.mounted) return;
      _showSnack(
        context,
        exported
            ? _label(
                context,
                ru: 'Резервная копия сохранена в Файлы Secretly',
                en: 'Backup saved to Secretly Files',
              )
            : _label(
                context,
                ru: 'Экспорт резервной копии отменён',
                en: 'Backup export canceled',
              ),
      );
    } catch (e) {
      // The snackbar is easy to miss, and then "I made a backup" and "the
      // restore picker finds nothing" look like two separate bugs instead of
      // one failed write (2026-07-20).
      DiagLog.event('backup', 'device_save_failed', {'err': e.toString()});
      if (!context.mounted) return;
      _showSnack(
        context,
        _label(
          context,
          ru: 'Не удалось экспортировать резервную копию: $e',
          en: 'Backup export failed: $e',
        ),
      );
    }
  }

  Future<_BackupCreateDestination?> _chooseBackupCreateDestination(
    BuildContext context,
  ) {
    return showDialog<_BackupCreateDestination>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _label(context, ru: 'Создать резервную копию', en: 'Create backup'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(AppIcons.cloudUpload),
              title: Text(
                _label(
                  context,
                  ru: 'Резервная копия на сервер',
                  en: 'Server backup',
                ),
              ),
              onTap: () =>
                  Navigator.of(context).pop(_BackupCreateDestination.server),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(AppIcons.fileOutline),
              title: Text(
                _label(
                  context,
                  ru: 'Резервная копия в файл',
                  en: 'Local backup',
                ),
              ),
              onTap: () =>
                  Navigator.of(context).pop(_BackupCreateDestination.local),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.cancel),
          ),
        ],
      ),
    );
  }

  Future<_BackupRestoreSource?> _chooseBackupRestoreSource(
    BuildContext context,
  ) {
    return showDialog<_BackupRestoreSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _label(
            context,
            ru: 'Восстановить резервную копию',
            en: 'Restore backup',
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(AppIcons.fileOutline),
              title: Text(
                _label(
                  context,
                  ru: 'Восстановить из файла',
                  en: 'Restore from device',
                ),
              ),
              onTap: () =>
                  Navigator.of(context).pop(_BackupRestoreSource.local),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(AppIcons.cloudDownload),
              title: Text(
                _label(
                  context,
                  ru: 'Восстановить с сервера',
                  en: 'Restore from server',
                ),
              ),
              onTap: () =>
                  Navigator.of(context).pop(_BackupRestoreSource.server),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.cancel),
          ),
        ],
      ),
    );
  }

  Future<void> _createBackupFlow(BuildContext context) async {
    final destination = await _chooseBackupCreateDestination(context);
    if (!context.mounted || destination == null) return;
    switch (destination) {
      case _BackupCreateDestination.server:
        await _createServerBackupFlow(context);
      case _BackupCreateDestination.local:
        await _exportSafeBackupFileFlow(context);
    }
  }

  Future<void> _createServerBackupFlow(BuildContext context) async {
    final authorized = await _authorizeSensitiveBackupAction(context);
    if (!context.mounted || !authorized) return;
    final pw = await _promptPasswordConfirm(context);
    if (pw == null) return;
    if (!context.mounted) return;
    try {
      final ok = await _withProgressDialog(
        context,
        () => controller.uploadSafeBackupToServer(password: pw),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SecretlySnackBar(
          content: Text(
            ok
                ? context.l10n.safeBackupUploaded
                : context.l10n.safeBackupUploadFailed,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SecretlySnackBar(
          content: Text(
            context.l10n.safeBackupUploadFailedWithError(e.toString()),
          ),
        ),
      );
    }
  }

  Future<void> _restoreBackupFlow(BuildContext context) async {
    final source = await _chooseBackupRestoreSource(context);
    if (!context.mounted || source == null) return;
    final authorized = await _authorizeSensitiveBackupAction(context);
    if (!context.mounted || !authorized) return;
    switch (source) {
      case _BackupRestoreSource.server:
        await _restoreFromServerFlow(context);
      case _BackupRestoreSource.local:
        await _restoreFromBackupFileFlow(context);
    }
  }

  String _backupCandidateLocationLabel(
    BuildContext context,
    SafeBackupFileCandidate candidate,
  ) {
    switch (candidate.location) {
      case SafeBackupFileCandidateLocation.appLocal:
        return _label(
          context,
          ru: 'Локальная резервная копия Secretly',
          en: 'Secretly local backup',
        );
      case SafeBackupFileCandidateLocation.downloads:
        return _label(context, ru: 'Загрузки', en: 'Downloads');
      case SafeBackupFileCandidateLocation.externalFolder:
        return _label(context, ru: 'Папка устройства', en: 'Device folder');
    }
  }

  String _formatCandidateModified(DateTime modifiedAt) {
    final dt = modifiedAt.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  String _backupCandidateSubtitle(
    BuildContext context,
    SafeBackupFileCandidate candidate,
  ) {
    return '${_backupCandidateLocationLabel(context, candidate)} · ${_formatBytes(candidate.sizeBytes)} · ${_formatCandidateModified(candidate.modifiedAt)}';
  }

  Future<String?> _pickSafeBackupPayloadWithAutoSearch(
    BuildContext context,
  ) async {
    final candidates = await discoverSafeBackupFilesOnDevice();
    if (!context.mounted) return null;

    final action = await showDialog<Object>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            _label(
              context,
              ru: candidates.isEmpty
                  ? 'Резервные копии не найдены'
                  : 'Найденные резервные копии',
              en: candidates.isEmpty
                  ? 'No backups found on this device'
                  : 'Found backups',
            ),
          ),
          content: SizedBox(
            width: 460,
            child: candidates.isEmpty
                ? Text(
                    _label(
                      context,
                      ru: 'Secretly автоматически проверил локальные резервные копии приложения и папку Загрузки. Можно выбрать файл вручную, если он сохранён в другом месте.',
                      en: 'Secretly checked local app backups and Downloads. You can still choose a file manually if it is stored elsewhere.',
                    ),
                  )
                : ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: candidates.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final candidate = candidates[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(AppIcons.fileOutline),
                          title: Text(
                            candidate.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            _backupCandidateSubtitle(context, candidate),
                          ),
                          onTap: () => Navigator.of(context).pop(candidate),
                        );
                      },
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(context.l10n.cancel),
            ),
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(_manualBackupFilePick),
              icon: const Icon(AppIcons.fileOutline),
              label: Text(
                _label(context, ru: 'Выбрать вручную', en: 'Choose manually'),
              ),
            ),
          ],
        );
      },
    );

    if (!context.mounted || action == null) return null;
    try {
      if (identical(action, _manualBackupFilePick)) {
        return pickSafeBackupPayloadFromFile(
          dialogTitle: _label(
            context,
            ru: 'Выберите файл резервной копии Secretly',
            en: 'Choose a Secretly backup file',
          ),
        );
      }
      if (action is SafeBackupFileCandidate) {
        return readSafeBackupPayloadFromPath(action.path);
      }
    } catch (e) {
      if (!context.mounted) return null;
      _showSnack(
        context,
        _label(
          context,
          ru: 'Не удалось прочитать файл резервной копии: $e',
          en: 'Could not read backup file: $e',
        ),
      );
    }
    return null;
  }

  Future<bool> _authorizeSensitiveBackupAction(BuildContext context) {
    return ensureSecurityScopeUnlocked(
      context: context,
      controller: controller,
      scope: SecurityLockScope.app,
      forcePrompt: true,
    );
  }

  Future<int?> _pickFrequency(BuildContext context, int currentFreq) async {
    var selected = currentFreq;
    return showDialog<int>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: Text(
                _label(context, ru: 'Частота сохранения', en: 'Save Frequency'),
              ),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _freqOptionsMin
                        .map(
                          (v) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              selected == v
                                  ? AppIcons.radioChecked
                                  : AppIcons.radioUnchecked,
                            ),
                            title: Text(_freqLabel(v, context)),
                            onTap: () {
                              setLocalState(() {
                                selected = v;
                              });
                            },
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(selected),
                  child: Text(_label(context, ru: 'Сохранить', en: 'Save')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Telegram-style building blocks ─────────────────────────────────────
  // Grouped rows in a rounded card, a muted caps header above, and a short
  // explainer below. Everything the screen shows is one of these four, so the
  // page reads as a list of decisions instead of a control panel.

  Widget _sectionHeader(BuildContext context, String text) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: cs.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _group(BuildContext context, List<Widget> rows) {
    final cs = Theme.of(context).colorScheme;
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Divider(
              height: 1,
              thickness: 0.5,
              color: cs.onSurface.withValues(alpha: 0.08),
            ),
          ),
        );
      }
      children.add(rows[i]);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: ColoredBox(
        color: cs.onSurface.withValues(alpha: 0.05),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }

  Widget _footer(BuildContext context, String text) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          height: 1.35,
          color: cs.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  /// A tappable row: title on the left, current value + chevron on the right.
  Widget _row(
    BuildContext context, {
    required String title,
    String? value,
    VoidCallback? onTap,
    Color? titleColor,
    bool chevron = true,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: titleColor ?? cs.onSurface,
                ),
              ),
            ),
            if (value != null)
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: cs.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ),
            if (chevron && onTap != null)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: cs.onSurface.withValues(alpha: 0.3),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _switchRow(
    BuildContext context, {
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final cs = Theme.of(context).colorScheme;
    // The whole row toggles, not just the switch — same as every other
    // settings row in the app, and the target is far easier to hit.
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 16, color: cs.onSurface),
              ),
            ),
            Switch.adaptive(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }

  /// Подсказка о пересохранении копии, у которой нет опоры токена доступа
  /// (SEC-01). Показывается только когда копия на сервере ЕСТЬ и опоры у неё
  /// НЕТ — иначе экран молчит.
  ///
  /// Почему это нужно отдельной карточкой, а не строкой в статусе: обновление
  /// приложения опору не создаёт, она выводится из пароля в момент сохранения.
  /// Человек видит «История защищена» и не догадывается, что его архив всё ещё
  /// отдаётся по одному идентификатору профиля. Замер прода 01.09.2026:
  /// 75,8 % устройств на сборках с опорой против 18,7 % архивов с ней.
  ///
  /// Тон намеренно спокойный. Это не тревога — данные зашифрованы паролем в
  /// любом случае; это предложение включить второй рубеж, и пугать им нельзя.
  Widget _accessUpgradeNotice(BuildContext context) {
    if (!controller.serverBackupNeedsAccessUpgrade) {
      return const SizedBox.shrink();
    }
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.primary.withValues(alpha: 0.22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_reset_rounded, size: 20, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.l10n.backupAccessUpgradeTitle,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.backupAccessUpgradeBody,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: cs.onSurface.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _createServerBackupFlow(context),
                child: Text(context.l10n.backupAccessUpgradeAction),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The one honest line at the top: is this device's history protected?
  Widget _statusHeader(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final health = controller.safeBackupHealth;
    final (IconData icon, Color tint, String line) = switch (health) {
      SafeBackupHealth.ok => (
        Icons.cloud_done_rounded,
        cs.primary,
        context.l10n.backupStateProtected,
      ),
      SafeBackupHealth.off => (
        Icons.cloud_off_rounded,
        cs.onSurface.withValues(alpha: 0.4),
        context.l10n.backupStateUnprotected,
      ),
      SafeBackupHealth.failing => (
        Icons.error_outline_rounded,
        cs.error,
        context.l10n.backupStateFailing,
      ),
      SafeBackupHealth.stale => (
        Icons.cloud_queue_rounded,
        cs.onSurface.withValues(alpha: 0.55),
        context.l10n.backupStateStale,
      ),
      SafeBackupHealth.pending => (
        Icons.cloud_queue_rounded,
        cs.onSurface.withValues(alpha: 0.55),
        context.l10n.backupStateNone,
      ),
    };

    // Any successful backup counts here, not just an automatic one — a manual
    // cloud upload or device save protects the user just as much.
    final lastAuto = controller.safeBackupLastAnySuccessAtMs;
    final detail = lastAuto > 0
        ? context.l10n.backupLastAt(_formatTs(lastAuto))
        : context.l10n.backupIntroHint;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Column(
        children: [
          Icon(icon, size: 44, color: tint),
          const SizedBox(height: 12),
          Text(
            line,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  /// Replaces the two separate "upload to server" / "save on device" switches
  /// with one row, because they are one decision.
  String _destinationLabel(BuildContext context) {
    final server = controller.safeBackupAutoServerEnabled;
    final device = controller.safeBackupAutoDeviceEnabled;
    if (server && device) {
      return context.l10n.backupDestServerDevice;
    }
    if (server) return context.l10n.backupDestServer;
    if (device) return context.l10n.backupDestDevice;
    return context.l10n.backupDestNone;
  }

  Future<void> _pickDestination(BuildContext context) async {
    final options = <(bool server, bool device, String label)>[
      (
        true,
        true,
        context.l10n.backupDestServerDevice,
      ),
      (true, false, context.l10n.backupDestServerOnly),
      (false, true, context.l10n.backupDestDeviceOnly),
    ];
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < options.length; i++)
              ListTile(
                title: Text(options[i].$3),
                trailing:
                    controller.safeBackupAutoServerEnabled == options[i].$1 &&
                        controller.safeBackupAutoDeviceEnabled == options[i].$2
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(i),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await controller.setSafeBackupAutoServerEnabled(options[picked].$1);
    await controller.setSafeBackupAutoDeviceEnabled(options[picked].$2);
  }

  /// Returns true when a password is stored afterwards.
  ///
  /// When one already exists the user is asked whether to replace or remove it
  /// — removal has no row of its own, which is why the old screen needed a
  /// separate "Clear password" entry.
  Future<bool> _editAutoPassword(BuildContext context) async {
    if (!await _authorizeSensitiveBackupAction(context)) return false;
    if (!context.mounted) return false;

    if (_passwordSet ?? false) {
      final replace = await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(sheetContext.l10n.backupPasswordChange),
                onTap: () => Navigator.of(sheetContext).pop(true),
              ),
              ListTile(
                title: Text(
                  sheetContext.l10n.backupPasswordRemove,
                  style: TextStyle(
                    color: Theme.of(sheetContext).colorScheme.error,
                  ),
                ),
                onTap: () => Navigator.of(sheetContext).pop(false),
              ),
            ],
          ),
        ),
      );
      if (replace == null) return true; // dismissed — nothing changed
      if (!replace) {
        await controller.clearSafeBackupAutoPassword();
        // A stored password is what makes automatic backup possible; without
        // one it would sit enabled and silently never run.
        await controller.setSafeBackupAutoEnabled(false);
        if (mounted) setState(() => _passwordSet = false);
        return false;
      }
      if (!context.mounted) return false;
    }

    final pw = await _promptPasswordConfirm(context);
    if (pw == null) return false;
    await controller.setSafeBackupAutoPassword(pw);
    _passwordSet = true;
    if (!context.mounted) return true;
    _showSnack(context, context.l10n.backupPasswordSaved);

    // 🔴 П-5а (SEC-01, Э-1): смена пароля НЕ перешифровывает копию, которая уже
    // лежит на сервере. Без перезаливки владелец при восстановлении введёт свой
    // новый пароль и получит отказ на собственный архив — а с этапа Э-2 ещё и
    // не пройдёт проверку доступа, потому что опора считается от пароля, каким
    // архив зашифрован.
    //
    // Перезаливаем сразу и с прогрессом. Неудача не отменяет смену пароля: она
    // уже сохранена, и повторная попытка возможна кнопкой «сохранить копию».
    if (controller.hasServerBackupCopy) {
      try {
        await _withProgressDialog(
          context,
          () => controller.uploadSafeBackupToServer(password: pw),
        );
      } catch (e) {
        if (!context.mounted) return true;
        _showSnack(
          context,
          context.l10n.safeBackupUploadFailedWithError(e.toString()),
        );
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: frostedAppBar(title: Text(l10n.safeBackupTitle)),
      body: StreamBuilder<void>(
        stream: controller.changed,
        builder: (context, _) {
          final autoEnabled = controller.safeBackupAutoEnabled;
          final currentFreq =
              _freqOptionsMin.contains(controller.safeBackupAutoIntervalMin)
              ? controller.safeBackupAutoIntervalMin
              : 24 * 60;
          final lastErr = controller.safeBackupLastAutoError;

          return ListView(
            padding: EdgeInsets.fromLTRB(
              0,
              MediaQuery.of(context).padding.top + 16,
              0,
              112 + MediaQuery.of(context).padding.bottom,
            ),
            children: [
              _statusHeader(context),
              _accessUpgradeNotice(context),

              _sectionHeader(
                context,
                context.l10n.backupSectionAutomatic,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _group(context, [
                  _switchRow(
                    context,
                    title: context.l10n.backupAutoToggle,
                    value: autoEnabled,
                    onChanged: (v) async {
                      await controller.setSafeBackupAutoEnabled(v);
                      unawaited(_refreshPasswordState());
                      if (!v || !context.mounted) return;
                      if (await controller.hasSafeBackupAutoPassword()) return;
                      if (!context.mounted) return;
                      // Without a password automatic backup can never run, so
                      // refusing the prompt must switch it back off rather than
                      // leave it on and silently broken.
                      final ok = await _editAutoPassword(context);
                      if (!ok) {
                        await controller.setSafeBackupAutoEnabled(false);
                      }
                    },
                  ),
                  if (autoEnabled) ...[
                    _row(
                      context,
                      title: context.l10n.backupPassword,
                      value: (_passwordSet ?? false)
                          ? context.l10n.backupPasswordSet
                          : context.l10n.backupPasswordNotSet,
                      titleColor: (_passwordSet ?? false) ? null : cs.error,
                      onTap: () => _editAutoPassword(context),
                    ),
                    _row(
                      context,
                      title: context.l10n.backupWhere,
                      value: _destinationLabel(context),
                      onTap: () => _pickDestination(context),
                    ),
                    _row(
                      context,
                      title: context.l10n.backupHowOften,
                      value: _freqLabel(currentFreq, context),
                      onTap: () async {
                        final picked = await _pickFrequency(
                          context,
                          currentFreq,
                        );
                        if (picked == null) return;
                        await controller.setSafeBackupAutoIntervalMinutes(
                          picked,
                        );
                      },
                    ),
                    _switchRow(
                      context,
                      title: context.l10n.backupIncludeMedia,
                      value: controller.safeBackupIncludeMedia,
                      onChanged: controller.setSafeBackupIncludeMedia,
                    ),
                  ],
                ]),
              ),
              _footer(
                context,
                lastErr.isNotEmpty
                    ? lastErr
                    : context.l10n.backupAutoFooter,
              ),

              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _group(context, [
                  _row(
                    context,
                    title: context.l10n.backupNow,
                    titleColor: cs.primary,
                    chevron: false,
                    onTap: () => _createBackupFlow(context),
                  ),
                ]),
              ),

              _sectionHeader(
                context,
                context.l10n.backupSectionRestore,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _group(context, [
                  _row(
                    context,
                    title: context.l10n.backupRestoreAction,
                    onTap: () => _restoreBackupFlow(context),
                  ),
                ]),
              ),
              _footer(
                context,
                context.l10n.backupRestoreFooter,
              ),

              _sectionHeader(
                context,
                context.l10n.backupSectionKey,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _group(context, [
                  _row(
                    context,
                    title: context.l10n.backupKeyShow,
                    onTap: () => _exportRecoveryKitFlow(context),
                  ),
                  _row(
                    context,
                    title: context.l10n.backupKeyRestore,
                    onTap: () => _restoreFromRecoveryKitFlow(context),
                  ),
                ]),
              ),
              _footer(
                context,
                context.l10n.backupKeyFooter,
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatTs(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _freqLabel(int min, BuildContext context) {
    final localeTag = wave1LocaleTagFromContext(context);
    if (min < 60) {
      return wave1Text(
        context,
        ru: '$min мин',
        en: '$min min',
        uk: '$min хв',
        es: '$min min',
        pt: '$min min',
        fr: '$min min',
        de: '$min Min.',
      );
    }
    if (min % (24 * 60) == 0) {
      final d = min ~/ (24 * 60);
      if (localeTag == 'ru') {
        if (d == 1) return 'Каждый день';
        if (d % 10 >= 2 && d % 10 <= 4 && (d % 100 < 10 || d % 100 >= 20)) {
          return 'Каждые $d дня';
        }
        return 'Каждые $d дней';
      }
      if (d == 1) {
        return wave1Text(
          context,
          ru: 'Каждый день',
          en: 'Every day',
          uk: 'Щодня',
          es: 'Cada dia',
          pt: 'Todos os dias',
          fr: 'Chaque jour',
          de: 'Jeden Tag',
        );
      }
      return wave1Text(
        context,
        ru: 'Каждые $d дней',
        en: 'Every $d days',
        uk: 'Кожні $d днів',
        es: 'Cada $d dias',
        pt: 'A cada $d dias',
        fr: 'Tous les $d jours',
        de: 'Alle $d Tage',
      );
    }
    if (min % 60 == 0) {
      final h = min ~/ 60;
      if (localeTag == 'ru') {
        if (h == 1) return 'Каждый час';
        if (h % 10 >= 2 && h % 10 <= 4 && (h % 100 < 10 || h % 100 >= 20)) {
          return 'Каждые $h часа';
        }
        return 'Каждые $h часов';
      }
      if (h == 1) {
        return wave1Text(
          context,
          ru: 'Каждый час',
          en: 'Every hour',
          uk: 'Щогодини',
          es: 'Cada hora',
          pt: 'A cada hora',
          fr: 'Chaque heure',
          de: 'Jede Stunde',
        );
      }
      return wave1Text(
        context,
        ru: 'Каждые $h часов',
        en: 'Every $h hours',
        uk: 'Кожні $h год',
        es: 'Cada $h horas',
        pt: 'A cada $h horas',
        fr: 'Toutes les $h heures',
        de: 'Alle $h Stunden',
      );
    }
    return wave1Text(
      context,
      ru: '$min мин',
      en: '$min min',
      uk: '$min хв',
      es: '$min min',
      pt: '$min min',
      fr: '$min min',
      de: '$min Min.',
    );
  }

  Future<String?> _promptPasswordConfirm(BuildContext context) async {
    final l10n = context.l10n;
    final p1 = TextEditingController();
    final p2 = TextEditingController();
    final f1 = FocusNode();
    final f2 = FocusNode();

    final pw = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            final validation = BackupPasswordPolicy.validate(p1.text);
            final matches = p1.text == p2.text;
            final canSubmit = validation.isValid && matches;

            void submit() {
              if (!canSubmit) return;
              TextInput.finishAutofillContext(shouldSave: true);
              Navigator.of(context).pop(p1.text);
            }

            return AlertDialog(
              title: Text(l10n.recoveryPasswordTitle),
              content: AutofillGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: p1,
                      focusNode: f1,
                      decoration: InputDecoration(labelText: l10n.password),
                      keyboardType: TextInputType.visiblePassword,
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setLocalState(() {}),
                      onSubmitted: (_) => f2.requestFocus(),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: p2,
                      focusNode: f2,
                      decoration: InputDecoration(
                        labelText: l10n.confirmPassword,
                        errorText: p2.text.isNotEmpty && !matches
                            ? _label(
                                context,
                                ru: 'Пароли не совпадают',
                                en: 'Passwords do not match',
                              )
                            : null,
                      ),
                      keyboardType: TextInputType.visiblePassword,
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setLocalState(() {}),
                      onSubmitted: (_) => submit(),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _backupPasswordRequirementsLabel(context),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (p1.text.isNotEmpty && !validation.isValid) ...[
                      const SizedBox(height: 8),
                      Text(
                        _backupPasswordProblemText(context, validation),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: canSubmit ? submit : null,
                  child: Text(
                    _label(context, ru: 'Продолжить', en: 'Continue'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    f1.dispose();
    f2.dispose();
    p1.dispose();
    p2.dispose();

    if (pw == null || pw.isEmpty) return null;
    return pw;
  }

  Future<bool?> _restoreFromServerFlow(BuildContext context) async {
    final l10n = context.l10n;

    // ID intentionally starts empty: this flow restores from cloud, often to
    // a *different* account than the one currently signed in (or to a fresh
    // install where the local profile is just a placeholder). Pre-filling
    // `controller.profileId` was confusing — users had to manually delete the
    // wrong ID before typing their real one.
    final pidC = TextEditingController();
    final pwC = TextEditingController();
    final f1 = FocusNode();
    final f2 = FocusNode();

    final res = await showDialog<({String profileId, String password})>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.safeBackupRestoreTitle),
          content: AutofillGroup(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: pidC,
                  focusNode: f1,
                  decoration: InputDecoration(labelText: l10n.secretlyIdLabel),
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => f2.requestFocus(),
                ),
                TextField(
                  controller: pwC,
                  focusNode: f2,
                  decoration: InputDecoration(labelText: l10n.password),
                  keyboardType: TextInputType.visiblePassword,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    final pid = pidC.text.trim();
                    final pw = pwC.text;
                    if (pid.isEmpty || pw.isEmpty) return;
                    TextInput.finishAutofillContext(shouldSave: true);
                    Navigator.of(context).pop((profileId: pid, password: pw));
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final pid = pidC.text.trim();
                final pw = pwC.text;
                if (pid.isEmpty || pw.isEmpty) return;
                TextInput.finishAutofillContext(shouldSave: true);
                Navigator.of(context).pop((profileId: pid, password: pw));
              },
              child: Text(l10n.restore),
            ),
          ],
        );
      },
    );

    f1.dispose();
    f2.dispose();
    pidC.dispose();
    pwC.dispose();

    if (res == null) return null;
    if (!context.mounted) return null;

    // Fetch from server.
    final (exists, payload, _) = await _withProgressDialog(
      context,
      () => controller.backupGetFromServer(
        res.profileId,
        useDeviceAuth: false,
        // Э-1 (SEC-01): пароль введён здесь же — он и удостоверяет запрос.
        backupPassword: res.password,
      ),
    );
    if (!exists || payload == null || payload.trim().isEmpty) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SecretlySnackBar(content: Text(l10n.safeBackupNotFound)));
      return false;
    }

    if (!context.mounted) return false;
    final plain = await _decryptAndConfirmSafeBackupRestore(
      context,
      payload: payload,
      password: res.password,
    );
    if (plain == null) return false;
    if (!context.mounted) return false;

    try {
      await _withProgressDialog(
        context,
        () => controller.restoreFromSafeBackup(plain),
      );
      return true;
    } catch (e) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SecretlySnackBar(
          content: Text(_safeBackupRestoreErrorMessage(context, e)),
        ),
      );
      return false;
    }
  }

  Future<bool?> _restoreFromBackupFileFlow(BuildContext context) async {
    final payload = await _pickSafeBackupPayloadWithAutoSearch(context);
    if (!context.mounted) return false;
    if (payload == null || payload.isEmpty) return false;

    final pw = await _promptPassword(
      context,
      title: _label(
        context,
        ru: 'Пароль резервной копии',
        en: 'Backup password',
      ),
    );
    if (pw == null) return false;
    if (!context.mounted) return false;

    final plain = await _decryptAndConfirmSafeBackupRestore(
      context,
      payload: payload,
      password: pw,
    );
    if (plain == null) return false;

    try {
      await controller.restoreFromSafeBackup(plain);
      return true;
    } catch (e) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SecretlySnackBar(
          content: Text(_safeBackupRestoreErrorMessage(context, e)),
        ),
      );
      return false;
    }
  }

  Future<String?> _promptPassword(
    BuildContext context, {
    required String title,
  }) async {
    final l10n = context.l10n;
    final c = TextEditingController();
    final f = FocusNode();
    final pw = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: AutofillGroup(
            child: TextField(
              controller: c,
              focusNode: f,
              decoration: InputDecoration(labelText: l10n.password),
              keyboardType: TextInputType.visiblePassword,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                final v = c.text;
                if (v.isEmpty) return;
                TextInput.finishAutofillContext(shouldSave: true);
                Navigator.of(context).pop(v);
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final v = c.text;
                if (v.isEmpty) return;
                TextInput.finishAutofillContext(shouldSave: true);
                Navigator.of(context).pop(v);
              },
              child: Text(l10n.restore),
            ),
          ],
        );
      },
    );
    f.dispose();
    c.dispose();
    if (pw == null || pw.isEmpty) return null;
    return pw;
  }

  Future<void> _exportRecoveryKitFlow(BuildContext context) async {
    final password = await _promptPasswordConfirm(context);
    if (password == null) return;

    try {
      final payload = await controller.createRecoveryKitPayload(
        password: password,
      );
      if (!context.mounted) return;
      await Navigator.of(context).push(
        SecretlyPageRoute(builder: (_) => RecoveryKitScreen(payload: payload)),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SecretlySnackBar(content: Text(_recoveryKitExportFailedLabel(context))),
      );
    }
  }

  Future<({String payload, String password})?> _promptRecoveryKitRestoreInput(
    BuildContext context,
  ) async {
    final l10n = context.l10n;
    final payloadController = TextEditingController();
    final passwordController = TextEditingController();
    final payloadFocus = FocusNode();
    final passwordFocus = FocusNode();

    final result = await showDialog<({String payload, String password})>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            final canSubmit =
                payloadController.text.trim().isNotEmpty &&
                passwordController.text.isNotEmpty;

            void submit() {
              final payload = payloadController.text.trim();
              final password = passwordController.text;
              if (payload.isEmpty || password.isEmpty) return;
              TextInput.finishAutofillContext(shouldSave: true);
              Navigator.of(context).pop((payload: payload, password: password));
            }

            return AlertDialog(
              title: Text(l10n.restoreRecoveryKit),
              content: AutofillGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: payloadController,
                      focusNode: payloadFocus,
                      decoration: InputDecoration(labelText: l10n.recoveryKit),
                      minLines: 3,
                      maxLines: 5,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setLocalState(() {}),
                      onSubmitted: (_) => passwordFocus.requestFocus(),
                    ),
                    TextField(
                      controller: passwordController,
                      focusNode: passwordFocus,
                      decoration: InputDecoration(labelText: l10n.password),
                      keyboardType: TextInputType.visiblePassword,
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setLocalState(() {}),
                      onSubmitted: (_) => submit(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: canSubmit ? submit : null,
                  child: Text(l10n.restore),
                ),
              ],
            );
          },
        );
      },
    );

    payloadFocus.dispose();
    passwordFocus.dispose();
    payloadController.dispose();
    passwordController.dispose();
    return result;
  }

  Future<bool?> _restoreFromRecoveryKitFlow(BuildContext context) async {
    final l10n = context.l10n;
    final input = await _promptRecoveryKitRestoreInput(context);
    if (input == null) return null;
    if (!context.mounted) return false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.restoreConfirmTitle),
          content: Text(l10n.restoreConfirmBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.restore),
            ),
          ],
        );
      },
    );
    if (ok != true) return false;

    try {
      await controller.restoreFromRecoveryKitPayload(
        payload: input.payload,
        password: input.password,
      );
      return true;
    } catch (e) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SecretlySnackBar(
          content: Text(_recoveryKitRestoreErrorMessage(context, e)),
        ),
      );
      return false;
    }
  }
}
