// Trusted npm bootstrap SOURCE materialization; never install/import candidate Pi here.
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { createHash } from 'node:crypto';
import { gunzipSync } from 'node:zlib';

export const npmVersion = '11.11.0';
const npmIntegrity = 'sha512-82gRxKrh/eY5UnNorkTFcdBQAGpgjWehkfGVqAGlJjejEtJZGGJUqjo3mbBTNbc5BTnPKGVtGPBZGhElujX5cw==';
const decoder = new TextDecoder('utf-8', { fatal: true });
const zero = buffer => buffer.every(byte => byte === 0);
function text(field) {
  const end = field.indexOf(0);
  if (end >= 0 && !zero(field.subarray(end))) throw Error('Nonzero tar string padding');
  return decoder.decode(end < 0 ? field : field.subarray(0, end));
}
function octal(field) {
  if (field.some(byte => byte > 127)) throw Error('Unsupported tar numeric field');
  const match = /^[ \x00]*([0-7]+)[ \x00]*$/.exec(field.toString('ascii'));
  if (!match) throw Error('Unsupported tar numeric field');
  const number = Number.parseInt(match[1], 8);
  if (!Number.isSafeInteger(number)) throw Error('Unbounded tar number');
  return number;
}
function memberPath(name) {
  if (!name.startsWith('package/')) throw Error('Single npm package root required');
  const rel = name.slice(8);
  const parts = rel.split('/');
  if (!rel || parts.some(part => !part || part === '.' || part === '..' || /[\x00-\x1f\x7f\\:*?"<>|]/.test(part) || /[. ]$/.test(part) || /^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)/i.test(part))) throw Error('Unsafe Windows tar path');
  return parts.join('/');
}

/** Pure bounded tar parser. Parsing alone grants no package or write authority. */
export function parseBootstrapTar(tar) {
  if (!Buffer.isBuffer(tar) || tar.length > 128 * 1024 * 1024 || tar.length % 512 !== 0) throw Error('Bounded block-aligned tar required');
  const files = new Map(), dirs = new Set();
  let cursor = 0, terminated = false, bytes = 0;
  while (cursor + 512 <= tar.length) {
    const header = tar.subarray(cursor, cursor + 512);
    if (zero(header)) {
      if (cursor + 1024 > tar.length || !zero(tar.subarray(cursor))) throw Error('Exact zero tar terminator required');
      terminated = true; break;
    }
    if (files.size >= 20000 || text(header.subarray(257, 263)) !== 'ustar') throw Error('Unsupported tar header/count');
    const expectedChecksum = octal(header.subarray(148, 156));
    let checksum = 0;
    for (let i = 0; i < 512; i++) checksum += i >= 148 && i < 156 ? 32 : header[i];
    if (checksum !== expectedChecksum) throw Error('Tar checksum mismatch');
    if (header[156] !== 48 && header[156] !== 0) throw Error('Only regular files allowed; links/special/PAX headers refused');
    const prefix = text(header.subarray(345, 500));
    const name = memberPath((prefix ? prefix + '/' : '') + text(header.subarray(0, 100)));
    const key = name.normalize('NFC').toLowerCase();
    const size = octal(header.subarray(124, 136));
    const body = cursor + 512, end = body + size;
    const next = body + Math.ceil(size / 512) * 512;
    if (size > 64 * 1024 * 1024 || next > tar.length || !zero(tar.subarray(end, next))) throw Error('Invalid tar file bound/padding');
    if (files.has(key) || dirs.has(key)) throw Error('Duplicate/colliding tar file');
    const components = key.split('/');
    for (let i = 1; i < components.length; i++) {
      const dir = components.slice(0, i).join('/');
      if (files.has(dir)) throw Error('Tar file/directory collision');
      dirs.add(dir);
    }
    bytes += size;
    if (bytes > 128 * 1024 * 1024) throw Error('Archive file bytes exceeded');
    files.set(key, { name, data: tar.subarray(body, end) });
    cursor = next;
  }
  if (!terminated || files.size === 0) throw Error('Missing tar terminator/files');
  return [...files.values()];
}

/** Verify the frozen official npm archive; no filesystem writes or payload execution. */
export function inspectNpmBootstrap(archive) {
  if (!Buffer.isBuffer(archive) || archive.length > 32 * 1024 * 1024) throw Error('Bounded npm archive required');
  if ('sha512-' + createHash('sha512').update(archive).digest('base64') !== npmIntegrity) throw Error('Exact official npm bootstrap integrity mismatch');
  const files = parseBootstrapTar(gunzipSync(archive, { maxOutputLength: 128 * 1024 * 1024 }));
  const manifest = files.find(file => file.name === 'package.json');
  if (!manifest || manifest.data.length > 1048576) throw Error('Bounded npm manifest required');
  const pkg = JSON.parse(decoder.decode(manifest.data));
  if (pkg.name !== 'npm' || pkg.version !== npmVersion) throw Error('Exact npm package identity mismatch');
  if (!files.some(file => file.name === 'bin/npm-cli.js')) throw Error('Official npm CLI entry absent');
  return files;
}

/** Caller must first pass the independently accepted actual VM boundary/owned-root gate. */
export function materializeGuestNpm(guestRoot) {
  if (process.platform !== 'win32' || os.userInfo().username !== 'WDAGUtilityAccount') throw Error('Sandbox guest identity required');
  if (!/^C:\\PiLabVM-[a-f0-9]{32}$/i.test(guestRoot) || path.resolve(fs.realpathSync.native(guestRoot)).toLowerCase() !== path.resolve(guestRoot).toLowerCase()) throw Error('Canonical owned guest root required');
  const executable = path.resolve(process.execPath).toLowerCase();
  if (!executable.startsWith(path.resolve(guestRoot).toLowerCase() + path.sep) || path.resolve(fs.realpathSync.native(process.execPath)).toLowerCase() !== executable) throw Error('Copied canonical guest Node required');
  const archivePath = 'C:\\PiLabCoreInput\\npm-11.11.0.tgz';
  const stat = fs.lstatSync(archivePath);
  if (!stat.isFile() || stat.isSymbolicLink() || stat.size > 32 * 1024 * 1024 || path.resolve(fs.realpathSync.native(archivePath)).toLowerCase() !== archivePath.toLowerCase()) throw Error('Regular fixed mapped npm input required');
  const files = inspectNpmBootstrap(fs.readFileSync(archivePath)); // ALL validation before first write
  const destination = path.join(guestRoot, 'npm-bootstrap');
  fs.mkdirSync(destination); // exclusive/fresh; preserve a failed partial, never repair
  for (const file of files) {
    const target = path.join(destination, ...file.name.split('/'));
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.writeFileSync(target, file.data, { flag: 'wx' });
  }
  return { scope: 'TRUSTED_NPM_SOURCE_MATERIALIZED_NOT_Pi_INSTALL_OR_RUNTIME_ACCEPTANCE',
    version: npmVersion, files: files.length, destination, npmCli: path.join(destination, 'bin', 'npm-cli.js'), candidateSdkActors: 0 };
}
