# example usage: nix-build generate-incentivized.nix -A tester
let
  ada = n: n * 1000000; # lovelace
  mada = n: n * 1000000 * 1000000; # million ada in lovelace
  stakePoolCount = 0;
  stakePoolBalances = [];
  readFile = file: (__replaceStrings ["\n"] [""] (__readFile file));
  extraBlockchainConfig = {
    slots_per_epoch = 43200;
  };

  inputParams =
    let
      genesisOverrides = {
        protocolParamaters = {
          decentralisationParameter = 1;
          poolDeposit = 1000000000000000;
          nOpt = 1;
          rho = 0;
          tau = 0;
          a0 = 0;
        };
        maxLovelaceSupply = 45000000000000000;
        protocolMagicId = 764824073;
      };
      initialUtxoSnapshot = (__fromJSON (__readFile ./sample-utxo.json)).fund;
      utxoSnapshot = {
        fund = initialUtxoSnapshot ++ [
          # additional addresses go here
          #{ address = ""; value = mada 1; }
        ];
      };
    in {
      inherit utxoSnapshot genesisOverrides;
    };
  in import ./. { inherit inputParams; }
