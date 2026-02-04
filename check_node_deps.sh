#!/bin/bash
# OpenClaw Node.js 依赖检查脚本
# 用于检查和安装 OpenClaw 插件所需的 Node.js 依赖

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}📦 OpenClaw Node.js 依赖检查工具${NC}"
echo "=================================="
echo ""

# 检测 Node.js 环境
echo "1️⃣ 检测 Node.js 环境..."
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version 2>&1)
    echo -e "${GREEN}✅ 找到 Node.js: $NODE_VERSION${NC}"
else
    echo -e "${RED}❌ 未找到 Node.js${NC}"
    echo "请先安装 Node.js: pkg install nodejs (Termux)"
    exit 1
fi

# 检测 npm
echo ""
echo "2️⃣ 检测 npm..."
if command -v npm &> /dev/null; then
    NPM_VERSION=$(npm --version 2>&1)
    echo -e "${GREEN}✅ 找到 npm: $NPM_VERSION${NC}"
else
    echo -e "${RED}❌ 未找到 npm${NC}"
    echo "请先安装 npm: pkg install nodejs (Termux)"
    exit 1
fi

# 检查关键依赖
echo ""
echo "3️⃣ 检查关键依赖..."

check_npm_module() {
    local module=$1
    local location=$2
    
    echo -n "检查 $module: "
    
    if [ -n "$location" ] && [ -d "$location" ]; then
        # 检查特定目录
        if [ -f "$location/package.json" ]; then
            if grep -q "\"$module\"" "$location/package.json" 2>/dev/null; then
                # 检查 node_modules
                if [ -d "$location/node_modules/$module" ]; then
                    echo -e "${GREEN}✅ 已安装 (在 $location)${NC}"
                    return 0
                fi
            fi
        fi
    fi
    
    # 全局检查
    if node -e "require('$module')" 2>/dev/null; then
        echo -e "${GREEN}✅ 已安装${NC}"
        return 0
    else
        echo -e "${RED}❌ 未安装${NC}"
        return 1
    fi
}

# 检查 OpenClaw 扩展目录
echo ""
echo "4️⃣ 检查 OpenClaw 扩展目录..."
OPENCLAW_EXT_DIR="$HOME/.openclaw/extensions"
OPENCLAW_NODE_MODULES="$HOME/.openclaw/node_modules"
OPENCLAW_GLOBAL="/data/data/com.termux/files/usr/lib/node_modules/openclaw"

MISSING_DEPS=()
MISSING_LOCATIONS=()

# 检查 feishu 扩展
if [ -d "$OPENCLAW_EXT_DIR/feishu" ]; then
    echo -e "${GREEN}✅ 找到 feishu 扩展: $OPENCLAW_EXT_DIR/feishu${NC}"
    
    echo ""
    echo "检查 feishu 扩展依赖:"
    
    # 检查 zod
    if ! check_npm_module "zod" "$OPENCLAW_EXT_DIR/feishu"; then
        MISSING_DEPS+=("zod")
        MISSING_LOCATIONS+=("$OPENCLAW_EXT_DIR/feishu")
    fi
    
    # 检查扩展的 package.json
    if [ -f "$OPENCLAW_EXT_DIR/feishu/package.json" ]; then
        echo ""
        echo "📋 feishu package.json 依赖:"
        if command -v jq &> /dev/null; then
            jq '.dependencies // {}' "$OPENCLAW_EXT_DIR/feishu/package.json" 2>/dev/null | head -20
        else
            grep -A 20 '"dependencies"' "$OPENCLAW_EXT_DIR/feishu/package.json" 2>/dev/null | head -20
        fi
    fi
else
    echo -e "${YELLOW}⚠️  未找到 feishu 扩展目录${NC}"
fi

# 检查全局 OpenClaw 安装
if [ -d "$OPENCLAW_GLOBAL" ]; then
    echo ""
    echo "5️⃣ 检查全局 OpenClaw 安装..."
    echo -e "${GREEN}✅ 找到全局安装: $OPENCLAW_GLOBAL${NC}"
    
    # 检查全局 node_modules
    if [ -d "$OPENCLAW_GLOBAL/node_modules" ]; then
        echo "检查全局依赖..."
        if [ -d "$OPENCLAW_GLOBAL/node_modules/zod" ]; then
            echo -e "${GREEN}✅ zod 在全局安装中可用${NC}"
        else
            echo -e "${YELLOW}⚠️  zod 不在全局安装中${NC}"
        fi
    fi
fi

# 安装缺失的依赖
if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo ""
    echo "6️⃣ 安装缺失的依赖..."
    echo "缺失的依赖: ${MISSING_DEPS[*]}"
    echo ""
    
    # 为每个扩展安装依赖
    for i in "${!MISSING_DEPS[@]}"; do
        local dep="${MISSING_DEPS[$i]}"
        local location="${MISSING_LOCATIONS[$i]}"
        
        if [ -d "$location" ]; then
            echo -e "${BLUE}在 $location 安装 $dep...${NC}"
            cd "$location" || continue
            
            # 检查是否有 package.json
            if [ -f "package.json" ]; then
                echo "运行: npm install"
                npm install
            else
                echo "运行: npm install $dep"
                npm install "$dep"
            fi
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✅ $dep 安装成功${NC}"
            else
                echo -e "${RED}❌ $dep 安装失败${NC}"
            fi
            echo ""
        fi
    done
    
    # 也尝试全局安装
    echo "尝试全局安装缺失的依赖..."
    for dep in "${MISSING_DEPS[@]}"; do
        echo -e "${BLUE}全局安装: $dep${NC}"
        npm install -g "$dep" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ $dep 全局安装成功${NC}"
        else
            echo -e "${YELLOW}⚠️  $dep 全局安装失败（可能需要本地安装）${NC}"
        fi
    done
    
    # 验证安装
    echo ""
    echo "7️⃣ 验证安装..."
    ALL_OK=true
    for i in "${!MISSING_DEPS[@]}"; do
        local dep="${MISSING_DEPS[$i]}"
        local location="${MISSING_LOCATIONS[$i]}"
        
        if [ -d "$location/node_modules/$dep" ] || node -e "require('$dep')" 2>/dev/null; then
            echo -e "${GREEN}✅ $dep 验证成功${NC}"
        else
            echo -e "${RED}❌ $dep 验证失败${NC}"
            ALL_OK=false
        fi
    done
    
    if [ "$ALL_OK" = true ]; then
        echo -e "${GREEN}✅ 所有依赖安装并验证成功${NC}"
    fi
else
    echo ""
    echo -e "${GREEN}✅ 所有依赖已安装${NC}"
fi

echo ""
echo "=================================="
echo "💡 提示："
echo "- 如果扩展有 package.json，在扩展目录运行: npm install"
echo "- 检查扩展依赖: cat ~/.openclaw/extensions/<extension>/package.json"
echo "- 全局安装: npm install -g <package>"
echo ""
