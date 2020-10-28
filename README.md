# cardano-ops
NixOps deployment configuration for IOHK/Cardano devops

TODO's:

- [ ] Make sure that all shell commands start with ▶

## Deploying a testnet

The following instructions assume you have a Unix system and
[nix](https://nixos.org/download.html "nix installation instructions")
installed.

## Create topology files

To spin up a custom cluster first create global topology files using the
available templates:

```sh
export MYENV=my-env # Choose the name of your environment.
globals-shelley-dev.nix globals-$MYENV.nix
ln -s globals-$MYENV.nix globals.nix
cp topologies/shelley-dev.nix topologies/$MYENV.nix
```

After the files above are created change the `enviromentName` of
`globals-$MYENV.nix` so that it matches the value of your environment
("my-env") in the preceding example.

```nix
pkgs: with pkgs.iohkNix.cardanoLib; rec {

  // ...
  environmentName = "my-env";

  // ...
}
```

## Enter the nix-shell

Once the topology files are created and configured, you can enter the nix
shell, which provides the correct environment for deployment, as well as bash
completion for `cardano-cli`.

```sh
nix-shell
```

Alternatively, you can install `lorri` which provides a [superior
alternative](https://youtu.be/WtbW0N8Cww4 "YouTube video explaining lorri") to
`nix-shell`. Installing and configuring `lorri` is outside of the scope of this
tutorial.

## Generate genesis file and keys

Run:

```sh
create-shelley-genesis-and-keys
```

The generated genesis file can be found at `keys/genesis.json`.

TODO's:
- what does this do?
- Which files are used an input?
- Which files are used as output?
- What are important parameters on

## Deploy the testnet

The testnet can be deployed locally or on [Amazon EC2
instances](https://aws.amazon.com/ec2 "Page about Amazon EC2 instances").

The deployment is made using [`nixops`](https://nixos.org/nixops/manual/
"nixops manual"). This means that starting and stopping the testnet, as well as
performing operations on the nodes (like logging in to the via ssh) should be
done via the `nixops` command. We'll see examples of such commands later on.

TODO's:
- Talk about how the deployments are set.

### Setup a local deployment

The local deployment requires
[libvirt](https://libvirt.org/manpages/libvirtd.html "libvirt site").

To setup on NixOS first enable `libvirtd` (TODO: which file is this?):

```nix
{ pkgs, lib, ... }:
{
  virtualisation.libvirtd.enable             = true;
  systemd.services.libvirtd.restartIfChanged = lib.mkForce true;
  networking.firewall.checkReversePath       = false;
  environment.systemPackages                 = with pkgs; [ virtmanager ];
}
```

On Ubuntu refer to [these
instructions](https://ubuntu.com/server/docs/virtualization-libvirt
"Instructions on how to install libvirt").

For other Linux distros refer to their documentation on how to install
`libvirt`.

After libvirt is installed and configured, check whether the default pool is
available. Run as root:

```sh
virsh pool-list
```

You should see the following output:

```text
 Name                 State      Autostart
-------------------------------------------
 default              active     yes
```

If the `default` pool is not setup yet, as `root` run:

```sh
virsh pool-define /dev/stdin <<EOF
<pool type='dir'>
  <name>default</name>
  <target>
    <path>/var/lib/libvirt/images</path>
  </target>
</pool>
EOF
# virsh pool-start default
# virsh pool-autostart default
```

and check that the default pools is listed when running `virsh pool-list`.

Once the default pool is available, the local deployment can be started using
the following script:

```sh
./scripts/create-libvirtd.sh
```

### Setup an AWS deplyoment

To deploy on AWS you need to add your ssh key to the `cls-developers` attribute
in `overlays/ssh-keys.nix`. This file can be found in the
[`ops-lib`](https://github.com/input-output-hk/ops-lib/ "ops-lib repository")
repository.

Once your key is added, you can start an AWS deployment using the following
script:

```sh
./scripts/create-aws.sh
```

### Operating on the testnet using nixops

To start the testnet use:

```sh
nixops start
```

To stop the network use:

```sh
nixops stop
```

To ssh to a node use

```sh
nixops ssh nodename
```

Where `nodename` is one of the node names specified in the
`topologies/$MYENV.nix` file we created early on.

### Querying the log files

To follow the logs:

```sh
journalctl -u cardano-node -f -n40
```

```sh
journalctl -u cardano-node -b
```

Or to query the status

```sh
systemctl status cardano-node --lines=20
```

Change the value of the `lines` flag if needed, or omit it if the default suits
your needs.

### About the different kind of keys

Look in the keys directory.

### Updating genesis and key files

TODO: ask JB: is this correct?

```sh
nixops deploy -k
```

In the command above we use the `-k` flag to tell nixops to remove obsolete
resources. You can omit this to keep them.

TODO: ask JB: is this correct?

Starting afresh:

```sh
nixops ssh-for-each --parallel "systemctl stop cardano-node && rm -fr /var/lib/cardano-node"
create-shelley-genesis-and-keys
nixops deploy
```

## Howtos

### Change logging levels

The logging configuration of a node is explained in the [Cardano
documentation](https://docs.cardano.org/projects/cardano-node/en/latest/getting-started/understanding-config-files.html#tracing).
In this section we show how logging can be configured in the nix deployment.

To change the logging level of all the nodes you have to modify the
`globals-$MYENV.nix` file. For example, to change the logging level of
`TraceBlockFetchProtocol` in node `a` we can edit this file as follows:

```nix
nodeConfig = lib.recursiveUpdate environments.shelley_qa.nodeConfig {
      ShelleyGenesisFile = genesisFile;
      ShelleyGenesisHash = genesisHash;
      Protocol = "TPraos";
      TraceBlockFetchProtocol = true;
    };
```

To change the logging level per-node you have to modify the
`topologies/$MYENV.nix` file. For instance, to change the logging level of
`TraceBlockFetchProtocol` in node `a` we can edit this file as follows:

```nix
{
      name = "a";
      nodeId = 1;
      org = "IOHK";
      region = "eu-central-1";
      producers = ["b" "c"];
      services.cardano-node.nodeConfig = {
        TraceBlockFetchProtocol = true;
        //... other settings
      };
}
```

### Query UTxO

```sh
cardano-cli shelley query utxo --testnet-magic 42 --shelley-mode
```

Querying the UTxO for a specific address. First you need the verification key
to obtain the address:

```sh
cardano-cli shelley genesis initial-addr \
                --testnet-magic 42 \
                --verification-key-file utxo-keys/utxo1.vkey
```

This will return an address like the following:

```text
addr_test1vqrl9rphzv064dsfuc3dfumxwnsm8syhj4yucdkrtntxvyqcld79a
```

This address can be used to query a specific UTxO:

```sh
cardano-cli shelley query utxo --testnet-magic 42 --shelley-mode\
     --address addr_test1vqrl9rphzv064dsfuc3dfumxwnsm8syhj4yucdkrtntxvyqcld79a
```

### Finding keys

In the nodes they are stored in `/var/lib/keys`:

```text
# ls /var/lib/keys
cardano-node-kes-signing  cardano-node-operational-cert  cardano-node-vrf-signing
```



### Use a different cardano-node version

The `cardano-ops` repository uses [`niv`](https://github.com/nmattia/niv "niv
project page") to manage dependencies. To update `cardano-node` to use a
specific branch run (inside a nix-shell if you are not using lorri):
<!-- TODO: maybe this guide should be opinionated and just use lorri -->

```
niv update cardano-node -b <branch>
```

To list all the components managed by `niv` run:

```
niv show
```

### Querying protocol parameters

```
cardano-cli shelley query protocol-parameters --testnet-magic 42 --shelley-mode --out-file pparams.json
```


### Copying files to a node

```sh
nixops scp a keys/utxo-keys /root --to
```

### Querying the hash of the initial transaction input

```sh
cardano-cli shelley genesis initial-addr \
                --testnet-magic 42 \
                --verification-key-file utxo-keys/utxo1.vkey
```

### Getting information about the nixops deployment

```sh
nixops list
```


```sh
nixops info
```

### Creating a simple transaction

First we need to copy the keys to an node.

```sh
▶ nixops scp stk-d-1-IOHK1 keys/utxo-keys /root --to
```

ssh to the node where the keys were copied:

```ssh
▶ nixops ssh stk-d-1-IOHK1
```

We will be spending some of the genesis funds, so we need to find the hash of
the initial transaction:

```sh
▶ cardano-cli shelley genesis initial-txin \
    --testnet-magic 42 \
    --verification-key-file utxo-keys/utxo1.vkey > initial-tx.hash
```

The choice of the key is arbitrary. You can pick whatever key is available and
has funds, provided that you have access to the corresponding signing key.

We will need the address associated with the key we want to spend from, so we
need to get this:

```sh
▶ cardano-cli shelley genesis initial-addr \
                 --testnet-magic 42 \
                 --verification-key-file utxo-keys/utxo1.vkey > initial.addr
```

We can inspect the utxo to make sure that this address has funds to spend:

```sh
cardano-cli shelley query utxo --testnet-magic 42 --shelley-mode\
     --address $(cat initial.addr)
```

This should return an UTxO entry where the given address has some funds to
spend:

```sh
                           TxHash                                 TxIx        Lovelace
----------------------------------------------------------------------------------------
ae4c59546880d3cc1e18afa53bc970df8f62b27057bb75c52d61e96ba9e01d19     0 13333333333333334
```

Next we need to draft a transaction. For this we'll need to create a new
payment address.

```sh
cardano-cli shelley address key-gen \
    --verification-key-file payment.vkey \
    --signing-key-file payment.skey
```

Create a stake key pair:

```sh
cardano-cli shelley stake-address key-gen \
    --verification-key-file stake.vkey \
    --signing-key-file stake.skey
```

Use these keys to create a payment address:

```sh
cardano-cli shelley address build \
    --payment-verification-key-file payment.vkey \
    --stake-verification-key-file stake.vkey \
    --out-file payment.addr \
    --testnet-magic 42
```

Now, we're ready to draft our first transaction:

```sh
▶ cardano-cli shelley transaction build-raw \
    --tx-in $(cat initial-tx.hash) \
    --tx-out $(cat initial.addr)+0 \
    --tx-out $(cat payment.addr)+0 \
    --ttl 0 \
    --fee 0 \
    --out-file tx.draft
```

Check that the minfee for the transaction is 0, which amounts to checking that
the following command outputs `0 Lovelace`.

```sh
cardano-cli shelley transaction calculate-min-fee \
    --tx-body-file tx.draft \
    --tx-in-count 1 \
    --tx-out-count 2 \
    --witness-count 1 \
    --byron-witness-count 0 \
    --testnet-magic 42 \
    --protocol-params-file pparams.json
```

Calculate the change to send back to `payment.addr` (all amounts must be in
Lovelace):

```sh
▶ expr 13333333333333334 - 10000000000000000
3333333333333334
```

Determine the transaction's time-to-live:

```sh
▶ cardano-cli shelley query tip --testnet-magic 42
{
    "blockNo": 88,
    "headerHash": "00fa20ab9e609c4bdfcc0e8c0c39e2b16f0b1521a1d902b21d3a695721d8a6de",
    "slotNo": 5400
}
```

Build the transaction:

```sh
▶ cardano-cli shelley transaction build-raw \
    --tx-in $(cat initial-tx.hash) \
    --tx-out $(cat initial.addr)+3333333333333334 \
    --tx-out $(cat payment.addr)+10000000000000000 \
    --ttl 10400 \
    --fee 0 \
    --out-file tx.raw
```

Sign the transaction:

```sh
▶ cardano-cli shelley transaction sign \
    --tx-body-file tx.raw \
    --signing-key-file utxo-keys/utxo1.skey \
    --testnet-magic 42 \
    --out-file tx.signed
```

Submit it:

```sh
cardano-cli shelley transaction submit \
    --tx-file tx.signed \
    --testnet-magic 42 --shelley-mode
```

Check the balances:

```sh
▶ cardano-cli shelley query utxo --testnet-magic 42 --shelley-mode\
     --address $(cat initial.addr)
```

```sh
▶ cardano-cli shelley query utxo --testnet-magic 42 --shelley-mode\
     --address $(cat payment.addr)
```

### Registering the stake address on the blockchain

```sh
cardano-cli shelley stake-address registration-certificate \
    --stake-verification-key-file stake.vkey \
    --out-file stake.cert
```

Draft the transaction. We will use as input the transaction in which we
transferred Lovelace to `payment.vkey`. So let's query this transaction first:

```sh
cardano-cli shelley query utxo --testnet-magic 42 --shelley-mode\
     --address $(cat payment.addr) \
     --out-file tmp.json
grep -oP '"\K[^"]+' -m 1 tmp.json | head -1 | tr -d '\n' > payment-tx-in
```


```sh
cardano-cli shelley transaction build-raw \
    --tx-in $(cat payment-tx-in) \
    --tx-out $(cat payment.addr)+0 \
    --ttl 0 \
    --fee 0 \
    --out-file tx.raw \
    --certificate-file stake.cert
```

Calculate the fees:

```sh
cardano-cli shelley transaction calculate-min-fee \
    --tx-body-file tx.raw \
    --tx-in-count 1 \
    --tx-out-count 1 \
    --witness-count 1 \
    --byron-witness-count 0 \
    --testnet-magic 42 \
    --protocol-params-file pparams.json
```

This should be 0 Lovelace.

Also the value of `keyDeposit` in the protocol parameters should be `0`.

Create the transaction. Note that we do not pay fees nor deposit, so we have to
send to the output address the same amount as the input address has.

```sh
cardano-cli shelley transaction build-raw \
    --tx-in $(cat payment-tx-in) \
    --tx-out $(cat payment.addr)+10000000000000000 \
    --ttl 70000 \
    --fee 0 \
    --out-file tx.raw \
    --certificate-file stake.cert
```

Sign the transaction:

```sh
cardano-cli shelley transaction sign \
    --tx-body-file tx.raw \
    --signing-key-file payment.skey \
    --signing-key-file stake.skey \
    --testnet-magic 42 \
    --out-file tx.signed
```

And submit it:

```sh
cardano-cli shelley transaction submit \
    --tx-file tx.signed \
    --testnet-magic 42 \
    --shelley-mode
```

### Registering a stakepool

A stakepool node needs:

1. A cold key pair
2. A VRF key pair
3. A KES key pair
4. An operational certificate

### Finding the topology file

In the node run:

```sh
systemctl status cardano-node
```

This file is derived from the topology specified in the `nix` derivation. This
means that you can also use:

```sh
nix eval '(with import ./nix {}; with lib; (head (filter (n: n.name == "stk-d-1-IOHK1") globals.topology.coreNodes))).producers'
```

Where `"stk-d-1-IOHK1"` is the name of the node whose topology we wish to
query.

### Submitting an update proposal

genesis-verification-key-file you need to pass for all genesis vkeys. epoch and
out-file are required, and then any of the other options can be set or ignored.
For example, to update the d param to 0.52:

```sh
cardano-cli shelley governance create-update-proposal \
    --epoch 225 \
    --decentralization-parameter 0.52 \
    --out-file mainnet-225-d-0.52.proposal \
    $(for i in {1..3}; do echo "--genesis-verification-key-file genesis-keys/genesis$i.vkey "; done)
```

See the `create-stake-pool.sh` script for more details.

We need to build a transaction that contains this update proposal file:

```sh
cardano-cli shelley query utxo --testnet-magic 42 --shelley-mode\
            --address $(cat payment.addr) \
            --out-file /tmp/tx-info.json
TX_IN=`grep -oP '"\K[^"]+' -m 1 /tmp/tx-info.json | head -1 | tr -d '\n'`
```

```sh

cardano-cli shelley transaction sign \
            --tx-body-file tx.raw \
            --signing-key-file payment.skey \
            --signing-key-file stake.skey \
            --signing-key-file cold.skey \
            --testnet-magic 42 \
            --out-file tx.signed

cardano-cli shelley transaction submit \
            --tx-file tx.signed \
            --testnet-magic 42 \
            --shelley-mode
```
### How to know the key associated to a given node?

The nodeId attribute in nix topology is what determine the key used. See
[`core.nix`](https://github.com/input-output-hk/cardano-ops/blob/ee1e304a439e40397662c85972adbce1e4fb311a/roles/core.nix#L6-L11).

### Documentation about multisig

https://github.com/input-output-hk/cardano-node/blob/72987eb866346d141cfd76d73065c440307651aa/doc/reference/multisig.md#example-of-using-multi-signature-scripts
