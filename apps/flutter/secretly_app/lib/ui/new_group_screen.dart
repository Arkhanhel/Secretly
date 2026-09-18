// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:secretly_app/ui/secretly_snackbar.dart';

import '../app/app_controller.dart';
import '../entitlements/feature_gate.dart';
import 'paywall_screen.dart';
import '../billing/show_paywall.dart';
import 'room_policy_error_text.dart';
import 'icons/app_icons.dart';
import 'l10n.dart';
import 'wave1_l10n.dart';
import 'widgets/avatar_initials.dart';
import 'widgets/content_edge_fade.dart';
import 'widgets/frosted_header_island.dart';
import 'widgets/glass_icon_island.dart';

class NewGroupScreen extends StatefulWidget {
  const NewGroupScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<NewGroupScreen> createState() => _NewGroupScreenState();
}

class _NewGroupScreenState extends State<NewGroupScreen> {
  final TextEditingController _title = TextEditingController();
  final Set<String> _selected = <String>{};
  int? _autoDeleteSeconds;
  bool _saving = false;

  String _t({
    required String ru,
    required String en,
    String? uk,
    String? es,
    String? pt,
    String? ptBr,
    String? fr,
    String? de,
  }) {
    return wave1Text(
      context,
      ru: ru,
      en: en,
      uk: uk,
      es: es,
      pt: pt,
      ptBr: ptBr,
      fr: fr,
      de: de,
    );
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_saving) return;
    final ids = _selected.toList(growable: false);
    final defaultTitle = _newRoomLabel();
    final createFailedText = _t(
      ru: 'Не удалось создать комнату.',
      en: 'Could not create the room.',
      uk: 'Не вдалося створити кімнату.',
      es: 'No se pudo crear la sala.',
      pt: 'Nao foi possivel criar a sala.',
      ptBr: 'Nao foi possivel criar a sala.',
      fr: 'Impossible de créer le salon.',
      de: 'Raum konnte nicht erstellt werden.',
    );
    setState(() => _saving = true);
    try {
      final gid = await widget.controller.createGroup(
        title: _title.text.trim().isEmpty ? defaultTitle : _title.text.trim(),
        memberProfileIds: ids,
        autoDeleteSeconds: _autoDeleteSeconds,
      );
      if (!mounted) return;
      Navigator.of(context).pop(gid);
    } on FeatureLockedException {
      // Free profile hit the group-creation cap — show the paywall instead of
      // an error. No group was created (the gate runs before any side effects).
      if (!mounted) return;
      await showPaywall(context, PaywallTrigger.group);
      return;
    } catch (error) {
      if (!mounted) return;
      final l10n = context.l10n;
      final roomPolicyText = tryRoomPolicyErrorText(l10n, error);
      final base = createFailedText;
      final details = error.toString().trim();
      final message =
          roomPolicyText ??
          (details.isEmpty || details == base ? base : '$base $details');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SecretlySnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _creationSummaryTitle(int selectedCount) {
    if (selectedCount <= 0) {
      return _t(
        ru: 'Можно создать комнату сразу',
        en: 'You can create the room now',
        uk: 'Можна створити кімнату зараз',
        es: 'Puedes crear la sala ahora',
        pt: 'Voce pode criar a sala agora',
        ptBr: 'Voce pode criar a sala agora',
        fr: 'Vous pouvez créer le salon maintenant',
        de: 'Sie können den Raum jetzt erstellen',
      );
    }
    return _t(
      ru: 'Выбрано $selectedCount участник${_pluralRu(selectedCount)}',
      en: '$selectedCount participant${selectedCount == 1 ? '' : 's'} selected',
      uk: 'Вибрано учасників: $selectedCount',
      es: '$selectedCount participante${selectedCount == 1 ? '' : 's'} seleccionado${selectedCount == 1 ? '' : 's'}',
      pt: '$selectedCount participante${selectedCount == 1 ? '' : 's'} selecionado${selectedCount == 1 ? '' : 's'}',
      ptBr:
          '$selectedCount participante${selectedCount == 1 ? '' : 's'} selecionado${selectedCount == 1 ? '' : 's'}',
      fr: '$selectedCount participant${selectedCount == 1 ? '' : 's'} sélectionné${selectedCount == 1 ? '' : 's'}',
      de: '$selectedCount Teilnehmer ausgewählt',
    );
  }

  String _creationSummaryBody(int selectedCount) {
    if (selectedCount <= 0) {
      return _t(
        ru: 'Комната создастся для вас, а участников можно добавить позже из профиля комнаты.',
        en: 'The room will be created for you now, and participants can be added later from the room profile.',
        uk: 'Кімнату буде створено для вас, а учасників можна додати пізніше з профілю кімнати.',
        es: 'La sala se creara para ti ahora y podras anadir participantes despues desde el perfil de la sala.',
        pt: 'A sala sera criada para voce agora, e participantes poderao ser adicionados depois pelo perfil da sala.',
        ptBr:
            'A sala sera criada para voce agora, e participantes poderao ser adicionados depois pelo perfil da sala.',
        fr: 'Le salon sera créé pour vous maintenant, et vous pourrez ajouter des participants plus tard depuis le profil du salon.',
        de: 'Der Raum wird jetzt für Sie erstellt. Teilnehmer können später im Raumprofil hinzugefügt werden.',
      );
    }
    return _t(
      ru: 'Эти участники будут добавлены в комнату сразу после создания.',
      en: 'These participants will be added to the room immediately after creation.',
      uk: 'Цих учасників буде додано до кімнати одразу після створення.',
      es: 'Estos participantes se anadiran a la sala justo despues de crearla.',
      pt: 'Estes participantes serao adicionados a sala logo apos a criacao.',
      ptBr: 'Estes participantes serao adicionados a sala logo apos a criacao.',
      fr: 'Ces participants seront ajoutés au salon juste après sa création.',
      de: 'Diese Teilnehmer werden direkt nach dem Erstellen zum Raum hinzugefügt.',
    );
  }

  String _newRoomLabel() {
    return _t(
      ru: 'Новая комната',
      en: 'New room',
      uk: 'Нова кімната',
      es: 'Nueva sala',
      pt: 'Nova sala',
      fr: 'Nouveau salon',
      de: 'Neuer Raum',
    );
  }

  String _pluralRu(int value) {
    final mod10 = value % 10;
    final mod100 = value % 100;
    if (mod10 == 1 && mod100 != 11) return '';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) {
      return 'а';
    }
    return 'ов';
  }

