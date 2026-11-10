# Pi 1.5.2 build.7 — ядро 1.5.2 и честные проверки на Windows

Дата: 2026-11-10. Выпуск после [build.6](pi-1.4.0-build.6.md). Формат тега: `pi-v1.5.2-build.7`.
Ядро **Pi 1.4.0 → 1.5.2** (поток багфиксов upstream core). Node 25.8.1, npm 11.11.0 и все
пакеты профилей не менялись: Memory 1.6.1, Session Search 1.6.0, Polza 0.3.1, MCP Adapter 5.3.2,
Subagents 0.79.1, Goal X 0.32.3, Intercom 0.17.1 и остальные по [packages lock](../../manifests/pi-packages.lock.json).

## Что изменилось для пользователя

- **Ядро Pi 1.5.2.** Владелец обновил рабочую установку на месте; принят поток багфиксов
  upstream core. Закреплено в `runtime.lock.json` и обоих профильных templates
  (`lastChangelogVersion`). Плагины, настройки, память и история не мигрировались и не менялись.
- **Верификатор и установщик на Windows/git-bash перестали врать.** Windows-python отправляет
  `\r\n` через git-bash пайпы, и `\r` цеплялся к последнему полю каждой строки manifest:
  — `apply-patches.sh` сообщал «patcher missing» по всем патчам при их фактическом наличии
    и падал с fatal exit 2 (в `verify.sh` это выглядело как «patch checks failed»);
  — `verify.sh` не находил annotated тег `pi-polza` («release tag object differs») при
    совпадающем теге и коммите;
  — `verify.sh` давал ложный WARN «executable not found» по реально установленному
    `codebase-memory-mcp`.
  Теперь `manifest_packages`, `patches_for_profile` и внешние циклы manifests отдают байт-точные
  LF-строки (`tr -d '\r'` на источнике; в inline-циклах применён существующий `manifest_lines_lf`).
  PowerShell-путь (`verify.ps1`) этим багом не затронут.
- **Точные версии инструментов разведены на рабочий диапазон и lab-пины.** Рабочий диапазон для
  установки: Node ≥ 22.19 (engines ядра Pi и `pi-session-search` 1.6.0; проверено на 24+), npm из комплекта Node,
  Python ≥ 3.8, Git 2.x, uv без жёсткого пина (проверено на 0.9.27). Lab-пины воспроизводимости
  (Node 25.8.1 / npm 11.11.0 / Git 2.54.0.windows.1 / uv 0.9.27) нужны для приёмки сборки и её
  верификатора; расхождение с пином не означает нерабочую установку. Ранее точные версии читались
  как требование к пользователю (обратная связь P01–P02). Точный runtime-гейт не менялся:
  Windows-вариант сверяет exact, POSIX-drift — WARN. При этом «ещё не настроено» (креденшл не
  задан, инструмент не на PATH) больше не помечается FAIL.
- **Приёмка перестала врать** (обратная связь P40–P43):
  — `check-main-model.mjs` наконец вызывает `sdk.initTheme()` (build.4 ошибочно заявил это
    сделанным): канарейка Task больше не падает с «Theme not initialized» на исправной установке;
  — self-run guard helper'а нормализует пути (realpath + регистр на win32): молчаливый «пустой
    exit 0» невозможен, контракт «отказ = exit 2» восстановлен;
  — отчёт helper'а содержит текст ответа (`answer.text`) и детали ошибок расширений (`detail`);
  — `verify.ps1`/`verify.sh` не красят главный индикатор при «ещё не настроено»: незаданный
    креденшл маршрута памяти и инструмент не на PATH (uv tool) — это WARN; `check-memory-model.mjs`
    различает «не настроено» (exit 3) и «плохо поставлено» (exit 2).
