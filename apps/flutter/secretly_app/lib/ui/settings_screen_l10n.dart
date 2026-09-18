// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/widgets.dart';

enum _SettingsLocale { en, ru, uk, es, pt, ptBR, fr, de }

String settingsScreenLabel(
  BuildContext context, {
  required String ru,
  required String en,
}) {
  final locale = _settingsLocaleOf(context);
  if (locale == _SettingsLocale.ru) return ru;
  if (locale == _SettingsLocale.en) return en;

  final dynamicLabel = _dynamicLabel(locale, en);
  if (dynamicLabel != null) return dynamicLabel;

  return _translatedStatic(locale, en) ?? en;
}

String settingsScreenPresetName(
  BuildContext context, {
  required String id,
  required String ru,
  required String en,
}) {
  final locale = _settingsLocaleOf(context);
  if (locale == _SettingsLocale.ru) return ru;
  if (locale == _SettingsLocale.en) return en;

  final translations = _presetTranslations[id];
  final direct = translations?[locale];
  if (direct != null) return direct;
  if (locale == _SettingsLocale.ptBR) {
    final fallback = translations?[_SettingsLocale.pt];
    if (fallback != null) return fallback;
  }
  return settingsScreenLabel(context, ru: ru, en: en);
}

bool settingsScreenUsesRussianShareText(BuildContext context) =>
    _settingsLocaleOf(context) == _SettingsLocale.ru;

_SettingsLocale _settingsLocaleOf(BuildContext context) {
  final locale = Localizations.localeOf(context);
  final languageCode = locale.languageCode.toLowerCase();
  final countryCode = locale.countryCode?.toUpperCase();
  if (languageCode == 'pt' && countryCode == 'BR') {
    return _SettingsLocale.ptBR;
  }
  switch (languageCode) {
    case 'ru':
      return _SettingsLocale.ru;
    case 'uk':
      return _SettingsLocale.uk;
    case 'es':
      return _SettingsLocale.es;
    case 'pt':
      return _SettingsLocale.pt;
    case 'fr':
      return _SettingsLocale.fr;
    case 'de':
      return _SettingsLocale.de;
    case 'en':
    default:
      return _SettingsLocale.en;
  }
}

String? _translatedStatic(_SettingsLocale locale, String en) {
  final translated = _settingsTranslations[locale]?[en];
  if (translated != null) return translated;
  if (locale == _SettingsLocale.ptBR) {
    return _settingsTranslations[_SettingsLocale.pt]?[en];
  }
  return null;
}

String? _dynamicLabel(_SettingsLocale locale, String en) {
  if (en.startsWith('Version ')) {
    return _version(locale, en.substring('Version '.length));
  }
  if (en.startsWith('Could not delete account: ')) {
    return _deleteAccountError(
      locale,
      en.substring('Could not delete account: '.length),
    );
  }
  if (en.startsWith('Current theme: ') && en.endsWith('.')) {
    return _currentTheme(
      locale,
      en.substring('Current theme: '.length, en.length - 1),
    );
  }
  final monthMatch = RegExp(r'^(\d+) months?$').firstMatch(en);
  if (monthMatch != null) {
    final count = int.tryParse(monthMatch.group(1)!);
    if (count != null) return _monthCount(locale, count);
  }
  final awayMatch = RegExp(r'^If away for: (\d+) months?$').firstMatch(en);
  if (awayMatch != null) {
    final count = int.tryParse(awayMatch.group(1)!);
    if (count != null) return _deleteAfter(locale, count);
  }
  final syncMatch = RegExp(
    r'^Sync complete: created (\d+), updated (\d+), removed (\d+)\.$',
  ).firstMatch(en);
  if (syncMatch != null) {
    return _syncComplete(
      locale,
      syncMatch.group(1)!,
      syncMatch.group(2)!,
      syncMatch.group(3)!,
    );
  }
  final removedMatch = RegExp(
    r'^Removed (\d+) imported contact\(s\)\. Sync is off\.$',
  ).firstMatch(en);
  if (removedMatch != null) {
    return _removedContacts(locale, removedMatch.group(1)!);
  }
  return null;
}

String _version(_SettingsLocale locale, String version) {
  switch (locale) {
    case _SettingsLocale.uk:
      return 'Версія $version';
    case _SettingsLocale.es:
      return 'Versión $version';
    case _SettingsLocale.pt:
    case _SettingsLocale.ptBR:
      return 'Versão $version';
    case _SettingsLocale.fr:
      return 'Version $version';
    case _SettingsLocale.de:
      return 'Version $version';
    case _SettingsLocale.en:
    case _SettingsLocale.ru:
      return 'Version $version';
  }
}

String _deleteAccountError(_SettingsLocale locale, String error) {
  switch (locale) {
    case _SettingsLocale.uk:
      return 'Не вдалося видалити акаунт: $error';
    case _SettingsLocale.es:
      return 'No se pudo eliminar la cuenta: $error';
    case _SettingsLocale.pt:
    case _SettingsLocale.ptBR:
      return 'Não foi possível excluir a conta: $error';
    case _SettingsLocale.fr:
      return 'Impossible de supprimer le compte : $error';
    case _SettingsLocale.de:
      return 'Konto konnte nicht gelöscht werden: $error';
    case _SettingsLocale.en:
    case _SettingsLocale.ru:
      return 'Could not delete account: $error';
  }
}

String _currentTheme(_SettingsLocale locale, String themeName) {
  switch (locale) {
    case _SettingsLocale.uk:
      return 'Поточна тема: $themeName.';
    case _SettingsLocale.es:
      return 'Tema actual: $themeName.';
    case _SettingsLocale.pt:
    case _SettingsLocale.ptBR:
      return 'Tema atual: $themeName.';
    case _SettingsLocale.fr:
      return 'Theme actuel : $themeName.';
    case _SettingsLocale.de:
      return 'Aktuelles Design: $themeName.';
    case _SettingsLocale.en:
    case _SettingsLocale.ru:
      return 'Current theme: $themeName.';
  }
}

String _deleteAfter(_SettingsLocale locale, int months) {
  final label = _monthCount(locale, months);
  switch (locale) {
    case _SettingsLocale.uk:
      return 'Якщо я не заходжу: $label';
    case _SettingsLocale.es:
      return 'Si estoy ausente durante: $label';
    case _SettingsLocale.pt:
    case _SettingsLocale.ptBR:
      return 'Se eu ficar ausente por: $label';
    case _SettingsLocale.fr:
      return 'Si je suis absent pendant : $label';
    case _SettingsLocale.de:
      return 'Bei Abwesenheit für: $label';
    case _SettingsLocale.en:
    case _SettingsLocale.ru:
      return 'If away for: $label';
  }
}

String _monthCount(_SettingsLocale locale, int months) {
  switch (locale) {
    case _SettingsLocale.uk:
      return '$months ${_ukMonthNoun(months)}';
    case _SettingsLocale.es:
      return '$months ${months == 1 ? 'mes' : 'meses'}';
    case _SettingsLocale.pt:
    case _SettingsLocale.ptBR:
      return '$months ${months == 1 ? 'mês' : 'meses'}';
    case _SettingsLocale.fr:
      return '$months mois';
    case _SettingsLocale.de:
      return '$months ${months == 1 ? 'Monat' : 'Monate'}';
    case _SettingsLocale.en:
    case _SettingsLocale.ru:
      return '$months month${months == 1 ? '' : 's'}';
  }
}

String _ukMonthNoun(int months) {
  final mod100 = months % 100;
  final mod10 = months % 10;
  if (mod100 >= 11 && mod100 <= 14) return 'місяців';
  if (mod10 == 1) return 'місяць';
  if (mod10 >= 2 && mod10 <= 4) return 'місяці';
  return 'місяців';
}

String _syncComplete(
  _SettingsLocale locale,
  String created,
  String updated,
  String removed,
) {
  switch (locale) {
    case _SettingsLocale.uk:
      return 'Синхронізацію завершено: створено $created, оновлено $updated, видалено $removed.';
    case _SettingsLocale.es:
      return 'Sincronización completada: creados $created, actualizados $updated, eliminados $removed.';
    case _SettingsLocale.pt:
    case _SettingsLocale.ptBR:
      return 'Sincronização concluída: criados $created, atualizados $updated, removidos $removed.';
    case _SettingsLocale.fr:
      return 'Synchronisation terminée : $created créés, $updated mis à jour, $removed supprimés.';
    case _SettingsLocale.de:
      return 'Synchronisierung abgeschlossen: $created erstellt, $updated aktualisiert, $removed entfernt.';
    case _SettingsLocale.en:
    case _SettingsLocale.ru:
      return 'Sync complete: created $created, updated $updated, removed $removed.';
  }
}

String _removedContacts(_SettingsLocale locale, String count) {
  switch (locale) {
    case _SettingsLocale.uk:
      return 'Видалено імпортованих контактів: $count. Синхронізацію вимкнено.';
    case _SettingsLocale.es:
      return 'Contactos importados eliminados: $count. La sincronización está desactivada.';
    case _SettingsLocale.pt:
    case _SettingsLocale.ptBR:
      return 'Contatos importados removidos: $count. A sincronização está desativada.';
    case _SettingsLocale.fr:
      return 'Contacts importés supprimés : $count. La synchronisation est désactivée.';
    case _SettingsLocale.de:
      return 'Importierte Kontakte entfernt: $count. Synchronisierung ist aus.';
    case _SettingsLocale.en:
    case _SettingsLocale.ru:
      return 'Removed $count imported contact(s). Sync is off.';
  }
}

