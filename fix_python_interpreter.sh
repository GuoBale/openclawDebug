#!/bin/bash
# OpenClaw Python 解释器诊断和修复脚本
# 用于解决 Termux 环境中的 Python 解释器检测问题

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}🐍 OpenClaw Python 解释器诊断工具${NC}"
echo "=================================="
echo ""

# 检测 Termux 环境
IS_TERMUX=false
if [ -d "/data/data/com.termux" ] || [ -n "$PREFIX" ] && [[ "$PREFIX" == *"termux"* ]]; then
    IS_TERMUX=true
    echo -e "${CYAN}📱 检测到 Termux 环境${NC}"
fi

# 1. 检测 which 命令问题
echo "1️⃣ 检测 which 命令..."
WHICH_CMD=""
if command -v which &> /dev/null; then
    WHICH_CMD="which"
    echo -e "${GREEN}✅ which 命令可用${NC}"
elif [ -f "/usr/bin/which" ]; then
    WHICH_CMD="/usr/bin/which"
    echo -e "${YELLOW}⚠️  找到 /usr/bin/which，但可能无法执行${NC}"
else
    echo -e "${YELLOW}⚠️  which 命令不可用（Termux 常见问题）${NC}"
    echo -e "${CYAN}💡 将使用 command -v 作为替代${NC}"
fi

# 2. 检测 Python 解释器
echo ""
echo "2️⃣ 检测 Python 解释器..."

# 使用多种方法查找 Python
find_python() {
    local python_cmd=""
    local python_path=""
    local python_version=""
    
    # 方法 1: command -v (推荐，兼容性最好)
    if command -v python3 &> /dev/null; then
        python_cmd="python3"
        python_path=$(command -v python3)
    elif command -v python &> /dev/null; then
        python_cmd="python"
        python_path=$(command -v python)
    fi
    
    # 方法 2: 如果 command -v 失败，尝试直接测试
    if [ -z "$python_cmd" ]; then
        if python3 --version &> /dev/null; then
            python_cmd="python3"
            python_path=$(python3 -c "import sys; print(sys.executable)" 2>/dev/null || echo "python3")
        elif python --version &> /dev/null; then
            python_cmd="python"
            python_path=$(python -c "import sys; print(sys.executable)" 2>/dev/null || echo "python")
        fi
    fi
    
    # 方法 3: 在 Termux 中查找常见路径
    if [ -z "$python_cmd" ] && [ "$IS_TERMUX" = true ]; then
        TERMUX_PATHS=(
            "$PREFIX/bin/python3"
            "$PREFIX/bin/python"
            "/data/data/com.termux/files/usr/bin/python3"
            "/data/data/com.termux/files/usr/bin/python"
        )
        for path in "${TERMUX_PATHS[@]}"; do
            if [ -f "$path" ] && [ -x "$path" ]; then
                python_cmd="$path"
                python_path="$path"
                break
            fi
        done
    fi
    
    if [ -n "$python_cmd" ]; then
        python_version=$($python_cmd --version 2>&1)
        echo "$python_cmd|$python_path|$python_version"
    fi
}

PYTHON_INFO=$(find_python)

if [ -z "$PYTHON_INFO" ]; then
    echo -e "${RED}❌ 未找到 Python 解释器${NC}"
    echo ""
    echo "请安装 Python:"
    echo "  pkg install python (Termux)"
    exit 1
fi

PYTHON_CMD=$(echo "$PYTHON_INFO" | cut -d'|' -f1)
PYTHON_PATH=$(echo "$PYTHON_INFO" | cut -d'|' -f2)
PYTHON_VERSION=$(echo "$PYTHON_INFO" | cut -d'|' -f3)

echo -e "${GREEN}✅ 找到 Python: $PYTHON_VERSION${NC}"
echo -e "   命令: $PYTHON_CMD"
echo -e "   路径: $PYTHON_PATH"

# 3. 检查 Python 版本
echo ""
echo "3️⃣ 检查 Python 版本..."

