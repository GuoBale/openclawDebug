#!/bin/bash
# 临时解决方案：在 Android/Termux 环境下手动停止 OpenClaw Gateway
# 使用方法: ./kill_gateway.sh [PORT]

PORT=${1:-18789}
PID=$(lsof -ti:$PORT 2>/dev/null || ps aux | grep "openclaw-gateway" | grep -v grep | awk '{print $2}' | head -1)

if [ -z "$PID" ]; then
    echo "❌ 未找到运行中的 OpenClaw Gateway 进程（端口: $PORT）"
    exit 1
fi

echo "🔍 找到 Gateway 进程: PID $PID"
echo "🛑 正在停止进程..."
kill $PID

# 等待进程结束
sleep 2

# 检查是否成功停止
if ps -p $PID > /dev/null 2>&1; then
    echo "⚠️  进程仍在运行，尝试强制停止..."
    kill -9 $PID
    sleep 1
fi

if ! ps -p $PID > /dev/null 2>&1; then
    echo "✅ Gateway 已成功停止"
else
    echo "❌ 无法停止 Gateway 进程"
    exit 1
fi
