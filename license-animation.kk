module license-animation

import std/os/process
import std/os/file
import std/os/path

fun shell-quote(text : string) : string
  "'" ++ text.split("'").join("'\"'\"'") ++ "'"

fun safe-label(text : string) : string
  text.list.map(fn(c)
    if c.int < 32 || (c.int >= 127 && c.int < 160) then ' ' else c
  ).string

val screen-script = r#"#!/bin/sh
cleanup() {
  printf '\033[0m\033[?7h\033[?25h\033[?1049l'
  rm -f -- "$0"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP
size() {
  set -- $(stty size < /dev/tty 2>/dev/null)
  rows=${1:-24}
  cols=${2:-80}
  case $rows in ''|*[!0-9]*|0) rows=24;; esac
  case $cols in ''|*[!0-9]*|0) cols=80;; esac
}
trap size WINCH
size
printf '\033[?1049h\033[?25l\033[?7l'
draw() {
  age=$((frame - $4))
  [ "$age" -ge 0 ] || return 0
  row=$((rows - age * rows / $5))
  [ "$row" -gt 0 ] || return 0
  room=$((cols - $2 - 1))
  [ "$room" -gt 0 ] || room=1
  drift=$((age * ($3 % 5 + 1)))
  col=$((1 + ($3 + drift) % room))
  printf '\033[%s;%sH\033[%sm%s\033[0m' "$row" "$col" "$6" "$1"
}
"#

fun burst(labels : list<string>) : string
  val commands = labels.map-indexed fn(i, label)
    val seed = (i + 1) * 7919
    "  draw " ++ shell-quote(label) ++ " " ++ (label.count * 2).show ++ " " ++ seed.show ++
      " " ++ (seed % 8).show ++ " " ++ (18 + seed % 3 * 5).show ++ " " ++ (31 + seed % 6).show
  "frame=0\nwhile [ \"$frame\" -lt 36 ]; do\n" ++
    "  printf '\\033[H\\033[2J'\n" ++
    commands.join("\n") ++ "\n  sleep 0.06 || exit\n  frame=$((frame + 1))\ndone\n"

pub fun animate-licenses(labels : list<string>) : io ()
  val safe = labels.map(safe-label)
  if safe.is-empty then println("No packages in lockfile.")
  elif run-system("test -t 1 && test \"${TERM:-dumb}\" != dumb") != 0 then
    safe.foreach(println)
  else
    val temporary = run-system-read("mktemp \"${TMPDIR:-/tmp}/prd-licenses.XXXXXX\"").untry.trim
    if temporary == "" then throw("unable to create animation script")
    with finally
      run-system("rm -f -- " ++ shell-quote(temporary))
      ()
    write-text-file(temporary.path, screen-script ++ burst(safe), create-dir=False)
    val status = run-system("sh " ++ shell-quote(temporary))
    if status != 0 && status != 130 && status != 143 && status != 129 && status != -2 && status != -15 && status != -1 then
      throw("license animation failed")
