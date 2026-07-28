<p align="center">
  <img src="/images/banner.png" width="400" />
</p>

# PandaWiki（二次开发 fork）

基于 [chaitin/PandaWiki](https://github.com/chaitin/PandaWiki) 开源版进行二次开发与本地化部署。PandaWiki 是一款 AI 大模型驱动的**开源知识库搭建系统**，帮助你快速构建智能化的产品文档、技术文档、FAQ、博客系统，提供 AI 创作、AI 问答、AI 搜索等能力。

## 🔧 与上游的主要差异

> 详细改动见 [CHANGELOG.md](./CHANGELOG.md)

- **放开开源版限制**：知识库/管理员/文档数量上限解除，SSO 并发限流解除，统计时间范围全部可用，专业版功能开关全部开启
- **补全 license 接口**：开源版补 `GET /api/v1/license`，前端不再误报「专业版可用 / 授权已到期」
- **源文档下载**：上传的 docx/pdf 等原始文件可重新下载（单篇 / 批量 zip / 列表格式徽章）
- **本地部署**：提供完整的 Docker Compose 编排与一键部署脚本

## 🚀 本地部署

### 环境要求

- Docker 20.x+（含 compose v2）。macOS 推荐 [OrbStack](https://orbstack.dev/)
- Node.js 20+ 与 pnpm（构建前端用）
- 首次拉取官方依赖镜像需能访问 `chaitin-registry.cn-hangzhou.cr.aliyuncs.com`

### 一键部署

根据你的平台选择脚本：

```bash
# Apple Silicon (M1/M2/M3)
bash deploy/deploy-arm64.sh

# x86_64 (Intel mac / Linux 服务器)
bash deploy/deploy-amd64.sh
```

脚本会自动：检查依赖 → 生成 `.env` → 构建前端 → 构建后端镜像（本地源码）→ 启动全部服务。

完成后访问：

```
管理后台：https://localhost:2443   （自签证书，浏览器接受风险即可）
账号：admin
密码：见 deploy/.env 的 ADMIN_PASSWORD
```

### 手动部署

```bash
cd deploy
cp .env.example .env          # 按需修改密码
cd ../web && pnpm install && cd admin && pnpm build   # 构建前端
cd ../../deploy && docker compose up -d --build       # 构建后端镜像并启动
```

### 架构

```
caddy(80/443 统一入口) → app(Next.js 用户站) / nginx(admin 管理台)
api(本地源码) + consumer(本地源码) → postgres-zhparser / redis / nats / minio / qdrant / raglite(RAG)
```

- 后端 `api` / `consumer` 从仓库源码构建，改代码后 `docker compose up -d --build api consumer` 即可生效
- 管理台 `nginx` 从本地源码构建，改前端后需重新 `pnpm build` 并 `docker compose up -d --build nginx`
- 其余依赖服务（postgres/redis/nats/minio/qdrant/raglite/caddy/app）使用官方镜像

## 🤖 配置 AI 模型（首次使用必做）

PandaWiki 是 AI 驱动的，未配置模型时创建知识库 / AI 问答 / 向量化会失败（提示 `no default embedding model available`）。

1. 登录管理后台，按提示「配置 AI 模型」
2. 至少配置 1 个 **embedding** 模型（设为默认）+ 1 个 **LLM**
3. 推荐使用 [百智云模型广场](https://baizhi.cloud/) 或任意兼容 OpenAI 的 API

## 🛠 常用运维命令

```bash
cd deploy
docker compose ps                # 查看服务状态
docker compose logs -f api       # 跟踪 api 日志
docker compose restart api       # 重启 api
docker compose down              # 停止（保留数据）
docker compose down && rm -rf data  # ⚠️ 停止并清空全部数据
```

## 📁 项目结构

```
backend/   Go 后端（api / consumer / migrate）
web/admin/ React + Vite 管理后台
web/app/   Next.js 用户前台
deploy/    本地 Docker 部署编排与脚本
```

## 🙏 致谢

- 上游项目：[chaitin/PandaWiki](https://github.com/chaitin/PandaWiki)

## 📝 许可证

继承自上游，采用 [AGPL-3.0](./LICENSE)。
