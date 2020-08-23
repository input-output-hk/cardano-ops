#!/usr/bin/env nix-shell
#!nix-shell -i crystal -p crystal -I nixpkgs=/nix/store/3b6p06fazphgdzwkf9g75l0pwsm5dnj8-source

# Crystal v0.34 source path for `-I nixpkgs=` is from:
#   nix-instantiate --eval -E '((import ../nix/sources.nix).nixpkgs-crystal).outPath'

# This script can be used in cron.  For example:
# 00 16 * * * cd ~/$CLUSTER && nix-shell --run 'relay-update -r --all' -I nixpkgs="$(nix eval '(import ./nix {}).path')" \
#   &> relay-update-logs/relay-update-$(date -u +"\%F_\%H-\%M-\%S").log

require "json"
require "email"
require "option_parser"
require "http/client"
require "file_utils"

EMAIL_ENABLED           = ENV.fetch("EMAIL_ENABLED", "TRUE") == "TRUE" ? true : false
MOCK_ENABLED            = ENV.fetch("MOCK_ENABLED", "FALSE") == "TRUE" ? true : false
PATH_MOD                = ENV.fetch("PATH_MOD", ".")
RELATIVE_TOPOLOGY_PATH  = ENV.fetch("RELATIVE_TOPOLOGY_PATH", "static/registered_relays_topology.json")
IP_METADATA_URL         = ENV.fetch("IP_METADATA_URL", "http://169.254.169.254/latest/meta-data/public-ipv4")
DENIED_CLUSTERS         = [] of String

EMAIL_FROM              = "devops@ci.iohkdev.io"
EMAIL_TO                = "devops@iohk.io"
NODE_METRICS_PORT       = 12798
NOW                     = Time.utc.to_s("%F %R %z")
METRICS_WAIT_INTERVAL   = 60
METRICS_WAIT_ITERATIONS = 15
MINIMUM_PRODUCERS       = 100
MAX_NODES_PER_DEPLOY    = 10
MIN_DEPLOY_BATCHES      = 3

IO_CMD_OUT    = IO::Memory.new
IO_CMD_ERR    = IO::Memory.new
IO_TEE_FULL   = IO::Memory.new
IO_TEE_OUT    = IO::MultiWriter.new(IO_CMD_OUT, IO_TEE_FULL, STDOUT)
IO_TEE_ERR    = IO::MultiWriter.new(IO_CMD_ERR, IO_TEE_FULL, STDOUT)
IO_TEE_STDOUT = IO::MultiWriter.new(IO_TEE_FULL, STDOUT)
IO_NO_TEE_OUT = IO::MultiWriter.new(IO_CMD_OUT, IO_TEE_FULL)
IO_NO_TEE_ERR = IO::MultiWriter.new(IO_CMD_ERR, IO_TEE_FULL)