  /// Real photo when available, else the shared initials-on-gradient bubble.
  Widget _avatarFor({
    required String seed,
    required String title,
    String? avatarPath,
  }) {
    final path = avatarPath?.trim();
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      return CircleAvatar(radius: 22, backgroundImage: FileImage(File(path)));
    }
    return AvatarInitials.fallbackBubble(
      context: context,
      radius: 22,
      seed: seed.isNotEmpty ? seed : title,
      displayName: title,
      fallbackId: seed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selectedCount = _selected.length;
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: Stack(
          // Let the top fade overflow upward behind the status bar.
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                const SizedBox(height: 56),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                  child: FrostedHeaderIsland(
                    radius: 16,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 2,
                    ),
                    child: TextField(
                      controller: _title,
                      decoration: InputDecoration(
                        hintText: _t(
                          ru: 'Название комнаты',
                          en: 'Room name',
                          uk: 'Назва кімнати',
                          es: 'Nombre de la sala',
                          pt: 'Nome da sala',
                          fr: 'Nom du salon',
                          de: 'Raumname',
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: FrostedHeaderIsland(
                    radius: 16,
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      leading: const Icon(AppIcons.timer),
                      title: Text(
                        _t(
                          ru: 'Автоудаление сообщений',
                          en: 'Messages auto-delete',
                          uk: 'Автовидалення повідомлень',
                          es: 'Autoeliminacion de mensajes',
                          pt: 'Autoexclusao de mensagens',
                          ptBr: 'Autoexclusao de mensagens',
                          fr: 'Suppression automatique des messages',
                          de: 'Automatisches Löschen von Nachrichten',
                        ),
                      ),
                      trailing: Text(_autoDeleteLabel(_autoDeleteSeconds)),
                      onTap: _showAutoDeletePicker,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: FrostedHeaderIsland(
                    radius: 16,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          selectedCount > 0
                              ? AppIcons.checkCircleSolid
                              : AppIcons.groupOutline,
                          color: selectedCount > 0
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _creationSummaryTitle(selectedCount),
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _creationSummaryBody(selectedCount),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      height: 1.35,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  // No content edge fade here: the list sits in a Column BELOW
                  // the header islands (it does not scroll under them), this
                  // pushed screen has no bottom shading, and a pinned "Create"
                  // button sits below the list — a top fade would just dim the
                  // first rows under the search field. (ContentEdgeFade(0,0)
                  // returns the child unchanged; kept wrapped to re-enable easily.)
                  child: ContentEdgeFade(
                    topFadeEndPx: 0.0,
                    bottomFadeFraction: 0.0,
                    child: FutureBuilder<List<Contact>>(
                      future: widget.controller.listContacts(),
                      builder: (context, snapshot) {
                        final contacts = (snapshot.data ?? const <Contact>[])
                            .where(
                              (contact) => !widget.controller
                                  .isSavedMessagesConvo(contact.profileId),
                            )
                            .toList(growable: false);
                        if (contacts.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    AppIcons.groupOutline,
                                    size: 34,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    l10n.noContactsYet,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _t(
                                      ru: 'Комнату всё равно можно создать сейчас и добавить участников позже.',
                                      en: 'You can still create the room now and add participants later.',
                                      uk: 'Кімнату все одно можна створити зараз і додати учасників пізніше.',
                                      es: 'Puedes crear la sala ahora y anadir participantes despues.',
                                      pt: 'Voce ainda pode criar a sala agora e adicionar participantes depois.',
                                      ptBr:
                                          'Voce ainda pode criar a sala agora e adicionar participantes depois.',
                                      fr: 'Vous pouvez quand même créer le salon maintenant et ajouter des participants plus tard.',
                                      de: 'Sie können den Raum jetzt erstellen und Teilnehmer später hinzufügen.',
                                    ),
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                          height: 1.35,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: contacts.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final c = contacts[i];
                            final title =
                                (c.displayName != null &&
                                    c.displayName!.trim().isNotEmpty)
                                ? c.displayName!.trim()
                                : c.profileId;
                            final selected = _selected.contains(c.profileId);
                            return ListTile(
                              leading: _avatarFor(
                                seed: c.profileId,
                                title: title,
                                avatarPath: c.avatarPath,
                              ),
                              title: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                c.profileId,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Icon(
                                selected
                                    ? AppIcons.checkCircleSolid
                                    : AppIcons.circleOutline,
                              ),
                              onTap: () {
                                setState(() {
                                  if (selected) {
                                    _selected.remove(c.profileId);
                                  } else {
                                    _selected.add(c.profileId);
                                  }
                                });
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _create,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _t(
                                  ru: 'Создать комнату',
                                  en: 'Create',
                                  uk: 'Створити кімнату',
                                  es: 'Crear sala',
                                  pt: 'Criar sala',
                                  fr: 'Créer le salon',
                                  de: 'Raum erstellen',
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              // Start at the very top of the screen (behind the status bar),
              // not at the SafeArea inset, so the shade covers the system bar.
              top: -MediaQuery.of(context).padding.top,
              left: 0,
              right: 0,
              child: SystemTopFadeLayer(
                height: MediaQuery.of(context).padding.top + 60,
                blurSigma: 20,
              ),
            ),
            Positioned(
              top: 4,
              left: 12,
              child: GlassIconIsland(
                icon: Icons.arrow_back_ios_new,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
            Positioned(
              top: 4,
              left: 64,
              right: 64,
              child: SizedBox(
                height: 44,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _newRoomLabel(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAutoDeletePicker() async {
    final options = <({int? secs, String label})>[
      (secs: null, label: _autoDeleteLabel(null)),
      (secs: 24 * 60 * 60, label: _autoDeleteLabel(24 * 60 * 60)),
      (secs: 7 * 24 * 60 * 60, label: _autoDeleteLabel(7 * 24 * 60 * 60)),
      (secs: 30 * 24 * 60 * 60, label: _autoDeleteLabel(30 * 24 * 60 * 60)),
    ];

    final selected = await showDialog<int?>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(
          _t(
            ru: 'Автоудаление',
            en: 'Auto-delete',
            uk: 'Автовидалення',
            es: 'Autoeliminacion',
            pt: 'Autoexclusao',
            ptBr: 'Autoexclusao',
            fr: 'Suppression automatique',
            de: 'Automatisch löschen',
          ),
        ),
        children: [
          for (final option in options)
            ListTile(
              leading: Icon(
                _autoDeleteSeconds == option.secs
                    ? AppIcons.radioChecked
                    : AppIcons.radioUnchecked,
              ),
              title: Text(option.label),
              onTap: () => Navigator.of(context).pop(option.secs),
            ),
        ],
      ),
    );
    if (selected == null && _autoDeleteSeconds == null) return;
    if (!mounted) return;
    setState(() {
      _autoDeleteSeconds = selected;
    });
  }

  String _autoDeleteLabel(int? seconds) {
    if (seconds == null || seconds <= 0) {
      return _t(
        ru: 'Выкл.',
        en: 'Off',
        uk: 'Вимк.',
        es: 'Desactivado',
        pt: 'Desativado',
        fr: 'Désactivé',
        de: 'Aus',
      );
    }
    if (seconds == 24 * 60 * 60) {
      return _t(
        ru: '1 день',
        en: '1 day',
        uk: '1 день',
        es: '1 dia',
        pt: '1 dia',
        fr: '1 jour',
        de: '1 Tag',
      );
    }
    if (seconds == 7 * 24 * 60 * 60) {
      return _t(
        ru: '7 дней',
        en: '7 days',
        uk: '7 днів',
        es: '7 dias',
        pt: '7 dias',
        fr: '7 jours',
        de: '7 Tage',
      );
    }
    if (seconds == 30 * 24 * 60 * 60) {
      return _t(
        ru: '30 дней',
        en: '30 days',
        uk: '30 днів',
        es: '30 dias',
        pt: '30 dias',
        fr: '30 jours',
        de: '30 Tage',
      );
    }
    final days = (seconds / (24 * 60 * 60)).round();
    return _t(
      ru: '$days дн.',
      en: '${days}d',
      uk: '$days дн.',
      es: '${days}d',
      pt: '${days}d',
      fr: '${days}j',
      de: '${days}T',
    );
  }
}
