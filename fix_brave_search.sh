#!/bin/bash
# OpenClaw Brave Search 配置修复脚本
# 修复 "Unrecognized key: braveSearch" 错误并正确配置 Brave Search

echo "🔍 OpenClaw Brave Search 配置工具"
echo "=================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# API Key
BRAVE_API_KEY="BSAGA7HtkxoBGCYBzPFEHXwqZ4E4ABo"

# 1. 查找配置文件（包括 openclaw.json）
echo "1️⃣ 查找配置文件..."
CONFIG_PATHS=(
    "$HOME/.openclaw/openclaw.json"
    "$HOME/.config/openclaw/openclaw.json"
    "$HOME/.openclaw/config.json"
    "$HOME/.config/openclaw/config.json"
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
    echo -e "${YELLOW}⚠️  未找到配置文件，将创建新配置${NC}"
    CONFIG_FILE="$HOME/.openclaw/openclaw.json"
    mkdir -p "$(dirname "$CONFIG_FILE")"
    echo "{}" > "$CONFIG_FILE"
    echo -e "${GREEN}✅ 已创建配置文件: $CONFIG_FILE${NC}"
fi

echo ""

# 2. 检查当前配置
echo "2️⃣ 检查当前配置..."
if command -v jq &> /dev/null; then
    # 检查是否有错误的配置
    BRAVE_SEARCH_CONFIG=$(jq '.tools.braveSearch // empty' "$CONFIG_FILE" 2>/dev/null)
    if [ -n "$BRAVE_SEARCH_CONFIG" ] && [ "$BRAVE_SEARCH_CONFIG" != "null" ]; then
        echo -e "${YELLOW}⚠️  发现错误的配置: tools.braveSearch${NC}"
        echo "$BRAVE_SEARCH_CONFIG" | jq '.'
    fi
    
    # 检查 tools 配置
    echo ""
    echo "📋 当前 tools 配置:"
    TOOLS_CONFIG=$(jq '.tools // empty' "$CONFIG_FILE" 2>/dev/null)
    if [ -n "$TOOLS_CONFIG" ] && [ "$TOOLS_CONFIG" != "null" ]; then
        echo "$TOOLS_CONFIG" | jq '.'
    else
        echo "  无 tools 配置"
    fi
else
    echo -e "${YELLOW}⚠️  未安装 jq，无法解析 JSON 配置${NC}"
    echo "安装 jq: pkg install jq (Termux) 或 brew install jq (macOS)"
    echo ""
    echo "配置文件内容:"
    cat "$CONFIG_FILE" | head -50
fi

echo ""
echo "=================================="
echo "3️⃣ 修复配置"
echo "=================================="
echo ""

if command -v jq &> /dev/null; then
    # 创建临时文件
    TEMP_FILE=$(mktemp)
    
    # 移除错误的 tools.braveSearch 配置
    echo "🔧 移除错误的配置: tools.braveSearch"
    jq 'del(.tools.braveSearch)' "$CONFIG_FILE" > "$TEMP_FILE" 2>/dev/null
    if [ $? -eq 0 ]; then
        mv "$TEMP_FILE" "$CONFIG_FILE"
        echo -e "${GREEN}✅ 已移除错误的配置${NC}"
    else
        echo -e "${YELLOW}⚠️  无法移除配置（可能不存在）${NC}"
        rm -f "$TEMP_FILE"
    fi
    
    # 正确配置 Brave Search
    # 根据 OpenClaw 的配置格式，Brave Search 应该配置在 tools.web.search.apiKey
    
    echo ""
    echo "🔧 配置 Brave Search API Key..."
    
    # 确保 tools.web.search 结构存在
    TEMP_FILE=$(mktemp)
    jq '.tools = (.tools // {}) | .tools.web = (.tools.web // {}) | .tools.web.search = (.tools.web.search // {}) | .tools.web.search.apiKey = "'"$BRAVE_API_KEY"'"' "$CONFIG_FILE" > "$TEMP_FILE" 2>/dev/null
    if [ $? -eq 0 ]; then
        mv "$TEMP_FILE" "$CONFIG_FILE"
        echo -e "${GREEN}✅ 已配置 tools.web.search.apiKey${NC}"
    else
        echo -e "${RED}❌ 配置失败，请手动编辑配置文件${NC}"
        rm -f "$TEMP_FILE"
    fi
    
    # 显示最终配置
    echo ""
    echo "📋 最终配置:"
    echo "tools.web.search:"
    jq '.tools.web.search // "未配置"' "$CONFIG_FILE" 2>/dev/null
    
else
    echo -e "${RED}❌ 需要 jq 工具来修复配置${NC}"
    echo "请安装 jq 或手动编辑配置文件: $CONFIG_FILE"
    echo ""
    echo "需要执行的操作:"
    echo "1. 移除: tools.braveSearch"
    echo "2. 添加: tools.web.search.apiKey = \"$BRAVE_API_KEY\""
    echo ""
    echo "配置示例:"
    echo "{"
    echo "  \"tools\": {"
    echo "    \"web\": {"
    echo "      \"search\": {"
    echo "        \"apiKey\": \"$BRAVE_API_KEY\""
    echo "      }"
    echo "    }"
    echo "  }"
    echo "}"
fi

echo ""
echo "=================================="
echo "💡 下一步:"
echo "1. 如果配置成功，请重启 Gateway:"
echo "   ./kill_gateway.sh && ./start_gateway.sh"
echo "2. 或者使用 OpenClaw 配置命令（推荐）:"
echo "   openclaw-cn configure --section web"
echo "   然后输入 API Key: $BRAVE_API_KEY"
echo "3. 查看 Gateway 日志确认配置:"
echo "   openclaw gateway logs --tail 50"
echo ""
echo "💡 提示: 如果仍有错误，可以运行:"
echo "   openclaw doctor --fix"
echo "   这会自动修复配置问题"
echo ""
