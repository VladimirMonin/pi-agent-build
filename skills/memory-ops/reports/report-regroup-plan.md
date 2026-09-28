# Шаблон плана: split / regroup 🌀→✅ 📦

> АГЕНТ: ЧИТАЙ ЭТОТ ФАЙЛ ЦЕЛИКОМ. Ниже только **СИНТЕТИЧЕСКИЙ ПРИМЕР**.

```markdown
## План перегруппировки — 2099-01-02

| Было | Станет | Source / защита |
|---|---|---|
| `demo.runtime.mixed` 🌀: retry + editor | `demo.runtime.retry.rule` ✅ + append в `demo.editor.preference` ✅ | user; нужен owner override |
| `demo.runtime.retry.old` 🕰️ | поглощён `demo.runtime.retry.rule` | consolidation |

**Операции:** create/update 2 → read-back → delete 2.
**Сверка:** facts 4/4; identifiers `RETRY_LIMIT`, `3` сохранены.
**Бюджет:** expanding domain 900 → 520 chars; прогноз требует post-probe.
**Правило:** факты не меняются — меняются только тематические группы.
Подтвердить? Для owner row требуется отдельное согласие на old → new.
```

## Правила

- Каждая source row присутствует в таблице.
- Все targets показаны до apply.
- Указать stores, keys/ids, source и reachability impact.
- Обязательны operation count и reconciliation N/N.
- Выполнение только после подтверждения; owner rows — только с отдельным override.
