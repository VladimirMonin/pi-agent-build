# Trace 0.1.16: русский интерфейс, Windows UTF-8 и профили

Поддерживаемая версия: `pi-trace-extension@0.1.16`.

## Что исправлено

1. Жёстко заданный китайский интерфейс viewer/dashboard переведён на русский.
2. Python renderer на Windows падал после успешной записи HTML, когда `stdout=cp1251` не мог вывести `✓`. Потоки `stdout/stderr` теперь явно переводятся в UTF-8.
3. Каталог traces учитывает `PI_CODING_AGENT_DIR`, чтобы профили Code и Task не смешивались.

`viewer/assets.json` не копируется: после применения patcher запускает штатный `viewer/build.py` с UTF-8 окружением.

## Использование

```powershell
python .\patches\trace-ru-windows-profile\apply.py `
  --agent-dir "$HOME\.pi\agent" --check

python .\patches\trace-ru-windows-profile\apply.py `
  --agent-dir "$HOME\.pi\agent" --apply
```

Повторить для Task-профиля при его наличии.

Проверка возвращает:

- `ALREADY PATCHED` и exit `0` — целевой payload установлен;
- `PATCH REQUIRED` и exit `1` — состояние распознано и может быть исправлено;
- `UNKNOWN STATE` и exit `2` — автоматическая перезапись запрещена.

## Проверка в Pi

После `/reload`:

```text
/trace
/trace all
```

Обе команды должны создать HTML без `UnicodeEncodeError`; интерфейс должен быть русским. Команды `/trace-dashboard` нет.

## Откат

`--apply` сохраняет точный runtime-backup под выбранным профилем:

```text
<PI_PROFILE>/.pi-agent-build-backups/trace-ru-windows-profile/
```

Откат к последней сохранённой копии:

```powershell
python .\patches\trace-ru-windows-profile\apply.py `
  --agent-dir "$HOME\.pi\agent" --restore
```

## После обновления

`pi update` перезаписывает package files. Сначала проверь установленную версию. Patcher откажется работать с версией, отличной от `0.1.16`; новый upstream необходимо повторно исследовать и только потом обновлять payload/hashes.
