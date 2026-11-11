# pi-serena 0.10.1: скрытие двух tools и честная guidance

Целевая связка: `@bacnh85/pi-serena 0.10.1`, `serena-agent 1.7.0`, Python/Pyright.

Wrapper регистрирует 20 инструментов, но два не работают в этой связке:

- `serena_check_onboarding_performed`: удалён в Serena1.7; onboarding теперь режим агента;
- `serena_find_implementations`: Pyright не объявляет `implementationProvider`, LSP возвращает `-32601`.

Patch комментирует только эти регистрации и убирает рекомендацию `find_implementations` из `SERENA_FIRST_GUIDANCE`. Остаётся 18 tools. References не являются заменой implementations. Worker, Python bridge, Serena Agent и project config не меняются.

Перенос с 0.9.20 (2026-11-11): upstream дефекты **не исправлены** — оба мёртвых tools регистрируются и в 0.10.1, guidance-реклама на месте. Зона задета косметически: внутри обоих блоков регистрации добавлена строка `exposure: "deferred" as const,` (deferred tier, 0.10.0/0.10.1). Механика patch без изменений воспроизводит canonical на 0.10.1: закомментированный `registerTool` означает, что инструмент не попадает в `getAllTools()` и новый direct-activate fallback (0.10.1, issue #49) его не активирует и не показывает модели.

## Использование

```powershell
python .\patches\serena-tools\apply.py --agent-dir "$HOME\.pi\agent" --check
python .\patches\serena-tools\apply.py --agent-dir "$HOME\.pi\agent" --apply
```

`--check`: 0 = canonical tools+guidance, 1 = exact stock требует patch, 2 = missing/unknown/mixed state или неподдерживаемая версия. Immutable pristine copies в `store/index.ts.orig-0.10.1` и `store/guidance.ts.orig-0.10.1` относятся только к 0.10.1; старые версии не допускаются guard. Прежние копии `*.orig-0.9.20` сохранены в том же `store/` как byte-эталон для отката (guard 0.9.20 больше не принимает: откат = переустановка 0.9.20 + ручное восстановление из store). Apply идемпотентен. Runtime backups обоих файлов находятся в выбранном профиле `.pi-agent-build-backups/serena-tools`, не в Git.

## Проверка

Связанный regression в `tests/scripts/run-tests.ps1` проверяет сохранность tracked stores, guidance, idempotence, drift/mixed-state refusal и byte-exact restore обоих файлов. Короткий runtime smoke на кандидате: 18 реально registered tools; hidden tools не видны; guidance их не предлагает; `serena_find_symbol` на synthetic Python project возвращает body через настоящий установленный Serena/Pyright. Source/static check не заменяет этот smoke.

## Откат и ограничения

```powershell
python .\patches\serena-tools\apply.py --agent-dir "$HOME\.pi\agent" --restore
```

Restore возвращает exact stock `extensions/index.ts` и `extensions/lib/guidance.ts`, но не делает отсутствующие backend capabilities рабочими. Другой backend может поддерживать implementations; повторно проверяйте capabilities перед снятием patch. После переустановки пакета примените patch заново и перезапустите Pi. Unknown или частично patched state автоматически не исправляется.
