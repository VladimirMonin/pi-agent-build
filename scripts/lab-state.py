"""Private installed-state gate. No repair, downloads or package/config writes.

Run only with the common scripts' sanitized private environment. MCP probes may
create ordinary private cache/log state; no tools/call or network transport.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import queue
import re
import subprocess
import sys
import threading
import time


class Refusal(RuntimeError):
    pass


def require(condition, message):
    if not condition:
        raise Refusal(message)


def inside(path, root):
    return path == root or root in path.parents


def link(path):
    return path.is_symlink() or (hasattr(path, 'is_junction') and path.is_junction())


def validate_tree(root):
    """Resolve every link, including directory graphs, without escaping LAB."""
    visited = set()

    def visit(path, active):
        try:
            target = path.resolve(strict=True) if link(path) else path
        except (OSError, RuntimeError):
            raise Refusal('broken/cyclic private link') from None
        require(target.exists(), 'broken private link')
        require(inside(target, root), 'private link escapes LAB')
        if not target.is_dir():
            return
        require(target not in active, 'cyclic private directory link')
        if target in visited:
            return
        for child in target.iterdir():
            visit(child, active | {target})
        visited.add(target)

    visit(root, set())


def read_json(path):
    try:
        return json.loads(path.read_text(encoding='utf-8-sig'))
    except (OSError, ValueError):
        raise Refusal('required private JSON missing or invalid') from None


def validate_paths(lab, repo):
    require(lab.is_absolute() and repo.is_absolute() and '..' not in lab.parts,
            'absolute private root required')
    for path in (lab, repo):
        for ancestor in (path, *path.parents):
            require(not link(ancestor), 'root/repository reparse ancestor refused')
    lab, repo = lab.resolve(strict=True), repo.resolve(strict=True)
    require(lab.is_dir() and repo.is_dir() and not inside(lab, repo) and not inside(repo, lab),
            'private root/repository overlap')
    for home in (os.environ.get('PI_LAB_LIVE_HOME'), os.environ.get('PI_LAB_LIVE_USERPROFILE')):
        if home:
            require(not inside(lab, Path(home).resolve()), 'private root overlaps live home')
    for ancestor in (lab, *lab.parents):
        require(not (ancestor / '.git').exists(), 'private root inside Git checkout')
    validate_tree(lab)
    for relative in ('pi-root', 'npm-prefix', 'test-cwd'):
        path = lab / relative
        require(path.is_dir() and not link(path), 'fixed private destination missing or linked')
    require({p.name for p in (lab / 'pi-root').iterdir()} == {'agent', 'task'},
            'unknown private profile')
    cwd = lab / 'test-cwd'
    require({p.name for p in cwd.iterdir()} == {'.pi'} and
            {p.name for p in (cwd / '.pi').iterdir()} == {'settings.json'},
            'synthetic cwd contains unknown content')
    require(read_json(cwd / '.pi/settings.json') == {'pi-memory': {'localPath': '../memory'}},
            'synthetic project settings mismatch')
    for name in ('user.npmrc', 'global.npmrc'):
        p = lab / 'npm-config' / name
        if p.exists():
            require(all(not line.strip() or line.lstrip().startswith(('#', ';'))
                        for line in p.read_text().splitlines()), 'private npm config contains directives')
    return lab, repo


def checked(command, cwd, timeout=20):
    require(Path(command[0]).is_absolute() and Path(command[0]).is_file(),
            'absolute executable required; no global fallback')
    try:
        result = subprocess.run(command, cwd=cwd, stdin=subprocess.DEVNULL,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                timeout=timeout, text=True, encoding='utf-8', errors='replace')
    except (OSError, subprocess.TimeoutExpired):
        raise Refusal('private command failed to start or timed out') from None
    require(result.returncode == 0, 'private command returned failure')
    return result.stdout + result.stderr


def metadata(path, name, version):
    data = read_json(path)
    require(data.get('name') == name and data.get('version') == version,
            'installed package identity/version mismatch: ' + name)


def installed(lab, repo, node, git):
    lab, repo = validate_paths(lab, repo)
    destinations = {'HOME': 'home', 'USERPROFILE': 'home', 'APPDATA': 'appdata',
                    'LOCALAPPDATA': 'localappdata', 'TEMP': 'temp', 'TMP': 'temp',
                    'XDG_CONFIG_HOME': 'xdg-config', 'XDG_CACHE_HOME': 'xdg-cache',
                    'XDG_DATA_HOME': 'xdg-data', 'XDG_STATE_HOME': 'xdg-state',
                    'UV_CACHE_DIR': 'uv-cache', 'UV_TOOL_DIR': 'uv-tools', 'UV_TOOL_BIN_DIR': 'uv-bin',
                    'CBM_CACHE_DIR': 'cbm-cache', 'PI_CBM_CACHE_DIR': 'cbm-cache',
                    'npm_config_prefix': 'npm-prefix', 'npm_config_cache': 'npm-cache'}
    for key, relative in destinations.items():
        require(os.environ.get(key) and Path(os.environ[key]).absolute() == lab / relative,
                'private environment destination mismatch: ' + key)
    require(os.environ.get('PI_MCP_CONFIG_MODE') == 'exclusive', 'private exclusive MCP guard required')
    runtime = read_json(repo / 'manifests/runtime.lock.json')['runtime']
    manifest = read_json(repo / 'manifests/pi-packages.lock.json')['profiles']
    prefix = lab / 'npm-prefix'
    modules = prefix / ('node_modules' if os.name == 'nt' else 'lib/node_modules')
    package = runtime['pi']['package']
    metadata(modules / package / 'package.json', package, runtime['pi']['version'])
    cli = modules / package / 'dist/bundle/cli.js'
    require(cli.is_file(), 'private Pi entry point missing')
    launcher = prefix / ('pi.cmd' if os.name == 'nt' else 'bin/pi')
    if os.name == 'nt':
        require(launcher.is_file() and not link(launcher) and
                hashlib.sha256(launcher.read_bytes()).hexdigest() ==
                '35ec1b2b20461eadbbaaf10e209e0ffe9a0f8cc2f948ae4670023ea85caff296',
                'private Pi npm launcher is not canonical')
        version = checked([str(launcher), '--version'], lab / 'test-cwd')
    else:
        require(link(launcher) and launcher.resolve(strict=True) == cli.resolve(strict=True),
                'private Pi npm launcher is not canonical')
        version = checked([str(launcher), '--version'], lab / 'test-cwd')
    require(version.strip() == runtime['pi']['version'], 'private Pi launcher version mismatch')
    node_version = checked([node, '--version'], lab / 'test-cwd').strip().lstrip('v')
    require(node_version == runtime['node'], 'Node runtime version mismatch')
    for name, template, expected_count in (('agent', 'code', 15), ('task', 'task', 12)):
        root = lab / 'pi-root' / name
        allowed = {'settings.json', 'models.json', 'models-store.json', 'ollama-cloud.json', 'mcp.json',
                   'auth.json', 'skills', 'npm', 'git', '.pi-agent-build-backups', 'traces', 'session-search', 'intercom'}
        require(not {p.name for p in root.iterdir()} - allowed, name + ' unknown profile content')
        if (root / 'intercom').exists():
            require((root / 'intercom').is_dir(), name + ' intercom runtime path is not a directory')
        require(read_json(root / 'settings.json') == read_json(repo / 'profiles' / template / 'settings.template.json'),
                name + ' settings mismatch')
        for filename, source in (('models.json', 'models.polza-memory.example.json'),
                                 ('ollama-cloud.json', 'ollama-cloud.example.json')):
            require(read_json(root / filename) == read_json(repo / 'config' / source), name + ' config mismatch')
        require(read_json(root / 'mcp.json') == {'mcpServers': {}, 'settings': {'scriptMode': False}},
                name + ' MCP config must be empty/exclusive')
        # Runtime may create an empty auth store. Never accept credentials here.
        if (root / 'auth.json').exists():
            require(read_json(root / 'auth.json') == {}, name + ' auth store is not empty')
        source_skills = repo / 'skills'
        installed_skills = root / 'skills'
        require(installed_skills.is_dir(), name + ' skills directory missing')
        expected_skills = {p.relative_to(source_skills): p for p in source_skills.rglob('*')}
        actual_skills = {p.relative_to(installed_skills): p for p in installed_skills.rglob('*')}
        require(actual_skills.keys() == expected_skills.keys(), name + ' skills path set mismatch')
        for relative, source in expected_skills.items():
            target = actual_skills[relative]
            require(target.is_dir() if source.is_dir() else
                    target.is_file() and target.read_bytes() == source.read_bytes(), name + ' skill mismatch')
        entries = manifest['common'] + (manifest['codeOnly'] if name == 'agent' else [])
        require(len(entries) == expected_count, 'unexpected pinned package count')
        patches = []
        for entry in entries:
            if entry['source'].startswith('npm:'):
                metadata(root / 'npm/node_modules' / entry['package'] / 'package.json',
                         entry['package'], entry['version'])
            else:
                match = re.fullmatch(r'https://github\.com/([^/]+)/([^@]+)@([0-9a-f]{40})', entry['source'])
                require(match is not None, 'unknown package source')
                repository = match[2][:-4] if match[2].endswith('.git') else match[2]
                checkout = root / 'git/github.com' / match[1] / repository
                metadata(checkout / 'package.json', entry['package'], entry['version'])
                for revision, expected in (('HEAD', entry['commit']),
                                           ('refs/tags/' + entry['releaseTag'], entry['tagObject']),
                                           (entry['tagObject'] + '^{commit}', entry['commit'])):
                    require(checked([git, '-C', str(checkout), 'rev-parse', revision],
                                    lab / 'test-cwd').strip() == expected, 'pinned Git identity mismatch')
            if entry.get('patch'):
                patches.append(entry['patch'])
            if entry.get('taskProfilePatch') and (name == 'task' or entry['taskProfilePatch'] == 'session-search-profile'):
                patches.append(entry['taskProfilePatch'])
        for patch in dict.fromkeys(patches):
            args = [sys.executable, str(repo / 'patches' / patch / 'apply.py'), '--check', '--agent-dir', str(root)]
            if patch == 'session-search-profile' and name == 'agent':
                args.append('--runtime-only')
            checked(args, lab / 'test-cwd')
        print('PASS ' + name + ' exact settings, ' + str(expected_count) + ' identities and canonical patches')
    return lab, repo


def stdio_probe(command, cwd, label):
    """Only initialize/initialized/tools/list. Bounded, drained pipes, always reap."""
    require(Path(command[0]).is_absolute() and Path(command[0]).is_file(), 'private MCP executable missing')
    process = subprocess.Popen(command, cwd=cwd, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE, text=True, encoding='utf-8', errors='replace')
    messages = queue.Queue()

    def drain(stream, collect):
        for line in stream:
            if collect:
                try:
                    messages.put(json.loads(line))
                except ValueError:
                    messages.put({'invalid': True})
        if collect:
            messages.put({'eof': True})

    threads = [threading.Thread(target=drain, args=(process.stdout, True), daemon=True),
               threading.Thread(target=drain, args=(process.stderr, False), daemon=True)]
    for thread in threads:
        thread.start()

    def send(value):
        process.stdin.write(json.dumps(value) + '\n')
        process.stdin.flush()

    def receive(identifier):
        deadline = time.monotonic() + 45
        while True:
            remaining = deadline - time.monotonic()
            require(remaining > 0, label + ' MCP response timeout')
            try:
                value = messages.get(timeout=remaining)
            except queue.Empty:
                raise Refusal(label + ' MCP response timeout') from None
            require(isinstance(value, dict), label + ' invalid MCP message')
            require(not value.get('eof') and not value.get('invalid'), label + ' invalid/closed MCP stdout')
            if value.get('id') == identifier:
                require('error' not in value and isinstance(value.get('result'), dict), label + ' MCP RPC failure')
                return value['result']

    try:
        send({'jsonrpc': '2.0', 'id': 1, 'method': 'initialize', 'params': {
            'protocolVersion': '2024-11-05', 'capabilities': {},
            'clientInfo': {'name': 'pi-private-lifecycle-probe', 'version': '1'}}})
        result = receive(1)
        require(isinstance(result.get('serverInfo'), dict) and result.get('protocolVersion') and
                isinstance(result.get('capabilities'), dict), label + ' initialize identity missing')
        send({'jsonrpc': '2.0', 'method': 'notifications/initialized'})
        send({'jsonrpc': '2.0', 'id': 2, 'method': 'tools/list', 'params': {}})
        tools = receive(2).get('tools')
        require(isinstance(tools, list) and tools and all(isinstance(t, dict) and t.get('name') and
                isinstance(t.get('inputSchema'), dict) for t in tools), label + ' tools/list invalid or empty')
        print('PASS ' + label + ' private stdio initialize + tools/list (' + str(len(tools)) + ' tools)')
    finally:
        try:
            try:
                process.stdin.close()
            except (OSError, ValueError):
                # A failed flush may leave buffered bytes after the peer closed stdin.
                pass
        finally:
            try:
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.terminate()
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait(timeout=5)
            finally:
                for thread in threads:
                    thread.join(timeout=2)
                for stream in (process.stdout, process.stderr):
                    try:
                        stream.close()
                    except (OSError, ValueError):
                        pass


def external(lab, repo, mcp):
    prefix = lab / 'npm-prefix'
    modules = prefix / ('node_modules' if os.name == 'nt' else 'lib/node_modules')
    tools = read_json(repo / 'manifests/external-tools.lock.json')['codeProfile']
    paths = {}
    for tool in tools:
        package, version = tool['package'], tool['version']
        if package == 'serena-agent':
            site = lab / 'uv-tools/serena-agent' / ('Lib/site-packages' if os.name == 'nt' else 'lib')
            candidates = list(site.rglob('serena_agent-*.dist-info/METADATA'))
            require(len(candidates) == 1, 'private Serena metadata missing/ambiguous')
            text = candidates[0].read_text(encoding='utf-8')
            require('\nName: serena-agent\n' in '\n' + text and '\nVersion: ' + version + '\n' in '\n' + text,
                    'private Serena metadata identity mismatch')
            path = lab / 'uv-bin' / ('serena.exe' if os.name == 'nt' else 'serena')
        else:
            metadata(modules / package / 'package.json', package, version)
            if package == '@ast-grep/cli':
                path = prefix / ('ast-grep.exe' if os.name == 'nt' else 'bin/ast-grep')
                if os.name == 'nt':
                    require(path.read_bytes() == (modules / package / 'ast-grep.exe').read_bytes(),
                            'private ast-grep staged executable mismatch')
            else:
                path = modules / package / 'bin' / ('codebase-memory-mcp.exe' if os.name == 'nt' else 'codebase-memory-mcp')
        require(inside(path.resolve(strict=True), lab), 'private external executable escapes LAB')
        output = checked([str(path), '--version'], lab / 'test-cwd')
        versions = re.findall(r'(?<![\d.])\d+\.\d+\.\d+(?![\d.])', output)
        require(versions == [version], 'private external version mismatch: ' + package)
        paths[package] = str(path)
        print('PASS private ' + package + ' identity/version ' + version)
    if mcp:
        project = lab / 'temp/mcp-probe-project'
        project.mkdir(parents=True, exist_ok=True)
        failures = []
        probes = [('CBM', [paths['codebase-memory-mcp'], '--ui=false']),
                  ('Serena', [paths['serena-agent'], 'start-mcp-server', '--transport', 'stdio',
                              '--enable-web-dashboard', 'false', '--enable-gui-log-window', 'false',
                              '--open-web-dashboard', 'false'])]
        for label, command in probes:
            try:
                stdio_probe(command, project, label)
            except (Refusal, OSError, BrokenPipeError):
                print('FAIL ' + label + ' private stdio probe')
                failures.append(label)
        require(not failures, 'mandatory private MCP failure: ' + ', '.join(failures))
    print('NOT TESTED: tools/call, optional MCP, LSP/indexing, provider transport, WVM and native Linux/macOS')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--lab-root', type=Path, required=True)
    parser.add_argument('--repo-root', type=Path, required=True)
    parser.add_argument('--node', required=True)
    parser.add_argument('--git', required=True)
    parser.add_argument('--mcp', action='store_true')
    args = parser.parse_args()
    try:
        require(os.environ.get('PYTHONDONTWRITEBYTECODE') == '1', 'private bytecode guard required')
        require(os.name != 'nt' or sys.version_info >= (3, 12), 'Windows junction checks require Python >=3.12')
        lab, repo = installed(args.lab_root, args.repo_root, args.node, args.git)
        external(lab, repo, args.mcp)
        print('VERIFIED INSTALLED-STATE: PASS')
        return 0
    except (Refusal, OSError, RuntimeError, ValueError) as error:
        # Never emit config/auth values, child stdout/stderr or tracebacks.
        print('VERIFIED INSTALLED-STATE: REFUSED: ' + (str(error) if isinstance(error, Refusal) else type(error).__name__))
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
