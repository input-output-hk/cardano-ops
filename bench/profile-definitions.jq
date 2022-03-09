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

def genesis_defaults($era; $compo; $defaults_external):
{ common:

  ## Trivia
  { protocol_magic:          42

  ## UTxO & delegation
  , total_balance:           900000000000000
  , pools_balance:           800000000000000
  , delegators:              1000000
  , utxo:                    4000000

  ## Blockchain time & block density
  , active_slots_coeff:      0.05
  , epoch_length:            8000   # Ought to be at least (10 * k / f).
  , parameter_k:             40
  , slot_duration:           1

  ## Block size & contents
  , max_block_size:          64000
  , max_tx_size:             16384

  ## Cluster composition
  , dense_pool_density:      1

  ## BFT overlay
  , decentralisation_param:  0

  , alonzo:  $defaults_external.alonzo
  , shelley: $defaults_external.shelley
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
} | (.common + (.[$era] // {}));

def generator_defaults($era):
{ common:
  { add_tx_size:             100
  , init_cooldown:           45
  , inputs_per_tx:           2
  , outputs_per_tx:          2
  , tx_fee:                  1000000
  , epochs:                  5
  , tps:                     9
  , highLevelConfig:         true
  }
} | (.common + (.[$era] // {}));

def node_defaults($era):
{ common:
  { rts_flags_override:            []
  }
} | (.common + (.[$era] // {}));

def derived_genesis_params($era; $compo; $gtor; $gsis; $node):
  (if      $compo.n_hosts > 50 then 20
  else if $compo.n_hosts == 3 then 2
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
{ common:
  {
  }
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

def profile_name($compo; $gsis; $gtor; $node; $gsis_defs):
    $node.extra_config.TestAlonzoHardForkAtEpoch as $alzoHFAt
  | [ "k\($gsis.n_pools)" ]
  + may_attr("dense_pool_density"; $gsis; $gsis_defs; 1; "ppn")
  + [ ($gtor.epochs                    | tostring) + "ep"
    , ($gtor.tx_count       | . / 1000 | tostring) + "kTx"
    , ($gsis.utxo           | . / 1000 | tostring) + "kU"
    , ($gsis.delegators     | . / 1000 | tostring) + "kD"
    , ($gsis.max_block_size | . / 1000 | floor | tostring) + "kbs"
    ]
  + if $gtor.plutusMode | not
    then []
    else
        $gsis.alonzo.maxTxExUnits    as $exLimTx
      | $gsis.alonzo.maxBlockExUnits as $exLimBlk
      | [ ($exLimTx.exUnitsMem    | . /1000/1000      | floor | tostring) + "MUTx"
        , ($exLimTx.exUnitsSteps  | . /1000/1000/1000 | floor | tostring) + "BStTx"
        , ($exLimBlk.exUnitsMem   | . /1000/1000      | floor | tostring) + "MUBk"
        , ($exLimBlk.exUnitsSteps | . /1000/1000/1000 | floor | tostring) + "BStBk"
        ]
    end
  + may_attr("tps";
             $gtor; generator_defaults($era); 1; "tps")
  + may_attr("epoch_length";
             $gsis; $gsis_defs; 1; "eplen")
  + may_attr("add_tx_size";
             $gtor; generator_defaults($era); 1; "b")
  + may_attr("inputs_per_tx";
             $gtor; generator_defaults($era); 1; "i")
  + may_attr("outputs_per_tx";
             $gtor; generator_defaults($era); 1; "o")
  + if $alzoHFAt != null and $alzoHFAt != 0
    then [ "alzo@\($alzoHFAt)" ]
    else [] end
  + if $gtor.plutusMode
    then [ ($gtor.plutusScript | rtrimstr(".plutus"))
         , ($gtor.plutusData | tostring)
         ]
    else [] end
  + if $node.rts_flags_override == [] then []
    else ["RTS", ($node.rts_flags_override | join(""))] end
  | join("-");

def utxo_delegators_density_profiles:
  [ { desc: "regression, October 2021 data set sizes" }

    , { desc: "rtsflags: batch1, best CPU/mem"
    , node: { rts_flags_override: ["-H4G", "-M6553M", "-c70"] } }

  , { desc: "rtsflags: batch1, better mem, costlier CPU"
    , node: { rts_flags_override: ["-H4G", "-M6553M"] } }

  , { desc: "rtsflags: suggestion from PR 3399"
    , node: { rts_flags_override: ["-C0", "-A32m", "-n1m", "-AL512M"] } }

  , { desc: "rtsflags: cache fitting extreme"
    , node: { rts_flags_override: ["-A1m"] } }
  , { desc: "rtsflags: cache fitting extreme + parallelism"
    , node: { rts_flags_override: ["-A1m", "-N4"] } }
  , { desc: "rtsflags: cache fitting hard"
    , node: { rts_flags_override: ["-A2m"] } }
  , { desc: "rtsflags: cache fitting hard + parallelism"
    , node: { rts_flags_override: ["-A2m", "-N4"] } }
  , { desc: "rtsflags: cache fitting"
    , node: { rts_flags_override: ["-A4m"] } }
  , { desc: "rtsflags: cache fitting + higher parallelism"
    , node: { rts_flags_override: ["-A4m", "-N4"] } }

  , { desc: "regression, March 2022 data set sizes"
    , genesis: { utxo:           7000000
               , delegators:     1250000
               , max_block_size: 80000
               }
    , generator: { tps:          11
                 }
    }

  , { desc: "Plutus return-success"
    , generator: { plutusMode: true
                 , plutusScript: "always-succeeds-spending.plutus"
		 , plutusData: 0
		 , plutusRedeemer: 0
                 , executionMemory: 125000
		 , executionSteps: 100000000
                 } }
  , { desc: "Plutus, 1e7-mem"
    , generator: { inputs_per_tx:           1
                 , outputs_per_tx:          1
		 , tx_count:             7500
                 , plutusMode: true
                 , plutusScript: "sum.plutus"
                 , plutusData: 1144
                 , plutusRedeemer: 654940
                 , executionMemory:    9998814   #  452138   + estimate
                 # true costs:  executionSteps:  3640582981   # 163807162 + estimate
                 , executionSteps: 10000000000 # set costs to 1e10 to limit plutus to 4 Tx per block
                 , debugMode: false
                 } }
  , { desc: "Plutus, 1e10-cpu smoke"
    , generator: { inputs_per_tx:           1
                 , outputs_per_tx:          1
                 , tx_count:               80
                 , plutusMode: true
                 , plutusScript: "sum.plutus"
                 , plutusData: 3304
                 , plutusRedeemer: 5459860
                 , executionMemory:   27507774
                 , executionSteps:  9999406981
                 , debugMode: true
                 } }
  , { desc: "Plutus, 1e10-cpu"
    , generator: { inputs_per_tx:           1
                 , outputs_per_tx:          1
		 , tx_count:             7500
                 , plutusMode: true
                 , plutusScript: "sum.plutus"
                 , plutusData: 3304
                 , plutusRedeemer: 5459860
                 , executionMemory:   27507774    #    460244 + estimate
                 , executionSteps:  9999406981    # 166751062 + estimate
                 , debugMode: false
                 } }
  , { desc: "Plutus, auto-mode-smoke-test"
    , generator: { inputs_per_tx:           1
                 , outputs_per_tx:          1
		 , tx_count:              100
                 , plutusMode:           true
                 , plutusAutoMode:       true
                 }
    }
  , { desc: "Plutus, baseline"
    , generator:
        { inputs_per_tx:           1
        , outputs_per_tx:          1
        , epochs:                  7
        , tx_count:            14000 # 8000eplen * 7eps / 20blockfreq * 5tx/block
        , plutusMode:           true
        , plutusAutoMode:       true
        }
    }
  , { desc: "Plutus, bump 1, Dec 2 2021"
    , generator:
        { inputs_per_tx:           1
        , outputs_per_tx:          1
        , epochs:                  7
        , tx_count:            14000 # 8000eplen * 7eps / 20blockfreq * 5tx/block
        , plutusMode:           true
        , plutusAutoMode:       true
        }
    , genesis:
        { max_block_size:            73728
        , alonzo:
            { maxTxExUnits:
                { exUnitsMem:     11250000
                }
            }
        }
    }
  , { desc: "Plutus, bump 2, 2022"
    , generator:
        { inputs_per_tx:           1
        , outputs_per_tx:          1
        , epochs:                  7
        , tx_count:            14000 # 8000eplen * 7eps / 20blockfreq * 5tx/block
        , plutusMode:           true
        , plutusAutoMode:       true
        }
    , genesis:
        { max_block_size:            73728
        , alonzo:
            { maxTxExUnits:
                { exUnitsMem:     12500000
                }
            }
        }
    }
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
  | map (reduce .[] as $item ({}; . * $item));

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

def aux_profiles($compo):
[ { name: "smoke"
  , desc: "A quick smoke test"
  , genesis:
    { utxo:                  3
    , delegators:            $compo.n_dense_hosts
    , dense_pool_density:    10
    }
  , generator: { tx_count: 100,   inputs_per_tx: 1, outputs_per_tx: 1
               , init_cooldown: 25, finish_patience: 4
               }
  }
, { name: "smoke-epoch"
  , desc: "Smoke test for epoch transitions"
  , genesis:
    { utxo:                  1
    , epoch_length:          60
    , parameter_k:           2
    , delegators:            $compo.n_dense_hosts
    , dense_pool_density:    1
    }
  , generator: { tx_count:   (9 * 6000)
               , init_cooldown: 25, finish_patience: 1000
               }
  }
, { name: "smoke-dense-large"
  , desc: "A quick smoke test, for large, dense clusters"
  , genesis:
    { utxo:                  3
    , delegators:            $compo.n_dense_hosts
    , dense_pool_density:    10
    }
  , generator: { tx_count: 100,   inputs_per_tx: 1, outputs_per_tx: 1
               , init_cooldown: 90, finish_patience: 10 }
  }
, { name: "smoke-large-1000"
  , desc: "A quick smoke test, for large, dense clusters"
  , generator: { tx_count: 1000, init_cooldown: 90, finish_patience: 10 }
  }
, { name: "smoke-large-5000"
  , desc: "A quick smoke test, for large, dense clusters"
  , generator: { tx_count: 5000, init_cooldown: 90, finish_patience: 10 }
  }
];
