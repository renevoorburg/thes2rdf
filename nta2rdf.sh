#/bin/bash

# nta2rdf.sh

# Creates rdf from the GGC-THES OAI-PMH dataset that lives at https://services.kb.nl/mdo/oai .
# Outputs RDF/XML that can be used at http://data.bibliotheken.nl/id/dataset/persons .

# Usage:

# 1. Harvest thesaurus data with oai2linesrec.sh (https://github.com/renevoorburg/oai2linerec) using:
# ./oai2linerec.sh -v -s GGC-THES -p mdoall -t 2021-06-21T00:00:00Z -b http://services.kb.nl/mdo/oai -o thesdata.xml
#
# Note: using an until date (-t) is strongly recommended!

# 2. Process the harvested xml:
# cat thesdata.xml | grep "set/GTT"" | ./nta2rdf.sh | xmllint --format - | uconv -x any-nfc - > out.rdf
#
# Notes:
# 1. The DATE_MODIFIED parameter as supplied will end up in the final RDF.
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
echo '<?xml version="1.0" encoding="UTF-8"?>'
echo '<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#" xmlns:schema="http://schema.org/" xmlns:owl="http://www.w3.org/2002/07/owl#" xmlns:foaf="http://xmlns.com/foaf/0.1/" xmlns:void="http://rdfs.org/ns/void#" xmlns:kbdef="http://data.bibliotheken.nl/def#">'


