#!/usr/bin/env nix-shell
#!nix-shell -i crystal -p crystal -I nixpkgs=/nix/store/3b6p06fazphgdzwkf9g75l0pwsm5dnj8-source

# Crystal v0.34 source path for `-I nixpkgs=` is from:
#   nix-instantiate --eval -E '((import ../nix/sources.nix).nixpkgs-crystal).outPath'

# This script can be used in cron.  For example:
# 00 16 * * * cd ~/$CLUSTER && nix-shell --run 'node-update -r --all' -I nixpkgs="$(nix eval '(import ./nix {}).path')" \
#   &> db-sync-snapshot/logs/db-sync-snapshot-$(date -u +"\%F_\%H-\%M-\%S").log

require "json"
require "email"
require "option_parser"
require "http/client"
require "file_utils"

PATH_MOD                = ENV.fetch("PATH_MOD", ".")

EMAIL_FROM              = "devops@ci.iohkdev.io"
NOW                     = Time.utc.to_s("%F %R %z")

IO_CMD_OUT    = IO::Memory.new
IO_CMD_ERR    = IO::Memory.new
IO_TEE_FULL   = IO::Memory.new
IO_TEE_OUT    = IO::MultiWriter.new(IO_CMD_OUT, IO_TEE_FULL, STDOUT)
IO_TEE_ERR    = IO::MultiWriter.new(IO_CMD_ERR, IO_TEE_FULL, STDERR)
IO_TEE_STDOUT = IO::MultiWriter.new(IO_TEE_FULL, STDOUT)
IO_NO_TEE_OUT = IO::MultiWriter.new(IO_CMD_OUT, STDOUT)
IO_NO_TEE_ERR = IO::MultiWriter.new(IO_CMD_ERR, STDERR)

