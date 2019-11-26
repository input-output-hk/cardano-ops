{
  defaultBackends = [ "KatipBK" ];
  defaultScribes = [ [ "StdoutSK" "stdout" ] ];
  hasEKG = 12780;
  hasPrometheus = 12798;
  minSeverity = "Info";
  options = {
    cfokey = { value = "Release-1.0.0"; };
    mapBackends = {
      "cardano.node.metrics" = [ "EKGViewBK" ];
      "cardano.node.metrics.ChainDB" = [ "EKGViewBK" ];
    };
    mapSubtrace = {
      "#ekgview" =
        {
          contents = [
            [
              {
                contents = "cardano.epoch-validation.benchmark";
                tag = "Contains";
              }
              [
                {
                  contents = ".monoclock.basic.";
                  tag = "Contains";
                }
              ]
            ]
            [
              {
                contents = "cardano.epoch-validation.benchmark";
                tag = "Contains";
              }
              [
                {
                  contents = "diff.RTS.cpuNs.timed.";
                  tag = "Contains";
                }
              ]
            ]
            [
              {
                contents = "#ekgview.#aggregation.cardano.epoch-validation.benchmark";
                tag = "StartsWith";
              }
              [
                {
                  contents = "diff.RTS.gcNum.timed.";
                  tag = "Contains";
                }
              ]
            ]
          ];
          subtrace = "FilterTrace";
        };
      "#messagecounters.aggregation" = { subtrace = "NoTrace"; };
      "#messagecounters.ekgview" = { subtrace = "NoTrace"; };
      "#messagecounters.katip" = { subtrace = "NoTrace"; };
      "#messagecounters.monitoring" = { subtrace = "NoTrace"; };
      "#messagecounters.switchboard" = { subtrace = "NoTrace"; };
      "cardano.benchmark" = {
        contents = [ "GhcRtsStats" "MonotonicClock" "ProcessStats" "NetStats" "IOStats" ];
        subtrace = "ObservableTraceSelf";
      };
      "cardano.epoch-validation.utxo-stats" = { subtrace = "NoTrace"; };
    };
  };
  rotation = { rpKeepFilesNum = 10; rpLogLimitBytes = 5000000; rpMaxAgeHours = 24; };
  setupBackends = [ "KatipBK" "EKGViewBK" ];
  setupScribes = [
    {
      scFormat = "ScJson";
      scKind = "StdoutSK";
      scName = "stdout";
      scRotation = null;
    }
  ];
}
