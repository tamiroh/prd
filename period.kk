module period

// Local mutation does not escape: this function has no I/O or state effects.
// KMP fallback strictly decreases j; the outer loop advances i exactly once.
pub fun period-length(s : string, strict : bool = False) : <exn,div> int
  val chars = s.vector
  val n = chars.length
  if n == 0 then 0 else
    var table := vector(n, 0)
    var i := 1
    var j := 0
    while { i < n }
      while { j > 0 && chars[i] != chars[j] }
        j := table[j - 1]
      if chars[i] == chars[j] then j := j + 1
      table[i] := j
      i := i + 1
    val p = n - j
    if strict && n % p != 0 then n else p

pub fun minimum-period(s : string, strict : bool = False) : <exn,div> string
  s.first(period-length(s, strict)).string
