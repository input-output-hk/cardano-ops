#!/usr/bin/env nix-shell
#!nix-shell -i crystal -p crystal -I nixpkgs=/nix/store/3b6p06fazphgdzwkf9g75l0pwsm5dnj8-source

# Crystal v0.34 source path for `-I nixpkgs=` is from:
#   nix-instantiate --eval -E '((import ../nix/sources.nix).nixpkgs-crystal).outPath'

# This script can be used in cron.  For example:
# 00 16 * * * cd ~/$CLUSTER && nix-shell --run 'node-update -r --all' -I nixpkgs="$(nix eval '(import ./nix {}).path')" \
#   &> snapshot-states/logs/snapshot-states-$(date -u +"\%F_\%H-\%M-\%S").log

require "json"
require "email"
require "option_parser"
require "http/client"
require "file_utils"

PATH_MOD                = ENV.fetch("PATH_MOD", ".")

EMAIL_FROM              = "devops@ci.iohkdev.io"
NOW                     = Time.utc.to_s("%F %R %z")

SNAPSHOTS_WORK_DIR       = "./state-snapshots"

IO_CMD_OUT    = IO::Memory.new
IO_CMD_ERR    = IO::Memory.new
IO_TEE_FULL   = IO::Memory.new
IO_TEE_OUT    = IO::MultiWriter.new(IO_CMD_OUT, IO_TEE_FULL, STDOUT)
IO_TEE_ERR    = IO::MultiWriter.new(IO_CMD_ERR, IO_TEE_FULL, STDERR)
IO_TEE_STDOUT = IO::MultiWriter.new(IO_TEE_FULL, STDOUT)
IO_NO_TEE_OUT = IO::MultiWriter.new(IO_CMD_OUT, STDOUT)
IO_NO_TEE_ERR = IO::MultiWriter.new(IO_CMD_ERR, STDERR)

