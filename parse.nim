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

type xmlCharPtr = ptr uint8

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

proc len(nodes: NodeList): int =
  return nodes.nodes.nodeNr.int

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
  var oldDoc = node.doc
  var doc = xmlNewDoc(cast[ptr uint8]("".cstring))
  # var copyNode = xmlCopyNode(node, 1)
  discard xmlDocSetRootElement(doc, node)
  var ret =  findByXPath(doc, XPath)
  discard xmlDocSetRootElement(oldDoc, node)
  return ret


proc parseString(xmlStr: string): xmlNodePtr =
  var doc = xmlReadMemory(xmlStr.cstring, xmlStr.len.cint, "".cstring, nil, 0.cint)
  return doc.xmlDocGetRootElement

proc parseFile(xmlFile: string): xmlNodePtr =
  var doc = xmlReadFile(xmlFile.cstring, nil, enumxmlparseroption.Xmlparsenoblanks.cint )
  return doc.xmlDocGetRootElement


proc getAttr(node: xmlNodePtr, name: string): string =
  cast[cstring](node.xmlGetProp(cast[xmlCharPtr](name.cstring))).`$`


proc stripTag2(node: xmlNodePtr, tag: string, sub: Option[string] = none(string)): xmlNodePtr =
  var nodes = findByXPath(node, fmt"//{tag}")
  var nodeStr = $node
  for n in nodes:
    if not sub.isSome:
      nodeStr = nodeStr.replace($n, n.innerXml)
    else:
      nodeStr = nodeStr.replace($n, sub.get)

  return nodeStr.parseString


proc stripTag(node: xmlNodePtr, tag: string, sub: Option[string] = none(string)): xmlNodePtr =
  var nodes = findByXPath(node, fmt"//{tag}")
  # var doc: node.doc
  var nodeStr = $node
  print "stripTag"
  print nodeStr
  # if nodes.len == 0:
  #   newDoc = n.doc
  for n in nodes:
    # newDoc = n.doc
    if not sub.isSome:
      print 'x'
      # nodeStr = nodeStr.replace($n, n.innerXml)
      for c in n.childNodes:
        print "1"
        print $c
        print "here"
        print $n
        var op = xmlAddSibling(n, c)
        print $n
        print $node
        print $n
        print "break ------"
        # print $op
      print $node
      print "unlink"
      n.xmlUnlinkNode
      print $node
    else:
      var newTextNode = xmlNewText(cast[ptr uint8](sub.get.cstring))
      var op = xmlAddSibling(n, newTextNode)
      n.xmlUnlinkNode


  print $node
  # print newDoc.xmlDocGetRootElement.`$`
  # return newDoc.xmlDocGetRootElement
  return node
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

var xml = parseFile("on-the-trinity.xml")
# print $xml

import yaml/serialization, streams
import std/[json, tables, algorithm]

type Source = object
  avail: bool
  base: string
  index: string

type Gloss = object
  text: string
  source: Source

type Sentence = object
  text: string
  glosses: Option[seq[Gloss]]

proc procSentences(node: xmlNodePtr): seq[Sentence] =
  var sentences: seq[Sentence]
  var procNode = node.stripTag("span")
                     # .stripTag("name")
                     # .stripTag("span")
                     # .stripTag("pb", some(" "))
                     # .stripTag("name", some(" "))

  print "meow"

  print procNode.innerXml
  discard readLine(stdin)

  for s in procNode.innerXml.split("."):
    sentences.add(Sentence(text: s, glosses: none(seq[Gloss])))
    print s
    discard readLine(stdin)

  return sentences



var formatFile = "on-the-trinity-structure.json"
var bookFormat = parseJson(readFile(formatFile))

var procStrings = initTable[string, (xmlNodePtr, string)]()

var allSelectors: seq[string]

for k,v in bookFormat.pairs:
  print k, $v
  var selector = v[0]["selector"].getStr
  allSelectors.add(selector)
  print selector
  var nodes = findByXPath(xml, selector)
  for n in nodes:
    procStrings[$n] = (node: n, section: k)
    # var content: string
    # if v[0]["content"][0].getStr != "inner":
    #   content = n
    # else:
    #   # print $n
    #   content = n.parseSentences
    #   print k
    # print (content: content, section: k)

print allSelectors.join(" | ")

var nodes = findByXPath(xml, allSelectors.join("|"))
for n in nodes:
  if procStrings[$n][1] == "sentence":
    print $(procStrings[$n][0])
    discard readLine(stdin)
    var sentences = n.procSentences
    # var sentences = procStrings[$n][0].split(".")
    # for s in sentences:
    #   print s
    # break

# var nodes = findByXPath(xml, "//title|//div1[not(@title='Indexes')]|//div2[not(@title='Index of Scripture References') and not(@title='Subject Index') and not(@title='Index of Pages of the Print Edition') and not(@title='Index of Names')]")
# for n in nodes:
#   print $n
#   # discard readLine(stdin)
