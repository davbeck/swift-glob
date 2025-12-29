package main

import (
	"fmt"
	"os"
	"path/filepath"
	"time"
)

type BenchmarkCase struct {
	Name    string
	Pattern string
}

var cases = []BenchmarkCase{
	{"basic", "stdlib/public/*/*.swift"},
	{"intermediate", "lib/SILOptimizer/*/*.cpp"},
	{"advanced", "lib/*/[A-Z]*.cpp"},
}

func runBenchmark(basePath string, bc BenchmarkCase) {
	fullPattern := filepath.Join(basePath, bc.Pattern)

	start := time.Now()

	matches, err := filepath.Glob(fullPattern)

	elapsed := time.Since(start)

	count := 0
	if err == nil && matches != nil {
		count = len(matches)
	}

	fmt.Printf("go,%s,%s,%d,%.3f\n", bc.Name, bc.Pattern, count, float64(elapsed.Nanoseconds())/1000000.0)
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintf(os.Stderr, "Usage: %s <search_path>\n", os.Args[0])
		os.Exit(1)
	}

	basePath := os.Args[1]

	for _, bc := range cases {
		runBenchmark(basePath, bc)
	}
}
