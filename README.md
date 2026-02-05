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

4. **`check_python_deps.sh`** - 检查并安装 Python 依赖
   ```bash
   ./check_python_deps.sh
   ```

5. **`check_node_deps.sh`** - 检查并安装 Node.js 依赖
   ```bash
   ./check_node_deps.sh
   ```

6. **`fix_feishu_zod.sh`** - 修复 feishu 扩展的 zod 依赖问题
   ```bash
   ./fix_feishu_zod.sh
   ```

7. **`fix_duplicate_plugin.sh`** - 修复重复插件 ID 警告
   ```bash
   ./fix_duplicate_plugin.sh
   ```

8. **`fix_api_keys.sh`** - 检查和修复 API Key 配置问题 ⭐ 新增
   ```bash
   ./fix_api_keys.sh
   ```
   用于诊断和修复 "invalid api key" 认证错误

9. **`fix_brave_search.sh`** - 修复 Brave Search 配置问题 ⭐ 新增
   ```bash
   ./fix_brave_search.sh
   ```
   用于修复 "Unrecognized key: braveSearch" 错误并正确配置 Brave Search

10. **`fix_python_interpreter.sh`** - 诊断和修复 Python 解释器问题 ⭐ 新增
    ```bash
    ./fix_python_interpreter.sh
    ```
    用于解决 "No interpreter found for Python >=3.13" 和 `/bin/which: cannot execute` 错误

11. **`fix_homeassistant.sh`** - 修复 Home Assistant 配置问题 ⭐ 新增
    ```bash
    ./fix_homeassistant.sh [URL] [TOKEN]
    # 示例: ./fix_homeassistant.sh http://192.168.43.10:8123 eyJhbGci...
    ```
    用于修复 "unknown channel id: homeassistant" 错误并正确配置 Home Assistant

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

#### 2.4 Node.js 依赖缺失问题 ⚠️ 新发现
- **现象**（第 995-1014 行）：
  ```
  [plugins] feishu failed to load: Error: Cannot find module 'zod'
  Require stack:
  - /data/data/com.termux/files/home/.openclaw/extensions/feishu/src/config-schema.ts
  ```
- **问题分析**：
  - feishu 插件需要 `zod` 模块（TypeScript 验证库）
  - 错误发生在加载用户自定义的 feishu 扩展时
  - 扩展位置：`~/.openclaw/extensions/feishu/`
  - **关键问题**：即使全局安装了 `zod`，扩展仍无法找到它
  - **原因**：Node.js 模块解析机制优先查找本地 `node_modules`，扩展在 `~/.openclaw/extensions/feishu` 目录中时，会在该目录的 `node_modules` 中查找，而不是全局 `node_modules`
  - 全局安装的 feishu 插件正常，但用户扩展缺少本地依赖
- **影响**：
  - 用户自定义的 feishu 扩展无法加载（第 268 行）
  - Gateway 仍能正常启动，但 feishu 功能受限

#### 2.5 进程无法完全停止问题 ⚠️ 新发现
- **现象**（第 979 行）：
  ```
  ❌ 仍有进程无法停止: 1354 7197 11067
  ```
- **问题分析**：
  - 部分 OpenClaw 进程无法通过 kill/kill -9 停止
  - 可能是僵尸进程（Zombie）或系统进程
  - 这些进程可能不影响新实例启动
- **影响**：
  - 启动脚本会显示警告，但 Gateway 仍能成功启动（第 1019 行）

#### 2.6 Python 依赖缺失问题 ⚠️ 新发现
- **现象**（第 993-1006 行）：
  ```
  [tools] exec failed: Generating QR code for Xiaomi login...
  ModuleNotFoundError: No module named 'PIL'
  ```
- **问题分析**：
  - OpenClaw 的 mijia 技能需要生成二维码
  - 脚本位于：`~/.openclaw/workspace/skills/mijia/scripts/generate_qr.py`
  - 缺少 Python 的 PIL 模块（Pillow 包）
  - 错误发生在 `qrcode` 库尝试导入 PIL 时
