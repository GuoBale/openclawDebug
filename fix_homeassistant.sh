#!/bin/bash
# OpenClaw Home Assistant 配置修复脚本
# 修复 "unknown channel id: homeassistant" 错误

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}🏠 OpenClaw Home Assistant 配置工具${NC}"
echo "=================================="
echo ""

# Home Assistant 配置（从参数或环境变量获取）
HA_URL="${1:-http://192.168.43.10:8123}"
HA_TOKEN="${2:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJlZmRiYzBiMzVlYTM0NjcwOGU3MmY1OTNkZWQzZDM0MSIsImlhdCI6MTc3MDIxMDMwMywiZXhwIjoyMDg1NTcwMzAzfQ.7kQ5ggqdxBIqRh1acADcycwUlXV2CDZQuM_dPXP_PZ0}"

# 1. 查找配置文件
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
    # 检查是否有错误的 channels.homeassistant 配置
    HA_CHANNEL_CONFIG=$(jq '.channels.homeassistant // empty' "$CONFIG_FILE" 2>/dev/null)
    if [ -n "$HA_CHANNEL_CONFIG" ] && [ "$HA_CHANNEL_CONFIG" != "null" ]; then
        echo -e "${YELLOW}⚠️  发现错误的配置: channels.homeassistant${NC}"
        echo "$HA_CHANNEL_CONFIG" | jq '.'
    else
        echo -e "${GREEN}✅ 未发现 channels.homeassistant 配置${NC}"
    fi
    
    # 检查 channels 配置
    echo ""
    echo "📋 当前 channels 配置:"
    CHANNELS_CONFIG=$(jq '.channels // empty' "$CONFIG_FILE" 2>/dev/null)
    if [ -n "$CHANNELS_CONFIG" ] && [ "$CHANNELS_CONFIG" != "null" ]; then
        echo "$CHANNELS_CONFIG" | jq '.'
    else
        echo "  无 channels 配置"
    fi
    
    # 检查 tools 配置（Home Assistant 可能配置在 tools 下）
    echo ""
    echo "📋 当前 tools 配置:"
    TOOLS_CONFIG=$(jq '.tools // empty' "$CONFIG_FILE" 2>/dev/null)
    if [ -n "$TOOLS_CONFIG" ] && [ "$TOOLS_CONFIG" != "null" ]; then
        # 检查是否有 homeassistant 相关配置
        HA_TOOLS_CONFIG=$(jq '.tools.homeassistant // empty' "$CONFIG_FILE" 2>/dev/null)
        if [ -n "$HA_TOOLS_CONFIG" ] && [ "$HA_TOOLS_CONFIG" != "null" ]; then
            echo -e "${CYAN}💡 发现 tools.homeassistant 配置:${NC}"
            echo "$HA_TOOLS_CONFIG" | jq '.'
        else
            echo "  无 homeassistant 工具配置"
        fi
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
    BACKUP_FILE="${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # 备份配置文件
    cp "$CONFIG_FILE" "$BACKUP_FILE"
    echo -e "${CYAN}💾 已备份配置文件: $BACKUP_FILE${NC}"
    echo ""
    
    # 移除错误的 channels.homeassistant 配置
    echo "🔧 移除错误的配置: channels.homeassistant"
    jq 'del(.channels.homeassistant)' "$CONFIG_FILE" > "$TEMP_FILE" 2>/dev/null
    if [ $? -eq 0 ]; then
        mv "$TEMP_FILE" "$CONFIG_FILE"
        echo -e "${GREEN}✅ 已移除错误的 channels.homeassistant 配置${NC}"
    else
        echo -e "${YELLOW}⚠️  无法移除配置（可能不存在或 JSON 格式错误）${NC}"
        rm -f "$TEMP_FILE"
    fi
    
    # 询问是否要配置 Home Assistant 工具
    echo ""
    echo -e "${CYAN}💡 是否要配置 Home Assistant 工具？${NC}"
    echo "   Home Assistant 地址: $HA_URL"
    echo "   Token: ${HA_TOKEN:0:20}..."
    echo ""
    read -p "配置 Home Assistant 工具? (y/n) " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo "🔧 配置 Home Assistant 工具..."
        
        # 配置 tools.homeassistant
        TEMP_FILE=$(mktemp)
        jq '.tools = (.tools // {}) | .tools.homeassistant = (.tools.homeassistant // {}) | .tools.homeassistant.url = "'"$HA_URL"'" | .tools.homeassistant.token = "'"$HA_TOKEN"'"' "$CONFIG_FILE" > "$TEMP_FILE" 2>/dev/null
        if [ $? -eq 0 ]; then
            mv "$TEMP_FILE" "$CONFIG_FILE"
            echo -e "${GREEN}✅ 已配置 tools.homeassistant${NC}"
            echo "   URL: $HA_URL"
            echo "   Token: ${HA_TOKEN:0:20}..."
        else
            echo -e "${RED}❌ 配置失败，请手动编辑配置文件${NC}"
            rm -f "$TEMP_FILE"
        fi
    else
        echo -e "${CYAN}💡 跳过 Home Assistant 工具配置${NC}"
    fi
    
    # 显示最终配置
    echo ""
    echo "📋 最终配置状态:"
    echo ""
    
    # 检查 channels 配置
    CHANNELS_FINAL=$(jq '.channels // empty' "$CONFIG_FILE" 2>/dev/null)
    if [ -n "$CHANNELS_FINAL" ] && [ "$CHANNELS_FINAL" != "null" ]; then
        echo "channels:"
        echo "$CHANNELS_FINAL" | jq '.'
    else
        echo -e "${GREEN}✅ channels 配置已清理（无错误配置）${NC}"
    fi
    
    # 检查 tools.homeassistant 配置
    HA_TOOLS_FINAL=$(jq '.tools.homeassistant // empty' "$CONFIG_FILE" 2>/dev/null)
    if [ -n "$HA_TOOLS_FINAL" ] && [ "$HA_TOOLS_FINAL" != "null" ]; then
        echo ""
        echo "tools.homeassistant:"
        echo "$HA_TOOLS_FINAL" | jq '.'
    fi
    
else
    echo -e "${RED}❌ 需要 jq 工具来修复配置${NC}"
    echo "请安装 jq 或手动编辑配置文件: $CONFIG_FILE"
    echo ""
    echo "需要执行的操作:"
    echo "1. 移除: channels.homeassistant"
    echo ""
    echo "如果配置了 Home Assistant 工具，确保格式正确:"
    echo "{"
    echo "  \"tools\": {"
    echo "    \"homeassistant\": {"
    echo "      \"url\": \"$HA_URL\","
    echo "      \"token\": \"$HA_TOKEN\""
    echo "    }"
    echo "  }"
    echo "}"
fi

echo ""
echo "=================================="
echo "💡 下一步:"
echo "1. 验证配置格式:"
echo "   jq . $CONFIG_FILE"
echo ""
echo "2. 运行 OpenClaw doctor 自动修复（推荐）:"
echo "   openclaw doctor --fix"
echo ""
echo "3. 重启 Gateway:"
echo "   ./kill_gateway.sh && ./start_gateway.sh"
echo ""
echo "4. 查看 Gateway 日志确认配置:"
echo "   openclaw gateway logs --tail 50"
echo ""
echo "💡 提示:"
echo "- 如果仍有 'unknown channel id' 错误，说明 OpenClaw 版本可能不支持 homeassistant channel"
echo "- Home Assistant 功能可能需要在 tools 下配置，而不是 channels"
echo "- 备份文件保存在: $BACKUP_FILE"
echo ""
