#!/bin/bash
# OpenClaw 工具调用错误诊断和修复脚本
# 用于诊断和修复 "tool result's tool id not found (2013)" 错误

echo "🔍 OpenClaw 工具调用错误诊断工具"
echo "=================================="
echo ""
echo "错误信息: LLM request rejected: invalid params, tool result's tool id not found (2013)"
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 1. 检查 Gateway 状态
echo "1️⃣ 检查 Gateway 状态..."
if pgrep -f "openclaw.*gateway" > /dev/null; then
    GATEWAY_PID=$(pgrep -f "openclaw.*gateway" | head -1)
    echo -e "${GREEN}✅ Gateway 正在运行 (PID: $GATEWAY_PID)${NC}"
else
    echo -e "${YELLOW}⚠️  Gateway 未运行${NC}"
    echo "建议: 启动 Gateway 后重试"
    echo "   ./start_gateway.sh"
fi

echo ""

# 2. 检查配置文件
echo "2️⃣ 检查配置文件..."
CONFIG_PATHS=(
    "$HOME/.config/openclaw/config.json"
    "$HOME/.openclaw/config.json"
    "$HOME/.config/openclaw/openclaw.json"
    "$HOME/.openclaw/openclaw.json"
)

CONFIG_FILE=""
for path in "${CONFIG_PATHS[@]}"; do
    if [ -f "$path" ]; then
        CONFIG_FILE="$path"
        echo -e "${GREEN}✅ 找到配置文件: $path${NC}"
        break
    fi
done

if [ -z "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}⚠️  未找到配置文件${NC}"
    if command -v openclaw &> /dev/null; then
        echo "尝试使用 openclaw 命令查找..."
        openclaw config path 2>/dev/null || echo "无法获取配置路径"
    fi
else
    echo ""
    echo "3️⃣ 检查工具配置..."
    
    if command -v jq &> /dev/null; then
        # 检查 tools 配置
        TOOLS_CONFIG=$(jq '.tools // empty' "$CONFIG_FILE" 2>/dev/null)
        if [ -n "$TOOLS_CONFIG" ] && [ "$TOOLS_CONFIG" != "null" ] && [ "$TOOLS_CONFIG" != "{}" ]; then
            echo -e "${GREEN}✅ 找到 tools 配置${NC}"
            echo ""
            echo "📋 当前 tools 配置:"
            echo "$TOOLS_CONFIG" | jq '.' 2>/dev/null || echo "$TOOLS_CONFIG"
        else
            echo -e "${YELLOW}⚠️  未找到 tools 配置${NC}"
        fi
        
        # 检查 providers 配置
        echo ""
        echo "4️⃣ 检查模型提供者配置..."
        PROVIDERS_CONFIG=$(jq '.providers // empty' "$CONFIG_FILE" 2>/dev/null)
        if [ -n "$PROVIDERS_CONFIG" ] && [ "$PROVIDERS_CONFIG" != "null" ] && [ "$PROVIDERS_CONFIG" != "{}" ]; then
            echo -e "${GREEN}✅ 找到 providers 配置${NC}"
            echo ""
            echo "📋 已配置的提供者:"
            echo "$PROVIDERS_CONFIG" | jq 'keys' 2>/dev/null || echo "无法解析"
        else
            echo -e "${YELLOW}⚠️  未找到 providers 配置${NC}"
        fi
        
        # 检查 agent 配置
        echo ""
        echo "5️⃣ 检查 Agent 配置..."
        AGENT_CONFIG=$(jq '.agent // empty' "$CONFIG_FILE" 2>/dev/null)
        if [ -n "$AGENT_CONFIG" ] && [ "$AGENT_CONFIG" != "null" ] && [ "$AGENT_CONFIG" != "{}" ]; then
            echo -e "${GREEN}✅ 找到 agent 配置${NC}"
            echo ""
            echo "📋 Agent 配置:"
            echo "$AGENT_CONFIG" | jq '.' 2>/dev/null || echo "$AGENT_CONFIG"
        else
            echo -e "${YELLOW}⚠️  未找到 agent 配置（使用默认配置）${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  未安装 jq，无法解析 JSON 配置${NC}"
        echo "安装 jq: pkg install jq (Termux) 或 brew install jq (macOS)"
    fi
fi

echo ""
echo "6️⃣ 检查 Gateway 日志..."
if command -v openclaw &> /dev/null; then
    echo "获取最近的错误日志..."
    echo ""
    openclaw gateway logs --tail 50 2>&1 | grep -i -E "(tool|2013|error|rejected|invalid)" | tail -20 || echo "未找到相关错误日志"
else
    echo -e "${YELLOW}⚠️  openclaw 命令不可用${NC}"
fi

echo ""
echo "7️⃣ 检查工具调用相关环境..."
echo "检查 Node.js 版本..."
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version 2>/dev/null)
    echo -e "${GREEN}✅ Node.js: $NODE_VERSION${NC}"
