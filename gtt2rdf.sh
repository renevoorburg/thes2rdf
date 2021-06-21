#/bin/bash

## known issues:

# processing using parallel causes entities to be translated to utf8 which is not wanted for <, > ...  This linke
#sed 's@<\([^:]*\)>@-\1-@g' | sed 's@Gupta, <@Gupta, @g' | sed 's@USUS>, <@USUS@g' | sed 's@<Mayaw@Mayaw@g'


#params:
DATE_MODIFIED="2021-04-21"



# header
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

	## core preparations / cleaning:
	
	#remove until rdf:RDF element
	#line=$(echo $line | sed 's@^.*<rdf:RDF[^>]*>@@')
	# and closing element
	#line=$(echo $line | sed 's@</rdf:RDF.*$@@')

	# restrict output to Brinkman
	line=$(echo $line | grep "http://data.kb.nl/dataset/GTT" -)



	## remove stuff we don't want:

	# remove <dc:type ....>....</dc:type> stuff
	line=$(echo $line | sed 's@<dc:type[^>]*>[^<]*</dc:type>@@g')

	# remove <skos:inScheme ...>
	line=$(echo $line | sed 's@<skos:inScheme[^>]*>@@g')

	# remove <void:inDataset ...>
	line=$(echo $line | sed 's@<void:inDataset[^>]*>@@')

	#UDC is a notation 
        #line=$(echo $line | sed 's@<skos:relatedMatch rdf:resource="http://www.udcc.org/\([0-9(][^"]*\)"/>@<skos:scopeNote rdf:datatype="http://udcdata.info/UDCnotation">\1</skos:scopeNote>@')
        line=$(echo $line | sed 's@<skos:relatedMatch rdf:resource="http://www.udcc.org/\([0-9(][^"]*\)"/>@<skos:relatedMatch rdf:datatype="http://udcdata.info/UDCnotation">\1</skos:relatedMatch>@')

	# SISO - custom notatoion datatype URI
        #line=$(echo $line | sed 's@<skos:relatedMatch rdf:resource="http://www.biblion.nl/siso/\([0-9(][^"]*\)"/>@<skos:scopeNote rdf:datatype="http://www.wikidata.org/entity/Q2582270">\1</skos:scopeNote>@')
        #line=$(echo $line | sed 's@<skos:relatedMatch rdf:resource="http://www.biblion.nl/siso/\([0-9(][^"]*\)"/>@<skos:scopeNote rdf:datatype="http://www.nbdbiblion.nl/SISO">\1</skos:scopeNote>@')
        line=$(echo $line | sed 's@<skos:relatedMatch rdf:resource="http://www.biblion.nl/siso/\([0-9(][^"]*\)"/>@<skos:relatedMatch rdf:datatype="http://www.nbdbiblion.nl/SISO">\1</skos:relatedMatch>@')

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
        nodedata="$nodedata"'<schema:isPartOf rdf:resource="http://data.bibliotheken.nl/id/dataset/gtt"/>'
        nodedata="$nodedata"'<schema:mainEntity rdf:resource="http://data.bibliotheken.nl/id/thes/p'$ppn'"/>'
        nodedata="$nodedata"'<schema:dateModified rdf:datatype="http://www.w3.org/2001/XMLSchema#date">'$DATE_MODIFIED'</schema:dateModified>'
        node="<schema:mainEntityOfPage><schema:WebPage>$nodedata</schema:WebPage></schema:mainEntityOfPage>"
        node=$node'<schema:mainEntityOfPage rdf:resource="http://data.bibliotheken.nl/doc/thes/p'$ppn'"/>'

        line=$(echo $line | sed "s@</skos:Concept>@$node<skos:inScheme rdf:resource=\"http://data.bibliotheken.nl/id/scheme/gtt\"/>$scopeNote</skos:Concept>@")




	## fixes:

	# remove unknow /empty schema:deathDate
	#line=$(echo $line | sed 's@<schema:deathDate/>@@')

        # remove unknow /empty schema:birthhDate
        #line=$(echo $line | sed 's@<schema:birthDate/>@@')

	# remove (bracketed) stuff from schema name:
	#line=$(echo $line | sed 's@\(<schema:name>[^(]*\)([^)]*)@\1@')

	# remove spaces before end tag:
	#line=$(echo $line | sed 's@\s*</@</@g')


	## output result:
	echo $line | grep '<'

done



# footer
echo '</rdf:RDF>'
