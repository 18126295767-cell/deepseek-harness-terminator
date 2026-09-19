# مشغل DeepSeek Harness لنظام Windows

<div dir="rtl">

**اللغة:** [简体中文](README.zh-CN.md) · [English](README.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt-BR.md) · [Русский](README.ru.md) · العربية · [हिन्दी](README.hi.md) · [繁體中文](README.zh-TW.md)

هذا مشغل مجتمعي يبدأ runtime الويب الرسمي `@deepseek-ai/dsh` ويفتح `http://127.0.0.1:<port>` في المتصفح الافتراضي. ليس تطبيق سطح مكتب رسميًا من DeepSeek AI، ولا يحتوي على runtime أو مفاتيح API أو profiles أو جلسات أو إضافة `dsh-mac-control` الخاصة بـ macOS.

## المتطلبات

- Windows 10/11 x64
- يُفضل Node.js 22 LTS أو 20 فأحدث
- PowerShell 5.1 أو 7
- DSH runtime محلي يحتوي `node_modules\@deepseek-ai\dsh\lib\bin.js`

## إعداد runtime الرسمي

</div>

```powershell
New-Item -ItemType Directory -Force "$HOME\dsh-runtime" | Out-Null
Set-Location "$HOME\dsh-runtime"
npm init -y
npm install --save-exact @deepseek-ai/dsh@0.1.0-rc.7
node node_modules\@deepseek-ai\dsh\lib\bin.js web --port 3080
```

<div dir="rtl">

لإعداد Git وNode.js LTS وNSIS أيضًا عبر `winget`، نفّذ من جذر المستودع. لا يضبط السكربت أي بيانات اعتماد.

</div>

```powershell
Set-Location windows
& .\bootstrap-build-environment.ps1
```

<div dir="rtl">

## التثبيت والتشغيل

شغّل `.\install.ps1` من ZIP بعد فكه أو استخدم مثبت NSIS من GitHub Release. لا تلزم صلاحيات المسؤول. المثبت الحالي غير موقّع؛ قارن SHA-256 المنشور قبل التشغيل.

</div>

```powershell
& "$env:LOCALAPPDATA\DeepSeek Harness Terminator\launch-dsh.ps1" -DshRuntime "$HOME\dsh-runtime" -Port 3080
```

<div dir="rtl">

يرفض المشغل المنفذ المشغول، ويفتح المتصفح عند جاهزية الخدمة، ويكتب السجلات في `%LOCALAPPDATA%\DeepSeek Harness Terminator\logs`. استخدم `-NoBrowser` لعدم فتح المتصفح.

## البناء والتحقق

</div>

```powershell
Set-Location windows
& .\build-release.ps1 -Version 0.1.1
Get-FileHash .\releases\DeepSeek-Harness-Setup-v0.1.1-x64.exe -Algorithm SHA256
Get-Content .\releases\DeepSeek-Harness-Windows-x64-v0.1.1.sha256
```

<div dir="rtl">

يشغّل CI على `windows-2025` الـ runtime الرسمي فعليًا، ويشترط HTTP 200 و`window.__DSH_BOOT__`، ثم يتحقق من ZIP وNSIS وأدلة اللغات الـ 12 وSHA-256. وظائف Automation/Accessibility الخاصة بـ macOS غير متاحة في Windows.

## إلغاء التثبيت

</div>

```powershell
& "$env:LOCALAPPDATA\DeepSeek Harness Terminator\uninstall.ps1"
```

<div dir="rtl">

يبقى DSH runtime وprofiles بدون حذف.

</div>

<div dir="rtl">

## فحص سلامة profile

قبل تشغيل DSH يقارن المشغّل profile المختار مع runtime الفعلي، ويمنع وجود نسخة مادية ثانية من حزم المضيف `@deepseek-ai/dsh-*`. يحدد التقرير الحزمة والإضافة التي جلبتها، لكنه لا يحذف أي ملف. بعد إصلاح الإضافة أعد إرسال المهمة في جلسة جديدة، لأن الجلسة القديمة قد تحتوي رسالة `tool_calls` غير مكتملة.

</div>
