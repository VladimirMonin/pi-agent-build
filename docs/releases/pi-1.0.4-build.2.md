# Pi 1.0.4 build.2 — Subagents, Goal X, Intercom

Короткое обновление личной сборки. Pi остаётся **1.0.4**, обновлены только три пакета:

| Пакет | Было | Стало |
|---|---|---|
| pi-subagents | 0.76.0 | **0.76.1** |
| pi-goal-x | 0.31.9 | **0.32.3** |
| pi-intercom | 0.13.0 | **0.16.1** |

Остальные пакеты, внешние инструменты, Goal X preset, модели, картинки и disabled filters не менялись. Порядок **Goal X → Intercom** сохранён. Обновлены manifests, Code/Task, связанные pinned-order fixtures и документация.

## Что получаем

- Subagents и Intercom будят idle parent/receiver через обычный Pi turn: `before_agent_start` добавления расширений сохраняются.
- Goal X заявляет поддержку Pi 1.x, обрабатывает failed compaction и дополнительно распознаёт `PROTOCOL_ERROR` / `finish_reason: error` как временные ошибки. Лимиты и настройки пользователя не меняются.
- Intercom запускает Windows broker скрытым Node-процессом, без прежнего VBS-helper.

## Короткая проверка

- Actual Pi 1.0.4 + candidate Code/Task: **13/10 extensions, errors 0, warnings 0, fetch 0**, `node tests/sdk/profile-loading.mjs <SDK_ROOT> <SYNTHETIC_PROFILE>` в private HOME.
- Private local-mock smoke: новый production `createParentWake` получил synthetic completion, вызвал обычный turn и сохранил canary prompt addition и Subagents guidance. Это не полный запуск background child или live Polza.
- Два отдельных Node-процесса с SDK-сессиями и новыми тремя extensions: настоящий Windows Intercom broker, адресный send и idle receiver wake через обычный turn — PASS.
- Старый synthetic goal с `nextAction`: чтение, нормализация, явный synthetic focus, продолжение через mock tool call и завершение/архивирование — PASS. `nextAction` отсутствует в новом сохранённом scheduler. Headless hooks Goal X → Intercom прошли без ошибок. Fake transient recovery и настоящий auditor/provider не запускались.
- `tests/scripts/run-tests.ps1`: **24/24**; Both repository verifier: **0 failures / 0 warnings**.
- `tests/scripts/goal-order-posix.sh`: PASS в Windows Git Bash с explicit Python path; это не native Linux/macOS proof.
- Exact-three delta и неизменность Core/external/Goal preset проверены; safety scan, links и diff review выполнены перед публикацией.

Raw fixture outputs остаются вне Git. При настройке smoke исправлены ошибки самого fixture: normalized system messages, выбор active tools, отдельный sender process и проверка archived goal вместо уже снятого focus. Это не исправления production-пакетов. Полная новая матрица, paid Polza smoke, MCP/WVM transport и соседние апдейты не входят в этот релиз; MCP adapter KEEP.

## Установка себе

Для существующей установки обновляйте **только эти три exact specs**, не `update --all` и не полный installer. Перед первой живой работой нового Goal X один раз скопируйте текущий project `.pi/goals` вне Git: после сохранения новой версией scheduler больше не содержит `nextAction`, который нужен старому Goal X. Рабочие settings/auth/память не заменять.

```powershell
foreach ($profile in @("$HOME/.pi/agent", "$HOME/.pi/task")) {
    $env:PI_CODING_AGENT_DIR = $profile
    pi install npm:pi-subagents@0.76.1
    pi install npm:pi-goal-x@0.32.3
    pi install npm:pi-intercom@0.16.1
}
Remove-Item Env:PI_CODING_AGENT_DIR
```

Если задан custom `intercom/config.json` → `brokerCommand`, он должен указывать на executable, а не `.cmd` shim. После установки нужен **полный перезапуск Pi и старых сабов**, не горячий `/reload` Subagents. Публикация исходников сама по себе рабочие пакеты не обновляет.

Следующий отдельный срез — Serena по [короткому плану](../plans/plugin-updates.md); в этом релизе её версия не менялась.
