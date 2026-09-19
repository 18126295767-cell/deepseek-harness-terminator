import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

function pngDimensions(file) {
  const bytes = fs.readFileSync(file);
  assert.deepEqual([...bytes.subarray(0, 8)], [137, 80, 78, 71, 13, 10, 26, 10]);
  return { width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20) };
}

test('macOS and Windows packages include the profile doctor', () => {
  const buildScript = fs.readFileSync(path.join(root, 'scripts', 'build-app.sh'), 'utf8');
  const launchAgent = fs.readFileSync(path.join(root, 'packaging', 'com.houxinran.deepseek-harness.plist.template'), 'utf8');
  const windowsBuild = fs.readFileSync(path.join(root, 'windows', 'build-release.ps1'), 'utf8');
  const windowsLauncher = fs.readFileSync(path.join(root, 'windows', 'launch-dsh.ps1'), 'utf8');

  assert.match(buildScript, /profile-doctor\.mjs/);
  assert.match(launchAgent, /__DOCTOR_SCRIPT__/);
  assert.match(launchAgent, /__ERROR_MARKER__/);
  assert.match(launchAgent, /<string>--no-open<\/string>/);
  assert.match(windowsBuild, /profile-doctor\.mjs/);
  assert.match(windowsLauncher, /profile-doctor\.mjs/);
  assert.equal(fs.existsSync(path.join(root, 'App', 'DeepSeekHarnessApp', 'DeepSeekHarness.app', 'Contents', 'Resources', 'profile-doctor.mjs')), true);
});

test('macOS builder accepts a deployed DSH package root', t => {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'dsh-macos-builder-'));
  t.after(() => fs.rmSync(temporary, { recursive: true, force: true }));

  const runtime = path.join(temporary, 'runtime');
  const output = path.join(temporary, 'output');
  fs.mkdirSync(path.join(runtime, 'lib'), { recursive: true });
  fs.writeFileSync(path.join(runtime, 'lib', 'bin.js'), '#!/usr/bin/env node\n');

  const result = spawnSync(
    'zsh',
    [path.join(root, 'scripts', 'build-app.sh'), '--dsh-runtime', runtime, '--output', output],
    { encoding: 'utf8' },
  );

  assert.equal(result.status, 0, result.stderr);
  assert.equal(fs.existsSync(path.join(output, 'DeepSeekHarness.app', 'Contents', 'MacOS', 'DeepSeekHarness')), true);
});

test('all Windows language guides include the profile integrity recovery', () => {
  const guides = fs.readdirSync(path.join(root, 'windows'))
    .filter(file => /^README.*\.md$/.test(file));
  assert.equal(guides.length, 12);
  for (const guide of guides) {
    const contents = fs.readFileSync(path.join(root, 'windows', guide), 'utf8');
    assert.match(contents, /@deepseek-ai\/dsh-/i, guide);
    assert.match(contents, /tool_calls/i, guide);
  }
});

test('Windows executable discovery preserves complete fallback paths', () => {
  for (const file of [
    'windows/build-release.ps1',
    'windows/launch-dsh.ps1',
    'windows/bootstrap-build-environment.ps1',
    '.github/workflows/windows-release.yml',
  ]) {
    const source = fs.readFileSync(path.join(root, file), 'utf8');
    assert.match(source, /Select-Object -First 1/);
    assert.doesNotMatch(source, /\$(?:nsisC|c)andidates(?:\.Count|\[0\])/);
  }
});

test('Windows verification summary closes its artifact loop', () => {
  const workflow = fs.readFileSync(path.join(root, '.github', 'workflows', 'windows-release.yml'), 'utf8');
  assert.match(
    workflow,
    /foreach \(\$artifact in \$artifacts\) \{[\s\S]*?GITHUB_STEP_SUMMARY[\s\S]*?^          \}$/m,
  );
});

test('Windows documentation screenshots are isolated and verified', () => {
  const capture = fs.readFileSync(path.join(root, 'scripts', 'capture-windows-ui.mjs'), 'utf8');
  const workflow = fs.readFileSync(path.join(root, '.github', 'workflows', 'windows-release.yml'), 'utf8');

  assert.match(capture, /viewport = \{ width: 1600, height: 1000 \}/);
  assert.match(capture, /locale: 'en-US'/);
  assert.match(capture, /parsedUrl\.hostname !== '127\.0\.0\.1'/);
  assert.match(capture, /fresh non-persistent Playwright context/);
  assert.match(capture, /validatePng/);
  assert.match(capture, /windows-screenshot-proof\.json/);
  assert.match(capture, /crypto\.createHash\('sha256'\)/);
  assert.match(capture, /windows-05-plugin-inventory\.png/);
  assert.match(workflow, /capture-windows-ui\.mjs/);
  assert.match(workflow, /windows-2025/);
  assert.match(workflow, /PLAYWRIGHT_BROWSERS_PATH/);
  assert.match(workflow, /runnerLabel -ne "windows-2025"/);
  assert.match(workflow, /runnerImage -notmatch '\^win25'/);
  assert.match(workflow, /1600x1000/);
});