const Map<String, Map<_SettingsLocale, String>> _presetTranslations = {
  'flutter_dash': {
    _SettingsLocale.uk: 'Flutter Dash',
    _SettingsLocale.es: 'Flutter Dash',
    _SettingsLocale.pt: 'Flutter Dash',
    _SettingsLocale.ptBR: 'Flutter Dash',
    _SettingsLocale.fr: 'Flutter Dash',
    _SettingsLocale.de: 'Flutter Dash',
  },
  'ocean': {
    _SettingsLocale.uk: 'Океан',
    _SettingsLocale.es: 'Océano',
    _SettingsLocale.pt: 'Oceano',
    _SettingsLocale.ptBR: 'Oceano',
    _SettingsLocale.fr: 'Océan',
    _SettingsLocale.de: 'Ozean',
  },
  'graphite': {
    _SettingsLocale.uk: 'Графіт',
    _SettingsLocale.es: 'Grafito',
    _SettingsLocale.pt: 'Grafite',
    _SettingsLocale.ptBR: 'Grafite',
    _SettingsLocale.fr: 'Graphite',
    _SettingsLocale.de: 'Graphit',
  },
  'amethyst': {
    _SettingsLocale.uk: 'Аметист',
    _SettingsLocale.es: 'Amatista',
    _SettingsLocale.pt: 'Ametista',
    _SettingsLocale.ptBR: 'Ametista',
    _SettingsLocale.fr: 'Améthyste',
    _SettingsLocale.de: 'Amethyst',
  },
  'sunset': {
    _SettingsLocale.uk: 'Захід',
    _SettingsLocale.es: 'Atardecer',
    _SettingsLocale.pt: 'Pôr do sol',
    _SettingsLocale.ptBR: 'Pôr do sol',
    _SettingsLocale.fr: 'Crépuscule',
    _SettingsLocale.de: 'Sonnenuntergang',
  },
  'aurora': {
    _SettingsLocale.uk: 'Аврора',
    _SettingsLocale.es: 'Aurora',
    _SettingsLocale.pt: 'Aurora',
    _SettingsLocale.ptBR: 'Aurora',
    _SettingsLocale.fr: 'Aurore',
    _SettingsLocale.de: 'Aurora',
  },
  'rosewood': {
    _SettingsLocale.uk: 'Рожеве дерево',
    _SettingsLocale.es: 'Palo rosa',
    _SettingsLocale.pt: 'Pau-rosa',
    _SettingsLocale.ptBR: 'Pau-rosa',
    _SettingsLocale.fr: 'Bois de rose',
    _SettingsLocale.de: 'Rosenholz',
  },
  'toplenoe_moloko': {
    _SettingsLocale.uk: 'Пряжене молоко',
    _SettingsLocale.es: 'Leche horneada',
    _SettingsLocale.pt: 'Leite cozido',
    _SettingsLocale.ptBR: 'Leite cozido',
    _SettingsLocale.fr: 'Lait cuit',
    _SettingsLocale.de: 'Gebackene Milch',
  },
  'noch_na_marse': {
    _SettingsLocale.uk: 'Ніч на Марсі!',
    _SettingsLocale.es: '¡Noche en Marte!',
    _SettingsLocale.pt: 'Noite em Marte!',
    _SettingsLocale.ptBR: 'Noite em Marte!',
    _SettingsLocale.fr: 'Nuit sur Mars !',
    _SettingsLocale.de: 'Nacht auf dem Mars!',
  },
  'accent': {
    _SettingsLocale.uk: 'Акцент',
    _SettingsLocale.es: 'Acento',
    _SettingsLocale.pt: 'Destaque',
    _SettingsLocale.ptBR: 'Destaque',
    _SettingsLocale.fr: 'Accent',
    _SettingsLocale.de: 'Akzent',
  },
  'amber': {
    _SettingsLocale.uk: 'Бурштин',
    _SettingsLocale.es: 'Ámbar',
    _SettingsLocale.pt: 'Âmbar',
    _SettingsLocale.ptBR: 'Âmbar',
    _SettingsLocale.fr: 'Ambre',
    _SettingsLocale.de: 'Bernstein',
  },
  'violet': {
    _SettingsLocale.uk: 'Фіолет',
    _SettingsLocale.es: 'Violeta',
    _SettingsLocale.pt: 'Violeta',
    _SettingsLocale.ptBR: 'Violeta',
    _SettingsLocale.fr: 'Violet',
    _SettingsLocale.de: 'Violett',
  },
  'ice': {
    _SettingsLocale.uk: 'Лід',
    _SettingsLocale.es: 'Hielo',
    _SettingsLocale.pt: 'Gelo',
    _SettingsLocale.ptBR: 'Gelo',
    _SettingsLocale.fr: 'Glace',
    _SettingsLocale.de: 'Eis',
  },
  // PR-J — indicator-colour preset names.
  'indicator_theme': {
    _SettingsLocale.uk: 'За темою',
    _SettingsLocale.es: 'Tema',
    _SettingsLocale.pt: 'Tema',
    _SettingsLocale.ptBR: 'Tema',
    _SettingsLocale.fr: 'Thème',
    _SettingsLocale.de: 'Design',
  },
  'indicator_indigo': {
    _SettingsLocale.uk: 'Індиго',
    _SettingsLocale.es: 'Índigo',
    _SettingsLocale.pt: 'Índigo',
    _SettingsLocale.ptBR: 'Índigo',
    _SettingsLocale.fr: 'Indigo',
    _SettingsLocale.de: 'Indigo',
  },
  'indicator_violet': {
    _SettingsLocale.uk: 'Фіолет',
    _SettingsLocale.es: 'Violeta',
    _SettingsLocale.pt: 'Violeta',
    _SettingsLocale.ptBR: 'Violeta',
    _SettingsLocale.fr: 'Violet',
    _SettingsLocale.de: 'Violett',
  },
  'indicator_pink': {
    _SettingsLocale.uk: 'Рожевий',
    _SettingsLocale.es: 'Rosa',
    _SettingsLocale.pt: 'Rosa',
    _SettingsLocale.ptBR: 'Rosa',
    _SettingsLocale.fr: 'Rose',
    _SettingsLocale.de: 'Pink',
  },
  'indicator_rose': {
    _SettingsLocale.uk: 'Троянда',
    _SettingsLocale.es: 'Rosado',
    _SettingsLocale.pt: 'Rosado',
    _SettingsLocale.ptBR: 'Rosado',
    _SettingsLocale.fr: 'Rosé',
    _SettingsLocale.de: 'Rosé',
  },
  'indicator_amber': {
    _SettingsLocale.uk: 'Бурштин',
    _SettingsLocale.es: 'Ámbar',
    _SettingsLocale.pt: 'Âmbar',
    _SettingsLocale.ptBR: 'Âmbar',
    _SettingsLocale.fr: 'Ambre',
    _SettingsLocale.de: 'Bernstein',
  },
  'indicator_emerald': {
    _SettingsLocale.uk: 'Смарагд',
    _SettingsLocale.es: 'Esmeralda',
    _SettingsLocale.pt: 'Esmeralda',
    _SettingsLocale.ptBR: 'Esmeralda',
    _SettingsLocale.fr: 'Émeraude',
    _SettingsLocale.de: 'Smaragd',
  },
  'indicator_blue': {
    _SettingsLocale.uk: 'Синій',
    _SettingsLocale.es: 'Azul',
    _SettingsLocale.pt: 'Azul',
    _SettingsLocale.ptBR: 'Azul',
    _SettingsLocale.fr: 'Bleu',
    _SettingsLocale.de: 'Blau',
  },
  'indicator_cyan': {
    _SettingsLocale.uk: 'Циан',
    _SettingsLocale.es: 'Cian',
    _SettingsLocale.pt: 'Ciano',
    _SettingsLocale.ptBR: 'Ciano',
    _SettingsLocale.fr: 'Cyan',
    _SettingsLocale.de: 'Cyan',
  },
  'indicator_orange': {
    _SettingsLocale.uk: 'Помаранчевий',
    _SettingsLocale.es: 'Naranja',
    _SettingsLocale.pt: 'Laranja',
    _SettingsLocale.ptBR: 'Laranja',
    _SettingsLocale.fr: 'Orange',
    _SettingsLocale.de: 'Orange',
  },
};

