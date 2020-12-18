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
  }

, shelley:
  { decentralisation_param:  0.5
  }

, allegra:
  { decentralisation_param:  0.5
  }

, mary:
  { decentralisation_param:  0.5
  }
} | (.common + .[$era]);

def generator_defaults($era):
{ common:
  { add_tx_size:             0
  , init_cooldown:           25
  , inputs_per_tx:           2
  , outputs_per_tx:          2
  , tx_fee:                  1000000
  , epochs:                  10
  , tps:                     2
  }
} | (.common + (.[$era] // {}));

def node_defaults($era):
{ common:
  {
  }
} | (.common + (.[$era] // {}));

def derived_genesis_params($compo; $gtor; $gsis; $node):
  (if      $compo.n_hosts > 50 then 32
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

def derived_generator_params($compo; $gtor; $gsis; $node):
  ($gsis.epoch_length * $gsis.slot_duration) as $epoch_duration
| ($epoch_duration * $gtor.epochs)           as $duration
|
{ common:
  { tx_count:                ($duration * ([$gtor.tps, 7] | min))
  }
} | (.common + (.[$era] // {}));

def derived_node_params($compo; $gtor; $gsis; $node):
{ common: {}
} | (.common + (.[$era] // {}));

def derived_tolerances($compo; $gtor; $gsis; $node; $tolers):
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
  ## Genesis
  [ "k\($gsis.n_pools)" ]
  + may_attr("dense_pool_density";
             $gsis; genesis_defaults($era; $compo); 1; "ppn")
  + [ ($gtor.epochs                | tostring) + "ep"
    , ($gsis.utxo       | . / 1000 | tostring) + "kU"
    , ($gsis.delegators | . / 1000 | tostring) + "kD"
    ]
  + may_attr("tps";
             $gtor; generator_defaults($era); 1; "tps")
  + may_attr("max_block_size";
             $gsis; genesis_defaults($era; $compo); 1000; "kb")
  + may_attr("add_tx_size";
             $gtor; generator_defaults($era); 1; "b")
  + may_attr("inputs_per_tx";
             $gtor; generator_defaults($era); 1; "i")
  + may_attr("outputs_per_tx";
             $gtor; generator_defaults($era); 1; "o")
  | join("-");

def utxo_profiles:
  [ { genesis: { utxo:         1000000 } }
  , { genesis: { utxo:         2000000 } }
  , { genesis: { utxo:         4000000 } }
  ];

def delegator_profiles:
  [ { genesis: { delegators:    125000 } }
  , { genesis: { delegators:    250000 } }
  , { genesis: { delegators:    500000 } }
  , { genesis: { delegators:   1000000 } }
  , { genesis: { delegators:   2000000 } }
  ];

def pool_density_profiles:
  [ { genesis: { dense_pool_density: 1  } }
  , { genesis: { dense_pool_density: 10 } }
  , { genesis: { dense_pool_density: 20 } }
  , { genesis: { dense_pool_density: 40 } }
  ];

def utxo_delegators_density_profiles:
  [ { genesis: { utxo: 1000000, delegators:  125000 } }
  , { genesis: { utxo: 1000000, delegators:  125000, dense_pool_density: 2 } }
  , { genesis: { utxo: 1000000, delegators:  125000, dense_pool_density: 4 } }
  , { genesis: { utxo: 1000000, delegators:  125000, dense_pool_density: 8 } }
  , { genesis: { utxo: 1000000, delegators:  125000, dense_pool_density: 20 } }
  , { genesis: { utxo: 1000000, delegators:  125000, dense_pool_density: 40 } }
  , { genesis: { utxo: 2000000, delegators:  125000 } }
  , { genesis: { utxo: 4000000, delegators:  125000 } }
  , { genesis: { utxo: 1000000, delegators:  250000 } }
  , { genesis: { utxo: 1000000, delegators:  500000 } }
  , { genesis: { utxo: 1000000, delegators: 1000000 } }
  , { genesis: { utxo: 2000000, delegators: 2000000 } }
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
  , start_log_spread_s:             120
  , last_log_spread_s:              120
  , silence_since_last_block_s:     120
  , tx_loss_ratio:                  0.02
  , finish_patience:                21
  , minimum_chain_density:          ($genesis.active_slots_coeff * 0.5)
  }
, shelley:
  { maximum_missed_slots:           0
  }
} | (.common + .[$era]);

def aux_profiles:
[ { name: "short"
  , generator: { tx_count: 10000, inputs_per_tx: 1, outputs_per_tx: 1,  tps: 100 }
  }
, { name: "small"
  , generator: { tx_count: 1000,  inputs_per_tx: 1, outputs_per_tx: 1,  tps: 100
               , init_cooldown: 25, finish_patience: 4 }
  }
, { name: "smoke"
  , generator: { tx_count: 100,   add_tx_size: 0, inputs_per_tx: 1, outputs_per_tx: 1,  tps: 100
               , init_cooldown: 25, finish_patience: 4 }
  }
, { name: "k1000-smoke"
  , generator: { tx_count: 100,   add_tx_size: 0, inputs_per_tx: 1, outputs_per_tx: 1,  tps: 100
               , init_cooldown: 25, finish_patience: 4 }
  , genesis:
    { genesis_future_offset: "32 minutes" }
  }

, { name: "k1000-52-1000kU-dlg0.33"
  , generator: { tx_count: 44000, add_tx_size: 0, inputs_per_tx: 1, outputs_per_tx: 1,  tps: 2 }
  , genesis:
    { dense_pool_density:        20
    , delegators:      333000
    , utxo:          667000
    , genesis_future_offset: "32 minutes" }
  }
, { name: "k1000-52-1000kU-dlg1.0"
  , generator: { tx_count: 44000, add_tx_size: 0, inputs_per_tx: 1, outputs_per_tx: 1,  tps: 2 }
  , genesis:
    { dense_pool_density:        20
    , delegators:     1000000
    , utxo:               0
    , genesis_future_offset: "32 minutes" }
  }

, { name: "k1000-fast"
  , generator: { tx_count: 10000, add_tx_size: 0, inputs_per_tx: 1, outputs_per_tx: 1,  tps: 100 }
  , genesis:
    { dense_pool_density:        20
    , delegators:      500000
    , utxo:          500000
    , genesis_future_offset: "9 minutes" }
  }

, { name: "k1000-fast52"
  , generator: { tx_count: 10000, add_tx_size: 0, inputs_per_tx: 1, outputs_per_tx: 1,  tps: 100 }
  , genesis:
    { dense_pool_density:        20
    , delegators:      500000
    , utxo:          500000
    , genesis_future_offset: "32 minutes" }
  }
, { name: "k1000-52-1500kU"
  , generator: { tx_count: 44000, add_tx_size: 0, inputs_per_tx: 1, outputs_per_tx: 1,  tps: 2 }
  , genesis:
    { dense_pool_density:        20
    , delegators:      750000
    , utxo:          750000
    , genesis_future_offset: "32 minutes" }
  }
, { name: "k1000-52-1000kU"
  , generator: { tx_count: 44000, add_tx_size: 0, inputs_per_tx: 1, outputs_per_tx: 1,  tps: 2 }
  , genesis:
    { dense_pool_density:        20
    , delegators:      500000
    , utxo:          500000
    , genesis_future_offset: "32 minutes" }
  }
, { name: "k1000-52-750kU"
  , generator: { tx_count: 44000, add_tx_size: 0, inputs_per_tx: 1, outputs_per_tx: 1,  tps: 2 }
  , genesis:
    { dense_pool_density:        20
    , delegators:      375000
    , utxo:          375000
    , genesis_future_offset: "32 minutes" }
  }
, { name: "k1000-52-500kU"
  , generator: { tx_count: 44000, add_tx_size: 0, inputs_per_tx: 1, outputs_per_tx: 1,  tps: 2 }
  , genesis:
    { dense_pool_density:        20
    , delegators:      250000
    , utxo:          250000
    , genesis_future_offset: "32 minutes" }
  }
];