- **影响**：
  - 无法使用 mijia 相关功能（如小米登录二维码生成）

#### 2.7 模型提供者速率限制问题 ⚠️ 新发现
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

#### 2.8 API Key 认证错误问题 ⚠️ 新发现
- **现象**：
  ```
  [diagnostic] lane task error: lane=main durationMs=3401 error="FailoverError: HTTP 401 authentication_error: invalid api key (request_id: ...)"
  [diagnostic] lane task error: lane=session:agent:main:main durationMs=3445 error="FailoverError: HTTP 401 authentication_error: invalid api key (request_id: ...)"
  ```
- **问题分析**：
  - Gateway 启动成功，但在调用模型 API 时返回 401 认证错误
  - 错误信息：`HTTP 401 authentication_error: invalid api key`
  - 通常发生在使用 minimax 或其他模型提供者时
  - 可能原因：
    1. API Key 未配置或配置错误
    2. API Key 已过期或无效
    3. API Key 配置在错误的配置文件中
    4. 配置文件格式错误（JSON 语法错误）
    5. 环境变量覆盖了配置文件中的设置
- **影响**：
  - Gateway 可以启动，但无法处理任何需要调用模型的任务
  - 所有 agent 任务都会失败

#### 2.9 Brave Search 配置错误问题 ⚠️ 新发现
- **现象**：
  ```
  Invalid config at ~/.openclaw/openclaw.json:
  - tools: Unrecognized key: "braveSearch"
  
  Config invalid
  Problem:
    - tools: Unrecognized key: "braveSearch"
  ```
- **问题分析**：
  - 用户尝试在 `tools.braveSearch` 下配置 Brave Search API Key
  - OpenClaw 不识别 `braveSearch` 这个键
  - 正确的配置路径应该是 `tools.web.search.apiKey`
  - 配置文件位置：`~/.openclaw/openclaw.json`（注意是 openclaw.json，不是 config.json）
- **影响**：
  - Gateway 无法启动
  - 配置验证失败，导致启动被阻止

#### 2.10 Python 解释器检测问题 ⚠️ 新发现
- **现象**：
  ```
  [tools] exec failed: error: No interpreter found for Python >=3.13 in managed installations or search path
  [tools] exec failed: Python 3.12.12
  /data/data/com.termux/files/usr/bin/bash: line 1: /bin/which: cannot execute: required file not found
  ```
- **问题分析**：
  - OpenClaw 工具系统尝试检测 Python 解释器时失败
  - 错误信息显示需要 Python >= 3.13，但系统只有 Python 3.12.12
  - `/bin/which` 命令在 Termux 环境中不存在或无法执行
  - 工具系统可能使用了不兼容的命令来查找 Python 解释器
  - 可能原因：
    1. Termux 环境中 `/bin/which` 不存在（需要使用 `command -v` 或 `whereis`）
    2. Python 版本检测逻辑过于严格（要求 >= 3.13）
    3. 环境变量 PATH 配置不正确
    4. Python 解释器路径未正确设置
- **影响**：
  - 所有需要 Python 的工具都无法执行
  - 技能脚本（如 mijia 的二维码生成）无法运行
  - 工具调用失败，导致功能受限

#### 2.11 Home Assistant 配置错误问题 ⚠️ 新发现
- **现象**：
  ```
  Invalid config at ~/.openclaw/openclaw.json:
  - channels.homeassistant: unknown channel id: homeassistant
  
  Config invalid
  Problem:
    - channels.homeassistant: unknown channel id: homeassistant
  ```
- **问题分析**：
  - 配置文件中存在 `channels.homeassistant` 配置
  - OpenClaw 不识别 `homeassistant` 作为有效的 channel ID
  - 可能原因：
    1. OpenClaw 版本不支持 `homeassistant` channel
    2. 配置位置错误（应该在 `tools` 下而不是 `channels` 下）
    3. Channel ID 名称错误或已更改
    4. 需要安装额外的扩展或插件才能使用 Home Assistant
