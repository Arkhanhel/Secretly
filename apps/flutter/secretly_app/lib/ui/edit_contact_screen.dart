// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:secretly_app/ui/secretly_snackbar.dart';
import 'package:image_picker/image_picker.dart';

import '../app/app_controller.dart';
import 'animations/animations.dart';
import 'cover_crop_screen.dart';
import 'icons/app_icons.dart';
import 'l10n.dart';
import 'motion/app_dialogs.dart';
import 'profile_icon_picker_screen.dart';
import 'wave1_l10n.dart';
import 'widgets/frosted_top_bar.dart';
import 'widgets/secretly_glass_sheet.dart';
import 'package:secretly_app/ui/apple_controls.dart';
import 'package:secretly_app/ui/apple_glass.dart';
import 'settings_group.dart';

String _editContactText(
  BuildContext context, {
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

class EditContactScreen extends StatefulWidget {
  const EditContactScreen({
    super.key,
    required this.controller,
    required this.profileId,
    required this.initialName,
    required this.initialEmoji,
    required this.initialAvatarPath,
  });

  final AppController controller;
  final String profileId;
  final String initialName;
  final String? initialEmoji;
  final String? initialAvatarPath;

  @override
  State<EditContactScreen> createState() => _EditContactScreenState();
}

class _EditContactScreenState extends State<EditContactScreen> {
  late final TextEditingController _name;
  String? _emoji;
  String? _avatarPath;
  bool _saving = false;
  bool _updatingPhoto = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName);
    _emoji = widget.initialEmoji;
    _avatarPath = widget.initialAvatarPath;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _updatingPhoto) return;
    setState(() => _saving = true);
    try {
      final cleaned = _name.text.trim();
      await widget.controller.renameContact(
        profileId: widget.profileId,
        displayName: cleaned.isEmpty ? null : cleaned,
      );
      await widget.controller.setContactEmoji(
        profileId: widget.profileId,
        emoji: _emoji,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setPhoto() async {
    if (_updatingPhoto) return;
    final selected = await showModalBottomSheet<String>(
  sheetAnimationStyle: appSheetAnimationStyle,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // Во всю ширину и до низа экрана; отступ под системную панель переехал
        // в содержимое, поверхность уходит за неё.
        final safeBottom = MediaQuery.paddingOf(context).bottom;
        return SecretlyGlassSheetSurface(
          flushToEdges: true,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + safeBottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: SecretlyGlassSheetHandle()),
                const SizedBox(height: 14),
                Text(
                  _editContactText(
                    context,
                    ru: 'Фото контакта',
                    en: 'Contact photo',
                    uk: 'Фото контакту',
                    es: 'Foto del contacto',
                    pt: 'Foto do contacto',
                    ptBr: 'Foto do contato',
                    fr: 'Photo du contact',
                    de: 'Kontaktfoto',
                  ),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(AppIcons.photo),
                  title: Text(
                    _editContactText(
                      context,
                      ru: 'Открыть галерею',
                      en: 'Open gallery',
                    ),
                  ),
                  onTap: () => Navigator.of(context).pop('gallery'),
                ),
                if (Platform.isAndroid || Platform.isIOS)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(AppIcons.camera),
                    title: Text(
                      _editContactText(
                        context,
                        ru: 'Снять на камеру',
                        en: 'Use camera',
                        uk: 'Зняти камерою',
                        es: 'Usar cámara',
                        pt: 'Usar câmara',
                        fr: 'Utiliser l’appareil photo',
                        de: 'Kamera verwenden',
                      ),
                    ),
                    onTap: () => Navigator.of(context).pop('camera'),
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(AppIcons.profile),
                  title: Text(
                    _editContactText(
                      context,
                      ru: 'Выбрать иконку',
                      en: 'Choose icon',
                      uk: 'Вибрати іконку',
                      es: 'Elegir icono',
                      pt: 'Escolher ícone',
                      fr: 'Choisir une icône',
                      de: 'Symbol auswählen',
                    ),
                  ),
                  onTap: () => Navigator.of(context).pop('icon'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null) return;
    if (!mounted) return;
    if (selected == 'icon') {
      await _pickIcon();
      return;
    }

    setState(() => _updatingPhoto = true);
    try {
      Uint8List? pickedBytes;
      if (selected == 'gallery') {
        final picked = await FilePicker.platform.pickFiles(
          withData: true,
          type: FileType.custom,
          allowedExtensions: const [
            'jpg',
            'jpeg',
            'png',
            'webp',
            'heic',
            'heif',
          ],
        );
        pickedBytes = picked?.files.single.bytes;
      } else if (selected == 'camera') {
        final shot = await ImagePicker().pickImage(
          source: ImageSource.camera,
          maxWidth: 2048,
          maxHeight: 2048,
        );
        if (shot != null) pickedBytes = await shot.readAsBytes();
      }
      if (pickedBytes == null || pickedBytes.isEmpty) return;
      if (!mounted) return;
      // FIX (2026-07-13): let the user position the photo in the circle over the
      // FULL image (not a forced centre-square) before saving — the same crop UX
      // as own profile + room avatars, now applied to a contact's photo too.
      final croppedBytes = await cropCircleAvatarBytes(
        context,
        pickedBytes,
        title: _editContactText(
          context,
          ru: 'Подгоните фото',
          en: 'Adjust photo',
          uk: 'Підлаштуйте фото',
          es: 'Ajusta la foto',
          pt: 'Ajuste a foto',
          fr: 'Ajustez la photo',
          de: 'Foto anpassen',
        ),
      );
      if (croppedBytes == null || croppedBytes.isEmpty) return;
      await widget.controller.setContactAvatarFromImageBytes(
        profileId: widget.profileId,
        bytes: croppedBytes,
      );
      await _refreshContactAvatar();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SecretlySnackBar(
          content: Text(
            _editContactText(
              context,
              ru: 'Не удалось установить фото: $error',
              en: 'Could not set photo: $error',
              uk: 'Не вдалося встановити фото: $error',
              es: 'No se pudo establecer la foto: $error',
              pt: 'Não foi possível definir a foto: $error',
              fr: 'Impossible de définir la photo : $error',
              de: 'Foto konnte nicht festgelegt werden: $error',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _updatingPhoto = false);
    }
  }

  Future<void> _refreshContactAvatar() async {
    final contacts = await widget.controller.listContacts();
    if (!mounted) return;
    final updated = contacts
        .where((c) => c.profileId == widget.profileId)
        .cast<Contact?>()
        .firstOrNull;
    setState(() => _avatarPath = updated?.avatarPath);
  }

  Future<void> _pickIcon() async {
    setState(() => _updatingPhoto = true);
    try {
      final applied = await Navigator.of(context).push<bool>(
        SecretlyPageRoute(
          builder: (_) => ProfileIconPickerScreen(
            controller: widget.controller,
            // Contact icons are a local label cosmetic — premium icons stay free
            // here even for free users (only own-profile / room icons are gated).
            gatePremium: false,
            title: _editContactText(
              context,
              ru: 'Иконка контакта',
              en: 'Contact icon',
              uk: 'Іконка контакту',
              es: 'Icono del contacto',
              pt: 'Ícone do contacto',
              ptBr: 'Ícone do contato',
              fr: 'Icône du contact',
              de: 'Kontaktsymbol',
            ),
            applyButtonLabel: _editContactText(
              context,
              ru: 'Использовать',
              en: 'Use icon',
              uk: 'Використати',
              es: 'Usar icono',
              pt: 'Usar ícone',
              fr: 'Utiliser l’icône',
              de: 'Symbol verwenden',
            ),
            onApplySelection: (selection) async {
              final iconBytes = selection.iconBytes;
              final bytes = iconBytes != null
                  ? await widget.controller.buildAvatarBytesFromIconBytes(
                      iconBytes: iconBytes,
                      gradientStartArgb: selection.gradientStartArgb,
                      gradientEndArgb: selection.gradientEndArgb,
                      iconScale: selection.iconScale,
                      debugLabel: selection.assetPath,
                    )
                  : await widget.controller.buildAvatarBytesFromIconAsset(
                      assetPath: selection.assetPath,
                      gradientStartArgb: selection.gradientStartArgb,
                      gradientEndArgb: selection.gradientEndArgb,
                      iconScale: selection.iconScale,
                    );
              await widget.controller.setContactAvatarFromImageBytes(
                profileId: widget.profileId,
                bytes: bytes,
              );
            },
          ),
        ),
      );
      if (applied == true) {
        await _refreshContactAvatar();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SecretlySnackBar(
          content: Text(
            _editContactText(
              context,
              ru: 'Не удалось установить иконку: $error',
              en: 'Could not set icon: $error',
              uk: 'Не вдалося встановити іконку: $error',
              es: 'No se pudo establecer el icono: $error',
              pt: 'Não foi possível definir o ícone: $error',
              fr: 'Impossible de définir l’icône : $error',
              de: 'Symbol konnte nicht festgelegt werden: $error',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _updatingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasAvatar =
        _avatarPath != null &&
        _avatarPath!.isNotEmpty &&
        File(_avatarPath!).existsSync();
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight + 12;
    final photoSubtitle = hasAvatar
        ? _editContactText(context, ru: 'Фото установлено', en: 'Photo set')
        : _editContactText(
            context,
            ru: 'Камера, галерея или иконка',
            en: 'Camera, gallery, or icon',
            uk: 'Камера, галерея або іконка',
            es: 'Cámara, galería o icono',
            pt: 'Camara, galeria ou ícone',
            fr: 'Appareil photo, galerie ou icône',
            de: 'Kamera, Galerie oder Symbol',
          );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: frostedAppBar(
        title: Text(l10n.contactEditTitle),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: SecretlySpinner(strokeWidth: 2),
                  )
                : Text(l10n.contactEditDone),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(12, topInset, 12, 20),
        children: [
          _EditContactBlock(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundImage: hasAvatar
                          ? FileImage(File(_avatarPath!))
                          : null,
                      child: hasAvatar
                          ? null
                          : const Icon(AppIcons.personOutline),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.profileId,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.contactDetailsStatusRecently,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: l10n.contactEditNameLabel,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _EditContactBlock(
            rows: true,
            child: Column(
              children: [
                ListTile(
                  // Android: цветной квадрат, как у строк настроек.
                  leading: settingsRowLeading(
                    icon: AppIcons.addPhoto,
                    tint: SettingsRowTint.blue,
                    fallback: const Icon(AppIcons.addPhoto),
                  ),
                  title: Text(l10n.contactEditSetPhoto),
                  subtitle: Text(photoSubtitle),
                  trailing: _updatingPhoto
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: SecretlySpinner(strokeWidth: 2),
                        )
                      : null,
                  onTap: _updatingPhoto ? null : _setPhoto,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _EditContactBlock(
            rows: true,
            child: ListTile(
              leading: settingsRowLeading(
                icon: AppIcons.delete,
                tint: SettingsRowTint.red,
                fallback: Icon(
                  AppIcons.delete,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              title: Text(
                l10n.contactDetailsDeleteContact,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () async {
                final ok = await showAppDialog<bool>(
                  context: context,
                  builder: (context) => SecretlyAlertDialog(
                    title: Text(l10n.contactDetailsDeleteConfirmTitle),
                    content: Text(widget.profileId),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(l10n.cancel),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text(l10n.delete),
                      ),
                    ],
                  ),
                );
                if (ok != true) return;
                await widget.controller.deleteContact(
                  profileId: widget.profileId,
                );
                if (!context.mounted) return;
                Navigator.of(context).pop(true);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Блок страницы правки контакта. Android (23.11.2026, владелец: «плашки и
/// строки везде как в настройках; прозрачность — настройкой»): та же панель,
/// что в настройках, строки [rows] — в теме строк настроек, без линий.
/// iPhone и компьютер — прежняя плашка.
class _EditContactBlock extends StatelessWidget {
  const _EditContactBlock({
    required this.child,
    this.padding,
    this.rows = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool rows;

  @override
  Widget build(BuildContext context) {
    if (settingsAndroidPanels) {
      if (rows) return SettingsRowsPanel(children: [child]);
      return SettingsPanel(
        margin: EdgeInsets.zero,
        padding: padding ?? EdgeInsets.zero,
        child: child,
      );
    }
    return Container(
      decoration: appleGlassDecorationOr(
        context,
        BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
        ),
      ),
      padding: padding,
      child: child,
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
