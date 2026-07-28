#!/usr/bin/env bash
# 构建 PandaWiki 离线部署包（arm64 / Apple Silicon 原生）
# 在能联网的 arm64 机器上运行，产物可拷到内网服务器用 install-offline.sh 部署
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
ARCH="arm64"
PLATFORM="linux/$ARCH"

echo "[1/6] 检查依赖..."
command -v docker >/dev/null || { echo "❌ 请先安装 Docker"; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "❌ 需要 docker compose v2"; exit 1; }
command -v pnpm >/dev/null || { echo "❌ 请先安装 pnpm: npm i -g pnpm"; exit 1; }

echo "[2/6] 构建前端管理台..."
( cd ../web && pnpm install )
( cd ../web/admin && pnpm build )

echo "[3/6] 预拉取 base 镜像 + 构建本地源码镜像（${PLATFORM}）..."
# 从镜像加速拉取 Dockerfile 依赖的 base 镜像(golang/alpine)，避免 docker.io 访问失败
for base in "golang:1.24.3-alpine" "alpine:3.21"; do
  docker pull --platform "${PLATFORM}" "docker.m.daocloud.io/library/${base}" 2>/dev/null \
    && docker tag "docker.m.daocloud.io/library/${base}" "${base}" \
    || echo "    (跳过 base 预拉: ${base})"
done
docker buildx build --platform "${PLATFORM}" --load -t panda-wiki-api:local -f ../backend/Dockerfile.api ../backend
docker buildx build --platform "${PLATFORM}" --load -t panda-wiki-consumer:local -f ../backend/Dockerfile.consumer ../backend
docker buildx build --platform "${PLATFORM}" --load -t panda-wiki-admin:local -f ../web/admin/Dockerfile.local ../web/admin

echo "[4/6] 拉取官方依赖镜像（${PLATFORM}）..."
for img in $(docker compose config --images | sort -u); do
  docker pull --platform "${PLATFORM}" "$img" 2>/dev/null || echo "    跳过(本地构建): $img"
done

echo "[5/6] 导出全部镜像..."
IMAGES=$(docker compose config --images | sort -u)
echo "$IMAGES" | sed 's/^/    - /'
docker save -o "images-$ARCH.tar" $IMAGES
echo "    → images-$ARCH.tar ($(du -h "images-$ARCH.tar" | cut -f1))"

echo "[6/6] 打包离线部署包..."
PKG="pandawiki-offline-$ARCH-$(date +%Y%m%d).tar.gz"
STAGE="$(mktemp -d)"
mkdir -p "$STAGE/pandawiki"
cp docker-compose.yml .env.example install-offline.sh "$STAGE/pandawiki/"
mv "images-$ARCH.tar" "$STAGE/pandawiki/"
tar -czf "$PKG" -C "$STAGE" pandawiki
rm -rf "$STAGE"
echo "    → $PKG ($(du -h "$PKG" | cut -f1))"

echo
echo "==============================================="
echo "✅ 离线包构建完成: $SCRIPT_DIR/$PKG"
echo "   拷到目标机器后执行："
echo "     tar xzf $PKG && cd pandawiki && bash install-offline.sh"
echo "==============================================="
