#!/usr/bin/env bash

set -e

echo "Unit tests..."
zig build test

echo "Build..."
zig build

echo -n "Created: "
ls zig-out/bin/skip
export PATH=$PWD/zig-out/bin/:$PATH

echo "> skip a line when reading from stdin"
INPUT=$(cat<<EOF
line 1
line 2
EOF
)
echo "line 2" > test.expect
echo "$INPUT" | skip 1 > test.out
diff --brief test.expect test.out

echo "> skip a line when reading from a file"
cat<<EOF > test.in
line 1
line 2
EOF
echo "line 2" > test.expect
skip 1 test.in > test.out
diff --brief test.expect test.out

echo "> skip until 2 matching lines seen"
cat<<EOF > test.in
alpha
beta
alpha
gamma
EOF
echo "gamma" > test.expect
skip 2 test.in --line alpha > test.out
diff --brief test.expect test.out

echo "> skip lines until 2 tokens seen"
cat<<EOF > test.in
Lorem ipsum dolor sit amet, 
consectetur adipiscing elit, 
sed do eiusmod tempor incididunt 
ut labore et dolore magna aliqua. 
Ut enim ad minim veniam, 
quis nostrud exercitation ullamco 
laboris nisi ut aliquip ex ea 
commodo consequat. 
EOF
cat<<EOF > test.expect
Ut enim ad minim veniam, 
quis nostrud exercitation ullamco 
laboris nisi ut aliquip ex ea 
commodo consequat. 
EOF
skip 2 test.in --token dolor > test.out
diff --brief test.expect test.out

rm test.in test.out test.expect

echo done
