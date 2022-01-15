#!/usr/bin/env bash

set -e

SKIP="./zig-out/bin/skip"
DIFF="diff -u --color"

if test ! -x $SKIP ; then
    echo "File missing: $SKIP - try 'zig build'"
    exit 1
fi

echo "> skip a line when reading from stdin"
INPUT=$(cat<<EOF
line 1
line 2
EOF
)
echo "line 2" > test.expect
echo "$INPUT" | $SKIP 1 > test.out
$DIFF test.expect test.out
rm test.expect test.out

echo "> skip a line when reading from a file"
cat<<EOF > test.in
line 1
line 2
EOF
echo "line 2" > test.expect
$SKIP 1 test.in > test.out
$DIFF test.expect test.out
rm test.expect test.out

echo "> skip until 2 matching lines seen"
cat<<EOF > test.in
alpha
beta
alpha
alpha
gamma
alpha
EOF
cat<<EOF > test.expect
alpha
gamma
alpha
EOF
$SKIP 2 test.in --line alpha > test.out
$DIFF test.expect test.out
rm test.in test.expect test.out

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
$SKIP 2 test.in --token dolor > test.out 2
$DIFF test.expect test.out
rm test.in test.expect test.out

echo "> handle unknown parameter with simple error message"
cat<<EOF > test.expect.err
Invalid argument '--foo'
EOF
cat<<EOF > test.expect
EOF
touch test.out test.err
$SKIP --foo > test.out 2> test.err
$DIFF test.expect test.out
$DIFF test.expect.err test.err
rm test.expect test.out
rm test.expect.err test.err

echo "> handle ignore-extra when token is missing"
cat<<EOF > test.expect.err
Error: --ignore-extras requires --token
EOF
cat<<EOF > test.expect
EOF
touch test.out test.err
$SKIP --ignore-extras > test.out 2> test.err
$DIFF test.expect test.out
$DIFF test.expect.err test.err
rm test.expect test.out
rm test.expect.err test.err

echo "> skip lines until 4 tokens seen - ignored extra tokens on same line"
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
quis nostrud exercitation ullamco 
laboris nisi ut aliquip ex ea 
commodo consequat. 
EOF
$SKIP 4 test.in --token m --ignore-extras > test.out
$DIFF test.expect test.out
rm test.in test.expect test.out

echo done
