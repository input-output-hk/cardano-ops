#!/usr/bin/env nix-shell
#!nix-shell -i crystal -p crystal -I nixpkgs=/nix/store/3b6p06fazphgdzwkf9g75l0pwsm5dnj8-source

# Crystal v0.34 source path for `-I nixpkgs=` is from:
#   nix-instantiate --eval -E '((import ../nix/sources.nix).nixpkgs-crystal).outPath'

# This script can be used in cron.  For example:
# 00 15 * * * cd ~/$CLUSTER && nix-shell --run 'kes-rotation -r --all' -I nixpkgs="$(nix eval '(import ./nix {}).path')" \
#   &> kes-rotation-logs/kes-rotate-$(date -u +"\%F_\%H-\%M-\%S").log

require "json"
require "email"
require "option_parser"

EMAIL_ENABLED           = ENV.fetch("EMAIL_ENABLED", "TRUE") == "TRUE" ? true : false
MOCK_ENABLED            = ENV.fetch("MOCK_ENABLED", "FALSE") == "TRUE" ? true : false
PATH_MOD                = ENV.fetch("PATH_MOD", ".")
DENIED_CLUSTERS         = [ "mainnet" ] of String

EMAIL_FROM              = "devops@ci.iohkdev.io"
EMAIL_TO                = "devops@iohk.io"
LATEST_CARDANO_URL      = "https://hydra.iohk.io/job/Cardano/iohk-nix/cardano-deployment/latest-finished"
NODE_METRICS_PORT       = 12798
NOW                     = Time.utc.to_s("%F %R %z")
METRICS_WAIT_INTERVAL   = 60
METRICS_WAIT_ITERATIONS = 10

IO_CMD_OUT    = IO::Memory.new
IO_CMD_ERR    = IO::Memory.new
IO_TEE_FULL   = IO::Memory.new
IO_TEE_OUT    = IO::MultiWriter.new(IO_CMD_OUT, IO_TEE_FULL, STDOUT)
IO_TEE_ERR    = IO::MultiWriter.new(IO_CMD_ERR, IO_TEE_FULL, STDOUT)
IO_NO_TEE_OUT = IO::MultiWriter.new(IO_CMD_OUT, IO_TEE_FULL)
IO_NO_TEE_ERR = IO::MultiWriter.new(IO_CMD_ERR, IO_TEE_FULL)

