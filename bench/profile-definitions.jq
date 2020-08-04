## Common parameters:
##
##  $era:
##    "byron" or "shelley"
##
##  $composition:
##    { n_bft_delegates: INT
##    , n_pools:         INT
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

def era_genesis_params($era; $composition):
{ common:
  { protocol_magic:          42
    ## XXX: for some reason, Shelley genesis generator does not respect
    ##      --testnet-magic
  , total_balance:           900000000000000
  }
, byron:
  { parameter_k:             2160
  , n_poors:                 128
  , n_delegates:             $composition.n_total
    ## Note, that the delegate count doesnt have to match cluster size.
  , delegate_share:          0.9
  , avvm_entries:            128
  , avvm_entry_balance:      100000000000000
  , secret:                  2718281828
  , slot_duration:           20
  }
, shelley:
  { parameter_k:             10
  , epoch_length:            2200   # Ought to be at least (10 * k / f).
  , slot_duration:           1
  , decentralisation_param:  0.5
  , max_tx_size:             16384
  , pools_balance:           800000000000000
  , active_slots_coeff:      0.05
  }
} | (.common + .[$era]);

def era_genesis_profiles($era):
{ byron:
  [ { max_block_size: 2000000 }
  , { max_block_size: 1000000 }
  , { max_block_size:  500000 }
  , { max_block_size:  250000 }
  , { max_block_size:  128000 }
  , { max_block_size:   64000 }
  , { max_block_size:   32000 }
  ]
, shelley:
  [ { max_block_size:   64000 }
  ]
} | .[$era];

def era_generator_params($era):
{ common:
  {
  }
, byron:
  { init_cooldown:           120
  , tx_fee:                  10000000
  }
, shelley:
  { init_cooldown:           40
  , tx_fee:                  1000000
  }
} | (.common + .[$era]);

def era_generator_profiles($era):
{ byron:
  [ { txs:  50000, add_tx_size: 100, io_arity: 1,  tps: 100 }
  , { txs:  50000, add_tx_size: 100, io_arity: 2,  tps: 100 }
  , { txs:  50000, add_tx_size: 100, io_arity: 4,  tps: 100 }
  , { txs:  50000, add_tx_size: 100, io_arity: 8,  tps: 100 }
  , { txs:  50000, add_tx_size: 100, io_arity: 16, tps: 100 }
  ]
, shelley:
  [ { txs: 250000, add_tx_size: 100, io_arity: 1,  tps: 100 }
  , { txs:  50000, add_tx_size: 100, io_arity: 1,  tps: 100 }
  , { txs:  10000, add_tx_size: 100, io_arity: 1,  tps: 100 }
  , { txs:   3000, add_tx_size: 100, io_arity: 1,  tps: 100 }
  ]
} | .[$era];

def era_tolerances($era; $genesis):
{ common:
  { tx_loss_ratio:                  0.0
  , start_log_spread_s:             60
  , last_log_spread_s:              60
  , slot_spread_dbsync_first:       5
  , slot_spread_dbsync_last:        5
  , silence_since_last_block_s:     40
  , cluster_startup_overhead_s:     60
  }
, byron:
  { finish_patience:                7
  , maximum_missed_slots:           5
  , minimum_chain_density:          0.9
  }
, shelley:
  { finish_patience:                15
  , maximum_missed_slots:           0
  , minimum_chain_density:          ($genesis.active_slots_coeff * 0.5)
  }
} | (.common + .[$era]);

def generator_aux_profiles:
[ { name: "short"
  , txs: 10000, add_tx_size: 100, io_arity: 1,  tps: 100
  }
, { name: "small"
  , txs: 1000,  add_tx_size: 100, io_arity: 1,  tps: 100
  , init_cooldown: 25, finish_patience: 4 }
, { name: "edgesmoke"
  , txs: 100,   add_tx_size: 100, io_arity: 1,  tps: 100
  , init_cooldown: 25, finish_patience: 3 }
, { name: "smoke"
  , txs: 100,   add_tx_size: 100, io_arity: 1,  tps: 100
  , init_cooldown: 25, finish_patience: 4 }
];