class SnapshotStates

  @sesUsername : String
  @sesSecret : String
  @cluster : String
  @s3Bucket : String
  @emails : Array(String)

  def initialize(@emailOpt : String)

    if (@emailOpt != "")
      @emails = @emailOpt.split(',')
      if runCmdSecret("nix-instantiate --eval -E --json '(import #{PATH_MOD}/static/ses.nix).sesSmtp.username'").success?
        @sesUsername = IO_CMD_OUT.to_s.rstrip.strip('"')
      else
        abort("Unable to process the ses username.")
      end

      if runCmdSecret("nix-instantiate --eval -E --json '(import #{PATH_MOD}/static/ses.nix).sesSmtp.secret'").success?
        @sesSecret = IO_CMD_OUT.to_s.rstrip.strip('"')
      else
        abort("Unable to process the ses secret.")
      end
    else
      @emails = [] of String
      @sesUsername = ""
      @sesSecret = ""
    end

    if runCmdVerbose("nix-instantiate --eval -E --json '(import #{PATH_MOD}/nix {}).globals.environmentName'").success?
      @cluster = IO_CMD_OUT.to_s.rstrip.strip('"')
    else
      updateAbort("Unable to process the environment name from the globals file.")
    end

    if runCmdVerbose("nix-instantiate --eval -E --json '(import #{PATH_MOD}/nix {}).globals.snapshotStatesS3Bucket'").success?
      @s3Bucket = IO_CMD_OUT.to_s.rstrip.strip('"')
    else
      updateAbort("Unable to process the s3 bucket name name from the globals file (`snapshotStatesS3Bucket` attribute).")
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
    msg = "Cardano-db-sync snapshot upload aborted on #{@cluster} at #{NOW}:\n" \
          "MESSAGE: #{msg}\n" \
          "STDOUT: #{IO_CMD_OUT}\n" \
          "STDERR: #{IO_CMD_ERR}"
    if (@emailOpt != "")
      sendEmail("Cardano-db-sync snapshot upload ABORTED on #{@cluster} at #{NOW}", "#{msg}\n\nFULL LOG:\n#{IO_TEE_FULL}")
    else
      IO_TEE_OUT.puts msg
    end
    exit(1)
  end

  def sendEmail(subject, body)
    config = EMail::Client::Config.new("email-smtp.us-east-1.amazonaws.com", 25)
    config.use_tls(EMail::Client::TLSMode::STARTTLS)
    config.tls_context
    config.tls_context.add_options(OpenSSL::SSL::Options::NO_SSL_V2 | OpenSSL::SSL::Options::NO_SSL_V3 | OpenSSL::SSL::Options::NO_TLS_V1 | OpenSSL::SSL::Options::NO_TLS_V1_1)
    config.use_auth("#{@sesUsername}", "#{@sesSecret}")
    client = EMail::Client.new(config)
    client.start do
      @emails.each do |rcpt|
        email = EMail::Message.new
        email.from(EMAIL_FROM)
        email.to(rcpt)
        email.subject(subject)
        email.message(body)
        send(email)
      end
    end
  end

  def retrieveNodeStateSnapshot()

    if runCmdVerbose("nixops ssh snapshots 'systemctl stop cardano-node && cd /var/lib/cardano-node && tar czf db-#{@cluster}.tar.gz db-#{@cluster}'").success?
      if !runCmdVerbose("mkdir -p #{SNAPSHOTS_WORK_DIR} "\
        "&& nixops scp --from snapshots /var/lib/cardano-node/db-#{@cluster}.tar.gz #{SNAPSHOTS_WORK_DIR}/").success?
        updateAbort("Could not retrieve cardano-node state snasphot from snapshots.")
      end
    else
      updateAbort("Unable to find the snapshot file in snapshots /var/lib/cardano-node directory.")
    end
  end

  def retrieveNodeStateUpgradeSnapshot()

    if runCmdVerbose("nixops ssh snapshots 'systemctl stop cardano-node && cd /var/lib/cardano-node && find db-#{@cluster}/immutable/ -maxdepth 1 -type f | sort | tail -n 30 | xargs tar czf db-#{@cluster}-upgrade.tar.gz db-#{@cluster}/clean db-#{@cluster}/protocolMagicId db-#{@cluster}/volatile db-#{@cluster}/ledger'").success?
      if !runCmdVerbose("mkdir -p #{SNAPSHOTS_WORK_DIR} "\
        "&& nixops scp --from snapshots /var/lib/cardano-node/db-#{@cluster}-upgrade.tar.gz #{SNAPSHOTS_WORK_DIR}/").success?
        updateAbort("Could not retrieve cardano-node state upgrade snasphot from snapshots.")
      end
    else
      updateAbort("Unable to find the upgrade snapshot file in snapshots /var/lib/cardano-node directory.")
    end
  end

  def retrieveDbSyncSnapshot()

    if runCmdVerbose("nixops ssh snapshots 'systemctl stop cardano-db-sync && systemctl start cardano-node && systemctl start cardano-db-sync && cd /var/lib/cexplorer && ls -tr db-sync-snapshot*.tgz | tail -n 1'").success?
      snapshotFile = IO_CMD_OUT.to_s.chomp

      if !runCmdVerbose("mkdir -p #{SNAPSHOTS_WORK_DIR} "\
        "&& nixops scp --from snapshots /var/lib/cexplorer/#{snapshotFile} #{SNAPSHOTS_WORK_DIR}/").success?
        updateAbort("Could not retrieve db-sync snasphot from snapshots.")
      end
      snapshotFile
    else
      updateAbort("Unable to find a snapshot file in snapshots /var/lib/cexplorer directory.")
    end
  end

  def uploadDbSyncSnapshot(snapshotFile)
    matchSchemaVersion = /-schema-(\d+(.\d+)*)-/.match(snapshotFile)
    if matchSchemaVersion == nil
      updateAbort("Could not deduce db-sync major version from snapshot file name: #{snapshotFile}")
    else
      schemaVersion = matchSchemaVersion.try &.[1]
      if !runCmdVerbose("./scripts/upload-with-checksum.sh #{SNAPSHOTS_WORK_DIR}/#{snapshotFile} #{@s3Bucket} cardano-db-sync/#{schemaVersion}").success?
        updateAbort("Error while upload db-sync snasphot.")
      end
      uploadLog = IO_CMD_OUT.to_s
      runCmdVerbose("rm -f #{SNAPSHOTS_WORK_DIR}/#{snapshotFile}*")
      uploadLog
    end
  end

  def uploadNodeStateSnapshot()
    if !runCmdVerbose("./scripts/upload-with-checksum.sh #{SNAPSHOTS_WORK_DIR}/db-#{@cluster}.tar.gz #{@s3Bucket} cardano-node-state").success?
      updateAbort("Error while upload db-sync snasphot.")
    end
    uploadLog = IO_CMD_OUT.to_s
    runCmdVerbose("rm -f #{SNAPSHOTS_WORK_DIR}/db-#{@cluster}.tar.gz*")
    uploadLog
  end

  def uploadNodeStateUpgradeSnapshot()
    if !runCmdVerbose("./scripts/upload-with-checksum.sh #{SNAPSHOTS_WORK_DIR}/db-#{@cluster}-upgrade.tar.gz #{@s3Bucket} cardano-node-state").success?
      updateAbort("Error while upload db-sync snasphot.")
    end
    uploadLog = IO_CMD_OUT.to_s
    runCmdVerbose("rm -f #{SNAPSHOTS_WORK_DIR}/db-#{@cluster}-upgrade.tar.gz*")
    uploadLog
  end

  def run()

    IO_TEE_OUT.puts "Script options selected:"
    IO_TEE_OUT.puts "s3Bucket = #{@s3Bucket}"
    IO_TEE_OUT.puts "emailOpt = #{@emailOpt}"

    retrieveNodeStateUpgradeSnapshot()
    retrieveNodeStateSnapshot()
    snapshotFile = retrieveDbSyncSnapshot()
    uploadNodeStateSnapshot()
    uploadNodeStateUpgradeSnapshot()


    uploadLog = uploadDbSyncSnapshot(snapshotFile)


    IO_TEE_OUT.puts "Cardano-db-sync snapshot upload on cluster #{@cluster} at #{NOW}, completed."
    if (@emailOpt != "")
      sendEmail("Cardano-db-sync snapshot upload on cluster #{@cluster} at #{NOW}, completed.", uploadLog)
    end
  end
end

emailOpt = ""
OptionParser.parse do |parser|
  parser.banner = "Usage: snapshot-states [arguments]"
  parser.on("-e EMAIL", "--email EMAIL", "Send email(s) to given address(es) (comma separated) on script completion") { |email| emailOpt = email }

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

snapshotStates = SnapshotStates.new(emailOpt: emailOpt)

snapshotStates.run

exit 0
