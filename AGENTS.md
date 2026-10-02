# Pi Agent Build — вход для агентов

Репозиторий описывает переносимую version-pinned сборку с двумя профилями: **Code** и **Task**. Он не является копией домашнего каталога или хранилищем памяти/credentials. Текущее состояние версии и поддержки читай в manifests и [readiness board](docs/plans/lab-readiness-board.md), не восстанавливай его из старого чата.

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
- Worktree изолирует Git, не ОС. Environment guards, metadata hashes и mocks не являются native/global isolation proof.
- PASS указывай вместе с source/command/scope. Source, managed, mock, native и live-provider evidence не взаимозаменяемы; NOT TESTED не равно PASS.
- Делай связный функциональный срез. Повторяй проверки изменённой границы; переиспользуй только применимые неизменённые evidence. Конкретный дефект не требует нового широкого audit loop.
- Runtime-state/raw receipts вне Git; public diff проверяется safety scan и вручную. Git revert не откатывает executable, profiles и данные.
