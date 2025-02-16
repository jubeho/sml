import std/[unicode,tables,strformat,strutils]

const
  whitespaceInts: seq[int32] = @[
    0x0009, #	Character Tabulation
    0x000A, #	Line Feed
    0x000B, #	Line Tabulation
    0x000C, #	Form Feed
    0x000D, #	Carriage Return
    0x0020, #	Space
    0x0085, #	Next Line
    0x00A0, #	No-Break Space
    0x1680, #	Ogham Space Mark
    0x2000, #	En Quad
    0x2001, #	Em Quad
    0x2002, #	En Space
    0x2003, #	Em Space
    0x2004, #	Three-Per-Em Space
    0x2005, #	Four-Per-Em Space
    0x2006, #	Six-Per-Em Space
    0x2007, #	Figure Space
    0x2008, #	Punctuation Space
    0x2009, #	Thin Space
    0x200A, #	Hair Space
    0x2028, #	Line Separator
    0x2029, #	Paragraph Separator
    0x202F, #	Narrow No-Break Space
    0x205F, #	Medium Mathematical Space
    0x3000 #	Ideographic Space
  ]
  dblQuote: Rune = cast[Rune](0x0022)
  slash: Rune = cast[Rune](0x002F)
  hashsign: Rune = cast[Rune](0x0023)

    
type

  WsvEncoding* = enum
    weUtf8, weUtf16

  WsvLine* = ref object
    values*: seq[string]
    comment*: string
    whitespaces*: seq[int32]
    
  WsvDocument* = ref object
    lines*: seq[WsvLine]
    encoding*: WsvEncoding

proc parseWsvFile*(fp: string): WsvDocument
proc parseWsvString*(txt: string): WsvDocument
proc newWsvDocument*(lines: seq[WsvLine] = @[], encoding: WsvEncoding = weUtf8): WsvDocument
proc newWsvLine*(line: string = ""): WsvLine
proc parseLine*(line: string): WsvLine

proc wsvdocToSeq*(wsvdoc: WsvDocument): seq[seq[string]]
proc `%`*(wsvdoc: WsvDocument): seq[seq[string]]

proc stringSeqToWsvDoc*(tab: seq[seq[string]]): WsvDocument

proc serializeWsvDoc*(wsvdoc: WsvDocument, fp: string, separator: char = '\t'): string

proc toString(wsvline: WsvLine, separator: char = '\t'): string
func stringToWsvString*(s: string): string

func isWhitespaceChar(c: int32): bool
func isDblQuote(r: Rune): bool
func isNextRuneDblQuote(runes: seq[Rune], curIndex: int): bool
func isNewlineEscapeSequence(runes: seq[Rune], curIndex: int): bool

proc newWsvLine*(line: string = ""): WsvLine =
  if line == "":
    return WsvLine()
  return parseLine(line)

proc newWsvDocument*(lines: seq[WsvLine] = @[], encoding: WsvEncoding = weUtf8): WsvDocument =
  result = WsvDocument(lines: lines, encoding: encoding)

proc parseWsvFile*(fp: string): WsvDocument =
  return parseWsvString(readFile(fp))

proc parseWsvString*(txt: string): WsvDocument =
  result = newWsvDocument()
  let lines = split(txt, "\n")
  var linecounter = 0
  for line in lines:
    if len(line) == 0:
      continue
    if line[0] == '#':
      var wl = WsvLine(comment: line)
      result.lines.add(wl)
    else:
      var wsvline = parseLine(line)
      result.lines.add(wsvline)
    inc(linecounter)
    
proc parseLine*(line: string): WsvLine =
  result = WsvLine()
  let runes = toRunes(line)
  var
    currentWord = ""
    isPendingDblQuote = false
    lastRune: Rune

  var i = -1
  while i < runes.len()-1:
    inc(i)
    let r = runes[i]
    if isWhitespaceChar(int32(r)):
      if isPendingDblQuote:
        currentWord.add($r)
      else:
        if currentWord.len() > 0:
          result.values.add(currentWord)
          currentWord = ""
    elif r == hashsign:
      echo "found ", $r
      if isPendingDblQuote:
        echo "isPendignDblQuote == true"
        currentWord.add($r)
      else:
        echo "isPendignDblQuote == false"
        if currentWord.len() > 0:
          result.values.add(currentWord)
          currentWord = ""
          result.comment = $runes[i..^1]
        else:
          result.comment = $runes[i..^1]
        break
    else:
      if r.isDblQuote:
        if isPendingDblQuote:
          if isNextRuneDblQuote(runes, i):
            currentWord.add($r)
            inc(i)
          elif isNewlineEscapeSequence(runes, i):
            currentWord.add("\n")
            i = i+2
          else:
            isPendingDblQuote = false
            if currentWord.len() > 0:
              result.values.add(currentWord)
              currentWord = ""
        else:
          isPendingDblQuote = true
      else:
        currentWord.add($r)
    lastRune = r

  if currentWord.len() > 0:
    result.values.add(currentWord)

proc wsvdocToSeq*(wsvdoc: WsvDocument): seq[seq[string]] =
  result = @[]
  for wsvline in wsvdoc.lines:
    result.add(wsvline.values)

proc `%`*(wsvdoc: WsvDocument): seq[seq[string]] =
  return wsvdocToSeq(wsvdoc)

proc stringSeqToWsvDoc*(tab: seq[seq[string]]): WsvDocument =
  result = newWsvDocument()
  for row in tab:
    var wsvline = newWsvLine()
    wsvline.values.add(row)
    result.lines.add(wsvline)    

proc serializeWsvDoc*(wsvdoc: WsvDocument, fp: string, separator: char = '\t'): string =
  if not ((int32(separator)) in whitespaceInts):
    echo "unsupported field separator"
    system.quit("bye-bye...")
  result = ""
  for wsvline in wsvdoc.lines:
    result.add(wsvline.toString())
    result.add("\n")

proc toString(wsvline: WsvLine, separator: char = '\t'): string =
  if not ((int32(separator)) in whitespaceInts):
    echo "unsupported field separator"
    system.quit("bye-bye...")
  result = ""
  for val in wsvline.values:
    result.add(stringToWsvString(val))
    result.add($separator)

func stringToWsvString*(s: string): string =
  result = ""
  let runes = toRunes(s)
  var needSurroundingDblQuotes = false
  for rune in runes:
    if rune == dblQuote:
      needSurroundingDblQuotes = true
      result.add("\"\"")
    elif int32(rune) in whitespaceInts:
      needSurroundingDblQuotes = true
      result.add($rune)
    elif char(rune) == '\n':
      needSurroundingDblQuotes = true
      result.add("\"/\"")
    else:
      result.add($rune)
  if needSurroundingDblQuotes:
    result.add("\"")
    result = fmt("\"{result}")
    
func isNextRuneDblQuote(runes: seq[Rune], curIndex: int): bool =
  if curIndex+1 >= len(runes):
    return false
  if runes[curIndex+1] == dblQuote:
    return true
  else:
    return false

func isNewlineEscapeSequence(runes: seq[Rune], curIndex: int): bool =
  if curIndex+2 >= len(runes):
    return false
  if (runes[curIndex+1] == slash) and (runes[curIndex+2] == dblQuote):
    return true
  else:
    return false

func isWhitespaceChar(c: int32): bool =
  if c in whitespaceInts:
    return true
  else:
    return false

func isDblQuote(r: Rune): bool =
  if r == dblQuote:
    return true
  else:
    return false
    
when isMainModule:
  let w = parseWsvFile("test.sml")
  for wline in w.lines:
    echo wline.values
    echo wline.comment
    echo ("-------------------------")
