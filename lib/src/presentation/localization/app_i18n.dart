import '../../models/app_language.dart';
import '../../models/chat_settings.dart';

class AppI18n {
  AppI18n(String languageCode)
    : _languageCode = AppLanguage.normalizeCode(languageCode);

  final String _languageCode;

  static const String fallbackLanguageCode = 'en';

  String get languageCode => _languageCode;

  String t(String key, [Map<String, String> params = const {}]) {
    final bundle =
        _translations[_languageCode] ?? _translations[fallbackLanguageCode]!;
    final fallback = _translations[fallbackLanguageCode]!;
    var text = bundle[key] ?? fallback[key] ?? key;
    params.forEach((name, value) {
      text = text.replaceAll('{$name}', value);
    });
    return text;
  }

  String modeLabel(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return t('themeModeSystem');
      case AppThemeMode.light:
        return t('themeModeLight');
      case AppThemeMode.dark:
        return t('themeModeDark');
    }
  }

  String paletteLabel(AppColorPalette palette) {
    switch (palette) {
      case AppColorPalette.ocean:
        return t('paletteOcean');
      case AppColorPalette.sunset:
        return t('paletteSunset');
      case AppColorPalette.forest:
        return t('paletteForest');
    }
  }

  String languageItemLabel(AppLanguage language) {
    return '${language.nativeName} (${language.englishName})';
  }

  static const Map<String, Map<String, String>> _translations = {
    'en': {
      'settings': 'Settings',
      'save': 'Save',
      'appearance': 'Appearance',
      'appearanceSubtitle':
          'Current palette: {palette}. Changes are applied instantly.',
      'language': 'Language',
      'languageSubtitle':
          'App UI and model response language. Includes CIS languages, Georgian, Ukrainian, major EU languages, and Hungarian.',
      'connection': 'Connection',
      'connectionSubtitle': 'Local LM Studio and model configuration.',
      'generation': 'Generation',
      'generationSubtitle': 'System prompt and generation parameters.',
      'baseUrlLabel': 'LM Studio Base URL',
      'modelLabel': 'Model',
      'systemPromptLabel': 'System prompt',
      'systemPromptHelp':
          'System prompt is a persistent instruction sent before each user message.',
      'temperature': 'Temperature: {value}',
      'webSearchTitle': 'Web search for answers',
      'webSearchSubtitle':
          'Uses internet context for links, explicit web commands, and auto-retry when model is unsure.',
      'sourcesCount': 'Sources in context: {count}',
      'saveSettings': 'Save settings',
      'saving': 'Saving...',
      'clearHistory': 'Clear chat history',
      'clearing': 'Clearing...',
      'clearHistoryTitle': 'Clear chat history',
      'clearHistoryBody': 'All saved messages will be permanently deleted.',
      'cancel': 'Cancel',
      'clear': 'Clear',
      'saveError': 'Failed to save settings.',
      'historyCleared': 'Chat history cleared.',
      'historyClearError': 'Failed to clear history.',
      'baseUrlRequired': 'Please enter base URL.',
      'baseUrlInvalid': 'Enter valid URL, e.g. http://172.19.0.1:1234',
      'modelRequired': 'Please enter model name.',
      'checking': 'Checking...',
      'checkLmStudio': 'Check LM Studio connection',
      'checkLanGateway': 'Check LAN gateway connection',
      'connectionOk': '{target}: connection successful.',
      'connectionFailed': '{target}: connection failed.',
      'connectionFailedStatus': '{target}: server returned HTTP {status}.',
      'connectionTimeout': '{target}: request timed out.',
      'connectionNoNetwork': '{target}: network is unavailable.',
      'lanGatewayRequired': 'Please enter LAN gateway URL.',
      'lanGatewayInvalid': 'Invalid LAN gateway URL.',
      'androidNetworkTitle': 'Android local network setup',
      'androidNetworkSubtitle':
          'For phone on Wi-Fi use your PC LAN IP. For emulator use 10.0.2.2.',
      'presetEmulator': 'Use emulator 10.0.2.2',
      'presetLanExample': 'Use LAN example',
      'presetGatewayLan': 'Gateway LAN example',
      'enable': 'Enable',
      'internetDisabledReason':
          'Model cannot access internet because "Web search for answers" is disabled.',
      'inputHint': 'Type a message...',
      'startDialogTitle': 'Start a conversation',
      'startDialogSubtitle':
          'Type your message and send it to the local model.',
      'windowSettings': 'Settings',
      'windowMinimize': 'Minimize',
      'windowRestore': 'Restore',
      'windowMaximize': 'Maximize',
      'windowClose': 'Close',
      'themeModeSystem': 'System',
      'themeModeLight': 'Light',
      'themeModeDark': 'Dark',
      'paletteOcean': 'Ocean',
      'paletteSunset': 'Sunset',
      'paletteForest': 'Forest',
      'answerLanguageInstruction':
          'Always answer in {language}. Keep the response natural and concise.',
    },
    'ru': {
      'settings': 'Настройки',
      'save': 'Сохранить',
      'appearance': 'Внешний вид',
      'appearanceSubtitle':
          'Текущая палитра: {palette}. Изменения применяются сразу.',
      'language': 'Язык',
      'languageSubtitle':
          'Язык интерфейса и ответов модели. Поддерживаются языки СНГ, грузинский, украинский, основные языки ЕС и венгерский.',
      'connection': 'Подключение',
      'connectionSubtitle': 'Параметры локального LM Studio и модели.',
      'generation': 'Генерация',
      'generationSubtitle': 'Системный prompt и параметры генерации ответа.',
      'baseUrlLabel': 'Базовый URL LM Studio',
      'modelLabel': 'Модель',
      'systemPromptLabel': 'Системный prompt',
      'systemPromptHelp':
          'Системный prompt — это постоянная инструкция, которая отправляется перед каждым сообщением пользователя.',
      'temperature': 'Температура: {value}',
      'webSearchTitle': 'Веб-поиск для ответов',
      'webSearchSubtitle':
          'Контекст из интернета используется по ссылке, по явной команде вроде "посмотри в интернете" и автоматически, если модель не уверена.',
      'sourcesCount': 'Источников в контексте: {count}',
      'saveSettings': 'Сохранить настройки',
      'saving': 'Сохранение...',
      'clearHistory': 'Очистить историю чата',
      'clearing': 'Очистка...',
      'clearHistoryTitle': 'Очистить историю чата',
      'clearHistoryBody':
          'Все сохраненные сообщения будут удалены без возможности восстановления.',
      'cancel': 'Отмена',
      'clear': 'Очистить',
      'saveError': 'Не удалось сохранить настройки.',
      'historyCleared': 'История чата очищена.',
      'historyClearError': 'Не удалось очистить историю.',
      'baseUrlRequired': 'Укажите базовый URL.',
      'baseUrlInvalid':
          'Введите корректный URL, например http://172.19.0.1:1234',
      'modelRequired': 'Укажите имя модели.',
      'checking': 'Проверка...',
      'checkLmStudio': 'Проверить подключение к LM Studio',
      'checkLanGateway': 'Проверить подключение к LAN-шлюзу',
      'connectionOk': '{target}: подключение успешно.',
      'connectionFailed': '{target}: подключиться не удалось.',
      'connectionFailedStatus': '{target}: сервер вернул HTTP {status}.',
      'connectionTimeout': '{target}: превышено время ожидания.',
      'connectionNoNetwork': '{target}: сеть недоступна.',
      'lanGatewayRequired': 'Укажите URL LAN-шлюза.',
      'lanGatewayInvalid': 'Некорректный URL LAN-шлюза.',
      'androidNetworkTitle': 'Подключение Android по локальной сети',
      'androidNetworkSubtitle':
          'Для телефона в Wi-Fi используйте LAN IP вашего ПК. Для эмулятора используйте 10.0.2.2.',
      'presetEmulator': 'Эмулятор 10.0.2.2',
      'presetLanExample': 'Пример LAN IP',
      'presetGatewayLan': 'Пример LAN-шлюза',
      'enable': 'Включить',
      'internetDisabledReason':
          'Модель не может выйти в интернет, потому что выключен переключатель «Веб-поиск для ответов».',
      'inputHint': 'Введите сообщение...',
      'startDialogTitle': 'Начните диалог',
      'startDialogSubtitle':
          'Напишите сообщение и отправьте его в локальную модель.',
      'windowSettings': 'Настройки',
      'windowMinimize': 'Свернуть',
      'windowRestore': 'Восстановить',
      'windowMaximize': 'Развернуть',
      'windowClose': 'Закрыть',
      'themeModeSystem': 'Система',
      'themeModeLight': 'Светлая',
      'themeModeDark': 'Темная',
      'paletteOcean': 'Океан',
      'paletteSunset': 'Закат',
      'paletteForest': 'Лес',
      'answerLanguageInstruction':
          'Всегда отвечай на языке: {language}. Формулируй ответ естественно и по делу.',
    },
    'uk': {
      'settings': 'Налаштування',
      'save': 'Зберегти',
      'appearance': 'Зовнішній вигляд',
      'connection': "Підключення",
      'generation': 'Генерація',
      'language': 'Мова',
      'saveSettings': 'Зберегти налаштування',
      'clearHistory': 'Очистити історію чату',
      'cancel': 'Скасувати',
      'clear': 'Очистити',
      'enable': 'Увімкнути',
      'themeModeSystem': 'Система',
      'themeModeLight': 'Світла',
      'themeModeDark': 'Темна',
      'paletteOcean': 'Океан',
      'paletteSunset': 'Захід',
      'paletteForest': 'Ліс',
      'windowSettings': 'Налаштування',
      'windowMinimize': 'Згорнути',
      'windowRestore': 'Відновити',
      'windowMaximize': 'Розгорнути',
      'windowClose': 'Закрити',
      'answerLanguageInstruction':
          'Always answer in {language}. Keep the response natural and concise.',
    },
    'ka': {
      'settings': 'პარამეტრები',
      'save': 'შენახვა',
      'appearance': 'გარეგნობა',
      'connection': 'კავშირი',
      'generation': 'გენერაცია',
      'language': 'ენა',
      'saveSettings': 'პარამეტრების შენახვა',
      'clearHistory': 'ჩატის ისტორიის გასუფთავება',
      'cancel': 'გაუქმება',
      'clear': 'გასუფთავება',
      'enable': 'ჩართვა',
      'windowSettings': 'პარამეტრები',
      'windowMinimize': 'ჩაკეცვა',
      'windowRestore': 'აღდგენა',
      'windowMaximize': 'გაშლა',
      'windowClose': 'დახურვა',
      'answerLanguageInstruction':
          'Always answer in {language}. Keep the response natural and concise.',
    },
    'de': {
      'settings': 'Einstellungen',
      'save': 'Speichern',
      'language': 'Sprache',
    },
    'fr': {
      'settings': 'Paramètres',
      'save': 'Enregistrer',
      'language': 'Langue',
    },
    'es': {
      'settings': 'Configuración',
      'save': 'Guardar',
      'language': 'Idioma',
    },
    'it': {'settings': 'Impostazioni', 'save': 'Salva', 'language': 'Lingua'},
    'pt': {'settings': 'Configurações', 'save': 'Salvar', 'language': 'Idioma'},
    'pl': {'settings': 'Ustawienia', 'save': 'Zapisz', 'language': 'Język'},
    'nl': {'settings': 'Instellingen', 'save': 'Opslaan', 'language': 'Taal'},
    'cs': {'settings': 'Nastavení', 'save': 'Uložit', 'language': 'Jazyk'},
    'ro': {'settings': 'Setări', 'save': 'Salvare', 'language': 'Limbă'},
    'el': {'settings': 'Ρυθμίσεις', 'save': 'Αποθήκευση', 'language': 'Γλώσσα'},
    'hu': {'settings': 'Beállítások', 'save': 'Mentés', 'language': 'Nyelv'},
    'be': {'settings': 'Налады', 'save': 'Захаваць', 'language': 'Мова'},
    'kk': {'settings': 'Баптаулар', 'save': 'Сақтау', 'language': 'Тіл'},
    'ky': {'settings': 'Жөндөөлөр', 'save': 'Сактоо', 'language': 'Тил'},
    'tg': {'settings': 'Танзимот', 'save': 'Нигоҳ доштан', 'language': 'Забон'},
    'uz': {'settings': 'Sozlamalar', 'save': 'Saqlash', 'language': 'Til'},
    'az': {'settings': 'Parametrlər', 'save': 'Saxla', 'language': 'Dil'},
    'hy': {
      'settings': 'Կարգավորումներ',
      'save': 'Պահպանել',
      'language': 'Լեզու',
    },
  };
}
