module package-lock

import json
import std/text/parse

pub fun is-package-lock(content : string) : div bool
  match parse-json(content)
    ParseOk(JsonObject(members), _) ->
      match members.lookup(fn(key) key == "lockfileVersion".list)
        Just(JsonNumber(version)) -> version == "1" || version == "2" || version == "3"
        _ -> False
    _ -> False

fun member(value : json, name : string) : maybe<json>
  match value
    JsonObject(members) -> members.lookup(fn(key) key == name.list)
    _ -> Nothing

fun text(value : maybe<json>) : maybe<string>
  match value
    Just(JsonString(chars)) -> Just(chars.string)
    _ -> Nothing

fun license-name(value : json) : string
  match value.member("license")
    Just(JsonString(chars)) -> chars.string
    Just(item) -> item.member("type").text.default("unknown")
    Nothing -> "unknown"

fun legacy-packages(value : json) : div list<string>
  match value.member("dependencies")
    Just(JsonObject(members)) -> members.flatmap fn(pair)
      Cons(license-name(pair.snd), legacy-packages(pair.snd))
    _ -> []

pub fun package-licenses(content : string) : <exn,div> list<string>
  match parse-json(content)
    ParseOk(root, _) -> match root.member("packages")
      Just(JsonObject(members)) -> members.map fn(pair)
        license-name(pair.snd)
      _ -> legacy-packages(root)
    ParseError(message, _) -> throw(message)
