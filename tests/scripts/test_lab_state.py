"""Focused offline state/path/RPC tests; executable identities are unit doubles.

These do not claim real package patch/MCP functionality: the private verifier
must independently perform those checks with actual absolute executables.
"""
import errno
import importlib.util
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch

REPO = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('lab_state', REPO / 'scripts/lab-state.py')
state = importlib.util.module_from_spec(spec)
spec.loader.exec_module(state)

LAUNCHER = '''@ECHO off
GOTO start
:find_dp0
SET dp0=%~dp0
EXIT /b
:start
SETLOCAL
CALL :find_dp0

IF EXIST "%dp0%\\node.exe" (
  SET "_prog=%dp0%\\node.exe"
) ELSE (
  SET "_prog=node"
  SET PATHEXT=%PATHEXT:;.JS;=;%
)

endLocal & goto #_undefined_# 2>NUL || title %COMSPEC% & "%_prog%"  "%dp0%\\node_modules\\@earendil-works\\pi-coding-agent\\dist\\bundle\\cli.js" %*
'''.replace('\n', '\r\n').encode()


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value), encoding='utf-8')


class PrivateStateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.lab = Path(self.temp.name) / 'lab'
        self.lab.mkdir()
        self.runtime = state.read_json(REPO / 'manifests/runtime.lock.json')['runtime']
        self.manifest = state.read_json(REPO / 'manifests/pi-packages.lock.json')['profiles']
        write_json(self.lab / 'test-cwd/.pi/settings.json', {'pi-memory': {'localPath': '../memory'}})
        self.modules = self.lab / 'npm-prefix' / ('node_modules' if os.name == 'nt' else 'lib/node_modules')
        package = self.runtime['pi']['package']
        write_json(self.modules / package / 'package.json', {'name': package, 'version': self.runtime['pi']['version']})
        cli = self.modules / package / 'dist/bundle/cli.js'
        cli.parent.mkdir(parents=True)
        cli.write_text('synthetic entry point')
        self.launcher = self.lab / 'npm-prefix' / ('pi.cmd' if os.name == 'nt' else 'bin/pi')
        if os.name == 'nt':
            self.launcher.write_bytes(LAUNCHER)
        else:
            self.launcher.parent.mkdir()
            self.launcher.symlink_to(cli)
        for name, template in [('agent', 'code'), ('task', 'task')]:
            root = self.lab / 'pi-root' / name
            write_json(root / 'settings.json', state.read_json(REPO / 'profiles' / template / 'settings.template.json'))
            for destination, source in [('models.json', 'models.polza-memory.example.json'), ('ollama-cloud.json', 'ollama-cloud.example.json')]:
                write_json(root / destination, state.read_json(REPO / 'config' / source))
            write_json(root / 'mcp.json', {'mcpServers': {}, 'settings': {'scriptMode': False}})
            write_json(root / 'auth.json', {})
            shutil.copytree(REPO / 'skills/memory-ops', root / 'skills/memory-ops')
            for entry in self.manifest['common'] + (self.manifest['codeOnly'] if name == 'agent' else []):
                if entry['source'].startswith('npm:'):
                    path = root / 'npm/node_modules' / entry['package']
                else:
                    path = root / 'git/github.com' / entry['source'].split('github.com/')[1].split('@')[0]
                write_json(path / 'package.json', {'name': entry['package'], 'version': entry['version']})
        destinations = {'HOME': 'home', 'USERPROFILE': 'home', 'APPDATA': 'appdata', 'LOCALAPPDATA': 'localappdata',
                        'TEMP': 'temp', 'TMP': 'temp', 'XDG_CONFIG_HOME': 'xdg-config', 'XDG_CACHE_HOME': 'xdg-cache',
                        'XDG_DATA_HOME': 'xdg-data', 'XDG_STATE_HOME': 'xdg-state', 'UV_CACHE_DIR': 'uv-cache',
                        'UV_TOOL_DIR': 'uv-tools', 'UV_TOOL_BIN_DIR': 'uv-bin', 'CBM_CACHE_DIR': 'cbm-cache',
                        'PI_CBM_CACHE_DIR': 'cbm-cache', 'npm_config_prefix': 'npm-prefix', 'npm_config_cache': 'npm-cache'}
        self.environment = patch.dict(os.environ, {**{k: str(self.lab / v) for k, v in destinations.items()},
                                                   'PI_MCP_CONFIG_MODE': 'exclusive'}, clear=True)
        self.environment.start()
        self.addCleanup(self.environment.stop)
        self.addCleanup(self.temp.cleanup)
        self.commands = []

    def command_double(self, command, cwd, timeout=20):
        self.commands.append(command)
        if command[-1] == '--version':
            return self.runtime['pi']['version'] if command[0] == str(self.launcher) else self.runtime['node']
        if 'rev-parse' in command:
            entry = next(e for e in self.manifest['common'] if not e['source'].startswith('npm:'))
            return entry['tagObject'] if command[-1].startswith('refs/tags/') else entry['commit']
        return 'unit canonical patch double'

    def validate(self):
        with patch.object(state, 'checked', side_effect=self.command_double):
            return state.installed(self.lab, REPO, str(Path(sys.executable)), str(Path(sys.executable)))

    def test_valid_repeat_read_only_and_code_runtime_only(self):
        for profile in ('agent', 'task'):
            write_json(self.lab / 'pi-root' / profile / 'intercom/state.json', {'synthetic': True})
        before = {str(p): p.read_bytes() for p in self.lab.rglob('*') if p.is_file()}
        self.validate()
        self.validate()
        after = {str(p): p.read_bytes() for p in self.lab.rglob('*') if p.is_file()}
        self.assertEqual(before, after)
        code = [c for c in self.commands if 'session-search-profile' in ' '.join(c) and '--runtime-only' in c]
        self.assertEqual(len(code), 2)
        self.assertFalse(any('install' in c for c in self.commands))

    def test_mismatch_partial_unknown_and_auth_refused(self):
        root = self.lab / 'pi-root/task'
        for filename, value in [('settings.json', {}), ('auth.json', {'synthetic': {}})]:
            path = root / filename
            previous = path.read_bytes()
            write_json(path, value)
            with self.assertRaises(state.Refusal):
                self.validate()
            path.write_bytes(previous)
        intercom = root / 'intercom'
        intercom.write_text('not a runtime directory')
        with self.assertRaises(state.Refusal):
            self.validate()
        intercom.unlink()
        unknown = root / 'unknown.txt'
        unknown.write_text('synthetic')
        with self.assertRaises(state.Refusal):
            self.validate()
        unknown.unlink()
        path = root / 'npm/node_modules' / self.manifest['common'][0]['package'] / 'package.json'
        previous = path.read_bytes()
        write_json(path, {'name': 'wrong', 'version': '0.0.0'})
        with self.assertRaises(state.Refusal):
            self.validate()
        path.write_bytes(previous)
        path.unlink()
        with self.assertRaises(state.Refusal):
            self.validate()

    def test_extra_skill_file_and_directory_refused(self):
        for profile in ('agent', 'task'):
            skills = self.lab / 'pi-root' / profile / 'skills'
            for relative in ('extra/SKILL.md', 'memory-ops/extra.txt'):
                extra = skills / relative
                extra.parent.mkdir(parents=True, exist_ok=True)
                extra.write_text('synthetic extra skill')
                with self.assertRaises(state.Refusal):
                    self.validate()
                extra.unlink()
                if relative.startswith('extra/'):
                    extra.parent.rmdir()
            empty = skills / 'extra-empty'
            empty.mkdir()
            with self.assertRaises(state.Refusal):
                self.validate()
            empty.rmdir()
            self.validate()

    def test_unknown_launcher_refused(self):
        self.launcher.unlink()
        self.launcher.write_text('unknown launcher')
        with self.assertRaises(state.Refusal):
            self.validate()

    def test_links_internal_escape_broken_and_cycle(self):
        target = self.lab / 'cache-target'
        target.mkdir()
        pointer = self.lab / 'cache-link'
        if os.name == 'nt':
            # Junction creation requires no developer-mode/symlink privilege.
            import subprocess
            def make(destination):
                subprocess.run([os.environ.get('COMSPEC', r'C:\Windows\System32\cmd.exe'), '/d', '/c',
                                'mklink', '/J', str(pointer), str(destination)], check=True, capture_output=True)
            def remove():
                os.rmdir(pointer)
        else:
            def make(destination):
                pointer.symlink_to(destination, target_is_directory=True)
            def remove():
                pointer.unlink()
        make(target)
        try:
            state.validate_tree(self.lab)
        finally:
            remove()
        for destination in (Path(self.temp.name), self.lab / 'missing', self.lab):
            make(destination)
            try:
                with self.assertRaises(state.Refusal):
                    state.validate_tree(self.lab)
            finally:
                remove()

    def test_private_environment_escape_refused(self):
        os.environ['CBM_CACHE_DIR'] = self.temp.name
        with self.assertRaises(state.Refusal):
            self.validate()


