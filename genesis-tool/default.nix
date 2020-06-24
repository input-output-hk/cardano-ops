let
  genesisSpecDefault = {
    activeSlotsCoeff = .05;
    protocolParams = {
      poolDeposit = 500000000;
      protocolVersion = {
        minor = 0;
        major = 0;
      };
      minUTxOValue = 0;
      decentralisationParam = 1;
      maxTxSize = 16384;
      minPoolCost = 0;
      minFeeA = 44;
      maxBlockBodySize = 65536;
      minFeeB = 155381;
      eMax = 18;
      extraEntropy = {
        tag = "NeutralNonce";
      };
      maxBlockHeaderSize = 1100;
      keyDeposit = 400000;
      nOpt = 50;
      rho = 1.78650067e-3;
      tau = 0.1;
      a0 = 0.1;
    };
    protocolMagicId = 42;
    genDelegs = {};
    updateQuorum = 3;
    networkId = "Testnet";
    initialFunds = {};
    maxLovelaceSupply = 45000000000000000;
    networkMagic = 42;
    epochLength = 21600;
    staking = {
      pools = {};
      stake = {};
    };
    systemStart = "1970-01-01T00 =00 =00Z";
    slotsPerKESPeriod = 3600;
    slotLength = 1;
    maxKESEvolutions = 120;
    securityParam = 108;
  };
in { inputParams ? {} }:

let
  pkgs = import ../nix { };
  inherit (pkgs) lib;

  inputConfig = __toFile "input.json" (__toJSON (inputParams.utxoSnapshot));
  genesisSpec = __toFile "genesis-spec.json" (__toJSON (genesisSpecDefault // inputParams.genesisOverrides));
in lib.fix (self: {
  inherit inputParams inputConfig genesisSpec;
  ghc = pkgs.haskellPackages.ghcWithPackages (ps: [ ps.aeson ps.base58-bytestring ps.base16-bytestring ]);
  utxo-converter = pkgs.runCommand "utxo-converter" {
    buildInputs = [ self.ghc pkgs.haskellPackages.ghcid ];
    preferLocalBuild = true;
  } ''
    cp ${./main.hs} main.hs
    mkdir -pv $out/bin/
    ghc ./main.hs -o $out/bin/utxo-converter
  '';

  genesisInitialFunds = let
    buildInputs = [ self.utxo-converter pkgs.cardano-cli pkgs.cardano-node ];
  in pkgs.runCommand "genesis-initial-funds" { inherit buildInputs; } ''
    utxo-converter ${inputConfig}
    mkdir -p $out
    cp output.json $out/utxo.json
  '';
  genesisCreator = let
    buildInputs = with pkgs; [ jq cardano-cli ];
  in pkgs.runCommand "genesis-initial-funds" { inherit buildInputs; } ''
    mkdir -p $out
    cp ${self.genesisInitialFunds}/utxo.json .
    cp ${self.genesisSpec} genesis-spec.json
    cardano-cli shelley genesis create --genesis-dir . --gen-genesis-keys 1 --mainnet
    jq --argjson initialFunds "$(<utxo.json)" '.initialFunds = $initialFunds' genesis.json > $out/genesis.json

  '';

  tester = pkgs.writeShellScript "tester" ''
    set -e
    export PATH=${lib.makeBinPath (with pkgs; [ jq cardano-cli cardano-node ])}:$PATH
    rm -f /tmp/testrun/*
    mkdir -p /tmp/testrun
    cd /tmp/testrun
    cp ${self.genesisInitialFunds}/utxo.json ./
    # TODO: launch node with genesis
    cp ${self.genesisSpec} genesis-spec.json
    cardano-cli shelley genesis --genesis-dir . create --genesis-keys 1
  '';
})
