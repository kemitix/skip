# skip

Skip part of a file.

![GitHub release (latest by date)](
https://img.shields.io/github/v/release/kemitix/skip?style=for-the-badge)
![GitHub Release Date](
https://img.shields.io/github/release-date/kemitix/skip?style=for-the-badge)

As `head` will show the top of a file after a number of line,
 so `skip` will do the opposite, and not show the top of the file,
 but will show the rest.

Additionally, it can check for whole lines matching,
 or for a token being present on the line.

## Usage

### Skip a fixed number of lines

This example reads the file from stdin.

File: `input.txt`

```text
line 1
line 2
line 3
line 4
```

```bash
skip 2 < input.txt
```

Will output:

```text
line 3
line 4
```

### Skip until a number of matching lines

This example reads the named file.

File: `input.txt`

```text
alpha
beta
alpha
alpha
gamma
alpha
```

```bash
skip 2 --line alpha input.txt
```

Will output:

```text
alpha
gamma
alpha
```

### Skip lines until a number of tokens as seen

This example reads the file from stdin.

File: `input.txt`

```text
Lorem ipsum dolor sit amet, 
consectetur adipiscing elit, 
sed do eiusmod tempor incididunt 
ut labore et dolore magna aliqua. 
Ut enim ad minim veniam, 
quis nostrud exercitation ullamco 
laboris nisi ut aliquip ex ea 
commodo consequat. 
```

```bash
cat input.txt | skip 2 --token dolor
```

Will output:

```text
Ut enim ad minim veniam, 
quis nostrud exercitation ullamco 
laboris nisi ut aliquip ex ea 
commodo consequat. 
```

It matches the first `dolor` on line 1,
 and the second on line 4 as part of the word `dolore`.