- **影响**：
  - Gateway 无法启动
  - 配置验证失败，导致启动被阻止
  - Home Assistant 集成功能无法使用

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

#### 3.1 问题说明

OpenClaw 同时加载了全局安装和用户自定义的 feishu 扩展，导致重复插件 ID 警告：
- 全局插件：`/data/data/com.termux/files/usr/lib/node_modules/openclaw/extensions/feishu`
- 用户扩展：`~/.openclaw/extensions/feishu`

#### 3.2 使用修复脚本（推荐）✨

```bash
./fix_duplicate_plugin.sh
```

脚本提供以下选项：
1. **保留用户扩展，禁用全局插件**（推荐，如果用户扩展是自定义的）
   - 重命名全局插件目录为 `.disabled`
   - 只使用用户扩展

2. **保留全局插件，删除/重命名用户扩展**（如果用户扩展只是复制）
   - 重命名用户扩展目录为 `.disabled`
   - 只使用全局插件

3. **重命名用户扩展**（保留两个但避免冲突）
   - 重命名用户扩展目录
   - 需要修改扩展的 ID 才能完全避免冲突

4. **查看详细信息后决定**
   - 显示两个插件的详细信息
   - 帮助做出决策

#### 3.3 手动处理

```bash
# 选项 A: 禁用用户扩展（使用全局插件）
mv ~/.openclaw/extensions/feishu ~/.openclaw/extensions/feishu.disabled

# 选项 B: 禁用全局插件（需要 root 权限，不推荐）
# sudo mv /data/data/com.termux/files/usr/lib/node_modules/openclaw/extensions/feishu \
#         /data/data/com.termux/files/usr/lib/node_modules/openclaw/extensions/feishu.disabled
```

#### 3.4 忽略警告（可选）

- 警告不影响功能，可以忽略
- 后加载的插件会覆盖先加载的
- 如果用户扩展成功加载，它会覆盖全局插件

### 方案 4: 解决 Node.js 依赖缺失问题

#### 4.1 安装缺失的依赖

在 Android/Termux 环境中安装 Node.js 依赖：

```bash
# 方法 1: 使用检查脚本（推荐）✨
./check_node_deps.sh
# 脚本会自动处理 workspace 协议问题

# 方法 2: 全局安装（最简单）
npm install -g zod

# 方法 3: 在扩展目录直接安装依赖
cd ~/.openclaw/extensions/feishu
npm install zod --save
# 注意：如果 package.json 使用 workspace:* 协议，直接安装具体依赖
```

**⚠️ 关于 workspace 协议**：
- 如果扩展的 `package.json` 包含 `workspace:*` 协议，这是 monorepo 的 workspace 依赖
- 在单独安装时，`npm install` 会失败并提示 `Unsupported URL Type "workspace:"`
- **解决方案**：直接安装具体依赖，而不是运行 `npm install`
  ```bash
  cd ~/.openclaw/extensions/feishu
  npm install zod --save  # 直接安装需要的包
  ```

**⚠️ 重要：全局安装 vs 本地安装**：
- 虽然全局安装了 `zod`，但扩展可能仍然无法找到它
- **原因**：Node.js 模块解析优先查找本地 `node_modules`，扩展在 `~/.openclaw/extensions/feishu` 目录中时，会在该目录的 `node_modules` 中查找
- **解决方案**：必须在扩展目录本地安装依赖
  ```bash
  # 方法 1: 使用修复脚本（推荐）✨
  ./fix_feishu_zod.sh
  
  # 方法 2: 手动在扩展目录安装
  cd ~/.openclaw/extensions/feishu
  npm install zod --save
  
  # 方法 3: 从全局安装创建符号链接
  cd ~/.openclaw/extensions/feishu
  mkdir -p node_modules
  ln -s $(npm root -g)/zod node_modules/zod
  ```

#### 4.2 验证安装

```bash
# 测试 zod 模块是否可用
node -e "require('zod'); console.log('zod 安装成功')"

# 检查扩展目录
ls -la ~/.openclaw/extensions/feishu/node_modules/
```

