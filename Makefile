default: tool copy
tool: tool.go
	go build -o tool tool.go
copy: tool
	cp -f tool image-busybox-layer/tool
clean:
	rm -fv tool
.phony: clean