class StdioTests(unittest.TestCase):
    def test_closed_stdin_live_server_is_reaped(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            script = root / 'closed-input-server.py'
            script.write_text("""import json,os,sys,time
request=json.loads(sys.stdin.readline())
os.close(0)
result={'protocolVersion':'2024-11-05','capabilities':{},'serverInfo':{'name':'closed-input-fixture','version':'1'}}
print(json.dumps({'jsonrpc':'2.0','id':request['id'],'result':result}),flush=True)
time.sleep(60)
""")
            processes = []
            original = state.subprocess.Popen

            def start(*args, **kwargs):
                process = original(*args, **kwargs)
                processes.append(process)
                return process

            with patch.object(state.subprocess, 'Popen', side_effect=start):
                with self.assertRaises(OSError) as failure:
                    state.stdio_probe([sys.executable, str(script)], root, 'closed-input-fixture')
            # Windows pipe flush reports EINVAL; POSIX reports EPIPE.
            self.assertIn(failure.exception.errno, (errno.EPIPE, errno.EINVAL))
            self.assertEqual(len(processes), 1)
            process = processes[0]
            self.assertIsNotNone(process.poll(), 'server must not survive failed stdin flush/close')
            self.assertTrue(all(stream.closed for stream in (process.stdin, process.stdout, process.stderr)))

    def test_real_local_rpc_success_error_and_closed_stdout(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            script = root / 'server.py'
            script.write_text("""import json,sys
for line in sys.stdin:
 request=json.loads(line)
 if request.get('id')==1:
  result={'protocolVersion':'2024-11-05','capabilities':{},'serverInfo':{'name':'local-fixture','version':'1'}}
 elif request.get('id')==2:
  result={'tools':[{'name':'fixture','inputSchema':{'type':'object'}}]}
 else: continue
 print(json.dumps({'jsonrpc':'2.0','id':request['id'],'result':result}),flush=True)
""")
            state.stdio_probe([sys.executable, str(script)], root, 'fixture')
            script.write_text("print('invalid protocol', flush=True)")
            with self.assertRaises(state.Refusal):
                state.stdio_probe([sys.executable, str(script)], root, 'fixture')
            script.write_text("print('[]', flush=True)")
            with self.assertRaises(state.Refusal):
                state.stdio_probe([sys.executable, str(script)], root, 'fixture')
            script.write_text("import json,sys\njson.loads(sys.stdin.readline())\nprint(json.dumps({'jsonrpc':'2.0','id':1,'error':{'code':-1}}),flush=True)")
            with self.assertRaises(state.Refusal):
                state.stdio_probe([sys.executable, str(script)], root, 'fixture')


if __name__ == '__main__':
    unittest.main()