- **Приёмка доведена до конца (обратная связь P44–P46).**
  — P44: креденшл-переменная маршрута памяти передаётся в проверочный процесс явно
    (Process/User/Machine scope): одна и та же проверка больше не даёт PASS/FAIL в
    зависимости от запускающего shell; `install.ps1` при незаданном ключе продолжает
    установку с пометкой «credential NOT TESTED», а не прерывает её;
  — P45: канарейка принимает ответ с любым регистром, пробелами/подчёркиваниями и хвостовыми
    знаками препинания (лишние слова по-прежнему отклоняются); проверено offline-тестами,
    живой повтор канарейки в этом срезе не запускался;
  — P46: верификаторы перестали быть слепыми — проверяют конфиг session-search
    (`check-session-search-config.mjs`: точная запись `modelPrefixes`, обе строки-префикса),
    установленные лаунчеры и наличие git-bash на Windows. Кейс-варианты ID моделей
    (`qwen/...` и `Qwen/...`) — валидные отдельные ключи, проверка их не путает.

## Проверки

- `scripts/verify.sh --profile Both` — **failures=0 / warnings=0** (83 PASS, включая новые
  проверки session-search/лаунчеров) на pinned
  Node 25.8.1 / Python 3.14.2 / Git 2.54.0.windows.1; `scripts/verify.ps1` — **failures=0 /
  warnings=0** (симметрично).
- Живая канарейка `check-main-model.mjs` на обоих профилях — **PASS** (по одному запросу:
  Code `polza/z-ai/glm-5.3-flash`, Task `ollama-cloud/deepseek-v4.1-flash`, `stopReason: stop`,
  ответ `PI_READY_OK`). Это та самая канарейка, что падала на Task по P40.
- Offline-проверки helper'ов: прямой запуск `check-main-model.mjs` без аргументов и с «чужим»
  регистром диска — exit 2 (не молчаливый 0); импорт как модуль не выполняет main;
  `check-memory-model.mjs` — exit 3 «credential NOT TESTED» на незаданном env-креденшле и
  exit 2 на пустой конфигурации.
- `scripts/apply-patches.sh --profile Both --mode Check` — все патчи PASS (5 в Code, 3 в Task):
  `trace-ru-windows-profile` и `session-search-profile` — patched, `memory-windows-runtime` —
  `runtime-safe`, `serena-tools`, `pi-cbm-011` — PASS.
- Живой smoke Code-профиля на рабочей машине (Windows x64, эта же установка): память —
  инъекция воспоминаний и гибридный recall (FTS5 + embeddings, 798/798 фактов проиндексированы);
  subagents — два фоновых прогона; intercom — connected; MCP — 4 сервера (ленивые, инструменты
  в кеше); Serena Agent 1.7.0; граф кода (codebase-memory) отвечает.

## Ограничения

- Живой старт Task-профиля проверен канарейкой уровня SDK (1 запрос); полный TUI-прогон
  обоих профилей не выполнялся.
- Helper приёмки: `--verbose` не добавлялся и виновник-расширение не выделен отдельной
  строкой интерфейса — детали ошибок расширений попадают в `detail` отчёта (частичное
  исправление P42).
- Полная plugin/live-provider приёмка не выполнялась; сборка не заявляет bit-for-bit
  reproducibility (см. «Границу повторяемости» в README).
- Требование Node — `>=22.19` (engines ядра Pi и `pi-session-search` 1.6.0);
  `compatibility.minimumNode` в runtime lock приведён к этой фактической границе (ранее там
  стояло `24.0.0` с неверным обоснованием «требование pi-session-search» — найдено проверяющим).
  Фактический гейт проверки — exact (Node 25.8.1 на Windows x64); сам «минимум» скриптами
  отдельно не проверяется.
- Обновление ядра выполнено владельцем на рабочей установке; пин воспроизводит фактическое
  состояние, а не результат штатного `install.sh` в чистое окружение.

## Установка и обновление

[INSTALL_FOR_AGENTS.md](../../INSTALL_FOR_AGENTS.md) — короткий preserving-маршрут.
Обычное обновление существующей установки: `install.sh --apply` c явным каталогом и синтетическими
проверками; живые профили, auth и данные не перезаписываются.

## Лицензии

Лицензии компонентов — [THIRD_PARTY.md](../../THIRD_PARTY.md) и
[THIRD_PARTY_NOTICES.md](../../THIRD_PARTY_NOTICES.md).