class DbSyncSnapshot

  @sesUsername : String
  @sesSecret : String
  @cluster : String

  def initialize(@bucket : String)

    if (@emailOpt != "")
      if runCmdSecret("nix-instantiate --eval -E --json '(import #{PATH_MOD}/static/ses.nix).sesSmtp.username'").success?
        @sesUsername = IO_CMD_OUT.to_s.strip('"')
      else
        abort("Unable to process the ses username.")
      end

      if runCmdSecret("nix-instantiate --eval -E --json '(import #{PATH_MOD}/static/ses.nix).sesSmtp.secret'").success?
        @sesSecret = IO_CMD_OUT.to_s.strip('"')
      else
        abort("Unable to process the ses secret.")
      end
    else
      @sesUsername = ""
      @sesSecret = ""
    end

    if runCmdVerbose("nix-instantiate --eval -E --json '(import #{PATH_MOD}/nix {}).globals.environmentName'").success?
      @cluster = IO_CMD_OUT.to_s.strip('"')
    else
      updateAbort("Unable to process the environment name from the globals file.")
    end

  end

  def runCmd(cmd) : Process::Status
    if (@noSensitiveOpt)
      runCmdSensitive(cmd)
    else
      runCmdVerbose(cmd)
    end
  end

  def runCmd(cmd, output, error)
    IO_CMD_OUT.clear
    IO_CMD_ERR.clear
    IO_TEE_STDOUT.puts "+ #{cmd}"
    Process.run(cmd, output: output, error: error, shell: true)
  end

  def runCmdVerbose(cmd): Process::Status
    result = runCmd(cmd, IO_TEE_OUT, IO_TEE_ERR)
    IO_TEE_STDOUT.puts "\n"
    result
  end

  def runCmdSensitive(cmd) : Process::Status
    runCmd(cmd, IO_NO_TEE_OUT, IO_NO_TEE_ERR)
  end

  def runCmdSecret(cmd) : Process::Status
    runCmd(cmd, IO_CMD_OUT, IO_NO_TEE_ERR)
  end

  def updateAbort(msg)
    msg = "cardano-db-sync snapshot upload aborted on #{@cluster} at #{NOW}:\n" \
          "MESSAGE: #{msg}\n" \
          "STDOUT: #{IO_CMD_OUT}\n" \
          "STDERR: #{IO_CMD_ERR}"
    if (@emailOpt != "")
      sendEmail("cardano-db-sync snapshot upload ABORTED on #{@cluster} at #{NOW}", "#{msg}\n\nFULL LOG:\n#{IO_TEE_FULL}")
    else
      IO_TEE_OUT.puts msg
    end
    exit(1)
  end

  def sendEmail(subject, body)
    email = EMail::Message.new
    email.from(EMAIL_FROM)
    email.to(@emailOpt)
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

  def retrieveSnapshot()
    if !runCmdVerbose("mkdir -p db-sync-snapshot "\
      "&& nixops scp --from explorer /var/lib/cexplorer/db-sync-snapshot*.tgz ./db-sync-snapshot/ "\
      "&& nixops ssh explorer 'rm /var/lib/cexplorer/db-sync-snapshot*.tgz'").success?
      updateAbort("Could not retrieve db-sync snasphot from explorer.")
    end
  end

  def doUploadSnapshot

    IO_TEE_OUT.puts "Script options selected:"
    IO_TEE_OUT.puts "bucket = #{@bucket}"

    retrieveSnapshot()

    if runCmdVerbose("nix eval --json '(__attrNames (import #{PATH_MOD}/deployments/cardano-aws.nix))'").success?
      network = Array(String).from_json(IO_CMD_OUT.to_s)
    else
      updateAbort("Unable to process the attribute names from the deployment.")
    end

    if runCmdVerbose("nix eval --json '(__attrNames (import #{PATH_MOD}/deployments/cardano-aws.nix).resources.ec2SecurityGroups)'").success?
      securityGroups = Array(String).from_json(IO_CMD_OUT.to_s)
    else
      updateAbort("Unable to process the ec2SecurityGroups attribute names from the deployment.")
    end

    if runCmdVerbose("nix eval --json '(__attrNames (import #{PATH_MOD}/deployments/cardano-aws.nix).resources.elasticIPs)'").success?
      elasticIps = Array(String).from_json(IO_CMD_OUT.to_s)
    else
      updateAbort("Unable to process the elasticIPs attribute names from the deployment.")
    end

    if runCmdVerbose("nix eval --json '(__attrNames (import #{PATH_MOD}/deployments/cardano-aws.nix).resources.route53RecordSets)'").success?
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
        targetNodes = @deployOnlyOpt.flatten
        targetNodes.concat(edgeNodes) if @edgeOpt
        targetNodes.concat(relayNodes) if @relOpt
      end
      # Exclude the source node from target nodes, since it supposed to be up-to-date already
      targetNodes.delete(@snapshotDbOpt)
    else
      updateAbort("The network array is empty")
    end

    #p! coreNodes
    #p! edgeNodes
    #p! faucetNodes
    #p! monitoringNodes
    #p! networkAttrs

    if (@deployOnlyOpt.empty?)

      if runCmdVerbose("nix eval --json \"(((import ./nix {}).topology-lib.nbBatches #{@maxNodesOpt}))\"").success?
        nbBatchWithSizeConstraint = IO_CMD_OUT.to_s.to_i
      else
        updateAbort("Unable to process the min number of batches.")
      end

      nbBatches = Math.max(nbBatchWithSizeConstraint, @minBatchesOpt)

      if runCmdVerbose("nix eval --json \"(((import ./nix {}).topology-lib.genRelayBatches #{nbBatches}))\"").success?
        deployBatches = Array(Array(String)).from_json(IO_CMD_OUT.to_s)
      else
        updateAbort("Unable to process the relays deploy batches from the deployment.")
      end
    else
      deployBatches = @deployOnlyOpt
      nbBatches = deployBatches.size
    end

    if @mockOpt
      updateCmd = "echo \"MOCK UPDATING SECURITY GROUPS AND IPS: #{securityGroups.join(" ")}\n #{elasticIps.join(" ")}\""
    else
      IO_TEE_STDOUT.puts "Deploying security groups and elastic ips:\n#{securityGroups.join(" ")}\n#{elasticIps.join(" ")}"
      updateCmd = "nixops deploy #{@extraDeployFlagsOpt} --include #{elasticIps.join(" ")} #{securityGroups.join(" ")}"
    end
    if !runCmd(updateCmd).success?
      updateAbort("Failed to deploy the security groups updates")
    end

    IO_TEE_STDOUT.puts "Deploying to target nodes:\n#{targetNodes}\n (#{targetNodes.size} nodes in #{nbBatches} batches)."

    deployBatches.each do |b|
      batchTargetNodes = b.select { |n| targetNodes.includes?(n) }
      if !batchTargetNodes.empty?

        if (@snapshotDbOpt != "" && !@mockOpt)
          snapshot = takeDbSnapshot(@snapshotDbOpt)
          batchTargetNodes.each do |n|
            if !runCmdVerbose("nixops scp --to #{n} #{snapshot} /var/lib/cardano-node/db-restore.tar.gz").success?
              updateAbort("Could not upload #{snapshot} to #{n}.")
            end
          end
        end

        if @mockOpt
          updateCmd = "echo \"MOCK UPDATING TOPOLOGY to target nodes #{batchTargetNodes.join(" ")}\""
        else
          updateCmd = "nixops deploy #{@extraDeployFlagsOpt} --include #{batchTargetNodes.join(" ")}"
        end

        IO_TEE_OUT.puts "Deploying new peer topology to target nodes: #{batchTargetNodes.join(" ")}"
        if !runCmd(updateCmd).success?
          updateAbort("Failed to deploy the new peer topology to target nodes: #{batchTargetNodes.join(" ")} (#{updateCmd})")
        end
        if !@mockOpt
          sleep(5)
        end
        batchTargetNodes.each do |n|
          IO_TEE_OUT.puts "Waiting for metrics to re-appear on target node: #{n}"
          if @mockOpt
            deployFinished = true
          else
            deployFinished = false
            prevSlot = 0
            i = 0
            while i < METRICS_WAIT_ITERATIONS
              if runCmdVerbose("nixops ssh #{n} -- 'curl -s #{n}:#{NODE_METRICS_PORT}/metrics | grep -oP \"cardano_node_metrics_slotNum_int \\K[0-9]+\"'").success?
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

    if (@deployOnlyOpt.empty?)
      if @mockOpt
        updateCmd = "echo \"MOCK MONITORING UPDATE\""
      else
        IO_TEE_STDOUT.puts "Deploying monitoring"
        updateCmd = "nixops deploy #{@extraDeployFlagsOpt} --include monitoring"
      end
      if !runCmd(updateCmd).success?
        updateAbort("Failed to deploy monitoring updates")
      end
    end

    if @mockOpt
      updateCmd = "echo \"MOCK UPDATING DNS ENRIES: #{route53RecordSets.join(" ")}\""
    else
      IO_TEE_STDOUT.puts "Deploying route53 dns entries:\n#{route53RecordSets.join(" ")}"
      updateCmd = "nixops deploy #{@extraDeployFlagsOpt} --include #{route53RecordSets.join(" ")}"
    end
    if !runCmd(updateCmd).success?
      updateAbort("Failed to deploy route53 dns entries updates")
    end

    IO_TEE_OUT.puts "Peer topology update and deployment on cluster #{@cluster} at #{NOW}, completed."
    if (@emailOpt != "")
      sendEmail("relayUpdate SUCCESS on #{@cluster} at #{NOW}",
                "Peer topology update and deployment on cluster #{@cluster} at #{NOW}, completed.\n\n#{IO_TEE_FULL}")
    end
  end
