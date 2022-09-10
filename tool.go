package main

import (
	"flag"
	"log"
	"runtime"
	"time"
)

const mb = 1024 * 1024

func main() {
	var memoryMb int
	var hangWithLabel string
	flag.IntVar(&memoryMb, "mb", 0, "allocate memory, in MB")
	flag.StringVar(&hangWithLabel, "hang", "", "hang on!")
	flag.Parse()
	if memoryMb > 0 {
		for {
			allocate(memoryMb)
			readMemStats()
			log.Printf("run garbage collector")
			time.Sleep(1 * time.Second)
			runtime.GC()
			readMemStats()
			time.Sleep(1 * time.Second)
		}
	}
	if hangWithLabel != "" {
		log.Print("hang on!")
		for {
			time.Sleep(1 * time.Second)
		}
	}
}

func allocate(memoryMb int) {
	log.Printf("allocate %dMB of memory", memoryMb)
	size := memoryMb * 1024 * 1024
	block := make([]uint8, size, size)
	// do something with memory to ensure that this code is not optimized-out.
	n := 0
	for i := 0; i < cap(block); i++ {
		block[i] = 1
		n++
	}
	log.Printf("allocated %d bytes", n)
}

func readMemStats() {
	stats := runtime.MemStats{}
	runtime.ReadMemStats(&stats)
	log.Printf("heap %d mb, sys %d mb", stats.HeapAlloc/mb, stats.Sys/mb)
}
