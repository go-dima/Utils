#!/bin/bash

usage() {
    echo -e "\nUsage: ./commander.sh <command> -param <parameter>"
    echo -e "\t"    "cmd1"        	"\t"    "Run cmd1"
    echo -e "\t"    "cmd2"   		"\t"    "Run cmd2"
    echo -e "\t"    "-h --help"     "\t"   	"Show usage"
}

commandError() {
    usage
    exit 1
}

function1() {
    echo "Running function1.."
}


function2() {
    echo "Running function2.."
}

#Read options
while test $# -gt 0; do
    case "$1" in
        cmd1|\
        cmd2)
            COMMAND=$1
            shift
            ;;
        -param)
            shift # skip flag
            PARAMETER=$1
            shift
            ;;
        -h|\
        --help)
            usage
            shift
            exit 0
            ;;
        *)
           echo "$1 is not a recognized parameter"
           commandError
           ;;
    esac
done

if [[ -z ${COMMAND} ]]; then
    echo Error: Command not specified.
    commandError
fi

if [[ -z ${PARAMETER} ]]; then
    echo Warning: Paremeter not specified.
fi

case "$COMMAND" in
    cmd1)
        function1
        ;;
    cmd1)
        function1
		function2
		;;
esac
