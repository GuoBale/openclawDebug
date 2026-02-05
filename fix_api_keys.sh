#!/bin/bash
# OpenClaw API Key 配置检查和修复脚本
# 用于诊断和修复 "invalid api key" 错误

echo "🔑 OpenClaw API Key 配置工具"
echo "=================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 1. 查找配置文件
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
    echo -e "${YELLOW}⚠️  未找到配置文件${NC}"
    if command -v openclaw &> /dev/null; then
        echo "尝试使用 openclaw 命令查找配置路径..."
        CONFIG_PATH=$(openclaw config path 2>/dev/null)
        if [ -n "$CONFIG_PATH" ] && [ -f "$CONFIG_PATH" ]; then
            CONFIG_FILE="$CONFIG_PATH"
            echo -e "${GREEN}✅ 找到配置文件: $CONFIG_FILE${NC}"
        fi
    fi
    
    if [ -z "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}⚠️  将创建新配置文件: $HOME/.openclaw/config.json${NC}"
        CONFIG_FILE="$HOME/.openclaw/config.json"
        mkdir -p "$(dirname "$CONFIG_FILE")"
        echo "{}" > "$CONFIG_FILE"
    fi
fi

echo ""

# 2. 检查当前配置
echo "2️⃣ 检查当前 API Key 配置..."
echo ""

if command -v jq &> /dev/null; then
    # 使用 jq 解析 JSON
    echo "📋 Minimax 配置:"
    MINIMAX_CONFIG=$(jq '.providers.minimax // empty' "$CONFIG_FILE" 2>/dev/null)
    if [ -n "$MINIMAX_CONFIG" ] && [ "$MINIMAX_CONFIG" != "null" ]; then
        echo "$MINIMAX_CONFIG" | jq '.'
        MINIMAX_API_KEY=$(echo "$MINIMAX_CONFIG" | jq -r '.api_key // .apiKey // empty' 2>/dev/null)
        if [ -z "$MINIMAX_API_KEY" ] || [ "$MINIMAX_API_KEY" = "null" ]; then
            echo -e "${RED}❌ Minimax API Key 未配置${NC}"
        else
            # 只显示前 8 个字符和后 4 个字符
            MASKED_KEY="${MINIMAX_API_KEY:0:8}...${MINIMAX_API_KEY: -4}"
            echo -e "${GREEN}✅ Minimax API Key 已配置: $MASKED_KEY${NC}"
        fi
    else
        echo -e "${RED}❌ Minimax 提供者未配置${NC}"
    fi
    
    echo ""
    echo "📋 Kimi-coding 配置:"
    KIMI_CONFIG=$(jq '.providers["kimi-coding"] // empty' "$CONFIG_FILE" 2>/dev/null)
    if [ -n "$KIMI_CONFIG" ] && [ "$KIMI_CONFIG" != "null" ]; then
        echo "$KIMI_CONFIG" | jq '.'
        KIMI_API_KEY=$(echo "$KIMI_CONFIG" | jq -r '.api_key // .apiKey // empty' 2>/dev/null)
        if [ -z "$KIMI_API_KEY" ] || [ "$KIMI_API_KEY" = "null" ]; then
            echo -e "${RED}❌ Kimi-coding API Key 未配置${NC}"
        else
            MASKED_KEY="${KIMI_API_KEY:0:8}...${KIMI_API_KEY: -4}"
            echo -e "${GREEN}✅ Kimi-coding API Key 已配置: $MASKED_KEY${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  Kimi-coding 提供者未配置${NC}"
    fi
    
    echo ""
    echo "📋 其他提供者配置:"
    OTHER_PROVIDERS=$(jq '.providers | keys | .[]' "$CONFIG_FILE" 2>/dev/null | grep -v "minimax" | grep -v "kimi-coding" | tr -d '"')
    if [ -n "$OTHER_PROVIDERS" ]; then
        for provider in $OTHER_PROVIDERS; do
            echo "  - $provider"
        done
    else
        echo "  无其他提供者"
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
echo "3️⃣ 配置选项"
echo "=================================="
echo ""
echo "请选择操作:"
echo "  1) 设置/更新 Minimax API Key"
echo "  2) 设置/更新 Kimi-coding API Key"
echo "  3) 查看配置帮助"
echo "  4) 测试 API Key（如果已配置）"
echo "  5) 退出"
echo ""
read -p "请输入选项 [1-5]: " choice

case $choice in
    1)
        echo ""
        echo -e "${CYAN}设置 Minimax API Key${NC}"
        echo "获取 API Key: https://platform.minimax.chat/"
        echo ""
        read -p "请输入 Minimax API Key: " api_key
        if [ -z "$api_key" ]; then
            echo -e "${RED}❌ API Key 不能为空${NC}"
            exit 1
        fi
        
        if command -v jq &> /dev/null; then
            # 使用 jq 更新配置
            jq ".providers.minimax = (.providers.minimax // {}) + {api_key: \"$api_key\"}" "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
            echo -e "${GREEN}✅ Minimax API Key 已更新${NC}"
        else
            echo -e "${RED}❌ 需要 jq 工具来更新 JSON 配置${NC}"
            echo "请安装 jq 或手动编辑配置文件: $CONFIG_FILE"
            echo ""
            echo "需要添加的配置:"
            echo "  \"providers\": {"
            echo "    \"minimax\": {"
            echo "      \"api_key\": \"$api_key\""
            echo "    }"
            echo "  }"
        fi
        ;;
    2)
        echo ""
        echo -e "${CYAN}设置 Kimi-coding API Key${NC}"
        echo "获取 API Key: https://platform.moonshot.cn/"
        echo ""
        read -p "请输入 Kimi-coding API Key: " api_key
        if [ -z "$api_key" ]; then
            echo -e "${RED}❌ API Key 不能为空${NC}"
            exit 1
        fi
        
        if command -v jq &> /dev/null; then
            # 使用 jq 更新配置
            jq ".providers[\"kimi-coding\"] = (.providers[\"kimi-coding\"] // {}) + {api_key: \"$api_key\"}" "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
            echo -e "${GREEN}✅ Kimi-coding API Key 已更新${NC}"
        else
            echo -e "${RED}❌ 需要 jq 工具来更新 JSON 配置${NC}"
            echo "请安装 jq 或手动编辑配置文件: $CONFIG_FILE"
            echo ""
            echo "需要添加的配置:"
            echo "  \"providers\": {"
            echo "    \"kimi-coding\": {"
            echo "      \"api_key\": \"$api_key\""
            echo "    }"
            echo "  }"
        fi
        ;;
    3)
        echo ""
        echo -e "${CYAN}配置帮助${NC}"
        echo "=================================="
        echo ""
        echo "1. Minimax API Key:"
        echo "   - 获取地址: https://platform.minimax.chat/"
        echo "   - 登录后，在控制台创建 API Key"
        echo "   - 配置项: providers.minimax.api_key"
        echo ""
        echo "2. Kimi-coding API Key:"
        echo "   - 获取地址: https://platform.moonshot.cn/"
        echo "   - 登录后，在控制台创建 API Key"
        echo "   - 配置项: providers[\"kimi-coding\"].api_key"
        echo ""
        echo "3. 配置文件位置:"
        echo "   - $CONFIG_FILE"
        echo ""
        echo "4. 手动编辑配置:"
        echo "   使用文本编辑器打开配置文件，添加或修改 providers 部分"
        echo ""
        echo "5. 配置示例 (JSON):"
        echo "   {"
        echo "     \"providers\": {"
        echo "       \"minimax\": {"
        echo "         \"api_key\": \"your-minimax-api-key\""
        echo "       },"
        echo "       \"kimi-coding\": {"
        echo "         \"api_key\": \"your-kimi-api-key\""
        echo "       }"
        echo "     }"
        echo "   }"
        echo ""
        ;;
    4)
        echo ""
        echo -e "${CYAN}测试 API Key${NC}"
        echo "=================================="
        echo ""
        
        if [ -z "$MINIMAX_API_KEY" ] || [ "$MINIMAX_API_KEY" = "null" ]; then
            echo -e "${YELLOW}⚠️  Minimax API Key 未配置，跳过测试${NC}"
        else
            echo "测试 Minimax API Key..."
            if command -v curl &> /dev/null; then
                # 简单的 API 测试（实际测试可能需要更复杂的请求）
                RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "https://api.minimax.chat/v1/text/chatcompletion_pro" \
                    -H "Authorization: Bearer $MINIMAX_API_KEY" \
                    -H "Content-Type: application/json" \
                    -d '{"model":"abab5.5-chat","messages":[{"role":"user","content":"test"}]}' \
                    --max-time 10 2>/dev/null)
                HTTP_CODE=$(echo "$RESPONSE" | tail -1)
                if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "401" ]; then
                    if [ "$HTTP_CODE" = "401" ]; then
                        echo -e "${RED}❌ Minimax API Key 无效或已过期${NC}"
                    else
                        echo -e "${GREEN}✅ Minimax API Key 有效${NC}"
                    fi
                else
                    echo -e "${YELLOW}⚠️  无法验证 API Key（HTTP $HTTP_CODE）${NC}"
                fi
            else
                echo -e "${YELLOW}⚠️  curl 不可用，无法测试${NC}"
            fi
        fi
        
        echo ""
        if [ -z "$KIMI_API_KEY" ] || [ "$KIMI_API_KEY" = "null" ]; then
            echo -e "${YELLOW}⚠️  Kimi-coding API Key 未配置，跳过测试${NC}"
        else
            echo "测试 Kimi-coding API Key..."
            if command -v curl &> /dev/null; then
                RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "https://api.moonshot.cn/v1/chat/completions" \
                    -H "Authorization: Bearer $KIMI_API_KEY" \
                    -H "Content-Type: application/json" \
                    -d '{"model":"moonshot-v1-8k","messages":[{"role":"user","content":"test"}]}' \
                    --max-time 10 2>/dev/null)
                HTTP_CODE=$(echo "$RESPONSE" | tail -1)
                if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "401" ]; then
                    if [ "$HTTP_CODE" = "401" ]; then
                        echo -e "${RED}❌ Kimi-coding API Key 无效或已过期${NC}"
                    else
                        echo -e "${GREEN}✅ Kimi-coding API Key 有效${NC}"
                    fi
                else
                    echo -e "${YELLOW}⚠️  无法验证 API Key（HTTP $HTTP_CODE）${NC}"
                fi
            else
                echo -e "${YELLOW}⚠️  curl 不可用，无法测试${NC}"
            fi
        fi
        ;;
    5)
        echo "退出"
        exit 0
        ;;
    *)
        echo -e "${RED}❌ 无效选项${NC}"
        exit 1
        ;;
esac

echo ""
echo "=================================="
echo "💡 下一步:"
echo "1. 如果更新了 API Key，请重启 Gateway:"
echo "   ./kill_gateway.sh && ./start_gateway.sh"
echo "2. 查看 Gateway 日志确认是否还有错误:"
echo "   openclaw gateway logs --tail 50"
echo ""
