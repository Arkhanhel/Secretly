// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
import 'package:flutter/widgets.dart';

String callHistoryLocaleTagFromContext(BuildContext context) {
  final locale = Localizations.localeOf(context);
  return callHistoryLocaleTag(
    locale.languageCode,
    countryCode: locale.countryCode,
  );
}

String callHistoryLocaleTag(String languageCode, {String? countryCode}) {
  final language = languageCode.trim().toLowerCase();
  final country = (countryCode ?? '').trim().toUpperCase();
  if (language == 'pt' && country == 'BR') return 'pt_BR';
  if (language == 'pt') return 'pt';
  if (<String>{'de', 'en', 'es', 'fr', 'ru', 'uk'}.contains(language)) {
    return language;
  }
  return 'en';
}

bool callHistoryLocaleIsRussian(BuildContext context) {
  return callHistoryLocaleTagFromContext(context) == 'ru';
}

String callHistoryText(
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
  return callHistoryTextForLocale(
    callHistoryLocaleTagFromContext(context),
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

String callHistoryTextForLocale(
  String localeTag, {
  required String ru,
  required String en,
  String? uk,
  String? es,
  String? pt,
  String? ptBr,
  String? fr,
  String? de,
}) {
  final direct = switch (localeTag) {
    'ru' => ru,
    'uk' => uk,
    'es' => es,
    'pt' => pt,
    'pt_BR' => ptBr ?? pt,
    'fr' => fr,
    'de' => de,
    _ => en,
  };
  if (direct != null) return direct;
  final mapped = _callHistoryTextTranslations[en];
  if (mapped == null) return en;
  return mapped[localeTag] ??
      (localeTag == 'pt_BR' ? mapped['pt'] : null) ??
      en;
}

String callHistoryMonthLabel(BuildContext context, int month) {
  final idx = month.clamp(1, 12) - 1;
  final localeTag = callHistoryLocaleTagFromContext(context);
  final months = switch (localeTag) {
    'ru' => _monthsRu,
    'uk' => _monthsUk,
    'es' => _monthsEs,
    'pt' || 'pt_BR' => _monthsPt,
    'fr' => _monthsFr,
    'de' => _monthsDe,
    _ => _monthsEn,
  };
  return months[idx];
}

String callHistoryTotalMissedText(
  BuildContext context, {
  required int total,
  required int missed,
}) {
  return callHistoryText(
    context,
    ru: 'Всего звонков: $total · Пропущено: $missed',
    en: 'Total calls: $total · Missed: $missed',
    uk: 'Усього дзвінків: $total · Пропущено: $missed',
    es: 'Total de llamadas: $total · Perdidas: $missed',
    pt: 'Total de chamadas: $total · Perdidas: $missed',
    ptBr: 'Total de chamadas: $total · Perdidas: $missed',
    fr: 'Total des appels : $total · Manqués : $missed',
    de: 'Anrufe gesamt: $total · Verpasst: $missed',
  );
}

const _monthsRu = <String>[
  'янв',
  'фев',
  'мар',
  'апр',
  'мая',
  'июн',
  'июл',
  'авг',
  'сен',
  'окт',
  'ноя',
  'дек',
];

const _monthsUk = <String>[
  'січ',
  'лют',
  'бер',
  'кві',
  'тра',
  'чер',
  'лип',
  'сер',
  'вер',
  'жов',
  'лис',
  'гру',
];

const _monthsEn = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const _monthsEs = <String>[
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sept',
  'oct',
  'nov',
  'dic',
];

const _monthsPt = <String>[
  'jan',
  'fev',
  'mar',
  'abr',
  'mai',
  'jun',
  'jul',
  'ago',
  'set',
  'out',
  'nov',
  'dez',
];

const _monthsFr = <String>[
  'janv.',
  'févr.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juil.',
  'août',
  'sept.',
  'oct.',
  'nov.',
  'déc.',
];

const _monthsDe = <String>[
  'Jan.',
  'Feb.',
  'März',
  'Apr.',
  'Mai',
  'Juni',
  'Juli',
  'Aug.',
  'Sept.',
  'Okt.',
  'Nov.',
  'Dez.',
];

const Map<String, Map<String, String>> _callHistoryTextTranslations = {
  'Unknown contact': {
    'uk': 'Невідомий контакт',
    'es': 'Contacto desconocido',
    'pt': 'Contato desconhecido',
    'fr': 'Contact inconnu',
    'de': 'Unbekannter Kontakt',
  },
  'Calls': {
    'uk': 'Дзвінки',
    'es': 'Llamadas',
    'pt': 'Chamadas',
    'fr': 'Appels',
    'de': 'Anrufe',
  },
  'All': {
    'uk': 'Усі',
    'es': 'Todas',
    'pt': 'Todas',
    'fr': 'Tous',
    'de': 'Alle',
  },
  'Missed': {
    'uk': 'Пропущені',
    'es': 'Perdidas',
    'pt': 'Perdidas',
    'fr': 'Manqués',
    'de': 'Verpasst',
  },
  'Video': {
    'uk': 'Відео',
    'es': 'Video',
    'pt': 'Vídeo',
    'fr': 'Vidéo',
    'de': 'Video',
  },
  'Today': {
    'uk': 'Сьогодні',
    'es': 'Hoy',
    'pt': 'Hoje',
    'fr': 'Aujourd\'hui',
    'de': 'Heute',
  },
  'Yesterday': {
    'uk': 'Учора',
    'es': 'Ayer',
    'pt': 'Ontem',
    'fr': 'Hier',
    'de': 'Gestern',
  },
  'Connection error': {
    'uk': 'Помилка з\'єднання',
    'es': 'Error de conexión',
    'pt': 'Erro de conexão',
    'fr': 'Erreur de connexion',
    'de': 'Verbindungsfehler',
  },
  'Call ended': {
    'uk': 'Дзвінок завершено',
    'es': 'Llamada finalizada',
    'pt': 'Chamada encerrada',
    'fr': 'Appel terminé',
    'de': 'Anruf beendet',
  },
  'Superseded by newer attempt': {
    'uk': 'Замінено новішою спробою',
    'es': 'Reemplazado por un intento más reciente',
    'pt': 'Substituída por uma tentativa mais recente',
    'fr': 'Remplacé par une tentative plus récente',
    'de': 'Durch neueren Versuch ersetzt',
  },
  'Call declined': {
    'uk': 'Дзвінок відхилено',
    'es': 'Llamada rechazada',
    'pt': 'Chamada recusada',
    'fr': 'Appel refusé',
    'de': 'Anruf abgelehnt',
  },
  'You declined': {
    'uk': 'Ви відхилили',
    'es': 'Has rechazado',
    'pt': 'Você recusou',
    'fr': 'Vous avez refusé',
    'de': 'Sie haben abgelehnt',
  },
  'No answer': {
    'uk': 'Немає відповіді',
    'es': 'Sin respuesta',
    'pt': 'Sem resposta',
    'fr': 'Pas de réponse',
    'de': 'Keine Antwort',
  },
  'Quality: excellent': {
    'uk': 'Якість: відмінна',
    'es': 'Calidad: excelente',
    'pt': 'Qualidade: excelente',
    'fr': 'Qualité : excellente',
    'de': 'Qualität: ausgezeichnet',
  },
  'Quality: good': {
    'uk': 'Якість: добра',
    'es': 'Calidad: buena',
    'pt': 'Qualidade: boa',
    'fr': 'Qualité : bonne',
    'de': 'Qualität: gut',
  },
  'Quality: fair': {
    'uk': 'Якість: середня',
    'es': 'Calidad: regular',
    'pt': 'Qualidade: razoável',
    'fr': 'Qualité : moyenne',
    'de': 'Qualität: mittel',
  },
  'Quality: poor': {
    'uk': 'Якість: погана',
    'es': 'Calidad: mala',
    'pt': 'Qualidade: ruim',
    'fr': 'Qualité : mauvaise',
    'de': 'Qualität: schlecht',
  },
  'Jitter': {
    'uk': 'Джитер',
    'es': 'Jitter',
    'pt': 'Jitter',
    'fr': 'Gigue',
    'de': 'Jitter',
  },
  'Loss': {
    'uk': 'Втрати',
    'es': 'Pérdida',
    'pt': 'Perda',
    'fr': 'Perte',
    'de': 'Verlust',
  },
  'Type': {'uk': 'Тип', 'es': 'Tipo', 'pt': 'Tipo', 'fr': 'Type', 'de': 'Typ'},
  'Reason': {
    'uk': 'Причина',
    'es': 'Motivo',
    'pt': 'Motivo',
    'fr': 'Raison',
    'de': 'Grund',
  },
  'Started': {
    'uk': 'Початок',
    'es': 'Inicio',
    'pt': 'Início',
    'fr': 'Début',
    'de': 'Beginn',
  },
  'Ended': {
    'uk': 'Завершення',
    'es': 'Fin',
    'pt': 'Fim',
    'fr': 'Fin',
    'de': 'Ende',
  },
  'Duration': {
    'uk': 'Тривалість',
    'es': 'Duración',
    'pt': 'Duração',
    'fr': 'Durée',
    'de': 'Dauer',
  },
  'Quality': {
    'uk': 'Якість',
    'es': 'Calidad',
    'pt': 'Qualidade',
    'fr': 'Qualité',
    'de': 'Qualität',
  },
  'Open call diagnostics': {
    'uk': 'Відкрити діагностику дзвінків',
    'es': 'Abrir diagnóstico de llamadas',
    'pt': 'Abrir diagnósticos de chamadas',
    'fr': 'Ouvrir le diagnostic des appels',
    'de': 'Anrufdiagnose öffnen',
  },
  'Open chat': {
    'uk': 'Відкрити чат',
    'es': 'Abrir chat',
    'pt': 'Abrir chat',
    'fr': 'Ouvrir le chat',
    'de': 'Chat öffnen',
  },
  'Call back': {
    'uk': 'Передзвонити',
    'es': 'Devolver llamada',
    'pt': 'Ligar de volta',
    'fr': 'Rappeler',
    'de': 'Zurückrufen',
  },
  'Call history': {
    'uk': 'Історія дзвінків',
    'es': 'Historial de llamadas',
    'pt': 'Histórico de chamadas',
    'fr': 'Historique des appels',
    'de': 'Anrufverlauf',
  },
  'No call history yet': {
    'uk': 'Історія дзвінків поки порожня',
    'es': 'Aún no hay historial de llamadas',
    'pt': 'Ainda não há histórico de chamadas',
    'fr': 'Aucun historique d\'appels pour le moment',
    'de': 'Noch kein Anrufverlauf',
  },
  'No entries for the selected filter': {
    'uk': 'Немає записів для вибраного фільтра',
    'es': 'No hay entradas para el filtro seleccionado',
    'pt': 'Nenhum registro para o filtro selecionado',
    'fr': 'Aucune entrée pour le filtre sélectionné',
    'de': 'Keine Einträge für den ausgewählten Filter',
  },
  'Details': {
    'uk': 'Деталі',
    'es': 'Detalles',
    'pt': 'Detalhes',
    'fr': 'Détails',
    'de': 'Details',
  },
};
