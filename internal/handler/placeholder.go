package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// Item is a placeholder domain type. Replace with your real model.
type Item struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}

func ListItems(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"items": []Item{}})
}

func GetItem(c *gin.Context) {
	id := c.Param("id")
	c.JSON(http.StatusOK, gin.H{"item": Item{ID: id, Name: "placeholder"}})
}

func CreateItem(c *gin.Context) {
	var item Item
	if err := c.ShouldBindJSON(&item); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"item": item})
}

func UpdateItem(c *gin.Context) {
	id := c.Param("id")
	var item Item
	if err := c.ShouldBindJSON(&item); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	item.ID = id
	c.JSON(http.StatusOK, gin.H{"item": item})
}

func DeleteItem(c *gin.Context) {
	c.Status(http.StatusNoContent)
}
