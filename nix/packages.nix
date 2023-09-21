self: super: with self; {

  pp = v: __trace (__toJSON v) v;
  leftPad = number: width: lib.fixedWidthString width "0" (toString number);
  shiftList = n: list: lib.drop n list ++ (lib.take n list);

  getPublicIp = resources: nodes: nodeName:
    resources.elasticIPs."${nodeName}-ip".address or
    (let
      publicIp = nodes.${nodeName}.config.networking.publicIPv4;
    in
      if (nodes.${nodeName}.options.networking.publicIPv4.isDefined && publicIp != null) then publicIp
      else (builtins.trace "No public IP found for node: ${nodeName}" "")
    );
  getStaticRouteIp = resources: nodes: nodeName: resources.elasticIPs."${nodeName}-ip".address
    or (let
      publicIp = nodes.${nodeName}.config.networking.publicIPv4;
      privateIp = nodes.${nodeName}.config.networking.privateIPv4;
    in
      if (nodes.${nodeName}.options.networking.publicIPv4.isDefined && publicIp != null) then publicIp
      else if (nodes.${nodeName}.options.networking.privateIPv4.isDefined && privateIp != null) then privateIp
      else (builtins.trace "No suitable ip found for node: ${nodeName}" "")
    );

  getListenIp = node:
    let ip = node.config.networking.privateIPv4;
    in if (node.options.networking.privateIPv4.isDefined && ip != null) then ip else "0.0.0.0";

  # this function import all nix files of the given directory,
  # returned in a attribute set indexed by name (with .nix suffix removed)
  # Furthermore, if the imported file is a function with an opaque argument,
  # that argument is assumed to be pkgs and is applied.
  # This allows to easliy inject a lazy pkgs to functions that return modules:
  # using pkgs in modules arg as limitation; due to modules args being strictly evaluated
  # they cannot be used for shaping the module structure (like in imports), otherwise
  # "infinite recursions" occurs.
  # This can greatly improve nixops eval perf /memory usage
  # when pkgs is the same for all machines (common case).
  importWithPkgs = with lib; dir:
    mapAttrs' (n: v:
      let l = stringLength n;
        nix = import (dir + "/${n}");
      in nameValuePair
        (substring 0 (l - 4) n)
        (if (isFunction nix && functionArgs nix == {})
          then nix self
          else nix)
    ) (filterAttrs (n: v:
        let l = stringLength n;
        in v == "regular" && (substring (l - 4) l n) == ".nix")
        (builtins.readDir dir));

  inherit (callPackage ../pkgs/kes-rotation {}) kes-rotation;
  inherit (callPackage ../pkgs/node-update {}) node-update;
  inherit (callPackage ../pkgs/snapshot-states {}) snapshot-states;

  aws-affinity-indexes = runCommand "aws-affinity-indexes" {
    nativeBuildInputs = with self; [ csvkit jq ];
  } ''
    mkdir -p $out
    csvjson -d ";" -I --blanks -H ${sourcePaths.aws-datacenters}/output/countries.index | jq 'map( { (.a): .c } ) | add' \
      > $out/countries-index.json
    csvjson -d ";" -I --blanks -H ${sourcePaths.aws-datacenters}/output/usa.index | jq 'map( { (.b): .c } ) | add' \
      > $out/usa-index.json
    jq -s 'add' $out/countries-index.json $out/usa-index.json > $out/state-index.json
  '';

  topology-lib = import ./topology-lib.nix self;

  ##
  ## removeLegacyTracingOptions :: NodeConfig -> NodeConfig
  ##
  removeLegacyTracingOptions = cfg:
    builtins.removeAttrs cfg
    [
      "TraceAcceptPolicy"
      "TraceBackingStore"
      "TraceBlockchainTime"
      "TraceBlockFetchClient"
      "TraceBlockFetchDecisions"
      "TraceBlockFetchProtocol"
      "TraceBlockFetchProtocolSerialised"
      "TraceBlockFetchServer"
      "TraceChainDB"
      "TraceChainSyncClient"
      "TraceChainSyncBlockServer"
      "TraceChainSyncHeaderServer"
      "TraceChainSyncProtocol"
      "TraceConnectionManager"
      "TraceConnectionManagerCounters"
      "TraceConnectionManagerTransitions"
      "DebugPeerSelectionInitiator"
      "DebugPeerSelectionInitiatorResponder"
      "TraceDiffusionInitialization"
      "TraceDnsResolver"
      "TraceDnsSubscription"
      "TraceErrorPolicy"
      "TraceForge"
      "TraceForgeStateInfo"
      "TraceHandshake"
      "TraceIpSubscription"
      "TraceKeepAliveClient"
      "TraceLedgerPeers"
      "TraceLocalChainSyncProtocol"
      "TraceLocalConnectionManager"
      "TraceLocalErrorPolicy"
      "TraceLocalHandshake"
      "TraceLocalInboundGovernor"
      "TraceLocalRootPeers"
      "TraceLocalServer"
      "TraceLocalStateQueryProtocol"
      "TraceLocalTxMonitorProtocol"
      "TraceLocalTxSubmissionProtocol"
      "TraceLocalTxSubmissionServer"
      "TraceMempool"
      "TraceMux"
      "TraceLocalMux"
      "TracePeerSelection"
      "TracePeerSelectionCounters"
      "TracePeerSelectionActions"
      "TracePublicRootPeers"
      "TraceServer"
      "TraceInboundGovernor"
      "TraceInboundGovernorCounters"
      "TraceInboundGovernorTransitions"
      "TraceTxInbound"
      "TraceTxOutbound"
      "TraceTxSubmissionProtocol"
      "TraceTxSubmission2Protocol"
      "TracingVerbosity"
      "defaultBackends"
      "defaultScribes"
      "hasEKG"
      "hasPrometheus"
      "minSeverity"
      "options"
      "rotation"
      "setupBackends"
      "setupScribes"
    ];

  finaliseNodeConfig = withNewTracing: xs:
    if !withNewTracing then xs
    else removeLegacyTracingOptions xs //
         { UseTraceDispatcher = true;
           TraceOptions  = {
             "" =
               { severity = "Notice";
                 backends = [
                   "Stdout MachineFormat"
                   "EKGBackend"
                   "Forwarder"
                 ];
               };
             "BlockFetch.Client".severity = "Debug";
             "BlockFetch.Client.CompletedBlockFetch".maxFrequency = 0;
             "BlockFetch.Decision".severity = "Notice";
             "BlockFetch.Remote".severity = "Notice";
             "BlockFetch.Remote.Serialised".severity = "Notice";
             "BlockFetch.Server".severity = "Debug";
             "BlockchainTime".severity = "Notice";
             "ChainDB".severity = "Debug";
             "ChainDB.ReplayBlock.LedgerReplay".severity = "Notice";
             "ChainSync.Client".severity = "Debug";
             "ChainSync.Client.DownloadedHeader".maxFrequency = 0;
             "ChainSync.Local".severity = "Notice";
             "ChainSync.Remote".severity = "Notice";
             "ChainSync.Remote.Serialised".severity = "Notice";
             "ChainSync.ServerBlock".severity = "Notice";
             "ChainSync.ServerHeader".severity = "Debug";
             "Forge.Loop".severity = "Debug";
             "Forge.StateInfo".severity = "Debug";
             "Mempool".severity = "Debug";
             "Net".severity = "Notice";
             "Net.AcceptPolicy".severity = "Debug";
             "Net.ConnectionManager.Local".severity = "Debug";
             "Net.ConnectionManager.Remote".severity = "Debug";
             "Net.DNSResolver".severity = "Notice";
             "Net.ErrorPolicy.Local".severity = "Debug";
             "Net.ErrorPolicy.Remote".severity = "Debug";
             "Net.Handshake.Local".severity = "Debug";
             "Net.Handshake.Remote".severity = "Debug";
             "Net.InboundGovernor.Local".severity = "Debug";
             "Net.InboundGovernor.Remote".severity = "Debug";
             "Net.InboundGovernor.Transition".severity = "Debug";
             "Net.Mux.Local".severity = "Notice";
             "Net.Mux.Remote".severity = "Notice";
             "Net.PeerSelection.Actions".severity = "Debug";
             "Net.PeerSelection.Counters".severity = "Debug";
             "Net.PeerSelection.Initiator".severity = "Notice";
             "Net.PeerSelection.Responder".severity = "Notice";
             "Net.PeerSelection.Selection".severity = "Debug";
             "Net.Peers.Ledger".severity = "Debug";
             "Net.Peers.List".severity = "Notice";
             "Net.Peers.LocalRoot".severity = "Debug";
             "Net.Peers.PublicRoot".severity = "Debug";
             "Net.Server.Local".severity = "Debug";
             "Net.Server.Remote".severity = "Debug";
             "Net.Subscription.DNS".severity = "Debug";
             "Net.Subscription.IP".severity = "Debug";
             "NodeState".severity = "Notice";
             "Resources".severity = "Debug";
             "Shutdown".severity = "Notice";
             "Startup".severity = "Notice";
             "Startup.Common".severity = "Info";
             "Startup.DiffusionInit".severity = "Debug";
             "StateQueryServer".severity = "Notice";
             "TxSubmission.Local".severity = "Notice";
             "TxSubmission.LocalServer".severity = "Notice";
             "TxSubmission.MonitorClient".severity = "Notice";
             "TxSubmission.Remote".severity = "Notice";
             "TxSubmission.TxInbound".severity = "Debug";
             "TxSubmission.TxOutbound".severity = "Notice";
           #} // lib.optionalAttrs (xs."TraceBlockFetchProtocol" or false)
           #{
           # needed for the explorer node only; needs better wiring into config construction
             "BlockFetch.Remote.Receive.Block".severity = "Info";
           };
         };

  relayUpdateTimer =
    let
      writeIni = filename: cfg: writeTextFile {
        name = filename;
        text = lib.generators.toINI {} cfg;
        destination = "/${filename}";
      } + "/${filename}";

      runNodeUpdate = writeShellScript "run-node-update" ''
        set -eu -o pipefail
        cd ${globals.deploymentPath}
        mkdir -p relay-update-logs
        ${if globals ? relayUpdateHoursBeforeNextEpoch
          then ''nix-shell --run 'if [ $(./scripts/hours-until-next-epoch.sh) -le ${toString globals.relayUpdateHoursBeforeNextEpoch} ]; then [ -f refresh-done ] || node-update --refresh --relay ${globals.relayUpdateArgs} &> relay-update-logs/relay-update-$(date -u +"%F_%H-%M-%S").log && touch refresh-done; else rm -f refresh-done; fi' ''
          else ''nix-shell --run 'node-update --refresh --relay ${globals.relayUpdateArgs}' &> relay-update-logs/relay-update-$(date -u +"%F_%H-%M-%S").log''
        }
      '';

      service = writeIni "relay-update-${globals.deploymentName}.service" {
        Unit = {};
        Service = {
           ExecStart = "${runNodeUpdate}";
           Environment = "PATH=${lib.makeBinPath [ nix coreutils git gnutar ]}";
        };
      };

      timer = writeIni "relay-update-${globals.deploymentName}.timer" {
        Unit = {};
        Timer = {
          OnCalendar = if (globals ? relayUpdateHoursBeforeNextEpoch)
            then "hourly"
            else globals.relayUpdatePeriod;
          Unit = "relay-update-${globals.deploymentName}.service";
        };
        Install = {
          WantedBy = "default.target";
        };
      };

    in writeShellScriptBin "relay-update-timer" ''
      set -eu -o pipefail
      cd ${globals.deploymentPath}
      MODE=''${1:-""}
      if [ "$MODE" = "--install" ]; then
        nix-store --indirect --add-root .nix-gc-roots/relay-update-service --realise ${service}
        nix-store --indirect --add-root .nix-gc-roots/relay-update-timer  --realise ${timer}
        mkdir -p ~/.config/systemd/user/
        ln -sf ${service} ~/.config/systemd/user/
        ln -sf ${timer} ~/.config/systemd/user/
        systemctl --user enable relay-update-${globals.deploymentName}.timer
        systemctl --user start relay-update-${globals.deploymentName}.timer
        systemctl --user status relay-update-${globals.deploymentName}.timer
      elif [ "$MODE" = "--uninstall" ]; then
        rm -f .nix-gc-roots/relay-update-*
        systemctl --user disable relay-update-${globals.deploymentName}.timer
        systemctl --user disable relay-update-${globals.deploymentName}.service
      else
        echo "usage: relay-update-timer --(un)install"
        echo ""
        echo "after install, check status with:"
        echo "  systemctl --user status relay-update-${globals.deploymentName}.timer"
        echo "  systemctl --user status relay-update-${globals.deploymentName}.service"
      fi
    '';


  snapshotStatesTimer =
    let
      writeIni = filename: cfg: writeTextFile {
        name = filename;
        text = lib.generators.toINI {} cfg;
        destination = "/${filename}";
      } + "/${filename}";

      runSnapshotStates = writeShellScript "run-snapshot-states" ''
        set -eu -o pipefail
        cd ${globals.deploymentPath}
        mkdir -p state-snapshots/logs
        nix-shell --run 'if [ $(./scripts/hours-since-last-epoch.sh) -le 1 ]; then [ -f state-snapshots/upload-done ] ||  snapshot-states ${globals.snapshotStatesArgs} &> state-snapshots/logs/snapshot-states-$(date -u +"%F_%H-%M-%S").log && touch state-snapshots/upload-done; else rm -f state-snapshots/upload-done; fi'
      '';

      service = writeIni "snapshot-states-${globals.deploymentName}.service" {
        Unit = {};
        Service = {
           ExecStart = "${runSnapshotStates}";
           Environment = "PATH=${lib.makeBinPath [ nix coreutils git gnutar ]}";
        };
      };

      timer = writeIni "snapshot-states-${globals.deploymentName}.timer" {
        Unit = {};
        Timer = {
          OnCalendar = "hourly";
          Unit = "snapshot-states-${globals.deploymentName}.service";
        };
        Install = {
          WantedBy = "default.target";
        };
      };

    in writeShellScriptBin "snapshot-states-timer" ''
      set -eu -o pipefail
      cd ${globals.deploymentPath}
      MODE=''${1:-""}
      if [ "$MODE" = "--install" ]; then
        nix-store --indirect --add-root .nix-gc-roots/snapshot-states-service --realise ${service}
        nix-store --indirect --add-root .nix-gc-roots/snapshot-states-timer  --realise ${timer}
        mkdir -p ~/.config/systemd/user/
        ln -sf ${service} ~/.config/systemd/user/
        ln -sf ${timer} ~/.config/systemd/user/
        systemctl --user enable snapshot-states-${globals.deploymentName}.timer
        systemctl --user start snapshot-states-${globals.deploymentName}.timer
        systemctl --user status snapshot-states-${globals.deploymentName}.timer
      elif [ "$MODE" = "--uninstall" ]; then
        rm -f .nix-gc-roots/snapshot-states-*
        systemctl --user disable snapshot-states-${globals.deploymentName}.timer
        systemctl --user disable snapshot-states-${globals.deploymentName}.service
      else
        echo "usage: snapshot-states-timer --(un)install"
        echo ""
        echo "after install, check status with:"
        echo "  systemctl --user status snapshot-states-${globals.deploymentName}.timer"
        echo "  systemctl --user status snapshot-states-${globals.deploymentName}.service"
      fi
    '';

  s3cmd = (super.s3cmd.overrideAttrs (old: {
    makeWrapperArgs = (old.makeWrapperArgs or []) ++ ["--unset" "PYTHONPATH"];
  }));

  flake-compat = import sourcePaths.flake-compat;

  inherit ((flake-compat {
    src = sourcePaths.nix;
    override-inputs = {
      nixpkgs = (flake-compat { src = sourcePaths.nixpkgs; inherit system; }).defaultNix;
    };
    inherit system;
  }).defaultNix.packages.${system}) nix;

  nixUnstable = nix;
  nixFlake = nix;
}
