#!/usr/bin/env node
// 轻量仓库 lint：在无 SwiftLint 依赖的前提下，对 Swift 源码与工程卫生做可重复检查。
// 策略：只查「硬伤」——不查风格偏好，避免误报；失败即退出非 0。
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const swiftFiles = [
  'App/DeepSeekHarnessApp/main.swift',
  'App/DeepSeekHarnessApp/BuiltinBrowserAddress.swift',
  'App/DeepSeekHarnessApp/VoiceInputModel.swift',
  'App/DeepSeekHarnessApp/VoiceController.swift',
  'App/DeepSeekHarnessApp/BrowserTabManager.swift',
  'App/DeepSeekHarnessApp/BrowserSessionStore.swift',
  'App/DeepSeekHarnessApp/FindInPageModel.swift',
  'App/DeepSeekHarnessApp/CommandPalette.swift',
  'App/DeepSeekHarnessApp/PageSummaryModel.swift',
  'App/DeepSeekHarnessApp/BrowserShortcuts.swift',
  'App/DeepSeekHarnessApp/TabGroupingModel.swift',
  'App/DeepSeekHarnessApp/SplitPaneState.swift',
  'App/DeepSeekHarnessApp/SessionRestoreModel.swift',
  'App/DeepSeekHarnessApp/PageCaptureModel.swift',
  'App/DeepSeekHarnessApp/VerticalTabsModel.swift',
  'App/DeepSeekHarnessApp/UserScriptStore.swift',
  'App/DeepSeekHarnessApp/MouseGestureModel.swift',
];

const problems = [];
let checked = 0;

function checkSwift(file) {
  const p = path.join(root, file);
  if (!fs.existsSync(p)) {
    problems.push(`${file}: 文件缺失`);
    return;
  }
  const src = fs.readFileSync(p, 'utf8');
  checked += 1;

  // 交付代码不应残留未完成标记。
  const m = src.match(/TODO|FIXME|HACK|XXX/);
  if (m) problems.push(`${file}: 残留未完成标记 ${m[0]}`);
}

function checkCommonHygiene() {
  // 构建脚本必须编译全部 Swift 源，防止改了模块忘了接线。
  const build = fs.readFileSync(path.join(root, 'scripts', 'build-app.sh'), 'utf8');
  for (const f of ['VoiceInputModel.swift', 'VoiceController.swift', 'BuiltinBrowserAddress.swift', 'BrowserTabManager.swift', 'BrowserSessionStore.swift', 'FindInPageModel.swift', 'CommandPalette.swift', 'PageSummaryModel.swift', 'BrowserShortcuts.swift', 'TabGroupingModel.swift', 'SplitPaneState.swift', 'SessionRestoreModel.swift', 'PageCaptureModel.swift', 'VerticalTabsModel.swift', 'UserScriptStore.swift', 'MouseGestureModel.swift']) {
    if (!build.includes(f)) problems.push(`scripts/build-app.sh 未编译 ${f}`);
  }
  // Info.plist 必须声明语音权限用途，否则麦克风/语音识别被拒会崩溃。
  const plist = fs.readFileSync(path.join(root, 'App', 'DeepSeekHarnessApp', 'Info.plist'), 'utf8');
  for (const key of ['NSMicrophoneUsageDescription', 'NSSpeechRecognitionUsageDescription']) {
    if (!plist.includes(key)) problems.push(`Info.plist 缺少 ${key}`);
  }
  // 测试必须覆盖语音输入纯逻辑。
  const pkgTest = fs.readFileSync(path.join(root, 'tests', 'package.test.mjs'), 'utf8');
  if (!pkgTest.includes('voice-input.test.swift')) {
    problems.push('tests/package.test.mjs 未驱动 voice-input.test.swift');
  }
  // 测试必须驱动浏览器标签管理纯逻辑（防新模块漏接线）。
  if (!pkgTest.includes('browser-tab.test.swift')) {
    problems.push('tests/package.test.mjs 未驱动 browser-tab.test.swift');
  }
  // 测试必须驱动浏览器会话存储纯逻辑（书签/历史）。
  if (!pkgTest.includes('browser-session.test.swift')) {
    problems.push('tests/package.test.mjs 未驱动 browser-session.test.swift');
  }
  // 测试必须驱动站内查找纯逻辑（find-in-page）。
  if (!pkgTest.includes('find-in-page.test.swift')) {
    problems.push('tests/package.test.mjs 未驱动 find-in-page.test.swift');
  }
  // 测试必须驱动命令栏纯逻辑（command palette）。
  if (!pkgTest.includes('command-palette.test.swift')) {
    problems.push('tests/package.test.mjs 未驱动 command-palette.test.swift');
  }
  // 测试必须驱动 AI 总结纯逻辑（page summary）。
  if (!pkgTest.includes('page-summary.test.swift')) {
    problems.push('tests/package.test.mjs 未驱动 page-summary.test.swift');
  }
  // 测试必须驱动快捷键集纯逻辑（browser shortcuts）。
  if (!pkgTest.includes('browser-shortcuts.test.swift')) {
    problems.push('tests/package.test.mjs 未驱动 browser-shortcuts.test.swift');
  }
  // 测试必须驱动标签分组纯逻辑（tab grouping）。
  if (!pkgTest.includes('tab-grouping.test.swift')) {
    problems.push('tests/package.test.mjs 未驱动 tab-grouping.test.swift');
  }
  // 测试必须驱动分屏纯逻辑（split pane）。
  if (!pkgTest.includes('split-pane.test.swift')) {
    problems.push('tests/package.test.mjs 未驱动 split-pane.test.swift');
  }
  // 测试必须驱动会话恢复纯逻辑（session restore）。
  if (!pkgTest.includes('session-restore.test.swift')) {
    problems.push('tests/package.test.mjs 未驱动 session-restore.test.swift');
  }
  // 测试必须驱动截图/页面保存纯逻辑（page capture）。
  if (!pkgTest.includes('page-capture.test.swift')) {
    problems.push('tests/package.test.mjs 未驱动 page-capture.test.swift');
  }
  // 测试必须驱动垂直多标签栏纯逻辑（vertical tabs）。
  if (!pkgTest.includes('vertical-tabs.test.swift')) {
    problems.push('tests/package.test.mjs 未驱动 vertical-tabs.test.swift');
  }
  // 测试必须驱动用户脚本纯逻辑（user script store）。
  if (!pkgTest.includes('user-script.test.swift')) {
    problems.push('tests/package.test.mjs 未驱动 user-script.test.swift');
  }
  // 测试必须驱动鼠标手势纯逻辑（mouse gesture）。
  if (!pkgTest.includes('mouse-gesture.test.swift')) {
    problems.push('tests/package.test.mjs 未驱动 mouse-gesture.test.swift');
  }
}

for (const f of swiftFiles) checkSwift(f);
checkCommonHygiene();

if (problems.length > 0) {
  console.error(`lint failed — ${problems.length} problem(s)`);
  for (const p of problems) console.error(`  - ${p}`);
  process.exit(1);
}
console.log(`lint ok — ${checked} Swift file(s), 0 problems`);