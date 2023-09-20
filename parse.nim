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


type ChildList = object
  node: xmlNodePtr

iterator items(children: ChildList): xmlNodePtr =
  var cur = children.node
  while cur != nil:
    yield cur
    cur = cur.next

proc childNodes(node: xmlNodePtr): ChildList =
  return ChildList(node: node.children)


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
  var copyNode = xmlCopyNode(node, 1)
  discard xmlDocSetRootElement(doc, copyNode)
  return findByXPath(doc, XPath)


proc parseString(xmlStr: string): xmlNodePtr =
  var doc = xmlReadMemory(xmlStr.cstring, xmlStr.len.cint, "".cstring, nil, 0.cint)
  return doc.xmlDocGetRootElement

proc parseFile(xmlFile: string): xmlNodePtr =
  var doc = xmlReadFile(xmlFile.cstring, nil, enumxmlparseroption.Xmlparsenoblanks.cint )
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


proc stripTag2(node: xmlNodePtr, tag: string, sub: Option[string] = none(string)): xmlNodePtr =
  var nodes = findByXPath(node, fmt"//{tag}")
  var newDoc: xmlDocPtr
  var nodeStr = $node
  for n in nodes:
    newDoc = n.doc
    if not sub.isSome:
      # nodeStr = nodeStr.replace($n, n.innerXml)
      for c in n.childNodes:
        print $c
        print "here"
        print $n
        var op = xmlAddSibling(n, c)
        print $n
        # print $op
      n.xmlUnlinkNode
    else:
      var newTextNode = xmlNewText(cast[ptr uint8](sub.get.cstring))
      var op = xmlAddSibling(n, newTextNode)
      n.xmlUnlinkNode

 
  print newDoc.xmlDocGetRootElement.`$`
  return newDoc.xmlDocGetRootElement
  # return nodeStr.parseString

# proc delTag(node: xmlNodePtr, tag: string): xmlNodePtr =




# var docstr = "<b><c>woof <br/> <i>dd</i></c><a>are you a <i>cat</i> or a <i>dog</i>?</a></b>"

# var doc2 = xmlReadMemory(docstr.cstring, docstr.len.cint, "".cstring, nil, 0.cint)
# discard xmlDocDump(cast[ptr structsfile](stdout), doc2);


# var node2 = doc2.xmlDocGetRootElement
# print $node2

# var nodeRes = findByXPath(node2, "//c")

# for n in nodeRes:
#   print $n
#   var m = n.stripTag2("i")
#   print $m
#   print m.stripTag("br", some("xx")).`$`


# print $node2

# discard xmlDocDump(cast[ptr structsfile](stdout), doc);

var xml = parseFile("Imitation_of_christ.xml")
print $xml

var nodes = findByXPath(xml, "//title or //div1 or //div2[not(@title='Index of Scripture References) and not(@title='Subject Index')]")
for n in nodes:
  print $n
  discard readLine(stdin)
