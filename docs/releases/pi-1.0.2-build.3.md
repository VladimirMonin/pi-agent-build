# Pi 1.0.2 build.3 — Polza 0.2.1 и memory-ops 1.0.1-public

Source-only follow-up к [build.2](pi-1.0.2-build.2.md). Core остаётся exact **Pi 1.0.2**; Code/Task, Goal X, Trace default-off, MCP owner и guarded patches не изменены. Новый tag `pi-v1.0.2-build.3` и repository release публикуются отдельно; эта интеграция не выполняет установку и не переключает рабочие профили. Старый публичный build.2 не заменяется.

## Состав и exact source

- `pi-polza` **0.2.1**, публичный [upstream release v0.2.1](https://github.com/VladimirMonin/pi-polza/releases/tag/v0.2.1).
- Immutable install source: `https://github.com/VladimirMonin/pi-polza@cbc8a61262eb682fc61c9ab1b3b1ab72ef08f139`.
- Peeled commit: `cbc8a61262eb682fc61c9ab1b3b1ab72ef08f139`; annotated tag object: `a93589ecd0075d3f4c34eb1f13bda891c5983d8c`. Remote refs проверены публикующим controller; локальный immutable source подтверждает version **0.2.1**, repository URL и MIT в `package.json`/`LICENSE`.
- Manifest, Code/Task templates и fake package/HEAD/tag/peel fixtures согласованы; installed package payload не вендорится. Top-level commit pin не фиксирует transitive npm tree.
- Выпуск включает **memory-ops 1.0.1-public** из предшествующего commit. Навык не изменён в этом срезе; прежняя запись CHANGELOG сохранена.

## Исправления plugin

Нативные расходы Polza учитываются один раз по последнему `usage.cost_rub` после успешного ответа Pi1.0.2, независимо от задержки закрытия SSE после `[DONE]`. Отсутствующая/некорректная стоимость, ошибки и отмена остаются unknown, настоящий ноль сохраняется. Неудачный balance refresh сохраняет последнюю сумму с пометкой `stale`; успешный снимает пометку. Частота запросов баланса не меняется.

## Evidence и границы

| Источник | Результат / scope |
|---|---|
| Принятый upstream plugin handoff для v0.2.1 | **203/203 offline checks**, включая **47 native checks** на actual installed Pi **1.0.2** с synthetic SSE; **audit/pack PASS**. Это не live-provider transport и не запуск тестов из build checkout |
| Сообщение владельца | Live acceptance в **новой сессии**; user-reported, не independently rerun здесь и не полный background-live |
| [Build.2](pi-1.0.2-build.2.md), неизменённая core/profile/patch граница | Reused loading13/10, errors0/warnings0/fetch0, local mock/CLI EOF и Windows regressions24/24. Старый package set: **не** fresh Both runtime нового Polza payload |

Repository gates для source интеграции (без full install; synthetic TEMP разрешён):

```powershell
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File scripts/verify.ps1 -RepositoryOnly -Profile Both -RepoRoot '<REPO_ROOT>'
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File scripts/safety-check.ps1 -Scope Both -Root '<REPO_ROOT>'
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File tests/scripts/run-tests.ps1
git diff --check
```

Результаты source-gates перед выпуском: repository-only Both — **0 failures / 0 warnings**; safety Both — **без находок**; Windows script regressions — **24/24**; изменённые Markdown — **77 относительных ссылок/anchors**; embedded JavaScript fixtures — **3/3 syntax PASS**; `git diff --check` — PASS. Независимый review: **OK with notes**.

Verifier проверяет schema/templates, не установленный новый Git checkout. Script regressions используют synthetic TEMP, fake npm/pi/git/uv и explicit fixture roots; не устанавливают реальные пакеты и не вызывают provider. Raw receipts остаются вне Git.

## Ограничения и обновление

- Проверенная plugin граница — Pi **1.0.2**; metadata peer `*` не доказывает совместимость со всеми Pi 1.x.
- Fresh Both runtime нового payload, полный background-live, прочие live providers/auth, full subagent execution, semantic embeddings, browser UI и native Linux/macOS **NOT TESTED в этой интеграции**.
- WVM legacy SSE/streamable HTTP **NOT TESTED**; synthetic plugin SSE не является WVM proof. Adapter KEEP.
- Auth, модели, память/DB, Goal X, working settings/runtime и старые release tags здесь не изменяются. Для будущей установки используйте [setup](../setup.md) и [provider docs](../polza-provider.md), затем новую Pi-сессию; source publication сама по себе не обновляет уже запущенный plugin.
- Raw receipts, личные paths, session/auth state и caches остаются вне Git. Source-only checks не являются OS isolation или bit-reproducibility proof.
