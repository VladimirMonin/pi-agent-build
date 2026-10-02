---
applyTo: "**"
name: "SEC.PublicRepository"
description: "Читай перед добавлением конфигов, примеров, logs, patches, skills, archives или данных с рабочей машины: secret scanning, личные пути, runtime data и безопасная генерация публичных шаблонов."
---

# SEC — Безопасность публичного репозитория

## Модель угроз

Главный риск — не вредоносный код, а случайная публикация credentials, истории сессий, памяти, личных путей или конфиденциальных фрагментов из логов. Удаление файла последующим commit не устраняет утечку из Git-истории.

## Запрещённые данные

Никогда не добавляй:

```text
auth.json
.env и реальные local overrides
API keys, passwords, access/refresh tokens
memory.db, *.db-wal, *.db-shm
sessions/, traces/, missions/
*.jsonl и trace.html из живых запусков
node_modules/, virtualenv, модели и caches
личный глобальный AGENTS.md
полные рабочие settings/models/mcp configs без allowlist-санитизации
архивы домашней папки или профиля Pi
```

Запрещены и их base64/hex/URL-encoded варианты, если они восстанавливают credential или приватный payload.

## Пути и идентификаторы

Публичные файлы не содержат:

- конкретное имя пользователя ОС;
- hostname;
- абсолютные `C:\Users\...`, `C:\PY\...` и синхронизируемые личные пути;
- email, ID аккаунтов и приватные URL;
- названия непубличных проектов в примерах, если они не нужны контракту.

Используй `%USERPROFILE%`, `$HOME`, `<PROJECT_ROOT>`, `<PORT>`, `<API_KEY>` и параметры installer.

Публичный GitHub URL собственного проекта (`pi-polza`) и имя публичного автора допустимы как библиографические/установочные сведения, но не как machine identity.

## Генерация безопасных шаблонов

Рабочий файл с секретами нельзя копировать, а затем чистить. Создай новый template по allowlist:

1. определи документированные несекретные поля;
2. запиши их заново;
3. замени credential на явный placeholder или env reference;
4. удали machine-specific cache/state;
5. проверь template parser-ом;
6. сравни schema/ключи с источником, не сравнивая secret values.

Placeholder должен быть очевидным и не выглядеть как настоящий ключ:

```text
PASTE_BRAVE_API_KEY_HERE
${POLZA_API_KEY}
<LOCAL_MCP_PORT>
```

## Проверка перед каждым commit

Safety scan должен:

- отклонять запрещённые имена и расширения;
- искать абсолютные домашние пути;
- искать типичные token prefixes (`sk-`, `ghp_`, `github_pat_`, JWT и provider-specific markers);
- искать длинные случайные строки в JSON/YAML/env/Markdown;
- проверять staged diff и полный tracked tree;
- не печатать найденное значение целиком — только файл, строку и класс совпадения;
- завершаться ненулевым exit code при находке.

После автоматического scan просматривай staged diff вручную: detector не понимает все форматы credentials и личного контекста.

## Если секрет попал в commit

1. Немедленно остановить push/publication.
2. Отозвать или заменить credential — даже если commit ещё кажется локальным.
3. Очистить историю, а не только последний снимок.
4. Повторно просканировать все refs и packed objects.
5. Зафиксировать только факт ротации без самого секрета.

Если секрет уже опубликован, считай его скомпрометированным независимо от скорости удаления.

## Перенос лабораторных sources и evidence

Безопасные harness sources/validators/synthetic fixtures можно сделать сопровождаемыми repository tests после проверки происхождения/лицензий и удаления machine binding. Не переносить вместе с ними реальные configs/env dumps, DB/sessions/trace outputs, compiled artifacts или raw host receipts. Рабочий secret-bearing config нельзя копировать и чистить даже под названием fixture: новый sample создаётся по allowlist.

Фиксировать measured scope/provenance: public board содержит безопасные IDs и limitations, raw packet — вне Git. Не печатать credentials ради hash/probe диагностики; personal DB/WAL/auth contents не читать как часть lab проверки. Архив исходников release не должен случайно включить private runtime-state. Стенд на другой машине получает repo/source и synthetic state, не копию домашней папки.

## Runtime backup — отдельный канал

Пользовательская память, сессии и auth могут переноситься только отдельным зашифрованным архивом вне Git. Этот репозиторий может содержать инструкцию и backup script с allowlist, но не сам архив и не пароль.
