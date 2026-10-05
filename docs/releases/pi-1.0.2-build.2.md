# Pi 1.0.2 build.2 — clean extension loading

Follow-up к [build.1](pi-1.0.2.md): Core остаётся exact stable **1.0.2**, Code/Task, Goal X autonomous preset и Trace default-off сохранены.

## Минимальные исправления

- `@juicesharp/rpiv-todo` **2.12.0**, `pi-subagents` **0.76.0**, `@nicknisi/pi-ast-grep` **0.2.1**: upstream исправил host-provided `typebox` на `peerDependencies:"*"`. Installed package.json не правится вручную, новый локальный patch не добавлен.
- Один MCP owner: сохранён `pi-mcp-adapter2.36.0`, в обоих templates — поддержанное Pi `extensions:["-builtin:mcp"]`. Settings merge сохраняет личные extension paths и добавляет это правило. MCP credentials/config не заменяются.
- Уже exact npm не переустанавливается Windows/POSIX installer: предотвращён наблюдавшийся ненужный `EEXIST npx`, без `--force` и удаления чужого shim.
- Project `.pi/` state исключён из Git: goal ledger/settings/receipts — персональные runtime данные, не public source. Safety scanner не ослаблен.

## Проверка и обновление

Проверены обоих synthetic profiles с **actual working Core1.0.2**: loading13/10, **0 errors / 0 package warnings / 0 fetch**; отдельно функциональный local-mock с Todo CRUD/get_goal/memoryFTS/subagent management, actual CLI/RPC get_goal + natural EOF exit0. Windows script regressions24/24 проверяют в том числе сохранение private extensions и перенос `-builtin:mcp` при sync. Verifier и patch checks — отдельная проверка, не замена startup diagnostics.

В рабочей Windows обновлены только эти exact3 packages (2 общих в Task), config синхронизирован через штатный `-SyncSettingsOnly`. Core1.0.2 и Goal X settings не заменены; auth/DB/sessions не трогались. Перезапустите существующие Pi-сессии, чтобы загрузить новые пакеты.

Для следующих обновлений: pins обновлять вместе в manifest/templates/component docs; предпочитать upstream metadata fix, не редактировать установленный package.json. После установки дополнительно проверить package warnings, а не только `verify`:

```powershell
# Только synthetic profiles в private HOME; не использовать рабочую память как fixture.
node tests/sdk/profile-loading.mjs "<SDK_ROOT>" "<SYNTHETIC_CODE_PROFILE>"
node tests/sdk/profile-loading.mjs "<SDK_ROOT>" "<SYNTHETIC_TASK_PROFILE>"
```

При выборе native MCP вместо adapter отдельно уберите adapter и `-builtin:mcp`: не загружать обоих владельцев `/mcp`. Project `+builtin:mcp` может переопределить user policy — проверяйте `/config`/startup resources проекта.

Ограничения build.1 сохраняются: provider calls, full subagent execution, semantic embeddings, browser UI, Linux/macOS/OS containment NT. WVM legacy SSE NT и HTTP NT — optional вне этого выпуска, adapter KEEP; parent gateway не protocol proof. Обновлённые пакеты проверены loading/local-mock, а не платными вызовами.