test('macOS documentation screenshots are lossless and linked', () => {
  assert.deepEqual(
    pngDimensions(path.join(root, 'docs', 'images', 'macos-dsh-home.png')),
    { width: 1600, height: 900 },
  );
  assert.deepEqual(
    pngDimensions(path.join(root, 'docs', 'images', 'macos-app-home.png')),
    { width: 1281, height: 768 },
  );

  for (const guide of ['README.md', 'README.zh-CN.md', 'TUTORIAL.md', 'TUTORIAL.zh-CN.md']) {
    const contents = fs.readFileSync(path.join(root, guide), 'utf8');
    assert.match(contents, /docs\/images\/macos-dsh-home\.png/, guide);
    assert.match(contents, /docs\/images\/macos-app-home\.png/, guide);
  }
});

test('built-in browser docs and WebKit notice are present', () => {
  const notice = fs.readFileSync(path.join(root, 'NOTICE'), 'utf8');
  const mainSwift = fs.readFileSync(path.join(root, 'App', 'DeepSeekHarnessApp', 'main.swift'), 'utf8');

  // WebKit open-source engine notice documents the browser kernel licensing.
  assert.match(notice, /Third-party notice: WebKit/);
  assert.match(notice, /WKWebView/);
  assert.match(notice, /BSD-2-Clause/);

  // The built-in browser must be real-time (WKWebView), not a screenshot, and
  // must not steal focus (orderFront + becomesKeyOnlyIfNeeded, no activate).
  assert.match(mainSwift, /class BrowserPaneController/);
  assert.match(mainSwift, /WKWebView/);
  assert.match(mainSwift, /orderFront/);
  assert.match(mainSwift, /becomesKeyOnlyIfNeeded = true/);
  assert.match(mainSwift, /\.utilityWindow/);

  for (const guide of ['README.md', 'README.zh-CN.md', 'TUTORIAL.md', 'TUTORIAL.zh-CN.md']) {
    const contents = fs.readFileSync(path.join(root, guide), 'utf8');
    assert.match(contents, /built-in browser panel|内置浏览器面板/, guide);
    assert.match(contents, /Cmd\+B/, guide);
    assert.match(contents, /real-time|实时渲染|live-rendered/i, guide);
    assert.match(contents, /becomesKeyOnlyIfNeeded|不抢前台/, guide);
  }
});

test('native app metadata matches the package release version', () => {
  const packageJson = JSON.parse(fs.readFileSync(path.join(root, 'package.json'), 'utf8'));
  const plist = fs.readFileSync(path.join(root, 'App', 'DeepSeekHarnessApp', 'Info.plist'), 'utf8');
  const mainSwift = fs.readFileSync(path.join(root, 'App', 'DeepSeekHarnessApp', 'main.swift'), 'utf8');
  const plistVersion = plist.match(/<key>CFBundleShortVersionString<\/key>\s*<string>([^<]+)<\/string>/)?.[1];
  const aboutVersion = mainSwift.match(/\.applicationVersion:\s*"([^"]+)"/)?.[1];

  assert.equal(plistVersion, packageJson.version, 'Info.plist release version matches package.json');
  assert.equal(aboutVersion, packageJson.version, 'About dialog release version matches package.json');
});

