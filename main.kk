module main

import std/os/env
import period
import std/os/readline
import std/os/file
import std/os/dir
import std/os/path

val usage = r"Usage: prd [OPTION]... [FILE]
Find the shortest repeating prefix of each UTF-8 line.

  -h, --help     Display this help and exit
  -V, --version  Display version and exit
  -l, --length   Output period length in Unicode code points
  -s, --strict   Require complete repetitions
  --             End options

Read standard input when FILE is omitted or is -.
Empty lines produce empty output (0 with --length)."

// readline removes LF but retains CR, including at the end of a final line.
fun output-line(line : string, length-only : bool, strict : bool) : io ()
  val text = if line.ends-with("\r").is-just then line.first(line.count - 1).string else line
  println(if length-only then period-length(text, strict).show else minimum-period(text, strict))

fun process-stdin(length-only : bool, strict : bool) : io ()
  match try(fn() readline())
    Ok(line) ->
      output-line(line, length-only, strict)
      process-stdin(length-only, strict)
    Error(err) -> match err.info
      ExnSystem(code) | code == -1 -> () // Native readline reports EOF as -1.
      _ -> throw-exn(err)

fun process-file-lines(lines : list<string>, length-only : bool, strict : bool) : io ()
  match lines
    Nil -> ()
    Cons(line, rest) ->
      // split retains a trailing empty field; it is not another input line.
      if line != "" || !rest.is-empty then output-line(line, length-only, strict)
      process-file-lines(rest, length-only, strict)

fun process(filename : string, length-only : bool, strict : bool) : io ()
  if filename == "-" then process-stdin(length-only, strict)
  elif filename.path.is-directory then throw("input is a directory: " ++ filename)
  else process-file-lines(read-text-file(filename.path).split("\n"), length-only, strict)

struct options(
  length-only : bool = False,
  strict : bool = False,
  filename : maybe<string> = Nothing
)

type command
  Help
  Version
  Run(options : options)

fun fail(message : string) : exn a
  throw(message ++ "\nTry 'prd --help' for usage.")

fun with-input(opts : options, input : string) : exn options
  match opts.filename
    Just(_) -> fail("expected at most one input file")
    Nothing -> opts(filename = Just(input))

// After --, all remaining arguments are operands, including names starting with -.
fun parse-operands(args : list<string>, opts : options) : exn command
  match args
    Nil -> Run(opts)
    Cons(filename, rest) -> parse-operands(rest, opts.with-input(filename))

fun parse-options(args : list<string>) : <exn,div> command
  fun loop(remaining : list<string>, opts : options) : <exn,div> command
    match remaining
      Nil -> Run(opts)
      Cons(arg, rest) -> match arg
        "--help"    -> Help
        "-h"        -> Help
        "--version" -> Version
        "-V"        -> Version
        "--"        -> parse-operands(rest, opts)
        "--length"  -> loop(rest, opts(length-only = True))
        "-l"        -> loop(rest, opts(length-only = True))
        "--strict"  -> loop(rest, opts(strict = True))
        "-s"        -> loop(rest, opts(strict = True))
        _ ->
          if arg != "-" && arg.starts-with("-").is-just then
            // Expand short option clusters using the same parser.
            if !arg.starts-with("--").is-just && arg.count > 2 then
              val flags = arg.list.drop(1).map(fn(c) { "-" ++ c.string })
              loop(flags ++ rest, opts)
            else fail("unknown option: " ++ arg)
          else loop(rest, opts.with-input(arg))

  loop(args, Options())

pub fun main() : io ()
  with try fn(err)
    println("prd: " ++ err.message)
  match parse-options(get-args())
    Help -> println(usage)
    Version -> println("prd 0.1.0")
    Run(opts) -> process(opts.filename.default("-"), opts.length-only, opts.strict)
