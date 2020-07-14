def byron_genesis_protocol_params($p):
{ heavyDelThd:       "300000000000"
, maxBlockSize:      "\($p.max_block_size)"
, maxHeaderSize:     "2000000"
, maxProposalSize:   "700"
, maxTxSize:         "4096"
, mpcThd:            "20000000000000"
, scriptVersion:     0
, slotDuration:      "\($p.slot_duration)"
, softforkRule:
  { initThd:         "900000000000000"
  , minThd:          "600000000000000"
  , thdDecrement:    "50000000000000"
  }
, txFeePolicy:
  { multiplier:      "43946000000"
  , summand:         "155381000000000"
  }
, unlockStakeEpoch:  "18446744073709551615"
, updateImplicit:    "10000"
, updateProposalThd: "100000000000000"
, updateVoteThd:     "1000000000000"
};

def byron_genesis_cli_args($p):
[ "--k",                      $p.parameter_k
, "--protocol-magic",         $p.protocol_magic
, "--secret-seed",            $p.secret
, "--total-balance",          $p.total_balance

, "--n-poor-addresses",       $p.n_poors
, "--n-delegate-addresses",   $p.n_delegates
, "--delegate-share",         $p.delegate_share
, "--avvm-entry-count",       $p.avvm_entries
, "--avvm-entry-balance",     $p.avvm_entry_balance
];

def shelley_genesis_protocol_params($p):
{ activeSlotsCoeff:           $p.active_slots_coeff
, epochLength:                $p.epoch_length
, securityParam:              $p.parameter_k
, slotLength:                 $p.slot_duration
, maxTxSize:                  $p.max_tx_size
, protocolParams:
  { "decentralisationParam":  $p.decentralisation_param
  , "maxBlockBodySize":       $p.max_block_size
  }
};

def shelley_genesis_cli_args($p; $composition; $cmd):
{ create0:
  [ "--testnet-magic",          $p.protocol_magic
  , "--supply",                 $p.total_balance
  , "--gen-genesis-keys",       $composition.n_bft_delegates
  ]
, create1:
  [ "--testnet-magic",          $p.protocol_magic
  , "--supply",                 $p.total_balance
  ]
, pools:
  [ "--argjson", "initialPoolCoin",
       $p.pools_balance / $composition.n_pools
  ]
} | .[$cmd];
