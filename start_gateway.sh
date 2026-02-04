#!/bin/bash
# OpenClaw Gateway 启动脚本（Android/Termux 兼容）
# 自动关闭占用端口的进程，然后启动 gateway
# 使用方法: ./start_gateway.sh [PORT] [BIND_ADDRESS]

PORT=${1:-18789}
BIND=${2:-loopback}

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 OpenClaw Gateway 启动脚本${NC}"
echo "=================================="
echo "端口: $PORT"
echo "绑定地址: $BIND"
echo ""

# 函数：查找占用端口的进程
find_port_process() {
    local port=$1
    # 方法1: 使用 lsof (如果可用)
    if command -v lsof &> /dev/null; then
        lsof -ti:$port 2>/dev/null
    # 方法2: 使用 netstat (如果可用)
    elif command -v netstat &> /dev/null; then
        netstat -tuln 2>/dev/null | grep ":$port " | awk '{print $NF}' | cut -d'/' -f1 | head -1
    # 方法3: 使用 ps 和 grep
    else
        ps aux | grep "openclaw-gateway" | grep -v grep | awk '{print $2}' | head -1
    fi
}

# 函数：强制关闭占用端口的进程
kill_port_process() {
    local port=$1
    local attempts=0
    local max_attempts=3
    
    while [ $attempts -lt $max_attempts ]; do
        local pid=$(find_port_process $port)
        
        if [ -z "$pid" ]; then
            echo -e "${GREEN}✅ 端口 $port 未被占用${NC}"
            return 0
        fi
        
        echo -e "${YELLOW}🔍 发现占用端口的进程: PID $pid${NC}"
        
        # 尝试正常终止
        if [ $attempts -eq 0 ]; then
            echo -e "${YELLOW}🛑 尝试正常停止进程...${NC}"
            kill $pid 2>/dev/null
        else
            echo -e "${YELLOW}⚠️  进程仍在运行，强制停止...${NC}"
            kill -9 $pid 2>/dev/null
        fi
        
        # 等待进程结束
        sleep 2
        
        # 检查进程是否还在运行
        if ! ps -p $pid > /dev/null 2>&1; then
            echo -e "${GREEN}✅ 进程已成功停止${NC}"
            return 0
        fi
        
        attempts=$((attempts + 1))
    done
    
    echo -e "${RED}❌ 无法停止占用端口的进程${NC}"
    return 1
}

# 函数：检查端口是否可用
check_port_available() {
    local port=$1
    local pid=$(find_port_process $port)
    
    if [ -z "$pid" ]; then
        return 0
    else
        return 1
    fi
}

# 步骤 1: 关闭占用端口的进程
echo -e "${BLUE}步骤 1: 检查并关闭占用端口的进程...${NC}"
if ! kill_port_process $PORT; then
    echo -e "${RED}❌ 无法清理端口，退出${NC}"
    exit 1
fi

# 额外等待，确保端口完全释放
sleep 1

# 步骤 2: 验证端口已释放
echo ""
echo -e "${BLUE}步骤 2: 验证端口状态...${NC}"
if check_port_available $PORT; then
    echo -e "${GREEN}✅ 端口 $PORT 已释放，可以启动${NC}"
else
    echo -e "${YELLOW}⚠️  端口可能仍被占用，但继续尝试启动...${NC}"
fi

# 步骤 3: 启动 gateway
echo ""
echo -e "${BLUE}步骤 3: 启动 OpenClaw Gateway...${NC}"
echo "运行命令: openclaw gateway run --bind $BIND --port $PORT"
echo ""

# 检查 openclaw 命令是否可用
if ! command -v openclaw &> /dev/null; then
    echo -e "${RED}❌ openclaw 命令不可用${NC}"
    echo "请确保 OpenClaw 已正确安装"
    exit 1
fi

# 启动 gateway（在后台运行）
echo -e "${GREEN}🚀 正在启动 Gateway...${NC}"
openclaw gateway run --bind $BIND --port $PORT

# 检查启动结果
sleep 2
if check_port_available $PORT; then
    echo -e "${RED}❌ Gateway 启动失败，端口未被占用${NC}"
    exit 1
else
    echo ""
    echo -e "${GREEN}✅ Gateway 已成功启动${NC}"
    echo "端口: $PORT"
    echo "绑定地址: $BIND"
    echo ""
    echo "查看日志: openclaw gateway logs"
    echo "停止服务: ./kill_gateway.sh $PORT"
fi
