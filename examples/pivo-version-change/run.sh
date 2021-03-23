
. /lib.sh

# Dispatch the command according to what was specified in the command line
if [ -z ${1+x} ];
then
    echo "Error: no command was specified.";
    exit 1
else
    case $1 in
        register )
            echo "Registering a stakepool"
            exit
        * )
            echo "Unknown command $1"
            exit 1
    esac
fi
