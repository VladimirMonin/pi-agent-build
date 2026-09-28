# Режим 🧬 Drift консолидации

> АГЕНТ: ЧИТАЙ ЭТОТ ФАЙЛ ЦЕЛИКОМ. Machine-generated запись подозрительна, но не является мусором автоматически.

Когда: нужно проверить строки, созданные автоматической консолидацией или неизвестным машинным источником. Формат: [audit report](../reports/report-audit.md).

## Шаги

1. Выбрать все facts/lessons, где `source != user`, включая version-specific значения. Удалённые lessons исключить.
2. Для каждой строки проверить:
   - истинна ли она сейчас;
   - durable это или snapshot;
   - конфликтует ли с `source=user`;
   - дублирует ли source of truth/другую запись;
   - не потеряна ли reachability из-за key/project.
3. При конфликте owner record имеет приоритет, но не переписывается. Machine row предлагается исправить, слить или удалить.
4. Preference order: rewrite из проверенного источника → merge → delete доказанного дубля/ошибки.
5. Machine lessons и дорогие расширяемые fact domains проверять раньше дешёвых leaf records.
6. Показать таблицу `id/key, source, evidence, action, budget impact`. Получить подтверждение по пунктам.
7. Backup → dry-run → apply. Если merge затрагивает owner row, нужен отдельный owner override и итог сохраняет owner provenance.
8. Read-back, N/N, post-probe, completion report и runtime log.

## Gate

- [ ] Все machine sources выбраны, не только literal `consolidation`.
- [ ] Истинность проверена инструментами.
- [ ] Snapshots отделены от durable rules.
- [ ] Conflicts разрешаются в пользу owner statement без его тихой правки.
- [ ] Rewrite/merge рассмотрены до delete.
- [ ] Бюджет измерен.
- [ ] Owner records без override не тронуты.
- [ ] Итог верифицирован чтением.
