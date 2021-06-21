#/bin/bash

# corp2rdf.sh

# Creates rdf from the GGC-THES OAI-PMH dataset that lives at https://services.kb.nl/mdo/oai .
# Outputs RDF/XML that can be used at http://data.bibliotheken.nl/id/dataset/corps .

# Usage:

# 1. Harvest thesaurus data with oai2linesrec.sh (https://github.com/renevoorburg/oai2linerec) using:
# ./oai2linerec.sh -v -s GGC-THES -p mdoall -t 2021-06-21T00:00:00Z -b http://services.kb.nl/mdo/oai -o thesdata.xml
#
# Note: using an until date (-t) is strongly recommended!

# 2. Process the harvested xml:
# cat thesdata.xml | grep "set/Corp" | ./nta2rdf.sh | xmllint --format - | uconv -x any-nfc - > out.rdf
#
# Notes:
# 1. The DATE_MODIFIED paramete as defined in this script will end up in the final RDF.
# 2. The pipe 'xmllint --format - | uconv -x any-nfc -' will ensure proper character encoding.


#params:
DATE_MODIFIED="2020-12-07"


# header
echo '<?xml version="1.0" encoding="UTF-8"?>'
echo '<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#" xmlns:schema="http://schema.org/" xmlns:owl="http://www.w3.org/2002/07/owl#" xmlns:kbdef="http://data.bibliotheken.nl/def#">'

