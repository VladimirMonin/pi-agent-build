# Offline core material: Source/cache ≠ runtime

Networking отключена в dummy capsule. Для следующего SDK этапа заранее нужен отдельный **frozen offline core bundle**, а не mapping рабочего npm cache/installation. Dummy capsule пока принимает только dummy inputs: не добавляйте Pi в неё до independent actual successful boundary raw review.

## Что замораживать

1. Exact coding-agent archive выбранной stable версии из официального npm registry: package name/version, HTTPS URL, registry SHA512 integrity и archive bytes. Никакого `latest`, рабочего `node_modules`, global prefix или personal npm cache.
2. Его **published `npm-shrinkwrap.json`**, прочитанный из regular bounded archive member без запуска/установки пакета. Не разрешайте ranges заново: берите exact `packages[*].version/resolved/integrity` из этого lock. Root archive добавляется отдельно; одинаковые URL+integrity дедуплицируются.
3. Если published entry не содержит SRI, получите **точную** официальную metadata `/<encoded-package>/<exact-version>`: name/version и `dist.tarball` должны совпасть с lock. Сохраните raw metadata и `dist.integrity` отдельно. Не вычисляйте hash неизвестных bytes как новое разрешение, не меняйте original published lock.
4. Каждый fetched archive должен совпасть с authoritative SHA512 и actual package manifest name/version. Top-level regular manifest не всегда `package/package.json`: типовой `@types/node` использует `node v…/package.json`. Reject ambiguous/nonregular/oversized manifests; не извлекайте payload и не запускайте lifecycle scripts на host.
5. Exact npm bootstrap archive версии из `manifests/runtime.lock.json` с официальными metadata/SHA512/name/version. Guest нуждается в собственном npm CLI, не в host PATH fallback.

Все outputs — новый owner-only subtree проверенного private stand. До package/cache операций — private env, home, temp, appdata, config и cwd и explicit approved binaries. Network обращается только к approved registry для source material; provider/auth calls не нужны.

## Стандартное наполнение private cache

После проверки/freeze архивов используйте **explicit Node + explicit npm CLI**, не bare `npm`, `npx` или Pi. Форма commands (paths передаются как отдельные argv, запуск только через bounded sanitized metadata runner):

```text
<APPROVED_NODE_EXE> <APPROVED_NPM_CLI_JS> cache add <ARCHIVE_1.tgz> … <ARCHIVE_N.tgz> --offline=true --ignore-scripts --no-audit --no-fund --loglevel=error
```

Небольшие batches ограничивают Windows command-line length и общий deadline. Обязательные config/env: новый private `cache`, пустые private `userconfig`/`globalconfig`, новый **пустой** metadata `prefix`, private HOME, USERPROFILE, APPDATA, LOCALAPPDATA, TEMP и TMP; `ignore-scripts=true`, `audit=false`, `fund=false`, `update-notifier=false`, `fetch-retries=0`. Не наследуйте `NODE_OPTIONS`, auth/proxy/provider/Pi variables.

Для entries без SRI в original lock также нужен HTTP cache key **их exact frozen URL**, иначе blob, добавленный по local file path, недостаточен для offline fetch этого entry:

```text
<APPROVED_NODE_EXE> <APPROVED_NPM_CLI_JS> cache add <EXACT_LOCKED_TARBALL_URL_1> … --offline=false --ignore-scripts --no-audit --no-fund --loglevel=error
```

Проверка material: cached blobs по **authoritative SRI** должны совпасть с archive lengths; missing-lock-SRI URL bindings — с exact registry SRI. Используется trusted npm cache library, не candidate SDK. Metadata prefix должен оставаться пустым. Сохраняются argv, exits, raw streams и partials. Ошибка не разрешает global cache repair, installation или повтор consumed VM attempt.

Для transfer нужен только новый synthetic material subtree: core archive, unchanged published lock, official supplemental metadata, verified cache payload и npm bootstrap archive. Data/cache/raw receipts не коммитятся. Не отображайте весь lab/home/source installation и не копируйте personal auth/configs/cache.

## Фактический статус текущего source этапа

Для frozen Pi **1.0.0** published lock содержит 146 dependency entries; вместе с root получено 146 уникальных архивов (138,984,286 bytes). Семь Earendil 1.0.0 entries без SRI дополнены отдельной exact official metadata. Private npm 11.11.0 cache-only 9 commands: 146 expected blobs/7 URL bindings подтверждены, metadata prefix пуст. Npm 11.11.0 bootstrap source archive: 2,835,959 bytes. Candidate code/SDK actors **0**.

Это **не** PASS offline guest installation, native/VM boundary, plugin compatibility, machine-B replay или выпуска. Portable host/guest provisioning entry point пока не принят; приведённая форма cache commands — не обход этого gate и не разрешение Pi runtime. После usable boundary/raw review остаются actual guest offline installation, exact SDK/env/PID/lifecycle, Both plugins/Trace/verifier/NO-OP и независимый Windows replay. Network не включается ради установки.
