#!/usr/bin/env node
// Generates docs/components/composition.md — the living composition table of
// the build: every Pi package with version, source, per-profile enabled state
// and a short description. Sources of truth: manifests/runtime.lock.json,
// manifests/pi-packages.lock.json, profiles/*/settings.template.json.
// Usage: node scripts/gen-composition.mjs [--check] [repoRoot]
//   (default) writes docs/components/composition.md
//   --check   exits 2 if the checked-in file differs (drift gate, wired into verify)
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const args = process.argv.slice(2);
const check = args.includes('--check');
const repoRoot = args.find((a) => !a.startsWith('--')) ?? process.cwd();
const readJson = (rel) => JSON.parse(readFileSync(join(repoRoot, rel), 'utf8'));

// Short hand-curated descriptions. Unknown packages fall back to "—".
const DESCRIPTIONS = {
  'pi-ollama-cloud': 'Маршрут к моделям Ollama Cloud (провайдер)',
  'pi-trace-extension': 'Trace — трассировка сессий (политика сборки: установлен, выключен по умолчанию)',
  'pi-context-inspector': 'Диагностика контекстного окна',
  '@juicesharp/rpiv-todo': 'Список задач (todo)',
  'pi-polza': 'Запасной провайдер Polza AI',
  'pi-subagents': 'Сабы — делегирование и сценарии из нескольких агентов',
  'pi-goal-x': 'Goal X — автономная работа с целями',
  'pi-intercom': 'Связь между сессиями',
  'pi-background-tasks': 'Фоновые shell-задачи, делегирование, Fusion через дочерние Pi',
  'pi-session-search': 'Поиск по сессиям (история работы)',
  '@samfp/pi-memory': 'Долговременная память',
  'pi-mcp-adapter': 'Мост к MCP-серверам',
  '@nicknisi/pi-ast-grep': 'Поиск и правка кода по синтаксису (ast-grep)',
  '@bacnh85/pi-serena': 'Семантика кода через LSP (Serena)',
  'pi-cbm': 'Граф кода: символы, связи, трассировки (codebase memory)',
};

// "npm:@scope/name@1.2.3" | "https://github.com/owner/repo@ref" -> package name.
function nameFromSource(source) {
  if (source.startsWith('npm:')) {
    const spec = source.slice('npm:'.length);
    const at = spec.lastIndexOf('@');
    return at > 0 ? spec.slice(0, at) : spec;
  }
  const base = source.split('@')[0];
  return base.slice(base.lastIndexOf('/') + 1);
}

// A template entry disables a package when its object form carries an empty
// "extensions" list (the build's documented off switch, e.g. Trace).
function profileState(entry) {
  if (entry === undefined) return '—';
  const enabled = typeof entry === 'string' || !Array.isArray(entry.extensions) || entry.extensions.length > 0;
  return enabled ? '✅' : '⛔';
}

const runtime = readJson('manifests/runtime.lock.json');
const packagesLock = readJson('manifests/pi-packages.lock.json');
const codeTemplate = readJson('profiles/code/settings.template.json').packages ?? [];
const taskTemplate = readJson('profiles/task/settings.template.json').packages ?? [];
const byName = (template, name) => template.find((e) => nameFromSource(typeof e === 'string' ? e : e.source) === name);

const rows = [];
for (const group of ['common', 'codeOnly']) {
  for (const entry of packagesLock.profiles[group] ?? []) {
    const templateEntry = byName(codeTemplate, entry.package) ?? byName(taskTemplate, entry.package);
    const source = templateEntry ? (typeof templateEntry === 'string' ? templateEntry : templateEntry.source) : entry.source;
    const kind = source.startsWith('npm:') ? 'npm' : 'git';
    let description = DESCRIPTIONS[entry.package] ?? '—';
    if (entry.external) description += ` (внешняя зависимость: ${entry.external})`;
    rows.push(`| \`${entry.package}\` | ${entry.version} | ${kind} | ${profileState(byName(codeTemplate, entry.package))} | ${profileState(byName(taskTemplate, entry.package))} | ${description} |`);
  }
}

const piVersion = runtime.runtime.pi.version;
const out = `<!-- GENERATED FILE — do not edit by hand.
Sources: manifests/runtime.lock.json, manifests/pi-packages.lock.json, profiles/*/settings.template.json.
Regenerate: node scripts/gen-composition.mjs · freshness gate: node scripts/gen-composition.mjs --check (wired into verify). -->

# Состав сборки (генерируется)

Ядро **Pi ${piVersion}** само поставляет базовые инструменты и SDK-подмостки для расширений (\`@earendil-works/pi-ai\`, \`pi-agent-core\`, \`pi-coding-agent\`, \`pi-tui\`, \`typebox\`) — это не плагины. Всё в таблице ниже — **Pi-пакеты**: отдельные npm/git-пакеты с закреплёнными версиями. Источник истины — \`manifests/pi-packages.lock.json\`; эта таблица лишь читаемое представление.

Легенда: ✅ активен · ⛔ установлен, но выключен (\`"extensions": []\` — расширения не загружаются; включается правкой одной строки в шаблоне профиля) · — пакет не входит в профиль.

| Пакет | Версия | Источник | Code | Task | Что делает |
|---|---|---|---|---|---|
${rows.join('\n')}

Профили: **Code** = общие пакеты + code-intelligence тройка; **Task** = только общие. Полные спецификации (коммиты, теги) — в \`manifests/pi-packages.lock.json\`.
`;

const target = join(repoRoot, 'docs/components/composition.md');
if (check) {
  const current = existsSync(target) ? readFileSync(target, 'utf8') : null;
  if (current !== out) {
    console.error('FAIL docs/components/composition.md is stale — run: node scripts/gen-composition.mjs');
    process.exit(2);
  }
  console.log('OK docs/components/composition.md is fresh');
} else {
  writeFileSync(target, out, 'utf8');
  console.log(`WROTE docs/components/composition.md (${rows.length} packages, Pi ${piVersion})`);
}
