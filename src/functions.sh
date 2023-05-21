#!/bin/bash

set +H

print_header() {
    echo "$HEADER"
}

print_footer()
{
    echo '</rdf:RDF>'
}

read_commandline_parameters()
{
    while getopts "xhf" option ; do
        case $option in
            x)  OUTPUT_XML=true
                ;;
            h)  print_header
                exit
                ;;
            f)  print_footer
                exit
                ;;
        esac
    done
    shift "$(($OPTIND -1))"
}

output_line() {
    if  [ "$OUTPUT_XML" = true ] ; then
        if [ ! -z "$line" ]  ; then
            (
                print_header
                echo $line
                print_footer
            ) | xmllint --format - | uconv -x any-nfc
        else
            echo ''
        fi
    else
        echo $line
    fi
}

validate_initial_conditions()
{
    MODIFICATION_DATE=`date -I`
    SED="sed"
    if [ "`uname`" == "Darwin" ] ; then
        if ! hash gsed 2>/dev/null; then
            echo "Requires GNU sed. Not found. Exiting."
            exit 1
        fi        
        SED="gsed"	
    fi
}