const Map<_SettingsLocale, Map<String, String>> _settingsTranslations = {
  _SettingsLocale.uk: {
    // Settings → Power (energy/heat), added 2026-08-01.
    'None of these affect message delivery, encryption or notifications — only how the app looks.': 'Ніщо з цього не впливає на доставку повідомлень, шифрування та сповіщення — лише на те, як застосунок виглядає.',
    'Power': 'Енергоспоживання',
    'Less heat and battery drain': 'Менше нагріву та витрати батареї',
    'Everything is on by default. Turn them off from the top down — the first one saves the most.': 'Усе ввімкнено за замовчуванням. Вимикайте по одному згори вниз — перший пункт заощаджує найбільше.',
    'Glass bubbles': 'Скляні бульбашки',
    'Incoming messages show the blurred wallpaper through them. It looks good, but keeps a blurred copy of the wallpaper alive the whole time a chat is open. Turn this off first if the phone gets hot.': 'Вхідні повідомлення показують крізь себе розмиті шпалери. Виглядає гарно, але тримає розмиту копію шпалер увесь час, поки відкрито чат. Вимкніть це першим, якщо телефон гріється.',
    'Frosted panels': 'Матові панелі',
    'The blur under the chat header and the composer. The panels stay exactly where they are — the background behind them simply stops being blurred.': 'Розмиття під шапкою чату та полем введення. Панелі залишаються на місці — фон за ними просто перестає розмиватися.',
    'Frame & status animations': 'Анімація рамок і статусів',
    "Animate peers' premium frames and status emoji in chats and lists. Profiles always animate.": 'Анімувати преміум-рамки та емодзі-статуси співрозмовників у чатах і списках. У профілях анімація є завжди.',
    'Nobody': 'Ніхто',
    'My contacts': 'Мої контакти',
    'Everybody': 'Усі',
    'Short': 'Короткий',
    'Long': 'Довгий',
    'System default': 'Системне значення',
    'Off': 'Вимкнено',
    'Beacon': 'Beacon',
    'Chime': 'Chime',
    'Default': 'За замовчуванням',
    'Hidden': 'Приховано',
    'Sender only': 'Лише відправник',
    'Sender + message': 'Відправник і текст',
    'Profile name': 'Ім’я профілю',
    'Enter name': 'Введіть ім’я',
    'Save': 'Зберегти',
    'Change name': 'Змінити ім’я',
    'Share profile': 'Поділитися профілем',
    'Privacy policy': 'Політика конфіденційності',
    'What is stored locally': 'Що зберігається локально',
    'Chat history and attachments are stored on your device in an encrypted database.':
        'Історія чатів і вкладення зберігаються на вашому пристрої в зашифрованій базі даних.',
    'What goes through the server': 'Що проходить через сервер',
    'Servers process encrypted message delivery, TTL queues, and key-service operations. Message content is not stored in plaintext.':
        'Сервери обробляють доставку зашифрованих повідомлень, черги TTL та операції сервісу ключів. Вміст повідомлень не зберігається у відкритому вигляді.',
    'Official version': 'Офіційна версія',
    'The full Privacy Policy and Terms of Service are published on the official Secretly website.':
        'Повна Політика конфіденційності та Умови використання опубліковані на офіційному сайті Secretly.',
    'Open Privacy Policy': 'Відкрити Privacy Policy',
    'Open Terms of Service': 'Відкрити Terms of Service',
    'About Secretly': 'Про Secretly',
    'A messenger focused on E2EE, privacy, and reliable message delivery.':
        'Месенджер із фокусом на E2EE, приватність і надійну доставку повідомлень.',
    'Build': 'Збірка',
    'Official website': 'Офіційний сайт',
    'Privacy Policy': 'Privacy Policy',
    'Terms of Service': 'Terms of Service',
    'Profile QR': 'QR профілю',
    'Media & profile': 'Медіа та профіль',
    'Security': 'Безпека',
    'System message available': 'Є системне повідомлення',
    'Invite friends': 'Запросити друзів',
    'Donate Secretly': 'Підтримати Secretly',
    'Support': 'Підтримка',
    'Not set': 'Не задано',
    'About': 'Про себе',
    'Not added': 'Не додано',
    'About text': 'Текст про себе',
    'Clear': 'Очистити',
    'Save this ID: it is required to restore your account and server backup.':
        'Збережіть цей ID: він потрібен для відновлення акаунта та серверної резервної копії.',
    'Log out': 'Вийти з акаунта',
    'End session on this device': 'Завершити сесію на цьому пристрої',
    'Log out and clear local profile data on this device?':
        'Вийти та очистити локальні дані профілю на цьому пристрої?',
    'Delete account': 'Видалити акаунт',
    'Delete server profile and local data':
        'Видалити профіль на сервері та локальні дані',
    'Delete account?': 'Видалити акаунт?',
    'Your profile, keys, backups, message queues, and local data will be deleted. This cannot be undone.':
        'Ваш профіль, ключі, резервні копії, черги повідомлень і локальні дані буде видалено. Цю дію неможливо скасувати.',
    'Delete': 'Видалити',
    'Deleting account...': 'Видалення акаунта...',
    'Enabled': 'Увімкнено',
    'Disabled': 'Вимкнено',
    'Show notifications': 'Показувати сповіщення',
    'All accounts': 'Усі акаунти',
    'Private chats': 'Особисті чати',
    'New messages': 'Нові повідомлення',
    'Notify about new messages in private chats.':
        'Сповіщати про нові повідомлення в особистих чатах.',
    'Message text': 'Текст повідомлення',
    'Show message text in private chat notifications.':
        'Показувати текст повідомлення у сповіщеннях особистих чатів.',
    'Name and photo': 'Ім’я та фото',
    'Show the contact name and photo in private chat notifications.':
        'Показувати ім’я та фото співрозмовника у сповіщеннях особистих чатів.',
    'Rooms': 'Кімнати',
    'Notify about new messages in rooms.':
        'Сповіщати про нові повідомлення в кімнатах.',
    'Show message text in room notifications.':
        'Показувати текст повідомлення у сповіщеннях кімнат.',
    'Show the sender name and photo in room notifications.':
        'Показувати ім’я та фото відправника у сповіщеннях кімнат.',
    'In-app calls': 'Дзвінки в застосунку',
    'Allow calls in the app': 'Дозволити дзвінки в застосунку',
    'Incoming calls': 'Вхідні дзвінки',
    'Allow incoming calls': 'Дозволити вхідні дзвінки',
    'Lock-screen call screen': 'Екран дзвінка на заблокованому екрані',
    'System permission enabled': 'Системний дозвіл увімкнено',
    'Enable this so calls can open over the lock screen':
        'Увімкніть, щоб дзвінки відкривалися поверх заблокованого екрана',
    'Checking permission...': 'Перевіряємо дозвіл...',
    'Screen sharing': 'Демонстрація екрана',
    'Allow incoming screen-sharing calls':
        'Дозволити вхідні дзвінки з демонстрацією екрана',
    'Vibration': 'Вібрація',
    'Ringtone': 'Рингтон',
    'Sound': 'Звук',
    'Incoming sound': 'Звук вхідних',
    'In-chat sound': 'Звук у чаті',
    'In-chat sound style': 'Тип звуку в чаті',
    'Haptics': 'Тактильний відгук',
    'Vibration for expanding categories, photos, and other in-app actions.':
        'Вібрація під час розгортання категорій, фото та інших дій у застосунку.',
    'Notification privacy': 'Приватність сповіщень',
    'Notification card': 'Картка сповіщення',
    'Show the system notification card while the app is in background.':
        'Показувати системну картку сповіщення, коли застосунок у фоні.',
    'Background connection': 'Фонове з’єднання',
    'Keep a minimal connection while the app stays in memory. When the app is fully closed, delivery relies on push notifications.':
        'Підтримувати мінімальне з’єднання, доки застосунок залишається в пам’яті. Після повного закриття доставка спирається на push-сповіщення.',
    'Reset notification settings': 'Скинути налаштування сповіщень',
    'Reset custom notification preferences.':
        'Скинути індивідуальні налаштування сповіщень.',
    'Reset settings': 'Скидання налаштувань',
    'Reset notification settings to defaults?':
        'Скинути налаштування сповіщень до значень за замовчуванням?',
    'Reset': 'Скинути',
    'Work group • online': 'Робоча група • онлайн',
    'Mira': 'Міра',
    'Forwarded from\nSMS: Courier\nDelivery at 7:30 PM, code 4821.':
        'Переслано від\nSMS: Кур’єр\nДоставка о 19:30, код 4821.',
    'You': 'Ви',
    'Done. Updated the team.': 'Готово. Повідомив команду.',
    'Forwarded from • SMS: Courier': 'Переслано від • SMS: Кур’єр',
    'Service': 'Сервіс',
    'Okay. I can add a reminder if needed.':
        'Добре. За потреби додам нагадування.',
    'Chat wallpapers': 'Фони чатів',
    'Open extended picker': 'Відкрити розширений вибір',
    'Application themes': 'Теми застосунку',
    'Bubble colors': 'Кольори бульбашок',
    'Nickname colors': 'Кольори імен',
    'Indicator colors': 'Кольори індикаторів',
    'You: got it': 'Ви: прийняв',
    'Mira: forwarded SMS': 'Міра: переслала SMS',
    'Chat behavior': 'Поведінка чатів',
    'Show your profile QR code': 'Показати ваш QR-код профілю',
    'QR scanner': 'QR-сканер',
    'Scan a contact QR code': 'Сканувати QR-код контакта',
    'Personal chats': 'Особисті чати',
    'Open your personal chat collection':
        'Відкрити вашу особисту добірку чатів',
    'Media privacy': 'Приватність медіа',
    'Profile media is visible only to you': 'Медіа з профілю видно лише вам',
    'Syncing with your device address book':
        'Синхронізація з адресною книгою пристрою',
    'Available in the Android and iPhone app':
        'Доступно в застосунку для Android та iPhone',
    'Keep Secretly contacts in your device address book':
        'Зберігати контакти Secretly в адресній книзі пристрою',
    'Do not save Secretly contacts to your device address book':
        'Не зберігати контакти Secretly в адресній книзі пристрою',
    'Removal is available only in the mobile app':
        'Видалення доступне лише в мобільному застосунку',
    'Remove Secretly contacts from your address book and turn sync off':
        'Видалити контакти Secretly з адресної книги та вимкнути синхронізацію',
    'Device contacts are already up to date.':
        'Контакти пристрою вже актуальні.',
    'Contact sync is turned off on this device.':
        'Синхронізацію контактів вимкнено на цьому пристрої.',
    'No imported contacts were found. Sync is off.':
        'Імпортованих контактів не знайдено. Синхронізацію вимкнено.',
    'Allow contact access to manage your device address book.':
        'Дозвольте доступ до контактів, щоб керувати адресною книгою пристрою.',
    'Manage device contacts from the Android or iPhone app.':
        'Керуйте контактами пристрою із застосунку для Android або iPhone.',
    'Could not update device contacts right now.':
        'Не вдалося оновити контакти пристрою просто зараз.',
    'Delete imported contacts?': 'Видалити імпортовані контакти?',
    'Secretly will remove its contacts from this device address book and turn sync off.':
        'Secretly видалить свої контакти з адресної книги цього пристрою та вимкне синхронізацію.',
    'Cancel': 'Скасувати',
    'Last seen': 'Час останнього входу',
    'Profile photos': 'Фото профілю',
    'Message forwards': 'Пересилання повідомлень',
    'Calls': 'Дзвінки',
    'Voice messages': 'Голосові повідомлення',
    'Messages': 'Повідомлення',
    'New chats from strangers': 'Нові чати від незнайомців',
    'Archive and mute': 'В архів і без сповіщень',
    'Delete my account': 'Видалити мій акаунт',
    'Delete imported contacts': 'Видалити імпортовані контакти',
    'Sync contacts': 'Синхронізувати контакти',
    'People suggestions in search': 'Підказки людей у пошуку',
    'Discoverable by nickname': 'Видимість за нікнеймом',
    'Allow others to find you by nickname':
        'Дозволити іншим знаходити вас за нікнеймом',
    'Privacy controls': 'Керування приватністю',
    'Manage blocked users': 'Керування заблокованими користувачами',
    'Describe the issue first.': 'Спочатку опишіть проблему.',
    'Could not open mail app. Request text copied to clipboard.':
        'Не вдалося відкрити поштовий застосунок. Текст запиту скопійовано в буфер обміну.',
    'Support contact form': 'Форма звернення до підтримки',
    'Describe the issue and add contact details if needed. The technical information below is attached automatically.':
        'Опишіть проблему й за потреби додайте контактні дані. Технічна інформація нижче додається автоматично.',
    'Name': 'Ім’я',
    'Email / Contact': 'Email / контакт',
    'Describe the issue': 'Опишіть проблему',
    'Technical information': 'Технічна інформація',
    'This block is already attached to the request automatically.':
        'Цей блок уже буде автоматично додано до запиту.',
    'Send request': 'Надіслати запит',
    'Could not open the Donorbox page in a browser.':
        'Не вдалося відкрити сторінку Donorbox у браузері.',
    'Could not open the Secretly website link.':
        'Не вдалося відкрити посилання на сайт Secretly.',
    'Default chat wallpapers': 'Фони чатів за замовчуванням',
    'Application color theme': 'Кольорова тема застосунку',
    'Message bubble style': 'Стиль бульбашок повідомлень',
    'Names color in replies and quotes': 'Колір імен у відповідях і цитатах',
    'Contact': 'Контакт',
    'System errors': 'Системні помилки',
    'Transport blocked': 'Транспорт заблоковано',
    'System is operating normally': 'Система працює нормально',
    'Support the project': 'Підтримка проєкту',
    'Secretly is evolving as a private messenger focused on security, UX, and independent infrastructure. On Android and iPhone, the Donorbox page opens in a browser so Apple Pay and Google Pay stay available instead of disappearing inside an embedded WebView.':
        'Secretly розвивається як приватний месенджер із фокусом на безпеку, UX та незалежну інфраструктуру. На Android і iPhone сторінка Donorbox відкривається в браузері, щоб Apple Pay і Google Pay лишалися доступними, а не зникали всередині вбудованого WebView.',
    'Donorbox link copied': 'Посилання Donorbox скопійовано',
    'Copy link': 'Скопіювати посилання',
    'Open in browser': 'Відкрити в браузері',
    'Refresh': 'Оновити',
    'Failed to load Donorbox.': 'Не вдалося завантажити Donorbox.',
    'Donorbox did not load right now': 'Donorbox зараз не завантажився',
    'Try again': 'Спробувати ще раз',
    'Apple Pay and Google Pay open in a browser':
        'Apple Pay і Google Pay відкриваються в браузері',
    'Donorbox briefly renders the web-wallet buttons and then hides them inside the embedded WebView after environment checks. Opening the page in your browser keeps Apple Pay and Google Pay available.':
        'Donorbox спочатку показує кнопки web-wallet, а потім приховує їх у вбудованому WebView після перевірки середовища. Відкриття сторінки в браузері зберігає доступність Apple Pay і Google Pay.',
    'Open payment page': 'Відкрити сторінку оплати',
    'Embedded Donorbox is available on Android, iPhone, and macOS':
        'Вбудований Donorbox доступний на Android, iPhone та macOS',
    'This platform currently uses a safe fallback. The campaign itself is already configured and the link is available below.':
        'На цій платформі наразі використовується безпечний fallback. Сама кампанія вже налаштована, а посилання доступне нижче.',
  },
  _SettingsLocale.es: {
    // Settings → Power (energy/heat), added 2026-08-01.
    'None of these affect message delivery, encryption or notifications — only how the app looks.': 'Nada de esto afecta a la entrega de mensajes, al cifrado ni a las notificaciones: solo al aspecto de la aplicación.',
    'Power': 'Energía',
    'Less heat and battery drain': 'Menos calor y consumo de batería',
    'Everything is on by default. Turn them off from the top down — the first one saves the most.': 'Todo está activado de forma predeterminada. Desactívalos de arriba abajo: el primero es el que más ahorra.',
    'Glass bubbles': 'Burbujas de cristal',
    'Incoming messages show the blurred wallpaper through them. It looks good, but keeps a blurred copy of the wallpaper alive the whole time a chat is open. Turn this off first if the phone gets hot.': 'Los mensajes entrantes dejan ver el fondo de pantalla difuminado a través de ellos. Queda bonito, pero mantiene una copia difuminada del fondo mientras el chat está abierto. Desactívalo primero si el teléfono se calienta.',
    'Frosted panels': 'Paneles esmerilados',
    'The blur under the chat header and the composer. The panels stay exactly where they are — the background behind them simply stops being blurred.': 'El desenfoque bajo la cabecera del chat y el campo de escritura. Los paneles no se mueven: el fondo detrás de ellos simplemente deja de difuminarse.',
    'Frame & status animations': 'Animación de marcos y estados',
    "Animate peers' premium frames and status emoji in chats and lists. Profiles always animate.": 'Animar los marcos premium y los emojis de estado de tus contactos en chats y listas. En los perfiles siempre se animan.',
    'Nobody': 'Nadie',
    'My contacts': 'Mis contactos',
    'Everybody': 'Todos',
    'Short': 'Corto',
    'Long': 'Largo',
    'System default': 'Predeterminado del sistema',
    'Off': 'Desactivado',
    'Beacon': 'Beacon',
    'Chime': 'Chime',
    'Default': 'Predeterminado',
    'Hidden': 'Oculto',
    'Sender only': 'Solo remitente',
    'Sender + message': 'Remitente y mensaje',
    'Profile name': 'Nombre del perfil',
    'Enter name': 'Introduce un nombre',
    'Save': 'Guardar',
    'Change name': 'Cambiar nombre',
    'Share profile': 'Compartir perfil',
    'Privacy policy': 'Política de privacidad',
    'What is stored locally': 'Qué se guarda localmente',
    'Chat history and attachments are stored on your device in an encrypted database.':
        'El historial de chats y los adjuntos se guardan en tu dispositivo en una base de datos cifrada.',
    'What goes through the server': 'Qué pasa por el servidor',
    'Servers process encrypted message delivery, TTL queues, and key-service operations. Message content is not stored in plaintext.':
        'Los servidores procesan la entrega de mensajes cifrados, las colas TTL y las operaciones del servicio de claves. El contenido de los mensajes no se guarda en texto claro.',
    'Official version': 'Versión oficial',
    'The full Privacy Policy and Terms of Service are published on the official Secretly website.':
        'La Política de privacidad y las Condiciones de servicio completas están publicadas en el sitio web oficial de Secretly.',
    'Open Privacy Policy': 'Abrir Privacy Policy',
    'Open Terms of Service': 'Abrir Terms of Service',
    'About Secretly': 'Acerca de Secretly',
    'A messenger focused on E2EE, privacy, and reliable message delivery.':
        'Un mensajero centrado en E2EE, privacidad y entrega fiable de mensajes.',
    'Build': 'Compilación',
    'Official website': 'Sitio web oficial',
    'Privacy Policy': 'Privacy Policy',
    'Terms of Service': 'Terms of Service',
    'Profile QR': 'QR del perfil',
    'Media & profile': 'Medios y perfil',
    'Security': 'Seguridad',
    'System message available': 'Hay un mensaje del sistema',
    'Invite friends': 'Invitar amigos',
    'Donate Secretly': 'Donar a Secretly',
    'Support': 'Soporte',
    'Not set': 'No definido',
    'About': 'Acerca de mí',
    'Not added': 'No añadido',
    'About text': 'Texto sobre mí',
    'Clear': 'Borrar',
    'Save this ID: it is required to restore your account and server backup.':
        'Guarda este ID: es necesario para restaurar tu cuenta y la copia de seguridad del servidor.',
    'Log out': 'Cerrar sesión',
    'End session on this device': 'Finalizar la sesión en este dispositivo',
    'Log out and clear local profile data on this device?':
        '¿Cerrar sesión y borrar los datos locales del perfil en este dispositivo?',
    'Delete account': 'Eliminar cuenta',
    'Delete server profile and local data':
        'Eliminar el perfil del servidor y los datos locales',
    'Delete account?': '¿Eliminar cuenta?',
    'Your profile, keys, backups, message queues, and local data will be deleted. This cannot be undone.':
        'Se eliminarán tu perfil, claves, copias de seguridad, colas de mensajes y datos locales. Esta acción no se puede deshacer.',
    'Delete': 'Eliminar',
    'Deleting account...': 'Eliminando cuenta...',
    'Enabled': 'Activado',
    'Disabled': 'Desactivado',
    'Show notifications': 'Mostrar notificaciones',
    'All accounts': 'Todas las cuentas',
    'Private chats': 'Chats privados',
    'New messages': 'Mensajes nuevos',
    'Notify about new messages in private chats.':
        'Avisar sobre mensajes nuevos en chats privados.',
    'Message text': 'Texto del mensaje',
    'Show message text in private chat notifications.':
        'Mostrar el texto del mensaje en las notificaciones de chats privados.',
    'Name and photo': 'Nombre y foto',
    'Show the contact name and photo in private chat notifications.':
        'Mostrar el nombre y la foto del contacto en las notificaciones de chats privados.',
    'Rooms': 'Salas',
    'Notify about new messages in rooms.':
        'Avisar sobre mensajes nuevos en salas.',
    'Show message text in room notifications.':
        'Mostrar el texto del mensaje en las notificaciones de salas.',
    'Show the sender name and photo in room notifications.':
        'Mostrar el nombre y la foto del remitente en las notificaciones de salas.',
    'In-app calls': 'Llamadas en la app',
    'Allow calls in the app': 'Permitir llamadas en la app',
    'Incoming calls': 'Llamadas entrantes',
    'Allow incoming calls': 'Permitir llamadas entrantes',
    'Lock-screen call screen': 'Pantalla de llamada bloqueada',
    'System permission enabled': 'Permiso del sistema activado',
    'Enable this so calls can open over the lock screen':
        'Activa esto para que las llamadas puedan abrirse sobre la pantalla bloqueada',
    'Checking permission...': 'Comprobando permiso...',
    'Screen sharing': 'Compartir pantalla',
    'Allow incoming screen-sharing calls':
        'Permitir llamadas entrantes con pantalla compartida',
    'Vibration': 'Vibración',
    'Ringtone': 'Tono de llamada',
    'Sound': 'Sonido',
    'Incoming sound': 'Sonido entrante',
    'In-chat sound': 'Sonido en el chat',
    'In-chat sound style': 'Estilo de sonido en el chat',
    'Haptics': 'Respuesta háptica',
    'Vibration for expanding categories, photos, and other in-app actions.':
        'Vibración al expandir categorías, fotos y otras acciones dentro de la app.',
    'Notification privacy': 'Privacidad de notificaciones',
    'Notification card': 'Tarjeta de notificación',
    'Show the system notification card while the app is in background.':
        'Mostrar la tarjeta de notificación del sistema cuando la app esté en segundo plano.',
    'Background connection': 'Conexión en segundo plano',
    'Keep a minimal connection while the app stays in memory. When the app is fully closed, delivery relies on push notifications.':
        'Mantener una conexión mínima mientras la app permanezca en memoria. Cuando la app se cierra por completo, la entrega depende de las notificaciones push.',
    'Reset notification settings': 'Restablecer notificaciones',
    'Reset custom notification preferences.':
        'Restablecer preferencias personalizadas de notificaciones.',
    'Reset settings': 'Restablecer ajustes',
    'Reset notification settings to defaults?':
        '¿Restablecer las notificaciones a sus valores predeterminados?',
    'Reset': 'Restablecer',
    'Work group • online': 'Grupo de trabajo • en línea',
    'Mira': 'Mira',
    'Forwarded from\nSMS: Courier\nDelivery at 7:30 PM, code 4821.':
        'Reenviado de\nSMS: Mensajería\nEntrega a las 19:30, código 4821.',
    'You': 'Tú',
    'Done. Updated the team.': 'Listo. Actualicé al equipo.',
    'Forwarded from • SMS: Courier': 'Reenviado de • SMS: Mensajería',
    'Service': 'Servicio',
    'Okay. I can add a reminder if needed.':
        'De acuerdo. Puedo añadir un recordatorio si hace falta.',
    'Chat wallpapers': 'Fondos de chat',
    'Open extended picker': 'Abrir selector ampliado',
    'Application themes': 'Temas de la app',
    'Bubble colors': 'Colores de burbujas',
    'Nickname colors': 'Colores de nombres',
    'Indicator colors': 'Colores de acento',
    'You: got it': 'Tú: recibido',
    'Mira: forwarded SMS': 'Mira: reenvió SMS',
    'Chat behavior': 'Comportamiento del chat',
    'Show your profile QR code': 'Mostrar tu código QR de perfil',
    'QR scanner': 'Escáner QR',
    'Scan a contact QR code': 'Escanear el QR de un contacto',
    'Personal chats': 'Chats personales',
    'Open your personal chat collection':
        'Abrir tu colección personal de chats',
    'Media privacy': 'Privacidad de medios',
    'Profile media is visible only to you':
        'Los medios del perfil solo son visibles para ti',
    'Syncing with your device address book':
        'Sincronizando con la agenda del dispositivo',
    'Available in the Android and iPhone app':
        'Disponible en la app para Android y iPhone',
    'Keep Secretly contacts in your device address book':
        'Guardar contactos de Secretly en la agenda del dispositivo',
    'Do not save Secretly contacts to your device address book':
        'No guardar contactos de Secretly en la agenda del dispositivo',
    'Removal is available only in the mobile app':
        'La eliminación solo está disponible en la app móvil',
    'Remove Secretly contacts from your address book and turn sync off':
        'Eliminar contactos de Secretly de tu agenda y desactivar la sincronización',
    'Device contacts are already up to date.':
        'Los contactos del dispositivo ya están actualizados.',
    'Contact sync is turned off on this device.':
        'La sincronización de contactos está desactivada en este dispositivo.',
    'No imported contacts were found. Sync is off.':
        'No se encontraron contactos importados. La sincronización está desactivada.',
    'Allow contact access to manage your device address book.':
        'Permite el acceso a contactos para gestionar la agenda del dispositivo.',
    'Manage device contacts from the Android or iPhone app.':
        'Gestiona los contactos del dispositivo desde la app para Android o iPhone.',
    'Could not update device contacts right now.':
        'No se pudieron actualizar los contactos del dispositivo ahora mismo.',
    'Delete imported contacts?': '¿Eliminar contactos importados?',
    'Secretly will remove its contacts from this device address book and turn sync off.':
        'Secretly eliminará sus contactos de la agenda de este dispositivo y desactivará la sincronización.',
    'Cancel': 'Cancelar',
    'Last seen': 'Última vez',
    'Profile photos': 'Fotos del perfil',
    'Message forwards': 'Reenvío de mensajes',
    'Calls': 'Llamadas',
    'Voice messages': 'Mensajes de voz',
    'Messages': 'Mensajes',
    'New chats from strangers': 'Chats nuevos de desconocidos',
    'Archive and mute': 'Archivar y silenciar',
    'Delete my account': 'Eliminar mi cuenta',
    'Delete imported contacts': 'Eliminar contactos importados',
    'Sync contacts': 'Sincronizar contactos',
    'People suggestions in search': 'Sugerencias de personas en la búsqueda',
    'Discoverable by nickname': 'Visible por apodo',
    'Allow others to find you by nickname':
        'Permitir que otros te encuentren por apodo',
    'Privacy controls': 'Controles de privacidad',
    'Manage blocked users': 'Gestionar usuarios bloqueados',
    'Describe the issue first.': 'Describe el problema primero.',
    'Could not open mail app. Request text copied to clipboard.':
        'No se pudo abrir la app de correo. El texto de la solicitud se copió al portapapeles.',
    'Support contact form': 'Formulario de contacto con soporte',
    'Describe the issue and add contact details if needed. The technical information below is attached automatically.':
        'Describe el problema y añade datos de contacto si hace falta. La información técnica de abajo se adjunta automáticamente.',
    'Name': 'Nombre',
    'Email / Contact': 'Email / Contacto',
    'Describe the issue': 'Describe el problema',
    'Technical information': 'Información técnica',
    'This block is already attached to the request automatically.':
        'Este bloque ya se adjunta automáticamente a la solicitud.',
    'Send request': 'Enviar solicitud',
    'Could not open the Donorbox page in a browser.':
        'No se pudo abrir la página de Donorbox en un navegador.',
    'Could not open the Secretly website link.':
        'No se pudo abrir el enlace del sitio web de Secretly.',
    'Default chat wallpapers': 'Fondos de chat predeterminados',
    'Application color theme': 'Tema de color de la app',
    'Message bubble style': 'Estilo de burbujas de mensaje',
    'Names color in replies and quotes':
        'Color de nombres en respuestas y citas',
    'Contact': 'Contacto',
    'System errors': 'Errores del sistema',
    'Transport blocked': 'Transporte bloqueado',
    'System is operating normally': 'El sistema funciona con normalidad',
    'Support the project': 'Apoyar el proyecto',
    'Secretly is evolving as a private messenger focused on security, UX, and independent infrastructure. On Android and iPhone, the Donorbox page opens in a browser so Apple Pay and Google Pay stay available instead of disappearing inside an embedded WebView.':
        'Secretly evoluciona como un mensajero privado centrado en seguridad, UX e infraestructura independiente. En Android y iPhone, la página de Donorbox se abre en un navegador para que Apple Pay y Google Pay sigan disponibles en lugar de desaparecer dentro de un WebView integrado.',
    'Donorbox link copied': 'Enlace de Donorbox copiado',
    'Copy link': 'Copiar enlace',
    'Open in browser': 'Abrir en navegador',
    'Refresh': 'Actualizar',
    'Failed to load Donorbox.': 'No se pudo cargar Donorbox.',
    'Donorbox did not load right now': 'Donorbox no se cargó ahora',
    'Try again': 'Intentar de nuevo',
    'Apple Pay and Google Pay open in a browser':
        'Apple Pay y Google Pay se abren en un navegador',
    'Donorbox briefly renders the web-wallet buttons and then hides them inside the embedded WebView after environment checks. Opening the page in your browser keeps Apple Pay and Google Pay available.':
        'Donorbox muestra brevemente los botones de web-wallet y luego los oculta dentro del WebView integrado tras comprobar el entorno. Abrir la página en tu navegador mantiene Apple Pay y Google Pay disponibles.',
    'Open payment page': 'Abrir página de pago',
    'Embedded Donorbox is available on Android, iPhone, and macOS':
        'Donorbox integrado está disponible en Android, iPhone y macOS',
    'This platform currently uses a safe fallback. The campaign itself is already configured and the link is available below.':
        'Esta plataforma usa actualmente una alternativa segura. La campaña ya está configurada y el enlace está disponible abajo.',
  },
  _SettingsLocale.pt: {
    // Settings → Power (energy/heat), added 2026-08-01.
    'None of these affect message delivery, encryption or notifications — only how the app looks.': 'Nada disto afeta a entrega de mensagens, a encriptação ou as notificações — apenas o aspeto da aplicação.',
    'Power': 'Energia',
    'Less heat and battery drain': 'Menos calor e consumo de bateria',
    'Everything is on by default. Turn them off from the top down — the first one saves the most.': 'Tudo vem ativado por padrão. Desative de cima para baixo — o primeiro é o que mais economiza.',
    'Glass bubbles': 'Balões de vidro',
    'Incoming messages show the blurred wallpaper through them. It looks good, but keeps a blurred copy of the wallpaper alive the whole time a chat is open. Turn this off first if the phone gets hot.': 'As mensagens recebidas deixam ver o papel de parede desfocado através delas. Fica bonito, mas mantém uma cópia desfocada do papel de parede enquanto a conversa está aberta. Desative isto primeiro se o telefone aquecer.',
    'Frosted panels': 'Painéis foscos',
    'The blur under the chat header and the composer. The panels stay exactly where they are — the background behind them simply stops being blurred.': 'O desfoque sob o cabeçalho da conversa e o campo de escrita. Os painéis continuam onde estão — o fundo atrás deles apenas deixa de ser desfocado.',
    'Frame & status animations': 'Animação de molduras e estados',
    "Animate peers' premium frames and status emoji in chats and lists. Profiles always animate.": 'Animar as molduras premium e os emojis de estado dos contactos nas conversas e listas. Nos perfis a animação está sempre ativa.',
    'Nobody': 'Ninguém',
    'My contacts': 'Meus contatos',
    'Everybody': 'Todos',
    'Short': 'Curto',
    'Long': 'Longo',
    'System default': 'Padrão do sistema',
    'Off': 'Desativado',
    'Beacon': 'Beacon',
    'Chime': 'Chime',
    'Default': 'Padrão',
    'Hidden': 'Oculto',
    'Sender only': 'Somente remetente',
    'Sender + message': 'Remetente e mensagem',
    'Profile name': 'Nome do perfil',
    'Enter name': 'Digite o nome',
    'Save': 'Salvar',
    'Change name': 'Alterar nome',
    'Share profile': 'Compartilhar perfil',
    'Privacy policy': 'Política de privacidade',
    'What is stored locally': 'O que fica armazenado localmente',
    'Chat history and attachments are stored on your device in an encrypted database.':
        'O histórico de chats e anexos ficam no seu dispositivo em um banco de dados criptografado.',
    'What goes through the server': 'O que passa pelo servidor',
    'Servers process encrypted message delivery, TTL queues, and key-service operations. Message content is not stored in plaintext.':
        'Os servidores processam a entrega de mensagens criptografadas, filas TTL e operações do serviço de chaves. O conteúdo das mensagens não é armazenado em texto claro.',
    'Official version': 'Versão oficial',
    'The full Privacy Policy and Terms of Service are published on the official Secretly website.':
        'A Política de Privacidade e os Termos de Serviço completos estão publicados no site oficial do Secretly.',
    'Open Privacy Policy': 'Abrir Privacy Policy',
    'Open Terms of Service': 'Abrir Terms of Service',
    'About Secretly': 'Sobre o Secretly',
    'A messenger focused on E2EE, privacy, and reliable message delivery.':
        'Um mensageiro focado em E2EE, privacidade e entrega confiável de mensagens.',
    'Build': 'Build',
    'Official website': 'Site oficial',
    'Privacy Policy': 'Privacy Policy',
    'Terms of Service': 'Terms of Service',
    'Profile QR': 'QR do perfil',
    'Media & profile': 'Mídia e perfil',
    'Security': 'Segurança',
    'System message available': 'Há uma mensagem do sistema',
    'Invite friends': 'Convidar amigos',
    'Donate Secretly': 'Doar para o Secretly',
    'Support': 'Suporte',
    'Not set': 'Não definido',
    'About': 'Sobre',
    'Not added': 'Não adicionado',
    'About text': 'Texto sobre você',
    'Clear': 'Limpar',
    'Save this ID: it is required to restore your account and server backup.':
        'Salve este ID: ele é necessário para restaurar sua conta e o backup no servidor.',
    'Log out': 'Sair',
    'End session on this device': 'Encerrar sessão neste dispositivo',
    'Log out and clear local profile data on this device?':
        'Sair e limpar os dados locais do perfil neste dispositivo?',
    'Delete account': 'Excluir conta',
    'Delete server profile and local data':
        'Excluir perfil no servidor e dados locais',
    'Delete account?': 'Excluir conta?',
    'Your profile, keys, backups, message queues, and local data will be deleted. This cannot be undone.':
        'Seu perfil, chaves, backups, filas de mensagens e dados locais serão excluídos. Isso não pode ser desfeito.',
    'Delete': 'Excluir',
    'Deleting account...': 'Excluindo conta...',
    'Enabled': 'Ativado',
    'Disabled': 'Desativado',
    'Show notifications': 'Mostrar notificações',
    'All accounts': 'Todas as contas',
    'Private chats': 'Chats privados',
    'New messages': 'Novas mensagens',
    'Notify about new messages in private chats.':
        'Notificar sobre novas mensagens em chats privados.',
    'Message text': 'Texto da mensagem',
    'Show message text in private chat notifications.':
        'Mostrar o texto da mensagem nas notificações de chats privados.',
    'Name and photo': 'Nome e foto',
    'Show the contact name and photo in private chat notifications.':
        'Mostrar o nome e a foto do contato nas notificações de chats privados.',
    'Rooms': 'Salas',
    'Notify about new messages in rooms.':
        'Notificar sobre novas mensagens em salas.',
    'Show message text in room notifications.':
        'Mostrar o texto da mensagem nas notificações de salas.',
    'Show the sender name and photo in room notifications.':
        'Mostrar o nome e a foto do remetente nas notificações de salas.',
    'In-app calls': 'Chamadas no app',
    'Allow calls in the app': 'Permitir chamadas no app',
    'Incoming calls': 'Chamadas recebidas',
    'Allow incoming calls': 'Permitir chamadas recebidas',
    'Lock-screen call screen': 'Tela de chamada na tela bloqueada',
    'System permission enabled': 'Permissão do sistema ativada',
    'Enable this so calls can open over the lock screen':
        'Ative para que as chamadas possam abrir sobre a tela bloqueada',
    'Checking permission...': 'Verificando permissão...',
    'Screen sharing': 'Compartilhamento de tela',
    'Allow incoming screen-sharing calls':
        'Permitir chamadas recebidas com compartilhamento de tela',
    'Vibration': 'Vibração',
    'Ringtone': 'Toque',
    'Sound': 'Som',
    'Incoming sound': 'Som de entrada',
    'In-chat sound': 'Som no chat',
    'In-chat sound style': 'Estilo do som no chat',
    'Haptics': 'Resposta tátil',
    'Vibration for expanding categories, photos, and other in-app actions.':
        'Vibração ao expandir categorias, fotos e outras ações no app.',
    'Notification privacy': 'Privacidade das notificações',
    'Notification card': 'Cartão de notificação',
    'Show the system notification card while the app is in background.':
        'Mostrar o cartão de notificação do sistema enquanto o app está em segundo plano.',
    'Background connection': 'Conexão em segundo plano',
    'Keep a minimal connection while the app stays in memory. When the app is fully closed, delivery relies on push notifications.':
        'Manter uma conexão mínima enquanto o app permanecer na memória. Quando o app é totalmente fechado, a entrega depende de notificações push.',
    'Reset notification settings': 'Redefinir notificações',
    'Reset custom notification preferences.':
        'Redefinir preferências personalizadas de notificação.',
    'Reset settings': 'Redefinir configurações',
    'Reset notification settings to defaults?':
        'Redefinir as notificações para os padrões?',
    'Reset': 'Redefinir',
    'Work group • online': 'Grupo de trabalho • online',
    'Mira': 'Mira',
    'Forwarded from\nSMS: Courier\nDelivery at 7:30 PM, code 4821.':
        'Encaminhado de\nSMS: Entregador\nEntrega às 19:30, código 4821.',
    'You': 'Você',
    'Done. Updated the team.': 'Pronto. Atualizei a equipe.',
    'Forwarded from • SMS: Courier': 'Encaminhado de • SMS: Entregador',
    'Service': 'Serviço',
    'Okay. I can add a reminder if needed.':
        'Certo. Posso adicionar um lembrete se necessário.',
    'Chat wallpapers': 'Papéis de parede dos chats',
    'Open extended picker': 'Abrir seletor avançado',
    'Application themes': 'Temas do app',
    'Bubble colors': 'Cores das bolhas',
    'Nickname colors': 'Cores dos nomes',
    'Indicator colors': 'Cores dos indicadores',
    'You: got it': 'Você: recebido',
    'Mira: forwarded SMS': 'Mira: encaminhou SMS',
    'Chat behavior': 'Comportamento dos chats',
    'Show your profile QR code': 'Mostrar seu QR code do perfil',
    'QR scanner': 'Leitor de QR',
    'Scan a contact QR code': 'Escanear o QR code de um contato',
    'Personal chats': 'Chats pessoais',
    'Open your personal chat collection': 'Abrir sua coleção pessoal de chats',
    'Media privacy': 'Privacidade da mídia',
    'Profile media is visible only to you':
        'A mídia do perfil fica visível somente para você',
    'Syncing with your device address book':
        'Sincronizando com a agenda do dispositivo',
    'Available in the Android and iPhone app':
        'Disponível no app para Android e iPhone',
    'Keep Secretly contacts in your device address book':
        'Manter contatos do Secretly na agenda do dispositivo',
    'Do not save Secretly contacts to your device address book':
        'Não salvar contatos do Secretly na agenda do dispositivo',
    'Removal is available only in the mobile app':
        'A remoção está disponível apenas no app móvel',
    'Remove Secretly contacts from your address book and turn sync off':
        'Remover contatos do Secretly da sua agenda e desligar a sincronização',
    'Device contacts are already up to date.':
        'Os contatos do dispositivo já estão atualizados.',
    'Contact sync is turned off on this device.':
        'A sincronização de contatos está desligada neste dispositivo.',
    'No imported contacts were found. Sync is off.':
        'Nenhum contato importado foi encontrado. A sincronização está desligada.',
    'Allow contact access to manage your device address book.':
        'Permita acesso aos contatos para gerenciar a agenda do dispositivo.',
    'Manage device contacts from the Android or iPhone app.':
        'Gerencie contatos do dispositivo pelo app para Android ou iPhone.',
    'Could not update device contacts right now.':
        'Não foi possível atualizar os contatos do dispositivo agora.',
    'Delete imported contacts?': 'Excluir contatos importados?',
    'Secretly will remove its contacts from this device address book and turn sync off.':
        'O Secretly removerá seus contatos da agenda deste dispositivo e desligará a sincronização.',
    'Cancel': 'Cancelar',
    'Last seen': 'Visto por último',
    'Profile photos': 'Fotos do perfil',
    'Message forwards': 'Encaminhamentos de mensagens',
    'Calls': 'Chamadas',
    'Voice messages': 'Mensagens de voz',
    'Messages': 'Mensagens',
    'New chats from strangers': 'Novos chats de desconhecidos',
    'Archive and mute': 'Arquivar e silenciar',
    'Delete my account': 'Excluir minha conta',
    'Delete imported contacts': 'Excluir contatos importados',
    'Sync contacts': 'Sincronizar contatos',
    'People suggestions in search': 'Sugestões de pessoas na busca',
    'Discoverable by nickname': 'Encontrável pelo apelido',
    'Allow others to find you by nickname':
        'Permitir que outras pessoas encontrem você pelo apelido',
    'Privacy controls': 'Controles de privacidade',
    'Manage blocked users': 'Gerenciar usuários bloqueados',
    'Describe the issue first.': 'Descreva o problema primeiro.',
    'Could not open mail app. Request text copied to clipboard.':
        'Não foi possível abrir o app de email. O texto da solicitação foi copiado para a área de transferência.',
    'Support contact form': 'Formulário de contato do suporte',
    'Describe the issue and add contact details if needed. The technical information below is attached automatically.':
        'Descreva o problema e adicione dados de contato se necessário. As informações técnicas abaixo são anexadas automaticamente.',
    'Name': 'Nome',
    'Email / Contact': 'Email / contato',
    'Describe the issue': 'Descreva o problema',
    'Technical information': 'Informações técnicas',
    'This block is already attached to the request automatically.':
        'Este bloco já é anexado automaticamente à solicitação.',
    'Send request': 'Enviar solicitação',
    'Could not open the Donorbox page in a browser.':
        'Não foi possível abrir a página do Donorbox em um navegador.',
    'Could not open the Secretly website link.':
        'Não foi possível abrir o link do site do Secretly.',
    'Default chat wallpapers': 'Papéis de parede padrão dos chats',
    'Application color theme': 'Tema de cores do app',
    'Message bubble style': 'Estilo das bolhas de mensagem',
    'Names color in replies and quotes':
        'Cor dos nomes em respostas e citações',
    'Contact': 'Contato',
    'System errors': 'Erros do sistema',
    'Transport blocked': 'Transporte bloqueado',
    'System is operating normally': 'O sistema está operando normalmente',
    'Support the project': 'Apoiar o projeto',
    'Secretly is evolving as a private messenger focused on security, UX, and independent infrastructure. On Android and iPhone, the Donorbox page opens in a browser so Apple Pay and Google Pay stay available instead of disappearing inside an embedded WebView.':
        'O Secretly evolui como um mensageiro privado focado em segurança, UX e infraestrutura independente. No Android e no iPhone, a página do Donorbox abre em um navegador para que Apple Pay e Google Pay continuem disponíveis em vez de desaparecerem dentro de um WebView incorporado.',
    'Donorbox link copied': 'Link do Donorbox copiado',
    'Copy link': 'Copiar link',
    'Open in browser': 'Abrir no navegador',
    'Refresh': 'Atualizar',
    'Failed to load Donorbox.': 'Falha ao carregar o Donorbox.',
    'Donorbox did not load right now': 'O Donorbox não carregou agora',
    'Try again': 'Tentar novamente',
    'Apple Pay and Google Pay open in a browser':
        'Apple Pay e Google Pay abrem em um navegador',
    'Donorbox briefly renders the web-wallet buttons and then hides them inside the embedded WebView after environment checks. Opening the page in your browser keeps Apple Pay and Google Pay available.':
        'O Donorbox renderiza brevemente os botões de web-wallet e depois os oculta dentro do WebView incorporado após verificar o ambiente. Abrir a página no navegador mantém Apple Pay e Google Pay disponíveis.',
    'Open payment page': 'Abrir página de pagamento',
    'Embedded Donorbox is available on Android, iPhone, and macOS':
        'O Donorbox incorporado está disponível no Android, iPhone e macOS',
    'This platform currently uses a safe fallback. The campaign itself is already configured and the link is available below.':
        'Esta plataforma usa atualmente uma alternativa segura. A campanha já está configurada e o link está disponível abaixo.',
  },
  _SettingsLocale.fr: {
    // Settings → Power (energy/heat), added 2026-08-01.
    'None of these affect message delivery, encryption or notifications — only how the app looks.': "Rien de tout cela n'affecte la remise des messages, le chiffrement ni les notifications : uniquement l'apparence de l'application.",
    'Power': 'Énergie',
    'Less heat and battery drain': 'Moins de chaleur et de batterie consommée',
    'Everything is on by default. Turn them off from the top down — the first one saves the most.': 'Tout est activé par défaut. Désactivez de haut en bas : le premier économise le plus.',
    'Glass bubbles': 'Bulles en verre',
    'Incoming messages show the blurred wallpaper through them. It looks good, but keeps a blurred copy of the wallpaper alive the whole time a chat is open. Turn this off first if the phone gets hot.': "Les messages reçus laissent voir le fond d'écran flouté à travers eux. C'est joli, mais cela garde une copie floutée du fond d'écran en mémoire tant que la conversation est ouverte. Désactivez-le en premier si le téléphone chauffe.",
    'Frosted panels': 'Panneaux dépolis',
    'The blur under the chat header and the composer. The panels stay exactly where they are — the background behind them simply stops being blurred.': "Le flou sous l'en-tête de la conversation et sous le champ de saisie. Les panneaux restent exactement où ils sont : l'arrière-plan cesse simplement d'être flouté.",
    'Frame & status animations': 'Animation des cadres et des statuts',
    "Animate peers' premium frames and status emoji in chats and lists. Profiles always animate.": "Animer les cadres premium et les emojis de statut de vos contacts dans les conversations et les listes. Dans les profils, l'animation est toujours active.",
    'Nobody': 'Personne',
    'My contacts': 'Mes contacts',
    'Everybody': 'Tout le monde',
    'Short': 'Court',
    'Long': 'Long',
    'System default': 'Par défaut du système',
    'Off': 'Désactivé',
    'Beacon': 'Beacon',
    'Chime': 'Chime',
    'Default': 'Par défaut',
    'Hidden': 'Masqué',
    'Sender only': 'Expéditeur uniquement',
    'Sender + message': 'Expéditeur et message',
    'Profile name': 'Nom du profil',
    'Enter name': 'Saisir un nom',
    'Save': 'Enregistrer',
    'Change name': 'Modifier le nom',
    'Share profile': 'Partager le profil',
    'Privacy policy': 'Politique de confidentialité',
    'What is stored locally': 'Ce qui est stocké localement',
    'Chat history and attachments are stored on your device in an encrypted database.':
        'L’historique des chats et les pièces jointes sont stockés sur votre appareil dans une base chiffrée.',
    'What goes through the server': 'Ce qui passe par le serveur',
    'Servers process encrypted message delivery, TTL queues, and key-service operations. Message content is not stored in plaintext.':
        'Les serveurs traitent la livraison des messages chiffrés, les files TTL et les opérations du service de clés. Le contenu des messages n’est pas stocké en clair.',
    'Official version': 'Version officielle',
    'The full Privacy Policy and Terms of Service are published on the official Secretly website.':
        'La Politique de confidentialité et les Conditions d’utilisation complètes sont publiées sur le site officiel de Secretly.',
    'Open Privacy Policy': 'Ouvrir la Privacy Policy',
    'Open Terms of Service': 'Ouvrir les Terms of Service',
    'About Secretly': 'À propos de Secretly',
    'A messenger focused on E2EE, privacy, and reliable message delivery.':
        'Une messagerie axée sur l’E2EE, la confidentialité et la livraison fiable des messages.',
    'Build': 'Build',
    'Official website': 'Site officiel',
    'Privacy Policy': 'Privacy Policy',
    'Terms of Service': 'Terms of Service',
    'Profile QR': 'QR du profil',
    'Media & profile': 'Médias et profil',
    'Security': 'Sécurité',
    'System message available': 'Message système disponible',
    'Invite friends': 'Inviter des amis',
    'Donate Secretly': 'Faire un don à Secretly',
    'Support': 'Support',
    'Not set': 'Non défini',
    'About': 'À propos',
    'Not added': 'Non ajouté',
    'About text': 'Texte de présentation',
    'Clear': 'Effacer',
    'Save this ID: it is required to restore your account and server backup.':
        'Enregistrez cet ID : il est nécessaire pour restaurer votre compte et la sauvegarde serveur.',
    'Log out': 'Se déconnecter',
    'End session on this device': 'Terminer la session sur cet appareil',
    'Log out and clear local profile data on this device?':
        'Se déconnecter et effacer les données locales du profil sur cet appareil ?',
    'Delete account': 'Supprimer le compte',
    'Delete server profile and local data':
        'Supprimer le profil serveur et les données locales',
    'Delete account?': 'Supprimer le compte ?',
    'Your profile, keys, backups, message queues, and local data will be deleted. This cannot be undone.':
        'Votre profil, vos clés, vos sauvegardes, les files de messages et les données locales seront supprimés. Cette action est irréversible.',
    'Delete': 'Supprimer',
    'Deleting account...': 'Suppression du compte...',
    'Enabled': 'Activé',
    'Disabled': 'Désactivé',
    'Show notifications': 'Afficher les notifications',
    'All accounts': 'Tous les comptes',
    'Private chats': 'Chats privés',
    'New messages': 'Nouveaux messages',
    'Notify about new messages in private chats.':
        'Notifier les nouveaux messages dans les chats privés.',
    'Message text': 'Texte du message',
    'Show message text in private chat notifications.':
        'Afficher le texte du message dans les notifications des chats privés.',
    'Name and photo': 'Nom et photo',
    'Show the contact name and photo in private chat notifications.':
        'Afficher le nom et la photo du contact dans les notifications des chats privés.',
    'Rooms': 'Salons',
    'Notify about new messages in rooms.':
        'Notifier les nouveaux messages dans les salons.',
    'Show message text in room notifications.':
        'Afficher le texte du message dans les notifications des salons.',
    'Show the sender name and photo in room notifications.':
        'Afficher le nom et la photo de l’expéditeur dans les notifications des salons.',
    'In-app calls': 'Appels dans l’app',
    'Allow calls in the app': 'Autoriser les appels dans l’app',
    'Incoming calls': 'Appels entrants',
    'Allow incoming calls': 'Autoriser les appels entrants',
    'Lock-screen call screen': 'Écran d’appel sur écran verrouillé',
    'System permission enabled': 'Autorisation système activée',
    'Enable this so calls can open over the lock screen':
        'Activez ceci pour que les appels puissent s’ouvrir par-dessus l’écran verrouillé',
    'Checking permission...': 'Vérification de l’autorisation...',
    'Screen sharing': 'Partage d’écran',
    'Allow incoming screen-sharing calls':
        'Autoriser les appels entrants avec partage d’écran',
    'Vibration': 'Vibration',
    'Ringtone': 'Sonnerie',
    'Sound': 'Son',
    'Incoming sound': 'Son entrant',
    'In-chat sound': 'Son dans le chat',
    'In-chat sound style': 'Style du son dans le chat',
    'Haptics': 'Retour haptique',
    'Vibration for expanding categories, photos, and other in-app actions.':
        'Vibration lors de l’ouverture de catégories, de photos et d’autres actions dans l’app.',
    'Notification privacy': 'Confidentialité des notifications',
    'Notification card': 'Carte de notification',
    'Show the system notification card while the app is in background.':
        'Afficher la carte de notification système lorsque l’app est en arrière-plan.',
    'Background connection': 'Connexion en arrière-plan',
    'Keep a minimal connection while the app stays in memory. When the app is fully closed, delivery relies on push notifications.':
        'Maintenir une connexion minimale tant que l’app reste en mémoire. Lorsque l’app est complètement fermée, la livraison repose sur les notifications push.',
    'Reset notification settings': 'Réinitialiser les notifications',
    'Reset custom notification preferences.':
        'Réinitialiser les préférences de notification personnalisées.',
    'Reset settings': 'Réinitialiser les réglages',
    'Reset notification settings to defaults?':
        'Réinitialiser les notifications aux valeurs par défaut ?',
    'Reset': 'Réinitialiser',
    'Work group • online': 'Groupe de travail • en ligne',
    'Mira': 'Mira',
    'Forwarded from\nSMS: Courier\nDelivery at 7:30 PM, code 4821.':
        'Transféré depuis\nSMS : Coursier\nLivraison à 19:30, code 4821.',
    'You': 'Vous',
    'Done. Updated the team.': 'C’est fait. L’équipe est informée.',
    'Forwarded from • SMS: Courier': 'Transféré depuis • SMS : Coursier',
    'Service': 'Service',
    'Okay. I can add a reminder if needed.':
        'D’accord. Je peux ajouter un rappel si nécessaire.',
    'Chat wallpapers': 'Fonds de chat',
    'Open extended picker': 'Ouvrir le sélecteur étendu',
    'Application themes': 'Thèmes de l’app',
    'Bubble colors': 'Couleurs des bulles',
    'Nickname colors': 'Couleurs des noms',
    'Indicator colors': 'Couleurs d\'accent',
    'You: got it': 'Vous : reçu',
    'Mira: forwarded SMS': 'Mira : SMS transféré',
    'Chat behavior': 'Comportement des chats',
    'Show your profile QR code': 'Afficher votre QR de profil',
    'QR scanner': 'Scanner QR',
    'Scan a contact QR code': 'Scanner le QR d’un contact',
    'Personal chats': 'Chats personnels',
    'Open your personal chat collection':
        'Ouvrir votre collection personnelle de chats',
    'Media privacy': 'Confidentialité des médias',
    'Profile media is visible only to you':
        'Les médias du profil ne sont visibles que par vous',
    'Syncing with your device address book':
        'Synchronisation avec le carnet d’adresses de l’appareil',
    'Available in the Android and iPhone app':
        'Disponible dans l’app Android et iPhone',
    'Keep Secretly contacts in your device address book':
        'Conserver les contacts Secretly dans le carnet d’adresses de l’appareil',
    'Do not save Secretly contacts to your device address book':
        'Ne pas enregistrer les contacts Secretly dans le carnet d’adresses de l’appareil',
    'Removal is available only in the mobile app':
        'La suppression est disponible uniquement dans l’app mobile',
    'Remove Secretly contacts from your address book and turn sync off':
        'Supprimer les contacts Secretly de votre carnet d’adresses et désactiver la synchronisation',
    'Device contacts are already up to date.':
        'Les contacts de l’appareil sont déjà à jour.',
    'Contact sync is turned off on this device.':
        'La synchronisation des contacts est désactivée sur cet appareil.',
    'No imported contacts were found. Sync is off.':
        'Aucun contact importé trouvé. La synchronisation est désactivée.',
    'Allow contact access to manage your device address book.':
        'Autorisez l’accès aux contacts pour gérer le carnet d’adresses de l’appareil.',
    'Manage device contacts from the Android or iPhone app.':
        'Gérez les contacts de l’appareil depuis l’app Android ou iPhone.',
    'Could not update device contacts right now.':
        'Impossible de mettre à jour les contacts de l’appareil maintenant.',
    'Delete imported contacts?': 'Supprimer les contacts importés ?',
    'Secretly will remove its contacts from this device address book and turn sync off.':
        'Secretly supprimera ses contacts du carnet d’adresses de cet appareil et désactivera la synchronisation.',
    'Cancel': 'Annuler',
    'Last seen': 'Dernière présence',
    'Profile photos': 'Photos de profil',
    'Message forwards': 'Transferts de messages',
    'Calls': 'Appels',
    'Voice messages': 'Messages vocaux',
    'Messages': 'Messages',
    'New chats from strangers': 'Nouveaux chats d’inconnus',
    'Archive and mute': 'Archiver et couper le son',
    'Delete my account': 'Supprimer mon compte',
    'Delete imported contacts': 'Supprimer les contacts importés',
    'Sync contacts': 'Synchroniser les contacts',
    'People suggestions in search':
        'Suggestions de personnes dans la recherche',
    'Discoverable by nickname': 'Trouvable par pseudo',
    'Allow others to find you by nickname':
        'Autoriser les autres à vous trouver par pseudo',
    'Privacy controls': 'Contrôles de confidentialité',
    'Manage blocked users': 'Gérer les utilisateurs bloqués',
    'Describe the issue first.': 'Décrivez d’abord le problème.',
    'Could not open mail app. Request text copied to clipboard.':
        'Impossible d’ouvrir l’app de messagerie. Le texte de la demande a été copié dans le presse-papiers.',
    'Support contact form': 'Formulaire de contact du support',
    'Describe the issue and add contact details if needed. The technical information below is attached automatically.':
        'Décrivez le problème et ajoutez des coordonnées si nécessaire. Les informations techniques ci-dessous sont jointes automatiquement.',
    'Name': 'Nom',
    'Email / Contact': 'Email / Contact',
    'Describe the issue': 'Décrivez le problème',
    'Technical information': 'Informations techniques',
    'This block is already attached to the request automatically.':
        'Ce bloc est déjà joint automatiquement à la demande.',
    'Send request': 'Envoyer la demande',
    'Could not open the Donorbox page in a browser.':
        'Impossible d’ouvrir la page Donorbox dans un navigateur.',
    'Could not open the Secretly website link.':
        'Impossible d’ouvrir le lien du site Secretly.',
    'Default chat wallpapers': 'Fonds de chat par défaut',
    'Application color theme': 'Thème de couleur de l’app',
    'Message bubble style': 'Style des bulles de message',
    'Names color in replies and quotes':
        'Couleur des noms dans les réponses et citations',
    'Contact': 'Contact',
    'System errors': 'Erreurs système',
    'Transport blocked': 'Transport bloqué',
    'System is operating normally': 'Le système fonctionne normalement',
    'Support the project': 'Soutenir le projet',
    'Secretly is evolving as a private messenger focused on security, UX, and independent infrastructure. On Android and iPhone, the Donorbox page opens in a browser so Apple Pay and Google Pay stay available instead of disappearing inside an embedded WebView.':
        'Secretly évolue comme une messagerie privée centrée sur la sécurité, l’UX et une infrastructure indépendante. Sur Android et iPhone, la page Donorbox s’ouvre dans un navigateur afin qu’Apple Pay et Google Pay restent disponibles au lieu de disparaître dans un WebView intégré.',
    'Donorbox link copied': 'Lien Donorbox copié',
    'Copy link': 'Copier le lien',
    'Open in browser': 'Ouvrir dans le navigateur',
    'Refresh': 'Actualiser',
    'Failed to load Donorbox.': 'Impossible de charger Donorbox.',
    'Donorbox did not load right now':
        'Donorbox ne s’est pas chargé maintenant',
    'Try again': 'Réessayer',
    'Apple Pay and Google Pay open in a browser':
        'Apple Pay et Google Pay s’ouvrent dans un navigateur',
    'Donorbox briefly renders the web-wallet buttons and then hides them inside the embedded WebView after environment checks. Opening the page in your browser keeps Apple Pay and Google Pay available.':
        'Donorbox affiche brièvement les boutons web-wallet puis les masque dans le WebView intégré après les vérifications d’environnement. L’ouverture de la page dans votre navigateur garde Apple Pay et Google Pay disponibles.',
    'Open payment page': 'Ouvrir la page de paiement',
    'Embedded Donorbox is available on Android, iPhone, and macOS':
        'Donorbox intégré est disponible sur Android, iPhone et macOS',
    'This platform currently uses a safe fallback. The campaign itself is already configured and the link is available below.':
        'Cette plateforme utilise actuellement une solution de repli sûre. La campagne est déjà configurée et le lien est disponible ci-dessous.',
  },
  _SettingsLocale.de: {
    // Settings → Power (energy/heat), added 2026-08-01.
    'None of these affect message delivery, encryption or notifications — only how the app looks.': 'Nichts davon beeinflusst die Zustellung von Nachrichten, die Verschlüsselung oder die Benachrichtigungen — nur das Aussehen der App.',
    'Power': 'Energie',
    'Less heat and battery drain': 'Weniger Wärme und Akkuverbrauch',
    'Everything is on by default. Turn them off from the top down — the first one saves the most.': 'Alles ist standardmäßig aktiviert. Schalte von oben nach unten ab — der erste Punkt spart am meisten.',
    'Glass bubbles': 'Glasblasen',
    'Incoming messages show the blurred wallpaper through them. It looks good, but keeps a blurred copy of the wallpaper alive the whole time a chat is open. Turn this off first if the phone gets hot.': 'Eingehende Nachrichten zeigen das unscharfe Hintergrundbild durch sich hindurch. Das sieht gut aus, hält aber die ganze Zeit, in der ein Chat geöffnet ist, eine unscharfe Kopie des Hintergrundbilds bereit. Schalte das zuerst ab, wenn das Telefon warm wird.',
    'Frosted panels': 'Mattierte Leisten',
    'The blur under the chat header and the composer. The panels stay exactly where they are — the background behind them simply stops being blurred.': 'Die Unschärfe unter der Chat-Kopfzeile und dem Eingabefeld. Die Leisten bleiben genau dort, wo sie sind — der Hintergrund dahinter wird nur nicht mehr weichgezeichnet.',
    'Frame & status animations': 'Animation von Rahmen und Status',
    "Animate peers' premium frames and status emoji in chats and lists. Profiles always animate.": 'Premium-Rahmen und Status-Emojis deiner Kontakte in Chats und Listen animieren. In Profilen sind sie immer animiert.',
    'Nobody': 'Niemand',
    'My contacts': 'Meine Kontakte',
    'Everybody': 'Alle',
    'Short': 'Kurz',
    'Long': 'Lang',
    'System default': 'Systemstandard',
    'Off': 'Aus',
    'Beacon': 'Beacon',
    'Chime': 'Chime',
    'Default': 'Standard',
    'Hidden': 'Ausgeblendet',
    'Sender only': 'Nur Absender',
    'Sender + message': 'Absender und Nachricht',
    'Profile name': 'Profilname',
    'Enter name': 'Namen eingeben',
    'Save': 'Speichern',
    'Change name': 'Namen ändern',
    'Share profile': 'Profil teilen',
    'Privacy policy': 'Datenschutzrichtlinie',
    'What is stored locally': 'Was lokal gespeichert wird',
    'Chat history and attachments are stored on your device in an encrypted database.':
        'Chatverlauf und Anhänge werden auf deinem Gerät in einer verschlüsselten Datenbank gespeichert.',
    'What goes through the server': 'Was über den Server läuft',
    'Servers process encrypted message delivery, TTL queues, and key-service operations. Message content is not stored in plaintext.':
        'Server verarbeiten die Zustellung verschlüsselter Nachrichten, TTL-Warteschlangen und Schlüsselservice-Vorgänge. Nachrichteninhalte werden nicht im Klartext gespeichert.',
    'Official version': 'Offizielle Version',
    'The full Privacy Policy and Terms of Service are published on the official Secretly website.':
        'Die vollständige Privacy Policy und Terms of Service sind auf der offiziellen Secretly-Website veröffentlicht.',
    'Open Privacy Policy': 'Privacy Policy öffnen',
    'Open Terms of Service': 'Terms of Service öffnen',
    'About Secretly': 'Über Secretly',
    'A messenger focused on E2EE, privacy, and reliable message delivery.':
        'Ein Messenger mit Fokus auf E2EE, Datenschutz und zuverlässige Nachrichtenzustellung.',
    'Build': 'Build',
    'Official website': 'Offizielle Website',
    'Privacy Policy': 'Privacy Policy',
    'Terms of Service': 'Terms of Service',
    'Profile QR': 'Profil-QR',
    'Media & profile': 'Medien und Profil',
    'Security': 'Sicherheit',
    'System message available': 'Systemmeldung verfügbar',
    'Invite friends': 'Freunde einladen',
    'Donate Secretly': 'Secretly unterstützen',
    'Support': 'Support',
    'Not set': 'Nicht festgelegt',
    'About': 'Über mich',
    'Not added': 'Nicht hinzugefügt',
    'About text': 'Über-mich-Text',
    'Clear': 'Leeren',
    'Save this ID: it is required to restore your account and server backup.':
        'Speichere diese ID: Sie wird benötigt, um dein Konto und das Server-Backup wiederherzustellen.',
    'Log out': 'Abmelden',
    'End session on this device': 'Sitzung auf diesem Gerät beenden',
    'Log out and clear local profile data on this device?':
        'Abmelden und lokale Profildaten auf diesem Gerät löschen?',
    'Delete account': 'Konto löschen',
    'Delete server profile and local data':
        'Serverprofil und lokale Daten löschen',
    'Delete account?': 'Konto löschen?',
    'Your profile, keys, backups, message queues, and local data will be deleted. This cannot be undone.':
        'Dein Profil, Schlüssel, Backups, Nachrichtenwarteschlangen und lokale Daten werden gelöscht. Dies kann nicht rückgängig gemacht werden.',
    'Delete': 'Löschen',
    'Deleting account...': 'Konto wird gelöscht...',
    'Enabled': 'Aktiviert',
    'Disabled': 'Deaktiviert',
    'Show notifications': 'Benachrichtigungen anzeigen',
    'All accounts': 'Alle Konten',
    'Private chats': 'Private Chats',
    'New messages': 'Neue Nachrichten',
    'Notify about new messages in private chats.':
        'Über neue Nachrichten in privaten Chats benachrichtigen.',
    'Message text': 'Nachrichtentext',
    'Show message text in private chat notifications.':
        'Nachrichtentext in Benachrichtigungen privater Chats anzeigen.',
    'Name and photo': 'Name und Foto',
    'Show the contact name and photo in private chat notifications.':
        'Kontaktname und Foto in Benachrichtigungen privater Chats anzeigen.',
    'Rooms': 'Räume',
    'Notify about new messages in rooms.':
        'Über neue Nachrichten in Räumen benachrichtigen.',
    'Show message text in room notifications.':
        'Nachrichtentext in Raumbenachrichtigungen anzeigen.',
    'Show the sender name and photo in room notifications.':
        'Absendername und Foto in Raumbenachrichtigungen anzeigen.',
    'In-app calls': 'Anrufe in der App',
    'Allow calls in the app': 'Anrufe in der App erlauben',
    'Incoming calls': 'Eingehende Anrufe',
    'Allow incoming calls': 'Eingehende Anrufe erlauben',
    'Lock-screen call screen': 'Anrufbildschirm auf Sperrbildschirm',
    'System permission enabled': 'Systemberechtigung aktiviert',
    'Enable this so calls can open over the lock screen':
        'Aktiviere dies, damit Anrufe über dem Sperrbildschirm geöffnet werden können',
    'Checking permission...': 'Berechtigung wird geprüft...',
    'Screen sharing': 'Bildschirmfreigabe',
    'Allow incoming screen-sharing calls':
        'Eingehende Anrufe mit Bildschirmfreigabe erlauben',
    'Vibration': 'Vibration',
    'Ringtone': 'Klingelton',
    'Sound': 'Ton',
    'Incoming sound': 'Eingangston',
    'In-chat sound': 'Chat-Ton',
    'In-chat sound style': 'Chat-Tonstil',
    'Haptics': 'Haptik',
    'Vibration for expanding categories, photos, and other in-app actions.':
        'Vibration beim Öffnen von Kategorien, Fotos und anderen Aktionen in der App.',
    'Notification privacy': 'Benachrichtigungs-Privatsphäre',
    'Notification card': 'Benachrichtigungskarte',
    'Show the system notification card while the app is in background.':
        'System-Benachrichtigungskarte anzeigen, während die App im Hintergrund ist.',
    'Background connection': 'Hintergrundverbindung',
    'Keep a minimal connection while the app stays in memory. When the app is fully closed, delivery relies on push notifications.':
        'Eine minimale Verbindung halten, solange die App im Speicher bleibt. Wenn die App vollständig geschlossen ist, erfolgt die Zustellung über Push-Benachrichtigungen.',
    'Reset notification settings':
        'Benachrichtigungseinstellungen zurücksetzen',
    'Reset custom notification preferences.':
        'Benutzerdefinierte Benachrichtigungseinstellungen zurücksetzen.',
    'Reset settings': 'Einstellungen zurücksetzen',
    'Reset notification settings to defaults?':
        'Benachrichtigungseinstellungen auf Standardwerte zurücksetzen?',
    'Reset': 'Zurücksetzen',
    'Work group • online': 'Arbeitsgruppe • online',
    'Mira': 'Mira',
    'Forwarded from\nSMS: Courier\nDelivery at 7:30 PM, code 4821.':
        'Weitergeleitet von\nSMS: Kurier\nLieferung um 19:30, Code 4821.',
    'You': 'Du',
    'Done. Updated the team.': 'Erledigt. Team informiert.',
    'Forwarded from • SMS: Courier': 'Weitergeleitet von • SMS: Kurier',
    'Service': 'Service',
    'Okay. I can add a reminder if needed.':
        'Okay. Ich kann bei Bedarf eine Erinnerung hinzufügen.',
    'Chat wallpapers': 'Chat-Hintergründe',
    'Open extended picker': 'Erweiterte Auswahl öffnen',
    'Application themes': 'App-Designs',
    'Bubble colors': 'Blasenfarben',
    'Nickname colors': 'Namensfarben',
    'Indicator colors': 'Akzentfarben',
    'You: got it': 'Du: verstanden',
    'Mira: forwarded SMS': 'Mira: SMS weitergeleitet',
    'Chat behavior': 'Chat-Verhalten',
    'Show your profile QR code': 'Deinen Profil-QR-Code anzeigen',
    'QR scanner': 'QR-Scanner',
    'Scan a contact QR code': 'QR-Code eines Kontakts scannen',
    'Personal chats': 'Persönliche Chats',
    'Open your personal chat collection':
        'Deine persönliche Chat-Sammlung öffnen',
    'Media privacy': 'Medien-Privatsphäre',
    'Profile media is visible only to you':
        'Profilmedien sind nur für dich sichtbar',
    'Syncing with your device address book':
        'Synchronisierung mit dem Adressbuch deines Geräts',
    'Available in the Android and iPhone app':
        'Verfügbar in der Android- und iPhone-App',
    'Keep Secretly contacts in your device address book':
        'Secretly-Kontakte im Adressbuch deines Geräts speichern',
    'Do not save Secretly contacts to your device address book':
        'Secretly-Kontakte nicht im Adressbuch deines Geräts speichern',
    'Removal is available only in the mobile app':
        'Entfernen ist nur in der mobilen App verfügbar',
    'Remove Secretly contacts from your address book and turn sync off':
        'Secretly-Kontakte aus deinem Adressbuch entfernen und Synchronisierung deaktivieren',
    'Device contacts are already up to date.':
        'Gerätekontakte sind bereits aktuell.',
    'Contact sync is turned off on this device.':
        'Kontaktsynchronisierung ist auf diesem Gerät deaktiviert.',
    'No imported contacts were found. Sync is off.':
        'Keine importierten Kontakte gefunden. Synchronisierung ist aus.',
    'Allow contact access to manage your device address book.':
        'Erlaube Kontaktzugriff, um das Adressbuch deines Geräts zu verwalten.',
    'Manage device contacts from the Android or iPhone app.':
        'Verwalte Gerätekontakte über die Android- oder iPhone-App.',
    'Could not update device contacts right now.':
        'Gerätekontakte konnten gerade nicht aktualisiert werden.',
    'Delete imported contacts?': 'Importierte Kontakte löschen?',
    'Secretly will remove its contacts from this device address book and turn sync off.':
        'Secretly entfernt seine Kontakte aus dem Adressbuch dieses Geräts und deaktiviert die Synchronisierung.',
    'Cancel': 'Abbrechen',
    'Last seen': 'Zuletzt gesehen',
    'Profile photos': 'Profilfotos',
    'Message forwards': 'Nachrichtenweiterleitungen',
    'Calls': 'Anrufe',
    'Voice messages': 'Sprachnachrichten',
    'Messages': 'Nachrichten',
    'New chats from strangers': 'Neue Chats von Fremden',
    'Archive and mute': 'Archivieren und stummschalten',
    'Delete my account': 'Mein Konto löschen',
    'Delete imported contacts': 'Importierte Kontakte löschen',
    'Sync contacts': 'Kontakte synchronisieren',
    'People suggestions in search': 'Personenvorschläge in der Suche',
    'Discoverable by nickname': 'Per Nickname auffindbar',
    'Allow others to find you by nickname':
        'Anderen erlauben, dich per Nickname zu finden',
    'Privacy controls': 'Datenschutzsteuerung',
    'Manage blocked users': 'Blockierte Benutzer verwalten',
    'Describe the issue first.': 'Beschreibe zuerst das Problem.',
    'Could not open mail app. Request text copied to clipboard.':
        'Mail-App konnte nicht geöffnet werden. Der Anfrage-Text wurde in die Zwischenablage kopiert.',
    'Support contact form': 'Support-Kontaktformular',
    'Describe the issue and add contact details if needed. The technical information below is attached automatically.':
        'Beschreibe das Problem und füge bei Bedarf Kontaktdaten hinzu. Die technischen Informationen unten werden automatisch angehängt.',
    'Name': 'Name',
    'Email / Contact': 'E-Mail / Kontakt',
    'Describe the issue': 'Problem beschreiben',
    'Technical information': 'Technische Informationen',
    'This block is already attached to the request automatically.':
        'Dieser Block wird der Anfrage bereits automatisch angehängt.',
    'Send request': 'Anfrage senden',
    'Could not open the Donorbox page in a browser.':
        'Donorbox-Seite konnte nicht im Browser geöffnet werden.',
    'Could not open the Secretly website link.':
        'Link zur Secretly-Website konnte nicht geöffnet werden.',
    'Default chat wallpapers': 'Standard-Chat-Hintergründe',
    'Application color theme': 'Farbdesign der App',
    'Message bubble style': 'Nachrichtenblasen-Stil',
    'Names color in replies and quotes': 'Namensfarbe in Antworten und Zitaten',
    'Contact': 'Kontakt',
    'System errors': 'Systemfehler',
    'Transport blocked': 'Transport blockiert',
    'System is operating normally': 'System arbeitet normal',
    'Support the project': 'Projekt unterstützen',
    'Secretly is evolving as a private messenger focused on security, UX, and independent infrastructure. On Android and iPhone, the Donorbox page opens in a browser so Apple Pay and Google Pay stay available instead of disappearing inside an embedded WebView.':
        'Secretly entwickelt sich als privater Messenger mit Fokus auf Sicherheit, UX und unabhängige Infrastruktur. Auf Android und iPhone wird die Donorbox-Seite im Browser geöffnet, damit Apple Pay und Google Pay verfügbar bleiben, statt in einem eingebetteten WebView zu verschwinden.',
    'Donorbox link copied': 'Donorbox-Link kopiert',
    'Copy link': 'Link kopieren',
    'Open in browser': 'Im Browser öffnen',
    'Refresh': 'Aktualisieren',
    'Failed to load Donorbox.': 'Donorbox konnte nicht geladen werden.',
    'Donorbox did not load right now': 'Donorbox wurde gerade nicht geladen',
    'Try again': 'Erneut versuchen',
    'Apple Pay and Google Pay open in a browser':
        'Apple Pay und Google Pay öffnen im Browser',
    'Donorbox briefly renders the web-wallet buttons and then hides them inside the embedded WebView after environment checks. Opening the page in your browser keeps Apple Pay and Google Pay available.':
        'Donorbox zeigt die Web-Wallet-Schaltflächen kurz an und blendet sie nach Umgebungsprüfungen im eingebetteten WebView aus. Wenn du die Seite im Browser öffnest, bleiben Apple Pay und Google Pay verfügbar.',
    'Open payment page': 'Zahlungsseite öffnen',
    'Embedded Donorbox is available on Android, iPhone, and macOS':
        'Eingebettetes Donorbox ist auf Android, iPhone und macOS verfügbar',
    'This platform currently uses a safe fallback. The campaign itself is already configured and the link is available below.':
        'Diese Plattform verwendet derzeit eine sichere Ausweichlösung. Die Kampagne selbst ist bereits eingerichtet und der Link ist unten verfügbar.',
  },
};
