#!/bin/bash
# 修复 feishu 扩展的 zod 依赖问题
# 在扩展目录本地安装 zod，确保扩展可以找到它

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 修复 feishu 扩展的 zod 依赖${NC}"
echo "=================================="
echo ""

FEISHU_EXT_DIR="$HOME/.openclaw/extensions/feishu"

# 检查扩展目录是否存在
if [ ! -d "$FEISHU_EXT_DIR" ]; then
    echo -e "${RED}❌ feishu 扩展目录不存在: $FEISHU_EXT_DIR${NC}"
    exit 1
fi

echo -e "${GREEN}✅ 找到 feishu 扩展目录: $FEISHU_EXT_DIR${NC}"
echo ""

# 进入扩展目录
cd "$FEISHU_EXT_DIR" || exit 1

# 检查是否已有 node_modules
if [ -d "node_modules/zod" ]; then
    echo -e "${GREEN}✅ zod 已在本地安装${NC}"
    echo "验证安装..."
    if node -e "require('./node_modules/zod')" 2>/dev/null; then
        echo -e "${GREEN}✅ zod 验证成功${NC}"
        exit 0
    else
        echo -e "${YELLOW}⚠️  zod 存在但无法加载，重新安装...${NC}"
        rm -rf node_modules/zod
    fi
fi

# 方法1: 直接安装 zod
echo -e "${BLUE}方法 1: 在扩展目录安装 zod...${NC}"
npm install zod --save --no-package-lock 2>&1 | head -20

if [ -d "node_modules/zod" ]; then
    echo -e "${GREEN}✅ zod 安装成功${NC}"
    
    # 验证
    echo "验证安装..."
    if node -e "require('./node_modules/zod')" 2>/dev/null; then
        echo -e "${GREEN}✅ zod 验证成功${NC}"
        echo ""
        echo -e "${GREEN}✅ 修复完成！请重启 OpenClaw Gateway${NC}"
        exit 0
    fi
fi

# 方法2: 如果方法1失败，尝试从全局 node_modules 创建符号链接
echo ""
echo -e "${BLUE}方法 2: 尝试从全局安装创建符号链接...${NC}"

GLOBAL_NODE_MODULES=$(npm root -g 2>/dev/null)
if [ -n "$GLOBAL_NODE_MODULES" ] && [ -d "$GLOBAL_NODE_MODULES/zod" ]; then
    echo -e "${GREEN}✅ 找到全局 zod 安装: $GLOBAL_NODE_MODULES/zod${NC}"
    
    # 确保 node_modules 目录存在
    mkdir -p node_modules
    
    # 创建符号链接
    if [ ! -e "node_modules/zod" ]; then
        ln -s "$GLOBAL_NODE_MODULES/zod" node_modules/zod
        echo -e "${GREEN}✅ 创建符号链接成功${NC}"
        
        # 验证
        if [ -L "node_modules/zod" ] && [ -d "node_modules/zod" ]; then
            echo -e "${GREEN}✅ 符号链接验证成功${NC}"
            echo ""
            echo -e "${GREEN}✅ 修复完成！请重启 OpenClaw Gateway${NC}"
            exit 0
        fi
    fi
else
    echo -e "${YELLOW}⚠️  未找到全局 zod 安装${NC}"
fi

# 方法3: 如果都失败了，提供手动指导
echo ""
echo -e "${YELLOW}⚠️  自动修复失败，请手动执行：${NC}"
echo ""
echo "1. 进入扩展目录："
echo "   cd $FEISHU_EXT_DIR"
echo ""
echo "2. 安装 zod："
echo "   npm install zod --save"
echo ""
echo "3. 或者从全局安装创建符号链接："
echo "   mkdir -p node_modules"
echo "   ln -s \$(npm root -g)/zod node_modules/zod"
echo ""
echo "4. 验证："
echo "   node -e \"require('./node_modules/zod')\""
echo ""

exit 1
