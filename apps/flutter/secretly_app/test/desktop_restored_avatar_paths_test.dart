// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
// Восстановление приносит СТРОКИ и ФАЙЛЫ, но пути в строках — чужие.
//
// 🔴 Дефект, ради которого этот тест написан (13.09.2026). Поле: «на
// компьютере нигде нет фотографий — ни моей, ни чужих, ни комнат».
//
// Копия профиля и связка по QR переносят таблицы целиком, а путь к картинке в
// них АБСОЛЮТНЫЙ: `/var/mobile/Containers/Data/Application/<UUID>/Documents/
// profile_avatars/…`. Файлы при этом кладутся в каталог НЫНЕШНЕГО приложения —
// на компьютере это вообще другая машина. В итоге всё восстановилось, байты
// лежат на диске, а человек видит инициалы: указатель ведёт в никуда, и
// разрешатель фотографий честно отвечает «файла нет».
//
// Ту же болезнь уже лечили дважды — у стикеров (`local_path`) и у своего фото
// (`my_avatar_path_v1`), оба раза перепривязкой по имени файла. Аватары
// собеседников, комнат и обложки остались единственными, кого починка не
// коснулась.
//
// Правило проверяется ровно одно: переписывается только МЁРТВЫЙ путь, и только
// когда файл с тем же именем нашёлся. Живой путь трогать нельзя — иначе
// «починка» сама уведёт картинку в сторону.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secretly_app/storage/app_db.dart';
import 'package:secretly_app/storage/safe_backup_snapshot_contract.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('rebase_images_');
  });

  tearDown(() async {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  /// Кладёт файл и возвращает его путь.
  Future<String> put(String name) async {
    final file = File('${tmp.path}/$name');
    await file.writeAsBytes(const <int>[1, 2, 3], flush: true);
    return file.path;
  }

  /// Тот же разрешатель, что в приложении: мёртвый путь — по имени файла.
  String? Function(String) resolverFor(Map<String, String> byName) {
    return (stored) {
      if (File(stored).existsSync()) return null;
      return byName[stored.split('/').last];
    };
  }

  test('🔴 мёртвый путь к фото собеседника переписывается на нынешний', () async {
    final db = await AppDb.openForTesting();
    try {
      final alive = await put('PEER_abc.png');
      await db.contactUpsert(profileId: 'PEER', displayName: 'Пётр');
      await db.contactSetAvatarPath(
        profileId: 'PEER',
        avatarPath: '/var/mobile/Containers/Data/Application/OLD/Documents/'
            'profile_avatars/PEER_abc.png',
      );

      final fixed = await db.rebaseImagePaths(
        resolverFor(<String, String>{'PEER_abc.png': alive}),
      );

      expect(fixed, 1);
      final row = await db.contactGet('PEER');
      expect(row?['avatar_path'], alive);
    } finally {
      await db.close();
    }
  });

  test('живой путь не трогается', () async {
    final db = await AppDb.openForTesting();
    try {
      final alive = await put('PEER_abc.png');
      final decoy = await put('decoy.png');
      await db.contactUpsert(profileId: 'PEER', displayName: 'Пётр');
      await db.contactSetAvatarPath(profileId: 'PEER', avatarPath: alive);

      final fixed = await db.rebaseImagePaths(
        resolverFor(<String, String>{'PEER_abc.png': decoy}),
      );

      expect(fixed, 0, reason: 'подмена живого пути — это не починка');
      final row = await db.contactGet('PEER');
      expect(row?['avatar_path'], alive);
    } finally {
      await db.close();
    }
  });

  test('файла с таким именем нет — путь остаётся как был', () async {
    final db = await AppDb.openForTesting();
    try {
      const dead = '/old/profile_avatars/GONE_abc.png';
      await db.contactUpsert(profileId: 'PEER', displayName: 'Пётр');
      await db.contactSetAvatarPath(profileId: 'PEER', avatarPath: dead);

      final fixed = await db.rebaseImagePaths(
        resolverFor(const <String, String>{}),
      );

      expect(fixed, 0);
      final row = await db.contactGet('PEER');
      expect(row?['avatar_path'], dead);
    } finally {
      await db.close();
    }
  });

  test('🔴 чинятся и метаданные профиля, и комнаты — не только контакты', () async {
    final db = await AppDb.openForTesting();
    try {
      final metaAvatar = await put('OD3S_meta.png');
      final roomAvatar = await put('room_xyz.jpg');

      // Заливаем строку тем же способом, каким её заливает восстановление —
      // снимком таблиц, а не отдельным сеттером.
      await db.importTables(<String, List<Map<String, Object?>>>{
        'profile_meta': <Map<String, Object?>>[
          <String, Object?>{
            'profile_id': 'OD3S',
            'nickname': 'Я',
            'avatar_path': '/old/Documents/profile_avatars/OD3S_meta.png',
            'updated_at_ms': 1,
          },
        ],
      }, allowedColumnsByTable: kSafeBackupSnapshotColumnsByTable);
      await db.groupSettingsUpsert(
        groupId: 'group:alpha',
        ownerProfileId: 'OD3S',
        avatarPath: '/old/Documents/room_avatars/room_xyz.jpg',
        avatarHash: 'hash',
        reactionsMode: 'all',
        allowText: true,
        allowMedia: true,
        allowAddMembers: true,
        allowPinMessages: true,
        allowChangeGroupInfo: true,
        allowChangeTag: false,
        joinApprovalRequired: false,
        slowModeSeconds: 0,
        chatHistoryVisible: true,
        membershipVersion: 1,
        stateVersion: 1,
      );

      final fixed = await db.rebaseImagePaths(
        resolverFor(<String, String>{
          'OD3S_meta.png': metaAvatar,
          'room_xyz.jpg': roomAvatar,
        }),
      );

      expect(fixed, 2);
      expect((await db.profileMetaGet('OD3S'))?['avatar_path'], metaAvatar);
      expect(
        (await db.groupSettingsGet('group:alpha'))?['avatar_path'],
        roomAvatar,
      );
    } finally {
      await db.close();
    }
  });
}
