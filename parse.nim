import print
import futhark

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
    # print "child- "
    # print children.name
    xmlBufferEmpty(buf)
    discard xmlnodedump(buf, node.doc,
                        cast[xmlnodeptr](children), 0, 0)
    # discard xmlBufferDump(cast[ptr structsfile](stdout), buf)

    outString = outString & $(cast[cstring](buf.content))
    children = children.next
  return outString


proc `$`(node: xmlNodePtr): string =
  var buf = xmlBufferCreate()
  discard xmlnodedump(buf, node.doc,
                      node, 0, 0)
  return $(cast[cstring](buf.content))


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


for i in 0..nodes.nodeNr - 1:
  print i
  var cur = cast[ptr UncheckedArray[xmlNodePtr]](nodes.nodeTab)[i];
  print cur.innerXml
  print $cur

  # xmlElemDump(cast[ptr structsfile](stdout), doc, xmlFirstElementChild(cur))
  print "\n"
