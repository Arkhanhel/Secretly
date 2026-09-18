// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:secretly_app/ui/secretly_snackbar.dart';
import 'animations/animations.dart';

import '../app/app_controller.dart';
import 'app_asset_paths.dart';
import 'chat_screen.dart';
import 'contact_action_error_text.dart';
import 'l10n.dart';
import 'my_secretly_id_screen.dart';
import 'share_utils.dart';
import 'wave1_l10n.dart';
import 'widgets/avatar_initials.dart';
import 'widgets/content_edge_fade.dart';
import 'widgets/dismiss_keyboard_on_tap.dart';
import 'widgets/frosted_header_island.dart';
import 'widgets/glass_icon_island.dart';
import 'widgets/horizontal_quick_action_button.dart';

class NewChatPickerScreen extends StatefulWidget {
  const NewChatPickerScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<NewChatPickerScreen> createState() => _NewChatPickerScreenState();
}

class _NewChatPickerScreenState extends State<NewChatPickerScreen> {
  static const String _settingsIconsDir = AppAssetPaths.settingsIconsDir;
  static const String _inviteIconAsset = '$_settingsIconsDir/w11-invite.png';

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _shareInviteFriend(BuildContext context) async {
    await shareTextExternally(
      text: buildInviteFriendShareText(
        controller: widget.controller,
        localeTag: wave1LocaleTagFromContext(context),
      ),
    );
  }

  Future<void> _openMyQr(BuildContext context) {
    return Navigator.of(context).push(
      SecretlyPageRoute(
        builder: (_) => MySecretlyIdScreen(controller: widget.controller),
      ),
    );
  }

