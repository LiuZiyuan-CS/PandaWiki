package v1

import (
	"net/http"

	"github.com/labstack/echo/v4"

	"github.com/chaitin/panda-wiki/domain"
	"github.com/chaitin/panda-wiki/handler"
	"github.com/chaitin/panda-wiki/log"
)

// LicenseHandler 开源版补充的 license 接口。
// 官方 /api/v1/license 路由在闭源 pro 中，开源版未实现，导致前端拿不到 edition、UI 一直显示“专业版可用”。
// 这里补一个 GET 接口，固定返回商业版(Business)，使前端 UI 解除限制提示，且与后端放开的状态一致。
type LicenseHandler struct {
	*handler.BaseHandler
	logger *log.Logger
}

func NewLicenseHandler(echo *echo.Echo, baseHandler *handler.BaseHandler, logger *log.Logger) *LicenseHandler {
	h := &LicenseHandler{
		BaseHandler: baseHandler,
		logger:      logger.WithModule("handler.v1.license"),
	}
	// 不挂鉴权：edition 非敏感信息，确保前端任意时机都能拿到版本号
	echo.GET("/api/v1/license", h.GetLicense)
	// 开源版没有 pro 闭源路由(/api/pro/v1/*)，用 catch-all 返回空响应，避免前端页面 404 报错
	echo.Any("/api/pro/v1/*", h.ProStub)
	return h
}

// GetLicense 返回当前版本信息
//
//	@Summary		Get license
//	@Description	get license
//	@Tags			license
//	@Produce		json
//	@Success		200	{object}	domain.LicenseResp
//	@Router			/api/v1/license [get]
func (h *LicenseHandler) GetLicense(c echo.Context) error {
	// 开源版无真实授权。返回一个远期有效区间，使前端「关于」弹窗正常显示授权时间、不误报到期。
	// 注：前端(AuthTypeModal)已兼容 expired_at<=0 表示「永久有效」；此处给远期值，仅为官方前端镜像(不可热改)的兜底。
	return h.NewResponseWithData(c, &domain.LicenseResp{
		Edition:   3,          // consts.LicenseEditionBusiness
		StartedAt: 1704067200, // 2024-01-01 00:00:00 UTC
		ExpiredAt: 4102444800, // 2100-01-01 00:00:00 UTC（远期，表示永久有效）
		State:     1,          // 有效
	})
}

// ProStub 开源版没有 pro 闭源功能(token/用户组/投稿/评论审核/node发布 等 /api/pro/v1/* 路由)，
// 用 catch-all 返回空成功响应，避免前端页面加载时 404 报错。
// 注意：这只是消除报错，对应功能并不真正可用(业务逻辑在闭源 pro 中)。
func (h *LicenseHandler) ProStub(c echo.Context) error {
	if c.Request().Method == http.MethodGet {
		return h.NewResponseWithData(c, []any{}) // 列表类接口返回空数组
	}
	return h.NewResponseWithData(c, map[string]any{}) // create/delete/update 返回空对象
}