end

refresh = false
allOpt = false
edgeOpt = false
relOpt = false
extraDeployFlagsOpt = ""
minOpt = MINIMUM_PRODUCERS
maxNodesOpt = MAX_NODES_PER_DEPLOY
minBatchesOpt = MIN_DEPLOY_BATCHES
emailOpt = ""
noSensitiveOpt = false
deployOnlyOpt = Array(Array(String)).new
oneByOneOpt = false
snapshotDbOpt = ""
mockOpt = false
OptionParser.parse do |parser|
  parser.banner = "Usage: node-update [arguments]"
  parser.on("-r", "--refresh", "Updates and deploys the latest explorer relay topology (required option)") { refresh = true }
  parser.on("-a", "--all", "Updates and deploys relay topology to all edges/relays") { allOpt = true }
  parser.on("-t", "--test", "Test update (don't deploy anything)") { mockOpt = true }
  parser.on("--edge", "Updates and deploys relay topology to edge nodes (e-X-Y)") { edgeOpt = true }
  parser.on("--relay", "Updates and deploys relay topology to relay nodes (rel-X-Y)") { relOpt = true }
  parser.on("--extra-flags EXTRAFLAG", "Extra flags to pass to nixops deploy") { |extraDeployFlags| extraDeployFlagsOpt = extraDeployFlags }
  parser.on("-m POSINT", "--minProducers POSINT", "The minimum third-party producers to allow deployment (default: #{minOpt})") { |posint| minOpt = posint.to_i }
  parser.on("-n POSINT", "--maxNodes POSINT", "The maximal number of nodes that will be simultaneously deployed (default: #{maxNodesOpt})") { |posint| maxNodesOpt = posint.to_i }
  parser.on("-b POSINT", "--minBatches POSINT", "The minimal number of deployment batches (default: #{minBatchesOpt})") { |posint| minBatchesOpt = posint.to_i }
  parser.on("-e EMAIL", "--email EMAIL", "Send email to given address on script completion") { |email| emailOpt = email }
  parser.on("-s", "--no-sensitive", "Email will no include sensitive information") { noSensitiveOpt = true }
  parser.on("-d NODE", "--deploy-only NODES", "Deploy only the given node") { |deployOnly| deployOnlyOpt = [deployOnly.split(" ")] }
  parser.on("-o", "--one-by-one", "Deploy the nodes specified one by one") { |oneByOne| oneByOneOpt = oneByOne }
  parser.on("-z NODE", "--snapshot-db NODE", "Snapshot and retrieve the state db of a given node, and use it for deployment") { |snapshotDb| snapshotDbOpt = snapshotDb }

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

if oneByOneOpt
  deployOnlyOpt = deployOnlyOpt[0].map { |n| [n] }
end

relayUpdate = RelayUpdate.new refresh: refresh, allOpt: allOpt, edgeOpt: edgeOpt, relOpt: relOpt, extraDeployFlagsOpt: extraDeployFlagsOpt, minOpt: minOpt,
    maxNodesOpt: maxNodesOpt, minBatchesOpt: minBatchesOpt, emailOpt: emailOpt, noSensitiveOpt: noSensitiveOpt, mockOpt: mockOpt,
    deployOnlyOpt: deployOnlyOpt, snapshotDbOpt: snapshotDbOpt

if (refresh || !deployOnlyOpt.empty?)
  relayUpdate.doUpdate
elsif (snapshotDbOpt != "")
  relayUpdate.takeDbSnapshot(snapshotDbOpt)
end

exit 0
