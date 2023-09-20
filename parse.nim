import print
import futhark
import std/[strformat, strutils, options]

  # export LDFLAGS="-L/usr/local/opt/libxml2/lib"
  # export CPPFLAGS="-I/usr/local/opt/libxml2/include"

importc:
  path "/usr/local/opt/libxml2/include"
  "libxml/tree.h"
  "libxml/parser.h"
  "libxml/xpath.h"
  "libxml/xpathInternals.h"

{.passl: "-L/usr/local/opt/libxml2/lib".}
{.passl: "-lxml2".}

proc innerXml(node: xmlNodePtr): string =
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


proc `$`(node: xmlNodePtr): string =
  var buf = xmlBufferCreate()
  discard xmlnodedump(buf, node.doc,
                      node, 0, 0)
  return $(cast[cstring](buf.content))

type NodeList = object
  nodes: xmlNodeSetPtr

iterator items(nodes: NodeList): xmlNodePtr =
  for i in 0..nodes.nodes.nodeNr - 1:
    yield cast[ptr UncheckedArray[xmlNodePtr]](nodes.nodes.nodeTab)[i]

proc findByXPath(doc: xmlDocPtr, XPath: string): NodeList =
  var xpathCtx = xmlXPathNewContext(doc);
  var xpathObj = xmlXPathEvalExpression(cast[ptr uint8](cstring(XPath)),
                                         xpathCtx);
  var nodes = xpathObj.nodesetval
  return NodeList(nodes: nodes)

proc findByXPath(node: xmlNodePtr, XPath: string): NodeList =
  var doc = xmlNewDoc(cast[ptr uint8]("".cstring))
  discard xmlDocSetRootElement(doc, node)
  return findByXPath(doc, XPath)


proc parseString(xmlStr: string): xmlNodePtr =
  var doc = xmlReadMemory(xmlStr.cstring, xmlStr.len.cint, "".cstring, nil, 0.cint)
  return doc.xmlDocGetRootElement

proc stripTag(node: xmlNodePtr, tag: string, sub: Option[string] = none(string)): xmlNodePtr =
  var nodes = findByXPath(node, fmt"//{tag}")
  var nodeStr = $node
  for n in nodes:
    if not sub.isSome:
      nodeStr = nodeStr.replace($n, n.innerXml)
    else:
      nodeStr = nodeStr.replace($n, sub.get)

  return nodeStr.parseString

# proc delTag(node: xmlNodePtr, tag: string): xmlNodePtr =


var doc = xmlReadFile(cstring("test.xml"), nil, enumxmlparseroption.Xmlparsenoblanks.cint )

if doc == nil:
  print "error"

discard xmlDocDump(cast[ptr structsfile](stdout), doc);

var xpathCtx = xmlXPathNewContext(doc);
var xpathExpr = "//div[@class='x']"
var xpathObj = xmlXPathEvalExpression(cast[ptr uint8](cstring(xpathExpr)), xpathCtx);

# discard xmlDocDump(cast[ptr structsfile](stdout), xpathObj);

var nodes = xpathObj.nodesetval
print nodes.nodeNr




var docstr = "<b><c>woof <br/> <i>dd</i></c><a>are you a <i>cat</i> or a <i>dog</i>?</a></b>"

var doc2 = xmlReadMemory(docstr.cstring, docstr.len.cint, "".cstring, nil, 0.cint)
discard xmlDocDump(cast[ptr structsfile](stdout), doc2);


var node2 = doc2.xmlDocGetRootElement
print $node2

var nodeRes = findByXPath(node2, "//c")

for n in nodeRes:
  print $n
  var m = n.stripTag("i")
  print m.stripTag("br", some("xx")).`$`

