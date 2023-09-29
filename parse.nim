import print
import xavierXML
import std/[strformat, strutils, options, unicode, re]
import splitSent

var xml = parseFile("on-the-trinity.xml")
# print $xml

import yaml/serialization, streams
import std/[json, tables, algorithm]

type Gloss = object
  text: string
  source: string

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

  for rep in repStrings.mitems:
    rep = rep.replace("\n", " ")
             .replace("“","\"")
             .replace("”", "\"")
             .replace("—", "-")
             .replace("’", "'")
    print rep
    echo rep
    var repNode = rep.parseString
    if repNode == nil:
      continue
    if repNode.getName == "scripRef":
      rep = "scrip:" & repNode.getAttr("parsed")

  echo $procNode

  var rawText = procNode.innerXml
                        .replace("\n", " ")
                        .replace("“","\"")
                        .replace("”", "\"")
                        .replace("—", "-")
                        .replace("’", "'")
  print rawText


  repStrings.reverse
  for s in rawText.splitSentences:
    var glosses: seq[Gloss]
    print s.count("†")
    for i in 1..s.count("†"):
      var repString = repStrings.pop
      if repString.startsWith("scrip:"):
        glosses.add(Gloss(text: "scrip", source: repString.split(":")[1]))
      else:
        glosses.add(Gloss(text: repString, source: "NA"))

    sentences.add(Sentence(text: s, glosses: some(glosses)))
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
      # echo "-----"
      echo s.text
      print s
    discard readLine(stdin)
    # var sentences = extractedNodes[$n][0].split(".")
    # for s in sentences:
    #   print s
    # break
