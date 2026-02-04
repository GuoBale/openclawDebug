#!/bin/bash
# 临时解决方案：在 Android/Termux 环境下手动停止 OpenClaw Gateway
# 使用方法: ./kill_gateway.sh [PORT]

PORT=${1:-18789}

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🛑 OpenClaw Gateway 停止脚本${NC}"
echo "=================================="
echo "端口: $PORT"
echo ""

# 函数：查找所有 OpenClaw 相关进程
find_openclaw_processes() {
    ps aux 2>/dev/null | grep -E "openclaw|node.*gateway" | grep -v grep | awk '{print $2}'
}

# 函数：查找占用端口的进程
find_port_process() {
    local port=$1
    if command -v lsof &> /dev/null; then
        lsof -ti:$port 2>/dev/null
    elif command -v netstat &> /dev/null; then
        netstat -tuln 2>/dev/null | grep ":$port " | awk '{print $NF}' | cut -d'/' -f1 | head -1
    else
        ps aux | grep "openclaw-gateway" | grep -v grep | awk '{print $2}' | head -1
    fi
}

# 查找进程
PORT_PID=$(find_port_process $PORT)
ALL_PIDS=$(find_openclaw_processes)

# 合并所有需要停止的进程 ID
ALL_TARGET_PIDS=""
if [ -n "$PORT_PID" ]; then
    ALL_TARGET_PIDS="$PORT_PID"
fi
if [ -n "$ALL_PIDS" ]; then
    ALL_TARGET_PIDS="$ALL_TARGET_PIDS $ALL_PIDS"
fi
# 去重
ALL_TARGET_PIDS=$(echo $ALL_TARGET_PIDS | tr ' ' '\n' | sort -u | tr '\n' ' ')

if [ -z "$ALL_TARGET_PIDS" ]; then
    echo -e "${YELLOW}⚠️  未找到运行中的 OpenClaw Gateway 进程${NC}"
    echo "端口 $PORT 未被占用"
    exit 0
fi

echo -e "${YELLOW}🔍 找到以下进程需要停止:${NC}"
for pid in $ALL_TARGET_PIDS; do
    if ps -p $pid > /dev/null 2>&1; then
        ps -p $pid -o pid,cmd --no-headers 2>/dev/null | head -1
    fi
done
echo ""

# 停止所有进程
echo -e "${YELLOW}🛑 正在停止进程...${NC}"
for pid in $ALL_TARGET_PIDS; do
    if ps -p $pid > /dev/null 2>&1; then
        echo -e "  停止 PID $pid..."
        kill $pid 2>/dev/null
    fi
done

# 等待进程结束
sleep 3

# 检查是否还有进程在运行
REMAINING_PIDS=""
for pid in $ALL_TARGET_PIDS; do
    if ps -p $pid > /dev/null 2>&1; then
        REMAINING_PIDS="$REMAINING_PIDS $pid"
    fi
done

# 如果有进程仍在运行，强制终止
if [ -n "$REMAINING_PIDS" ]; then
    echo -e "${YELLOW}⚠️  部分进程仍在运行，强制停止...${NC}"
    for pid in $REMAINING_PIDS; do
        if ps -p $pid > /dev/null 2>&1; then
            echo -e "  强制停止 PID $pid..."
            kill -9 $pid 2>/dev/null
        fi
    done
    sleep 2
fi

# 最终检查
FINAL_PIDS=$(find_openclaw_processes)
PORT_STILL_IN_USE=$(find_port_process $PORT)

if [ -z "$FINAL_PIDS" ] && [ -z "$PORT_STILL_IN_USE" ]; then
    echo -e "${GREEN}✅ Gateway 已成功停止${NC}"
    exit 0
else
    echo -e "${RED}❌ 无法完全停止 Gateway 进程${NC}"
    if [ -n "$FINAL_PIDS" ]; then
        echo "仍在运行的进程: $FINAL_PIDS"
    fi
    if [ -n "$PORT_STILL_IN_USE" ]; then
        echo "端口 $PORT 仍被占用: PID $PORT_STILL_IN_USE"
    fi
    exit 1
fi
