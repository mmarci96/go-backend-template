package router

import (
	"github.com/gin-gonic/gin"
	"github.com/your-org/go-backend-template/internal/handler"
	"github.com/your-org/go-backend-template/internal/middleware"
)

func New() *gin.Engine {
	r := gin.New()
	r.Use(middleware.Logger())
	r.Use(gin.Recovery())

	r.GET("/health", handler.Health)
	r.GET("/ready", handler.Ready)

	v1 := r.Group("/api/v1")
	{
		items := v1.Group("/items")
		items.GET("", handler.ListItems)
		items.POST("", handler.CreateItem)
		items.GET("/:id", handler.GetItem)
		items.PUT("/:id", handler.UpdateItem)
		items.DELETE("/:id", handler.DeleteItem)
	}

	return r
}