class KesRotate
  setter nodeConfigOpt, allOpt, coreOpt, bftOpt, stkOpt, ignoreOpt

  @sesUsername : String
  @sesSecret : String
  @cluster : String
  @network : Array(String)

  def initialize

    @nodeConfigOpt = ""
    @allOpt = false
    @coreOpt = false
    @bftOpt = false
    @stkOpt = false
    @ignoreOpt = false

    if EMAIL_ENABLED
      if scriptCmdPrivate("nix-instantiate --eval -E --json '(import #{PATH_MOD}/static/ses.nix).sesSmtp.username'").success?
        @sesUsername = IO_CMD_OUT.to_s.strip('"')
      else
        abort("Unable to process the ses username.")
      end

      if scriptCmdPrivate("nix-instantiate --eval -E --json '(import #{PATH_MOD}/static/ses.nix).sesSmtp.secret'").success?
        @sesSecret = IO_CMD_OUT.to_s.strip('"')
      else
        abort("Unable to process the ses secret.")
      end
    else
      @sesUsername = ""
      @sesSecret = ""
    end

    if scriptCmdPrivate("nix-instantiate --eval -E --json '(import #{PATH_MOD}/globals.nix {}).environmentName'").success?
      @cluster = IO_CMD_OUT.to_s.strip('"')
      IO_TEE_OUT.puts "cluster: #{@cluster}"
    else
      kesAbort("Unable to process the environment name from the globals file.")
    end

    if DENIED_CLUSTERS.includes?(@cluster)
      kesAbort("The current cluster \"#{@cluster}\" is not allowed to use this script.")
    end

    if scriptCmdPrivate("nix-instantiate --eval -E --json 'let n = import #{PATH_MOD}/deployments/cardano-aws.nix; in __attrNames n'").success?
      @network = Array(String).from_json(IO_CMD_OUT.to_s)
    else
      kesAbort("Unable to process the network attribute names from the deployment.")
    end

  end

  def scriptCmd(cmd)
    IO_CMD_OUT.clear
    IO_CMD_ERR.clear
    result = Process.run(cmd, output: IO_TEE_OUT, error: IO_TEE_ERR, shell: true)
  end

  def scriptCmdPrivate(cmd)
    IO_CMD_OUT.clear
    IO_CMD_ERR.clear
    result = Process.run(cmd, output: IO_CMD_OUT, error: IO_CMD_ERR, shell: true)
  end

  def scriptCmdNoTee(cmd)
    IO_CMD_OUT.clear
    IO_CMD_ERR.clear
    result = Process.run(cmd, output: IO_NO_TEE_OUT, error: IO_NO_TEE_ERR, shell: true)
  end

  def kesAbort(msg)
    msg = "kesAbort on #{@cluster} at #{NOW}:\n" \
          "MESSAGE: #{msg}\n" \
          "STDOUT: #{IO_CMD_OUT}\n" \
          "STDERR: #{IO_CMD_ERR}"
    if EMAIL_ENABLED
      sendEmail("kesRotation ABORTED on #{@cluster} at #{NOW}", "#{msg}\n\nFULL LOG:\n#{IO_TEE_FULL}")
    else
      IO_TEE_OUT.puts msg
    end
    exit(1)
  end

  def sendEmail(subject, body)
    email = EMail::Message.new
    email.from(EMAIL_FROM)
    email.to(EMAIL_TO)
    email.subject(subject)
    email.message(body)
    config = EMail::Client::Config.new("email-smtp.us-east-1.amazonaws.com", 25)
    config.use_tls(EMail::Client::TLSMode::STARTTLS)
    config.tls_context
    config.tls_context.add_options(OpenSSL::SSL::Options::NO_SSL_V2 | OpenSSL::SSL::Options::NO_SSL_V3 | OpenSSL::SSL::Options::NO_TLS_V1 | OpenSSL::SSL::Options::NO_TLS_V1_1)
    config.use_auth("#{@sesUsername}", "#{@sesSecret}")
    client = EMail::Client.new(config)
    client.start do
      send(email)
    end
  end

  def doRotation

    IO_TEE_OUT.puts "Script options selected:"
    IO_TEE_OUT.puts "nodeConfigOpt = #{@nodeConfigOpt}"
    IO_TEE_OUT.puts "allOpt = #{@allOpt}"
    IO_TEE_OUT.puts "coreOpt = #{@coreOpt}"
    IO_TEE_OUT.puts "bftOpt = #{@bftOpt}"
    IO_TEE_OUT.puts "stkOpt = #{@stkOpt}"
    IO_TEE_OUT.puts "ignoreOpt = #{@ignoreOpt}"

    IO_TEE_OUT.puts "LATEST_CARDANO_URL: #{LATEST_CARDANO_URL}"

    if @network
      coreNodes       = @network.select { |n| /^c-[a-z]-[0-9]+$/ =~ n }
      bftNodes        = @network.select { |n| /^bft-[a-z]-[0-9]+$/ =~ n }
      stkNodes        = @network.select { |n| /^stk-[a-z]-[0-9]+.*$/ =~ n }
      edgeNodes       = @network.select { |n| /^e-[a-z]-[0-9]+$/ =~ n }
      relayNodes      = @network.select { |n| /^rel-[a-z]-[0-9]+$/ =~ n }
      faucetNodes     = @network.select { |n| /^faucet/ =~ n }
      monitoringNodes = @network.select { |n| /^monitoring/ =~ n }
      networkAttrs    = @network - coreNodes - bftNodes - stkNodes - edgeNodes - relayNodes - faucetNodes - monitoringNodes

      if @allOpt
        kesNodes = coreNodes + bftNodes + stkNodes
      else
        kesNodes = [] of String
        kesNodes.concat(coreNodes) if @coreOpt
        kesNodes.concat(bftNodes) if @bftOpt
        kesNodes.concat(stkNodes) if @stkOpt
      end
    else
      kesAbort("The network array is empty")
    end

    IO_TEE_OUT.puts "Selected KES nodes: #{kesNodes}"

    #p! edgeNodes
    #p! faucetNodes
    #p! monitoringNodes
    #p! networkAttrs


    config = JSON.parse(File.read(@nodeConfigOpt))
    protocol = config["Protocol"]
    IO_TEE_OUT.puts "Protocol: #{protocol}"

    case protocol
    when "RealPBFT" then kesAbort("KES rotation does not need to happen in the byron era")
    when "TPraos"   then eraName = "Shelley"
    when "Cardano"  then eraName = "Shelley"
    else kesAbort("Unrecognized protocol in the latest config file")
    end

    genesisPath = config["#{eraName}GenesisFile"]
    IO_TEE_OUT.puts "genesisPath: #{genesisPath}"

    genesis = JSON.parse(File.read(genesisPath.to_s))

    slotsPerKesPeriod = genesis["slotsPerKESPeriod"]
    slotsPerKesPeriodInt = slotsPerKesPeriod.to_s.to_i64? || 0_i64
    IO_TEE_OUT.puts "slotsPerKesPeriodInt: #{slotsPerKesPeriodInt}"

    nodeKesPeriod = Hash(String, Int64).new
    kesNodes.as(Array).each do |n|
      if scriptCmdPrivate("nixops ssh #{n} -- 'curl -s #{n}:#{NODE_METRICS_PORT}/metrics | grep -oP \"cardano_node_metrics_slotNum_int \\K[0-9]+\"'").success?
        slotHeight = IO_CMD_OUT.to_s
      else
        kesAbort("Failed to obtain slotHeight for node #{n}")
      end
      slotHeightInt = slotHeight.to_s.to_i64? || 0_i64
      kesPeriodStart = (slotHeightInt / slotsPerKesPeriodInt).floor.to_i64
      nodeKesPeriod[n] = kesPeriodStart
    end

    IO_TEE_OUT.puts "Calculated new kesPeriodStart:\n#{nodeKesPeriod}"

    if (consensusValues = nodeKesPeriod.values.uniq.size) != 1
      kesAbort("There are multiple KES start periods calculated on the core nodes (#{consensusValues} unique values); manual intervention required.")
    end

    if nodeKesPeriod.values.includes?(0)
      kesAbort("At least one KES period is 0; manual intervention required.")
    end

    kesNewStartPeriod = nodeKesPeriod.values.uniq[0]
    IO_TEE_OUT.puts "\nGenerating new KES keys at starting period: #{kesNewStartPeriod}\n"

    if MOCK_ENABLED
      rotateCmd1 = "test-cronjob-script #{kesNewStartPeriod}"
    else
      if @ignoreOpt
        rotateCmd1 = "./scripts/renew-kes-keys.sh #{kesNewStartPeriod} || true"
      else
        rotateCmd1 = "./scripts/renew-kes-keys.sh #{kesNewStartPeriod}"
      end
    end

    if scriptCmdPrivate(rotateCmd1).success?
      IO_TEE_OUT.puts "Deployer kesUpdate key command output (#{rotateCmd1}):"
      IO_TEE_OUT.puts "  STDOUT: #{IO_CMD_OUT}"
      IO_TEE_OUT.puts "  STDERR: #{IO_CMD_ERR}"
    else
      kesAbort("Deployer kesUpdate command FAILED (#{rotateCmd1})")
    end

    IO_TEE_OUT.puts "Sleeping 10 seconds prior to deploying the new keys..."
    sleep(10)

    kesNodes.each do |n|
      if MOCK_ENABLED
        rotateCmd2 = "echo \"MOCK SENDING KEYS to core node #{n}\""
        rotateCmd3 = "nixops ssh-for-each --include #{n} -- 'id'"
      else
        rotateCmd2 = "nixops send-keys --include #{n}"
        rotateCmd3 = "nixops ssh-for-each --include #{n} -- 'systemctl restart cardano-node'"
      end

      IO_TEE_OUT.puts "Deploying new KES key to core node: #{n} (#{rotateCmd2})"
      if scriptCmdPrivate(rotateCmd2).success?
        IO_TEE_OUT.puts IO_CMD_OUT.to_s
        IO_TEE_OUT.puts IO_CMD_ERR.to_s
      else
        kesAbort("Failed to send the new KES key to core node: #{n} (#{rotateCmd2})")
      end

      IO_TEE_OUT.puts "Restarting cardano-node service on core node: #{n} (#{rotateCmd3})"
      if scriptCmdPrivate(rotateCmd3).success?
        IO_TEE_OUT.puts IO_CMD_OUT.to_s
        IO_TEE_OUT.puts IO_CMD_ERR.to_s
      else
        kesAbort("Failed to restart cardano-node with the new KES key on core node: #{n} (#{rotateCmd3})")
      end

      IO_TEE_OUT.puts "Waiting for metrics to re-appear on core node: #{n}"
      deployFinished = false
      METRICS_WAIT_ITERATIONS.times do |i|
        if scriptCmdPrivate("nixops ssh #{n} -- 'curl -s #{n}:#{NODE_METRICS_PORT}/metrics | grep -oP \"cardano_node_metrics_slotNum_int \\K[0-9]+\"'").success?
          IO_TEE_OUT.puts "Found slotNum_int metrics post KES update deploy on core node: #{n} at #{IO_CMD_OUT.to_s}"
          deployFinished = true
          break
        else
          IO_TEE_OUT.puts "... sleeping #{METRICS_WAIT_INTERVAL} seconds ..."
          sleep(METRICS_WAIT_INTERVAL)
        end
      end
      kesAbort("Failed to find returned slotNum metrics on core node: #{n}") unless deployFinished
      IO_TEE_OUT.puts "\n"
    end

    IO_TEE_OUT.puts "KES key rotation and deployment on cluster #{@cluster} at #{NOW}, completed."

    if EMAIL_ENABLED
      sendEmail("kesRotation SUCCESS on #{@cluster} at #{NOW}",
                "KES key rotation and deployment on cluster #{@cluster} at #{NOW}, completed.\n\n#{IO_TEE_FULL}")
    end
  end
