# Шаблон отчёта: результат операции

> АГЕНТ: ЧИТАЙ ЭТОТ ФАЙЛ ЦЕЛИКОМ. Ниже только **СИНТЕТИЧЕСКИЙ ПРИМЕР**; рабочий отчёт строится из read-back.

```markdown
## Перегруппировка завершена — 2099-01-02

| № | Id / key | Тема | Source | Проверка |
|---:|---|---|---|---|
| 1 | `demo.runtime.retry.rule` | Retry limit и remedy | user | ✅ read-back, facts 3/3 |
| 2 | `demo.editor.preference` | Настройка редактора | user | ✅ не затронуто |
| L1 | `00000000-0000-4000-8000-000000000001` | Failed batch rule | user | ✅ не затронуто |

Операции: ➕ 1 · 💀 2 · ✏️ 0. Owner override: подтверждён для №1. Факты сохранены 3/3.
Post-probe: 2780/8000 chars, truncation: нет. Нерешённых пунктов нет.
```

## Варианты закрывающей строки

- Cleanup: `Удалено 2 подтверждённых machine rows; owner rows не затронуты.`
- Compression: `demo.key: 340 → 180 chars; facts 5/5; source сохранён.`
- Partial: `Применён только пункт 2; пункты 1 и 3 не затронуты.`
- Failure: `Транзакция откатилась; read-back подтвердил исходное состояние; incident записан без содержимого памяти.`

## Правила

- Итог основан на read-back, а не на exit code.
- Реальные identifiers обязательны; вымышленные labels запрещены.
- Указать fact preservation, owner override status и post-probe.
- Секреты и тексты owner records в runtime log не переносятся.
