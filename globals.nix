self: super: {
  globals = {
    static = import ./static;

    domain = "";

    applicationMonitoringPortsFor = name: node: [];

    environment = "stagingshelleyshort";
  };
}
