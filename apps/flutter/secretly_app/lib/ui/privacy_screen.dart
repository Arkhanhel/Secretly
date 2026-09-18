// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/material.dart';
import 'package:secretly_app/ui/secretly_snackbar.dart';

import '../app/app_controller.dart';
import 'contact_action_error_text.dart';
import 'icons/app_icons.dart';
import 'l10n.dart';
import 'wave1_l10n.dart';
import 'widgets/frosted_top_bar.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: frostedAppBar(title: Text(l10n.privacyTitle)),
      body: StreamBuilder<void>(
        stream: controller.changed,
        builder: (context, _) {
          return FutureBuilder<(List<String>, List<Contact>)>(
            future: Future.wait<dynamic>([
              controller.listBlockedProfiles(),
              controller.listContacts(),
            ]).then((v) => ((v[0] as List<String>), (v[1] as List<Contact>))),
            builder: (context, snapshot) {
              final blocked = snapshot.data?.$1 ?? const <String>[];
              final contacts = snapshot.data?.$2 ?? const <Contact>[];
              return ListView(
                children: [
                  ListTile(
                    title: Text(
                      wave1Text(
                        context,
                        ru: 'Разрешения звонков по контактам',
                        en: 'Per-contact call permissions',
                        uk: 'Дозволи дзвінків для контактів',
                        es: 'Permisos de llamadas por contacto',
                        pt: 'Permissoes de chamadas por contacto',
                        ptBr: 'Permissoes de chamadas por contato',
                        fr: 'Autorisations d appel par contact',
                        de: 'Anrufberechtigungen pro Kontakt',
                      ),
                    ),
                    subtitle: Text(
                      wave1Text(
                        context,
                        ru: 'Отключайте звонки для отдельных контактов',
                        en: 'Disable calls for individual contacts',
                        uk: 'Вимикайте дзвінки для окремих контактів',
                        es: 'Desactiva llamadas para contactos concretos',
                        pt: 'Desative chamadas para contactos especificos',
                        ptBr: 'Desative chamadas para contatos especificos',
                        fr: 'Desactivez les appels pour certains contacts',
                        de: 'Anrufe fur einzelne Kontakte deaktivieren',
                      ),
                    ),
                  ),
                  if (contacts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        wave1Text(
                          context,
                          ru: 'Контакты не добавлены',
                          en: 'No contacts yet',
                          uk: 'Контакти ще не додані',
                          es: 'Aun no hay contactos',
                          pt: 'Ainda nao ha contactos',
                          ptBr: 'Ainda nao ha contatos',
                          fr: 'Aucun contact pour le moment',
                          de: 'Noch keine Kontakte',
                        ),
                      ),
                    )
                  else
                    ...contacts.map(
                      (c) => FutureBuilder<bool>(
                        future: controller.isContactCallsAllowed(c.profileId),
                        builder: (context, permissionSnap) {
                          final allowed = permissionSnap.data ?? true;
                          final title = (c.displayName ?? '').trim().isEmpty
                              ? c.profileId
                              : c.displayName!.trim();
                          return SwitchListTile.adaptive(
                            value: allowed,
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
                            onChanged: (v) async {
                              try {
                                await controller.setContactCallsAllowed(
                                  profileId: c.profileId,
                                  allowed: v,
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SecretlySnackBar(
                                    content: Text(
                                      contactActionErrorText(
                                        context.l10n,
                                        e,
                                      ),
                                    ),
                                  ),
                                );
                              }
                            },
                          );
                        },
                      ),
                    ),
                  const Divider(height: 24),
                  ListTile(
                    title: Text(l10n.blockedUsers),
                    subtitle: Text(l10n.blockedUsersSubtitle),
                  ),
                  const Divider(height: 1),
                  if (blocked.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(l10n.noBlockedUsers),
                    )
                  else
                    ...blocked.map(
                      (pid) => ListTile(
                        leading: const Icon(AppIcons.block),
                        title: Text(
                          pid,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: TextButton(
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: Text(l10n.unblockUserConfirmTitle),
                                  content: Text(pid),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: Text(l10n.cancel),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      child: Text(l10n.unblock),
                                    ),
                                  ],
                                );
                              },
                            );
                            if (ok != true) return;
                            try {
                              await controller.setProfileBlocked(
                                profileId: pid,
                                blocked: false,
                                deleteChatHistory: false,
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SecretlySnackBar(
                                  content: Text(
                                    contactActionErrorText(l10n, e),
                                  ),
                                ),
                              );
                            }
                          },
                          child: Text(l10n.unblock),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
