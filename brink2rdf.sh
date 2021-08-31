#/bin/bash

# brink2rdf.sh

# Creates rdf from the GGC-THES OAI-PMH dataset that lives at https://services.kb.nl/mdo/oai .
# Outputs RDF/XML that can be used at http://data.bibliotheken.nl/id/dataset/brinkman .

# Usage:

# 1. Harvest thesaurus data with oai2linesrec.sh (https://github.com/renevoorburg/oai2linerec) using:
# ./oai2linerec.sh -v -s GGC-THES -p mdoall -t 2021-06-21T00:00:00Z -b http://services.kb.nl/mdo/oai -o thesdata.xml
#
# Note: using an until date (-t) is strongly recommended!

# 2. Process the harvested xml:
# cat thesdata.xml | grep "dataset/Brinkman" | ./brink2rdf.sh {yyyy-mm-dd} | xmllint --format - | uconv -x any-nfc - > out.rdf
#
# Notes:
# 1. The DATE_MODIFIED parameter as supplied to this script {yyyy-mm-dd} will end up in the final RDF.
# 2. The pipe 'xmllint --format - | uconv -x any-nfc -' will ensure proper character encoding.

# check params supplied:
if [ "$#" -ne 1 ]
then
  echo "Please supply the modification date as paramater (for example 2021-03-11 )"
  exit 1
fi

#params:
DATE_MODIFIED=$1

# output header:
echo '<?xml version="1.0"?>'
echo '<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#" xmlns:schema="http://schema.org/" xmlns:owl="http://www.w3.org/2002/07/owl#"  xmlns:skos="http://www.w3.org/2004/02/skos/core#"  xmlns:kbdef="http://data.bibliotheken.nl/def#">'


# body
while read line ; do

	scopeNote=""
	echo $line | grep -q '<datafield tag="003Z"> <subfield code="0">vorm</subfield>' && if [ "$?" == "0" ] ; then
		scopeNote="<skos:scopeNote>vormtrefwoord</skos:scopeNote>"
	fi

	skos=$(echo $line | sed 's@.*\(<skos:Concept.*</skos:Concept>\).*@\1@' -)

	line="$skos"

	# restrict output to Brinkman
	line=$(echo $line | grep "http://data.kb.nl/dataset/Brinkman" -)

	## remove stuff we don't want:

	# remove <dc:type ....>....</dc:type> stuff
	line=$(echo $line | sed 's@<dc:type[^>]*>[^<]*</dc:type>@@g')

	# remove <skos:inScheme ...>
	line=$(echo $line | sed 's@<skos:inScheme[^>]*>@@g')

	# remove <void:inDataset ...>
	line=$(echo $line | sed 's@<void:inDataset[^>]*>@@')

	#UDC is a notation
    line=$(echo $line | sed 's@<skos:relatedMatch rdf:resource="http://www.udcc.org/\([0-9(][^"]*\)"/>@<skos:relatedMatch rdf:datatype="http://udcdata.info/UDCnotation">\1</skos:relatedMatch>@')

	# SISO - custom notatoion datatype URI
    line=$(echo $line | sed 's@<skos:relatedMatch rdf:resource="http://www.biblion.nl/siso/[0-9(][^"]*"/>@@')

	# remove other skos:relatedMatch
    line=$(echo $line | sed 's@<skos:relatedMatch rdf:resource="[^"]*"/>@@g')



	## rename to our standards:

	# set proper URI (http://data.kb.nl/thesaurus/191687707 =>  http://data.bibliotheken.nl/id/thes/p191687707"
	line=$(echo $line | sed 's@data.kb.nl/thesaurus/@data.bibliotheken.nl/id/thes/p@g')

        # add 'meta' node:
        ppn=$(echo $line | sed 's@.*<skos:Concept rdf:about="http://data.bibliotheken.nl/id/thes/p\([0-9Xx]*\)">.*@\1@')
        nodedata='<rdf:type rdf:resource="http://schema.org/Dataset"/>'
        nodedata="$nodedata"'<owl:sameAs rdf:resource="http://data.bibliotheken.nl/doc/thes/p'$ppn'"/>'
        nodedata="$nodedata"'<kbdef:ppn>'$ppn'</kbdef:ppn>'
        nodedata="$nodedata"'<schema:license rdf:resource="http://opendatacommons.org/licenses/by/1-0/"/>'
        nodedata="$nodedata"'<schema:isPartOf rdf:resource="http://data.bibliotheken.nl/id/dataset/brinkman"/>'
        nodedata="$nodedata"'<schema:mainEntity rdf:resource="http://data.bibliotheken.nl/id/thes/p'$ppn'"/>'
        nodedata="$nodedata"'<schema:dateModified rdf:datatype="http://www.w3.org/2001/XMLSchema#date">'$DATE_MODIFIED'</schema:dateModified>'

        nodedata="$nodedata"'<schema:isBasedOn rdf:resource="http://services.kb.nl/mdo/oai?verb=GetRecord\&amp;identifier=GGC-THES:AC:'$ppn'\&amp;metadataPrefix=mdoall"/>'
        node="<schema:mainEntityOfPage><schema:WebPage>$nodedata</schema:WebPage></schema:mainEntityOfPage>"
        node=$node'<schema:mainEntityOfPage rdf:resource="http://data.bibliotheken.nl/doc/thes/p'$ppn'"/>'

        line=$(echo $line | sed "s@</skos:Concept>@$node<skos:inScheme rdf:resource=\"http://data.bibliotheken.nl/id/scheme/brinkman\"/>$scopeNote</skos:Concept>@")

	## output result:
	echo $line | grep '<'

done

# footer
echo '</rdf:RDF>'
