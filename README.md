# Goodog's AI

Локальный AI-чат на Flutter для Windows и Android 🤖

Local Flutter AI chat for Windows and Android 🤖

---

## 🇷🇺 Русский

### О проекте ✨
**Goodog's AI** — это локальный AI-чат без облачного backend.
Приложение работает с **LM Studio** через OpenAI-compatible API и подходит как удобный фронтенд для локальных моделей (например, Qwen).

### Что есть сейчас 🚀
- 💬 Система чатов, папок и избранного
- 🧠 Контекст чата с лимитами по тарифам
- 🌐 Веб-контекст (по команде/ссылке) без импровизации
- ⚙️ Гибкие настройки модели (URL, model, system prompt, temperature)
- 👤 Профили и уровни доступа: `Free / Plus / Max`
- 🛡️ LAN-шлюз (очередь, приоритеты, права, бан)
- 🧩 Отдельное admin-приложение
- 🪟 Кастомный desktop UI + темы/палитры
- 📱 Адаптация под Android и локальную сеть

### Beta v1.3 — что нового 🆕
- ✅ Улучшена Android LAN-диагностика в настройках
  - предупреждения для `localhost`, `10.0.2.2`, `172.19.0.1` и похожих адресов
- ✅ Улучшены сообщения ошибок сети при отправке в LM Studio
  - теперь видно, почему телефон может не доставать до сервера
- ✅ Исправлен UI-баг на Android
  - поле ввода больше не перекрывается системными кнопками навигации
- ✅ Пересобран Android APK с актуальными фиксам

### Архитектура 🧱
- `lib/src/presentation` — экраны, контроллеры, виджеты, тема
- `lib/src/application` — сервисный слой
- `lib/src/data` — local/remote data sources
- `lib/src/models` — модели
- `lib/src/admin` — admin UI + LAN gateway

### Требования 📋
- Flutter SDK (stable)
- Windows 10/11 (для desktop)
- Android SDK (для Android)
- LM Studio с включенным local API

### Быстрый старт 🚀
```bash
flutter pub get
```

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

### Сборка Windows 🛠️
```cmd
scripts\build_windows.cmd
```

### Сборка Android 🛠️
```cmd
scripts\build_android.cmd -AndroidSdkPath "C:\Users\<USER>\AppData\Local\Android\Sdk"
```

APK после сборки:
- `Releases\android\apk\app-release.apk`

### Структура релизов 📦
- `Releases\user` — пользовательский Windows release
- `Releases\admin` — admin Windows release
- `Releases\installer` — инсталляторы
- `Releases\android\apk` — Android APK
- `Releases\android\aab` — Android AAB (если включено в сборке)

### Android LAN: важно ⚠️
- На телефоне **не используйте `localhost`** для LM Studio на ПК.
- Указывайте LAN IP вашего ПК, например:
  - `http://192.168.1.15:1234`
- Адрес вроде `172.19.0.1` часто является внутренним Docker/WSL IP и может быть недоступен из Wi‑Fi.
- Проверьте Windows Firewall (входящий порт `1234`; для шлюза — `8088`).

### Рекомендации (LAN IP ПК) 💡
- Если LM Studio запущен на вашем ПК, в приложении на телефоне используйте **IP ПК в локальной сети**, а не внутренний IP LM/WSL/Docker.
- Где взять IP ПК: откройте `ipconfig` и используйте `IPv4 Address` активного Wi‑Fi/Ethernet адаптера.
- Хороший пример: `http://192.168.1.15:1234`
- Плохие примеры для реального телефона: `http://localhost:1234`, `http://127.0.0.1:1234`, `http://172.19.0.1:1234`
- Если сменили Wi‑Fi сеть, IP ПК может измениться — обновите URL в настройках приложения.

