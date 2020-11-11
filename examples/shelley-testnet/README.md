In this document we describe how to deploy a Shelley testnet and perform some
operations on it.

The definition of the testnet (nodes, topology, etc) is done using [`nix`].

Deployment of the testnet is done using [`nixops`] (which you do not need to
install it, since it will be done by `nix` when entering a `nix-shell`). Using
`nixops` means that creating, starting, stopping, and destroying the testnet,
as well as performing operations on the nodes (like logging in to the via ssh)
should be done via the `nixops` command. We'll see examples of such commands
later on.

The instructions described here will allow you to deploy a testnet locally or
on [AWS-EC2] machines.

## Prerequisites

The following instructions assume you have a Unix system, and [`nix`]
installed. Depending on where you want to deploy the tesnet, i.e. locally or on
AWS, you need to perform different preparatory steps.

### Local deployment

The local deployment uses [libvirt]. Make sure that you have it installed and
properly configured.

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

On Ubuntu see [these
instructions](https://ubuntu.com/server/docs/virtualization-libvirt
"Instructions on how to install libvirt").

For other Linux distros refer to their documentation on how to install
`libvirt`.

After `libvirt` is installed and configured, check whether the default pool is
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

In addition, `nix` uses large amounts of temporary storage, so you might want
to make sure your runtime directory is large enough. Depending on your Linux
distro, the way to achieve this might be modifying the value of
`RuntimeDirectorySize` in `/etc/systemd/logind.conf` so that the runtime
directory has a least 4G of space, but use 8 or 16 if possible to be on the
safe side. After modifying that file you should log out and in again.

Finally, if you find out you did not allocated enough space for the temporary
directory, you can either set the value of `RuntimeDirectorySize` to a larger
value, or set the `TMPDIR` variable to point to a location with sufficient
space.

### AWS deployment

