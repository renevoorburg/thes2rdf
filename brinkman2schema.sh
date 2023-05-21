#/bin/bash

HEADER='<?xml version="1.0"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#" xmlns:schema="http://schema.org/" xmlns:owl="http://www.w3.org/2002/07/owl#"  xmlns:skos="http://www.w3.org/2004/02/skos/core#"  xmlns:kbdef="http://data.bibliotheken.nl/def#">'

source $(dirname "$0")/src/functions.sh

read_commandline_parameters "$@"
validate_initial_conditions

#####

line=`cat <&0 | perl -pe 's@\n@@gi' | perl -pe 's@$@\n@'`

scopeNote=""
echo $line | grep -q '<datafield tag="003Z"> <subfield code="0">vorm</subfield>' && if [ "$?" == "0" ] ; then
    scopeNote="<skos:scopeNote>vormtrefwoord</skos:scopeNote>"
fi

skos=$(echo $line | $SED 's@.*\(<skos:Concept.*</skos:Concept>\).*@\1@' -)

line="$skos"

# restrict output to Brinkman
line=$(echo $line | grep "http://data.kb.nl/dataset/Brinkman" -)

## remove stuff we don't want:
# remove <dc:type ....>....</dc:type> stuff
line=$(echo $line | $SED 's@<dc:type[^>]*>[^<]*</dc:type>@@g')

# remove <skos:inScheme ...>
line=$(echo $line | $SED 's@<skos:inScheme[^>]*>@@g')

# remove <void:inDataset ...>
line=$(echo $line | $SED 's@<void:inDataset[^>]*>@@')

#UDC is a notation
line=$(echo $line | $SED 's@<skos:relatedMatch rdf:resource="http://www.udcc.org/\([0-9(][^"]*\)"/>@<skos:relatedMatch rdf:datatype="http://udcdata.info/UDCnotation">\1</skos:relatedMatch>@')

# SISO - custom notatoion datatype URI
line=$(echo $line | $SED 's@<skos:relatedMatch rdf:resource="http://www.biblion.nl/siso/[0-9(][^"]*"/>@@')

# remove other skos:relatedMatch
line=$(echo $line | $SED 's@<skos:relatedMatch rdf:resource="[^"]*"/>@@g')

## rename to our standards:
# set proper URI (http://data.kb.nl/thesaurus/191687707 =>  http://data.bibliotheken.nl/id/thes/p191687707"
line=$(echo $line | $SED 's@data.kb.nl/thesaurus/@data.bibliotheken.nl/id/thes/p@g')

# add 'meta' node:
ppn=$(echo $line | $SED 's@.*<skos:Concept rdf:about="http://data.bibliotheken.nl/id/thes/p\([0-9Xx]*\)">.*@\1@')
nodedata='<rdf:type rdf:resource="http://schema.org/Dataset"/>'
nodedata="$nodedata"'<owl:sameAs rdf:resource="http://data.bibliotheken.nl/doc/thes/p'$ppn'"/>'
nodedata="$nodedata"'<kbdef:ppn>'$ppn'</kbdef:ppn>'
nodedata="$nodedata"'<schema:license rdf:resource="http://creativecommons.org/publicdomain/zero/1.0/"/>'
nodedata="$nodedata"'<schema:isPartOf rdf:resource="http://data.bibliotheken.nl/id/dataset/brinkman"/>'
nodedata="$nodedata"'<schema:mainEntity rdf:resource="http://data.bibliotheken.nl/id/thes/p'$ppn'"/>'
nodedata="$nodedata"'<schema:dateModified rdf:datatype="http://www.w3.org/2001/XMLSchema#date">'$DATE_MODIFIED'</schema:dateModified>'

nodedata="$nodedata"'<schema:isBasedOn rdf:resource="http://services.kb.nl/mdo/oai?verb=GetRecord\&amp;identifier=GGC-THES:AC:'$ppn'\&amp;metadataPrefix=mdoall"/>'
node="<schema:mainEntityOfPage><schema:WebPage>$nodedata</schema:WebPage></schema:mainEntityOfPage>"
node=$node'<schema:mainEntityOfPage rdf:resource="http://data.bibliotheken.nl/doc/thes/p'$ppn'"/>'

line=$(echo $line | sed "s@</skos:Concept>@$node<skos:inScheme rdf:resource=\"http://data.bibliotheken.nl/id/scheme/brinkman\"/>$scopeNote</skos:Concept>@")

output_line
