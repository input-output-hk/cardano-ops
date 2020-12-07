## Common parameters:
##
##  $era:
##    "byron" or "shelley"
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

def era_genesis_params($era; $compo):
{ common:
  { protocol_magic:          42
    ## XXX: for some reason, Shelley genesis generator does not respect
    ##      --testnet-magic
  , total_balance:           900000000000000
  , genesis_future_offset:   "3 minutes"
  }
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
, shelley:
  { parameter_k:             10
  , epoch_length:            2200   # Ought to be at least (10 * k / f).
  , slot_duration:           1
  , decentralisation_param:  0.5
  , max_tx_size:             16384
  , pools_balance:           800000000000000
  , active_slots_coeff:      0.05
  , extra_delegators:        0
  , stuffed_utxo:            0
  , max_block_size:          64000
  , dense_pool_density:      1
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

def era_node_profiles($era):
{ common:
  [{}]
, byron:
  []
, shelley:
  []
} | (.common + .[$era]);

def era_node_params($era):
{ common:
  {
  }
, byron:
  {
  }
, shelley:
  {
  }
} | (.common + .[$era]);

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

def era_default_generator_profile($era):
{ byron:   { txs:  50000, add_tx_size: 100, io_arity: 2,  tps: 100 }
, shelley: { txs:   3000, add_tx_size: 100, io_arity: 2,  tps: 100 }
} | .[$era];

def era_generator_profiles($era):
{ byron:
  [ { txs:  50000, add_tx_size: 100, io_arity: 1,  tps: 100 }
  , { txs:  50000, add_tx_size: 100, io_arity: 2,  tps: 100 }
  , { txs:  50000, add_tx_size: 100, io_arity: 4,  tps: 100 }
  , { txs:  50000, add_tx_size: 100, io_arity: 8,  tps: 100 }
  , { txs:  50000, add_tx_size: 100, io_arity: 16, tps: 100 }
  ]
, shelley:
  [ { txs: 250000, add_tx_size: 100, io_arity: 2,  tps: 100 }
  , { txs:  50000, add_tx_size: 100, io_arity: 8,  tps: 100 }
  , { txs:  50000, add_tx_size: 100, io_arity: 4,  tps: 100 }
  , { txs:  50000, add_tx_size: 100, io_arity: 2,  tps: 100 }
  , { txs:  10000, add_tx_size: 100, io_arity: 2,  tps: 100 }
  , { txs:   3000, add_tx_size: 100, io_arity: 1,  tps: 100 }
  , { txs:    500, add_tx_size: 100, io_arity: 1,  tps: 100 }
  ]
} | .[$era];

def era_tolerances($era; $genesis):
{ common:
  { tx_loss_ratio:                  0.0
  , start_log_spread_s:             120
  , last_log_spread_s:              120
  , silence_since_last_block_s:     120
  , cluster_startup_overhead_s:     60
  }
, byron:
  { finish_patience:                7
  , maximum_missed_slots:           5
  , minimum_chain_density:          0.9
  }
, shelley:
  { finish_patience:                7
  , maximum_missed_slots:           0
  , minimum_chain_density:          ($genesis.active_slots_coeff * 0.5)
  }
} | (.common + .[$era]);

def aux_profiles:
[ { name: "short",
    generator: { txs: 10000, add_tx_size: 100, io_arity: 1,  tps: 100 }
  }
, { name: "small",
    generator: { txs: 1000,  add_tx_size: 100, io_arity: 1,  tps: 100
               , init_cooldown: 25, finish_patience: 4 }
  }
, { name: "smoke",
    generator: { txs: 100,   add_tx_size: 100, io_arity: 1,  tps: 100
               , init_cooldown: 25, finish_patience: 4 }
  }

, { name: "k1000-52-1000kU-dlg0.33"
  , generator: { txs: 44000, add_tx_size: 100, io_arity: 1,  tps: 2 }
  , genesis:
    { dense_pool_density:        20
    , extra_delegators:      333000
    , stuffed_utxo:          667000
    , reuse:                   true
    , genesis_future_offset: "22 minutes" }
  }
, { name: "k1000-52-1000kU-dlg1.0"
  , generator: { txs: 44000, add_tx_size: 100, io_arity: 1,  tps: 2 }
  , genesis:
    { dense_pool_density:        20
    , extra_delegators:     1000000
    , stuffed_utxo:               0
    , reuse:                   true
    , genesis_future_offset: "32 minutes" }
  }
, { name: "k500-52-1000kU"
  , generator: { txs: 44000, add_tx_size: 100, io_arity: 1,  tps: 2 }
  , genesis:
    { dense_pool_density:        10
    , extra_delegators:      500000
    , stuffed_utxo:          500000
    , reuse:                   true
    , genesis_future_offset: "22 minutes" }
  }
, { name: "k500-52-1500kU"
  , generator: { txs: 44000, add_tx_size: 100, io_arity: 1,  tps: 2 }
  , genesis:
    { dense_pool_density:        10
    , extra_delegators:      750000
    , stuffed_utxo:          750000
    , reuse:                   true
    , genesis_future_offset: "22 minutes" }
  }

, { name: "k1000-fast"
  , generator: { txs: 10000, add_tx_size: 100, io_arity: 1,  tps: 100 }
  , genesis:
    { dense_pool_density:        20
    , extra_delegators:      500000
    , stuffed_utxo:          500000
    , reuse:                   true
    , genesis_future_offset: "9 minutes" }
  }
, { name: "k2000-fast"
  , generator: { txs: 10000, add_tx_size: 100, io_arity: 1,  tps: 100 }
  , genesis:
    { dense_pool_density:       200
    , extra_delegators:      500000
    , stuffed_utxo:          500000
    , reuse:                   true
    , genesis_future_offset: "9 minutes" }
  }
, { name: "k1000"
  , generator: { txs: 22000, add_tx_size: 100, io_arity: 1,  tps: 1 }
  , genesis:
    { dense_pool_density:       100
    , extra_delegators:      500000
    , stuffed_utxo:          500000
    , reuse:                   true
    , genesis_future_offset: "9 minutes" }
  }
, { name: "k2000"
  , generator: { txs: 22000, add_tx_size: 100, io_arity: 1,  tps: 1 }
  , genesis:
    { dense_pool_density:       200
    , extra_delegators:      500000
    , stuffed_utxo:          500000
    , reuse:                   true
    , genesis_future_offset: "9 minutes" }
  }
, { name: "k3000"
  , generator: { txs: 22000, add_tx_size: 100, io_arity: 1,  tps: 1 }
  , genesis:
    { dense_pool_density:       300
    , extra_delegators:      500000
    , stuffed_utxo:          500000
    , reuse:                   true
    , genesis_future_offset: "9 minutes" }
  }

, { name: "k1000-fast52"
  , generator: { txs: 10000, add_tx_size: 100, io_arity: 1,  tps: 100 }
  , genesis:
    { dense_pool_density:        20
    , extra_delegators:      500000
    , stuffed_utxo:          500000
    , reuse:                   true
    , genesis_future_offset: "22 minutes" }
  }
, { name: "k1000-52-1500kU"
  , generator: { txs: 44000, add_tx_size: 100, io_arity: 1,  tps: 2 }
  , genesis:
    { dense_pool_density:        20
    , extra_delegators:      750000
    , stuffed_utxo:          750000
    , reuse:                   true
    , genesis_future_offset: "32 minutes" }
  }
, { name: "k1000-52-1000kU"
  , generator: { txs: 44000, add_tx_size: 100, io_arity: 1,  tps: 2 }
  , genesis:
    { dense_pool_density:        20
    , extra_delegators:      500000
    , stuffed_utxo:          500000
    , reuse:                   true
    , genesis_future_offset: "22 minutes" }
  }
, { name: "k1000-52-750kU"
  , generator: { txs: 44000, add_tx_size: 100, io_arity: 1,  tps: 2 }
  , genesis:
    { dense_pool_density:        20
    , extra_delegators:      375000
    , stuffed_utxo:          375000
    , reuse:                   true
    , genesis_future_offset: "22 minutes" }
  }
, { name: "k1000-52-500kU"
  , generator: { txs: 44000, add_tx_size: 100, io_arity: 1,  tps: 2 }
  , genesis:
    { dense_pool_density:        20
    , extra_delegators:      250000
    , stuffed_utxo:          250000
    , reuse:                   true
    , genesis_future_offset: "22 minutes" }
  }

, { name: "k2000-fast52"
  , generator: { txs: 10000, add_tx_size: 100, io_arity: 1,  tps: 100 }
  , genesis:
    { dense_pool_density:        40
    , extra_delegators:      500000
    , stuffed_utxo:          500000
    , reuse:                   true
    , genesis_future_offset: "22 minutes" }
  }
, { name: "k2000-52"
  , generator: { txs: 44000, add_tx_size: 100, io_arity: 1,  tps: 2 }
  , genesis:
    { dense_pool_density:        40
    , extra_delegators:      500000
    , stuffed_utxo:          500000
    , reuse:                   true
    , genesis_future_offset: "22 minutes" }
  }

, { name: "k3000-fast52"
  , generator: { txs: 10000, add_tx_size: 100, io_arity: 1,  tps: 100 }
  , genesis:
    { dense_pool_density:        60
    , extra_delegators:      500000
    , stuffed_utxo:          500000
    , reuse:                   true
    , genesis_future_offset: "22 minutes" }
  }
, { name: "k3000-52"
  , generator: { txs: 44000, add_tx_size: 100, io_arity: 1,  tps: 2 }
  , genesis:
    { dense_pool_density:        60
    , extra_delegators:      500000
    , stuffed_utxo:          500000
    , reuse:                   true
    , genesis_future_offset: "22 minutes" }
  }
];