## Common parameters:
##
##  $era:
##    "shelley"
##    "allegra"
##    "mary"
##    "alonzo"
##
##  $composition:
##    { n_bft_hosts:       INT
##    , n_singular_hosts:  INT
##    , n_dense_hosts:     INT
##    }
##
## This specification is interpreted by 'lib-params.sh' as follows:
##
##  1. The chosen node count determines the topology file.
##  2. The topology file determines the BFT/stake pool composition.
##  3. The era and composition determine base genesis/generator parameters.
##  4. The era determines sets of genesis/generator profiles,
##     a set product of which defines _benchmarking profiles_,
##     which are then each extended with era tolerances,
##     yielding _final benchmarking profiles_.
##

def genesis_defaults($era; $compo):
{ common:

  ## Trivia
  { protocol_magic:          42

  ## UTxO & delegation
  , total_balance:           900000000000000
  , pools_balance:           800000000000000
  , delegators:              $compo.n_dense_hosts
  , utxo:                    1000000

  ## Blockchain time & block density
  , active_slots_coeff:      0.05
  , epoch_length:            2200   # Ought to be at least (10 * k / f).
  , parameter_k:             10
  , slot_duration:           1
  , genesis_future_offset:   "3 minutes"

  ## Block size & contents
  , max_block_size:          64000
  , max_tx_size:             16384

  ## Cluster composition
  , dense_pool_density:      1

  ## Ahh, the sweet dear legacy..
  , byron:
    { parameter_k:             2160
    , n_poors:                 128
    , n_delegates:             $compo.n_total
    ## Note, that the delegate count doesnt have to match cluster size.
    , delegate_share:          0.9
    , avvm_entries:            128
    , avvm_entry_balance:      100000000000000
    , secret:                  2718281828
    , slot_duration:           20
    , max_block_size:          2000000
    }
  }

, shelley:
  { decentralisation_param:  0.5
  }

, allegra:
  { decentralisation_param:  0.5
  }

, mary:
  { decentralisation_param:  0
  }

, alonzo:
  { decentralisation_param:  0,
    "lovelacePerUTxOWord": 0,
    "executionPrices": {
      "prSteps":
      {
	  "numerator" :   721,
	  "denominator" : 10000000
	      },
      "prMem":
      {
	  "numerator" :   577,
	  "denominator" : 10000
      }
    },
    "maxTxExUnits": {
      "exUnitsMem":    1000000000,
      "exUnitsSteps": 10000000000
    },
    "maxBlockExUnits": {
      "exUnitsMem":    5000000000,
      "exUnitsSteps": 40000000000
    },
    "maxValueSize": 5000,
    "collateralPercentage": 150,
    "maxCollateralInputs": 3,
    "costModels": {
      "PlutusV1": {
	  "sha2_256-memory-arguments": 4,
	  "equalsString-cpu-arguments-constant": 1000,
	  "cekDelayCost-exBudgetMemory": 100,
	  "lessThanEqualsByteString-cpu-arguments-intercept": 103599,
	  "divideInteger-memory-arguments-minimum": 1,
	  "appendByteString-cpu-arguments-slope": 621,
	  "blake2b-cpu-arguments-slope": 29175,
	  "iData-cpu-arguments": 150000,
	  "encodeUtf8-cpu-arguments-slope": 1000,
	  "unBData-cpu-arguments": 150000,
	  "multiplyInteger-cpu-arguments-intercept": 61516,
	  "cekConstCost-exBudgetMemory": 100,
	  "nullList-cpu-arguments": 150000,
	  "equalsString-cpu-arguments-intercept": 150000,
	  "trace-cpu-arguments": 150000,
	  "mkNilData-memory-arguments": 32,
	  "lengthOfByteString-cpu-arguments": 150000,
	  "cekBuiltinCost-exBudgetCPU": 29773,
	  "bData-cpu-arguments": 150000,
	  "subtractInteger-cpu-arguments-slope": 0,
	  "unIData-cpu-arguments": 150000,
	  "consByteString-memory-arguments-intercept": 0,
	  "divideInteger-memory-arguments-slope": 1,
	  "divideInteger-cpu-arguments-model-arguments-slope": 118,
	  "listData-cpu-arguments": 150000,
	  "headList-cpu-arguments": 150000,
	  "chooseData-memory-arguments": 32,
	  "equalsInteger-cpu-arguments-intercept": 136542,
	  "sha3_256-cpu-arguments-slope": 82363,
	  "sliceByteString-cpu-arguments-slope": 5000,
	  "unMapData-cpu-arguments": 150000,
	  "lessThanInteger-cpu-arguments-intercept": 179690,
	  "mkCons-cpu-arguments": 150000,
	  "appendString-memory-arguments-intercept": 0,
	  "modInteger-cpu-arguments-model-arguments-slope": 118,
	  "ifThenElse-cpu-arguments": 1,
	  "mkNilPairData-cpu-arguments": 150000,
	  "lessThanEqualsInteger-cpu-arguments-intercept": 145276,
	  "addInteger-memory-arguments-slope": 1,
	  "chooseList-memory-arguments": 32,
	  "constrData-memory-arguments": 32,
	  "decodeUtf8-cpu-arguments-intercept": 150000,
	  "equalsData-memory-arguments": 1,
	  "subtractInteger-memory-arguments-slope": 1,
	  "appendByteString-memory-arguments-intercept": 0,
	  "lengthOfByteString-memory-arguments": 4,
	  "headList-memory-arguments": 32,
	  "listData-memory-arguments": 32,
	  "consByteString-cpu-arguments-intercept": 150000,
	  "unIData-memory-arguments": 32,
	  "remainderInteger-memory-arguments-minimum": 1,
	  "bData-memory-arguments": 32,
	  "lessThanByteString-cpu-arguments-slope": 248,
	  "encodeUtf8-memory-arguments-intercept": 0,
	  "cekStartupCost-exBudgetCPU": 100,
	  "multiplyInteger-memory-arguments-intercept": 0,
	  "unListData-memory-arguments": 32,
	  "remainderInteger-cpu-arguments-model-arguments-slope": 118,
	  "cekVarCost-exBudgetCPU": 29773,
	  "remainderInteger-memory-arguments-slope": 1,
	  "cekForceCost-exBudgetCPU": 29773,
	  "sha2_256-cpu-arguments-slope": 29175,
	  "equalsInteger-memory-arguments": 1,
	  "indexByteString-memory-arguments": 1,
	  "addInteger-memory-arguments-intercept": 1,
	  "chooseUnit-cpu-arguments": 150000,
	  "sndPair-cpu-arguments": 150000,
	  "cekLamCost-exBudgetCPU": 29773,
	  "fstPair-cpu-arguments": 150000,
	  "quotientInteger-memory-arguments-minimum": 1,
	  "decodeUtf8-cpu-arguments-slope": 1000,
	  "lessThanInteger-memory-arguments": 1,
	  "lessThanEqualsInteger-cpu-arguments-slope": 1366,
	  "fstPair-memory-arguments": 32,
	  "modInteger-memory-arguments-intercept": 0,
	  "unConstrData-cpu-arguments": 150000,
	  "lessThanEqualsInteger-memory-arguments": 1,
	  "chooseUnit-memory-arguments": 32,
	  "sndPair-memory-arguments": 32,
	  "addInteger-cpu-arguments-intercept": 197209,
	  "decodeUtf8-memory-arguments-slope": 8,
	  "equalsData-cpu-arguments-intercept": 150000,
	  "mapData-cpu-arguments": 150000,
	  "mkPairData-cpu-arguments": 150000,
	  "quotientInteger-cpu-arguments-constant": 148000,
	  "consByteString-memory-arguments-slope": 1,
	  "cekVarCost-exBudgetMemory": 100,
	  "indexByteString-cpu-arguments": 150000,
	  "unListData-cpu-arguments": 150000,
	  "equalsInteger-cpu-arguments-slope": 1326,
	  "cekStartupCost-exBudgetMemory": 100,
	  "subtractInteger-cpu-arguments-intercept": 197209,
	  "divideInteger-cpu-arguments-model-arguments-intercept": 425507,
	  "divideInteger-memory-arguments-intercept": 0,
	  "cekForceCost-exBudgetMemory": 100,
	  "blake2b-cpu-arguments-intercept": 2477736,
	  "remainderInteger-cpu-arguments-constant": 148000,
	  "tailList-cpu-arguments": 150000,
	  "encodeUtf8-cpu-arguments-intercept": 150000,
	  "equalsString-cpu-arguments-slope": 1000,
	  "lessThanByteString-memory-arguments": 1,
	  "multiplyInteger-cpu-arguments-slope": 11218,
	  "appendByteString-cpu-arguments-intercept": 396231,
	  "lessThanEqualsByteString-cpu-arguments-slope": 248,
	  "modInteger-memory-arguments-slope": 1,
	  "addInteger-cpu-arguments-slope": 0,
	  "equalsData-cpu-arguments-slope": 10000,
	  "decodeUtf8-memory-arguments-intercept": 0,
	  "chooseList-cpu-arguments": 150000,
	  "constrData-cpu-arguments": 150000,
	  "equalsByteString-memory-arguments": 1,
	  "cekApplyCost-exBudgetCPU": 29773,
	  "quotientInteger-memory-arguments-slope": 1,
	  "verifySignature-cpu-arguments-intercept": 3345831,
	  "unMapData-memory-arguments": 32,
	  "mkCons-memory-arguments": 32,
	  "sliceByteString-memory-arguments-slope": 1,
	  "sha3_256-memory-arguments": 4,
	  "ifThenElse-memory-arguments": 1,
	  "mkNilPairData-memory-arguments": 32,
	  "equalsByteString-cpu-arguments-slope": 247,
	  "appendString-cpu-arguments-intercept": 150000,
	  "quotientInteger-cpu-arguments-model-arguments-slope": 118,
	  "cekApplyCost-exBudgetMemory": 100,
	  "equalsString-memory-arguments": 1,
	  "multiplyInteger-memory-arguments-slope": 1,
	  "cekBuiltinCost-exBudgetMemory": 100,
	  "remainderInteger-memory-arguments-intercept": 0,
	  "sha2_256-cpu-arguments-intercept": 2477736,
	  "remainderInteger-cpu-arguments-model-arguments-intercept": 425507,
	  "lessThanEqualsByteString-memory-arguments": 1,
	  "tailList-memory-arguments": 32,
	  "mkNilData-cpu-arguments": 150000,
	  "chooseData-cpu-arguments": 150000,
	  "unBData-memory-arguments": 32,
	  "blake2b-memory-arguments": 4,
	  "iData-memory-arguments": 32,
	  "nullList-memory-arguments": 32,
	  "cekDelayCost-exBudgetCPU": 29773,
	  "subtractInteger-memory-arguments-intercept": 1,
	  "lessThanByteString-cpu-arguments-intercept": 103599,
	  "consByteString-cpu-arguments-slope": 1000,
	  "appendByteString-memory-arguments-slope": 1,
	  "trace-memory-arguments": 32,
	  "divideInteger-cpu-arguments-constant": 148000,
	  "cekConstCost-exBudgetCPU": 29773,
	  "encodeUtf8-memory-arguments-slope": 8,
	  "quotientInteger-cpu-arguments-model-arguments-intercept": 425507,
	  "mapData-memory-arguments": 32,
	  "appendString-cpu-arguments-slope": 1000,
	  "modInteger-cpu-arguments-constant": 148000,
	  "verifySignature-cpu-arguments-slope": 1,
	  "unConstrData-memory-arguments": 32,
	  "quotientInteger-memory-arguments-intercept": 0,
	  "equalsByteString-cpu-arguments-constant": 150000,
	  "sliceByteString-memory-arguments-intercept": 0,
	  "mkPairData-memory-arguments": 32,
	  "equalsByteString-cpu-arguments-intercept": 112536,
	  "appendString-memory-arguments-slope": 1,
	  "lessThanInteger-cpu-arguments-slope": 497,
	  "modInteger-cpu-arguments-model-arguments-intercept": 425507,
	  "modInteger-memory-arguments-minimum": 1,
	  "sha3_256-cpu-arguments-intercept": 0,
	  "verifySignature-memory-arguments": 1,
	  "cekLamCost-exBudgetMemory": 100,
	  "sliceByteString-cpu-arguments-intercept": 150000
      }
    }
  }
} | (.common + .[$era]);

