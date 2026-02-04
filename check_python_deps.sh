#!/bin/bash
# OpenClaw Python 依赖检查脚本
# 用于检查和安装 OpenClaw 技能所需的 Python 依赖

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🐍 OpenClaw Python 依赖检查工具${NC}"
echo "=================================="
echo ""

# 检测 Python 版本
echo "1️⃣ 检测 Python 环境..."
if command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
    PYTHON_VERSION=$(python3 --version 2>&1)
    echo -e "${GREEN}✅ 找到 Python3: $PYTHON_VERSION${NC}"
elif command -v python &> /dev/null; then
    PYTHON_CMD="python"
    PYTHON_VERSION=$(python --version 2>&1)
    echo -e "${GREEN}✅ 找到 Python: $PYTHON_VERSION${NC}"
else
    echo -e "${RED}❌ 未找到 Python${NC}"
    echo "请先安装 Python: pkg install python (Termux)"
    exit 1
fi

# 检测 pip
echo ""
echo "2️⃣ 检测 pip..."
if command -v pip3 &> /dev/null; then
    PIP_CMD="pip3"
    echo -e "${GREEN}✅ 找到 pip3${NC}"
elif command -v pip &> /dev/null; then
    PIP_CMD="pip"
    echo -e "${GREEN}✅ 找到 pip${NC}"
else
    echo -e "${RED}❌ 未找到 pip${NC}"
    echo "请先安装 pip: pkg install python (Termux) 或 python -m ensurepip"
    exit 1
fi

# 检查关键依赖
echo ""
echo "3️⃣ 检查关键依赖..."

check_module() {
    local module=$1
    local package=$2
    
    echo -n "检查 $module: "
    if $PYTHON_CMD -c "import $module" 2>/dev/null; then
        echo -e "${GREEN}✅ 已安装${NC}"
        return 0
    else
        echo -e "${RED}❌ 未安装${NC}"
        if [ -n "$package" ]; then
            echo -e "  ${YELLOW}需要安装: $package${NC}"
        fi
        return 1
    fi
}

# 检查常见依赖
MISSING_DEPS=()

echo ""
echo "检查 PIL/Pillow (图像处理):"
if ! check_module "PIL" "Pillow"; then
    MISSING_DEPS+=("Pillow")
fi

echo ""
echo "检查 qrcode (二维码生成):"
if ! check_module "qrcode" "qrcode[pil]"; then
    MISSING_DEPS+=("qrcode[pil]")
fi

echo ""
echo "检查 requests (HTTP 请求):"
if ! check_module "requests" "requests"; then
    MISSING_DEPS+=("requests")
fi

# 检查 OpenClaw 工作空间
echo ""
echo "4️⃣ 检查 OpenClaw 工作空间..."
OPENCLAW_WS="$HOME/.openclaw/workspace"
if [ -d "$OPENCLAW_WS" ]; then
    echo -e "${GREEN}✅ 找到工作空间: $OPENCLAW_WS${NC}"
    
    # 检查是否有 requirements.txt
    if [ -f "$OPENCLAW_WS/requirements.txt" ]; then
        echo -e "${GREEN}✅ 找到 requirements.txt${NC}"
        echo "内容:"
        cat "$OPENCLAW_WS/requirements.txt" | head -10
    fi
    
    # 检查技能目录
    if [ -d "$OPENCLAW_WS/skills" ]; then
        SKILL_COUNT=$(find "$OPENCLAW_WS/skills" -mindepth 1 -maxdepth 1 -type d | wc -l)
        echo -e "${GREEN}✅ 找到 $SKILL_COUNT 个技能目录${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  未找到 OpenClaw 工作空间${NC}"
fi

# 安装缺失的依赖
if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo ""
    echo "5️⃣ 安装缺失的依赖..."
    echo "缺失的依赖: ${MISSING_DEPS[*]}"
    echo ""
    read -p "是否自动安装缺失的依赖? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        for dep in "${MISSING_DEPS[@]}"; do
            echo -e "${BLUE}正在安装: $dep${NC}"
            $PIP_CMD install "$dep"
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✅ $dep 安装成功${NC}"
            else
                echo -e "${RED}❌ $dep 安装失败${NC}"
            fi
            echo ""
        done
        
        # 验证安装
        echo "6️⃣ 验证安装..."
        ALL_OK=true
        for dep in "${MISSING_DEPS[@]}"; do
            module=$(echo "$dep" | cut -d'[' -f1)
            if [ "$module" = "qrcode[pil]" ]; then
                module="qrcode"
            fi
            if ! $PYTHON_CMD -c "import $module" 2>/dev/null; then
                echo -e "${RED}❌ $module 验证失败${NC}"
                ALL_OK=false
            fi
        done
        
        if [ "$ALL_OK" = true ]; then
            echo -e "${GREEN}✅ 所有依赖安装并验证成功${NC}"
        fi
    else
        echo "跳过自动安装。手动安装命令:"
        for dep in "${MISSING_DEPS[@]}"; do
            echo "  $PIP_CMD install $dep"
        done
    fi
else
    echo ""
    echo -e "${GREEN}✅ 所有依赖已安装${NC}"
fi

echo ""
echo "=================================="
echo "💡 提示："
echo "- 如果使用虚拟环境，请先激活: source ~/.openclaw/venv/bin/activate"
echo "- 检查特定技能依赖: cat ~/.openclaw/workspace/skills/<skill>/requirements.txt"
echo ""
