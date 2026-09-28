# Шаблон отчёта: полный аудит 🔍

> АГЕНТ: ЧИТАЙ ЭТОТ ФАЙЛ ЦЕЛИКОМ. Ниже только **СИНТЕТИЧЕСКИЙ ПРИМЕР**; не копируй его идентификаторы в рабочий отчёт.

```markdown
## Аудит памяти — 2099-01-02

**Измерение:** plugin demo-1.0; snapshot; case set `demo-cases.json`; block 3120/8000 chars; truncation: нет.

| № | Id / key | Тема | Reachability | Ценность | Integrity | Source | Вывод |
|---:|---|---|---|:---:|:---:|---|---|
| 1 | `demo.editor.preference` | Форматирование редактора | match-only | 🟢 | ✅ | user | Оставить; owner statement |
| 2 | `demo.runtime.retry.limit` | Retry limit 3 | domain-expanded | 🟠 | ✅ | consolidation | Проверено по synthetic config; предложить rewrite |
| 3 | `demo.runtime.retry.old` | Старый retry limit | domain-expanded | — | — | consolidation | 🕰️ доказанно устарело; предложить merge |
| L1 | `00000000-0000-4000-8000-000000000001` | Не повторять failed batch | always-injected | 🔴 | ✅ | user | Оставить |

**Флаги:** 💀 0 · 🕰️ 1 · 🌀 0 · 🔁 0 · 🧬 2 · 🕳️ 0.
**Secrets sweep:** совпадений нет.
**Предложение:** объединить №2–3 после dry-run; №1 и L1 не менять. Подтвердить пункт №2–3?
```

## Правила

- Реальный отчёт использует identifiers только из проверяемого snapshot.
- Source, reachability, measurement version и truncation обязательны.
- Для каждого диагноза приводится evidence без секретов.
- Аудит ничего не меняет.
- `source=user` помечается как owner-protected; для rewrite/delete требуется отдельный owner override.
