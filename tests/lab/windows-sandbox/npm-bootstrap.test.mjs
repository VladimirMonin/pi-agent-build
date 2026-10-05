import test from 'node:test';
import assert from 'node:assert/strict';
import { parseBootstrapTar, inspectNpmBootstrap, materializeGuestNpm } from './npm-bootstrap.mjs';

function entry(name, content = 'x', type = '0') {
  const header = Buffer.alloc(512), data = Buffer.from(content);
  header.write(name, 0, 100, 'utf8');
  header.write(data.length.toString(8).padStart(11, '0') + '\0', 124, 12, 'ascii');
  header.fill(32, 148, 156); header[156] = type.charCodeAt(0);
  header.write('ustar\0', 257, 6, 'ascii');
  let sum = 0; for (const byte of header) sum += byte;
  header.write(sum.toString(8).padStart(6, '0') + '\0 ', 148, 8, 'ascii');
  return Buffer.concat([header, data, Buffer.alloc((512 - data.length % 512) % 512)]);
}
const tar = (...entries) => Buffer.concat([...entries, Buffer.alloc(1024)]);

test('regular files and inferred directories parse without writes', () => {
  const files = parseBootstrapTar(tar(entry('package/package.json', '{}'), entry('package/bin/npm-cli.js')));
  assert.deepEqual(files.map(file => file.name), ['package.json', 'bin/npm-cli.js']);
});
test('untrusted bootstrap bytes never gain authority from parsing', () => assert.throws(() => inspectNpmBootstrap(tar(entry('package/package.json', '{}'))), /integrity mismatch/));
test('host materialization refuses before input reads/writes', () => assert.throws(() => materializeGuestNpm('C:\\PiLabVM-' + '0'.repeat(32)), /Sandbox guest identity required/));
test('truncated tar refused', () => assert.throws(() => parseBootstrapTar(tar(entry('package/a')).subarray(0, 513)), /block-aligned/));
test('checksum drift refused', () => { const data = tar(entry('package/a')); data[1] ^= 1; assert.throws(() => parseBootstrapTar(data), /checksum/); });
for (const type of ['1', '2', '5', 'x', 'L']) test(`non-regular ${type} refused`, () => assert.throws(() => parseBootstrapTar(tar(entry('package/a', 'x', type))), /Only regular files/));
for (const name of ['package/../outside', '/package/a', 'package/a:stream', 'package/CON.txt', 'package/a.', 'package/a\\b']) test(`unsafe path ${name} refused`, () => assert.throws(() => parseBootstrapTar(tar(entry(name))), /Unsafe Windows|Single npm/));
test('case-folded duplicates refused', () => assert.throws(() => parseBootstrapTar(tar(entry('package/a'), entry('package/A'))), /Duplicate/));
test('file parent collision refused', () => assert.throws(() => parseBootstrapTar(tar(entry('package/a'), entry('package/a/b'))), /collision/));
test('inferred directory overwritten by file refused', () => assert.throws(() => parseBootstrapTar(tar(entry('package/a/b'), entry('package/a'))), /colliding/));
test('nonzero file padding refused', () => { const data = tar(entry('package/a')); data[513] = 1; assert.throws(() => parseBootstrapTar(data), /padding/); });
test('trailing bytes after zero terminator refused', () => { const data = tar(entry('package/a')); data[data.length - 1] = 1; assert.throws(() => parseBootstrapTar(data), /terminator/); });