else
    echo -e "${RED}❌ Node.js 未安装${NC}"
fi

echo ""
echo "检查 OpenClaw 版本..."
if command -v openclaw &> /dev/null; then
    OPENCLAW_VERSION=$(openclaw --version 2>/dev/null || echo "无法获取版本")
    echo -e "${GREEN}✅ OpenClaw: $OPENCLAW_VERSION${NC}"
else
    echo -e "${RED}❌ OpenClaw 未安装或不在 PATH 中${NC}"
fi

echo ""
echo "=================================="
echo "🔧 问题分析和修复建议"
echo "=================================="
echo ""
echo "错误原因分析:"
echo "1. 工具调用 ID 不匹配"
echo "   - LLM 返回的工具结果中，工具 ID 与请求时的 ID 不一致"
echo "   - 可能是工具调用系统在处理异步结果时出现问题"
echo ""
echo "2. 工具调用超时或中断"
echo "   - 工具调用过程中 Gateway 重启或连接中断"
echo "   - 工具执行时间过长导致 ID 过期"
echo ""
echo "3. 配置问题"
echo "   - 工具配置不正确导致调用失败"
echo "   - 模型提供者配置问题"
echo ""
echo "修复建议:"
echo ""
echo "1. 重启 Gateway（最常见解决方案）"
echo "   ${BLUE}./kill_gateway.sh && ./start_gateway.sh${NC}"
echo ""
echo "2. 检查并修复工具配置"
if [ -n "$CONFIG_FILE" ]; then
    echo "   配置文件: $CONFIG_FILE"
    echo "   检查 tools 配置是否正确"
    if command -v jq &> /dev/null; then
        echo ""
        echo "   当前 tools 配置:"
        jq '.tools // "未配置"' "$CONFIG_FILE" 2>/dev/null | head -20
    fi
fi
echo ""
echo "3. 检查模型提供者配置"
if [ -n "$CONFIG_FILE" ]; then
    if command -v jq &> /dev/null; then
        echo "   检查 API Key 是否有效:"
        echo "   ${BLUE}./fix_api_keys.sh${NC}"
    fi
fi
echo ""
echo "4. 查看详细日志"
echo "   ${BLUE}openclaw gateway logs --tail 100 | grep -i tool${NC}"
echo ""
echo "5. 检查工具调用超时设置"
if [ -n "$CONFIG_FILE" ] && command -v jq &> /dev/null; then
    TIMEOUT_CONFIG=$(jq '.agent.timeout // .timeout // empty' "$CONFIG_FILE" 2>/dev/null)
    if [ -z "$TIMEOUT_CONFIG" ] || [ "$TIMEOUT_CONFIG" = "null" ]; then
        echo "   ⚠️  未找到超时配置，可能需要添加:"
        echo "   {"
        echo "     \"agent\": {"
        echo "       \"timeout\": 30000"
        echo "     }"
        echo "   }"
    else
        echo "   当前超时配置: $TIMEOUT_CONFIG"
    fi
fi
echo ""
echo "6. 临时解决方案：禁用有问题的工具"
echo "   如果特定工具导致问题，可以临时禁用它"
echo "   编辑配置文件，移除或注释相关工具配置"
echo ""
echo "7. 更新 OpenClaw"
echo "   ${BLUE}npm update -g openclaw${NC}"
echo "   或"
echo "   ${BLUE}npm install -g openclaw@latest${NC}"
echo ""
echo "=================================="
echo "💡 快速修复命令"
echo "=================================="
echo ""
echo "如果问题持续，按顺序执行以下命令:"
echo ""
echo "1. 停止 Gateway:"
echo "   ${BLUE}./kill_gateway.sh${NC}"
echo ""
echo "2. 等待几秒确保进程完全停止"
echo "   ${BLUE}sleep 3${NC}"
echo ""
echo "3. 启动 Gateway:"
echo "   ${BLUE}./start_gateway.sh${NC}"
echo ""
echo "4. 查看日志确认是否还有错误:"
echo "   ${BLUE}openclaw gateway logs --tail 50${NC}"
echo ""
echo "=================================="
echo ""
