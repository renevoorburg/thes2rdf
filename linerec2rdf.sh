#/bin/bash
set +H

# linerec2rdf.sh

read_commandline_parameters()
{
    PROG=$0
    SCRIPT_DIR=$(dirname "$PROG")
    while getopts "p:" option ; do
        case $option in
            h)  usage
                ;;
            p)  FILTER="$SCRIPT_DIR/$OPTARG"
                ;;
            ?)  usage
                ;;
        esac
    done
    shift "$(($OPTIND -1))"
}

usage()
{

    exit
}

check_software_dependencies()
{
    if ! hash xmllint 2>/dev/null; then
        echo "Requires xmllint. Not found. Exiting."
        exit 1
    fi
    if ! hash uconv 2>/dev/null; then
        echo "Requires uconv. Not found. Exiting."
        exit 1
    fi
    SED="sed"
    if [ "`uname`" == "Darwin" ] ; then
        if ! hash gsed 2>/dev/null; then
            echo "Requires GNU sed. Not found. Exiting."
            exit 1
        fi        
        SED="gsed"	
    fi
}

set_valid_initial_parameters()
{
    if [ ! -f "$FILTER" ] ; then
        echo "Filter not found. Please specify a filter to use (-p)."
        exit
    fi
}

read_commandline_parameters "$@"
check_software_dependencies
set_valid_initial_parameters


# main:
# $FILTER -f
# exit


(
    $FILTER -h
    
    while read line ; do
	    echo $line | $FILTER 
	done

    $FILTER -f
) | xmllint --format - | uconv -x any-nfc
