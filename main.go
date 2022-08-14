package main

import (
	"flag"
	"log"
)

func main() {
	var memoryMb int
	flag.IntVar(&memoryMb, "mb", 0, "allocate memory, in MB")
	flag.Parse()
	if memoryMb > 0 {
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
}
