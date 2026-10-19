import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

export async function runCli(sdkRoot, root) {
  fs.mkdirSync(root); const cwd = path.join(root, 'project'); fs.mkdirSync(cwd);
  const report = { status: 'STARTED', commands: [], checks: [], execPath: process.execPath, nodeVersion: process.version };
  const childEnv = {};
  for (const key of ('PATH PATHEXT SystemRoot WINDIR COMSPEC HOME USERPROFILE APPDATA LOCALAPPDATA TEMP TMP '
    + 'XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME PI_CODING_AGENT_DIR PI_CODING_AGENT_SESSION_DIR '
    + 'PI_SESSION_DIR PI_SESSION_ARCHIVE_DIR PI_AGENT_BUILD_NPM_PREFIX PI_MCP_CONFIG_MODE PI_INTERCOM_SCOPE_ID '
    + 'npm_config_cache npm_config_userconfig npm_config_globalconfig npm_config_prefix UV_CACHE_DIR UV_TOOL_DIR UV_TOOL_BIN_DIR').split(' ')) {
    if (process.env[key] !== undefined) childEnv[key] = process.env[key];
  }
  childEnv.PI_PACKAGE_DIR = sdkRoot;
  childEnv.PI_OFFLINE = '1';
  assert(childEnv.HOME && childEnv.USERPROFILE && childEnv.TEMP, 'Private child environment required');
  const base = [path.join(sdkRoot, 'dist/bundle/cli.js'), '--offline', '-p', '--no-extensions',
    '-e', fileURLToPath(new URL('./cli-provider.mjs', import.meta.url)), '--no-skills', '--no-prompt-templates', '--no-context-files', '--thinking', 'off'];
  const run = args => {
    const result = spawnSync(process.execPath, [...base, ...args], { cwd, env: childEnv, input: 'SYNTHETIC_STDIN\n', encoding: 'utf8', timeout: 20000 });
    report.commands.push({ args, argv: [...base, ...args], pid: result.pid, status: result.status,
      signal: result.signal, errorCode: result.error?.code, stdout: result.stdout, stderr: result.stderr });
    assert(!result.error, String(result.error)); assert.equal(result.signal, null);
    return result;
  };
  const terminalText = 'PARTIAL_PRINT_OUTPUT';
  const truncationWarning = 'Response was truncated: the model reached its output token limit.';
  const checkTerminal = result => {
    assert.equal(result.status, 1, result.stderr);
    assert.equal(result.stdout.trim(), terminalText, 'Print must contain only the current terminal partial');
    assert(result.stderr.includes(truncationWarning), 'Missing actual truncation warning');
    assert(!result.stdout.includes('activeTools'), 'Print replayed a stale assistant from resumed history');
    return { status: 'PASS', exitCode: result.status, stdout: result.stdout, stderr: result.stderr };
  };
  try {
    report.stage = 'bare-terminal';
    report.barePrint = checkTerminal(run(['--provider', 'cli-fixture', '--model', 'length', '--no-session', '--no-tools', 'Synthetic terminal partial print']));
    report.checks.push('BARE_PRINT_CURRENT_TERMINAL_PARTIAL_WARNING_EXIT1');
    report.stage = 'explicit-text-terminal';
    report.explicitTextPrint = checkTerminal(run(['--mode', 'text', '--provider', 'cli-fixture', '--model', 'length', '--no-session', '--no-tools', 'Synthetic terminal partial print']));
    report.checks.push('EXPLICIT_TEXT_CURRENT_TERMINAL_PARTIAL_WARNING_EXIT1');
    report.stage = 'json-terminal-discriminator';
    const jsonPartial = run(['--mode', 'json', '--provider', 'cli-fixture', '--model', 'length', '--no-session', '--no-tools', 'Synthetic terminal partial print']);
    assert.equal(jsonPartial.status, 0, jsonPartial.stderr); // JSON mode exit0 is its contract, not text-mode evidence.
    const events = jsonPartial.stdout.trim().split('\n').filter(Boolean).map(line => JSON.parse(line));
    const assistants = events.filter(event => event.type === 'message_end' && event.message?.role === 'assistant');
    assert.equal(assistants.length, 1, 'Unexpected recovery/retry assistant attempt');
    const message = assistants[0].message;
    assert.equal(message.stopReason, 'length');
    assert(message.content.every(item => item.type === 'text'));
    assert.equal(message.content.map(item => item.text).join(''), terminalText);
    assert.equal(message.usage.input, 1); assert.equal(message.usage.output, 128); assert.equal(message.usage.totalTokens, 129);
    const entries = events.filter(event => event.type === 'entry_appended').map(event => event.entry);
    // Normal messages are not emitted as entry_appended. This fresh one-answer
    // case rejects every context edit, hence also omission of the current answer.
    const omissions = entries.filter(entry => entry.type === 'context_edit');
    assert.deepEqual(omissions, [], 'Fresh terminal run context-edited a message');
    const ended = events.filter(event => event.type === 'agent_end');
    assert.equal(ended.length, 1); assert.equal(ended[0].willRetry, false);
    const retained = ended[0].messages.filter(item => item.role === 'assistant');
    assert.equal(retained.length, 1);
    assert.equal(retained[0].timestamp, message.timestamp);
    assert.equal(retained[0].stopReason, 'length');
    assert.equal(retained[0].content.map(item => item.text).join(''), terminalText);
    assert.equal(retained[0].usage.output, 128);
    const recovery = events.filter(event => /compact|retry|recovery/i.test(event.type) || /compact|retry|recovery/i.test(event.entry?.type ?? ''));
    assert.deepEqual(recovery, [], 'Recovery/compaction replaced the terminal-limit scenario');
    assert.equal(events.filter(event => event.type === 'agent_start').length, 1);
    const settled = events.filter(event => event.type === 'agent_settled');
    assert.equal(settled.length, 1); assert.equal(settled[0].aborted, false);
    report.jsonDiscriminator = { status: 'PASS', currentMessageTimestamp: message.timestamp, output: message.usage.output,
      totalTokens: message.usage.totalTokens, contextWindow: 65536, omissions, recovery };
    report.lengthEvents = events.filter(event => event.type === 'entry_appended' || event.type === 'agent_settled');
    report.checks.push('JSON_TERMINAL_OUTPUT128_TOTAL129_NO_CURRENT_OMISSION_OR_RECOVERY');
    const sessionDir = path.join(root, 'sessions');
    report.stage = 'normal-persisted-tools';
    const first = run(['--mode', 'text', '--provider', 'cli-fixture', '--model', 'normal', '--session-dir', sessionDir, '--session-id', 'synthetic-tools',
      '--tools', 'fixture_allowed', '--exclude-tools', 'fixture_forbidden', 'Synthetic first turn']);
    assert.equal(first.status, 0, first.stderr);
    assert.deepEqual(JSON.parse(first.stdout.trim()).activeTools, ['fixture_allowed']);
    report.checks.push('NORMAL_ACTIVE_TOOLS_ONLY_ALLOWED');
    report.stage = 'resumed-persisted-tools';
    const second = run(['--mode', 'text', '--provider', 'cli-fixture', '--model', 'normal', '--session-dir', sessionDir, '--session', 'synthetic-tools', 'Synthetic resumed turn']);
    assert.equal(second.status, 0, second.stderr);
    assert.deepEqual(JSON.parse(second.stdout.trim()).activeTools, ['fixture_allowed'], 'Resume revived an excluded tool');
    report.checks.push('RESUME_ACTIVE_TOOLS_DOES_NOT_REVIVE_EXCLUDED_TOOLS');
    report.stage = 'resumed-terminal';
    report.resumedTerminal = checkTerminal(run(['--mode', 'text', '--provider', 'cli-fixture', '--model', 'length',
      '--session-dir', sessionDir, '--session', 'synthetic-tools', 'Synthetic resumed terminal partial print']));
    report.checks.push('RESUMED_TERMINAL_CURRENT_PARTIAL_WARNING_EXIT1_NO_STALE_ACTIVE_TOOLS');
    report.stage = 'complete'; report.status = 'PASS';
  } catch (error) { report.status = 'FAIL'; report.error = String(error.stack || error); throw error; }
  finally { fs.writeFileSync(path.join(root, 'report.json'), JSON.stringify(report, null, 2), { flag: 'wx' }); }
  return report;
}
