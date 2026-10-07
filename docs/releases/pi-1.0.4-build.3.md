# Pi 1.0.4 build.3 — Context Inspector и Serena

Release tag: `pi-v1.0.4-build.3`. Pi остаётся **1.0.4**.

## Изменения

- Code/Task: `pi-context-inspector` **1.1.1 → 1.3.0**, чистый pin без patch/config migration. Overlay и paging используют текущую высоту терминала; optional `e` открывает editor snapshot, не изменяя session.
- Только Code: `@bacnh85/pi-serena` **0.9.16 → 0.9.20**. Serena Agent **1.7.0** и Python/Pyright не меняются. Exact patch скрывает два отсутствующих tools и убирает `find_implementations` из guidance. Новые pristine copies и file-level provenance для обоих файлов.
- Остальные pins, Goal X → Intercom order, Trace/Background Tasks default-off и пользовательские настройки сохраняются. Session Search, Memory и MCP здесь не обновляются.

## Проверки

- **Synthetic candidate loading, actual installed Pi1.0.4 SDK:** `node tests/sdk/profile-loading.mjs <SDK_ROOT> <PRIVATE_PROFILE>` — Code13/Task10 extensions, errors0/warnings0/fetch0.
- **Private patch lifecycle:** stock check1 → apply0 → check0 → idempotent apply0 → byte-exact restore0 → stock check1 → apply0. Связанный public regression дополнительно проверяет guidance drift и mixed-state refusal.
- **Native Serena/Pyright, synthetic Python project:** installed0.9.20 зарегистрировал18 tools; hidden tools отсутствуют и guidance их не предлагает. Реальный `serena_find_symbol` вернул body `synthetic_add`; Serena1.7.0/LSP сообщает ready. Модельных/provider calls нет.
- **Inspector command with synthetic UI against actual Pi1.0.4 SDK:** `/context` factory создаёт5 tabs; rows20/8/50 дают18/7/35 lines с footer/border; resize меняет PageDown/PageUp, поиск работает, `y` dispatch отдаёт полный текст tab mocked clipboard target. Это не native visual TUI/OS clipboard test.
- `powershell -File tests/scripts/run-tests.ps1` — **24/24**; `scripts/verify.ps1 -RepositoryOnly -Profile Both -RepoRoot <REPO_ROOT>` — **0 failures/0 warnings**. Safety/diff checks выполняются перед публикацией.

Native visual TUI, настоящий clipboard и optional editor launch — **NOT TESTED**. `$EDITOR` сборка не меняет; quoted executable paths с пробелами stock1.3 разбирает неправильно. Не добавляем ради optional функции локальный patch. Core-only/local-mock и build.2 broker evidence не повторяются: их inputs не меняются.

## Установка себе

**Установка завершена:** штатный Pi lifecycle поставил exact Inspector1.3.0 в Code/Task и Serena0.9.20 только в Code; `serena-tools` применён к Code. Свежая загрузка actual installed payloads: Code13/Task10, errors0/warnings0/fetch0. Assertions подтвердили сохранение прочих settings/package versions, models/Goal X settings и sampled unrelated patch bytes. Не использовать полный installer или `update --all`, не заменять settings/auth/memory/sessions. Свежий loader process проверяется отдельно от живого TUI. Открытые Pi-сессии полностью перезапускает владелец.

Private candidate, raw logs и synthetic state находятся вне Git; не публикуются. Публичный runtime support не расширяется за пределы перечисленных проверок.
