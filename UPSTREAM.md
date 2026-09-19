# Upstream and Scope

This repository contains the native AppKit/WebKit macOS shell used to launch
and present a local DeepSeek Harness service as a desktop application.

The upstream runtime is [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness),
an open-source agent harness developed by DeepSeek AI and released under MIT.
The shell connects only to a user-managed local service at `127.0.0.1:3080`.

This repository is an independent community project. It does not claim to be
an official DeepSeek app, and it does not include the upstream runtime or any
third-party plugins. Install the runtime separately, then point the packaging
script at that local installation.