# body
while read line ; do

	## core preparations / cleaning:

	# grab isni
	isni=$(echo $line | xmllint --xpath "//*[local-name()='datafield'][contains(@tag,'003B')][*[local-name()='subfield'][contains(@code, '2')]='isni']/*[local-name()='subfield'][contains(@code, 'a')]/text()" 2> /dev/null -)
	isni=$(echo $isni | egrep "[0-9]{16}")

	#
        natio=$(echo $line | xmllint --xpath "//*[local-name()='datafield'][contains(@tag,'019@')][1]/*[local-name()='subfield'][contains(@code, 'a')]/text()" 2> /dev/null -)

	# continu processing skos
        skos=$(echo $line | sed 's@.*\(<skos:Concept.*</skos:Concept>\).*@\1@' -)
        line="$skos"

	#remove until rdf:RDF element
	line=$(echo $line | sed 's@^.*<rdf:RDF[^>]*>@@')
	# and closing element
	line=$(echo $line | sed 's@</rdf:RDF.*$@@')

	# restrict output to persons
	line=$(echo $line | grep "http://data.kb.nl/dataset/Persoonsnamen" -)

	## remove stuff we don't want:
	line=$(echo $line | sed 's@<dc:type[^>]*>[^<]*</dc:type>@@g')
	line=$(echo $line | sed 's@<skos:inScheme[^>]*>@@g')
	line=$(echo $line | sed 's@<void:inDataset[^>]*>@@')
	#line=$(echo $line | sed 's@<foaf:name[^>]*>[^<]*</foaf:name>@@g')


	## rename to our standards:

	# retag as schema:Person iso skos:Concept
	line=$(echo $line | sed 's@skos:Concept@schema:Person@g')

	# add ISNI
	if [ ! -z "$isni" ] ; then
		line=$(echo $line | sed "s@</schema:Person>@<schema:sameAs rdf:resource=\"http://www.isni.org/isni/$isni\"/></schema:Person>@")
	fi

       if [ ! -z "$natio" ] ; then
                line=$(echo $line | sed  "s@</schema:Person>@<schema:nationality>$natio</schema:nationality></schema:Person>@")
        fi


        # schema:name iso skos:prefLabel
        #line=$(echo $line | sed 's@skos:prefLabel@schema:name@g')
        line=$(echo $line | sed 's@skos:prefLabel@rdfs:label@g')


	# schema:givenName iso foaf:givenName
        line=$(echo $line | sed 's@foaf:name@schema:name@g')
        line=$(echo $line | sed 's@foaf:givenName@schema:givenName@g')

	#
	line=$(echo $line | sed 's@foaf:familyName@schema:familyName@g')

	# set proper URI (http://data.kb.nl/thesaurus/191687707 =>  http://data.bibliotheken.nl/id/thes/p191687707"
	line=$(echo $line | sed 's@data.kb.nl/thesaurus/@data.bibliotheken.nl/id/thes/p@g')

	## rename skos:editorialNote to rdfs:comment
	line=$(echo $line | sed 's@skos:editorialNote@schema:description@g')

	# rename skos:scopeNote to rdfs:comment
	line=$(echo $line | sed 's@skos:scopeNote@schema:description@g')

	# rename skos:altLabel to schema:alternateName
	line=$(echo $line | sed 's@skos:altLabel@schema:alternateName@g')

	# rename skos:exactMatch to schema:sameAs
	line=$(echo $line | sed 's@skos:exactMatch@schema:sameAs@g')

	# rename skos:related to schema:sameAs
	line=$(echo $line | sed 's@skos:related@schema:sameAs@g')


        # add 'meta' node:
        ppn=$(echo $line | sed 's@.*<schema:Person rdf:about="http://data.bibliotheken.nl/id/thes/p\([0-9Xx]*\)">.*@\1@')
        nodedata='<rdf:type rdf:resource="http://schema.org/Dataset"/>'
        nodedata="$nodedata"'<owl:sameAs rdf:resource="http://data.bibliotheken.nl/doc/thes/p'$ppn'"/>'
        nodedata="$nodedata"'<kbdef:ppn>'$ppn'</kbdef:ppn>'
        nodedata="$nodedata"'<schema:license rdf:resource="http://opendatacommons.org/licenses/by/1-0/"/>'
        nodedata="$nodedata"'<schema:isPartOf rdf:resource="http://data.bibliotheken.nl/id/dataset/persons"/>'
        nodedata="$nodedata"'<schema:mainEntity rdf:resource="http://data.bibliotheken.nl/id/thes/p'$ppn'"/>'
        nodedata="$nodedata"'<schema:dateModified rdf:datatype="http://www.w3.org/2001/XMLSchema#date">'$DATE_MODIFIED'</schema:dateModified>'
	nodedata="$nodedata"'<schema:isBasedOn rdf:resource="http://services.kb.nl/mdo/oai?verb=GetRecord\&amp;identifier=GGC-THES:AC:'$ppn'\&amp;metadataPrefix=mdoall"/>'
        node="<schema:mainEntityOfPage><schema:WebPage>$nodedata</schema:WebPage></schema:mainEntityOfPage>"
        #node=$node'<schema:mainEntityOfPage rdf:resource="http://data.bibliotheken.nl/doc/thes/p'$ppn'"/>'
        line=$(echo $line | sed "s@</schema:Person>@$node</schema:Person>@")

	## fixes:

	# remove unknow /empty schema:deathDate
	line=$(echo $line | sed 's@<schema:deathDate/>@@')

        # remove unknow /empty schema:birthhDate
        line=$(echo $line | sed 's@<schema:birthDate/>@@')

	# add datatype to deathDate:
	line=$(echo $line | sed 's@<schema:deathDate>\([0-9]*\)</schema:deathDate>@<schema:deathDate rdf:datatype="http://www.w3.org/2001/XMLSchema#gYear">\1</schema:deathDate>@')

	# add datatype to birthDate:
	line=$(echo $line | sed 's@<schema:birthDate>\([0-9]*\)</schema:birthDate>@<schema:birthDate rdf:datatype="http://www.w3.org/2001/XMLSchema#gYear">\1</schema:birthDate>@')

	# remove spaces before end tag:
	line=$(echo $line | sed 's@\s*</@</@g')

	## output result:
	echo $line

done

# footer
echo '</rdf:RDF>'