PYTHON_MAJOR=$($PYTHON_CMD -c "import sys; print(sys.version_info.major)" 2>/dev/null)
PYTHON_MINOR=$($PYTHON_CMD -c "import sys; print(sys.version_info.minor)" 2>/dev/null)
PYTHON_MICRO=$($PYTHON_CMD -c "import sys; print(sys.version_info.micro)" 2>/dev/null)

if [ -n "$PYTHON_MAJOR" ] && [ -n "$PYTHON_MINOR" ]; then
    echo -e "${GREEN}✅ Python 版本: $PYTHON_MAJOR.$PYTHON_MINOR.$PYTHON_MICRO${NC}"
    
    # 检查版本要求
    if [ "$PYTHON_MAJOR" -lt 3 ]; then
        echo -e "${RED}❌ Python 版本过低，需要 Python 3.x${NC}"
    elif [ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 8 ]; then
        echo -e "${YELLOW}⚠️  Python 版本较旧，建议使用 Python 3.8+${NC}"
    else
        echo -e "${GREEN}✅ Python 版本符合要求${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  无法获取详细版本信息${NC}"
fi

# 4. 检查 Python 可执行性
echo ""
echo "4️⃣ 检查 Python 可执行性..."

if [ -x "$PYTHON_PATH" ]; then
    echo -e "${GREEN}✅ Python 可执行${NC}"
else
    echo -e "${RED}❌ Python 不可执行: $PYTHON_PATH${NC}"
    echo "尝试修复权限..."
    chmod +x "$PYTHON_PATH" 2>/dev/null && echo -e "${GREEN}✅ 权限已修复${NC}" || echo -e "${RED}❌ 无法修复权限${NC}"
fi

# 5. 测试 Python 基本功能
echo ""
echo "5️⃣ 测试 Python 基本功能..."

if $PYTHON_CMD -c "import sys; print('OK')" 2>/dev/null | grep -q "OK"; then
    echo -e "${GREEN}✅ Python 可以正常执行${NC}"
else
    echo -e "${RED}❌ Python 无法正常执行${NC}"
    exit 1
fi

# 6. 检查 OpenClaw 配置
echo ""
echo "6️⃣ 检查 OpenClaw 配置..."

OPENCLAW_CONFIG_DIR="$HOME/.openclaw"
if [ -d "$OPENCLAW_CONFIG_DIR" ]; then
    echo -e "${GREEN}✅ 找到 OpenClaw 配置目录: $OPENCLAW_CONFIG_DIR${NC}"
    
    # 检查配置文件
    CONFIG_FILES=(
        "$OPENCLAW_CONFIG_DIR/config.json"
        "$OPENCLAW_CONFIG_DIR/openclaw.json"
    )
    
    for config_file in "${CONFIG_FILES[@]}"; do
        if [ -f "$config_file" ]; then
            echo -e "${GREEN}✅ 找到配置文件: $config_file${NC}"
            
            # 检查是否有 Python 相关配置
            if grep -q "python" "$config_file" 2>/dev/null; then
                echo -e "${CYAN}💡 配置文件中包含 Python 相关配置${NC}"
            fi
        fi
    done
else
    echo -e "${YELLOW}⚠️  未找到 OpenClaw 配置目录${NC}"
fi

# 7. 创建修复建议
echo ""
echo "7️⃣ 修复建议..."

echo ""
echo -e "${CYAN}📝 诊断结果：${NC}"
echo ""

ISSUES=()

# 检查 which 命令问题
if [ -z "$WHICH_CMD" ] || [ ! -x "/bin/which" ] 2>/dev/null; then
    ISSUES+=("which 命令不可用")
    echo -e "${YELLOW}⚠️  问题: which 命令不可用${NC}"
    echo -e "${CYAN}   解决方案:${NC}"
    echo "   1. 使用 command -v 替代 which"
    echo "   2. 安装 which: pkg install debianutils (Termux)"
    echo ""
fi

