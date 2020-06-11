# List of peers included in our relays topology config,
# evenly split across all IOHK FF relays.
# Pull-requests against this file will be merged and deployed once a day.
[
  {
    operator = "disassembler";
    addr = "prophet.samleathers.com";
    port = 3001;
  }
    {
    operator = "planetstake";
    addr = "stake-relay1.planetstake.com";
    port = 3001;
  }
  {
    operator = "planetstake";
    addr = "stake-relay2.planetstake.com";
    port = 3002;
  }
  {
    operator = "planetstake";
    addr = "stake-relay3.planetstake.com";
    port = 3003;
  }
]
