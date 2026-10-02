import fs from 'node:fs';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

// No providers or SDK: the same harmless file fixture runs in both native PIDs.
const runtime = process.env.BOUNDARY_RUNTIME;
const canary = process.env.BOUNDARY_CANARY;
const role = process.argv[2] === 'descendant' ? 'descendant' : 'root';
const started = Date.now();
while (!fs.existsSync(path.join(runtime, `verified-${process.pid}`))) {
  if (Date.now() - started > 15000) throw new Error('Independent token/Job inspection gate timed out');
  await new Promise(resolve => setTimeout(resolve, 25));
}
const receipt = {
  role, pid: process.pid, ppid: process.ppid,
  execPath: process.execPath, modulePath: fileURLToPath(import.meta.url), cwd: process.cwd(),
  environment: Object.fromEntries(Object.entries(process.env).sort(([a], [b]) => a.localeCompare(b))),
  attempts: [], naturalExit: false,
};
function attempt(operation, target, data, expectedAllowed) {
  const record = { operation, target, expectedAllowed, allowed: false };
  try {
    if (operation === 'create-exclusive') fs.writeFileSync(target, data, { flag: 'wx' });
    else fs.writeFileSync(target, data);
    record.allowed = true;
  } catch (error) {
    record.error = { name: error.name, message: error.message, code: error.code, errno: error.errno, syscall: error.syscall, path: error.path, stack: error.stack };
  }
  receipt.attempts.push(record);
  // Only actual OS denial qualifies; nonexistent path or invalid argument is not proof.
  if (record.allowed !== expectedAllowed || (!expectedAllowed && !['EACCES', 'EPERM'].includes(record.error?.code))) {
    throw new Error(`Unexpected canary outcome: ${JSON.stringify(record)}`);
  }
}
try {
  attempt('create-exclusive', path.join(runtime, `${role}-allowed.txt`), `${role} harmless output\n`, true);
  attempt('create-exclusive', path.join(canary, `${role}-must-not-exist.txt`), 'dummy forbidden create\n', false);
  attempt('overwrite', path.join(canary, 'working-memory-shaped.txt'), 'dummy forbidden overwrite\n', false);
  // Also show that the medium-integrity harness control tree is not writable.
  attempt('create-exclusive', path.join(path.dirname(runtime), `${role}-control-must-not-exist.txt`), 'dummy forbidden control write\n', false);
  if (role === 'root') {
    const stdoutPath = path.join(runtime, 'descendant-stdout.txt');
    const stderrPath = path.join(runtime, 'descendant-stderr.txt');
    const fds = [];
    receipt.childStdio = { stdin: 'ignore', stdoutPath, stderrPath, openedFds: fds, closedFds: [] };
    try {
      const stdoutFd = fs.openSync(stdoutPath, 'wx');
      fds.push(stdoutFd);
      const stderrFd = fs.openSync(stderrPath, 'wx');
      fds.push(stderrFd);
      // Match the parent-supplied native SDK contract: ignore stdin, private file output,
      // windowsHide:true; no detached override. No stdout/stderr system NUL write request.
      const child = spawn(process.execPath, [fileURLToPath(import.meta.url), 'descendant'], {
        cwd: runtime, env: process.env, stdio: ['ignore', stdoutFd, stderrFd], windowsHide: true,
      });
      receipt.childPid = child.pid;
      const exit = await new Promise((resolve, reject) => {
        child.once('error', reject);
        child.once('exit', (code, signal) => resolve({ code, signal }));
      });
      receipt.childExit = exit;
      if (exit.code !== 0 || exit.signal !== null) throw new Error(`Unexpected descendant exit: ${JSON.stringify(exit)}`);
    } finally {
      const closeErrors = [];
      for (const fd of fds) {
        try { fs.closeSync(fd); receipt.childStdio.closedFds.push(fd); }
        catch (error) { closeErrors.push(error); }
      }
      if (closeErrors.length) throw new AggregateError(closeErrors, 'Private descendant stdio cleanup failed');
    }
  }
  receipt.naturalExit = true;
} catch (error) {
  receipt.failure = { message: error.message, stack: error.stack };
  process.exitCode = 1;
} finally {
  fs.writeFileSync(path.join(runtime, `${role}-receipt.json`), JSON.stringify(receipt, null, 2));
}
// Do not call process.exit: root and child must terminate via their natural event-loop drain.