def generator_defaults($era):
{ common:
  { add_tx_size:             100
  , init_cooldown:           45
  , inputs_per_tx:           2
  , outputs_per_tx:          2
  , tx_fee:                  1000000
  , epochs:                  10
  , tps:                     10
  }
} | (.common + (.[$era] // {}));

def node_defaults($era):
{ common:
  { expected_activation_time:      30
  }
} | (.common + (.[$era] // {}));

def derived_genesis_params($era; $compo; $gtor; $gsis; $node):
  (if      $compo.n_hosts > 50 then 20
  else if $compo.n_hosts == 3 then 3
  else 10 end end)                      as $future_offset
|
{ common:
  ({ n_pools: ($compo.n_singular_hosts
             + $compo.n_dense_hosts * $gsis.dense_pool_density)
   , genesis_future_offset: "\($future_offset) minutes"
   } +
   if $gsis.dense_pool_density > 1
   then
   { n_singular_pools:  $compo.n_singular_hosts
   , n_dense_pools:    ($compo.n_dense_hosts
                       * $gsis.dense_pool_density) }
   else
   { n_singular_pools: ($compo.n_singular_hosts
                        + $compo.n_dense_hosts)
   , n_dense_pools:     0 }
   end)
} | (.common + (.[$era] // {}));

def derived_generator_params($era; $compo; $gtor; $gsis; $node):
  ($gsis.epoch_length * $gsis.slot_duration) as $epoch_duration
| ($epoch_duration * $gtor.epochs)           as $duration
|
{ common:
  { era:                     $era
  , tx_count:                ($gtor.tx_count
                              // ($duration * $gtor.tps))
  }
} | (.common + (.[$era] // {}));

def derived_node_params($era; $compo; $gtor; $gsis; $node):
{ common: {}
} | (.common + (.[$era] // {}));

def derived_tolerances($era; $compo; $gtor; $gsis; $node; $tolers):
{ common:
  { finish_patience:
    ## TODO:  fix ugly
    ($gtor.finish_patience // $tolers.finish_patience)
  }
} | (.common + (.[$era] // {}));

def may_attr($attr; $dict; $defdict; $scale; $suf):
  if ($dict[$attr] //
      error("undefined attr: \($attr)"))
     != $defdict[$attr]
  then [($dict[$attr] | . / $scale | tostring) + $suf] else [] end;

def profile_name($compo; $gsis; $gtor; $node):
  $node.extra_config.TestAlonzoHardForkAtEpoch as $alzoHFAt
  ## Genesis
  | [ "k\($gsis.n_pools)" ]
  + may_attr("dense_pool_density";
             $gsis; genesis_defaults($era; $compo); 1; "ppn")
  + [ ($gtor.epochs                    | tostring) + "ep"
    , ($gtor.tx_count       | . / 1000 | tostring) + "kTx"
    , ($gsis.utxo           | . / 1000 | tostring) + "kU"
    , ($gsis.delegators     | . / 1000 | tostring) + "kD"
    , ($gsis.max_block_size | . / 1000 | tostring) + "kbs"
    ]
  + may_attr("tps";
             $gtor; generator_defaults($era); 1; "tps")
  + may_attr("epoch_length";
             $gsis; genesis_defaults($era; $compo); 1; "eplen")
  + may_attr("add_tx_size";
             $gtor; generator_defaults($era); 1; "b")
  + may_attr("inputs_per_tx";
             $gtor; generator_defaults($era); 1; "i")
  + may_attr("outputs_per_tx";
             $gtor; generator_defaults($era); 1; "o")
  + if $alzoHFAt != null and $alzoHFAt != 0
    then [ "alzo@\($alzoHFAt)" ]
    else [] end
  + if $gtor.scriptMode
    then if $gtor.plutusMode
        then [ ($gtor.plutusScript | rtrimstr(".plutus"))
             , ($gtor.plutusData | tostring)
             ]
        else ["scr"] end
    else ["cli"] end
  | join("-");

def legacy_profiles:
  [ { desc: "calibration, with ~30 tx/64k-block; NOTE: needs special node & ops"
    , genesis: { utxo: 2000000, delegators:  500000 }
    , generator: { add_tx_size: 2000, scriptMode: false } }

  , { desc: "regression, February 2021 data set sizes, unsaturated"
    , genesis: { utxo: 2000000, delegators:  500000 }
    , generator: { tps: 2, scriptMode: false } }
  ];

def utxo_delegators_density_profiles:
  [ { desc: "regression, August 2021 data set sizes"
    , genesis: { utxo: 3000000, delegators:  750000 }
    , generator: { scriptMode: false } }

  , { desc: "regression, August 2021 data set sizes, script mode"
    , genesis: { utxo: 3000000, delegators:  750000 }
    , generator: { scriptMode: true } }

  , { desc: "regression, 2022 projected data set sizes"
    , genesis: { utxo: 4000000, delegators: 1000000 }
    , generator: { scriptMode: false } }

  , { desc: "regression, 2022 projected data set sizes"
    , genesis: { utxo: 4000000, delegators: 1000000 }
    , generator: { scriptMode: true } }

  , { desc: "Plutus return-success"
    , genesis: { utxo: 3000000, delegators:  750000 }
    , generator: { scriptMode: true
                 , plutusMode: true
                 , plutusScript: "always-succeeds-spending.plutus"
		 , plutusData: 0
		 , plutusRedeemer: 0
                 , executionMemory: 125000
		 , executionSteps: 100000000
                 } }
  , { desc: "Plutus max-cpu-units"
    , genesis: { utxo: 3000000, delegators:  750000 }
    , generator: {
                   inputs_per_tx:           1
                 , outputs_per_tx:          1
                 , tx_count:             80
                 , tps: 9
                 , scriptMode: true
                 , plutusMode: true
                 , plutusScript: "sum.plutus"
                 , plutusData: 3304
                 , plutusRedeemer: 5459860
                 , executionMemory:  100000000
                 , executionSteps:  9999406981
                 , debugMode: true
                 } }
  , { desc: "Plutus max-cpu-units, large"
    , genesis: { utxo: 3000000, delegators:  750000 }
    , generator: {
                   inputs_per_tx:           1
                 , outputs_per_tx:          1
		 , tx_count:             5000
                 , tps: 9
                 , scriptMode: true
                 , plutusMode: true
                 , plutusScript: "sum.plutus"
                 , plutusData: 3304
                 , plutusRedeemer: 5459860
                 , executionMemory:  100000000
                 , executionSteps:  9999406981
                 , debugMode: false
                 } }

    , generator: { tps: 10, scriptMode: true } }

  , { desc: "always-succeeds-script"
    , genesis: { utxo: 3000000, delegators:  750000 }
    , generator: { tps: 11, scriptMode: true
                 , plutusMode: true
                 , plutusScript: "always-succeeds-spending.plutus"
		 , plutusData: 0
		 , plutusRedeemer: 0
                 , executionMemory: 125000
		 , executionSteps: 100000000
                 } }
  , { desc: "max-cpu-units-smoke"
    , genesis: { utxo: 3000000, delegators:  750000 }
    , generator: {
                   inputs_per_tx:           1
                 , outputs_per_tx:          1
		 , tx_count:             1000
                 , tps: 9, scriptMode: true
                 , plutusMode: true
                 , plutusScript: "sum.plutus"
		 , plutusData: 3304
		 , plutusRedeemer: 5459860
                 , executionMemory:  100000000
		 , executionSteps:  9999406981
                 } }

];

def generator_profiles:
  [ { generator: {} }
  ];

def node_profiles:
  [ { node: {} }
  ];

def profiles:
  [ utxo_delegators_density_profiles
  , generator_profiles
  , node_profiles
  ]
  | [combinations]
  | map (reduce .[] as $item ({}; . * $item))
  | map (. *
        { node:
          { expected_activation_time:
            (60 * ((.genesis.delegators / 500000)
                   +
                   (.genesis.utxo       / 2000000))
                / 2)
          }
        });

def era_tolerances($era; $genesis):
{ common:
  { cluster_startup_overhead_s:     60
  , start_log_spread_s:             300
  , last_log_spread_s:              120
  , silence_since_last_block_s:     120
  , tx_loss_ratio:                  0.02
  , finish_patience:                42
  , minimum_chain_density:          ($genesis.active_slots_coeff * 0.5)
  }
, shelley:
  { maximum_missed_slots:           0
  }
} | (.common + .[$era]);

def aux_profiles:
[ { name: "smoke-100"
  , generator: { tx_count: 100,   inputs_per_tx: 1, outputs_per_tx: 1
               , init_cooldown: 25, finish_patience: 4 }
  , genesis:
    { genesis_future_offset: "3 minutes"
    , utxo:                  1000
    , dense_pool_density:    10
    }
  }
, { name: "smoke-k50"
  , generator: { tx_count: 100,   inputs_per_tx: 1, outputs_per_tx: 1
               , init_cooldown: 90, finish_patience: 4 }
  , genesis:
    { genesis_future_offset: "20 minutes" }
  }
];