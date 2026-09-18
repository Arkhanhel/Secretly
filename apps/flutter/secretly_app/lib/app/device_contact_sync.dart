// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as native_contacts;

const String _managedContactUrlPrefix = 'secretly://profile/';
const String _managedContactLabel = 'Secretly ID';

class DeviceContactSyncEntry {
  const DeviceContactSyncEntry({
    required this.profileId,
    required this.displayName,
    this.avatarPath,
  });

  final String profileId;
  final String displayName;
  final String? avatarPath;
}

class DeviceContactSyncSummary {
  const DeviceContactSyncSummary({
    this.createdCount = 0,
    this.updatedCount = 0,
    this.deletedCount = 0,
  });

  final int createdCount;
  final int updatedCount;
  final int deletedCount;
}

class DeviceContactSyncService {
  const DeviceContactSyncService();

  static bool get isSupportedPlatform => Platform.isAndroid || Platform.isIOS;

  Future<bool> hasPermission() async {
    if (!isSupportedPlatform) return false;
    try {
      return await native_contacts.FlutterContacts.permissions.has(
        native_contacts.PermissionType.readWrite,
      );
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> requestPermission() async {
    if (!isSupportedPlatform) return false;
    try {
      final status = await native_contacts.FlutterContacts.permissions.request(
        native_contacts.PermissionType.readWrite,
      );
      return status == native_contacts.PermissionStatus.granted ||
          status == native_contacts.PermissionStatus.limited;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<DeviceContactSyncSummary> syncContacts({
    required List<DeviceContactSyncEntry> entries,
  }) async {
    final managedContacts = await _loadManagedContacts();
    final managedByProfileId = <String, native_contacts.Contact>{};
    final duplicateManagedContacts = <native_contacts.Contact>[];

    for (final contact in managedContacts) {
      final profileId = _managedProfileIdFor(contact);
      if (profileId == null) continue;
      if (managedByProfileId.containsKey(profileId)) {
        duplicateManagedContacts.add(contact);
        continue;
      }
      managedByProfileId[profileId] = contact;
    }

    final desiredByProfileId = <String, DeviceContactSyncEntry>{};
    for (final entry in entries) {
      final profileId = entry.profileId.trim();
      final displayName = entry.displayName.trim();
      if (profileId.isEmpty || displayName.isEmpty) continue;
      desiredByProfileId[profileId] = DeviceContactSyncEntry(
        profileId: profileId,
        displayName: displayName,
        avatarPath: entry.avatarPath,
      );
    }

    var createdCount = 0;
    var updatedCount = 0;
    var deletedCount = 0;

    for (final entry in desiredByProfileId.values) {
      final existing = managedByProfileId.remove(entry.profileId);
      final photo = await _loadPhoto(entry.avatarPath);
      final nextContact = _buildManagedContact(
        entry,
        existing: existing,
        photo: photo,
      );
      if (existing == null) {
        await native_contacts.FlutterContacts.create(nextContact);
        createdCount += 1;
      } else {
        await native_contacts.FlutterContacts.update(nextContact);
        updatedCount += 1;
      }
    }

    for (final contact in <native_contacts.Contact>[
      ...managedByProfileId.values,
      ...duplicateManagedContacts,
    ]) {
      final contactId = contact.id?.trim();
      if (contactId == null || contactId.isEmpty) continue;
      await native_contacts.FlutterContacts.delete(contactId);
      deletedCount += 1;
    }

    return DeviceContactSyncSummary(
      createdCount: createdCount,
      updatedCount: updatedCount,
      deletedCount: deletedCount,
    );
  }

  Future<int> deleteManagedContacts() async {
    final managedContacts = await _loadManagedContacts();
    var deletedCount = 0;
    for (final contact in managedContacts) {
      final contactId = contact.id?.trim();
      if (contactId == null || contactId.isEmpty) continue;
      await native_contacts.FlutterContacts.delete(contactId);
      deletedCount += 1;
    }
    return deletedCount;
  }

  Future<List<native_contacts.Contact>> _loadManagedContacts() async {
    final contacts = await native_contacts.FlutterContacts.getAll(
      properties: <native_contacts.ContactProperty>{
        native_contacts.ContactProperty.name,
        native_contacts.ContactProperty.website,
        native_contacts.ContactProperty.photoThumbnail,
      },
    );
    return contacts
        .where((contact) => _managedProfileIdFor(contact) != null)
        .toList(growable: false);
  }

  native_contacts.Contact _buildManagedContact(
    DeviceContactSyncEntry entry, {
    required native_contacts.Contact? existing,
    required native_contacts.Photo? photo,
  }) {
    final markerWebsite = native_contacts.Website(
      url: _managedContactUrlFor(entry.profileId),
      label: const native_contacts.Label(
        native_contacts.WebsiteLabel.custom,
        _managedContactLabel,
      ),
    );
    final websites = <native_contacts.Website>[markerWebsite];
    if (existing != null) {
      for (final website in existing.websites) {
        if (_isManagedContactUrl(website.url)) continue;
        websites.add(website);
      }
    }

    final name = native_contacts.Name(first: entry.displayName);
    if (existing == null) {
      return native_contacts.Contact(
        name: name,
        websites: websites,
        photo: photo,
      );
    }

    return existing.copyWith(
      name: name,
      websites: websites,
      photo: photo,
      clearPhoto: photo == null,
    );
  }

  Future<native_contacts.Photo?> _loadPhoto(String? avatarPath) async {
    final normalizedPath = avatarPath?.trim();
    if (normalizedPath == null || normalizedPath.isEmpty) return null;
    try {
      final file = File(normalizedPath);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      return native_contacts.Photo(fullSize: bytes);
    } catch (_) {
      return null;
    }
  }

  static String? _managedProfileIdFor(native_contacts.Contact contact) {
    for (final website in contact.websites) {
      final profileId = _profileIdFromManagedContactUrl(website.url);
      if (profileId != null) return profileId;
    }
    return null;
  }

  static bool _isManagedContactUrl(String url) {
    return url.startsWith(_managedContactUrlPrefix);
  }

  static String _managedContactUrlFor(String profileId) {
    return '$_managedContactUrlPrefix${Uri.encodeComponent(profileId)}';
  }

  static String? _profileIdFromManagedContactUrl(String url) {
    if (!_isManagedContactUrl(url)) return null;
    final encoded = url.substring(_managedContactUrlPrefix.length).trim();
    if (encoded.isEmpty) return null;
    final decoded = Uri.decodeComponent(encoded).trim();
    return decoded.isEmpty ? null : decoded;
  }
}