test('public release identity is DeepSeek Harness Terminator', () => {
  const packageJson = JSON.parse(fs.readFileSync(path.join(root, 'package.json'), 'utf8'));
  const plist = fs.readFileSync(path.join(root, 'App', 'DeepSeekHarnessApp', 'Info.plist'), 'utf8');
  const builder = fs.readFileSync(path.join(root, 'scripts', 'build-app.sh'), 'utf8');
  const readme = fs.readFileSync(path.join(root, 'README.md'), 'utf8');

  assert.equal(packageJson.name, 'deepseek-harness-terminator');
  assert.match(packageJson.repository.url, /deepseek-harness-terminator\.git$/);
  assert.match(plist, /<key>CFBundleDisplayName<\/key>\s*<string>DeepSeek Harness Terminator<\/string>/);
  assert.match(builder, /target_app=.*DeepSeek Harness Terminator\.app/);
  assert.match(readme, /^# DeepSeek Harness Terminator/m);
});

test('Windows release defaults and documentation stay reproducible', () => {
  const packageJson = JSON.parse(fs.readFileSync(path.join(root, 'package.json'), 'utf8'));
  const buildRelease = fs.readFileSync(path.join(root, 'windows', 'build-release.ps1'), 'utf8');
  const installer = fs.readFileSync(path.join(root, 'windows', 'installer.nsi'), 'utf8');
  const launcher = fs.readFileSync(path.join(root, 'windows', 'launch-dsh.ps1'), 'utf8');
  const workflow = fs.readFileSync(path.join(root, '.github', 'workflows', 'windows-release.yml'), 'utf8');
  const windowsReadme = fs.readFileSync(path.join(root, 'windows', 'README.md'), 'utf8');
  const windowsReadmeZh = fs.readFileSync(path.join(root, 'windows', 'README.zh-CN.md'), 'utf8');

  assert.match(buildRelease, new RegExp(`\\$Version = "${packageJson.version}"`));
  assert.match(installer, new RegExp(`VERSION "${packageJson.version}"`));
  assert.match(workflow, new RegExp(`default: "${packageJson.version}"`));
  assert.match(workflow, new RegExp(`else \\{ '${packageJson.version}' \\}`));
  assert.match(launcher, /DeepSeek Harness Terminator\\logs/);
  assert.match(workflow, /DeepSeek Harness Terminator\\logs/);
  for (const guide of [windowsReadme, windowsReadmeZh]) {
    assert.match(guide, /DeepSeek Harness Terminator/);
    assert.doesNotMatch(guide, /%LOCALAPPDATA%\\DeepSeek Harness\\logs/);
    assert.doesNotMatch(guide, /(?:-Version |v)0\.1\.0|0\.1\.0\.sha256/);
  }
});

test('built-in browser panel stays above the main window without taking focus', () => {
  const mainSwift = fs.readFileSync(path.join(root, 'App', 'DeepSeekHarnessApp', 'main.swift'), 'utf8');

  assert.match(
    mainSwift,
    /panel\.isFloatingPanel\s*=\s*true/,
    'browser panel must float above the main window so orderFront is visible',
  );
  assert.match(mainSwift, /panel\.becomesKeyOnlyIfNeeded\s*=\s*true/);
  assert.match(mainSwift, /panel\.orderFront\(nil\)/);
});

test('built-in browser address bar turns search terms into an in-panel search (TDD)', () => {
  const source = path.join(root, 'App', 'DeepSeekHarnessApp', 'BuiltinBrowserAddress.swift');
  assert.equal(fs.existsSync(source), true, 'BuiltinBrowserAddress.swift exists');
  const mainSwift = fs.readFileSync(path.join(root, 'App', 'DeepSeekHarnessApp', 'main.swift'), 'utf8');
  const buildScript = fs.readFileSync(path.join(root, 'scripts', 'build-app.sh'), 'utf8');

  // main.swift must route address input through the resolver.
  assert.match(mainSwift, /BuiltinBrowserAddress\.resolve/, 'main.swift uses BuiltinBrowserAddress.resolve');
  assert.match(mainSwift, /输入网址或搜索词/, 'address bar placeholder hints search');

  // build-app.sh must compile the new source together with main.swift.
  assert.match(buildScript, /BuiltinBrowserAddress\.swift/, 'build-app.sh compiles BuiltinBrowserAddress.swift');

  // Run the Swift contract test (pure Foundation, no AppKit), cross-checking the
  // grammar for URL / host / search-term resolution. This is the green gate.
  const testSwift = path.join(root, 'tests', 'builtin-address.test.swift');
  const bin = path.join(root, 'tests', 'builtin-address-test');
  const compiled = spawnSync('swiftc', ['-O', source, testSwift, '-o', bin], { encoding: 'utf8' });
  assert.equal(compiled.status, 0, `swiftc failed: ${compiled.stderr || compiled.stdout}`);
  const run = spawnSync(bin, [], { encoding: 'utf8' });
  assert.equal(run.status, 0, `built-in address test failed: ${run.stdout} ${run.stderr}`);
  assert.match(run.stdout, /0 failures/, 'built-in address test reports 0 failures');
});

test('voice input model passes its pure-logic contract test (TDD)', () => {
  const model = path.join(root, 'App', 'DeepSeekHarnessApp', 'VoiceInputModel.swift');
  assert.equal(fs.existsSync(model), true, 'VoiceInputModel.swift exists');

  // main.swift must expose a voice input entry point (menu / panel mic button).
  const mainSwift = fs.readFileSync(path.join(root, 'App', 'DeepSeekHarnessApp', 'main.swift'), 'utf8');
  assert.match(mainSwift, /VoiceController/, 'main.swift wires VoiceController');
  assert.match(mainSwift, /语音输入/, 'UI exposes a voice input entry');

  // build-app.sh must compile the new voice sources with main.swift.
  const buildScript = fs.readFileSync(path.join(root, 'scripts', 'build-app.sh'), 'utf8');
  assert.match(buildScript, /VoiceInputModel\.swift/, 'build-app.sh compiles VoiceInputModel.swift');
  assert.match(buildScript, /VoiceController\.swift/, 'build-app.sh compiles VoiceController.swift');

  // Info.plist must declare the two usage-description keys or permission would crash at runtime.
  const plist = fs.readFileSync(path.join(root, 'App', 'DeepSeekHarnessApp', 'Info.plist'), 'utf8');
  assert.match(plist, /NSMicrophoneUsageDescription/, 'Info.plist declares microphone usage');
  assert.match(plist, /NSSpeechRecognitionUsageDescription/, 'Info.plist declares speech recognition usage');

  // Run the Swift contract test (pure Foundation, no Speech/AppKit), cross-checking
  // locale normalization, transcript normalization, and permission→state mapping.
  const testSwift = path.join(root, 'tests', 'voice-input.test.swift');
  const bin = path.join(root, 'tests', 'voice-input-test');
  const compiled = spawnSync('swiftc', ['-O', model, testSwift, '-o', bin], { encoding: 'utf8' });
  assert.equal(compiled.status, 0, `swiftc failed: ${compiled.stderr || compiled.stdout}`);
  const run = spawnSync(bin, [], { encoding: 'utf8' });
  assert.equal(run.status, 0, `voice input test failed: ${run.stdout} ${run.stderr}`);
  assert.match(run.stdout, /0 failures/, 'voice input test reports 0 failures');
});

test('browser tab manager passes its pure-logic contract test (TDD)', () => {
  const model = path.join(root, 'App', 'DeepSeekHarnessApp', 'BrowserTabManager.swift');
  assert.equal(fs.existsSync(model), true, 'BrowserTabManager.swift exists');

  // main.swift must use the tab manager to track open tabs (real-time panel state).
  const mainSwift = fs.readFileSync(path.join(root, 'App', 'DeepSeekHarnessApp', 'main.swift'), 'utf8');
  assert.match(mainSwift, /BrowserTabManager\(\)/, 'main.swift instantiates BrowserTabManager');

  // build-app.sh must compile the new tab manager together with main.swift.
  const buildScript = fs.readFileSync(path.join(root, 'scripts', 'build-app.sh'), 'utf8');
  assert.match(buildScript, /BrowserTabManager\.swift/, 'build-app.sh compiles BrowserTabManager.swift');

  // Run the Swift contract test (pure Foundation, no AppKit/WebKit), cross-checking
  // add/select/remove/next/previous and tab model construction.
  const testSwift = path.join(root, 'tests', 'browser-tab.test.swift');
  const bin = path.join(root, 'tests', 'browser-tab-test');
  const compiled = spawnSync('swiftc', ['-O', model, testSwift, '-o', bin], { encoding: 'utf8' });
  assert.equal(compiled.status, 0, `swiftc failed: ${compiled.stderr || compiled.stdout}`);
  const run = spawnSync(bin, [], { encoding: 'utf8' });
  assert.equal(run.status, 0, `browser tab test failed: ${run.stdout} ${run.stderr}`);
  assert.match(run.stdout, /0 failures/, 'browser tab test reports 0 failures');
});

test('browser session store passes its pure-logic contract test (TDD)', () => {
  const model = path.join(root, 'App', 'DeepSeekHarnessApp', 'BrowserSessionStore.swift');
  assert.equal(fs.existsSync(model), true, 'BrowserSessionStore.swift exists');

  // build-app.sh must compile the session store together with main.swift.
  const buildScript = fs.readFileSync(path.join(root, 'scripts', 'build-app.sh'), 'utf8');
  assert.match(buildScript, /BrowserSessionStore\.swift/, 'build-app.sh compiles BrowserSessionStore.swift');

  // Run the Swift contract test (pure Foundation), covering bookmarks, LIFO
  // history capping, cross-instance persistence via the KV seam, and search.
  const testSwift = path.join(root, 'tests', 'browser-session.test.swift');
  const bin = path.join(root, 'tests', 'browser-session-test');
  const compiled = spawnSync('swiftc', ['-O', model, testSwift, '-o', bin], { encoding: 'utf8' });
  assert.equal(compiled.status, 0, `swiftc failed: ${compiled.stderr || compiled.stdout}`);
  const run = spawnSync(bin, [], { encoding: 'utf8' });
  assert.equal(run.status, 0, `browser session test failed: ${run.stdout} ${run.stderr}`);
  assert.match(run.stdout, /0 failures/, 'browser session test reports 0 failures');
});

test('find-in-page model passes its pure-logic contract test (TDD)', () => {
  const model = path.join(root, 'App', 'DeepSeekHarnessApp', 'FindInPageModel.swift');
  assert.equal(fs.existsSync(model), true, 'FindInPageModel.swift exists');

  // build-app.sh must compile the find-in-page model together with main.swift.
  const buildScript = fs.readFileSync(path.join(root, 'scripts', 'build-app.sh'), 'utf8');
  assert.match(buildScript, /FindInPageModel\.swift/, 'build-app.sh compiles FindInPageModel.swift');

  // main.swift wires a find-in-page entry point (⌘F find bar).
  const mainSwift = fs.readFileSync(path.join(root, 'App', 'DeepSeekHarnessApp', 'main.swift'), 'utf8');
  assert.match(mainSwift, /FindInPageModel/, 'main.swift wires FindInPageModel');

  // Run the Swift contract test (pure Foundation), covering query normalization,
  // match counting, wrap-around navigation, and status text.
  const testSwift = path.join(root, 'tests', 'find-in-page.test.swift');
  const bin = path.join(root, 'tests', 'find-in-page-test');
  const compiled = spawnSync('swiftc', ['-O', model, testSwift, '-o', bin], { encoding: 'utf8' });
  assert.equal(compiled.status, 0, `swiftc failed: ${compiled.stderr || compiled.stdout}`);
  const run = spawnSync(bin, [], { encoding: 'utf8' });
  assert.equal(run.status, 0, `find-in-page test failed: ${run.stdout} ${run.stderr}`);
  assert.match(run.stdout, /0 failures/, 'find-in-page test reports 0 failures');
});

test('command palette passes its pure-logic contract test (TDD)', () => {
  const model = path.join(root, 'App', 'DeepSeekHarnessApp', 'CommandPalette.swift');
  assert.equal(fs.existsSync(model), true, 'CommandPalette.swift exists');

  // build-app.sh must compile the command palette together with main.swift.
  const buildScript = fs.readFileSync(path.join(root, 'scripts', 'build-app.sh'), 'utf8');
  assert.match(buildScript, /CommandPalette\.swift/, 'build-app.sh compiles CommandPalette.swift');

  // main.swift wires a command-palette entry point (⌘T command bar).
  const mainSwift = fs.readFileSync(path.join(root, 'App', 'DeepSeekHarnessApp', 'main.swift'), 'utf8');
  assert.match(mainSwift, /CommandPalette/, 'main.swift wires CommandPalette');

  // Run the Swift contract test (pure Foundation), covering case-insensitive
  // search by title/subtitle/host, prefix command mode, and keyboard navigation.
  const testSwift = path.join(root, 'tests', 'command-palette.test.swift');
  const bin = path.join(root, 'tests', 'command-palette-test');
  const compiled = spawnSync('swiftc', ['-O', model, testSwift, '-o', bin], { encoding: 'utf8' });
  assert.equal(compiled.status, 0, `swiftc failed: ${compiled.stderr || compiled.stdout}`);
  const run = spawnSync(bin, [], { encoding: 'utf8' });
  assert.equal(run.status, 0, `command palette test failed: ${run.stdout} ${run.stderr}`);
  assert.match(run.stdout, /0 failures/, 'command palette test reports 0 failures');
});

test('page-summary model passes its pure-logic contract test (TDD)', () => {
  const model = path.join(root, 'App', 'DeepSeekHarnessApp', 'PageSummaryModel.swift');
  assert.equal(fs.existsSync(model), true, 'PageSummaryModel.swift exists');

  // build-app.sh must compile the page-summary model together with main.swift.
  const buildScript = fs.readFileSync(path.join(root, 'scripts', 'build-app.sh'), 'utf8');
  assert.match(buildScript, /PageSummaryModel\.swift/, 'build-app.sh compiles PageSummaryModel.swift');

  // main.swift routes summarize through the pure model into the local DSH.
  const mainSwift = fs.readFileSync(path.join(root, 'App', 'DeepSeekHarnessApp', 'main.swift'), 'utf8');
  assert.match(mainSwift, /PageSummaryModel/, 'main.swift wires PageSummaryModel');

  // Run the Swift contract test (pure Foundation), covering eligibility,
  // prompt construction with title/URL/snippet, and per-language summaries.
  const testSwift = path.join(root, 'tests', 'page-summary.test.swift');
  const bin = path.join(root, 'tests', 'page-summary-test');
  const compiled = spawnSync('swiftc', ['-O', model, testSwift, '-o', bin], { encoding: 'utf8' });
  assert.equal(compiled.status, 0, `swiftc failed: ${compiled.stderr || compiled.stdout}`);
  const run = spawnSync(bin, [], { encoding: 'utf8' });
  assert.equal(run.status, 0, `page summary test failed: ${run.stdout} ${run.stderr}`);
  assert.match(run.stdout, /0 failures/, 'page summary test reports 0 failures');
});

test('browser shortcuts pass their pure-logic contract test (TDD)', () => {
  const model = path.join(root, 'App', 'DeepSeekHarnessApp', 'BrowserShortcuts.swift');
  assert.equal(fs.existsSync(model), true, 'BrowserShortcuts.swift exists');

  // build-app.sh must compile the shortcuts model together with main.swift.
  const buildScript = fs.readFileSync(path.join(root, 'scripts', 'build-app.sh'), 'utf8');
  assert.match(buildScript, /BrowserShortcuts\.swift/, 'build-app.sh compiles BrowserShortcuts.swift');

  // main.swift places the roadmap shortcut menu items (⌘N/⌘W/⌘1-9/⌃⌘Tab).
  const mainSwift = fs.readFileSync(path.join(root, 'App', 'DeepSeekHarnessApp', 'main.swift'), 'utf8');
  assert.match(mainSwift, /BrowserShortcuts/, 'main.swift wires BrowserShortcuts');

  // Run the Swift contract test (pure Foundation), covering key→command parsing
  // and roadmap coverage.
  const testSwift = path.join(root, 'tests', 'browser-shortcuts.test.swift');
  const bin = path.join(root, 'tests', 'browser-shortcuts-test');
  const compiled = spawnSync('swiftc', ['-O', model, testSwift, '-o', bin], { encoding: 'utf8' });
  assert.equal(compiled.status, 0, `swiftc failed: ${compiled.stderr || compiled.stdout}`);
  const run = spawnSync(bin, [], { encoding: 'utf8' });
  assert.equal(run.status, 0, `browser shortcuts test failed: ${run.stdout} ${run.stderr}`);
  assert.match(run.stdout, /0 failures/, 'browser shortcuts test reports 0 failures');
});

test('tab grouping model passes its pure-logic contract test (TDD)', () => {
  const model = path.join(root, 'App', 'DeepSeekHarnessApp', 'TabGroupingModel.swift');
  assert.equal(fs.existsSync(model), true, 'TabGroupingModel.swift exists');

  // build-app.sh must compile the tab-grouping model together with main.swift.
  const buildScript = fs.readFileSync(path.join(root, 'scripts', 'build-app.sh'), 'utf8');
  assert.match(buildScript, /TabGroupingModel\.swift/, 'build-app.sh compiles TabGroupingModel.swift');

  // main.swift wires tab grouping into the browser panel.
  const mainSwift = fs.readFileSync(path.join(root, 'App', 'DeepSeekHarnessApp', 'main.swift'), 'utf8');
  assert.match(mainSwift, /TabGroupingModel/, 'main.swift wires TabGroupingModel');

  // Run the Swift contract test (pure Foundation), covering grouping key
  // aggregation, first-seen ordering, and group summaries.
  const testSwift = path.join(root, 'tests', 'tab-grouping.test.swift');
  const bin = path.join(root, 'tests', 'tab-grouping-test');
  const compiled = spawnSync('swiftc', ['-O', model, testSwift, '-o', bin], { encoding: 'utf8' });
  assert.equal(compiled.status, 0, `swiftc failed: ${compiled.stderr || compiled.stdout}`);
  const run = spawnSync(bin, [], { encoding: 'utf8' });
  assert.equal(run.status, 0, `tab grouping test failed: ${run.stdout} ${run.stderr}`);
  assert.match(run.stdout, /0 failures/, 'tab grouping test reports 0 failures');
});

test('split pane state passes its pure-logic contract test (TDD)', () => {
  const model = path.join(root, 'App', 'DeepSeekHarnessApp', 'SplitPaneState.swift');
  assert.equal(fs.existsSync(model), true, 'SplitPaneState.swift exists');

  // build-app.sh must compile the split-pane state model together with main.swift.
  const buildScript = fs.readFileSync(path.join(root, 'scripts', 'build-app.sh'), 'utf8');
  assert.match(buildScript, /SplitPaneState\.swift/, 'build-app.sh compiles SplitPaneState.swift');

  // main.swift wires split-pane state into the browser panel.
  const mainSwift = fs.readFileSync(path.join(root, 'App', 'DeepSeekHarnessApp', 'main.swift'), 'utf8');
  assert.match(mainSwift, /SplitPaneState/, 'main.swift wires SplitPaneState');

  // Run the Swift contract test (pure Foundation), covering activate/close and split mirroring.
  const testSwift = path.join(root, 'tests', 'split-pane.test.swift');
  const bin = path.join(root, 'tests', 'split-pane-test');
  const compiled = spawnSync('swiftc', ['-O', model, testSwift, '-o', bin], { encoding: 'utf8' });
  assert.equal(compiled.status, 0, `swiftc failed: ${compiled.stderr || compiled.stdout}`);
  const run = spawnSync(bin, [], { encoding: 'utf8' });
  assert.equal(run.status, 0, `split pane test failed: ${run.stdout} ${run.stderr}`);
  assert.match(run.stdout, /0 failures/, 'split pane test reports 0 failures');
});

test('session restore model passes its pure-logic contract test (TDD)', () => {
  const model = path.join(root, 'App', 'DeepSeekHarnessApp', 'SessionRestoreModel.swift');
  assert.equal(fs.existsSync(model), true, 'SessionRestoreModel.swift exists');

  // build-app.sh must compile the session-restore model together with main.swift.
  const buildScript = fs.readFileSync(path.join(root, 'scripts', 'build-app.sh'), 'utf8');
  assert.match(buildScript, /SessionRestoreModel\.swift/, 'build-app.sh compiles SessionRestoreModel.swift');

  // main.swift wires session restore into the browser panel lifecycle.
  const mainSwift = fs.readFileSync(path.join(root, 'App', 'DeepSeekHarnessApp', 'main.swift'), 'utf8');
  assert.match(mainSwift, /SessionRestoreModel/, 'main.swift wires SessionRestoreModel');

  // Run the Swift contract test (pure Foundation): snapshot round-trip,
  // empty/clear handling, and index clamping.
  const testSwift = path.join(root, 'tests', 'session-restore.test.swift');
  const bin = path.join(root, 'tests', 'session-restore-test');
  const compiled = spawnSync('swiftc', [
    '-O',
    path.join(root, 'App', 'DeepSeekHarnessApp', 'BrowserSessionStore.swift'),
    model, testSwift, '-o', bin,
  ], { encoding: 'utf8' });
  assert.equal(compiled.status, 0, `swiftc failed: ${compiled.stderr || compiled.stdout}`);
  const run = spawnSync(bin, [], { encoding: 'utf8' });
  assert.equal(run.status, 0, `session restore test failed: ${run.stdout} ${run.stderr}`);
  assert.match(run.stdout, /0 failures/, 'session restore test reports 0 failures');
});

test('page capture model passes its pure-logic contract test (TDD)', () => {
  const model = path.join(root, 'App', 'DeepSeekHarnessApp', 'PageCaptureModel.swift');
  assert.equal(fs.existsSync(model), true, 'PageCaptureModel.swift exists');

  // build-app.sh must compile the page-capture model together with main.swift.
  const buildScript = fs.readFileSync(path.join(root, 'scripts', 'build-app.sh'), 'utf8');
  assert.match(buildScript, /PageCaptureModel\.swift/, 'build-app.sh compiles PageCaptureModel.swift');

  // main.swift wires page capture into the browser panel.
  const mainSwift = fs.readFileSync(path.join(root, 'App', 'DeepSeekHarnessApp', 'main.swift'), 'utf8');
  assert.match(mainSwift, /PageCaptureModel/, 'main.swift wires PageCaptureModel');

  // Run the Swift contract test (pure Foundation): file-name generation,
  // illegal-char sanitization, format→capture-kind, and default directory.
  const testSwift = path.join(root, 'tests', 'page-capture.test.swift');
  const bin = path.join(root, 'tests', 'page-capture-test');
  const compiled = spawnSync('swiftc', ['-O', model, testSwift, '-o', bin], { encoding: 'utf8' });
  assert.equal(compiled.status, 0, `swiftc failed: ${compiled.stderr || compiled.stdout}`);
  const run = spawnSync(bin, [], { encoding: 'utf8' });
  assert.equal(run.status, 0, `page capture test failed: ${run.stdout} ${run.stderr}`);
  assert.match(run.stdout, /0 failures/, 'page capture test reports 0 failures');
});

test('vertical tabs model passes its pure-logic contract test (TDD)', () => {
  const model = path.join(root, 'App', 'DeepSeekHarnessApp', 'VerticalTabsModel.swift');
  assert.equal(fs.existsSync(model), true, 'VerticalTabsModel.swift exists');

  // build-app.sh must compile the vertical-tabs model together with main.swift.
  const buildScript = fs.readFileSync(path.join(root, 'scripts', 'build-app.sh'), 'utf8');
  assert.match(buildScript, /VerticalTabsModel\.swift/, 'build-app.sh compiles VerticalTabsModel.swift');

  // main.swift wires vertical tab grouping into the browser panel.
  const mainSwift = fs.readFileSync(path.join(root, 'App', 'DeepSeekHarnessApp', 'main.swift'), 'utf8');
  assert.match(mainSwift, /VerticalTabsModel/, 'main.swift wires VerticalTabsModel');

  // Run the Swift contract test (pure Foundation): grouping, fold/unfold, and
  // in-group reorder.
  const testSwift = path.join(root, 'tests', 'vertical-tabs.test.swift');
  const bin = path.join(root, 'tests', 'vertical-tabs-test');
  const compiled = spawnSync('swiftc', ['-O', model, testSwift, '-o', bin], { encoding: 'utf8' });
  assert.equal(compiled.status, 0, `swiftc failed: ${compiled.stderr || compiled.stdout}`);
  const run = spawnSync(bin, [], { encoding: 'utf8' });
  assert.equal(run.status, 0, `vertical tabs test failed: ${run.stdout} ${run.stderr}`);
  assert.match(run.stdout, /0 failures/, 'vertical tabs test reports 0 failures');
});

test('user script store passes its pure-logic contract test (TDD)', () => {
  const model = path.join(root, 'App', 'DeepSeekHarnessApp', 'UserScriptStore.swift');
  assert.equal(fs.existsSync(model), true, 'UserScriptStore.swift exists');

  // build-app.sh must compile the user-script store together with main.swift.
  const buildScript = fs.readFileSync(path.join(root, 'scripts', 'build-app.sh'), 'utf8');
  assert.match(buildScript, /UserScriptStore\.swift/, 'build-app.sh compiles UserScriptStore.swift');

  // main.swift wires the user-script store into the browser panel.
  const mainSwift = fs.readFileSync(path.join(root, 'App', 'DeepSeekHarnessApp', 'main.swift'), 'utf8');
  assert.match(mainSwift, /UserScriptStore/, 'main.swift wires UserScriptStore');

  // Run the Swift contract test (pure Foundation): CRUD, active toggle, and
  // URL-pattern matching.
  const testSwift = path.join(root, 'tests', 'user-script.test.swift');
  const bin = path.join(root, 'tests', 'user-script-test');
  const compiled = spawnSync('swiftc', [
    '-O',
    path.join(root, 'App', 'DeepSeekHarnessApp', 'BrowserSessionStore.swift'),
    model, testSwift, '-o', bin,
  ], { encoding: 'utf8' });
  assert.equal(compiled.status, 0, `swiftc failed: ${compiled.stderr || compiled.stdout}`);
  const run = spawnSync(bin, [], { encoding: 'utf8' });
  assert.equal(run.status, 0, `user script test failed: ${run.stdout} ${run.stderr}`);
  assert.match(run.stdout, /0 failures/, 'user script test reports 0 failures');
});

test('mouse gesture model passes its pure-logic contract test (TDD)', () => {
  const model = path.join(root, 'App', 'DeepSeekHarnessApp', 'MouseGestureModel.swift');
  assert.equal(fs.existsSync(model), true, 'MouseGestureModel.swift exists');

  // build-app.sh must compile the mouse-gesture model together with main.swift.
  const buildScript = fs.readFileSync(path.join(root, 'scripts', 'build-app.sh'), 'utf8');
  assert.match(buildScript, /MouseGestureModel\.swift/, 'build-app.sh compiles MouseGestureModel.swift');

  // main.swift wires mouse gestures into the browser panel.
  const mainSwift = fs.readFileSync(path.join(root, 'App', 'DeepSeekHarnessApp', 'main.swift'), 'utf8');
  assert.match(mainSwift, /MouseGestureModel/, 'main.swift wires MouseGestureModel');

  // Run the Swift contract test (pure Foundation): direction quantization,
  // gesture→command mapping.
  const testSwift = path.join(root, 'tests', 'mouse-gesture.test.swift');
  const bin = path.join(root, 'tests', 'mouse-gesture-test');
  const compiled = spawnSync('swiftc', ['-O', model, testSwift, '-o', bin], { encoding: 'utf8' });
  assert.equal(compiled.status, 0, `swiftc failed: ${compiled.stderr || compiled.stdout}`);
  const run = spawnSync(bin, [], { encoding: 'utf8' });
  assert.equal(run.status, 0, `mouse gesture test failed: ${run.stdout} ${run.stderr}`);
  assert.match(run.stdout, /0 failures/, 'mouse gesture test reports 0 failures');
});