class RelayUpdate
  setter allOpt, edgeOpt, relOpt, minOpt

  @sesUsername : String
  @sesSecret : String
  @deployerIp : String
  @cluster : String
  @deployment : String
  @explorerUrl : String

  def initialize

    @allOpt = false
    @edgeOpt = false
    @relOpt = false
    @minOpt = 100

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
      updateAbort("Unable to process the environment name from the globals file.")
    end

    if DENIED_CLUSTERS.includes?(@cluster)
      updateAbort("The current cluster \"#{@cluster}\" is not allowed to use this script.")
    end

    if scriptCmdPrivate("nix-instantiate --eval -E --json '(import #{PATH_MOD}/globals.nix {}).deploymentName'").success?
      @deployment = IO_CMD_OUT.to_s.strip('"')
      IO_TEE_OUT.puts "deployment: #{@deployment}"
    else
      updateAbort("Unable to process the deployment name from the globals file.")
    end

    if scriptCmdPrivate("nix eval --raw '(with import ./#{PATH_MOD}/nix {}; \"https://${globals.explorerHostName}.${globals.domain}/relays/topology.json\")'").success?
      @explorerUrl = IO_CMD_OUT.to_s
    else
      updateAbort("Unable to process the explorer fqdn name from the globals file.")
    end

    IO_TEE_STDOUT.puts "Getting deployer IP"
    @deployerIp = ""
    if (response = apiGet(IP_METADATA_URL)).success?
      IO_TEE_STDOUT.puts "#{IO_CMD_OUT.to_s.split("\n").map { |i| "  " + i }.join("\n")}"
      IO_TEE_STDOUT.puts "Checking for valid deployer IP regex"
      IO_CMD_OUT.clear
      IO_CMD_ERR.clear
      if response.body.to_s =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/
        @deployerIp = response.body.to_s
        IO_TEE_STDOUT.puts "Deployer IP metadata is #{@deployerIp}"
        if ENV.has_key?("DEPLOYER_IP")
          IO_TEE_STDOUT.puts "Pre-existing DEPLOYER_IP env var: #{ENV["DEPLOYER_IP"]}"
        else
          IO_TEE_STDOUT.puts "No existing DEPLOYER_IP env var found; setting to #{@deployerIp}"
          ENV["DEPLOYER_IP"] = @deployerIp
        end
      else
        updateAbort("The deployer IP is not available (does not match an IPv4 pattern) but is required for deployment.")
      end
    else
      updateAbort("Unable to access deployer metadata.")
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

  def apiGet(path)
    IO_CMD_OUT.clear
    IO_CMD_ERR.clear
    response = HTTP::Client.get(path)
    unless response.success?
      IO_CMD_ERR.puts "statusCode: #{response.status_code}"
      IO_CMD_ERR.puts "statusMessage: #{response.status_message}\n"
      IO_CMD_ERR.puts "Result: #{response.body}"
      updateAbort("Explorer GET URL (#{@explorerUrl}) FAILED")
    end
    IO_CMD_OUT.puts "statusCode: #{response.status_code}"
    IO_CMD_OUT.puts "statusMessage: #{response.status_message}\n"
    return response
  end

  def updateAbort(msg)
    msg = "updateAbort on #{@cluster} at #{NOW}:\n" \
          "MESSAGE: #{msg}\n" \
          "STDOUT: #{IO_CMD_OUT}\n" \
          "STDERR: #{IO_CMD_ERR}"
    if EMAIL_ENABLED
      sendEmail("relayUpdate ABORTED on #{@cluster} at #{NOW}", "#{msg}\n\nFULL LOG:\n#{IO_TEE_FULL}")
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

  def writeTopology(topo)
    IO_CMD_OUT.clear
    IO_CMD_ERR.clear
    relativePath = "#{PATH_MOD}/#{RELATIVE_TOPOLOGY_PATH}"
    IO_TEE_STDOUT.puts "Topology relative path target is: #{relativePath}"

    absolutePath = File.expand_path(relativePath)
    IO_TEE_STDOUT.puts "Topology absolute path target is: #{absolutePath}"

    if File.exists?(absolutePath)
      IO_TEE_STDOUT.puts "Topology absolute path target exists"
      pathInfo = File.info(absolutePath)
      if pathInfo.directory?
        updateAbort("Target path #{absolutePath} is not a file, but a directory.")
      elsif pathInfo.symlink?
        updateAbort("Target path #{absolutePath} is not a regular file, but a symlink.")
      elsif pathInfo.file?
        IO_TEE_STDOUT.puts "Topology absolute path target is a pre-existing regular file"
        IO_TEE_STDOUT.puts "Creating a single backup file: #{absolutePath}-backup"
        begin
          FileUtils.cp(absolutePath, "#{absolutePath}-backup")
        rescue e
          IO_CMD_ERR.puts e.to_s
          updateAbort("Copying the existing explorer topology to path #{absolutePath}-backup FAILED.")
        end
      end
    end

    IO_TEE_STDOUT.puts "Writing the latest explorer topology config to: #{absolutePath}"
    begin
      File.write(absolutePath, topo)
    rescue e
      IO_CMD_ERR.puts e.to_s
      updateAbort("Writing the latest explorer topology to path #{absolutePath} FAILED.")
    end
  end

  def doUpdate

    network : Array(String)
    securityGroups : Array(String)
    elasticIps : Array(String)
    route53RecordSets : Array(String)
    lastSlot = 0
    nbBatches : Int32
    deployBatches : Array(Array(String))

    IO_TEE_OUT.puts "Script options selected:"
    IO_TEE_OUT.puts "allOpt = #{@allOpt}"
    IO_TEE_OUT.puts "edgeOpt = #{@edgeOpt}"
    IO_TEE_OUT.puts "relOpt = #{@relOpt}"
    IO_TEE_OUT.puts "minOpt = #{@minOpt}"

    IO_TEE_STDOUT.puts "Explorer GET URL topology (#{@explorerUrl}):"
    if (response = apiGet(@explorerUrl)).success?
      IO_TEE_STDOUT.puts "#{IO_CMD_OUT.to_s.split("\n").map { |i| "  " + i }.join("\n")}"
      IO_TEE_STDOUT.puts "Checking explorer topology for valid JSON"
      IO_CMD_OUT.clear
      IO_CMD_ERR.clear
      begin
        blob = JSON.parse(response.body.to_s)
        IO_TEE_STDOUT.puts "Explorer GET URL response body is valid JSON"
        if blob["Producers"]?
          IO_TEE_STDOUT.puts "Explorer latest topology contains #{blob["Producers"].size} producers"
          if blob["Producers"].size < @minOpt
            updateAbort("Explorer latest topology contains less than the required minimum number " \
                        "(#{@minOpt}) of producers: #{blob["Producers"].size}.")
          else
            IO_TEE_STDOUT.puts "Explorer latest topology meets or exceeds the minimum number of producers (#{@minOpt})"
          end
        else
          updateAbort("Explorer latest topology contains no \"Producers\" JSON.")
        end
        writeTopology(response.body.to_s)
      rescue
        IO_CMD_ERR.puts response.body.to_s
        updateAbort("Explorer GET URL body is NOT valid JSON.")
      end
    end

    if scriptCmdPrivate("nix eval --json '(__attrNames (import #{PATH_MOD}/deployments/cardano-aws.nix))'").success?
      network = Array(String).from_json(IO_CMD_OUT.to_s)
    else
      updateAbort("Unable to process the attribute names from the deployment.")
    end

    if scriptCmdPrivate("nix eval --json '(__attrNames (import #{PATH_MOD}/deployments/cardano-aws.nix).resources.ec2SecurityGroups)'").success?
      securityGroups = Array(String).from_json(IO_CMD_OUT.to_s)
    else
      updateAbort("Unable to process the ec2SecurityGroups attribute names from the deployment.")
    end

    if scriptCmdPrivate("nix eval --json '(__attrNames (import #{PATH_MOD}/deployments/cardano-aws.nix).resources.elasticIPs)'").success?
      elasticIps = Array(String).from_json(IO_CMD_OUT.to_s)
    else
      updateAbort("Unable to process the elasticIPs attribute names from the deployment.")
    end

    if scriptCmdPrivate("nix eval --json '(__attrNames (import #{PATH_MOD}/deployments/cardano-aws.nix).resources.route53RecordSets)'").success?
      route53RecordSets = Array(String).from_json(IO_CMD_OUT.to_s)
    else
      updateAbort("Unable to process the route53RecordSets attribute names from the deployment.")
    end

    if network
      coreNodes       = network.select { |n| /^c-[a-z]-[0-9]+$/ =~ n }
      bftNodes        = network.select { |n| /^bft-[a-z]-[0-9]+$/ =~ n }
      stkNodes        = network.select { |n| /^stk-[a-z]-[0-9]+-\w+$/ =~ n }
      edgeNodes       = network.select { |n| /^e-[a-z]-[0-9]+$/ =~ n }
      relayNodes      = network.select { |n| /^rel-[a-z]-[0-9]+$/ =~ n }
      faucetNodes     = network.select { |n| /^faucet/ =~ n }
      monitoringNodes = network.select { |n| /^monitoring/ =~ n }
      networkAttrs    = network - coreNodes - bftNodes - stkNodes - edgeNodes - relayNodes - faucetNodes - monitoringNodes

      if @allOpt
        targetNodes = edgeNodes + relayNodes
      else
        targetNodes = [] of String
        targetNodes.concat(edgeNodes) if @edgeOpt
        targetNodes.concat(relayNodes) if @relOpt
      end
    else
      updateAbort("The network array is empty")
    end

    #p! coreNodes
    #p! edgeNodes
    #p! faucetNodes
    #p! monitoringNodes
    #p! networkAttrs

    nbBatches = Math.max(targetNodes.size // MAX_NODES_PER_DEPLOY, MIN_DEPLOY_BATCHES)

    if scriptCmdPrivate("nix eval --json \"(((import ./nix {}).topology-lib.relaysBatchesOf #{nbBatches}))\"").success?
      deployBatches = Array(Array(String)).from_json(IO_CMD_OUT.to_s)
    else
      updateAbort("Unable to process the relays deploy batches from the deployment.")
    end

    if MOCK_ENABLED
      updateCmd = "echo \"MOCK UPDATING SECURITY GROUPS AND IPS: #{securityGroups.join(" ")}\n #{elasticIps.join(" ")}\""
    else
      IO_TEE_STDOUT.puts "Deploying security groups and elastic ips:\n#{securityGroups.join(" ")}\n#{elasticIps.join(" ")}"
      updateCmd = "nixops deploy --include #{elasticIps.join(" ")} #{securityGroups.join(" ")}"
    end
    if scriptCmdPrivate(updateCmd).success?
      IO_TEE_OUT.puts IO_CMD_OUT.to_s
      IO_TEE_OUT.puts IO_CMD_ERR.to_s
    else
      updateAbort("Failed to deploy the security groups updates (#{updateCmd})")
    end

    IO_TEE_STDOUT.puts "Deploying to target nodes:\n#{targetNodes}\n (#{targetNodes.size} nodes in #{nbBatches} batches)."

    deployBatches.each do |b|
      batchTargetNodes = b.select { |n| targetNodes.includes?(n) }
      if !batchTargetNodes.empty?
        if MOCK_ENABLED
          updateCmd = "echo \"MOCK UPDATING TOPOLOGY to target nodes #{batchTargetNodes.join(" ")}\""
        else
          updateCmd = "nixops deploy --include #{batchTargetNodes.join(" ")}"
        end

        IO_TEE_OUT.puts "Deploying new peer topology to target nodes: #{batchTargetNodes.join(" ")} (#{updateCmd})"
        if scriptCmdPrivate(updateCmd).success?
          IO_TEE_OUT.puts IO_CMD_OUT.to_s
          IO_TEE_OUT.puts IO_CMD_ERR.to_s
        else
          updateAbort("Failed to deploy the new peer topology to target nodes: #{batchTargetNodes.join(" ")} (#{updateCmd})")
        end
        sleep(10)
        batchTargetNodes.each do |n|
          IO_TEE_OUT.puts "Waiting for metrics to re-appear on target node: #{n}"
          if MOCK_ENABLED
            deployFinished = true
          else
            deployFinished = false
            prevSlot = 0
            i = 0
            while i < METRICS_WAIT_ITERATIONS
              if scriptCmdPrivate("nixops ssh #{n} -- 'curl -s #{n}:#{NODE_METRICS_PORT}/metrics | grep -oP \"cardano_node_ChainDB_metrics_slotNum_int \\K[0-9]+\"'").success?
                slot = IO_CMD_OUT.to_s
                IO_TEE_OUT.puts "Found slotNum_int metrics post topology update deploy on target node: #{n} at #{slot}"
                if (slot.to_i >= lastSlot)
                  lastSlot = slot.to_i
                  deployFinished = true
                  break
                else
                  IO_TEE_OUT.puts "... not yet synced.. sleeping #{METRICS_WAIT_INTERVAL} seconds ..."
                  if (slot.to_i > prevSlot)
                    # Only allow more wait if there is actual progress:
                    i = 0
                    prevSlot = slot.to_i
                  else
                    i = i + 1
                  end
                  sleep(METRICS_WAIT_INTERVAL)
                end
              else
                i = i + 1
                IO_TEE_OUT.puts "... sleeping #{METRICS_WAIT_INTERVAL} seconds ..."
                sleep(METRICS_WAIT_INTERVAL)
              end
            end
          end
          updateAbort("Failed to find returned slotNum metrics on target node: #{n}") unless deployFinished
          IO_TEE_OUT.puts "\n"
        end
      end
    end

    if MOCK_ENABLED
      updateCmd = "echo \"MOCK MONITORING UPDATE\""
    else
      IO_TEE_STDOUT.puts "Deploying monitoring"
      updateCmd = "nixops deploy --include monitoring"
    end
    if scriptCmdPrivate(updateCmd).success?
      IO_TEE_OUT.puts IO_CMD_OUT.to_s
      IO_TEE_OUT.puts IO_CMD_ERR.to_s
    else
      updateAbort("Failed to deploy monitoring updates (#{updateCmd})")
    end

    if MOCK_ENABLED
      updateCmd = "echo \"MOCK UPDATING DNS ENRIES: #{route53RecordSets.join(" ")}\""
    else
      IO_TEE_STDOUT.puts "Deploying route53 dns entries:\n#{route53RecordSets.join(" ")}"
      updateCmd = "nixops deploy --include #{route53RecordSets.join(" ")}"
    end
    if scriptCmdPrivate(updateCmd).success?
      IO_TEE_OUT.puts IO_CMD_OUT.to_s
      IO_TEE_OUT.puts IO_CMD_ERR.to_s
    else
      updateAbort("Failed to deploy route53 dns entries updates (#{updateCmd})")
    end

    IO_TEE_OUT.puts "Peer topology update and deployment on cluster #{@cluster} at #{NOW}, completed."
    if EMAIL_ENABLED
      sendEmail("relayUpdate SUCCESS on #{@cluster} at #{NOW}",
                "Peer topology update and deployment on cluster #{@cluster} at #{NOW}, completed.\n\n#{IO_TEE_FULL}")
    end
  end
end

proceed = false
allOpt = false
edgeOpt = false
relOpt = false
minOpt = MINIMUM_PRODUCERS
OptionParser.parse do |parser|
  parser.banner = "Usage: relay-update [arguments]"
  parser.on("-r", "--refresh", "Updates and deploys the latest explorer relay topology (required option)") { proceed = true }
  parser.on("-a", "--all", "Updates and deploys relay topology to all edges/relays") { allOpt = true }
  parser.on("--edge", "Updates and deploys relay topology to edge nodes (e-X-Y)") { edgeOpt = true }
  parser.on("--relay", "Updates and deploys relay topology to relay nodes (rel-X-Y)") { relOpt = true }
  parser.on("-m POSINT", "--minProd POSINT", "The minimum producers to allow deployment (default: #{MINIMUM_PRODUCERS})") { |posint| minOpt = posint.to_i }
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
  relayUpdate=RelayUpdate.new
  relayUpdate.allOpt = allOpt
  relayUpdate.edgeOpt = edgeOpt
  relayUpdate.relOpt = relOpt
  relayUpdate.minOpt = minOpt
  relayUpdate.doUpdate
end
exit 0
