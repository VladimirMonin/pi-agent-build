// Focused write-guard test over the actual generated bundle bodies; no user DB.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const source=readFileSync(process.argv[2],'utf8');
function body(start,end){const a=source.indexOf(start),b=source.indexOf(end,a);assert(a>=0&&b>a,`Missing production guard ${start}`);return source.slice(a,b);}
const helpers=body('// pi-memory scoped injection v3','function projectSlug(cwd) {');
const guard=new Function(helpers+'; return projectFactScopeError;')();
for(const prefix of ['pref.','user.','tool.']) assert.equal(guard(prefix+'sample','/work/foo-bar',{}),null);
assert.equal(guard('project.foo-bar.sample','/work/foo-bar',{}),null);
for(const key of ['project.foo_bar.sample','project.foreign.sample','project.foo-bar','project.foo-bar.']) assert.match(guard(key,'/work/foo-bar',{}),/expected project\.foo-bar\./);
assert.equal(guard('project.alias-name.sample','/work/branch',{factProjectAliases:[{path:'/work/branch',scope:'alias-name'}]}),null);
assert(source.includes('projectFactScopeError(rememberParams.key, ctx.cwd, injectorConfig)'));
assert(source.includes('projectFactScopeError(s.key, cwd, config)'));
assert(source.includes('factScope: projectFactScope(sessionCwd, injectorConfig)'));
assert(source.includes('Allowed project fact prefix: project.${input.factScope}.'));
console.log('PASS exact project write/read/consolidation scope contract');
