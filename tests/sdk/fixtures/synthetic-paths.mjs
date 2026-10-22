// Bounded path admission for new synthetic SDK cases, before SDK/package imports.
// The runtime root itself must already have passed the installer's placement gate.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
export function assertSyntheticPaths(sdkRoot, freshRoot, ...packages) {
 const repo=fileURLToPath(new URL('../../../',import.meta.url));
 const sdk=path.resolve(sdkRoot),prefix=path.resolve(sdk,'../../..');
 assert.equal(path.basename(prefix),'npm-prefix','Use the explicit synthetic npm prefix');
 const runtime=fs.realpathSync(path.dirname(prefix));
 const contained=(base,p)=>{const r=path.relative(base,p);return r!==''&&r!=='..'&&!r.startsWith('..'+path.sep)&&!path.isAbsolute(r);};
 const canonical=p=>{
  let existing=path.resolve(p),suffix=[];
  while(!fs.existsSync(existing)){suffix.unshift(path.basename(existing));const parent=path.dirname(existing);assert.notEqual(parent,existing);existing=parent;}
  return path.join(fs.realpathSync(existing),...suffix);
 };
 for(const p of [sdk,freshRoot,...packages,process.env.HOME,process.env.USERPROFILE]){
  assert(p&&path.isAbsolute(p),'Absolute owned paths and private HOME are required');
  const real=canonical(p);
  assert(contained(runtime,real),'Synthetic inputs/output/HOME must remain in the admitted runtime root');
  assert(!contained(repo,real)&&real!==path.resolve(repo),'No runtime state in Git');
  assert(!real.split(path.sep).some(part=>part.toLowerCase()==='.pi'),'Working profiles are not fixtures');
 }
 assert(!fs.existsSync(freshRoot),'A fresh case directory is required');
 return runtime;
}
