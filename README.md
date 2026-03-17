# Goodog's AI

Локальный AI-чат на Flutter (Windows + Android) с подключением к LM Studio и моделью Qwen.

Local Flutter AI chat app (Windows + Android) for LM Studio and Qwen models.

## Русский

### О проекте
Goodog's AI - это локальный чат-клиент, который работает без облачного backend.
Приложение поддерживает:
- чаты и папки
- избранные чаты
- локальную историю
- настройку LM Studio endpoint
- веб-контекст (переключаемый)
- профиль и тарифы `Free / Plus / Max`
- LAN-очередь запросов с приоритетами
- отдельное admin-приложение для бана и смены прав

### Рекомендации
Используйте LM Studio и желательно модель (qwen2.5-7b-instruct-uncensored) т.к проект сделан под них.
### Архитектура
Проект разделен на слои:
- `lib/src/presentation` - экраны, контроллеры, виджеты, тема
- `lib/src/application` - сервисы приложения
- `lib/src/data` - remote/local data sources
- `lib/src/models` - модели данных
- `lib/src/admin` - LAN gateway и admin UI

### Требования
- Flutter SDK (stable)
- Windows 10/11 для desktop-сборки
- Android SDK для Android-сборки
- LM Studio с поднятым локальным API

### Быстрый старт
1. Установите зависимости:

```bash
flutter pub get
```

2. Проверьте URL LM Studio в настройках приложения, например:
- `http://172.19.0.1:1234`

3. Убедитесь, что в LM Studio выбран нужный model id, например:
- `qwen2.5-7b-instruct-uncensored`

### Запуск приложения
Windows:

```bash
flutter run -d windows
```

Android:

```bash
flutter run -d <android_device_id>
```

### Запуск admin-приложения
Admin-приложение запускается отдельным entrypoint:

```bash
flutter run -d windows -t lib/main_admin.dart
```

В админке можно:
- запустить/остановить LAN-шлюз
- менять тарифы пользователей (`Free / Plus / Max`)
- банить/разбанивать пользователей
- видеть очередь и активный профиль

### LAN-режим (очередь + права)
Чтобы основной клиент использовал LAN-очередь:
1. Запустите admin-приложение и включите шлюз.
2. В основном приложении откройте настройки.
3. Включите `LAN-шлюз`.
4. Укажите URL шлюза, например `http://192.168.1.10:8088`.

### Тарифы и лимиты
| Тариф | Папки | Чаты | Контекст | Задержка ответа | Автообновление контекста | Приоритет очереди |
|---|---:|---:|---:|---:|---|---:|
| Free | 1 | 5 | 5 сообщений | 10 сек | Нет | 1 |
| Plus | 3 | 10 | 20 сообщений | 5 сек | Да | 2 |
| Max | Без жесткого лимита | Без жесткого лимита | 50 сообщений | 0 сек | Да | 3 |

### Сборка Windows release
Быстрый способ:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build_windows.ps1
```

или:

```cmd
scripts\build_windows.cmd
```

Скрипт собирает:
- обычное приложение
- admin-приложение
- инсталлятор (если не указан `-SkipInstaller`)

### Артефакты сборки
- Пользовательский release: `artifacts/windows_release`
- Admin release: `artifacts/windows_admin_release`
- Инсталлятор: `artifacts/installer`

### Важно для Android
- Разрешение `INTERNET` уже добавлено в `android/app/src/main/AndroidManifest.xml`.
- Если LM Studio запущен на ПК, на Android нужно использовать LAN IP ПК, а не `localhost`.

---

## English

### About
Goodog's AI is a local Flutter chat client with no cloud backend.
It includes:
- chats and folders
- favorites
- local history
- configurable LM Studio endpoint
- optional web context
- profile and plans (`Free / Plus / Max`)
- LAN request queue with priorities
- separate admin app for bans and plan management

### Recommendations
Use LM Studio and preferably the (qwen2.5-7b-instruct-uncensored) model, since the project is built for them.
### Architecture
Layered structure:
- `lib/src/presentation` - screens, controllers, widgets, theme
- `lib/src/application` - app services
- `lib/src/data` - remote/local data sources
- `lib/src/models` - data models
- `lib/src/admin` - LAN gateway and admin UI

### Requirements
- Flutter SDK (stable)
- Windows 10/11 for desktop build
- Android SDK for Android build
- LM Studio running with local API enabled

### Quick Start
1. Install dependencies:

```bash
flutter pub get
```

2. Set LM Studio base URL in app settings, for example:
- `http://172.19.0.1:1234`

3. Ensure the selected model id matches your LM Studio model, for example:
- `qwen2.5-7b-instruct-uncensored`

### Run App
Windows:

```bash
flutter run -d windows
```

Android:

```bash
flutter run -d <android_device_id>
```

### Run Admin App
Admin app uses a separate entrypoint:

```bash
flutter run -d windows -t lib/main_admin.dart
```

Admin app can:
- start/stop LAN gateway
- change user plans (`Free / Plus / Max`)
- ban/unban users
- show queue status and active profile

### LAN Mode (Queue + Permissions)
To route user requests through LAN queue:
1. Start the admin app and enable gateway.
2. Open settings in the main app.
3. Enable `LAN gateway`.
4. Set gateway URL, for example `http://192.168.1.10:8088`.

### Plans and Limits
| Plan | Folders | Chats | Context | Reply Delay | Auto Context Refresh | Queue Priority |
|---|---:|---:|---:|---:|---|---:|
| Free | 1 | 5 | 5 messages | 10 sec | No | 1 |
| Plus | 3 | 10 | 20 messages | 5 sec | Yes | 2 |
| Max | No hard limit | No hard limit | 50 messages | 0 sec | Yes | 3 |

### Windows Release Build
Recommended command:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build_windows.ps1
```

or:

```cmd
scripts\build_windows.cmd
```

The script builds:
- user app
- admin app
- installer (unless `-SkipInstaller` is passed)

### Build Artifacts
- User release: `artifacts/windows_release`
- Admin release: `artifacts/windows_admin_release`
- Installer: `artifacts/installer`

### Android Notes
- `INTERNET` permission is already present in `android/app/src/main/AndroidManifest.xml`.
- If LM Studio runs on your PC, Android must use your PC LAN IP, not `localhost`.
