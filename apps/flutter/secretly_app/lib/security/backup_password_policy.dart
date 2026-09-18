// SPDX-License-Identifier: AGPL-3.0-only
// SPDX-FileCopyrightText: 2025-2026 Yurii Arkhanhelskyi
// Additional permission under AGPL-3.0 section 7: see LICENSE-EXCEPTION.
enum BackupPasswordProblem {
  tooShort,
  tooLong,
  nonAscii,
  outerWhitespace,
  missingUppercase,
  missingSpecial,
}

class BackupPasswordValidation {
  const BackupPasswordValidation(this.problems);

  final List<BackupPasswordProblem> problems;

  bool get isValid => problems.isEmpty;
}

class BackupPasswordPolicy {
  static const minLength = 8;
  static const maxLength = 128;
  static const _specialChars = r'''!@#$%^&*()_+-=[]{};':"\|,.<>/?''';

  static BackupPasswordValidation validate(String password) {
    final problems = <BackupPasswordProblem>[];
    if (password.length < minLength) {
      problems.add(BackupPasswordProblem.tooShort);
    }
    if (password.length > maxLength) {
      problems.add(BackupPasswordProblem.tooLong);
    }
    if (!_isPrintableAscii(password)) {
      problems.add(BackupPasswordProblem.nonAscii);
    }
    if (password != password.trim()) {
      problems.add(BackupPasswordProblem.outerWhitespace);
    }
    if (!password.contains(RegExp('[A-Z]'))) {
      problems.add(BackupPasswordProblem.missingUppercase);
    }
    if (!password.runes.any((rune) => _specialChars.containsCharCode(rune))) {
      problems.add(BackupPasswordProblem.missingSpecial);
    }
    return BackupPasswordValidation(List.unmodifiable(problems));
  }

  static void validateOrThrow(String password) {
    final validation = validate(password);
    if (validation.isValid) return;
    throw StateError(validation.problemText(isRu: false));
  }

  static bool _isPrintableAscii(String value) {
    for (final rune in value.runes) {
      if (rune < 0x20 || rune > 0x7e) return false;
    }
    return true;
  }

  static String requirementsText({required bool isRu}) {
    if (isRu) {
      return 'Минимум 8 символов, латиница/ASCII, одна заглавная буква и один спецсимвол. Без пробелов в начале или конце.';
    }
    return 'Use at least 8 ASCII characters, one uppercase letter, and one special character. No leading or trailing spaces.';
  }

  static String problemText(
    BackupPasswordProblem problem, {
    required bool isRu,
  }) {
    switch (problem) {
      case BackupPasswordProblem.tooShort:
        if (isRu) return 'Пароль должен быть не короче $minLength символов.';
        return 'Password must be at least $minLength characters.';
      case BackupPasswordProblem.tooLong:
        if (isRu) return 'Пароль должен быть не длиннее $maxLength символов.';
        return 'Password must be no longer than $maxLength characters.';
      case BackupPasswordProblem.nonAscii:
        if (isRu) return 'Используйте только латиницу, цифры и ASCII-символы.';
        return 'Use only Latin letters, digits, and ASCII symbols.';
      case BackupPasswordProblem.outerWhitespace:
        if (isRu) return 'Уберите пробелы в начале или конце пароля.';
        return 'Remove leading or trailing spaces from the password.';
      case BackupPasswordProblem.missingUppercase:
        if (isRu) return 'Добавьте хотя бы одну заглавную букву A-Z.';
        return 'Add at least one uppercase A-Z letter.';
      case BackupPasswordProblem.missingSpecial:
        if (isRu) {
          return 'Добавьте хотя бы один спецсимвол, например !, # или ?.';
        }
        return 'Add at least one special character, such as !, #, or ?.';
    }
  }
}

extension BackupPasswordValidationText on BackupPasswordValidation {
  String problemText({required bool isRu}) {
    return problems
        .map((problem) => BackupPasswordPolicy.problemText(problem, isRu: isRu))
        .join('\n');
  }
}

extension on String {
  bool containsCharCode(int code) {
    for (final rune in runes) {
      if (rune == code) return true;
    }
    return false;
  }
}
