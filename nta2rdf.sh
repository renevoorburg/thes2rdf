#/bin/bash

# nta2rdf.sh
# 2023-05-17

# Creates rdf from the GGC-THES OAI-PMH dataset that lives at https://services.kb.nl/mdo/oai .
# Outputs RDF/XML that can be used at http://data.bibliotheken.nl/id/dataset/persons .
# Assumes each record to be processed to be on a single line.

# Usage:

# 1. Harvest thesaurus data with https://github.com/renevoorburg/oai2linerec using:
# ./oai2linerec.sh -s GGC-THES -p mdoall -b http://services.kb.nl/mdo/oai -o thesdata.xml
# (or use https://github.com/renevoorburg/oailite and process each record individually).


# 2. Process the harvested xml:
# cat thesdata.xml | grep "dataset/Persoonsnamen"" | ./nta2rdf.sh {yyyy-mm-dd} > out.rdf
#
# The optional parameter will be used a a modification data that ends up in the RDF.


# check for input parameter:
if [ "$#" -eq 1 ] ; then
    MODIFICATION_DATE=$1
else
    MODIFICATION_DATE=`date -I`
fi

# check_software_dependencies
if ! hash xmllint 2>/dev/null; then
    echo "Requires xmllint. Not found. Exiting."
    exit 1
fi
if ! hash uconv 2>/dev/null; then
    echo "Requires uconv. Not found. Exiting."
    exit 1
fi
if [ "`uname`" == "Darwin" ] ; then
    if ! hash gsed 2>/dev/null; then
        echo "Requires GNU sed. Not found. Exiting."
        exit 1
    fi        
    alias sed="gsed"
fi


# main:
(
    echo '<?xml version="1.0" encoding="UTF-8"?>'
    echo '<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#" xmlns:schema="http://schema.org/" xmlns:owl="http://www.w3.org/2002/07/owl#" xmlns:foaf="http://xmlns.com/foaf/0.1/" xmlns:void="http://rdfs.org/ns/void#" xmlns:kbdef="http://data.bibliotheken.nl/def#">'

    while read line ; do

    	## core preparations / cleaning:
	    # grab isni
	    isni=$(echo $line | xmllint --xpath "//*[local-name()='datafield'][contains(@tag,'003B')][*[local-name()='subfield'][contains(@code, '2')]='isni']/*[local-name()='subfield'][contains(@code, 'a')]/text()" 2> /dev/null -)
	    isni=$(echo $isni | egrep "[0-9]{16}")

	    # grab nationality
	    natio=$(echo $line | xmllint --xpath "//*[local-name()='datafield'][contains(@tag,'019@')][1]/*[local-name()='subfield'][contains(@code, 'a')]/text()" 2> /dev/null -)
	    natio=$(echo $natio | awk '{print$1}' | egrep "[a-z]*")

	    # continu processing skos
	    skos=$(echo $line | sed 's@.*\(<skos:Concept.*</skos:Concept>\).*@\1@' - )
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
	    nodedata="$nodedata"'<schema:license rdf:resource="http://creativecommons.org/publicdomain/zero/1.0/"/>'
	    nodedata="$nodedata"'<schema:isPartOf rdf:resource="http://data.bibliotheken.nl/id/dataset/persons"/>'
	    nodedata="$nodedata"'<schema:mainEntity rdf:resource="http://data.bibliotheken.nl/id/thes/p'$ppn'"/>'
	    nodedata="$nodedata"'<schema:dateModified rdf:datatype="http://www.w3.org/2001/XMLSchema#date">'$MODIFICATION_DATE'</schema:dateModified>'
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

	    # output
	    echo $line
	done

	echo '</rdf:RDF>'
) | xmllint --format - | uconv -x any-nfc
