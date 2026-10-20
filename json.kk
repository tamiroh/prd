// JSON grammar: https://www.json.org/json-en.html
module json

import std/text/parse

pub alias json-string = list<char>

pub type json
  JsonNull
  JsonBool(value : bool)
  JsonNumber(text : string)
  JsonString(value : json-string)
  JsonArray(values : list<json>)
  JsonObject(members : list<(json-string,json)>)

fun peek() : parse maybe<char>
  current-input().next.map(fn(pair) pair.fst)

fun expect(c : char) : parse ()
  char(c)
  ()

fun consume(c : char) : parse bool
  if peek() == Just(c) then
    expect(c)
    True
  else False

fun take-while(pred : char -> bool) : parse string
  match peek()
    Just(c) | pred(c) -> chars-are("character", pred).string
    _ -> ""

fun skip-space() : parse ()
  take-while(fn(c) c == ' ' || c == '\t' || c == '\r' || c == '\n')
  ()

fun hex-unit() : parse int
  val digits = count(4) { char-is("hexadecimal digit", is-hex-digit) }
  digits.foldl(0) fn(n, c)
    val digit = if c >= '0' && c <= '9' then c.int - '0'.int
                elif c >= 'a' && c <= 'f' then c.int - 'a'.int + 10
                else c.int - 'A'.int + 10
    n * 16 + digit

fun unicode-escape() : parse char
  val high = hex-unit()
  if high >= 0xD800 && high <= 0xDBFF then
    val low = current-input().parse fn()
      pstring("\\u")
      val unit = hex-unit()
      if unit >= 0xDC00 && unit <= 0xDFFF then unit
      else fail("low surrogate")
    match low
      ParseOk(unit, rest) ->
        satisfy(fn(_) Just(((), rest)))
        (0x10000 + (high - 0xD800) * 1024 + unit - 0xDC00).char
      ParseError(_, _) -> high.char
  else high.char

fun escaped-char() : parse char
  val c = char-is("string escape", fn(_) True)
  match c
    '"'  -> '"'
    '\\' -> '\\'
    '/'  -> '/'
    'b'  -> '\x08'
    'f'  -> '\x0c'
    'n'  -> '\n'
    'r'  -> '\r'
    't'  -> '\t'
    'u'  -> unicode-escape()
    _ -> fail("invalid string escape")

fun string-value() : <parse,div> json-string
  expect('"')
  fun loop(acc : list<char>) : <parse,div> json-string
    val c = char-is("string character or closing quote", fn(_) True)
    if c == '"' then acc.reverse
    elif c == '\\' then loop(Cons(escaped-char(), acc))
    elif c.int < 0x20 then fail("unescaped control character")
    else loop(Cons(c, acc))
  loop([])

fun number-value() : parse json
  val sign = if consume('-') then "-" else ""
  val integer = if consume('0') then "0" else
    val first = char-is("digit from 1 to 9", fn(c) c >= '1' && c <= '9')
    first.string ++ take-while(is-digit)
  val fraction = if consume('.') then "." ++ digits() else ""
  val exponent = if peek() == Just('e') || peek() == Just('E') then
    val marker = one-of("eE")
    val exponent-sign = if consume('+') then "+" elif consume('-') then "-" else ""
    marker.string ++ exponent-sign ++ digits()
  else ""
  JsonNumber(sign ++ integer ++ fraction ++ exponent)

fun sequence(end : char, item : () -> <parse,div> a) : <parse,div> list<a>
  skip-space()
  fun loop(acc)
    val value = item()
    skip-space()
    if consume(end) then Cons(value, acc).reverse
    else
      expect(',')
      skip-space()
      loop(Cons(value, acc))
  if consume(end) then [] else loop([])

fun value() : <parse,div> json
  match peek()
    Just('n') -> { pstring("null"); JsonNull }
    Just('t') -> { pstring("true"); JsonBool(True) }
    Just('f') -> { pstring("false"); JsonBool(False) }
    Just('"') -> JsonString(string-value())
    Just('[') ->
      expect('[')
      JsonArray(sequence(']', value))
    Just('{') ->
      expect('{')
      JsonObject(sequence('}') fn()
        val key = string-value()
        skip-space()
        expect(':')
        skip-space()
        (key, value())
      )
    Just(c) | c == '-' || c.is-digit -> number-value()
    _ -> fail("expected JSON value")

pub fun parse-json(input : string) : div parse-error<json>
  input.slice.parse-eof fn()
    skip-space()
    val result = value()
    skip-space()
    result
