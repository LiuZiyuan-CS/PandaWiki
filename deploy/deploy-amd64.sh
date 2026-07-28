#!/usr/bin/env bash
# PandaWiki 本地一键部署脚本（x86_64 / Intel mac / Linux 服务器）
# 用法：bash deploy/deploy-amd64.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
PLATFORM="linux/amd64"

echo "[1/5] 检查依赖..."
command -v docker >/dev/null || { echo "❌ 请先安装 Docker"; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "❌ 请确认已安装 docker compose v2"; exit 1; }
command -v pnpm >/dev/null || { echo "❌ 请先安装 pnpm: npm i -g pnpm"; exit 1; }
echo "    平台: $PLATFORM"

echo "[2/5] 准备配置..."
if [ ! -f .env ]; then
  cp .env.example .env
  echo "    已从 .env.example 生成 .env（默认密码，生产环境请修改）"
fi

echo "[3/5] 构建前端管理台..."
( cd ../web && pnpm install )
( export NODE_OPTIONS="--max-old-space-size=12288"; cd ../web/admin && pnpm build )

echo "[4/5] 构建后端镜像（$PLATFORM）..."
docker buildx build --platform "$PLATFORM" --load \
  -t panda-wiki-api:local -f ../backend/Dockerfile.api ../backend
docker buildx build --platform "$PLATFORM" --load \
  -t panda-wiki-consumer:local -f ../backend/Dockerfile.consumer ../backend
docker buildx build --platform "$PLATFORM" --load \
  -t panda-wiki-admin:local -f ../web/admin/Dockerfile.local ../web/admin

echo "[5/5] 启动全部服务..."
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
echo " 停止: cd deploy && docker compose down"
echo "==============================================="
