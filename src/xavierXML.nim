import print
import futhark
import std/[strformat, strutils, options]

importc:
  path "/usr/local/opt/libxml2/include"
  "libxml/tree.h"
  "libxml/parser.h"
  "libxml/xpath.h"
  "libxml/xmlerror.h"
  "libxml/xpathInternals.h"

{.passl: "-L/usr/local/opt/libxml2/lib".}
{.passl: "-lxml2".}

type xmlCharPtr = ptr uint8

proc innerXml*(node: xmlNodePtr): string =
  var outString = ""
  var buf = xmlBufferCreate()
  var children = node.children
  while children != nil:
    xmlBufferEmpty(buf)
    discard xmlnodedump(buf, node.doc,
                        cast[xmlnodeptr](children), 0, 0)

    outString = outString & $(cast[cstring](buf.content))
    children = children.next
  return outString

type ChildList* = object
  node: xmlNodePtr

iterator items*(children: ChildList): xmlNodePtr =
  var cur = children.node
  while cur != nil:
    yield cur
    cur = cur.next

proc childNodes*(node: xmlNodePtr): ChildList =
  return ChildList(node: node.children)


proc childNodesList*(node: xmlNodePtr): seq[xmlNodePtr] =
  var childNodesList: seq[xmlNodePtr]
  for c in node.childNodes:
    childNodesList.add(c)

  return childNodesList


proc `$`*(node: xmlNodePtr): string =
  var buf = xmlBufferCreate()
  discard xmlnodedump(buf, node.doc,
                      node, 0, 0)
  return $(cast[cstring](buf.content))

type NodeList* = object
  nodes: xmlNodeSetPtr

proc len*(nodes: NodeList): int =
  return nodes.nodes.nodeNr.int

iterator items*(nodes: NodeList): xmlNodePtr =
  for i in 0..nodes.nodes.nodeNr - 1:
    yield cast[ptr UncheckedArray[xmlNodePtr]](nodes.nodes.nodeTab)[i]

proc findByXPath*(doc: xmlDocPtr, XPath: string): NodeList =
  var xpathCtx = xmlXPathNewContext(doc);
  var xpathObj = xmlXPathEvalExpression(cast[ptr uint8](cstring(XPath)),
                                         xpathCtx)
  var nodes = xpathObj.nodesetval
  return NodeList(nodes: nodes)

proc findByXPath*(node: xmlNodePtr, XPath: string): NodeList =
  var oldDoc = node.doc
  var doc = xmlNewDoc(cast[ptr uint8]("".cstring))
  # var copyNode = xmlCopyNode(node, 1)
  discard xmlDocSetRootElement(doc, node)
  var ret =  findByXPath(doc, XPath)
  discard xmlDocSetRootElement(oldDoc, node)
  return ret


proc genericErrorFunc(ctx: pointer, msg: cstring) {.cdecl.} =
  return

proc parseString*(xmlStr: string): xmlNodePtr =
  var xmlString = cast[xmlCharPtr](xmlStr.cstring)
  var ctx = xmlCreateDocParserCtxt(xmlString)
  xmlSetGenericErrorFunc(ctx, genericErrorFunc)
  var doc = xmlCtxtReadMemory(ctx, xmlStr.cstring, xmlStr.len.cint, "".cstring, nil, 0.cint)
  if doc == nil:
    return nil

  return doc.xmlDocGetRootElement

proc getName*(node: xmlNodePtr): string =
  return $(cast[cstring](node.name))

proc parseFile*(xmlFile: string): xmlNodePtr =
  var doc = xmlReadFile(xmlFile.cstring, nil, enumxmlparseroption.Xmlparsenoblanks.cint )
  return doc.xmlDocGetRootElement

proc getAttr*(node: xmlNodePtr,
             name: string): string =
  return cast[cstring](node.xmlGetProp(cast[xmlCharPtr](name.cstring))).`$`

proc stripTagRetrieve*(node: xmlNodePtr, tag: string, sub: Option[string] = none(string)): (xmlNodePtr, seq[string]) =
  var nodes = findByXPath(node, fmt"//{tag}")
  var repStrings: seq[string]
  for n in nodes:
    repStrings.add(n.innerXml)
    if not sub.isSome:
      for c in n.childNodesList:
        var op = xmlAddPrevSibling(n, c)
    else:
      var newTextNode = xmlNewText(cast[xmlCharPtr](sub.get.cstring))
      var op = xmlAddPrevSibling(n, newTextNode)
    n.xmlUnlinkNode

  return (node, repStrings)

proc stripTag*(node: xmlNodePtr, tag: string, sub: Option[string] = none(string)): xmlNodePtr =
  stripTagRetrieve(node, tag, sub)[0]
