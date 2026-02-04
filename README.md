# OpenClaw Android Debug

这个仓库用于调试和修复 OpenClaw 在 Android/Termux 环境下的兼容性问题。

## 问题描述

在 Android 设备（通过 SSH 连接）上运行 OpenClaw 时遇到以下错误：

```
Error: Gateway service install not supported on android
    at resolveGatewayService (file:///data/data/com.termux/files/usr/lib/node_modules/openclaw/dist/service-BoDHq_LN.js:676:8)
    at runDaemonStop (file:///data/data/com.termux/files/usr/lib/node_modules/openclaw/dist/daemon-cli-r9AWdqxf.js:272:18)
```

## 环境信息

- **设备**: Android (Termux)
- **SSH 连接**: `u0_a31@192.168.43.6 -p 8022`
- **OpenClaw 版本**: 2026.2.2-3 (9c5941b)
- **错误位置**: `/data/data/com.termux/files/usr/lib/node_modules/openclaw/dist/service-BoDHq_LN.js:676`

## 问题分析

OpenClaw 尝试安装/配置网关服务时，检测到 Android 平台并抛出错误。需要修改代码以在 Android 环境下优雅处理，而不是直接抛出错误。

## 解决方案

待补充修复方案和补丁文件。