To deploy on AWS you need to add your ssh key to the `cls-developers` attribute
in `overlays/ssh-keys.nix`. This file can be found in the
[`ops-lib`](https://github.com/input-output-hk/ops-lib/ "ops-lib repository")
repository.

## Configuring the deployment

To spin up a custom cluster first use the shelley pools example template. This
features a setup with 1 OBFT node and 3 stakepools. The OBFT node is needed to
bootstrap the network, and produce blocks. The 3 stakepools need to be
registered and the decentralization parameter needs to be changed from 1 so
that the pools can start producing blocks. We provide a
[setup-stakepools-block-production.sh](examples/shelley-testnet/scripts/setup-stakepools-block-production.sh)
script which performs these tasks and illustrates how they can be done.

Use this template to create the global topology files:

```sh
export MYENV=my-env # Choose the name of your environment.
cp examples/shelley-testnet/globals.nix globals-$MYENV.nix
ln -s globals-$MYENV.nix globals.nix
cp examples/shelley-testnet/topology.nix topologies/$MYENV.nix
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

Once the topology files are created and configured, you can enter the nix
shell, which provides the environment for deployment, as well as bash
completion for `cardano-cli`.

```sh
nix-shell
```

Alternatively, you can install `lorri` which provides a [superior
alternative](https://youtu.be/WtbW0N8Cww4 "YouTube video explaining lorri") to
`nix-shell`. Installing and configuring `lorri` is outside of the scope of this
tutorial.

Prior to running the testnet the genesis file and several keys for the nodes
need to be created. This is done by running from a nix shell:

```sh
create-shelley-genesis-and-keys
```

This script uses `cardano-cli` to generate a genesis file and the different
types of keys the node needs. The generated keys will be placed in `keys` and
the generated genesis file can be found at `keys/genesis.json`.

The genesis file generated by this script will specify the starting time of the
network 10 minutes into the future. We do this to avoid missing blocks while we
wait for the network to be deployed. The genesis files also specifies parameter
values to change epochs every 3 minutes (see `K`, `F`, and `SLOT_LENGTH` in
`shell.nix`). Feel free to tweak these numbers by modifying the
`create-shelley-genesis-and-keys` script in the aforementioned file.

After all the files are in place (globals, topology, genesis, and keys), you're
ready to create the deployment :shipit:

### Creating a local deployment

The local deployment can be started using the following script on a nix-shell:

```sh
./scripts/create-libvirtd.sh
```

### Creating a deployment on AWS

You can create an AWS deployment using the following script on a nix-shell:

```sh
./scripts/create-aws.sh
```

## Manipulating the testnet machines

The machines of the network can be created, accessed, and destroyed using
`nixops`. When creating the deployment using any of the `create-aws.sh` or
`create-libvirtd.sh` scripts, the machines will be created and started for you.

Nixops provides several commands for manipulating the machines:

```sh
nixops stop
nixops start
nixops destroy
nixops deploy -k
```

In the `deploy` command above we use the `-k` flag to tell nixops to remove
obsolete resources. You can omit this to keep them.

Bear in mind that stopping and starting the machines can cause the block
production to halt, since there is a limit in the amount of blocks the network
can miss.

To list the machines created by a nix deployment, run:

```sh
nixops info
```

The name of the machines returned by the command above can be used to ssh to any
of the machines.

```sh
nixops ssh $NODE_NAME
```

To copy files to the machines one can use the `nixops scp` command:

```sh
nixops scp $NODE_NAME $PATH_IN_HOST $PATH_IN_NODE --to
```


## Manipulating the node

In this section we describe operations on the nodes that are commonly used
during tests (manual or automatic).

### Updating cardano node

The `cardano-ops` repository uses [`niv`](https://github.com/nmattia/niv "niv
project page") to manage dependencies. To update `cardano-node` to use a
specific branch run nix-shell:

```sh
niv update cardano-node -b <branch>
```

To list all the components managed by `niv` run:

```
niv show
```

### Locating keys in the node

In the nodes they are stored in `/var/lib/keys`:

```text
▶ ls /var/lib/keys
cardano-node-kes-signing  cardano-node-operational-cert  cardano-node-vrf-signing
```


### Getting the node logs

The Cardano node is started as a service in every machine in the network. To
query its status, once logged into a machine of the network, run:

```sh
systemctl status cardano-node
```

To show the logs of the last boot use:

```sh
journalctl -u cardano-node -b
```

To follow the logs use:

```sh
journalctl -u cardano-node -f -n40
```

### Customizing logging levels

The logging configuration of a node is explained in the [Cardano
documentation][cardano-docs]. In this section we show how logging can be
configured in the nix deployment.

To change the logging level of all the nodes you have to modify the
`globals-$MYENV.nix` file. For example, to change the logging level of
`TraceBlockFetchProtocol` in all nodes we can edit this file as follows:

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

### Querying the UTxO

To obtain the entire UTxO set, run:

```sh
cardano-cli shelley query utxo --testnet-magic 42 --shelley-mode
```

Querying the UTxO for a specific address. First you need the verification key
to obtain the address. For a verification key corresponding to an initial
address you can obtain its associated address as follows:

```sh
cardano-cli shelley genesis initial-addr \
                --testnet-magic 42 \
                --verification-key-file utxo.vkey
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

### Querying protocol parameters

```
cardano-cli shelley query protocol-parameters --testnet-magic 42 --shelley-mode
```

You can use the `--out-file` flag to output the result to a file.

### Dumping the ledger state


```sh
cardano-cli shelley query ledger-state --testnet-magic 42 --shelley-mode
```

### Querying the stake distribution

Once stakepools are registered, you can check the portion of the stake they own
by running:

```sh
cardano-cli shelley query stake-distribution  --testnet-magic 42 --shelley-mode
```
### Querying the blocks produced per-stakepool

You can dump the ledger state and look into the value to the `nesBprev` field
or the `nesBCur` field to get the number of blocks produced per-stakepool in
the previous and current epochs, respectively. For instance:

```sh
cardano-cli shelley query ledger-state --testnet-magic 42 --shelley-mode | jq '.nesBcur'
```

### Key hashing

The genesis file and `cardano-cli`'s output use the hashes of the verification
keys instead of the verification key itself. For this reason it might be useful
to use the commands that `cardano-cli` provides for hashing keys. We show some
examples below:

```sh
▶ cardano-cli shelley genesis key-hash \
              --verification-key-file example/genesis-keys/genesis1.vkey
              f42b0eb14056134323d9756fa693dba5e421acaaf84fdaff922a4c0f

▶ cardano-cli shelley genesis key-hash \
              --verification-key-file example/delegate-keys/delegate1.vkey
              e446c231ace1f29eb83827f29cb4a19e4c324229d59472c8d2dbb958

▶ cardano-cli shelley node key-hash-VRF \
              --verification-key-file example/delegate-keys/delegate1.vrf.vkey
              e5b6b13eacc21968953ecb78eb900c1eaa2b4744ffead8719f9064f4863e1813
```


## References

- [nix.dev](https://nix.dev/)
- [Making a Shelley blockchain from scratch](https://github.com/input-output-hk/cardano-node/blob/62485960494d914f8efd06ed0d8357d41a8f9d26/doc/reference/shelley-genesis.md)
- [Cardano node documentation](https://docs.cardano.org/projects/cardano-node/en/latest/)
- [Documentation about multisig](https://github.com/input-output-hk/cardano-node/blob/72987eb866346d141cfd76d73065c440307651aa/doc/reference/multisig.md#example-of-using-multi-signature-scripts)

[`nix`]: https://nixos.org/download.html "nix installation instructions"
[`nixops`]: https://github.com/NixOS/nixops
[AWS-EC2]: https://aws.amazon.com/ec2/
[libvirt]: https://libvirt.org/manpages/libvirtd.html "libvirt site"
[cardano-docs]: https://docs.cardano.org/projects/cardano-node/en/latest/getting-started/understanding-config-files.html#tracing
