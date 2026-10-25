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