#### 4.3 检查扩展依赖

```bash
# 查看扩展的 package.json
cat ~/.openclaw/extensions/feishu/package.json

# 检查是否使用 workspace 协议
grep -i "workspace" ~/.openclaw/extensions/feishu/package.json

# 如果使用 workspace 协议，直接安装需要的依赖
cd ~/.openclaw/extensions/feishu
npm install zod --save  # 替换为实际需要的包名

# 验证安装
node -e "require('zod'); console.log('zod 可用')"
```

#### 4.4 验证全局安装

全局安装的模块可能无法通过简单的 `require()` 验证，但通常仍可使用：

```bash
# 检查全局 node_modules 路径
npm root -g

# 检查模块是否存在
ls -la $(npm root -g)/zod

# 设置 NODE_PATH 后验证
export NODE_PATH=$(npm root -g):$NODE_PATH
node -e "require('zod'); console.log('zod 可用')"
```

### 方案 5: 解决进程无法停止问题

#### 5.1 问题说明

部分进程无法停止是正常现象：
- 可能是僵尸进程（已终止但父进程未回收）
- 可能是系统进程或受保护进程
- 这些进程通常不影响新实例启动

#### 5.2 处理方式

启动脚本已改进，会：
- 识别可终止和不可终止的进程
- 对不可终止的进程显示警告但不阻止启动
- 继续尝试启动 Gateway

如果 Gateway 启动成功，可以忽略这些警告。

#### 5.3 手动清理（如需要）

```bash
# 查看进程状态
ps aux | grep openclaw

# 查看僵尸进程
ps aux | grep " Z "

# 如果确实需要清理，可以重启 Termux 或 Android 设备
```

### 方案 6: 解决 Python 依赖缺失问题

#### 4.1 安装 Pillow 包

在 Android/Termux 环境中安装 Pillow：

```bash
# 使用 pip 安装 Pillow
pip install Pillow

# 或者使用 pip3
pip3 install Pillow

# 如果使用虚拟环境，先激活虚拟环境
source ~/.openclaw/venv/bin/activate  # 如果存在
pip install Pillow
```

#### 4.2 验证安装

```bash
# 测试 PIL 模块是否可用
python3 -c "from PIL import Image; print('PIL 安装成功')"

# 或者
python -c "from PIL import Image; print('PIL 安装成功')"
```

#### 4.3 检查其他可能缺失的依赖

```bash
# 检查 qrcode 库
python3 -c "import qrcode; print('qrcode 可用')"

# 如果缺失，安装
pip install qrcode[pil]
```

**注意**：`qrcode[pil]` 会同时安装 qrcode 和 Pillow。

### 方案 7: 解决模型提供者速率限制问题

#### 7.1 检查配置文件

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

#### 7.2 诊断步骤

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

#### 7.3 可能的修复方法

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

### 方案 8: 解决 API Key 认证错误问题

#### 8.1 问题说明

当 Gateway 启动后出现 `HTTP 401 authentication_error: invalid api key` 错误时，说明模型提供者的 API Key 配置有问题。

#### 8.2 使用修复脚本（推荐）✨

**快速检查和修复 API Key 配置**：

```bash
# 运行 API Key 配置工具
./fix_api_keys.sh
```

脚本功能：
- ✅ 自动查找 OpenClaw 配置文件
- ✅ 检查当前 API Key 配置状态
- ✅ 交互式设置/更新 Minimax API Key
- ✅ 交互式设置/更新 Kimi-coding API Key
- ✅ 测试 API Key 有效性（如果已配置）
- ✅ 提供配置帮助和示例

#### 8.3 手动检查和修复

**步骤 1: 查找配置文件**

```bash
# 方法 1: 使用 openclaw 命令
openclaw config path

# 方法 2: 检查常见位置
cat ~/.config/openclaw/config.json
# 或
cat ~/.openclaw/config.json
```

**步骤 2: 检查 API Key 配置**

