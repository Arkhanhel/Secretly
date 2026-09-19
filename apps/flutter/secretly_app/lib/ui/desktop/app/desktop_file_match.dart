// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import '../../../l10n/app_localizations.dart';
import '../../../models/e2e_payload_v1.dart';

/// Поиск ПО ФАЙЛАМ: чем именно вложение отвечает на запрос.
///
/// 🔴 ПОЧЕМУ ЭТО ОТДЕЛЬНЫЙ ФАЙЛ, А НЕ ДВЕ СТРОКИ В ПАЛИТРЕ.
///
/// Имени файла нет ни в одном указателе: таблица `attachments` хранит ключ,
/// размер и срок жизни, а имя лежит ВНУТРИ зашифрованного полезного груза.
/// Значит поиск по файлам — это разбор каждого события, и цена ошибки в
/// разборе выше обычного: лишнее совпадение заставит расшифровать и показать
/// не то, а пропущенное сделает вид, что файла в переписке нет.
///
/// Здесь лежит ЧИСТАЯ часть — что считать именем и что считать совпадением.
/// Её можно проверить тестом без базы, ключей и контроллера.

/// Имя, под которым вложение видно человеку.
///
/// Порядок не случайный:
///   1. `filename` — то, что человек и отправлял;
///   2. название трека — у музыки своё имя из тегов, и оно узнаваемее, чем
///      `a1b2c3.mp3`;
///   3. подпись под файлом — иногда единственное, что человек помнит;
///   4. пусто — тогда строку рисует вызывающий по типу вложения.
String attachmentDisplayName(AttachmentEventV1 a) {
  final name = (a.filename ?? '').trim();
  if (name.isNotEmpty) return name;
  final title = (a.musicTitle ?? '').trim();
  final artist = (a.musicArtist ?? '').trim();
  if (title.isNotEmpty) {
    return artist.isEmpty ? title : '$artist — $title';
  }
  final caption = (a.caption ?? '').trim();
  if (caption.isNotEmpty) return caption;
  return '';
}

/// Совпадает ли вложение с запросом.
///
/// Ищем по имени, по тегам музыки и по подписи. По типу файла (`mime`) —
/// НЕТ: запрос «image» выдал бы все снимки переписки и вытеснил бы из выдачи
/// те несколько файлов, которые человек действительно искал.
///
/// [query] ожидается уже приведённым к нижнему регистру и обрезанным.
bool attachmentMatchesQuery(AttachmentEventV1 a, String query) {
  if (query.isEmpty) return false;
  for (final field in <String?>[
    a.filename,
    a.musicTitle,
    a.musicArtist,
    a.caption,
  ]) {
    final value = (field ?? '').trim();
    if (value.isEmpty) continue;
    if (value.toLowerCase().contains(query)) return true;
  }
  return false;
}

/// Подпись под именем файла в строке выдачи: «PDF · 2,4 МБ».
String attachmentMetaLine(AttachmentEventV1 a, AppLocalizations l10n) {
  final ext = _extensionLabel(a);
  final size = formatAttachmentSize(a.sizeBytes, l10n);
  if (ext.isEmpty) return size.isEmpty ? '—' : size;
  return size.isEmpty ? ext : '$ext · $size';
}

String _extensionLabel(AttachmentEventV1 a) {
  final name = (a.filename ?? '').trim();
  final dot = name.lastIndexOf('.');
  if (dot > 0 && dot < name.length - 1) {
    return name.substring(dot + 1).toUpperCase();
  }
  final mime = (a.mime ?? '').trim();
  if (mime.isEmpty) return '';
  final slash = mime.indexOf('/');
  if (slash < 0 || slash == mime.length - 1) return mime.toUpperCase();
  return mime.substring(slash + 1).toUpperCase();
}

/// Размер вложения словами: «820 КБ».
///
/// 🔴 ОДИН НА ВЕСЬ ДЕСКТОП. Тот же размер показывают строка под кадром в
/// ленте, пузырь файла и выдача поиска. Человек сверяет эти строки глазами, и
/// два разных округления одного файла читались бы как два разных файла.
///
/// Пустая строка при нулевом и отрицательном размере — так строка под кадром
/// просто не рисует размер, вместо того чтобы писать «0 Б».
String formatAttachmentSize(int n, AppLocalizations l10n) {
  if (n <= 0) return '';
  final units = <String>[
    l10n.desktopUnitB,
    l10n.desktopUnitKb,
    l10n.desktopUnitMb,
    l10n.desktopUnitGb,
    l10n.desktopUnitTb,
  ];
  var v = n.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  final fmt = v >= 100 || i == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  return '$fmt ${units[i]}';
}
