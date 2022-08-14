main: main.go
	go build -o main main.go
clean:
	rm -fv main
.phony: clean