```bash
# 如果安装了 jq
jq '.providers.minimax' ~/.openclaw/config.json
jq '.providers["kimi-coding"]' ~/.openclaw/config.json

# 或者直接查看配置文件
cat ~/.openclaw/config.json | grep -A 5 "minimax"
```

**步骤 3: 设置 API Key**

**方法 A: 使用 openclaw 命令（如果支持）**

```bash
# 检查是否支持配置命令
openclaw config set providers.minimax.api_key "your-api-key"
```

**方法 B: 手动编辑配置文件**

编辑配置文件（通常是 `~/.openclaw/config.json`），添加或修改 `providers` 部分：

```json
{
  "providers": {
    "minimax": {
      "api_key": "your-minimax-api-key-here"
    },
    "kimi-coding": {
      "api_key": "your-kimi-api-key-here"
    }
  }
}
```

**步骤 4: 获取 API Key**

- **Minimax**: https://platform.minimax.chat/
  - 登录后，在控制台创建 API Key
- **Kimi-coding (Moonshot)**: https://platform.moonshot.cn/
  - 登录后，在控制台创建 API Key

**步骤 5: 验证配置**

```bash
# 重启 Gateway
./kill_gateway.sh
./start_gateway.sh

# 查看日志确认是否还有错误
openclaw gateway logs --tail 50
```

#### 8.4 常见问题排查

1. **API Key 已配置但仍报错**
   - 检查 API Key 是否有效（可能已过期）
   - 确认 API Key 格式正确（没有多余空格）
   - 验证 API Key 是否有足够的权限和额度

2. **配置文件格式错误**
   - 使用 JSON 验证工具检查语法：`jq . config.json`
   - 确保 JSON 格式正确（逗号、引号等）

3. **多个配置文件**
   - OpenClaw 可能从多个位置读取配置
   - 使用 `openclaw config path` 确认实际使用的配置文件

4. **环境变量覆盖**
   - 检查是否有环境变量设置了 API Key
   - 例如：`MINIMAX_API_KEY`、`KIMI_API_KEY` 等

### 方案 9: 解决 Brave Search 配置错误问题

#### 9.1 问题说明

当在配置文件中使用错误的键名 `tools.braveSearch` 时，OpenClaw 会报告配置错误并阻止 Gateway 启动。

#### 9.2 使用修复脚本（推荐）✨

**快速修复 Brave Search 配置**：

```bash
# 运行修复脚本（已包含 API Key: BSAGA7HtkxoBGCYBzPFEHXwqZ4E4ABo）
./fix_brave_search.sh
```

脚本功能：
- ✅ 自动查找配置文件（包括 openclaw.json）
- ✅ 移除错误的 `tools.braveSearch` 配置
- ✅ 正确配置 `tools.web.search.apiKey`
- ✅ 显示最终配置状态

#### 9.3 使用 OpenClaw 配置命令（推荐）✨

**使用官方配置命令**：

```bash
# 方法 1: 使用配置向导
openclaw-cn configure --section web
# 然后输入 API Key: BSAGA7HtkxoBGCYBzPFEHXwqZ4E4ABo

# 方法 2: 使用 doctor 命令自动修复
openclaw doctor --fix
```

#### 9.4 手动修复

**步骤 1: 查找配置文件**

```bash
# 配置文件可能是 openclaw.json 而不是 config.json
cat ~/.openclaw/openclaw.json
```

**步骤 2: 移除错误配置并添加正确配置**

如果安装了 `jq`：

```bash
# 移除错误的配置
jq 'del(.tools.braveSearch)' ~/.openclaw/openclaw.json > /tmp/config.json
mv /tmp/config.json ~/.openclaw/openclaw.json

# 添加正确的配置
jq '.tools = (.tools // {}) | .tools.web = (.tools.web // {}) | .tools.web.search = (.tools.web.search // {}) | .tools.web.search.apiKey = "BSAGA7HtkxoBGCYBzPFEHXwqZ4E4ABo"' ~/.openclaw/openclaw.json > /tmp/config.json
mv /tmp/config.json ~/.openclaw/openclaw.json
```

