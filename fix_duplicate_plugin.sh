#!/bin/bash
# 修复 OpenClaw 重复插件 ID 警告
# 处理 feishu 插件的重复配置问题

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 修复 OpenClaw 重复插件 ID 警告${NC}"
echo "=================================="
echo ""

GLOBAL_FEISHU="/data/data/com.termux/files/usr/lib/node_modules/openclaw/extensions/feishu"
USER_FEISHU="$HOME/.openclaw/extensions/feishu"

# 检查两个位置
GLOBAL_EXISTS=false
USER_EXISTS=false

if [ -d "$GLOBAL_FEISHU" ]; then
    GLOBAL_EXISTS=true
    echo -e "${GREEN}✅ 找到全局 feishu 插件: $GLOBAL_FEISHU${NC}"
else
    echo -e "${YELLOW}⚠️  未找到全局 feishu 插件${NC}"
fi

if [ -d "$USER_FEISHU" ]; then
    USER_EXISTS=true
    echo -e "${GREEN}✅ 找到用户 feishu 扩展: $USER_FEISHU${NC}"
else
    echo -e "${YELLOW}⚠️  未找到用户 feishu 扩展${NC}"
fi

echo ""

# 如果只有一个，不需要处理
if [ "$GLOBAL_EXISTS" = true ] && [ "$USER_EXISTS" = false ]; then
    echo -e "${GREEN}✅ 只有一个 feishu 插件，无需处理${NC}"
    exit 0
fi

if [ "$GLOBAL_EXISTS" = false ] && [ "$USER_EXISTS" = true ]; then
    echo -e "${GREEN}✅ 只有一个 feishu 扩展，无需处理${NC}"
    exit 0
fi

# 如果两个都存在，需要处理
if [ "$GLOBAL_EXISTS" = true ] && [ "$USER_EXISTS" = true ]; then
    echo -e "${YELLOW}⚠️  检测到重复的 feishu 插件${NC}"
    echo ""
    echo "选项："
    echo "1. 保留用户扩展，禁用全局插件（推荐）"
    echo "2. 保留全局插件，删除/重命名用户扩展"
    echo "3. 重命名用户扩展（保留两个但避免冲突）"
    echo "4. 查看详细信息后决定"
    echo "5. 取消"
    echo ""
    read -p "请选择 (1-5): " choice
    
    case $choice in
        1)
            echo ""
            echo -e "${BLUE}选项 1: 禁用全局插件${NC}"
            echo "方法：重命名全局插件目录"
            read -p "确认重命名全局插件目录? (y/n) " confirm
            if [[ $confirm =~ ^[Yy]$ ]]; then
                if [ -d "$GLOBAL_FEISHU" ]; then
                    BACKUP_NAME="${GLOBAL_FEISHU}.disabled"
                    if [ -d "$BACKUP_NAME" ]; then
                        echo -e "${YELLOW}⚠️  备份目录已存在，删除旧备份...${NC}"
                        rm -rf "$BACKUP_NAME"
                    fi
                    mv "$GLOBAL_FEISHU" "$BACKUP_NAME"
                    if [ $? -eq 0 ]; then
                        echo -e "${GREEN}✅ 全局插件已禁用（重命名为 .disabled）${NC}"
                        echo -e "${GREEN}✅ 现在只使用用户扩展${NC}"
                    else
                        echo -e "${RED}❌ 操作失败（可能需要 root 权限）${NC}"
                        exit 1
                    fi
                fi
            else
                echo "已取消"
                exit 0
            fi
            ;;
        2)
            echo ""
            echo -e "${BLUE}选项 2: 删除/重命名用户扩展${NC}"
            echo "方法：重命名用户扩展目录"
            read -p "确认重命名用户扩展目录? (y/n) " confirm
            if [[ $confirm =~ ^[Yy]$ ]]; then
                if [ -d "$USER_FEISHU" ]; then
                    BACKUP_NAME="${USER_FEISHU}.disabled"
                    if [ -d "$BACKUP_NAME" ]; then
                        echo -e "${YELLOW}⚠️  备份目录已存在，删除旧备份...${NC}"
                        rm -rf "$BACKUP_NAME"
                    fi
                    mv "$USER_FEISHU" "$BACKUP_NAME"
                    if [ $? -eq 0 ]; then
                        echo -e "${GREEN}✅ 用户扩展已禁用（重命名为 .disabled）${NC}"
                        echo -e "${GREEN}✅ 现在只使用全局插件${NC}"
                    else
                        echo -e "${RED}❌ 操作失败${NC}"
                        exit 1
                    fi
                fi
            else
                echo "已取消"
                exit 0
            fi
            ;;
        3)
            echo ""
            echo -e "${BLUE}选项 3: 重命名用户扩展${NC}"
            read -p "输入新的扩展名称（例如: feishu-custom）: " new_name
            if [ -z "$new_name" ]; then
                echo -e "${RED}❌ 名称不能为空${NC}"
                exit 1
            fi
            NEW_PATH="$HOME/.openclaw/extensions/$new_name"
            if [ -d "$NEW_PATH" ]; then
                echo -e "${RED}❌ 目录已存在: $NEW_PATH${NC}"
                exit 1
            fi
            mv "$USER_FEISHU" "$NEW_PATH"
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✅ 用户扩展已重命名为: $new_name${NC}"
                echo -e "${YELLOW}⚠️  注意：需要修改扩展的 ID 才能避免冲突${NC}"
                echo "编辑: $NEW_PATH/index.ts 或 package.json，修改插件 ID"
            else
                echo -e "${RED}❌ 操作失败${NC}"
                exit 1
            fi
            ;;
        4)
            echo ""
            echo -e "${BLUE}详细信息：${NC}"
            echo ""
            echo "全局插件："
            echo "  路径: $GLOBAL_FEISHU"
            if [ -f "$GLOBAL_FEISHU/index.ts" ]; then
                echo "  主文件: $GLOBAL_FEISHU/index.ts"
                echo "  大小: $(du -sh "$GLOBAL_FEISHU" 2>/dev/null | cut -f1)"
            fi
            echo ""
            echo "用户扩展："
            echo "  路径: $USER_FEISHU"
            if [ -f "$USER_FEISHU/index.ts" ]; then
                echo "  主文件: $USER_FEISHU/index.ts"
                echo "  大小: $(du -sh "$USER_FEISHU" 2>/dev/null | cut -f1)"
            fi
            echo ""
            echo "建议："
            echo "- 如果用户扩展是自定义的，保留用户扩展，禁用全局插件"
            echo "- 如果用户扩展只是复制，删除用户扩展，使用全局插件"
            echo ""
            echo "重新运行脚本进行修复"
            exit 0
            ;;
        5)
            echo "已取消"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ 无效选择${NC}"
            exit 1
            ;;
    esac
    
    echo ""
    echo -e "${GREEN}✅ 修复完成！请重启 OpenClaw Gateway${NC}"
    echo "运行: ./kill_gateway.sh && ./start_gateway.sh"
else
    echo -e "${YELLOW}⚠️  未找到任何 feishu 插件${NC}"
    exit 1
fi
