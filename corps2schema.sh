#!/bin/bash

HEADER='<?xml version="1.0" encoding="UTF-8"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#" xmlns:schema="http://schema.org/" xmlns:owl="http://www.w3.org/2002/07/owl#" xmlns:kbdef="http://data.bibliotheken.nl/def#">'

source $(dirname "$0")/src/functions.sh

read_commandline_parameters "$@"
validate_initial_conditions

#####

line=`cat <&0 | perl -pe 's@\n@@gi' | perl -pe 's@$@\n@'`

straat=$(echo $line | xmllint --xpath "//*[local-name()='datafield'][contains(@tag,'035')][1]/*[local-name()='subfield'][contains(@code, 'a')]/text()" 2> /dev/null - | recode html..html)
postbus=$(echo $line | xmllint --xpath "//*[local-name()='datafield'][contains(@tag,'035')][1]/*[local-name()='subfield'][contains(@code, 'b')]/text()" 2> /dev/null - | recode html..html)
postcode=$(echo $line | xmllint --xpath "//*[local-name()='datafield'][contains(@tag,'035')][1]/*[local-name()='subfield'][contains(@code, 'c')]/text()" 2> /dev/null - | recode html..html)
plaats=$(echo $line | xmllint --xpath "//*[local-name()='datafield'][contains(@tag,'035')][1]/*[local-name()='subfield'][contains(@code, 'd')]/text()" 2> /dev/null - | recode html..html)

postbus=$(echo "$postbus" | sed 's~^[^0-9]*~~')

#remove until rdf:RDF element
line=$(echo $line | $SED 's~^.*<rdf:RDF[^>]*>~~')
# and closing element
line=$(echo $line | $SED 's~</rdf:RDF.*$~~')

# restrict output to persons
line=$(echo $line | grep "http://data.kb.nl/dataset/Corporaties" -)

# remove <dc:type ....>....</dc:type> stuff
line=$(echo $line | $SED 's~<dc:type[^>]*>[^<]*</dc:type>~~g')

# remove <skos:inScheme ...>
line=$(echo $line | $SED 's~<skos:inScheme[^>]*>~~g')

# remove <void:inDataset ...>
line=$(echo $line | $SED 's~<void:inDataset[^>]*>~~')

# remove skos:editorialNote (see comment in header)
line=$(echo $line | $SED 's~<skos:scopeNote[^>]*>[^<]*</skos:scopeNote>~~g')

# retag as schema:Person iso skos:Concept
line=$(echo $line | $SED 's~skos:Concept~schema:Organization~g')

# schema:name iso skos:prefLabel
line=$(echo $line | $SED 's~skos:prefLabel~schema:name~g')

# set proper URI (http://data.kb.nl/thesaurus/191687707 =>  http://data.bibliotheken.nl/id/thes/p191687707"
line=$(echo $line | $SED 's~data.kb.nl/thesaurus/~data.bibliotheken.nl/id/thes/p~g')

# country code
line=$(echo $line | $SED 's~/gn:countryCode~/schema:addressCountry></schema:PostalAddress></schema:location~g')
line=$(echo $line | $SED 's~gn:countryCode~schema:location><schema:PostalAddress><schema:addressCountry~g')

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
line=$(echo $line | $SED 's~skos:editorialNote~schema:description~g')

# rename skos:scopeNote to rdfs:comment
line=$(echo $line | $SED 's~skos:historyNote~schema:description~g')

# rename skos:altLabel to schema:alternateName
line=$(echo $line | $SED 's~skos:altLabel~schema:alternateName~g')

# rename skos:exactMatch to schema:sameAs
line=$(echo $line | $SED 's~skos:related~rdfs:seeAlso~g')

# rename skos:related to schema:sameAs
line=$(echo $line | $SED 's@skos:broader@schema:parentOrganization@g')

# add 'meta' node:
ppn=$(echo $line | $SED 's~.*<schema:Organization rdf:about="http://data.bibliotheken.nl/id/thes/p\([0-9Xx]*\)">.*~\1~')
nodedata=''
nodedata="$nodedata"'<owl:sameAs rdf:resource="http://data.bibliotheken.nl/doc/thes/p'$ppn'"/>'
nodedata="$nodedata"'<kbdef:ppn>'$ppn'</kbdef:ppn>'
nodedata="$nodedata"'<schema:license rdf:resource="http://creativecommons.org/publicdomain/zero/1.0/"/>'
nodedata="$nodedata"'<schema:isPartOf rdf:resource="http://data.bibliotheken.nl/id/dataset/corps"/>'
nodedata="$nodedata"'<schema:mainEntity rdf:resource="http://data.bibliotheken.nl/id/thes/p'$ppn'"/>'
nodedata="$nodedata"'<schema:dateModified rdf:datatype="http://www.w3.org/2001/XMLSchema#date">'$DATE_MODIFIED'</schema:dateModified>'
nodedata="$nodedata"'<schema:isBasedOn rdf:resource="http://services.kb.nl/mdo/oai?verb=GetRecord\&amp;identifier=GGC-THES:AC:'$ppn'\&amp;metadataPrefix=mdoall"/>'
node="<schema:mainEntityOfPage><schema:AboutPage>$nodedata</schema:AboutPage></schema:mainEntityOfPage>"
node=$node'<schema:mainEntityOfPage rdf:resource="http://data.bibliotheken.nl/doc/thes/p'$ppn'"/>'

line=$(echo $line | $SED "s~</schema:Organization>~$node</schema:Organization>~")

## fixes:
# what are these? we'l remove them
line=$(echo $line | $SED 's~<schema:description>![^<]*</schema:description>~~g')
line=$(echo $line | $SED 's~<schema:description>B[0-9]*</schema:description>~~g')

# r
line=$(echo $line | $SED 's~<schema:dissolutionDate>\([0-9]*\)</schema:dissolutionDate>~<schema:dissolutionDate rdf:datatype="http://www.w3.org/2001/XMLSchema#gYear">\1</schema:dissolutionDate>~g')
line=$(echo $line | $SED 's~<schema:dissolutionDate>[^0-9]*</schema:dissolutionDate>~~g')

line=$(echo $line | $SED 's~<schema:foundingDate>\([0-9]*\)</schema:foundingDate>~<schema:foundingDate rdf:datatype="http://www.w3.org/2001/XMLSchema#gYear">\1</schema:foundingDate>~g')
line=$(echo $line | $SED 's~<schema:foundingDate>[^0-9]*</schema:foundingDate>~~g')

#
line=$(echo $line | $SED 's~<schema:description>"\(.*\)"</schema:description>~<schema:description>\1</schema:description>~g')

output_line
