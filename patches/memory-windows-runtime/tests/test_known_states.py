"""Exact known memory states and native-CLI replacement preflight.

Optional --previous-150 supplies public stock-index.js/canonical.js reconstructed
from published build 248b6cbfa4d6a4d8e7dc864b12241198e63712ab, not a user install.
"""
import argparse
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

HERE=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('memory_states',HERE/'apply.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
parser=argparse.ArgumentParser();parser.add_argument('--previous-150',type=Path)
args,rest=parser.parse_known_args()

class KnownStates(unittest.TestCase):
 def test_exact_transitions_and_backups(self):
  stock=m.BACKUP.read_bytes();current=m.build_canonical(stock);previous=m.build_canonical(stock,project_writes=False)
  self.assertEqual(m.digest(previous),m.PREVIOUS_161_SHA256)
  sources=[('1.6.1',stock,'stock-pristine'),('1.6.1',previous,'previous-patched-1.6.1'),('1.6.1',current,'runtime-safe')]
  if args.previous_150:
   for filename in ['stock-index.js','canonical.js']:
    body=(args.previous_150/filename).read_bytes();self.assertIn(m.digest(body),m.PREVIOUS_150_HASHES)
    sources.append(('1.5.0',body,m.PREVIOUS_150_HASHES[m.digest(body)]))
  for version,body,state in sources:
   with self.subTest(state=state),tempfile.TemporaryDirectory() as td:
    profile=Path(td);target=profile/'npm/node_modules/@samfp/pi-memory/dist/index.js';target.parent.mkdir(parents=True)
    metadata=target.parent.parent/'package.json';metadata.write_text(json.dumps({'version':version}));target.write_bytes(body)
    command=[sys.executable,'-B',str(HERE/'apply.py'),'--agent-dir',str(profile)]
    def call(flag=None,expected=0):
     p=subprocess.run(command+([flag]if flag else[]),capture_output=True,text=True)
     self.assertEqual(p.returncode,expected,p.stdout+p.stderr);return p
    self.assertIn(state,call('--inspect-installed').stdout)
    call('--prepare-replace');self.assertEqual(target.read_bytes(),body)
    backup=profile/'.pi-agent-build-backups/memory-windows-runtime';receipts=list(backup.glob('*.receipt.json'));self.assertEqual(len(receipts),1)
    receipt=json.loads(receipts[0].read_text());self.assertEqual(receipt['sha256'],m.digest(body));self.assertEqual(receipt['packageVersion'],version)
    # Emulate the exact target package replacement; preflight did not patch 1.5.
    if version=='1.5.0':
     call(expected=2);self.assertEqual(target.read_bytes(),body)
     metadata.write_text('{"version":"1.6.1"}');target.write_bytes(stock)
    call();self.assertEqual(target.read_bytes(),current)
    count=len(list(backup.glob('*.receipt.json')));call();self.assertEqual(len(list(backup.glob('*.receipt.json'))),count)
    call('--check');call('--restore');self.assertEqual(target.read_bytes(),stock)
    call('--check',expected=1)
    # A marker-preserving private edit is not a supported predecessor.
    drift=current+b'\n// synthetic unknown local change';target.write_bytes(drift)
    count=len(list(backup.glob('*.receipt.json')))
    for flag in ['--inspect-installed','--prepare-replace',None,'--restore']:
     call(flag,expected=2);self.assertEqual(target.read_bytes(),drift)
    self.assertEqual(len(list(backup.glob('*.receipt.json'))),count)
    metadata.write_text('{"version":"1.5.1"}');target.write_bytes(stock)
    call('--prepare-replace',expected=2)
  print('PASS exact memory states:',','.join(s[2] for s in sources))

if __name__=='__main__':unittest.main(argv=[sys.argv[0],*rest])
