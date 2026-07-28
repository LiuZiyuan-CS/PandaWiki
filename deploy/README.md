# PandaWiki 完整本地容器部署（全套）

基于本仓库源码的**全套** PandaWiki 本地部署：后端 api/consumer 用本地源码构建（可即时验证代码改动），前端 admin/app、RAG(raglite)、向量库(qdrant) 等使用官方 arm64 镜像。架构与官方生产部署一致。

## 架构（12 个服务，固定子网 169.254.15.0/24）

```
                         ┌──────────────────────────────┐
   浏览器 ──https:2443──▶│ nginx (admin 管理台 SPA)      │──┐
                         │  panda-wiki-nginx (.111)      │  │
                         └──────────────────────────────┘  │ 反代 /api
                         ┌──────────────────────────────┐  ▼
   知识库站点 ──80/443──▶│ caddy (动态站点路由, host 网络)│▶ api (本地源码构建 .2:8000)
                         └──────────────────────────────┘  │
                         ┌──────────────────────────────┐  │
                         │ app (Next.js 用户站 .112)     │  │
                         └──────────────────────────────┘  │
                                                           ▼
   ┌─────────────┐  ┌─────────┐  ┌───────┐  ┌──────────┐  ┌──────────┐
   │ postgres    │  │ redis   │  │ nats  │  │ minio    │  │ qdrant   │
   │ zhparser .10│  │ .11     │  │ .13   │  │ (S3) .12 │  │ 向量 .14 │
   └──────┬──────┘  └─────────┘  └───┬───┘  └────┬─────┘  └────┬─────┘
          │                          │            │             │
          │            ┌─────────────┴────────────┴─────────────┘
          └───────────▶│ raglite (RAG 服务 .18:5050)
                        │   consumer (本地源码构建 .3)
                        └─ 任何doc/crawler (.17，可选，默认关闭)
```

> **注意：** 后端代码（`backend/config/config.go`）硬编码依赖子网 `169.254.15.x`：NATS=`.13`、RAG=`.18`、minio=`.12` 等。故各服务用固定 IP，请勿改 `SUBNET_PREFIX`。

## 快速开始

```bash
cd deploy

# 一键启动全套（crawler 默认不启动）
docker compose up -d

# 单独重建并启动后端（改了 backend 代码后用）
docker compose up -d --build api consumer

# 查看全部服务
docker compose ps

# 跟踪日志
docker compose logs -f api
docker compose logs -f consumer
docker compose logs -f raglite
```

## 访问地址

| 入口 | 地址 | 说明 |
|------|------|------|
| **管理后台** | `https://localhost:2443` | admin SPA（自签证书，浏览器接受风险即可） |
| 账号 | `admin` | 密码见 `.env` 的 `ADMIN_PASSWORD` |
| 知识库站点 | `http://localhost` (80) | caddy 按域名路由，需配 hosts 或建库时指定端口 |
| Postgres | `localhost` 未对外映射 | 进容器：`docker exec -it panda-wiki-postgres psql -U panda-wiki -d panda-wiki` |
| MinIO | 未对外映射 | 库 `panda-wiki`、`raglite_v2`；bucket `static-file`、`raglite` |

> 后端 api 只在内部网络 `169.254.15.2:8000`，**不对外暴露端口**，通过 nginx 反代访问。如需直连调试，临时加端口映射或 `docker exec` 进容器。

## 首次使用：必须配置 AI 模型

PandaWiki 是 AI 驱动的。**不配模型，创建知识库/AI 问答/向量化都会失败**（raglite 报 `no default embedding model available`）。

1. 打开 `https://localhost:2443` 登录
2. 按提示「配置 AI 模型」：至少配 1 个 **embedding** 模型（设为默认）+ 1 个 **LLM**
3. 推荐用 [百智云模型广场](https://baizhi.cloud/) 或任意兼容 OpenAI 的 API

> 模型记录写入 `raglite_v2.ai_models` 表。配置后即可创建知识库、导入文档、AI 问答。

## 配置（`.env`）

| 变量 | 说明 |
|------|------|
| `SUBNET_PREFIX` | 容器网段（默认 `169.254.15`，勿改） |
| `ADMIN_PORT` | 管理后台端口（默认 `2443`） |
| `ADMIN_PASSWORD` | admin 登录密码 |
| `POSTGRES_PASSWORD` / `NATS_PASSWORD` / `REDIS_PASSWORD` / `S3_SECRET_KEY` / `QDRANT_API_KEY` / `JWT_SECRET` | 各中间件凭据 |

## 数据持久化

全部数据在 `deploy/data/`（postgres / redis / minio / nats / qdrant / raglite / caddy / nginx）。

```bash
docker compose down              # 停止，保留数据
docker compose down && rm -rf data  # ⚠️ 停止并清空全部数据
```

## 关于 api/consumer 用本地源码

- `api` / `consumer` 通过 `build: ../backend` 从仓库源码构建（`Dockerfile.api` / `Dockerfile.consumer`），arm64 原生。
- **改了后端代码后**：`docker compose up -d --build api consumer` 即可生效（用于测试你的改动、排查 bug）。
- 其余 9 个服务用官方 arm64 镜像（本机已缓存，无需联网）。

## 可选：文档爬虫（anydoc）

用于「按 URL / Sitemap 导入文档」。镜像较大且需联网拉取，默认关闭：

```bash
docker compose --profile crawler up -d crawler
```

## 常见问题

- **创建知识库报 `no default embedding model available`** → 正常，见上文「配置 AI 模型」。
- **管理台打不开** → 确认 `ADMIN_PORT`(2443) 未被占用；旧部署已停（`docker ps | grep panda-wiki` 应只有本套）。
- **80 端口冲突** → caddy 用 host 网络监听 80/443，确保本机无其他 web 服务占用。
- **改后端代码不生效** → 必须 `--build`，见上文。

## 调试小抄

```bash
# 看 api 实时请求日志
docker compose logs -f api | grep REQUEST

# 直连各数据库
docker exec -it panda-wiki-postgres psql -U panda-wiki -d panda-wiki      # 业务库
docker exec -it panda-wiki-postgres psql -U panda-wiki -d raglite_v2      # RAG 库（ai_models/datasets/chunks）

# 查 NATS stream（raglite 自动建的 raglite_events/raglite_tasks）
docker run --rm --network deploy_panda-wiki natsio/nats-box \
  nats stream ls --server=nats://panda-wiki:bef94e2f592e4d2f0de62a14af56c012@panda-wiki-nats:4222
```
