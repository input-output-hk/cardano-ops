def genesis_protocol_params($p; $composition):
{ activeSlotsCoeff:           $p.active_slots_coeff
, epochLength:                $p.epoch_length
, securityParam:              $p.parameter_k
, slotLength:                 $p.slot_duration
, maxTxSize:                  $p.max_tx_size
, protocolParams:
  { "decentralisationParam":  $p.decentralisation_param
  , "maxBlockBodySize":       $p.max_block_size
  , "nOpt":                   $p.n_pools
  }
};

def genesis_cli_args($p; $composition; $cmd):
{ create0:
  [ "--supply",                 $p.total_balance
  , "--testnet-magic",          $p.protocol_magic
  ]
, create1:
  ([ "--supply",                 ($p.total_balance - $p.pools_balance)
   , "--gen-genesis-keys",       $composition.n_bft_hosts
   , "--supply-delegated",       $p.pools_balance
   , "--gen-pools",              $p.n_pools
   , "--gen-stake-delegs",       ([$p.n_pools, $p.delegators] | max)
   , "--testnet-magic",          $p.protocol_magic
   , "--num-stuffed-utxo",       ($p.utxo - $p.delegators - 1)
                                 ## 1 is for the generator's very own funds.
   ] +
   if $p.dense_pool_density != 1
   then
   [ "--bulk-pool-cred-files",   $composition.n_dense_hosts
   , "--bulk-pools-per-file",    $p.dense_pool_density ]
   else [] end)
, pools:
  [ "--argjson", "initialPoolCoin",
       $p.pools_balance / $p.n_pools
  ]
} | .[$cmd];
