#!/usr/bin/env bash
# 只打包本地修改的镜像（panda-wiki-api / consumer / admin）
# 其他官方镜像由目标机器 docker compose up 时从互联网自动拉取
#
# 用法：
#   bash build-custom.sh            # 默认本机架构
#   bash build-custom.sh arm64      # 显式指定 arm64
#   bash build-custom.sh amd64      # 显式指定 amd64（建议在 amd64 服务器原生构建，避免 QEMU 模拟慢）
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 解析架构：优先用第一个参数，否则按本机 uname 推断
if [ -n "${1:-}" ]; then
  ARCH="$1"
else
  case "$(uname -m)" in
    x86_64) ARCH="amd64" ;;
    arm64|aarch64) ARCH="arm64" ;;
    *) ARCH="$(uname -m)" ;;
  esac
fi
PLATFORM="linux/${ARCH}"

echo "[1/5] 检查依赖..."
command -v docker >/dev/null || { echo "❌ 请先安装 Docker"; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "❌ 需要 docker compose v2"; exit 1; }
command -v node >/dev/null || { echo "❌ 请先安装 Node.js 18+"; exit 1; }
node_major=$(node -v 2>/dev/null | sed 's/v//' | cut -d. -f1)
[ "${node_major:-0}" -ge 18 ] || { echo "❌ Node 版本过低 ($(node -v))，pnpm/Vite 需要 Node 18+，请升级: https://nodejs.org/"; exit 1; }
command -v pnpm >/dev/null || { echo "❌ 请先安装 pnpm: npm i -g pnpm"; exit 1; }
echo "    架构: ${ARCH} (${PLATFORM})"

echo "[2/5] 构建前端管理台..."
( cd ../web && pnpm install )
( cd ../web/admin && pnpm build )

echo "[3/5] 预拉取 base 镜像 + 构建本地镜像（${PLATFORM}）..."
# 从镜像加速拉取 Dockerfile 依赖的 base 镜像(golang/alpine)，避免 docker.io 访问失败
for base in "golang:1.24.3-alpine" "alpine:3.21"; do
  docker pull --platform "${PLATFORM}" "docker.m.daocloud.io/library/${base}" 2>/dev/null \
    && docker tag "docker.m.daocloud.io/library/${base}" "${base}" \
    || echo "    (跳过 base 预拉: ${base})"
done
# 智能选择：本机原生用 docker build（快），跨架构用 buildx + QEMU（可交叉构建）
LOCAL_ARCH="$(uname -m)"
case "$LOCAL_ARCH" in x86_64) LOCAL_ARCH="amd64";; arm64|aarch64) LOCAL_ARCH="arm64";; esac
if [ "${ARCH}" = "${LOCAL_ARCH}" ]; then
  echo "    本机原生构建（${ARCH}）→ docker build"
  BUILD_CMD=(docker build)
else
  echo "    ⚠️ 跨架构构建（本机 ${LOCAL_ARCH} → 目标 ${ARCH}），使用 buildx + QEMU 模拟，速度较慢"
  BUILD_CMD=(docker buildx build --platform "${PLATFORM}" --load)
fi
"${BUILD_CMD[@]}" -t panda-wiki-api:local -f ../backend/Dockerfile.api ../backend
"${BUILD_CMD[@]}" -t panda-wiki-consumer:local -f ../backend/Dockerfile.consumer ../backend
"${BUILD_CMD[@]}" -t panda-wiki-admin:local -f ../web/admin/Dockerfile.local ../web/admin
# 校验镜像已生成
for img in panda-wiki-api:local panda-wiki-consumer:local panda-wiki-admin:local; do
  docker image inspect "$img" >/dev/null 2>&1 || { echo "❌ 镜像构建失败: $img"; exit 1; }
done

echo "[4/5] 导出本地修改的镜像（仅 3 个）..."
CUSTOM_IMAGES="panda-wiki-api:local panda-wiki-consumer:local panda-wiki-admin:local"
docker save -o "images-custom-${ARCH}.tar" ${CUSTOM_IMAGES}
echo "    → images-custom-${ARCH}.tar ($(du -h "images-custom-${ARCH}.tar" | cut -f1))"

echo "[5/5] 打包..."
PKG="pandawiki-custom-${ARCH}-$(date +%Y%m%d).tar.gz"
STAGE="$(mktemp -d)"
mkdir -p "$STAGE/pandawiki"
cp docker-compose.yml .env.example install-offline.sh "$STAGE/pandawiki/"
mv "images-custom-${ARCH}.tar" "$STAGE/pandawiki/"
cat > "$STAGE/pandawiki/部署说明.txt" <<EOF
PandaWiki 自定义镜像包（${ARCH}）
=================================
本包仅含本地修改的 3 个镜像：
  - panda-wiki-api:local
  - panda-wiki-consumer:local
  - panda-wiki-admin:local

其他官方镜像（postgres/redis/nats/minio/qdrant/raglite/caddy/app）
由 docker compose up 时从 chaitin-registry 自动拉取，目标机器需能访问互联网。

部署步骤：
  bash install-offline.sh
（脚本会 docker load 本地镜像 + docker compose up，缺失的官方镜像自动 pull）
EOF
tar -czf "$PKG" -C "$STAGE" pandawiki
rm -rf "$STAGE"
echo "    → ${PKG} ($(du -h "$PKG" | cut -f1))"

echo
echo "==============================================="
echo "✅ 自定义镜像包: ${SCRIPT_DIR}/${PKG}"
echo "   仅含 api/consumer/admin（本地修改的 3 个）"
echo "   拷到目标服务器后："
echo "     tar xzf ${PKG} && cd pandawiki && bash install-offline.sh"
echo "   （其他镜像服务器联网自动拉取）"
echo "==============================================="