或者手动编辑配置文件：

```json
{
  "tools": {
    "web": {
      "search": {
        "apiKey": "BSAGA7HtkxoBGCYBzPFEHXwqZ4E4ABo"
      }
    }
  }
}
```

**步骤 3: 验证配置**

```bash
# 验证 JSON 格式
jq . ~/.openclaw/openclaw.json

# 重启 Gateway
./kill_gateway.sh && ./start_gateway.sh
```

#### 9.5 配置格式说明

**错误的配置** ❌：
```json
{
  "tools": {
    "braveSearch": {
      "api_key": "BSAGA7HtkxoBGCYBzPFEHXwqZ4E4ABo"
    }
  }
}
```

**正确的配置** ✅：
```json
{
  "tools": {
    "web": {
      "search": {
        "apiKey": "BSAGA7HtkxoBGCYBzPFEHXwqZ4E4ABo"
      }
    }
  }
}
```

**关键点**：
- 配置路径：`tools.web.search.apiKey`（不是 `tools.braveSearch`）
- 键名：`apiKey`（不是 `api_key`）
- 配置文件：`~/.openclaw/openclaw.json`（不是 `config.json`）

### 方案 10: 解决 Python 解释器检测问题

#### 10.1 问题说明

当 OpenClaw 工具系统无法检测到 Python 解释器时，会出现 `No interpreter found for Python >=3.13` 和 `/bin/which: cannot execute` 错误。

#### 10.2 使用修复脚本（推荐）✨

**快速诊断和修复 Python 解释器问题**：

```bash
# 运行诊断脚本
./fix_python_interpreter.sh
```

脚本功能：
- ✅ 自动检测 Termux 环境
- ✅ 使用多种方法查找 Python 解释器（command -v、直接测试、路径查找）
- ✅ 检查 Python 版本和可执行性
- ✅ 诊断 `which` 命令问题
- ✅ 生成环境变量配置脚本
- ✅ 提供详细的修复建议

#### 10.3 手动修复步骤

**步骤 1: 检查 Python 是否安装**

```bash
# 方法 1: 使用 command -v（推荐，兼容性最好）
command -v python3
command -v python

# 方法 2: 直接测试
python3 --version
python --version

# 方法 3: 在 Termux 中查找
ls -la $PREFIX/bin/python*
```

**步骤 2: 修复 which 命令问题**

```bash
# 方法 1: 安装 which 命令（如果可用）
pkg install debianutils

# 方法 2: 使用 command -v 替代 which
alias which='command -v'

# 方法 3: 创建 which 的符号链接（如果系统有但路径不对）
# 通常不需要，command -v 更可靠
```

**步骤 3: 设置环境变量**

```bash
# 查找 Python 路径
PYTHON_CMD=$(command -v python3 || command -v python)
PYTHON_PATH=$PYTHON_CMD

# 设置环境变量
export PYTHON_CMD="$PYTHON_CMD"
export PYTHON_PATH="$PYTHON_PATH"

# 添加到 PATH（如果需要）
export PATH="$(dirname "$PYTHON_PATH"):$PATH"
```

**步骤 4: 永久配置**

将环境变量添加到 shell 配置文件：

```bash
# 对于 bash
echo 'export PYTHON_CMD="$(command -v python3 || command -v python)"' >> ~/.bashrc
echo 'export PYTHON_PATH="$PYTHON_CMD"' >> ~/.bashrc
alias which='command -v' >> ~/.bashrc

# 对于 zsh
echo 'export PYTHON_CMD="$(command -v python3 || command -v python)"' >> ~/.zshrc
echo 'export PYTHON_PATH="$PYTHON_CMD"' >> ~/.zshrc
alias which='command -v' >> ~/.zshrc

# 重新加载配置
source ~/.bashrc  # 或 source ~/.zshrc
```

#### 10.4 使用自动生成的修复脚本

诊断脚本会在 `~/.openclaw/fix_python_env.sh` 生成一个修复脚本：

