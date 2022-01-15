dist: inttest
	mkdir dist
	cp zig-out/bin/skip dist/

inttest: zig-out/bin/skip
	./test.sh

zig-out/bin/skip: unittest
	zig build

unittest: zigmod src/main.zig
	zig build test

zigmod: zig.mod
	zigmod ci
