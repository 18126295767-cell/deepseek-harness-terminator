import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { auditProfile, formatReport } from '../scripts/profile-doctor.mjs';

function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'dsh-profile-doctor-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const runtimeDir = path.join(root, 'runtime');
  const profileDir = path.join(root, 'profile');
  fs.mkdirSync(profileDir, { recursive: true });
  writePackage(runtimeDir, '@deepseek-ai/dsh', '0.1.0-rc.6');
  return { runtimeDir, profileDir };
}

function writePackage(root, name, version, fields = {}) {
  const directory = path.join(root, 'node_modules', ...name.split('/'));
  fs.mkdirSync(directory, { recursive: true });
  fs.writeFileSync(path.join(directory, 'package.json'), `${JSON.stringify({ name, version, ...fields }, null, 2)}\n`);
  return directory;
}

test('rejects a profile core package from a different host version', t => {
  const { runtimeDir, profileDir } = fixture(t);
  writePackage(runtimeDir, '@deepseek-ai/dsh-tools', '0.1.0-rc.6');
  writePackage(profileDir, '@deepseek-ai/dsh-tools', '0.1.0-rc.7');
  writePackage(profileDir, 'broken-plugin', '1.0.0', { dependencies: { '@deepseek-ai/dsh-tools': '0.1.0-rc.7' } });

  const report = auditProfile({ runtimeDir, profileDir });
  assert.equal(report.ok, false);
  assert.equal(report.conflicts[0].package, '@deepseek-ai/dsh-tools');
  assert.equal(report.conflicts[0].hostVersion, '0.1.0-rc.6');
  assert.equal(report.conflicts[0].profileVersion, '0.1.0-rc.7');
  assert.equal(report.dependencyOwners[0].owner, 'broken-plugin');
  assert.match(formatReport(report), /DSH_PROFILE_INTEGRITY_ERROR/);
});

test('rejects the same core version when it is a second physical copy', t => {
  const { runtimeDir, profileDir } = fixture(t);
  writePackage(runtimeDir, '@deepseek-ai/dsh-tools', '0.1.0-rc.6');
  writePackage(profileDir, '@deepseek-ai/dsh-tools', '0.1.0-rc.6');

  const report = auditProfile({ runtimeDir, profileDir });
  assert.equal(report.ok, false);
  assert.notEqual(report.conflicts[0].hostPath, report.conflicts[0].profilePath);
});

test('accepts a plugin that declares the host core package only as a peer', t => {
  const { runtimeDir, profileDir } = fixture(t);
  writePackage(runtimeDir, '@deepseek-ai/dsh-tools', '0.1.0-rc.6');
  writePackage(profileDir, 'safe-plugin', '1.0.0', { peerDependencies: { '@deepseek-ai/dsh-tools': '>=0.1.0-rc.6 <0.2.0' } });

  assert.equal(auditProfile({ runtimeDir, profileDir }).ok, true);
});

test('rejects an ordinary host-core dependency even before a copy is installed', t => {
  const { runtimeDir, profileDir } = fixture(t);
  writePackage(runtimeDir, '@deepseek-ai/dsh-tools', '0.1.0-rc.6');
  writePackage(profileDir, 'structurally-broken-plugin', '1.0.0', { dependencies: { '@deepseek-ai/dsh-tools': '0.1.0-rc.6' } });

  const report = auditProfile({ runtimeDir, profileDir });
  assert.equal(report.ok, false);
  assert.equal(report.conflicts.length, 0);
  assert.equal(report.dependencyOwners[0].owner, 'structurally-broken-plugin');
});

test('accepts a profile link that resolves to the runtime host package', t => {
  const { runtimeDir, profileDir } = fixture(t);
  const protocol = writePackage(runtimeDir, '@deepseek-ai/dsh-typert-protocol', '0.1.0-rc.6');
  const tools = writePackage(runtimeDir, '@deepseek-ai/dsh-tools', '0.1.0-rc.6', {
    dependencies: { '@deepseek-ai/dsh-typert-protocol': '0.1.0-rc.6' },
  });
  fs.mkdirSync(path.join(profileDir, 'node_modules', '@deepseek-ai'), { recursive: true });
  fs.symlinkSync(tools, path.join(profileDir, 'node_modules', '@deepseek-ai', 'dsh-tools'), 'dir');
  fs.symlinkSync(protocol, path.join(profileDir, 'node_modules', '@deepseek-ai', 'dsh-typert-protocol'), 'dir');

  assert.equal(auditProfile({ runtimeDir, profileDir }).ok, true);
});

test('accepts a deployed DSH package root', t => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'dsh-profile-doctor-deployed-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const runtimeDir = path.join(root, 'runtime');
  const profileDir = path.join(root, 'profile');
  fs.mkdirSync(path.join(runtimeDir, 'lib'), { recursive: true });
  fs.mkdirSync(profileDir, { recursive: true });
  fs.writeFileSync(path.join(runtimeDir, 'package.json'), JSON.stringify({
    name: '@deepseek-ai/dsh',
    version: '0.1.1-rc.2',
  }));

  assert.equal(auditProfile({ runtimeDir, profileDir }).ok, true);
});
