## Common parameters:
##
##  $era:
##    "shelley"
##    "allegra"
##    "mary"
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
} | (.common + .[$era]);

def generator_defaults($era):
{ common:
  { add_tx_size:             100
  , init_cooldown:           45
  , inputs_per_tx:           2
  , outputs_per_tx:          2
  , tx_fee:                  1000000
  , epochs:                  10
  , tps:                     2
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
  + [ if $gtor.scriptMode then "scr" else "cli" end ]
  + if $alzoHFAt != null
    then [ "alzo@\($alzoHFAt)" ]
    else [] end
  | join("-");

def utxo_delegators_density_profiles:
  [ { desc: "regression, February 2021 data set sizes, unsaturated"
    , genesis: { utxo: 2000000, delegators:  500000, scriptMode: false } }

  , { desc: "regression, February 2021 data set sizes"
    , genesis: { utxo: 2000000, delegators:  500000, scriptMode: false }
    , generator: { tps: 10 } }

  , { desc: "regression, August 2021 data set sizes"
    , genesis: { utxo: 3000000, delegators:  750000, scriptMode: false }
    , generator: { tps: 10 } }

  , { desc: "would the Alonzo hard fork meet the performance constraints?"
    , genesis: { utxo:  3000000, delegators:   750000 }
    , generator: { epochs: 6 }
    , node: { extra_config:
              { TestAlonzoHardForkAtEpoch: 3
              }}}

  , { desc: "calibration, with ~30 tx/64k-block; NOTE: needs special node & ops"
    , genesis: { utxo: 2000000, delegators:  500000 }
    , generator: { add_tx_size: 2000, tps: 10, scriptMode: false } }

  , { desc: "Alonzo HF at ep 3"
    , genesis: { utxo:  3000000, delegators:   750000 }
    , generator: { epochs: 6 }
    , node: { extra_config:
              { TestAlonzoHardForkAtEpoch: 3
              }}}

  , { desc: "Alonzo HF at ep 4"
    , genesis: { utxo:  3000000, delegators:   750000 }
    , generator: { epochs: 8 }
    , node: { extra_config:
              { TestAlonzoHardForkAtEpoch: 3
              }}}

  , { desc: "regression, February 2021 data set sizes, script mode"
    , genesis: { utxo: 2000000, delegators:  500000 }
    , generator: { tps: 10, scriptMode: true } }

  , { desc: "regression, August 2021 data set sizes, script mode"
    , genesis: { utxo: 3000000, delegators:  750000 }
    , generator: { tps: 10, scriptMode: true } }

  , { desc: "regression, August 2021 data set sizes, Alonzo @4, script mode"
    , genesis: { utxo: 3000000, delegators:  750000 }
    , generator: { tps: 10, scriptMode: true }
    , node: { extra_config:
              { TestAlonzoHardForkAtEpoch: 4
              }} }

  , { desc: "regression, August 2021 data set sizes, Alonzo @0, script mode"
    , genesis: { utxo: 3000000, delegators:  750000 }
    , generator: { tps: 10, scriptMode: true }
    , node: { extra_config:
              { TestAlonzoHardForkAtEpoch: 0
              }} }

  , { desc: "regression, projected future, data set sizes, Alonzo @0, script mode"
    , genesis: { utxo: 4000000, delegators: 1000000 }
    , generator: { tps: 10, scriptMode: true }
    , node: { extra_config:
              { TestAlonzoHardForkAtEpoch: 0
              }} }
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
[ { name: "smoke-10000"
  , generator: { tx_count: 10000, inputs_per_tx: 1, outputs_per_tx: 1,  tps: 100 }
  , genesis:
    { genesis_future_offset: "3 minutes"
    , utxo:                  1000
    , dense_pool_density:    10
    }
  }
, { name: "smoke-1000"
  , generator: { tx_count: 1000,  inputs_per_tx: 1, outputs_per_tx: 1,  tps: 100
               , init_cooldown: 25, finish_patience: 4 }
  , genesis:
    { genesis_future_offset: "3 minutes"
    , utxo:                  1000
    , dense_pool_density:    10
    }
  }
, { name: "smoke-100"
  , generator: { tx_count: 100,   inputs_per_tx: 1, outputs_per_tx: 1,  tps: 100
               , init_cooldown: 25, finish_patience: 4 }
  , genesis:
    { genesis_future_offset: "3 minutes"
    , utxo:                  1000
    , dense_pool_density:    10
    }
  }
, { name: "smoke-k50"
  , generator: { tx_count: 100,   inputs_per_tx: 1, outputs_per_tx: 1,  tps: 100
               , init_cooldown: 90, finish_patience: 4 }
  , genesis:
    { genesis_future_offset: "20 minutes" }
  }
];