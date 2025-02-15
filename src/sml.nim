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
proc getNodetype*(wsvline: WsvLine): NodeType
proc parseSmlTree(parentnode: SmlNode, endkeyword: string, lines: seq[string], idx: var int)

proc newSmlDocumentation*(): SmlDocument =
  return SmlDocument()

proc parseSmlFile*(fp: string): SmlDocument =
  return parseSmlString(readFile(fp))
  
proc parseSmlString*(content: string): SmlDocument =
  result = SmlDocument()
  let lines = split(content, "\n")
  var
    idx = -1
    pendingElement = false
  while idx < len(lines)-1:
    idx.inc()
    let
      wsvline = parseLine(lines[idx])
      nodetype = getNodetype(wsvline)
    if idx == 0:
      if nodetype != ntElement:
        echo("error - malformed SML-Document. First node must be Element")
        system.quit()
      result.name = wsvline.values[0]
      pendingElement = true
      if idx+1 >= lines.len()-1:
        echo("error - malformed SML-Document. Root-Element has no Endkeyword")
        system.quit()
      let
        endwsvline = parseLine(lines[idx+1])
        lastnodetype = getNodetype(endwsvline)
      if lastnodetype != ntElement:
        echo("error - malformed SML-Document. Last-Element must be Endkeyword")
        system.quit()
      result.endkeyword = endwsvline.values[0]
      continue
    var smlnode = SmlNode()
    parseSmlTree(smlnode, result.endkeyword, lines, idx)
    result.childs.add(smlnode)

proc parseSmlTree(parentnode: SmlNode, endkeyword: string, lines: seq[string], idx: var int) =
  echo idx
  while idx < lines.len()-1:
    let
      wsvline = parseLine(lines[idx])
    echo wsvline.values
    var smlnode = SmlNode()
    smlnode.type = getNodetype(wsvline)

    if (smlnode.type == ntElement) and not pendingElement:
      # new Element found
      pendingElement = true
      smlnode.name = wsvline.values[0]
      smlnode.comment = wsvline.comment
      parseSmlTree(smlnode, endkeyword, lines, idx.inc())
    elif (smlnode.type == ntElement) and pendingElement:






    
    if (smlnode.type == ntElement) and not pendingElement:
      echo("Element with !pendingElement")
      if wsvline.values[0] == endkeyword:
        echo("found END-Keyword")
        pendingElement = false
      else:
        echo("found Element")
        smlnode.name = wsvline.values[0]
        parseSmlTree(smlnode, endkeyword, lines, idx)
        parentnode.childs.add(smlnode)
     elif (smlnode.type == ntElement) and pendingElement:
      if wsvline.values[0] == endkeyword:
        echo("found END-Keyword")
        pendingElement = false
      else:
        echo("found Element")
        smlnode.name = wsvline.values[0]
        parseSmlTree(smlnode, endkeyword, lines, idx)
        parentnode.childs.add(smlnode)
    elif (smlnode.type == ntComment):
      echo ("found Comment")
      smlnode.comment = wsvline.comment
    elif (smlnode.type == ntAttribute):
      echo("found Attribute")
      smlnode.name = wsvline.values[0]
      smlnode.values = wsvline.values[1..^1]
      smlnode.comment = wsvline.comment
      parentnode.childs.add(smlnode)
    else:
      echo("warn: skip this wsvline because of type Nodetype == Niltype")
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
  echo smldoc.childs.len()
  echo smldoc.name
  for smlnode in smldoc.childs:
    echo smlnode.name
