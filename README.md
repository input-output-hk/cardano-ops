# cardano-ops
NixOps deployment configuration for IOHK/Cardano devops

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
nixops deploy
```

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

TODO: find where to get the payment address?

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

In the nodes they are stored in

```text
/var/lib/keys
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
cardano-cli shelley query protocol-parameters --testnet-magic 42 --shelley-mode
```
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
