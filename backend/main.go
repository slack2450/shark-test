package main

import (
	"encoding/json"
	"io"
	"net/http"
	"os"
	"slices"
	"sort"
	"strconv"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
)

// Create a global variable to store the packs
var packs []int

func init() {
	// Dynamically load packs from json file
	jsonFile, err := os.Open("packs.json")

	// Panic if pack file is not found / cannot be opened
	if err != nil {
		panic(err)
	}

	// Read the json file
	byteValue, _ := io.ReadAll(jsonFile)

	// Close the file
	jsonFile.Close()

	// Unmarshal the json into a slice of ints
	json.Unmarshal(byteValue, &packs)

	// Check length of packs is greater than 0
	if len(packs) == 0 {
		panic("No packs found")
	}

	// Sort the packs
	sort.Ints(packs[:])
	// Remove duplicates
	packs = slices.Compact[[]int, int](packs)

	println("Packs loaded")
}

func getPacks(c *gin.Context) {
	count, err := strconv.Atoi(c.Param("count"))

	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"message": "Invalid count",
		})
		return
	}

	// Use a greedy algorithm to solve this problem
	// We start with the largest pack and keep subtracting the pack size from the count until we reach 0
	// We will then move to the next pack size and repeat the process

	// Round count up to the smallest pack size
	// This is to ensure that we don't send more items than necessary to fulfill the order
	count = (count + packs[0] - 1) / packs[0] * packs[0]

	// We will keep track of the number of packs of each size we use
	packCounts := make(map[int]int)

	// We will start with the largest pack
	for i := len(packs) - 1; i >= 0; i-- {
		pack := packs[i]
		// We will keep subtracting the pack size from the count until we reach 0
		for count >= pack {
			count -= pack
			packCounts[pack]++
		}
	}

	// Return the pack counts
	c.JSON(http.StatusOK, packCounts)
}

func main() {

	// Create a new router
	router := gin.Default()

	// Add CORS middleware to allow localhost:5173 to access the server
	config := cors.DefaultConfig()
	config.AllowOrigins = []string{"http://localhost:5173"}
	router.Use(cors.New(config))

	// Add a route to get the packs
	router.GET("/packs/:count", getPacks)

	// Run the server on port 8080
	router.Run(":8080")
}
