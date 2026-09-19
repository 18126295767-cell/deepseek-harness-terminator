#!/usr/bin/env node
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const CORE_PREFIX = '@deepseek-ai/dsh-';
const CORE_EXACT = new Set(['@deepseek-ai/dsh', '@deepseek-ai/cordis']);

export function isHostCorePackage(name) {
  return typeof name === 'string' && (CORE_EXACT.has(name) || name.startsWith(CORE_PREFIX));
}

function readJson(file) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch {
    return null;
  }
}

function realpath(file) {
  try {
    return fs.realpathSync(file);
  } catch {
    return path.resolve(file);
  }
}

function visitPackage(directory, result, visited) {
  const resolved = realpath(directory);
  if (visited.has(resolved)) return;
  visited.add(resolved);

  const manifestPath = path.join(directory, 'package.json');
  const manifest = readJson(manifestPath);
  if (manifest?.name) {
    result.push({
      name: manifest.name,
      version: manifest.version ?? 'unknown',
      path: realpath(directory),
      dependencies: manifest.dependencies ?? {},
    });
  }
  scanNodeModules(path.join(directory, 'node_modules'), result, visited);
}

function scanNodeModules(nodeModules, result = [], visited = new Set()) {
  let entries;
  try {
    entries = fs.readdirSync(nodeModules, { withFileTypes: true });
  } catch {
    return result;
  }

  for (const entry of entries) {
    if (entry.name === '.bin') continue;
    const entryPath = path.join(nodeModules, entry.name);
    if (entry.name === '.pnpm') {
      let storeEntries = [];
      try {
        storeEntries = fs.readdirSync(entryPath, { withFileTypes: true });
      } catch {}
      for (const storeEntry of storeEntries) {
        if (!storeEntry.isDirectory() && !storeEntry.isSymbolicLink()) continue;
        scanNodeModules(path.join(entryPath, storeEntry.name, 'node_modules'), result, visited);
      }
      continue;
    }
    if (entry.name.startsWith('@')) {
      let scopedEntries = [];
      try {
        scopedEntries = fs.readdirSync(entryPath, { withFileTypes: true });
      } catch {}
      for (const scopedEntry of scopedEntries) {
        if (!scopedEntry.isDirectory() && !scopedEntry.isSymbolicLink()) continue;
        visitPackage(path.join(entryPath, scopedEntry.name), result, visited);
      }
      continue;
    }
    if (entry.isDirectory() || entry.isSymbolicLink()) visitPackage(entryPath, result, visited);
  }
  return result;
}

function dependencyOwners(profileDir, coreNames, installedPackages, hostPaths) {
  const owners = [];
  const rootManifest = readJson(path.join(profileDir, 'package.json'));
  const candidates = rootManifest
    ? [{ name: rootManifest.name ?? '<profile>', path: profileDir, dependencies: rootManifest.dependencies ?? {} }, ...installedPackages]
    : installedPackages;

  for (const candidate of candidates) {
    // A profile peer may intentionally link to the exact host package. Its
    // own workspace dependencies are host-owned too, not profile violations.
    if (hostPaths.has(candidate.path)) continue;
    for (const name of Object.keys(candidate.dependencies)) {
      if (coreNames.has(name)) owners.push({ corePackage: name, owner: candidate.name, ownerPath: candidate.path });
    }
  }
  return owners;
}

export function auditProfile({ runtimeDir, profileDir }) {
  const runtime = path.resolve(runtimeDir);
  const profile = path.resolve(profileDir);
  const runtimeManifestCandidates = [
    path.join(runtime, 'node_modules', '@deepseek-ai', 'dsh', 'package.json'),
    path.join(runtime, 'package.json'),
  ];
  const runtimeManifest = runtimeManifestCandidates.find(file => fs.existsSync(file));
  if (!runtimeManifest) {
    throw new Error(`Cannot find the DSH runtime at ${runtimeManifestCandidates.join(' or ')}`);
  }

  const hostPackages = scanNodeModules(path.join(runtime, 'node_modules'))
    .filter(pkg => isHostCorePackage(pkg.name));
  const hostByName = new Map();
  for (const pkg of hostPackages) if (!hostByName.has(pkg.name)) hostByName.set(pkg.name, pkg);

  if (!fs.existsSync(profile)) {
    return { ok: true, runtimeDir: runtime, profileDir: profile, conflicts: [], dependencyOwners: [] };
  }

  const profilePackages = scanNodeModules(path.join(profile, 'node_modules'));
  const conflicts = [];
  for (const pkg of profilePackages) {
    const host = hostByName.get(pkg.name);
    if (!host || host.path === pkg.path) continue;
    conflicts.push({
      package: pkg.name,
      hostVersion: host.version,
      profileVersion: pkg.version,
      hostPath: host.path,
      profilePath: pkg.path,
    });
  }

  const owners = dependencyOwners(
    profile,
    new Set(hostByName.keys()),
    profilePackages,
    new Set(hostPackages.map(pkg => pkg.path)),
  );
  return {
    ok: conflicts.length === 0 && owners.length === 0,
    runtimeDir: runtime,
    profileDir: profile,
    conflicts,
    dependencyOwners: owners,
  };
}