  Future<void> _openChat({
    required BuildContext context,
    required String profileId,
    required String title,
  }) async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      SecretlyPageRoute(
        builder: (_) => ChatScreen(
          controller: widget.controller,
          convoId: profileId,
          title: title,
          peerProfileIdForSend: profileId,
        ),
      ),
    );
  }

  /// Real photo when available, else the shared initials-on-gradient bubble
  /// (matches contacts/chats). Previously these rows used a bare transparent
  /// CircleAvatar, so every avatar looked blank.
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

  Widget _searchField(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        textInputAction: TextInputAction.search,
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        decoration: InputDecoration(
          hintText: l10n.queryLabel,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _query.trim().isEmpty
              ? null
              : IconButton(
                  tooltip: l10n.cancel,
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onChanged: (v) => setState(() => _query = v),
      ),
    );
  }

  Widget _quickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      child: Row(
        children: [
          Expanded(
            child: HorizontalQuickActionButton(
              assetPath: _inviteIconAsset,
              fallbackIcon: Icons.share_rounded,
              iconTint: const Color(0xFF2092E7),
              title: wave1Text(
                context,
                ru: 'Пригласить друга',
                en: 'Invite a friend',
                uk: 'Запросити друга',
                es: 'Invitar a un amigo',
                pt: 'Convidar um amigo',
                fr: 'Inviter un ami',
                de: 'Freund einladen',
              ),
              onTap: () => _shareInviteFriend(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: HorizontalQuickActionButton(
              icon: Icons.qr_code_2_rounded,
              iconTint: const Color(0xFF2DBE4C),
              title: wave1Text(
                context,
                ru: 'QR-код',
                en: 'QR code',
                uk: 'QR-код',
                es: 'Código QR',
                pt: 'Código QR',
                ptBr: 'Código QR',
                fr: 'Code QR',
                de: 'QR-Code',
              ),
              onTap: () => _openMyQr(context),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final q = _query.trim();
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: Stack(
          // Let the top fade overflow upward behind the status bar.
          clipBehavior: Clip.none,
          children: [
            DismissKeyboardOnTap(
              child: Column(
                children: [
                  const SizedBox(height: 56),
                  _quickActions(context),
                  _searchField(context),
                  Expanded(
                    // No content edge fade here: the list sits in a Column
                    // BELOW the header islands (it does not scroll under them)
                    // and this pushed screen has no bottom shading — a top fade
                    // would just dim the first rows under the search field.
                    // (ContentEdgeFade(0,0) returns the child unchanged; kept
                    // wrapped so it's trivial to re-enable.)
                    child: ContentEdgeFade(
                      topFadeEndPx: 0.0,
                      bottomFadeFraction: 0.0,
                      child: FutureBuilder<List<Contact>>(
                        future: widget.controller.listContacts(),
                        builder: (context, snapshot) {
                          final contacts = snapshot.data ?? const <Contact>[];
                          final contactsFiltered = q.isEmpty
                              ? contacts
                              : contacts
                                    .where((c) {
                                      final idHit = c.profileId
                                          .toLowerCase()
                                          .contains(q.toLowerCase());
                                      final nick = (c.displayName ?? '').trim();
                                      final nickHit = nick
                                          .toLowerCase()
                                          .contains(q.toLowerCase());
                                      return idHit || nickHit;
                                    })
                                    .toList(growable: false);

                          if (q.isEmpty) {
                            if (contacts.isEmpty) {
                              return Center(child: Text(l10n.noContactsYet));
                            }
                            return ListView.separated(
                              padding: EdgeInsets.zero,
                              itemCount: contacts.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final c = contacts[i];
                                final baseTitle =
                                    (c.displayName != null &&
                                        c.displayName!.trim().isNotEmpty)
                                    ? c.displayName!.trim()
                                    : c.profileId;
                                final title =
                                    (c.emoji != null && c.emoji!.isNotEmpty)
                                    ? '$baseTitle ${c.emoji!}'
                                    : baseTitle;
                                return ListTile(
                                  leading: _avatarFor(
                                    seed: c.profileId,
                                    title: baseTitle,
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
                                  onTap: () => _openChat(
                                    context: context,
                                    profileId: c.profileId,
                                    title: title,
                                  ),
                                );
                              },
                            );
                          }

                          return FutureBuilder<List<UserLookupResult>>(
                            future: widget.controller.lookupUsers(q),
                            builder: (context, remoteSnap) {
                              final remote =
                                  remoteSnap.data ?? const <UserLookupResult>[];
                              final remoteOnly = remote
                                  .where(
                                    (r) => !contacts.any(
                                      (c) => c.profileId == r.profileId,
                                    ),
                                  )
                                  .toList(growable: false);
                              final remoteError = remoteSnap.error;

                              if (contactsFiltered.isEmpty &&
                                  remoteOnly.isEmpty &&
                                  remoteSnap.connectionState !=
                                      ConnectionState.waiting) {
                                if (remoteError != null) {
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Text(
                                        contactLookupErrorText(
                                          l10n,
                                          remoteError,
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                return Center(child: Text(l10n.noMatches));
                              }

                              final total =
                                  contactsFiltered.length + remoteOnly.length;
                              return ListView.separated(
                                padding: EdgeInsets.zero,
                                itemCount: total,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, i) {
                                  if (i < contactsFiltered.length) {
                                    final c = contactsFiltered[i];
                                    final baseTitle =
                                        (c.displayName != null &&
                                            c.displayName!.trim().isNotEmpty)
                                        ? c.displayName!.trim()
                                        : c.profileId;
                                    final title =
                                        (c.emoji != null && c.emoji!.isNotEmpty)
                                        ? '$baseTitle ${c.emoji!}'
                                        : baseTitle;
                                    return ListTile(
                                      leading: _avatarFor(
                                        seed: c.profileId,
                                        title: baseTitle,
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
                                      onTap: () => _openChat(
                                        context: context,
                                        profileId: c.profileId,
                                        title: title,
                                      ),
                                    );
                                  }

                                  final r =
                                      remoteOnly[i - contactsFiltered.length];
                                  final title =
                                      (r.nickname != null &&
                                          r.nickname!.trim().isNotEmpty)
                                      ? r.nickname!.trim()
                                      : r.profileId;
                                  return ListTile(
                                    leading: _avatarFor(
                                      seed: r.profileId,
                                      title: title,
                                    ),
                                    title: Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      r.profileId,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: r.alreadyInContacts
                                        ? FilledButton.tonal(
                                            onPressed: () => _openChat(
                                              context: context,
                                              profileId: r.profileId,
                                              title: title,
                                            ),
                                            child: Text(
                                              l10n.contactDetailsChat,
                                            ),
                                          )
                                        : FilledButton(
                                            onPressed: () async {
                                              try {
                                                await widget.controller
                                                    .addContact(
                                                      profileId: r.profileId,
                                                      displayName:
                                                          (r.nickname != null &&
                                                              r.nickname!
                                                                  .trim()
                                                                  .isNotEmpty)
                                                          ? r.nickname!.trim()
                                                          : null,
                                                    );
                                              } catch (e) {
                                                if (!context.mounted) return;
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SecretlySnackBar(
                                                    content: Text(
                                                      contactActionErrorText(
                                                        l10n,
                                                        e,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                                return;
                                              }
                                              if (!context.mounted) return;
                                              await _openChat(
                                                context: context,
                                                profileId: r.profileId,
                                                title: title,
                                              );
                                            },
                                            child: Text(l10n.add),
                                          ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
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
              right: 12,
              child: Row(
                children: [
                  GlassIconIsland(
                    icon: Icons.arrow_back_ios_new,
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.newChat,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
