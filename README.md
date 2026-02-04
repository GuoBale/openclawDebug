# OpenClaw Android Debug

这个仓库用于调试和修复 OpenClaw 在 Android/Termux 环境下的兼容性问题。

## 快速开始

### 可用脚本

1. **`start_gateway.sh`** - 启动 Gateway（自动关闭占用端口）
   ```bash
   ./start_gateway.sh [PORT] [BIND_ADDRESS]
   # 示例: ./start_gateway.sh 18789 loopback
   ```

2. **`kill_gateway.sh`** - 停止 Gateway
   ```bash
   ./kill_gateway.sh [PORT]
   # 示例: ./kill_gateway.sh 18789
   ```

3. **`diagnose_providers.sh`** - 诊断模型提供者问题
   ```bash
   ./diagnose_providers.sh
   ```

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

### 1. 主要错误

从终端输出（第 60-66 行）可以看到核心错误：

```
Error: Gateway service install not supported on android
    at resolveGatewayService (file:///data/data/com.termux/files/usr/lib/node_modules/openclaw/dist/service-BoDHq_LN.js:676:8)
    at maybeExplainGatewayServiceStop (file:///data/data/com.termux/files/usr/lib/node_modules/openclaw/dist/shared-D42-KbPa.js:61:18)
    at runGatewayCommand$1 (file:///data/data/com.termux/files/usr/lib/node_modules/openclaw/dist/gateway-cli-CvZ1b_8x.js:16146:10)
```

**问题根源**：OpenClaw 尝试使用系统服务管理机制（如 systemd）来管理网关，但 Android/Termux 环境不支持这种服务安装方式。

### 2. 次要问题

#### 2.1 网关已运行但无法停止
- **现象**（第 55-59, 218-227 行）：
  - Gateway 已经在运行（pid 21348 或 6300）
  - 端口 18789 可能被占用，也可能未被占用
  - OpenClaw 使用锁文件机制，即使端口未被占用也会检测到已有实例
  - 错误信息：`Gateway failed to start: gateway already running (pid XXX); lock timeout after 5000ms`
  - 尝试停止时触发服务管理错误：`Gateway service install not supported on android`

#### 2.2 插件配置警告
- **现象**（第 25-28, 34, 44, 54 行）：
  - 重复的 feishu 插件 ID 警告
  - 警告信息：`plugin feishu: duplicate plugin id detected; later plugin may be overridden`
  - 位置：`/data/data/com.termux/files/usr/lib/node_modules/openclaw/extensions/feishu/index.ts`

#### 2.3 命令未找到错误
- **现象**（第 29-32 行）：
  - `[plugins]: command not found` 错误（可能是 shell 配置问题）

#### 2.4 模型提供者速率限制问题 ⚠️ 新发现
- **现象**（第 144 行）：
  ```
  Embedded agent failed before reply: All models failed (2): 
  minimax/MiniMax-M2.1: Provider minimax is in cooldown (all profiles unavailable) (rate_limit) 
  kimi-coding/k2p5: Provider kimi-coding is in cooldown (all profiles unavailable) (rate_limit)
  ```
- **问题分析**：
  - 虽然模型额度充足，但提供者处于 cooldown 状态
  - 所有 profiles 显示为 unavailable
  - 错误类型为 `rate_limit`（速率限制），而非额度不足
  - 可能原因：
    1. 速率限制配置过于严格
    2. 提供者配置文件中的 `rate_limit` 或 `cooldown` 设置问题
    3. Profiles 配置错误导致无法使用
    4. 短时间内请求过多触发临时限制

### 3. 错误调用链分析

```
runGatewayCommand$1 (gateway-cli-CvZ1b_8x.js:16146)
  └─> maybeExplainGatewayServiceStop (shared-D42-KbPa.js:61)
      └─> resolveGatewayService (service-BoDHq_LN.js:676) ❌ 抛出错误
```

当检测到 Android 平台时，`resolveGatewayService` 函数直接抛出错误，而不是提供替代方案（如直接 kill 进程）。

## 解决方案

### 方案 1: 修改服务检测逻辑（推荐）

在 `service-BoDHq_LN.js:676` 处，当检测到 Android 平台时：
- 不抛出错误
- 返回一个 Android 兼容的服务管理器
- 使用 `kill` 命令直接管理进程，而不是系统服务

### 方案 2: 临时解决方案

#### 2.1 使用启动脚本（推荐）✨

**自动关闭占用端口并启动 Gateway**：

```bash
# 使用默认端口 18789 和 loopback 绑定
./start_gateway.sh

# 指定端口
./start_gateway.sh 18789

# 指定端口和绑定地址
./start_gateway.sh 18789 loopback
```

脚本功能：
- ✅ 自动检测并关闭所有 OpenClaw 相关进程（不仅仅是端口）
- ✅ 清理锁文件（解决 "gateway already running" 错误）
- ✅ 验证端口已释放
- ✅ 启动 OpenClaw Gateway
- ✅ 支持多种进程查找方法（lsof/netstat/ps）
- ✅ 智能处理进程终止（先正常终止，失败则强制终止）

#### 2.2 手动管理网关进程

```bash
# 查找网关进程
ps aux | grep openclaw-gateway

# 直接 kill 进程（替代 openclaw gateway stop）
kill 21348

# 或者使用端口查找并 kill
lsof -ti:18789 | xargs kill

# 使用提供的停止脚本
./kill_gateway.sh [PORT]
```

### 方案 3: 修复插件重复问题

检查并修复 feishu 插件的重复注册问题，避免配置警告。

### 方案 4: 解决模型提供者速率限制问题

#### 4.1 检查配置文件

在 Android 设备上检查 OpenClaw 配置文件：

```bash
# 查找配置文件位置
openclaw config path
# 或
cat ~/.config/openclaw/config.json
# 或
cat ~/.openclaw/config.json
```

检查以下配置项：
- `providers.minimax.rate_limit`
- `providers.kimi-coding.rate_limit`
- `profiles` 配置是否正确
- `cooldown` 相关设置

#### 4.2 诊断步骤

**快速诊断**（使用提供的脚本）：
```bash
# 在 Android 设备上运行诊断脚本
./diagnose_providers.sh
```

**手动诊断**：
```bash
# 1. 检查提供者状态
openclaw providers list

# 2. 检查 profiles 配置
openclaw profiles list

# 3. 查看详细错误日志
openclaw gateway logs --tail 100

# 4. 检查配置文件
openclaw config path
cat $(openclaw config path)
```

#### 4.3 可能的修复方法

1. **调整速率限制配置**：
   - 增加 `rate_limit` 的值
   - 或暂时禁用速率限制进行测试

2. **检查 API Key 配置**：
   - 确认 minimax 和 kimi-coding 的 API keys 正确配置
   - 验证 keys 是否有效且有足够权限

3. **重置 cooldown 状态**：
   - 重启 gateway 服务
   - 清除可能的缓存或状态文件

4. **检查网络连接**：
   - 确认 Android 设备可以正常访问 API 服务
   - 检查是否有防火墙或代理问题

## 待办事项

- [ ] 分析 `service-BoDHq_LN.js` 源码，定位 Android 检测逻辑
- [ ] 实现 Android 兼容的服务管理方案
- [ ] 修复 feishu 插件重复注册问题
- [ ] **诊断模型提供者速率限制问题**（优先级：高）
  - [ ] 检查 OpenClaw 配置文件中的 rate_limit 设置
  - [ ] 验证 minimax 和 kimi-coding 的 API keys 配置
  - [ ] 检查 profiles 配置是否正确
  - [ ] 测试调整速率限制后的效果
- [ ] 测试修复后的功能
