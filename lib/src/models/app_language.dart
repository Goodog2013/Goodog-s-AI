class AppLanguage {
  const AppLanguage({
    required this.code,
    required this.nativeName,
    required this.englishName,
  });

  final String code;
  final String nativeName;
  final String englishName;

  static const List<AppLanguage> supported = <AppLanguage>[
    AppLanguage(code: 'ru', nativeName: 'Русский', englishName: 'Russian'),
    AppLanguage(code: 'uk', nativeName: 'Українська', englishName: 'Ukrainian'),
    AppLanguage(
      code: 'be',
      nativeName: 'Беларуская',
      englishName: 'Belarusian',
    ),
    AppLanguage(code: 'kk', nativeName: 'Қазақша', englishName: 'Kazakh'),
    AppLanguage(code: 'ky', nativeName: 'Кыргызча', englishName: 'Kyrgyz'),
    AppLanguage(code: 'tg', nativeName: 'Тоҷикӣ', englishName: 'Tajik'),
    AppLanguage(code: 'uz', nativeName: "O'zbekcha", englishName: 'Uzbek'),
    AppLanguage(
      code: 'az',
      nativeName: 'Azərbaycanca',
      englishName: 'Azerbaijani',
    ),
    AppLanguage(code: 'hy', nativeName: 'Հայերեն', englishName: 'Armenian'),
    AppLanguage(code: 'ka', nativeName: 'ქართული', englishName: 'Georgian'),
    AppLanguage(code: 'en', nativeName: 'English', englishName: 'English'),
    AppLanguage(code: 'de', nativeName: 'Deutsch', englishName: 'German'),
    AppLanguage(code: 'fr', nativeName: 'Français', englishName: 'French'),
    AppLanguage(code: 'es', nativeName: 'Español', englishName: 'Spanish'),
    AppLanguage(code: 'it', nativeName: 'Italiano', englishName: 'Italian'),
    AppLanguage(code: 'pt', nativeName: 'Português', englishName: 'Portuguese'),
    AppLanguage(code: 'pl', nativeName: 'Polski', englishName: 'Polish'),
    AppLanguage(code: 'nl', nativeName: 'Nederlands', englishName: 'Dutch'),
    AppLanguage(code: 'cs', nativeName: 'Čeština', englishName: 'Czech'),
    AppLanguage(code: 'ro', nativeName: 'Română', englishName: 'Romanian'),
    AppLanguage(code: 'el', nativeName: 'Ελληνικά', englishName: 'Greek'),
    AppLanguage(code: 'hu', nativeName: 'Magyar', englishName: 'Hungarian'),
  ];

  static AppLanguage byCode(String? code) {
    final normalized = normalizeCode(code);
    for (final language in supported) {
      if (language.code == normalized) {
        return language;
      }
    }
    return supported.first;
  }

  static bool isSupported(String? code) {
    final raw = (code ?? '').trim().toLowerCase();
    if (raw.isEmpty) {
      return false;
    }
    final normalized = raw.length >= 2 ? raw.substring(0, 2) : raw;
    for (final language in supported) {
      if (language.code == normalized) {
        return true;
      }
    }
    return false;
  }

  static String normalizeCode(String? code) {
    final value = (code ?? '').trim().toLowerCase();
    if (value.length >= 2) {
      final short = value.substring(0, 2);
      for (final language in supported) {
        if (language.code == short) {
          return short;
        }
      }
    }
    return 'ru';
  }
}
