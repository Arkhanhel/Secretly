// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
String buildSupportTechnicalInfo({
  required String buildMarker,
  required String deviceId,
  required String profileId,
  Iterable<String> additionalLines = const <String>[],
}) {
  return <String>[
    'Build marker: ${buildMarker.trim()}',
    'Device ID: ${deviceId.trim()}',
    'Profile ID: ${profileId.trim()}',
    ...additionalLines,
  ].join('\n');
}

String buildSupportRequestPayload({
  required String message,
  required String technicalInfo,
  String? name,
  String? email,
}) {
  final normalizedMessage = message.trim();
  final normalizedTechnicalInfo = technicalInfo.trim();
  final normalizedName = name?.trim() ?? '';
  final normalizedEmail = email?.trim() ?? '';

  return <String>[
    'Secretly Support Request',
    if (normalizedName.isNotEmpty) 'Name: $normalizedName',
    if (normalizedEmail.isNotEmpty) 'Email: $normalizedEmail',
    '',
    'Message:',
    normalizedMessage,
    '',
    'Technical info:',
    normalizedTechnicalInfo,
  ].join('\n');
}

String buildAbuseReportPayload({
  required String targetType,
  required String targetId,
  required String reasonCode,
  required String reasonLabel,
  required String technicalInfo,
  String? targetTitle,
  String? conversationId,
  String? details,
  DateTime? generatedAtUtc,
}) {
  final normalizedTargetType = targetType.trim();
  final normalizedTargetId = targetId.trim();
  final normalizedTargetTitle = targetTitle?.trim() ?? '';
  final normalizedConversationId = conversationId?.trim() ?? '';
  final normalizedReasonCode = reasonCode.trim();
  final normalizedReasonLabel = reasonLabel.trim();
  final normalizedDetails = details?.trim() ?? '';
  final normalizedTechnicalInfo = technicalInfo.trim();
  final generatedAt = (generatedAtUtc ?? DateTime.now().toUtc()).toUtc();

  return <String>[
    'Secretly Abuse Report',
    'Generated at UTC: ${generatedAt.toIso8601String()}',
    '',
    'Target:',
    'Type: $normalizedTargetType',
    'ID: $normalizedTargetId',
    if (normalizedTargetTitle.isNotEmpty) 'Title: $normalizedTargetTitle',
    if (normalizedConversationId.isNotEmpty)
      'Conversation ID: $normalizedConversationId',
    '',
    'Reason:',
    'Code: $normalizedReasonCode',
    'Label: $normalizedReasonLabel',
    '',
    'Details:',
    normalizedDetails.isEmpty ? '(none provided)' : normalizedDetails,
    '',
    'Technical info:',
    normalizedTechnicalInfo,
  ].join('\n');
}
