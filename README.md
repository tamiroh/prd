# prd

A command-line utility written in Koka that prints the shortest repeating
prefix of each input line. Incomplete repetitions are allowed.

```sh
$ echo 'abcabcab' | prd
abc
```

## Build

Requires Koka 3.2.9 and Make.

```sh
make
make install PREFIX="$HOME/.local"
```

## Usage

```text
prd [OPTION]... [FILE]

-h, --help     Display help
-V, --version  Display version
-l, --length   Print the period length in Unicode code points
-s, --strict   Require complete repetitions
--            End options
```

Read standard input when FILE is omitted or is `-`. Empty lines are preserved
(`0` with `--length`). Short options can be combined, such as `-sl`.

```sh
printf 'abcabcab\naaaaaa\n' | prd  # Prints abc and a on separate lines
echo 'abcabcab' | prd --length   # 3
echo 'abcabcab' | prd --strict   # abcabcab
echo 'abcabcabc' | prd -sl       # 3
prd input.txt
prd < input.txt
```

File arguments are read into memory; redirect standard input for line-by-line
processing. Errors are printed to standard output and do not set a nonzero
exit status.
