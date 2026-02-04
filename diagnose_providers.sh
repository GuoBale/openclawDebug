#!/bin/bash
# OpenClaw 模型提供者诊断脚本
# 用于诊断 rate_limit 和 cooldown 问题

echo "🔍 OpenClaw 模型提供者诊断工具"
echo "=================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. 检查配置文件位置
echo "1️⃣ 查找配置文件..."
CONFIG_PATHS=(
    "$HOME/.config/openclaw/config.json"
    "$HOME/.openclaw/config.json"
    "$HOME/.config/openclaw/config.yaml"
    "$HOME/.openclaw/config.yaml"
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
    echo -e "${YELLOW}⚠️  未找到配置文件，尝试使用 openclaw 命令查找...${NC}"
    if command -v openclaw &> /dev/null; then
        openclaw config path 2>/dev/null || echo "无法获取配置路径"
    fi
else
    echo ""
    echo "2️⃣ 检查提供者配置..."
    
    # 检查 minimax 配置
    if command -v jq &> /dev/null; then
        echo ""
        echo "📋 Minimax 配置:"
        jq '.providers.minimax // "未配置"' "$CONFIG_FILE" 2>/dev/null || echo "无法解析 JSON"
        
        echo ""
        echo "📋 Kimi-coding 配置:"
        jq '.providers["kimi-coding"] // "未配置"' "$CONFIG_FILE" 2>/dev/null || echo "无法解析 JSON"
        
        echo ""
        echo "📋 Profiles 配置:"
        jq '.profiles // "未配置"' "$CONFIG_FILE" 2>/dev/null || echo "无法解析 JSON"
    else
        echo -e "${YELLOW}⚠️  未安装 jq，无法解析 JSON 配置${NC}"
        echo "安装 jq: pkg install jq (Termux) 或 brew install jq (macOS)"
        echo ""
        echo "配置文件内容（前 50 行）:"
        head -50 "$CONFIG_FILE"
    fi
fi

echo ""
echo "3️⃣ 检查 OpenClaw 命令可用性..."
if command -v openclaw &> /dev/null; then
    echo -e "${GREEN}✅ openclaw 命令可用${NC}"
    
    echo ""
    echo "4️⃣ 检查提供者状态..."
    echo "运行: openclaw providers list"
    openclaw providers list 2>&1 | head -20 || echo "命令执行失败"
    
    echo ""
    echo "5️⃣ 检查 Profiles 状态..."
    echo "运行: openclaw profiles list"
    openclaw profiles list 2>&1 | head -20 || echo "命令执行失败"
else
    echo -e "${RED}❌ openclaw 命令不可用${NC}"
    echo "请确保 OpenClaw 已正确安装"
fi

echo ""
echo "6️⃣ 检查网络连接..."
echo "测试 API 端点连接性..."

# 测试 minimax API
if command -v curl &> /dev/null; then
    echo -n "Minimax API: "
    curl -s -o /dev/null -w "%{http_code}" --max-time 5 https://api.minimax.chat 2>/dev/null && echo " ✅" || echo " ❌"
    
    echo -n "Kimi API: "
    curl -s -o /dev/null -w "%{http_code}" --max-time 5 https://api.moonshot.cn 2>/dev/null && echo " ✅" || echo " ❌"
else
    echo -e "${YELLOW}⚠️  curl 不可用，跳过网络测试${NC}"
fi

echo ""
echo "=================================="
echo "💡 建议："
echo "1. 检查配置文件中的 rate_limit 设置"
echo "2. 确认 API keys 正确配置且有效"
echo "3. 检查 profiles 配置是否正确"
echo "4. 如果问题持续，尝试重启 gateway: kill_gateway.sh && openclaw gateway run"
echo ""
