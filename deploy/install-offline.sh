#!/usr/bin/env bash
# PandaWiki 离线部署脚本（在内网目标机器执行）
# 前置：已用 build-offline-arm64.sh / build-offline-amd64.sh 构建离线包并解压到本目录
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

echo "[1/3] 检查依赖..."
command -v docker >/dev/null || { echo "❌ 请先安装 Docker"; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "❌ 需要 docker compose v2"; exit 1; }

echo "[2/3] 导入镜像 + 准备配置..."
shopt -s nullglob
for tar in images-*.tar; do
  echo "    加载 $tar ..."
  docker load -i "$tar"
done
[ -f .env ] || cp .env.example .env

echo "[3/3] 启动全部服务..."
docker compose up -d
sleep 5
docker compose ps

PORT="$(grep -E '^ADMIN_PORT=' .env | cut -d= -f2)"
ADMIN_PWD="$(grep -E '^ADMIN_PASSWORD=' .env | cut -d= -f2)"
echo
echo "==============================================="
echo " ✅ 部署完成"
echo " 管理后台: https://localhost:${PORT:-2443}"
echo " 账号: admin    密码: ${ADMIN_PWD}"
echo " 跟踪日志: docker compose logs -f api"
echo "==============================================="
