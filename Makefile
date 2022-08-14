default: main copy
main: main.go
	go build -o main main.go
copy: main
	cp -f main image-busybox-layer/main
clean:
	rm -fv main
.phony: clean
