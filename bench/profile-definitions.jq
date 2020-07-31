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
##     which yield a set product of _final, benchmarking profiles._
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
  , slot_duration:           20000
  }
, shelley:
  { parameter_k:             20
  , epoch_length:            4000   # Ought to be at least (10 * k / f).
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
  { init_cooldown:           20
  , tx_fee:                  1000000
  }
} | (.common + .[$era]);

def era_generator_profiles($era):
{ byron:
  [ { txs: 50000, add_tx_size: 100, io_arity: 1,  tps: 100 }
  , { txs: 50000, add_tx_size: 100, io_arity: 2,  tps: 100 }
  , { txs: 50000, add_tx_size: 100, io_arity: 4,  tps: 100 }
  , { txs: 50000, add_tx_size: 100, io_arity: 8,  tps: 100 }
  , { txs: 50000, add_tx_size: 100, io_arity: 16, tps: 100 }
  ]
, shelley:
  [ { txs: 50000, add_tx_size: 100, io_arity: 1,  tps: 100 }
  , { txs: 10000, add_tx_size: 100, io_arity: 1,  tps: 100 }
  , { txs:  3000, add_tx_size: 100, io_arity: 1,  tps: 100 }
  ]
} | .[$era];

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