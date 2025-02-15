import std/[tables,os,strutils]
import ./[wsv]

type
  NodeType = enum
    ntElement, ntAttribute, ntComment, ntEndkeyword, ntNiltype

  SmlNode* = ref object
    name*: string
    `type`*: NodeType
    childs*: seq[SmlNode]
    values*: seq[string]
    comment*: string

  SmlDocument* = ref object
    name*: string # root element
    childs*: seq[SmlNode]
    endkeyword*: string

proc newSmlDocumentation*(): SmlDocument
proc parseSmlFile*(fp: string): SmlDocument
proc parseSmlString*(content: string): SmlDocument
proc getNodetype*(wsvline: WsvLine, endkeyword: string ): NodeType
proc parseSmlTree(parentnode: SmlNode, endkeyword: string, lines: seq[string], idx: var int)

proc newSmlDocumentation*(): SmlDocument =
  return SmlDocument()

proc parseSmlFile*(fp: string): SmlDocument =
  return parseSmlString(readFile(fp))
  
proc parseSmlString*(content: string): SmlDocument =
  result = SmlDocument()
  var lines = split(content, "\n")
  if lines[^1] == "":
    lines = lines[0..^2]
  var
    idx = -1
  while idx < len(lines)-1:
    idx.inc()
    let wsvline = parseLine(lines[idx])
    if wsvline.values.len() != 1:
      echo $idx, ": error - malformed SML-Document. First node must be Element ", $wsvline.values
      system.quit()
    
    let endwsvline = parseLine(lines[^1])
    if endwsvline.values.len() != 1:
      echo lines[^2]
      echo("error - malformed SML-Document. last line must be EndNode: ", $endwsvline.values)
      system.quit()
    result.name = wsvline.values[0]
    result.endkeyword = endwsvline.values[0]
    var smlnode = SmlNode(
      name: result.name,
      type: ntElement,
    )
    parseSmlTree(smlnode, result.endkeyword, lines, idx)
    result.childs.add(smlnode)
    echo smlnode.childs.len()
    let s = smlnode.childs[0]
    echo s.childs.len()
    echo idx

proc parseSmlTree(parentnode: SmlNode, endkeyword: string, lines: seq[string], idx: var int) =
  echo idx
  while idx < lines.len()-1:
    let
      wsvline = parseLine(lines[idx])
    echo wsvline.values
    var smlnode = SmlNode()
    smlnode.type = getNodetype(wsvline, endkeyword)

    if smlnode.type == ntEndkeyword:
      return
    elif (smlnode.type == ntElement):
      # new Element found
      smlnode.name = wsvline.values[0]
      smlnode.comment = wsvline.comment
      idx.inc()
      parentnode.childs.add(
        parseSmlTree(smlnode, endkeyword, lines, idx))
    elif smlnode.type == ntAttribute:
      smlnode.name = wsvline.values[0]
      smlnode.comment = wsvline.comment
      parentnode.childs.add(smlnode)
    elif smlnode.type == ntComment:
      smlnode.comment = wsvline.comment
      parentnode.childs.add(smlnode)
    else:
      echo "skip this wsvline: ", $smlnode.type
    idx.inc()

proc getNodetype*(wsvline: WsvLine, endkeyword: string): NodeType =
  if len(wsvline.values) == 1:
    if wsvline.values[0] == endkeyword:
      return ntEndkeyword
    else:
      return ntElement
  elif len(wsvline.values) == 0 and wsvline.comment.len() > 0:
    return ntComment
  elif wsvline.values.len() > 1:
    return ntAttribute
  else:
    return ntNiltype
  
when isMainModule:
  let wsvdoc = parseWsvFile("test.sml")
  for wsvline in wsvdoc.lines:
    echo wsvline.values
  let smldoc = parseSmlFile("test.sml")
  echo smldoc.name
  echo smldoc.childs.len()
  for smlnode in smldoc.childs:
    echo smlnode.name
