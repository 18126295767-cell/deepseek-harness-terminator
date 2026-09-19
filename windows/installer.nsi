Unicode true
SetCompressor /SOLID lzma

!ifndef VERSION
  !define VERSION "0.1.1"
!endif
!ifndef STAGE_DIR
  !error "STAGE_DIR is required"
!endif
!ifndef OUT_FILE
  !error "OUT_FILE is required"
!endif

Name "DeepSeek Harness Terminator Windows Launcher"
OutFile "${OUT_FILE}"
InstallDir "$LOCALAPPDATA\DeepSeek Harness Terminator"
InstallDirRegKey HKCU "Software\DeepSeek Harness Terminator" "InstallDir"
RequestExecutionLevel user
ShowInstDetails show
ShowUninstDetails show

VIProductVersion "${VERSION}.0"
VIAddVersionKey /LANG=1033 "ProductName" "DeepSeek Harness Terminator Windows Launcher"
VIAddVersionKey /LANG=1033 "FileDescription" "DeepSeek Harness Terminator Windows Launcher"
VIAddVersionKey /LANG=1033 "FileVersion" "${VERSION}"
VIAddVersionKey /LANG=1033 "ProductVersion" "${VERSION}"

Page directory
Page instfiles
UninstPage uninstConfirm
UninstPage instfiles

Section "DeepSeek Harness Terminator Windows Launcher"
  SetOutPath "$INSTDIR"
  File /r "${STAGE_DIR}\*"
  WriteRegStr HKCU "Software\DeepSeek Harness Terminator" "InstallDir" "$INSTDIR"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  CreateDirectory "$SMPROGRAMS\DeepSeek Harness Terminator"
  CreateShortcut "$SMPROGRAMS\DeepSeek Harness Terminator\DeepSeek Harness Terminator.lnk" "$INSTDIR\launch-dsh.cmd"
SectionEnd

Section "Uninstall"
  Delete "$SMPROGRAMS\DeepSeek Harness Terminator\DeepSeek Harness Terminator.lnk"
  RMDir "$SMPROGRAMS\DeepSeek Harness Terminator"
  RMDir /r "$INSTDIR"
  DeleteRegKey HKCU "Software\DeepSeek Harness Terminator"
SectionEnd
