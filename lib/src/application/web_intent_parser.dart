class WebIntentParser {
  static final RegExp _urlPattern = RegExp(
    r'https?:\/\/\S+',
    caseSensitive: false,
  );
  static final RegExp _searchVerbPattern = RegExp(
    r'\b(посмотри|проверь|найди|поищи|поиск|погугли|загугли|'
    r'подивись|перевір|знайди|пошукай|'
    r'search|lookup|look up|find|check|google|'
    r'suche|recherche|cherche|busca|cerca|procure|szukaj|keresd)\b',
    caseSensitive: false,
  );
  static final RegExp _webTargetPattern = RegExp(
    r'\b(инет|инете|интернет|интернете|сети|веб|web|гугл|гугле|google|'
    r'інтернет|мережі|вебі|'
    r'internet|online|netz|webu|reseau|réseau|'
    r'red|rete|rede|sieci|համացանց|ინტერნეტ)\b',
    caseSensitive: false,
  );
  static final RegExp _directWebVerbPattern = RegExp(
    r'\b(погугли|загугли)\b',
    caseSensitive: false,
  );
  static final List<String> _explicitPhrases = <String>[
    'посмотри в инете',
    'посмотри в интернете',
    'проверь в инете',
    'проверь в интернете',
    'найди в инете',
    'найди в интернете',
    'поищи в интернете',
    'подивись в интернете',
    'подивись в інтернеті',
    'знайди в інтернеті',
    'look in web',
    'search on web',
    'search in internet',
    'find on the web',
    'search online',
  ];

  static bool containsUrl(String text) {
    return _urlPattern.hasMatch(text);
  }

  static bool requestsWeb(String text) {
    final normalized = _normalize(text);
    if (normalized.isEmpty) {
      return false;
    }
    if (_urlPattern.hasMatch(normalized)) {
      return true;
    }

    for (final phrase in _explicitPhrases) {
      if (normalized.contains(phrase)) {
        return true;
      }
    }

    if (_directWebVerbPattern.hasMatch(normalized)) {
      return true;
    }

    final hasSearchVerb = _searchVerbPattern.hasMatch(normalized);
    final hasWebTarget = _webTargetPattern.hasMatch(normalized);
    return hasSearchVerb && hasWebTarget;
  }

  static String buildSearchQuery(String text) {
    var query = text;
    query = query.replaceAll(_urlPattern, ' ');
    query = query.replaceAll(
      RegExp(
        r'\b(посмотри|проверь|найди|поищи|поиск|погугли|загугли|'
        r'подивись|перевір|знайди|пошукай|'
        r'search|lookup|look up|find|check|google|'
        r'suche|recherche|cherche|busca|cerca|procure|szukaj|keresd)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    query = query.replaceAll(
      RegExp(
        r'\b(в|во|на|по|через|у|в|на|по|on|in)\s+'
        r'(инете|интернете|интернет|сети|вебе|веб|web|google|гугле|гугл|'
        r'інтернеті|інтернет|мережі|internet|online|netz|reseau|réseau|red|rete|sieci)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    query = query.replaceAll(
      RegExp(
        r'\b(пожалуйста|плиз|будь ласка|pls|please|por favor|s il vous plait|si vous plait)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    query = query.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (query.isEmpty) {
      return text.trim();
    }
    return query;
  }

  static String _normalize(String text) {
    return text.toLowerCase().replaceAll('ё', 'е').trim();
  }
}