```bash
# 在运行 OpenClaw 之前执行
source ~/.openclaw/fix_python_env.sh

# 或者添加到 shell 配置文件
echo 'source ~/.openclaw/fix_python_env.sh' >> ~/.bashrc
```

#### 10.5 验证修复

```bash
# 测试 Python 是否可用
$PYTHON_CMD --version

# 测试 Python 基本功能
$PYTHON_CMD -c "import sys; print(sys.version)"

# 测试 which 替代方案
command -v python3

# 检查环境变量
echo "PYTHON_CMD: $PYTHON_CMD"
echo "PYTHON_PATH: $PYTHON_PATH"
```

#### 10.6 常见问题排查

1. **Python 版本不满足要求（需要 >= 3.13）**
   - 检查工具是否真的需要 Python 3.13，或者是否可以降级要求
   - 如果必须使用 Python 3.13，考虑使用 pyenv 安装
   - 在 Termux 中，Python 版本由 pkg 管理，可能需要等待更新

2. **which 命令持续失败**
   - 优先使用 `command -v` 替代 `which`
   - 安装 debianutils 包：`pkg install debianutils`
   - 检查 PATH 环境变量是否正确

3. **Python 路径找不到**
   - 确认 Python 已正确安装：`pkg install python`（Termux）
   - 检查 PATH 是否包含 Python 目录
   - 使用绝对路径：`/data/data/com.termux/files/usr/bin/python3`

4. **环境变量未生效**
   - 确认已重新加载 shell 配置：`source ~/.bashrc`
   - 检查环境变量是否正确设置：`env | grep PYTHON`
   - 在运行 OpenClaw 的同一终端中设置环境变量

### 方案 11: 解决 Home Assistant 配置错误问题

#### 11.1 问题说明

当配置文件中存在 `channels.homeassistant` 配置时，OpenClaw 会报告 `unknown channel id: homeassistant` 错误并阻止 Gateway 启动。

#### 11.2 使用修复脚本（推荐）✨

**快速修复 Home Assistant 配置**：

```bash
# 使用默认配置（脚本中已包含）
./fix_homeassistant.sh

# 或指定自定义 URL 和 Token
./fix_homeassistant.sh http://192.168.43.10:8123 eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

脚本功能：
- ✅ 自动查找配置文件（包括 openclaw.json）
- ✅ 移除错误的 `channels.homeassistant` 配置
- ✅ 可选配置 `tools.homeassistant`（如果支持）
- ✅ 自动备份配置文件
- ✅ 显示最终配置状态

#### 11.3 使用 OpenClaw doctor 命令（推荐）✨

**使用官方 doctor 命令自动修复**：

```bash
# 运行 doctor 自动修复配置问题
openclaw doctor --fix
```

这会自动移除无效的配置项。

#### 11.4 手动修复

**步骤 1: 查找配置文件**

```bash
# 配置文件通常是 openclaw.json
cat ~/.openclaw/openclaw.json
```

**步骤 2: 移除错误的配置**

如果安装了 `jq`：

```bash
# 备份配置文件
cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.backup

# 移除 channels.homeassistant 配置
jq 'del(.channels.homeassistant)' ~/.openclaw/openclaw.json > /tmp/config.json
mv /tmp/config.json ~/.openclaw/openclaw.json
```

或者手动编辑配置文件，移除 `channels.homeassistant` 部分。

**步骤 3: 验证配置**

```bash
# 验证 JSON 格式
jq . ~/.openclaw/openclaw.json

# 检查是否还有 homeassistant 配置
jq '.channels.homeassistant' ~/.openclaw/openclaw.json
# 应该返回 null
```

**步骤 4: 配置 Home Assistant 工具（可选）**

如果 OpenClaw 支持 Home Assistant 工具，可以在 `tools` 下配置：

```json
{
  "tools": {
    "homeassistant": {
      "url": "http://192.168.43.10:8123",
      "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
    }
  }
}
```

使用 `jq` 添加配置：

```bash
jq '.tools = (.tools // {}) | .tools.homeassistant = {
  "url": "http://192.168.43.10:8123",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}' ~/.openclaw/openclaw.json > /tmp/config.json