export function formatReport(report) {
  if (report.ok) return `DSH profile integrity OK: ${report.profileDir}`;
  const lines = [
    'DSH_PROFILE_INTEGRITY_ERROR',
    'DSH profile 依赖完整性检查失败：profile 安装了宿主核心包的第二个物理副本。',
    'This can break Cordis service Symbols and leave incomplete tool calls. Startup has been stopped.',
  ];
  for (const conflict of report.conflicts) {
    lines.push(`- ${conflict.package}: host ${conflict.hostVersion} at ${conflict.hostPath}`);
    lines.push(`  profile ${conflict.profileVersion} at ${conflict.profilePath}`);
    const owners = report.dependencyOwners.filter(owner => owner.corePackage === conflict.package);
    for (const owner of owners) lines.push(`  introduced by ${owner.owner} at ${owner.ownerPath}`);
  }
  for (const owner of report.dependencyOwners) {
    if (report.conflicts.some(conflict => conflict.package === owner.corePackage)) continue;
    lines.push(`- ${owner.owner} declares host core ${owner.corePackage} in dependencies at ${owner.ownerPath}`);
  }
  lines.push('修复方法：升级或移除上面列出的插件；插件必须把 DSH 核心包声明在 peerDependencies，而不是 dependencies。');
  lines.push('旧会话若已经缺少 tool/result，请保留记录并新建会话重新发送任务。检查器不会删除任何文件。');
  return lines.join('\n');
}

function parseArguments(argv) {
  let runtimeDir = '';
  let profileDir = path.join(process.env.DSH_HOME || path.join(os.homedir(), '.dsh'), 'profiles', 'web');
  let json = false;
  let errorMarker = '';
  let command = [];
  for (let index = 0; index < argv.length; index += 1) {
    const value = argv[index];
    if (value === '--runtime') runtimeDir = argv[++index] || '';
    else if (value === '--profile-dir') profileDir = argv[++index] || '';
    else if (value === '--json') json = true;
    else if (value === '--error-marker') errorMarker = argv[++index] || '';
    else if (value === '--exec') { command = argv.slice(index + 1); break; }
    else if (value === '--help' || value === '-h') {
      console.log('Usage: node profile-doctor.mjs --runtime PATH [--profile-dir PATH] [--error-marker PATH] [--json] [--exec COMMAND ...]');
      process.exit(0);
    } else throw new Error(`Unknown argument: ${value}`);
  }
  if (!runtimeDir) throw new Error('--runtime is required');
  if (command.length === 1 && command[0] === '--') command = [];
  return { runtimeDir, profileDir, json, errorMarker, command };
}

async function runCommand(command) {
  const child = spawn(command[0], command.slice(1), { stdio: 'inherit' });
  const forwardTerm = () => child.kill('SIGTERM');
  const forwardInterrupt = () => child.kill('SIGINT');
  process.on('SIGTERM', forwardTerm);
  process.on('SIGINT', forwardInterrupt);
  const result = await new Promise((resolve, reject) => {
    child.on('error', reject);
    child.on('exit', (code, signal) => resolve({ code, signal }));
  });
  process.off('SIGTERM', forwardTerm);
  process.off('SIGINT', forwardInterrupt);
  if (result.signal) process.kill(process.pid, result.signal);
  process.exitCode = result.code ?? 1;
}

async function main() {
  const options = parseArguments(process.argv.slice(2));
  const report = auditProfile(options);
  const output = options.json ? JSON.stringify(report, null, 2) : formatReport(report);
  console.log(output);
  if (!report.ok) {
    if (options.errorMarker) fs.writeFileSync(options.errorMarker, `${output}\n`);
    process.exitCode = 2;
    return;
  }
  if (options.errorMarker) fs.rmSync(options.errorMarker, { force: true });
  if (options.command.length) await runCommand(options.command);
}

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  main().catch(error => {
    console.error(`DSH_PROFILE_DOCTOR_ERROR: ${error.message}`);
    process.exitCode = 1;
  });
}