# 检查 Python 版本要求
if [ -n "$PYTHON_MAJOR" ] && [ -n "$PYTHON_MINOR" ]; then
    # 如果工具要求 Python >= 3.13，但只有 3.12
    if [ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 13 ]; then
        echo -e "${YELLOW}⚠️  问题: Python 版本可能不满足某些工具的要求（需要 >= 3.13）${NC}"
        echo -e "${CYAN}   当前版本: Python $PYTHON_MAJOR.$PYTHON_MINOR.$PYTHON_MICRO${NC}"
        echo -e "${CYAN}   解决方案:${NC}"
        echo "   1. 升级 Python（如果可能）"
        echo "   2. 检查工具是否真的需要 Python 3.13，或者是否可以降级要求"
        echo "   3. 使用 pyenv 或其他版本管理工具安装 Python 3.13"
        echo ""
    fi
fi

# 8. 生成环境变量建议
echo ""
echo "8️⃣ 环境变量建议..."

echo ""
echo -e "${CYAN}💡 建议设置以下环境变量：${NC}"
echo ""
echo "export PYTHON_CMD=\"$PYTHON_CMD\""
echo "export PYTHON_PATH=\"$PYTHON_PATH\""
echo "export PYTHON_VERSION=\"$PYTHON_MAJOR.$PYTHON_MINOR.$PYTHON_MICRO\""

# 如果 which 不可用，建议使用 command -v
if [ -z "$WHICH_CMD" ] || [ ! -x "/bin/which" ] 2>/dev/null; then
    echo ""
    echo "# 使用 command -v 替代 which"
    echo "alias which='command -v'"
fi

# 9. 创建修复脚本
echo ""
echo "9️⃣ 生成修复脚本..."

FIX_SCRIPT="$HOME/.openclaw/fix_python_env.sh"
mkdir -p "$(dirname "$FIX_SCRIPT")"

cat > "$FIX_SCRIPT" << EOF
#!/bin/bash
# 自动生成的 Python 环境修复脚本
# 生成时间: $(date)

export PYTHON_CMD="$PYTHON_CMD"
export PYTHON_PATH="$PYTHON_PATH"
export PYTHON_VERSION="$PYTHON_MAJOR.$PYTHON_MINOR.$PYTHON_MICRO"

# 使用 command -v 替代 which（如果 which 不可用）
if ! command -v which &> /dev/null || [ ! -x "/bin/which" ] 2>/dev/null; then
    alias which='command -v'
fi

# 添加到 PATH（如果需要）
if [[ ":\$PATH:" != *":$(dirname "$PYTHON_PATH"):"* ]]; then
    export PATH="$(dirname "$PYTHON_PATH"):\$PATH"
fi

echo "Python 环境已配置:"
echo "  PYTHON_CMD: \$PYTHON_CMD"
echo "  PYTHON_PATH: \$PYTHON_PATH"
echo "  PYTHON_VERSION: \$PYTHON_VERSION"
EOF

chmod +x "$FIX_SCRIPT"
echo -e "${GREEN}✅ 修复脚本已生成: $FIX_SCRIPT${NC}"

# 10. 测试修复
echo ""
echo "🔟 测试修复..."

if [ -f "$FIX_SCRIPT" ]; then
    source "$FIX_SCRIPT"
    echo -e "${GREEN}✅ 环境变量已设置${NC}"
    echo "   测试 Python 调用:"
    if $PYTHON_CMD --version &> /dev/null; then
        echo -e "   ${GREEN}✅ $PYTHON_CMD --version: $($PYTHON_CMD --version 2>&1)${NC}"
    fi
fi

echo ""
echo "=================================="
echo -e "${GREEN}✅ 诊断完成${NC}"
echo ""
echo "💡 使用建议："
echo "   1. 在运行 OpenClaw 之前，先执行: source $FIX_SCRIPT"
echo "   2. 或者将环境变量添加到 ~/.bashrc 或 ~/.zshrc"
echo "   3. 如果 which 命令问题持续，安装: pkg install debianutils"
echo ""
