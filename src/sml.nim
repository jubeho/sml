import std/[tables,os,strutils]
import ./[wsv]

type
  NodeType = enum
    ntElement, ntAttribute, ntComment, ntEndkeyword, ntNiltype

  SmlNode* = ref object
    name*: string
    `type`*: NodeType
    path*: seq[string]
    childs*: seq[SmlNode]
    values*: seq[string]
    comment*: string

  SmlDocument* = ref object
    name*: string # root element
    childs*: seq[SmlNode]
    endkeyword*: string

proc newSmlDocumentation*(): SmlDocument
proc parseSmlFile*(fp: string): SmlDocument
proc parseSmlText*(text: string): SmlDocument
proc serializeSmlDocument*(smldoc: SmlDocument): string

proc printSmlTree*(rootnode: SmlNode, level: var string)

proc getNodetype(wsvline: WsvLine, endkeyword: string ): NodeType
proc parseSmlTree(rootnode: SmlNode, endkeyword: string, lines: seq[string],
                  idx: var int, nodepath: var seq[string])

proc newSmlDocumentation*(): SmlDocument =
  return SmlDocument()

proc parseSmlFile*(fp: string): SmlDocument =
  return parseSmlText(readFile(fp))
  
proc parseSmlText*(text: string): SmlDocument =
  result = SmlDocument()
  var lines = split(text, "\n")
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
      path: @[result.name],
      type: ntElement,
    )
    # var node = parseSmlTree(result.endkeyword, lines, idx)
    var nodepath: seq[string] = @[]
    parseSmlTree(smlnode, result.endkeyword, lines, idx, nodepath)
    result.childs.add(smlnode)

proc parseSmlTree(rootnode: SmlNode, endkeyword: string, lines: seq[string],
                  idx: var int, nodepath: var seq[string]) =
  while idx < lines.len()-1:
    let
      wsvline = parseLine(lines[idx])
      nt = getNodetype(wsvline, endkeyword)
    if nt == ntEndkeyword:
      idx.inc()
      nodepath = nodepath[0..^2]
      return
    elif (nt == ntElement):
      nodepath.add(wsvline.values[0])
      var smlnode = SmlNode(
        name: wsvline.values[0],
        type: nt,
        path: nodepath,
        comment: wsvline.comment)
      idx.inc()
      parseSmlTree(smlnode, endkeyword, lines, idx, nodepath)
      rootnode.childs.add(smlnode)
    elif nt == ntAttribute:
      nodepath.add(wsvline.values[0])
      rootnode.childs.add(SmlNode(
        name: wsvline.values[0],
        type: nt,
        path: nodepath,
        values: wsvline.values[1..^1],
        comment: wsvline.comment))
      nodepath = nodepath[0..^2]
      idx.inc()
    elif nt == ntComment:
      rootnode.childs.add(SmlNode(
        type: nt,
        comment: wsvline.comment))
      idx.inc()
    else:
      echo "Node is form type Nil-Type"
      idx.inc()

proc getNodetype(wsvline: WsvLine, endkeyword: string): NodeType =
  if len(wsvline.values) == 1:
    if wsvline.values[0] == endkeyword:
      return ntEndkeyword
    else:
      return ntElement
  elif len(wsvline.values) == 0 and wsvline.comment.len() > 0:
    echo "comment: ", wsvline.comment
    return ntComment
  elif wsvline.values.len() > 1:
    return ntAttribute
  else:
    return ntNiltype

proc serializeTree(rootnode: SmlNode, text: var string, indent: var string, sep: string = "  ") =
  for smlnode in rootnode.childs:
    text.add(indent)
    case smlnode.type
    of ntElement:
      text.add(stringToWsvString(smlnode.name))
      text.add("\n")
      if smlnode.comment != "":
        text.add(stringToWsvString(smlnode.comment))
      if smlnode.childs.len() == 0:
        text.add(indent)
        text.add("END\n")
    of ntAttribute:
      text.add(stringToWsvString(smlnode.name))
      text.add(sep)
      for s in smlnode.values:
        echo s
        text.add(sep)
        text.add(stringToWsvString(s))
      if smlnode.comment != "":
        text.add(sep)
        text.add(smlnode.comment)
      text.add("\n")
    of ntComment:
      text.add(smlnode.comment)
      text.add("\n")
    else:
      discard
    if smlnode.childs.len() > 0:
      indent.add(sep)
      serializeTree(smlnode, text, indent, sep)
      let i = sep.len() + 1
      indent = indent[0..^i]
      text.add(indent)
      text.add("END\n")
      
proc serializeSmlDocument*(smldoc: SmlDocument): string =
  result = ""
  var indent = ""
  serializeTree(smldoc.childs[0], result, indent, "  ")

proc printSmlTree*(rootnode: SmlNode, level: var string) =
  for smlnode in rootnode.childs:
    echo level, smlnode.name, " (", smlnode.path.join("/"), ")"
    if smlnode.childs.len() > 0:
      level.add("\t")
      printSmlTree(smlnode, level)
      level = level[0..^2]
    
when isMainModule:
  let smldoc = parseSmlFile("test.sml")
  echo serializeSmlDocument(smldoc)
