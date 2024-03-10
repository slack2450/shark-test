package main

import (
	"context"
	"strconv"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
)

// Create a global variable to store the packs
var packs = []uint64{
	250,
	500,
	1000,
	2000,
	5000,
}

func HandleRequest(ctx context.Context, request events.APIGatewayV2HTTPRequest) (map[uint64]uint64, error) {
	// Use a greedy algorithm to solve this problem
	// We start with the largest pack and mod the count by the pack size
	// This will give us the remainder
	// We will then move to the next pack size and repeat the process
	count, err := strconv.ParseUint(request.PathParameters["count"], 10, 64)

	if err != nil {
		return nil, err
	}

	// Round count up to the smallest pack size
	// This is to ensure that we don't send more items than necessary to fulfill the order
	count = (count + packs[0] - 1) / packs[0] * packs[0]

	// We will keep track of the number of packs of each size we use
	packCounts := make(map[uint64]uint64)

	// We will start with the largest pack
	for i := len(packs) - 1; i >= 0; i-- {
		pack := packs[i]
		// Divide the count by the pack size
		// This will give us the number of packs of the current size that we need
		// Only add the pack count to the map if it is greater than 0
		packCount := count / pack
		if packCount > 0 {
			packCounts[pack] = packCount
		}
		// Mod the count by the pack size to get the remainder
		count = count % pack
	}

	// Return the pack counts
	return packCounts, nil
}

func main() {
	lambda.Start(HandleRequest)
}
