# Human summary in chat after the retrospective

> Read before workflow step 7. The chat report is AUTHORED BY A SUBAGENT — the
> one that ran the analysis or a dedicated report subagent — and relayed verbatim
> by the orchestrator of the main session, so the expensive main-session context
> stays small. These style rules bind the report author. The rules below are
> adapted from the user's plain-speech skill (caveman); the Russian source body
> is copied at the end of this file for exact wording when the report is in
> Russian.

## What the report is

One detailed, honest message in the user's language. It says what the period
really produced, what the user's asks came to, and what remains — in plain words,
without hiding important small things behind simplification.

## Hard style rules for the report

1. No technology names, no class names, no developer jargon, and no anglicisms
   in a Russian report. When a name is genuinely needed to find information, give
   it once in general words ("the project file of the code") instead of a slogan.
2. Details stay in: numbers, order of steps, conditions, negations, limits, and
   what is not known. Simplify words, never facts.
3. Answer first: verdict and results up front, then why, then what is next.
4. One mermaid diagram when it explains a real relation — the route of the work,
   who talked to whom, how ideas connect, or the whole picture. No diagram quota.
5. If the user asks for a shorter or a more detailed answer, that applies to the
   next answer.

## What the report must carry from this skill

- wanted to got to evidence to remaining, row by row, in words;
- volume in honest counts: files, commits, checks run and checks not run;
- emphasis points honored or missed;
- small deferred defects with place, effect and next check;
- the next useful steps.

## Where the style does not apply

Code, comments, quotes, documents, letters, commit messages, memory records and
exact error messages keep their exact form — never rewrite those into this style.
The style governs the chat report only.

## Diagrams in the report

The report author draws the diagrams AND validates them (optional mermaid CLI
flow in `references/mermaid-diagrams.md`), so the main session never renders or
checks them. New mermaid defects go to `journal/mermaid-defects.md`. Keep report
diagrams conservative — short labels, one relation per line.

## Source body (Russian, copied from the caveman skill)

> Ниже — дословно скопированное тело навыка caveman. Используй его формулировки
> как точные правила при русском отчёте.

### Как включать и выбирать объём

| Объём | Когда | Что выдать |
|---|---|---|
| **Коротко** | «короче», «только главное», «в двух словах» | Ответ, одна необходимая причина или оговорка, действие при необходимости. Не превращай его в шифр. |
| **Обычно** | Объём не указан | Ответ и столько причин, последствий и промежуточных сведений, чтобы не пришлось отдельно выпытывать основу. Без длинных вводных и повтора вывода. |
| **Подробно** | «подробнее», «разбери по шагам», «почему так» | Объясни механизм, существенные промежуточные шаги, условия и последствия. Пример или аналогия — только если помогают понять. |

**Понятность неизменна во всех трёх случаях.** «Короче» сокращает второстепенное, а не определения, необходимые для понимания. «Подробно» добавляет объяснение, а не плотность специальных слов.

### Как объяснять

1. Сначала ответь на вопрос или назови честное состояние дела; затем объясни причину и следующее действие, если оно действительно нужно. Не начинай с церемоний и не заканчивай повторным итогом.
2. Сначала опиши явление простыми словами, потом введи профессиональное название, **если оно понадобится далее** или поможет найти сведения. При первом важном упоминании дай краткое пояснение. Не переводить каждое знакомое слово механически и не составлять словарь ради словаря.
3. Предпочитай точное русское выражение ненужному англицизму. «Повторно использовать результат» понятнее «сделать reuse». Но имена классов, команд, параметров и цитируемые ошибки оставляй без искажений и при необходимости объясняй рядом.
4. Не выдавай русифицированный жаргон за ясность. «Изменили структуру кода, чтобы убрать дублирование; поведение осталось прежним» может быть яснее, чем «произвели рефакторинг ядра». Если факты о результате неизвестны, не утверждай, что именно было изменено или что поведение не изменилось; уточни либо назови это возможным объяснением.
5. Сохраняй отрицания, условия, порядок действий, числа, единицы, ограничения и неопределённость. Если короткая фраза допускает два прочтения — используй полное предложение. Не смягчай предупреждения ради краткости.
6. Аналогия необязательна. Применяй её к одному конкретному механизму; покажи соответствие с реальностью и, если существенно, место, где сравнение перестаёт работать. Не подменяй аналогией проверяемые факты.

Если пользователь говорит «не понял», **найди неясное звено** — термин, пропущенный шаг или неназванную причину — и объясни иначе. Не повторяй то же предложение с большим количеством слов.

### Где стиль не применять

Эти правила задают тон **ответа в чате**. Не сокращай и не переписывай автоматически код, существующие комментарии, цитаты, документы, письма, коммиты, записи памяти, тексты для третьих лиц или точные сообщения об ошибках. Для опасных или необратимых действий, неоднозначной последовательности шагов и важных оговорок используй достаточно полные фразы даже в режиме «коротко».

### Проверка перед отправкой

- Получил ли пользователь ответ без необходимости вытягивать основу следующими вопросами?
- Есть ли важный термин или англицизм без объяснения, ненужное вступление, повтор или длинная ветка не по вопросу? Исправь нужный слой, не переписывая всё подряд.
- Сохранены ли точные названия, отрицания, числа, условия, порядок, осторожность и уровень уверенности?
- В режиме «подробно» прибавилось ли понимания, а в режиме «коротко» не исчезла ли существенная причина?
