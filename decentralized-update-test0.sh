
set -euo pipefail

if [ -z ${1+x} ];
then
    echo "'redeploy' command was not specified, so the test will run on an existing testnet";
else
    case $1 in
        redeploy )
            echo "Redeploying the testnet"
            nixops destroy
            create-shelley-genesis-and-keys
            nixops deploy -k
            ;;
        * )
            echo "Unknown command $1"
            exit
    esac
fi

sleep 30

# TODO: can we get this from the nix files?
BFT_NODES=( bft-a-1 )
POOL_NODES=( stk-b-1-IOHK1 stk-c-1-IOHK2 stk-d-1-IOHK3 )

for f in ${BFT_NODES[@]}
do
    nixops scp $f submit-update-proposal.sh /root/ --to
done

for f in ${POOL_NODES[@]}
do
    nixops scp $f register-stake-pool.sh /root/ --to
done

for f in ${BFT_NODES[@]}
do
    nixops ssh $f "./submit-update-proposal.sh"
done

for f in ${POOL_NODES[@]}
do
    nixops ssh $f "./register-stake-pool.sh" &
done

wait