mv /tmp/config.json ~/.openclaw/openclaw.json
```

#### 11.5 配置格式说明

**错误的配置** ❌：
```json
{
  "channels": {
    "homeassistant": {
      "url": "http://192.168.43.10:8123",
      "token": "..."
    }
  }
}
```

**正确的配置** ✅（如果支持）：
```json
{
  "tools": {
    "homeassistant": {
      "url": "http://192.168.43.10:8123",
      "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
    }
  }
}
```

**关键点**：
- `channels.homeassistant` 是无效的配置，需要移除
- Home Assistant 可能需要在 `tools` 下配置，而不是 `channels`
- 配置文件：`~/.openclaw/openclaw.json`（不是 `config.json`）
- 如果 OpenClaw 版本不支持 Home Assistant，移除配置即可

#### 11.6 验证修复

```bash
# 验证 JSON 格式
jq . ~/.openclaw/openclaw.json

# 运行 doctor 检查配置
openclaw doctor

# 重启 Gateway
./kill_gateway.sh && ./start_gateway.sh

# 查看日志确认没有配置错误
openclaw gateway logs --tail 50
```

#### 11.7 常见问题排查

1. **配置移除后仍有错误**
   - 检查是否有多个配置文件
   - 使用 `openclaw config path` 确认实际使用的配置文件
   - 运行 `openclaw doctor --fix` 自动修复

2. **Home Assistant 功能不可用**
   - 确认 OpenClaw 版本是否支持 Home Assistant
   - 检查是否需要安装额外的扩展或插件
   - 查看 OpenClaw 文档确认正确的配置方式

3. **Token 或 URL 错误**
   - 验证 Home Assistant 地址是否可访问
   - 确认 Token 是否有效且未过期
   - 检查 Token 权限是否足够

## 待办事项

- [ ] 分析 `service-BoDHq_LN.js` 源码，定位 Android 检测逻辑
- [ ] 实现 Android 兼容的服务管理方案
- [ ] 修复 feishu 插件重复注册问题
- [x] **解决 Python 依赖缺失问题**（已完成脚本）
  - [x] 创建依赖检查脚本 `check_python_deps.sh`
  - [ ] 在 Android 设备上测试脚本
  - [ ] 验证 Pillow 安装后 mijia 功能正常
- [ ] **诊断模型提供者速率限制问题**（优先级：高）
  - [ ] 检查 OpenClaw 配置文件中的 rate_limit 设置
  - [ ] 验证 minimax 和 kimi-coding 的 API keys 配置
  - [ ] 检查 profiles 配置是否正确
  - [ ] 测试调整速率限制后的效果
- [x] **解决 API Key 认证错误问题**（已完成脚本）
  - [x] 创建 API Key 配置检查和修复脚本 `fix_api_keys.sh`
  - [ ] 在 Android 设备上测试脚本
  - [ ] 验证 API Key 配置后 Gateway 功能正常
- [x] **解决 Brave Search 配置错误问题**（已完成脚本）
  - [x] 创建 Brave Search 配置修复脚本 `fix_brave_search.sh`
  - [ ] 在 Android 设备上测试脚本
  - [ ] 验证 Brave Search 配置后 Gateway 功能正常
- [x] **解决 Python 解释器检测问题**（已完成脚本）
  - [x] 创建 Python 解释器诊断和修复脚本 `fix_python_interpreter.sh`
  - [ ] 在 Android 设备上测试脚本
  - [ ] 验证 Python 解释器检测修复后工具功能正常
- [x] **解决 Home Assistant 配置错误问题**（已完成脚本）
  - [x] 创建 Home Assistant 配置修复脚本 `fix_homeassistant.sh`
  - [ ] 在 Android 设备上测试脚本
  - [ ] 验证 Home Assistant 配置修复后 Gateway 功能正常
- [ ] 测试修复后的功能
