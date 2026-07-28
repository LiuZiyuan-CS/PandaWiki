# Changelog

本项目基于 [chaitin/PandaWiki](https://github.com/chaitin/PandaWiki) 开源版进行二次开发与本地化部署。以下记录主要改动。

## [Unreleased] - 2026-07-27

### 🚀 部署：完整本地 Docker 编排

新增 `deploy/` 目录，提供与官方生产架构一致的全套本地部署（Apple Silicon / arm64 原生）。

- **后端**：`api` / `consumer` 使用仓库源码本地构建（`Dockerfile.api` / `Dockerfile.consumer`），便于即时验证代码改动
- **前端管理台**：`nginx` 改为本地构建（`web/admin/Dockerfile.local`，基于官方 nginx 镜像替换 dist），使前端改动可生效
- **依赖服务**：postgres-zhparser（中文分词）、redis、nats(JetStream)、minio、qdrant、raglite(RAG)、caddy(统一入口)、app(Next.js 用户站)
- 固定子网 `169.254.15.0/24`（后端代码硬编码依赖）
- 文档：`deploy/README.md`

### 🐛 Bug 修复

#### 1. License 授权时间显示异常（`1970-01-01` + 误报"已到期"）
- **现象**：管理台「关于」弹窗显示 `1970-01-01 ~ 1970-01-01` 并提示"授权已到期"
- **根因**：后端 `GetLicense` 返回 `started_at:0, expired_at:0`（语义"永久"），前端把 `0` 当 Unix 时间戳渲染成 1970 并误判到期
- **改动**：
  - 后端 `handler/v1/license.go`：返回远期区间（2024-01-01 ~ 2100-01-01）
  - 前端 `components/Sidebar/AuthTypeModal.tsx`：识别 `expired_at<=0` 显示「永久有效」

#### 2. 文档「前台查看」跳转失败（`No routes matched`）
- **现象**：点「前台查看」报 `No routes matched location "/xxx"`，请求被 nginx SPA fallback 返回 `index.html`
- **根因**：`wikiUrl` 计算存在空数组 truthy 陷阱——`if (ssl_ports)` 对 `[]` 为真但内部什么都不做，导致 `wikiUrl` 为空字符串，退化成 admin 域名相对路径
- **改动**：`pages/document/layout/index.tsx`、`pages/document/editor/edit/Header.tsx`：`if (ssl_ports)` → `if (ssl_ports && ssl_ports.length > 0)`（与已有的正确实现 `components/Header/index.tsx` 对齐）

### ✨ 新功能：源文档（原始上传文件）下载

> 场景：用户上传 docx/pdf 等文档转成知识库内容后，希望能下载回原始文件。

#### 3. 单篇源文档下载
- 新增 `GET /api/v1/node/source?id={node_id}`：流式下载节点对应的原始上传文件
- 数据层：`NodeMeta` + `CreateNodeReq` 新增 `source_object_key` 字段（复用 meta jsonb，免改表）；上传时记录源文件在 minio 的 object key
- 文件名优先取上传时的原始文件名（minio 元数据），RFC 5987 编码支持中文
- 前端：文档编辑器「导出」菜单新增「下载源文件」（仅当节点有源文件时显示）

#### 4. 批量下载源文档（打包 zip）
- 新增 `POST /api/v1/node/batch_source`：接收节点 id 列表，打包 zip 流式返回
- 自动跳过没有源文件的节点；同名文件自动编号（`xxx.docx` / `xxx(2).docx`）
- `NodeListItemResp` 新增 `source_object_key`，列表接口暴露该字段
- 前端：文档列表批量操作栏新增「下载源文件」按钮

#### 5. 源文档格式徽章（列表可视化标识）
- 文档列表项名称旁显示彩色格式徽章（复用现有「MD」徽章模式）
- 按格式上色：`DOCX`蓝 / `PDF`红 / `PPTX`橙 / `XLSX`绿，hover 提示「含原始上传文件」
- 无源文件的文档不显示徽章

### 📁 涉及文件

**后端（backend/）**
- `domain/node.go`：`NodeMeta` / `CreateNodeReq` / `NodeListItemResp` 加 `source_object_key`；新增 `BatchDownloadSourceReq`
- `repo/pg/node.go`：`GetList` / `GetNodeListByStatus` 的 SQL 提取 `source_object_key`；`Create` 写入该字段
- `usecase/node.go`：新增 `DownloadSource` / `GetDownloadableNodes` / `WriteSourceZip`
- `handler/v1/node.go`：新增 `GET /source`、`POST /batch_source` 接口及路由
- `handler/v1/license.go`：修复 license 时间返回

**前端（web/admin/）**
- `request/types.ts`：`DomainNodeMeta` / `DomainCreateNodeReq` / `DomainNodeListItemResp` 加 `source_object_key`
- `api/type.ts`：`ITreeItem` 加 `source_object_key`
- `utils/drag.ts`：`convertToTree` 透传 `source_object_key`
- `components/Drag/DragTree/TreeItem.tsx`：格式徽章（`getSourceFileExt` / `getSourceFileColor`）
- `pages/document/editor/edit/Header.tsx`：导出菜单「下载源文件」+ `wikiUrl` 修复
- `pages/document/layout/index.tsx`：`wikiUrl` 修复
- `pages/document/layout/DocPageList/DocPageListContent.tsx`：批量栏「下载源文件」按钮
- `pages/document/layout/DocPageList/DocPageListContainer.tsx`：批量下载逻辑
- `pages/document/component/AddDocByType/`：上传导入时记录 `sourceObjectKey` 数据流
- `components/Sidebar/AuthTypeModal.tsx`：license「永久有效」展示

**部署（deploy/）**
- `docker-compose.yml` / `.env` / `README.md`
- `web/admin/Dockerfile.local`

---

### 远程仓库
- `origin` 已从 `chaitin/PandaWiki` 切换至 `https://github.com/LiuZiyuan-CS/PandaWiki.git`