end

nodeConfigOpt = ENV.fetch("NODE_CONFIG_PATH", "")
proceed = false
allOpt = false
coreOpt = false
bftOpt = false
stkOpt = false
ignoreOpt = false
OptionParser.parse do |parser|
  parser.banner = "Usage: kes-rotate [arguments]"
  parser.on("-c NODE_CONFIG_PATH", "--config NODE_CONFIG_PATH", "Path to a cardano node config for the network") { |config| nodeConfigOpt = config }
  parser.on("-a", "--all", "Updates and deploys all KES nodes") { allOpt = true }
  parser.on("-r", "--rotate", "Updates and deploy the KES keys (required option)") { proceed = true }
  parser.on("-a", "--all", "Updates and deploys all KES nodes") { allOpt = true }
  parser.on("--core", "Updates and deploys KES core nodes (c-X-Y)") { coreOpt = true }
  parser.on("--bft", "Updates and deploys KES bft nodes (bft-X-Y)") { bftOpt = true }
  parser.on("--stk", "Updates and deploys KES stake nodes (stk-X-Y-TICKER)") { stkOpt = true }
  parser.on("-i", "--ignore", "Ignores errors thrown by renew-kes-keys.sh (CAUTION!)") { ignoreOpt = true }
  parser.on("-h", "--help", "Show this help") do
    puts parser
    exit
  end
  parser.invalid_option do |flag|
    STDERR.puts "ERROR: #{flag} is not a valid option."
    STDERR.puts parser
    exit(1)
  end
end

if proceed
  kesRotate=KesRotate.new
  kesRotate.nodeConfigOpt = nodeConfigOpt
  kesRotate.allOpt = allOpt
  kesRotate.coreOpt = coreOpt
  kesRotate.bftOpt = bftOpt
  kesRotate.stkOpt = stkOpt
  kesRotate.ignoreOpt = ignoreOpt
  kesRotate.doRotation
end
exit 0
