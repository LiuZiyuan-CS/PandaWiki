package domain

import (
	"context"
	"encoding/json"
)

const ContextKeyEditionLimitation contextKey = "edition_limitation"

type BaseEditionLimitation struct {
	MaxKb                  int   `json:"max_kb"`                     // 知识库站点数量
	MaxNode                int   `json:"max_node"`                   // 单个知识库下文档数量
	MaxSSOUser             int   `json:"max_sso_users"`              // SSO认证用户数量
	MaxAdmin               int64 `json:"max_admin"`                  // 后台管理员数量
	AllowAdminPerm         bool  `json:"allow_admin_perm"`           // 支持管理员分权控制
	AllowCustomCopyright   bool  `json:"allow_custom_copyright"`     // 支持自定义版权信息
	AllowCommentAudit      bool  `json:"allow_comment_audit"`        // 支持评论审核
	AllowAdvancedBot       bool  `json:"allow_advanced_bot"`         // 支持高级机器人配置
	AllowWatermark         bool  `json:"allow_watermark"`            // 支持水印
	AllowCopyProtection    bool  `json:"allow_copy_protection"`      // 支持内容复制保护
	AllowOpenAIBotSettings bool  `json:"allow_open_ai_bot_settings"` // 支持问答机器人
	AllowMCPServer         bool  `json:"allow_mcp_server"`           // 支持创建MCP Server
	AllowNodeStats         bool  `json:"allow_node_stats"`           // 支持文档统计
}

// 开源版默认限制。
// 原官方值：MaxKb:1 / MaxAdmin:1 / MaxNode:300，且所有功能开关(Allow*)默认 false（专业版功能）。
// 本仓库基于开源版做二次开发，已放开全部数量上限与功能开关。
// 注意各数量检查点是 `count >= Max`，不能填 0，否则会变成一个都创建不了。
var baseEditionLimitationDefault = BaseEditionLimitation{
	MaxKb:      1 << 30, // 知识库数量上限
	MaxAdmin:   1 << 30, // 后台管理员数量上限
	MaxNode:    1 << 30, // 单个知识库文档数量上限
	MaxSSOUser: 1 << 30, // SSO 认证用户数量上限（原默认 0 = 完全禁用）

	// 以下为原专业版功能开关，本仓库已全部开启
	AllowAdminPerm:         true, // 管理员分权控制
	AllowCustomCopyright:   true, // 自定义版权信息
	AllowCommentAudit:      true, // 评论审核
	AllowAdvancedBot:       true, // 高级机器人配置
	AllowWatermark:         true, // 水印
	AllowCopyProtection:    true, // 内容复制保护
	AllowOpenAIBotSettings: true, // 问答机器人(OpenAI API Bot)
	AllowMCPServer:         true, // 创建 MCP Server
	AllowNodeStats:         true, // 文档统计
}

func GetBaseEditionLimitation(c context.Context) BaseEditionLimitation {

	edition, ok := c.Value(ContextKeyEditionLimitation).([]byte)
	if !ok {
		return baseEditionLimitationDefault
	}

	var editionLimitation BaseEditionLimitation
	if err := json.Unmarshal(edition, &editionLimitation); err != nil {
		return baseEditionLimitationDefault
	}

	return editionLimitation
}

// LicenseResp 对应前端 DomainLicenseResp。开源版补的接口，固定返回商业版(Business=3)，使前端 UI 解除所有限制提示。
// 注：官方 /api/v1/license 路由在闭源 pro 中，开源版未实现，前端因此拿不到 edition、UI 一直显示“专业版可用”。
type LicenseResp struct {
	Edition   int   `json:"edition"`    // consts.LicenseEdition: 3=Business
	ExpiredAt int64 `json:"expired_at"` // 过期时间(秒)，0=永久
	StartedAt int64 `json:"started_at"` // 开始时间(秒)
	State     int   `json:"state"`      // 1=有效
}
