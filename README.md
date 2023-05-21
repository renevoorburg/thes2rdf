# thes2rdf
Converts OAI-PMH based KB thesaurus data to RDF for data.bibliotheken.nl. Can be used with output from [https://github.com/renevoorburg/oai2linerec](https://github.com/renevoorburg/oai2linerec) ("line records", records on a single line, separared by a newline character), or with output from [https://github.com/renevoorburg/oailite ](https://github.com/renevoorburg/oailite)(records in an sqlite database).

It comes with 4 parsers, for 4 RDF datasets that can be found at [http://data.bibliotheken.nl/](https://github.com/renevoorburg/oailite) :

* `brinkman2schema.sh`, for the Brinkman thesaurus as skos (+schema) at [http://data.bibliotheken.nl/id/dataset/brinkman](http://data.bibliotheken.nl/id/dataset/brinkman)
* `corps2schema.sh`, for the corporation thesaurus at [http://data.bibliotheken.nl/id/dataset/corps](http://data.bibliotheken.nl/id/dataset/corps)
* `gtt2schema.sh`, for the GTT/GOO thesaurus as skos (+schema) at [http://data.bibliotheken.nl/id/dataset/gtt]()
* `nta2schema.org`, for schema Persons from the Nederlandse Thesaurus van Auteursnamen (NTA), at [http://data.bibliotheken.nl/id/dataset/persons](http://data.bibliotheken.nl/id/dataset/persons).


An example how use it with line records as created by oai2linerec.sh, here to create RDF with NTA Persons:

	cat linerecords.txt | ./linerec2rdf.sh -p ./nta2schema.sh > persons.xml

To use it with records stored in an sqlite database, as created by `oailite.sh`, specify the parser to use when calling `dbwalker.sh` (part of [https://github.com/renevoorburg/oailite ](https://github.com/renevoorburg/oailite)):

	./dbwalker.sh -s SOURCE.db -t TABLE -p "nta2schema.sh -x" -d DESTINATION_DB.db
	
The parser option `-x` ensures that the required RDF wrapper element, including namespace definitions, and XML declaration are added, and that the XML is normalized. 
