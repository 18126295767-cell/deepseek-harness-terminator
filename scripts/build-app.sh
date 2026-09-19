#!/bin/zsh
set -euo pipefail

usage() {
  print "Usage: $0 --dsh-runtime /absolute/path/to/dsh-runtime [--install] [--output /absolute/path]"
}

runtime=""
install_app=false
output=""
while (( $# > 0 )); do
  case "$1" in
    --dsh-runtime) runtime="${2:-}"; shift 2 ;;
    --install) install_app=true; shift ;;
    --output) output="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) print -u2 "Unknown argument: $1"; usage; exit 2 ;;
  esac
done

[[ -n "$runtime" ]] || { print -u2 "--dsh-runtime is required"; exit 2; }
runtime="${runtime:A}"
if [[ -f "$runtime/node_modules/@deepseek-ai/dsh/lib/bin.js" ]]; then
  dsh_bin="$runtime/node_modules/@deepseek-ai/dsh/lib/bin.js"
elif [[ -f "$runtime/lib/bin.js" ]]; then
  dsh_bin="$runtime/lib/bin.js"
else
  print -u2 "Cannot find @deepseek-ai/dsh/lib/bin.js or lib/bin.js under $runtime"
  exit 1
fi
dsh_bin="${dsh_bin:A}"
node_bin="$(command -v node)"
[[ -x "$node_bin" ]] || { print -u2 "Node.js is required"; exit 1; }

script_dir="${0:A:h}"
if [[ -f "$script_dir/main.swift" ]]; then
  repo="$script_dir"
  source_dir="$script_dir"
  template="$script_dir/com.houxinran.deepseek-harness.plist.template"
else
  repo="$script_dir:h"
  source_dir="$repo/App/DeepSeekHarnessApp"
  template="$repo/packaging/com.houxinran.deepseek-harness.plist.template"
fi
output="${output:-$repo/build}"
output="${output:A}"
app="$output/DeepSeekHarness.app"
contents="$app/Contents"
mkdir -p "$contents/MacOS" "$contents/Resources" "$output/.module-cache"

# 把 clang 的模块缓存定位到工作区本地：可复现、避免系统缓存权限/污染问题。
swiftc -O -whole-module-optimization \
  -Xcc -fmodules-cache-path="$output/.module-cache" \
  -framework AppKit -framework WebKit -framework Speech -framework AVFoundation \
  "$source_dir/main.swift" \
  "$source_dir/BuiltinBrowserAddress.swift" \
  "$source_dir/VoiceInputModel.swift" \
  "$source_dir/VoiceController.swift" \
  "$source_dir/BrowserTabManager.swift" \
  "$source_dir/BrowserSessionStore.swift" \
  "$source_dir/FindInPageModel.swift" \
  "$source_dir/CommandPalette.swift" \
  "$source_dir/PageSummaryModel.swift" \
  "$source_dir/BrowserShortcuts.swift" \
  "$source_dir/TabGroupingModel.swift" \
  "$source_dir/SplitPaneState.swift" \
  "$source_dir/SessionRestoreModel.swift" \
  "$source_dir/PageCaptureModel.swift" \
  "$source_dir/VerticalTabsModel.swift" \
  "$source_dir/UserScriptStore.swift" \
  "$source_dir/MouseGestureModel.swift" \
  -o "$contents/MacOS/DeepSeekHarness"
cp "$source_dir/Info.plist" "$contents/Info.plist"
if [[ "$source_dir/icon-source.svg" != "$output/icon-source.svg" ]]; then
  cp "$source_dir/icon-source.svg" "$output/icon-source.svg"
fi
cp "$repo/scripts/profile-doctor.mjs" "$contents/Resources/profile-doctor.mjs"
if [[ -f "$source_dir/DeepSeekHarness.app/Contents/Resources/DeepSeekHarness.icns" ]]; then
  icon_source="$source_dir/DeepSeekHarness.app/Contents/Resources/DeepSeekHarness.icns"
else
  icon_source="$source_dir/DeepSeekHarness.icns"
fi
if [[ "$icon_source" != "$contents/Resources/DeepSeekHarness.icns" ]]; then
  cp "$icon_source" "$contents/Resources/DeepSeekHarness.icns"
fi

if $install_app; then
  app_dir="$HOME/Applications"
  target_app="$app_dir/DeepSeek Harness Terminator.app"
  mkdir -p "$app_dir"
  ditto "$app" "$target_app"
  launch_agents="$HOME/Library/LaunchAgents"
  logs="$HOME/Library/Logs"
  mkdir -p "$launch_agents" "$logs"
  plist="$launch_agents/com.houxinran.deepseek-harness.plist"
  doctor_script="$target_app/Contents/Resources/profile-doctor.mjs"
  profile_dir="${DSH_HOME:-$HOME/.dsh}/profiles/web"
  sed -e "s|__NODE_BIN__|$node_bin|g" \
      -e "s|__DSH_BIN__|$dsh_bin|g" \
      -e "s|__DOCTOR_SCRIPT__|$doctor_script|g" \
      -e "s|__DSH_RUNTIME__|$runtime|g" \
      -e "s|__PROFILE_DIR__|$profile_dir|g" \
      -e "s|__ERROR_MARKER__|$logs/DeepSeekHarness.profile-error|g" \
      -e "s|__WORKING_DIRECTORY__|$runtime|g" \
      -e "s|__LOG_PATH__|$logs/DeepSeekHarness.log|g" \
      "$template" > "$plist"
  launchctl bootout "gui/$(id -u)/com.houxinran.deepseek-harness" 2>/dev/null || true
  print "Installed: $target_app"
  print "LaunchAgent: $plist"
else
  print "Built: $app"
fi
