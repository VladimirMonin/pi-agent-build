# Pi Agent Build — вход для агентов

Репозиторий описывает переносимую version-pinned сборку с двумя профилями: **Code** и **Task**. Он не является копией домашнего каталога или хранилищем памяти/credentials. Текущее состояние версии и поддержки читай в manifests и [readiness board](docs/plans/lab-readiness-board.md), не восстанавливай его из старого чата.

## Правила разработки

1. **Простое лучше сложного. Сложное лучше запутанного. Читаемость имеет значение. Сложность должна быть контролируемой.**

2. **Должен существовать один основной и очевидный способ сделать что-либо в программе.** Не создавай второй механизм, если уже есть нормальный существующий.

3. **Предпочитай минимальное корректное решение.** Не создавай архитектуру на будущее, лишние слои, интерфейсы, фабрики, менеджеры, retry, fallback, конфигурации и универсальные механизмы без текущей необходимости.

4. **SOLID, DRY и паттерны важны, но не являются самоцелью.** Если их применение делает решение сложнее, менее читаемым или создаёт лишние сущности — предпочитай простое решение.

5. **Не расширяй задачу самостоятельно.** Не превращай локальный фикс в рефакторинг проекта и не исправляй соседние проблемы, если они не мешают текущей задаче.

6. **Работай по схеме: понять → минимально исследовать → реализовать → проверить → закончить.** Анализ, план и исследование не являются результатом работы.

7. **Не буксуй.** Если ты долго читаешь файлы, вызываешь инструменты, обсуждаешь риски и строишь гипотезы, но код не приближается к готовому результату — прекрати исследование и попробуй конкретное решение.

8. **Не перестраховывайся без причины.** Не спрашивай подтверждение для обычных локальных и обратимых действий: чтения и изменения файлов, запуска тестов, линтера, сборки и исправления собственных ошибок.

9. **Тестируй достаточно, а не максимально.** Сначала запускай тесты, связанные с изменением. Не гоняй весь test suite после каждого шага и не создавай тесты для каждого воображаемого edge case.

10. **Учитывай реальные edge cases, а не гипотетические.** Не усложняй основной код ради крайне редкого сценария, если его можно просто корректно отклонить.

11. **Подагенты нужны для независимой работы, а не для бюрократии.** Одна задача — один ответственный агент. Не создавай рекурсивную армию агентов. Главный агент отвечает за итоговый результат, а не просто пересказывает отчёты подагентов.

12. **Задача завершена, когда требуемое изменение реализовано и разумно проверено.** После этого остановись. Не продолжай рефакторить, улучшать архитектуру и искать дополнительные проблемы только потому, что можешь.

**Главный принцип: рабочее, простое и понятное решение лучше архитектурно идеального решения, которое сложнее необходимого.**

## Goal X — автономная работа

Do not modify Goal X settings unless explicitly requested by the user. Never set maxAutonomousRuns to 0.
For technical blockers use blocked, not paused, so Blocker Oracle can intervene.

Пресет и применение: [Goal X](docs/goal-autonomy.md).

## Источники истины и начало работы

1. Перед изменением состава прочитай BUILD.Master и тематические инструкции ниже.
2. Версии: [runtime lock](manifests/runtime.lock.json), [packages lock](manifests/pi-packages.lock.json), [external tools lock](manifests/external-tools.lock.json). Не устанавливай latest и не расширяй guards по предположению совместимости.
3. Перед обновлением: [паспорт стенда](docs/lab-stand.md), [upgrade workflow](docs/pi-upgrade-workflow.md), [evidence contract](docs/lab-evidence.md). Если требуемая команда ещё не реализована, не выдавай её описание за работающий инструмент.
4. Проверь Git-состояние. Не стирай чужие изменения/untracked state; runtime writes разрешены только в явно принадлежащем работе private root вне Git.
5. Рабочие профили/память/auth не являются test fixtures. Не копируй их в lab. Документ сам по себе не разрешает install, native/model calls, release или working-profile switch: проверь scope текущего запроса.

## Каталог постоянных инструкций

| Инструкция | Когда читать |
|---|---|
| [BUILD.Master](instructions/BUILD.master.instructions.md) | Состав, manifests, profiles, installer/verifier и release contract |
| [BUILD.LabUpgrade](instructions/BUILD.lab_upgrade.instructions.md) | Обновление Pi, preparation стенда, lab testing, границы исполнения и handoff |
| [PATCH.Maintenance](instructions/PATCH.maintenance.instructions.md) | Patcher/version/hash guards, upstream fixes, check/apply/restore и executable staging |
| [SEC.PublicRepository](instructions/SEC.public_repository.instructions.md) | Templates, fixtures, logs, private source promotion, secrets и публикация |
| [DOCS.InstructionsStyle](instructions/DOCS.instructions_style.instructions.md) | Создание/изменение AGENTS и instructions, owner/frontmatter/catalog |
| [DOCS.CommitMessages](instructions/DOCS.commit_messages.instructions.md) | Staging, semantic commits, проверка, tags и publication |

## Практические ориентиры

- Сохраняй ровно Code/Task; политика нового выпуска — Trace установлен, но выключен по умолчанию в обоих. Явное включение должно иметь проверенную инструкцию и не создавать третий профиль. Текущее выполнение этой политики и команды находятся в [workflow](docs/pi-upgrade-workflow.md) и board; не утверждай, что planned поведение уже реализовано.
- Для обычного обновления достаточно явно выбранного установочного каталога и synthetic checks без изменения живых профилей. Не создавай VM, Windows Sandbox, native runners или новые isolation frameworks без отдельного запроса владельца. Worktree, отдельный prefix и environment guards не являются защитной границей ОС.
- PASS указывай вместе с source/command/scope. Source, managed, mock, native и live-provider evidence не взаимозаменяемы; NOT TESTED не равно PASS.
- Делай связный функциональный срез. Повторяй проверки изменённой границы; переиспользуй только применимые неизменённые evidence. Конкретный дефект не требует нового широкого audit loop.
- Runtime-state/raw receipts вне Git; public diff проверяется safety scan и вручную. Git revert не откатывает executable, profiles и данные.
