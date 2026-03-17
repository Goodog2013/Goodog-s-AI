# Goodog's AI

Локальный AI-чат на Flutter для Windows и Android с LM Studio/Qwen 🤖  
Local Flutter AI chat for Windows and Android with LM Studio/Qwen 🤖

## Русский

### О проекте ✨
Goodog's AI - локальный чат-клиент без облачного backend.

Основные возможности:
- чаты, папки, избранное
- локальная история и локальные настройки
- подключение к LM Studio через OpenAI-compatible API
- веб-контекст (включается в настройках)
- профиль и тарифы `Free / Plus / Max`
- LAN-шлюз с очередью и приоритетами
- отдельное admin-приложение

### Рекомендации 💡
- Используйте LM Studio как локальный сервер LLM.
- Рекомендуемая модель: `qwen2.5-7b-instruct-uncensored`.
- Для Android не используйте `localhost`, указывайте LAN IP вашего ПК (например `http://192.168.1.10:1234`).
- Если включен веб-поиск, держите стабильное интернет-соединение, иначе приложение вернет честный ответ без импровизации.

### Архитектура 🧩
- `lib/src/presentation` - экраны, контроллеры, виджеты, тема
- `lib/src/application` - сервисный слой
- `lib/src/data` - local/remote data sources
- `lib/src/models` - модели
- `lib/src/admin` - admin UI + LAN gateway

### Требования 📋
- Flutter SDK (stable)
- Windows 10/11 (для desktop-сборки)
- Android SDK (для Android-сборки)
- LM Studio с включенным локальным API

### Быстрый старт 🚀
1. Установите зависимости:

```bash
flutter pub get
```

2. Проверьте настройки LM Studio в приложении:
- Base URL, например: `http://172.19.0.1:1234`
- Model, например: `qwen2.5-7b-instruct-uncensored`

### Запуск ▶️
Windows:

```bash
flutter run -d windows
```

Android:

```bash
flutter run -d <android_device_id>
```

Admin-приложение:

```bash
flutter run -d windows -t lib/main_admin.dart
```

### LAN-режим (очередь + права) 🌐
1. Запустите admin-приложение и включите шлюз.
2. В основном приложении включите `LAN-шлюз`.
3. Укажите URL шлюза, например `http://192.168.1.10:8088`.

### Тарифы и лимиты 📊
| Тариф | Папки | Чаты | Контекст | Задержка | Автообновление контекста | Приоритет |
|---|---:|---:|---:|---:|---|---:|
| Free | 1 | 5 | 5 сообщений | 10 сек | Нет | 1 |
| Plus | 3 | 10 | 20 сообщений | 5 сек | Да | 2 |
| Max | Без жесткого лимита | Без жесткого лимита | 50 сообщений | 0 сек | Да | 3 |

### Новый стандарт сборки Windows 🛠️
Основная команда:

```cmd
scripts\build_windows.cmd
```

Эквивалент через PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build_windows.ps1
```

Параметры:
- `-SkipClean` - пропустить `flutter clean`
- `-SkipInstaller` - собрать только приложения без инсталляторов
- `-OpenOutput` - открыть папку результата

### Структура релизов (новый стандарт) 📦
После сборки создается папка `Releases` в корне проекта:
- `Releases\user` - пользовательский Windows release
- `Releases\admin` - admin Windows release
- `Releases\installer` - оба инсталлятора (`user` и `admin`)

### Android 📱
- Разрешение `INTERNET` уже есть в `android/app/src/main/AndroidManifest.xml`.
- Если LM Studio запущен на ПК, на Android используйте LAN IP ПК, а не `localhost`.

---

## English

### About ✨
Goodog's AI is a local Flutter chat client with no cloud backend.

Core features:
- chats, folders, favorites
- local history and local settings
- LM Studio integration via OpenAI-compatible API
- optional web context
- profile with plans `Free / Plus / Max`
- LAN gateway with queue and priorities
- separate admin app

### Recommendations 💡
- Use LM Studio as the local LLM server.
- Recommended model: `qwen2.5-7b-instruct-uncensored`.
- On Android, do not use `localhost`; use your PC LAN IP instead (for example `http://192.168.1.10:1234`).
- If web search is enabled, keep internet access stable; otherwise the app returns a strict no-guessing response.

### Architecture 🧩
- `lib/src/presentation` - screens, controllers, widgets, theme
- `lib/src/application` - service layer
- `lib/src/data` - local/remote data sources
- `lib/src/models` - data models
- `lib/src/admin` - admin UI + LAN gateway

### Requirements 📋
- Flutter SDK (stable)
- Windows 10/11 (desktop build)
- Android SDK (Android build)
- LM Studio with local API enabled

### Quick Start 🚀
1. Install dependencies:

```bash
flutter pub get
```

2. Check LM Studio settings in app:
- Base URL, for example: `http://172.19.0.1:1234`
- Model, for example: `qwen2.5-7b-instruct-uncensored`

### Run ▶️
Windows:

```bash
flutter run -d windows
```

Android:

```bash
flutter run -d <android_device_id>
```

Admin app:

```bash
flutter run -d windows -t lib/main_admin.dart
```

### LAN Mode (Queue + Permissions) 🌐
1. Start admin app and enable gateway.
2. Enable `LAN gateway` in the main app settings.
3. Set gateway URL, for example `http://192.168.1.10:8088`.

### Plans and Limits 📊
| Plan | Folders | Chats | Context | Delay | Auto Context Refresh | Priority |
|---|---:|---:|---:|---:|---|---:|
| Free | 1 | 5 | 5 messages | 10 sec | No | 1 |
| Plus | 3 | 10 | 20 messages | 5 sec | Yes | 2 |
| Max | No hard limit | No hard limit | 50 messages | 0 sec | Yes | 3 |

### New Windows Build Standard 🛠️
Main command:

```cmd
scripts\build_windows.cmd
```

PowerShell equivalent:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build_windows.ps1
```

Parameters:
- `-SkipClean` - skip `flutter clean`
- `-SkipInstaller` - build apps only (no installers)
- `-OpenOutput` - open output folder

### Release Layout (new standard) 📦
After build, `Releases` is created in project root:
- `Releases\user` - user Windows release
- `Releases\admin` - admin Windows release
- `Releases\installer` - both installers (`user` and `admin`)

### Android Notes 📱
- `INTERNET` permission is already added in `android/app/src/main/AndroidManifest.xml`.
- If LM Studio runs on your PC, Android must use your PC LAN IP instead of `localhost`.