### Тарифы и лимиты 📊
| План | Папки | Чаты | Контекст | Задержка | Автообновление контекста | Приоритет |
|---|---:|---:|---:|---:|---|---:|
| Free | 1 | 5 | 5 сообщений | 10 сек | Нет | 1 |
| Plus | 3 | 10 | 20 сообщений | 5 сек | Да | 2 |
| Max | Без жесткого лимита | Без жесткого лимита | 50 сообщений | 0 сек | Да | 3 |

---

## 🇬🇧 English

### About ✨
**Goodog's AI** is a local AI chat app without a cloud backend.
It connects to **LM Studio** through an OpenAI-compatible API and works as a practical frontend for local models (for example, Qwen).

### Current Features 🚀
- 💬 Chats, folders, favorites
- 🧠 Chat context system with plan-based limits
- 🌐 Web context (links/commands) with no hallucination mode
- ⚙️ Model settings (URL, model, system prompt, temperature)
- 👤 Access tiers: `Free / Plus / Max`
- 🛡️ LAN gateway (queue, priorities, permissions, bans)
- 🧩 Separate admin app
- 🪟 Custom desktop UI + themes/palettes
- 📱 Android + local network support

### Beta v1.3 — What’s New 🆕
- ✅ Better Android LAN diagnostics in Settings
  - warnings for `localhost`, `10.0.2.2`, `172.19.0.1`, and similar addresses
- ✅ Better network error messages for LM Studio requests
  - clearer reasons why phone requests may not reach the server
- ✅ Android UI fix
  - message input no longer overlaps system navigation buttons
- ✅ Fresh Android APK build with all fixes

### Architecture 🧱
- `lib/src/presentation` — screens, controllers, widgets, theme
- `lib/src/application` — service layer
- `lib/src/data` — local/remote data sources
- `lib/src/models` — models
- `lib/src/admin` — admin UI + LAN gateway

### Requirements 📋
- Flutter SDK (stable)
- Windows 10/11 (desktop)
- Android SDK (Android)
- LM Studio with local API enabled

### Quick Start 🚀
```bash
flutter pub get
```

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

### Build Windows 🛠️
```cmd
scripts\build_windows.cmd
```

### Build Android 🛠️
```cmd
scripts\build_android.cmd -AndroidSdkPath "C:\Users\<USER>\AppData\Local\Android\Sdk"
```

APK output:
- `Releases\android\apk\app-release.apk`

### Release Layout 📦
- `Releases\user` — user Windows release
- `Releases\admin` — admin Windows release
- `Releases\installer` — installers
- `Releases\android\apk` — Android APK
- `Releases\android\aab` — Android AAB (if enabled)

### Android LAN Notes ⚠️
- On a real phone, do **not** use `localhost` for LM Studio running on PC.
- Use your PC LAN IP, e.g.:
  - `http://192.168.1.15:1234`
- Addresses like `172.19.0.1` are often Docker/WSL internal and may be unreachable from Wi‑Fi.
- Check Windows Firewall (inbound `1234`; for gateway `8088`).

### Recommendations (PC LAN IP) 💡
- If LM Studio is running on your PC, set the phone app URL to your **PC LAN IP**, not an internal LM/WSL/Docker address.
- How to find your PC IP: run `ipconfig` and use the active adapter `IPv4 Address`.
- Good example: `http://192.168.1.15:1234`
- Bad examples on a real phone: `http://localhost:1234`, `http://127.0.0.1:1234`, `http://172.19.0.1:1234`
- If you switch Wi‑Fi networks, your PC IP may change — update the app URL.

### Plans & Limits 📊
| Plan | Folders | Chats | Context | Delay | Auto Context Refresh | Priority |
|---|---:|---:|---:|---:|---|---:|
| Free | 1 | 5 | 5 messages | 10 sec | No | 1 |
| Plus | 3 | 10 | 20 messages | 5 sec | Yes | 2 |
| Max | No hard limit | No hard limit | 50 messages | 0 sec | Yes | 3 |