# body
while read line ; do

	## core preparations / cleaning:

	straat=$(echo $line | xmllint --xpath "//*[local-name()='datafield'][contains(@tag,'035')][1]/*[local-name()='subfield'][contains(@code, 'a')]/text()" 2> /dev/null - | recode html..html)
	postbus=$(echo $line | xmllint --xpath "//*[local-name()='datafield'][contains(@tag,'035')][1]/*[local-name()='subfield'][contains(@code, 'b')]/text()" 2> /dev/null - | recode html..html)
	postcode=$(echo $line | xmllint --xpath "//*[local-name()='datafield'][contains(@tag,'035')][1]/*[local-name()='subfield'][contains(@code, 'c')]/text()" 2> /dev/null - | recode html..html)
	plaats=$(echo $line | xmllint --xpath "//*[local-name()='datafield'][contains(@tag,'035')][1]/*[local-name()='subfield'][contains(@code, 'd')]/text()" 2> /dev/null - | recode html..html)

	postbus=$(echo "$postbus" | sed 's~^[^0-9]*~~')

	#remove until rdf:RDF element
	line=$(echo $line | sed 's~^.*<rdf:RDF[^>]*>~~')
	# and closing element
	line=$(echo $line | sed 's~</rdf:RDF.*$~~')

	# restrict output to persons
	line=$(echo $line | grep "http://data.kb.nl/dataset/Corporaties" -)

	## remove stuff we don't want:

	# remove <dc:type ....>....</dc:type> stuff
	line=$(echo $line | sed 's~<dc:type[^>]*>[^<]*</dc:type>~~g')

	# remove <skos:inScheme ...>
	line=$(echo $line | sed 's~<skos:inScheme[^>]*>~~g')

	# remove <void:inDataset ...>
	line=$(echo $line | sed 's~<void:inDataset[^>]*>~~')

	# remove skos:editorialNote (see comment in header)
	line=$(echo $line | sed 's~<skos:scopeNote[^>]*>[^<]*</skos:scopeNote>~~g')


	## rename to our standards:

	# retag as schema:Person iso skos:Concept
	line=$(echo $line | sed 's~skos:Concept~schema:Organization~g')

    # schema:name iso skos:prefLabel
    line=$(echo $line | sed 's~skos:prefLabel~schema:name~g')

	# set proper URI (http://data.kb.nl/thesaurus/191687707 =>  http://data.bibliotheken.nl/id/thes/p191687707"
	line=$(echo $line | sed 's~data.kb.nl/thesaurus/~data.bibliotheken.nl/id/thes/p~g')

	# country code
        line=$(echo $line | sed 's~/gn:countryCode~/schema:addressCountry></schema:PostalAddress></schema:location~g')
        line=$(echo $line | sed 's~gn:countryCode~schema:location><schema:PostalAddress><schema:addressCountry~g')


        if [ ! -z "$plaats" ] ; then
                line=$(echo $line | perl -pe "s~<schema:PostalAddress>~<schema:PostalAddress><schema:addressLocality>$plaats</schema:addressLocality>~")
        fi

        if [ ! -z "$postcode" ] ; then
                line=$(echo $line | perl -pe "s~<schema:PostalAddress>~<schema:PostalAddress><schema:postalCode>$postcode</schema:postalCode>~")
        fi

        if [ ! -z "$postbus" ] ; then
                line=$(echo $line | perl -pe "s~<schema:PostalAddress>~<schema:PostalAddress><schema:postOfficeBoxNumber>$postbus</schema:postOfficeBoxNumber>~")
        fi

	if [ ! -z "$straat" ] ; then
                line=$(echo $line | perl -pe  "s~<schema:PostalAddress>~<schema:PostalAddress><schema:streetAddress>$straat</schema:streetAddress>~")
        fi



	## rename skos:editorialNote to rdfs:comment
	line=$(echo $line | sed 's~skos:editorialNote~schema:description~g')

	# rename skos:scopeNote to rdfs:comment
	line=$(echo $line | sed 's~skos:historyNote~schema:description~g')

	# rename skos:altLabel to schema:alternateName
	line=$(echo $line | sed 's~skos:altLabel~schema:alternateName~g')

	# rename skos:exactMatch to schema:sameAs
	line=$(echo $line | sed 's~skos:related~rdfs:seeAlso~g')

	# rename skos:related to schema:sameAs
	line=$(echo $line | sed 's@skos:broader@schema:parentOrganization@g')


	# add 'meta' node:
	ppn=$(echo $line | sed 's~.*<schema:Organization rdf:about="http://data.bibliotheken.nl/id/thes/p\([0-9Xx]*\)">.*~\1~')
        nodedata='<rdf:type rdf:resource="http://schema.org/Dataset"/>'
	nodedata="$nodedata"'<owl:sameAs rdf:resource="http://data.bibliotheken.nl/doc/thes/p'$ppn'"/>'
	nodedata="$nodedata"'<kbdef:ppn>'$ppn'</kbdef:ppn>'
	nodedata="$nodedata"'<schema:license rdf:resource="http://creativecommons.org/publicdomain/zero/1.0/"/>'
	nodedata="$nodedata"'<schema:isPartOf rdf:resource="http://data.bibliotheken.nl/id/dataset/corps"/>'
	nodedata="$nodedata"'<schema:mainEntity rdf:resource="http://data.bibliotheken.nl/id/thes/p'$ppn'"/>'
	nodedata="$nodedata"'<schema:dateModified rdf:datatype="http://www.w3.org/2001/XMLSchema#date">'$DATE_MODIFIED'</schema:dateModified>'
        nodedata="$nodedata"'<schema:isBasedOn rdf:resource="http://services.kb.nl/mdo/oai?verb=GetRecord\&amp;identifier=GGC-THES:AC:'$ppn'\&amp;metadataPrefix=mdoall"/>'
	node="<schema:mainEntityOfPage><schema:WebPage>$nodedata</schema:WebPage></schema:mainEntityOfPage>"
        node=$node'<schema:mainEntityOfPage rdf:resource="http://data.bibliotheken.nl/doc/thes/p'$ppn'"/>'

	line=$(echo $line | sed "s~</schema:Organization>~$node</schema:Organization>~")


	## fixes:
	# what are these? we'l remove them
	line=$(echo $line | sed 's~<schema:description>![^<]*</schema:description>~~g')
	line=$(echo $line | sed 's~<schema:description>B[0-9]*</schema:description>~~g')

	# r
	line=$(echo $line | sed 's~<schema:dissolutionDate>\([0-9]*\)</schema:dissolutionDate>~<schema:dissolutionDate rdf:datatype="http://www.w3.org/2001/XMLSchema#gYear">\1</schema:dissolutionDate>~g')
	line=$(echo $line | sed 's~<schema:dissolutionDate>[^0-9]*</schema:dissolutionDate>~~g')

	line=$(echo $line | sed 's~<schema:foundingDate>\([0-9]*\)</schema:foundingDate>~<schema:foundingDate rdf:datatype="http://www.w3.org/2001/XMLSchema#gYear">\1</schema:foundingDate>~g')
	line=$(echo $line | sed 's~<schema:foundingDate>[^0-9]*</schema:foundingDate>~~g')

	#
	line=$(echo $line | sed 's~<schema:description>"\(.*\)"</schema:description>~<schema:description>\1</schema:description>~g')

	## output result:
	echo $line | grep '<'

done


# footer
echo '</rdf:RDF>'
