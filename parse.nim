import print
import xavierXML
import std/[strformat, strutils, options]
import splitSent

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


# proc procGlosses(node: xmlNodePtr) =
#   var repStrings: seq[string]
#   # var ret = procNode.stripTagRetrieve("scripRef", some("†"))
#   # procNode = ret[0]
#   # repStrings = repStrings & ret[1]

#   var ret = procNode.stripTagRetrieve("note", some("†"))
#   repStrings = ret[1]
#   for r


proc procSentences(node: xmlNodePtr): seq[Sentence] =
  var sentences: seq[Sentence]
  # var procNode: xmlNodePtr
  var repStrings: seq[string]

  var procNode = node.stripTag("i")
                      .stripTag("name")
                      .stripTag("span")
                      .stripTag("pb", some(" "))
                      .stripTag("""p[@class="endnote"]""")

  var ret = procNode.stripTagRetrieve("note", some("†"))
  procNode = ret[0]
  repStrings = ret[1]


  print "before", repStrings
  for rep in repStrings.mitems:
    var repNode = rep.parseString
    if repNode == nil:
      continue
    if repNode.getName == "scripRef":
      rep = repNode.getAttr("parsed")
      discard readLine(stdin)

  echo $procNode
  print "after", repStrings

  discard readLine(stdin)
  var rawText = procNode.innerXml.replace("\n", " ")
  print rawText

  for s in rawText.splitSentences:
    sentences.add(Sentence(text: s, glosses: none(seq[Gloss])))
    # print s
    # discard readLine(stdin)

  return sentences



var formatFile = "on-the-trinity-structure.json"
var bookFormat = parseJson(readFile(formatFile))

var extractedNodes = initTable[string, (xmlNodePtr, string)]()

var allSelectors: seq[string]

for k,v in bookFormat.pairs:
  print k, $v
  var selector = v[0]["selector"].getStr
  allSelectors.add(selector)
  print selector
  var nodes = findByXPath(xml, selector)
  for n in nodes:
    extractedNodes[$n] = (node: n, section: k)
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
  if extractedNodes[$n][1] == "sentence":
    print $n
    var sentences = n.procSentences
    for s in sentences:
      print s
    discard readLine(stdin)
    # var sentences = extractedNodes[$n][0].split(".")
    # for s in sentences:
    #   print s
    # break
