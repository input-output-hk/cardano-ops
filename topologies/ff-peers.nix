# List of peers included in our relays topology config,
# evenly split across all IOHK FF relays.
# Pull-requests against this file will be merged and deployed once a day.
[
  {
    operator = "disassembler";
    addr = "prophet.samleathers.com";
    port = 3001;
    # valency = 1; (default)
  }
  {
    operator = "samcgill";
    addr = "relays.ddnsfree.com";
    port = 3002;
    valency = 2;
  },
]
