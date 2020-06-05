#!/usr/bin/env nix-shell
#!nix-shell -i crystal -p crystal -I nixpkgs=/nix/store/3b6p06fazphgdzwkf9g75l0pwsm5dnj8-source

# Crystal v0.34 source path for `-I nixpkgs=` is from:
#   nix-instantiate --eval -E '((import ../nix/sources.nix).nixpkgs-crystal).outPath'

require "json"

LATEST_CARDANO_URL = "https://hydra.iohk.io/job/Cardano/iohk-nix/cardano-deployment/latest-finished"
NODE_METRICS_PORT = 12798

CLUSTER          = `nix-instantiate --eval -E --json '(import ./globals.nix {}).deploymentName'`.to_s.strip('"')
NETWORK          = Array(String).from_json(`nix-instantiate --eval -E --json 'let n = import ./deployments/cardano-aws.nix; in __attrNames n'`)
CORE_NODES       = NETWORK.select { |n| /^c-[a-z]-[0-9]+$/ =~ n }
EDGE_NODES       = NETWORK.select { |n| /^e-[a-z]-[0-9]+$/ =~ n }
FAUCET_NODES     = NETWORK.select { |n| /^faucet/ =~ n }
MONITORING_NODES = NETWORK.select { |n| /^monitoring/ =~ n }
NETWORK_ATTRS    = NETWORK - CORE_NODES - EDGE_NODES - FAUCET_NODES - MONITORING_NODES

#p! CORE_NODES
#p! EDGE_NODES
#p! FAUCET_NODES
#p! MONITORING_NODES
#p! NETWORK_ATTRS

p "CLUSTER = #{CLUSTER}"
p "LATEST_CARDANO_URL = #{LATEST_CARDANO_URL}"

LATEST_REPORT_URL = `curl -sL #{LATEST_CARDANO_URL} | grep https | grep download | grep -oP '="\\K[^"]+'`.strip
p "LATEST_REPORT_URL = #{LATEST_REPORT_URL}"

LATEST_GENESIS_URL = "#{LATEST_REPORT_URL.rstrip("index.html")}#{CLUSTER}-genesis.json"
p "LATEST_GENESIS_URL = #{LATEST_GENESIS_URL}"

LATEST_GENESIS = `curl -sL #{LATEST_GENESIS_URL}`
#p "LATEST_GENESIS = #{LATEST_GENESIS}"

GENESIS = JSON.parse(LATEST_GENESIS)

SLOTS_PER_KES_PERIOD = GENESIS["slotsPerKESPeriod"]
SLOTS_PER_KES_PERIOD_INT = SLOTS_PER_KES_PERIOD.to_s.to_i64? || 0_i64
p "SLOTS_PER_KES_PERIOD_INT: #{SLOTS_PER_KES_PERIOD_INT}"

nodeKesPeriod = Hash(String, Int64).new
CORE_NODES.each do |n|
 slotHeight = `nixops ssh #{n} -- 'curl -s #{n}:#{NODE_METRICS_PORT}/metrics | grep -oP "cardano_node_ChainDB_metrics_slotNum_int \\K[0-9]+"'`
 slotHeightInt = slotHeight.to_i64? || 0_i64
 kesPeriodStart = (slotHeightInt / SLOTS_PER_KES_PERIOD_INT).floor.to_i64
 nodeKesPeriod[n] = kesPeriodStart
 #p "#{n}: #{slotHeightInt}; kesPeriodStart = #{kesPeriodStart}"
end

p ""
pp! nodeKesPeriod
p ""

fail = false
if (consensusValues = nodeKesPeriod.values.uniq.size) != 1
  p "Aborting: There are multiple KES start periods calculated on the core nodes (#{consensusValues} unique values); manual intervention required."
  fail = true
end

if nodeKesPeriod.values.includes?(0)
  p "Aborting: At least one KES period is 0; manual intervention required."
  fail = true
end

if fail
  # GENERATE AN ALERT
  exit
end

p "Test"
