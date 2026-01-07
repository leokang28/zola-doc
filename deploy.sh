#!/bin/bash

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  部署到 GitHub Pages${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# 检查是否有未提交的更改
if [[ -n $(git status -s) ]]; then
    echo -e "${YELLOW}检测到未提交的更改${NC}"
    git status -s
    echo ""
    read -p "是否要提交这些更改? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "请输入提交信息: " commit_msg
        git add .
        git commit -m "$commit_msg"
        echo -e "${GREEN}✓ 已提交更改${NC}"
    else
        echo -e "${RED}✗ 取消部署${NC}"
        exit 1
    fi
fi

# 推送到 GitHub
echo ""
echo -e "${YELLOW}正在推送到 GitHub...${NC}"
git push origin main

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ 推送成功！${NC}"
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  部署已触发${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "请访问以下链接查看部署状态："
    echo -e "${YELLOW}https://github.com/leokang28/leokang28.github.io/actions${NC}"
    echo ""
    echo "部署完成后访问："
    echo -e "${YELLOW}https://leokang28.github.io${NC}"
else
    echo -e "${RED}✗ 推送失败${NC}"
    exit 1
fi
