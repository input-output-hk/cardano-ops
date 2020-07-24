# Cardano benchmarking infrastructure

### Contents

1.  *Bird's eye overview*
2.  *Quick action -- running a benchmark without much ado*
3.  *Conceptual overview*
4.  *Benchmarking environment operation notes*
5.  *Parametrisation – source pins and and benchmarking profiles*
6.  *Deployment state handling*
7.  *The benchmarking process*
8.  *The capture process*
9.  *Benchmark results*

### Bird's eye overview

The benchmarking infrastructure consists of the following components:

  - The `cardano-benchmarking` repository, which contains:
    
      - log analysis scripts, in the `scripts/` subdirectory
      - the `cardano-tx-generator`, that generates Tx load on arbitrary
        nodes,
      - a NixOS service definition for the generator, in
        `nix/nixos/tx-generator-service.nix`

  - The `cardano-ops` repository, with:
    
      - the general cluster deployment infrastructure,
      - a specific, benchmarking-oriented deployment type, defined in
        `globals-bench-txgen-simple.nix`,
      - the `bench` script, that automates benchmark runs.

  - Resources on the development deployer, available under the `dev`
    user:
    
      - A number of cluster deployments, that have `cardano-ops`
        checkouts & benchmarking configuration set up in each of them,
        in the form of `benchmarking-cluster-params.json` files. These
        benchmark clusters are controlled by the `bench` tool from the
        benchmarking screen session.
        
        The clusters currently include:
        
          - `bench-dist-0`
          - `bench-dist-1`
          - `bench-dist-2`
          - `bench-dist-3`
    
      - Benchmark result storages:
        
          - `bench-results`
          - `bench-results-bad`, for results that failed validation,
          - `bench-results-old`, for legacy data.

<!-- end list -->

1.  The `bench` tool
    
    Benchmarking clusters are controlled using the `bench` tool, which
    is equivalent to running `./bench/bench.sh` in the current
    development checkout.
    
    The tool automates a significant part of the benchmarking workflow:
    
      - definition of multiple benchmarking profiles
      - genesis handling
      - deploying the cluster
      - running the benchmark profiles
      - collecting & doing analysis (incl. validation) on the logs
      - packaging the profile run data
    
    The tool includes fairly helpful `--help` & `--help-full`
    facilities.

### Quick action – running a benchmark without much ado

1.  Access the cluster deployment environment:
      - log into the development deployer under the `dev` user
          - in case you don't have this set up, add the following to
            your

Host staging User staging Hostname 18.196.206.34

  - `screen -x bench`
  - use `C-b p` / `C-b n` to select the `screen` window that contains
    the cluster you want to operate on
  - update the `cardano-ops` checkout to the desired version

<!-- end list -->

1.  Ensure the cluster params file (`benchmarking-cluster-params.json`)
    is up-to-date with the current `cardano-ops` checkout:
    
    ``` example
    bench reinit-params
    ```
    
    This step is only necessary when `cardano-ops` is updated in a major
    way, which is rarely the case.

2.  The easiest way to run a basic benchmark for the default profile is
    to issue:
    
    ``` example
    bench profile default
    ```
    
    That's it\! The default profile
    (`dist3-50000tx-100b-100tps-1io-2000kb`, provided that the cluster
    is currently initialised to the size of 3 nodes) runs roughly 15
    minutes, and will deliver packaged results in `~dev/bench-results`,
    in a file such as:
    
    ``` example
    2020-05-27-12.02.dist3-50000tx-100b-100tps-1io-128kb.tar.xz
    ```
    
    The timestamp in the package name corresponds to the initiation of
    the test run.

3.  Otherwise, if we would like to make a specific choice on the
    profiles to run, we'll have to explore the available profiles and
    express that choice.
    
    The first exploration option lists all available profiles:
    
    ``` example
    bench list-profiles
    ```
    
    Second, we can use a `jq` query to subset the profiles, based on
    their properties. Properties possessed by profiles have can be
    observed via the `show` command:
    
    ``` example
    bench show-profile default
    ```
    
    These properties can, then be used for subsetting, as follows:
    
    ``` example
    bench query-profiles '.generator.inputs_per_tx | among([1, 2])'
    ```
    
    Once we're satisfied with the query, we can use it as follows:
    
    ``` example
    bench profiles-jq '.generator.inputs_per_tx | among([1, 2])'
    ```
    
    Please, refer to <https://stedolan.github.io/jq/manual/> for further
    information on the `jq` query language.

### Conceptual overview

The pipeline can be described in terms of the following concepts, which
we enumerate here shortly, but will also revisit in depth later:

1.  **Source pins** for the components (`cardano-node`,
    `cardano-db-sync` and `cardano-benchmarking` repositories).

2.  **Benchmarking parameters**, maintained in
    `benchmarking-cluster-params.json`, carry the *benchmarking
    profiles*.

3.  **Benchmarking profiles** are contained in *benchmarking
    parameters*, and parametrise the cluster genesis and transaction
    generator.

4.  Cluster components: the **producers** hosts, which mint blocks, and
    the **explorer** host, which generates transactions and serves as a
    point of observation.

5.  **Deployment checkout** is a per-cluster checkout of the
    `cardano-ops` repository, that is situated in the home directory of
    the `dev` user on the development deployer. After **checkout
    initialisation** (see: `bench init N`) it is extended by the
    *benchmarking parameters* file, `benchmarking-cluster-params.json`.

6.  The **deployment state**, which is implicit in the *cluster
    component* states, but also summarised in the **deployment state
    files** – `deployment-explorer.json` and
    `deployment-producers.json`.

7.  The **genesis** is parametrised by the *benchmarking profile*, and,
    once changed (perhaps due to *benchmarking profile* selection),
    necessitates redeployment of all *cluster components*.

8.  The **deployment process**, which affects the *deployment state*,
    and updates its summaries in the *deployment state files*.

9.  The **benchmarking process**, which is defined by the *deployment
    state*, which is in turn affected by the *source pins*, *topology*
    and the chosen *benchmarking profile*.
    
    It consists of several phases: **profile activation**, **cleanup**,
    **initialisation**, **registration**, **generation** and
    **termination**.

10. **Benchmarking run** is a closely related concept that denotes a
    particular, parametrised instance of the *benchmarking process*,
    that was executed at a certain time.
    
    Each *benchmarking run* is assigned a unique **tag**, that coincides
    with the name of a subdirectory under `./runs` in the deployment
    checkout, and also defines the name of the run report package.
    
    The *tag* is formed as concatenation of the run's timestamp and
    profile name.

11. The **benchmarking batch** is a set of **benchmarking runs** for all
    *benchmarking profiles* defined by the *benchmarking parameters* of
    the particular cluster..

12. The **capture process**, that follows the *benchmarking process*,
    collects and processes the post-benchmarking cluster state, and
    ultimately provides the **benchmark results**.
    
    It consists of: **log fetching**, **analysis**, **validation** and
    **packaging**.

13. **Benchmark results**, consist of run *logs* and results of their
    *analysis*.

### Benchmarking environment operation notes

**WARNING 1**: it is strongly discouraged to edit the `cardano-ops`
deployment checkouts directly, as this severely impedes collaboration.

It is, instead, advised to add on the developer's machine, a `git`
remote for the `cardano-ops` deployment checkout, and use `git` to push
to that. Note, that even the branch currently checked out on the
deployer can be pushed to – the checkout will be magically updated,
provided there were no local changes.

**WARNING 2**: it is strongly discouraged to operate the cluster outside
of the permanent screen session on the `dev` deployer – this raises the
possibilty of conflicting deployments and discarded benchmark results.

It's easy to join the screen session:

``` example
screen -x bench
```

In any case, please be mindful of the potential disruption to the
ongoing benchmarks.

### Parametrisation – source pins, topologies and and benchmarking profiles

Benchmark runs are, ultimately, parametrised by a combination of
explicit variables (we're omitting such implicit factors as network
congestion and cloud service load), that are captured and exposed by the
benchmarking infrastructure via concordant control mechanisms:

1.  versions of deployed software
      - exposed via source pins
2.  cluster topology (incl. size)
      - currently not parametrisable in a satisfactorily flexible way,
        so only cluster size can be picked easily
3.  blockchain and transaction generation parameters
      - exposed via benchmarking profiles

<!-- end list -->

1.  Source pins
    
    **Source pins** specify versions of software components deployed on
    the benchmarking cluster. These pins are honored by all profile
    runs, and their values are captured in the profile run metadata.
    
    Following pins are relevant in the benchmarking context:
    
      - `cardano-node`, stored in `nix/sources.bench-txgen-simple.json`
      - `cardano-db-sync`, stored in
        `nix/sources.bench-txgen-simple.json`
      - `cardano-benchmarking`, stored in `nix/sources.json`
    
    These pins can be automatically updated to match a particular branch
    or tag using `niv`, which is available inside the `nix-shell` at
    `cardano-ops`:
    
    ``` example
    niv -s SOURCES-JSON-FILE update REPO-NAME --branch BRANCH-OR-TAG
    ```

2.  Topology and size
    
    As mentioned previously, only cluster size and topology type can be changed
    conveniently.
    
    There are four pre-defined topology, each associated with a
    particular cluster size: `3`, `6`, `9` or `12` nodes, and that's what
    forms the basis for the parametrisation.
    
    These topology files reside in the `topologies` subdirectory of
    `cardano-ops`, and are called `bench-txgen-TYPE-N.nix`, where N is
    the intended cluster size, and TYPE is topology type -- either `distrib` or
    `eu-central-1`.
    
    Changes beyond mere size require direct, manual intervention into
    one of those topology files.
    
    Once the desired topology is prepared, switching the cluster to that
    topology takes two steps:
    
    1.  ``` example
        bench recreate-cluster N
        ```
        
        ..where `N` is the new cluster size.
        
        This step will fails at the very end, due to a known
        `cardano-db-sync` service definition issue, and then:
    
    2.  ``` example
        bench deploy
        ```
        
        ..which ought to succeed, with the following final messages:
        
        ``` example
        explorer................................> activation finished successfully
        bench-dist-0> deployment finished successfully
        ```
    
    This completes preparations for running of benchmark profiles of the
    new size.

3.  Profiles and the benchmarking cluster parameters file
    
    Each benchmarking cluster obtains its profile definitions and other
    metadata from a local file called
    `./benchmarking-cluster-params.json`.
    
    This cluster parameterisation file is generated, and the generator
    accepts a single parameter – cluster size:
    
    ``` example
    bench init-params 3
    ```
    
    This produces a JSON object, that defines benchmarking profiles
    (except for its `meta` component, which carries things like node
    names and genesis configuration).
    
    NOTE: From time to time, the JSON schema intended by the `bench`
    tool for this file changes, and so the file has to be reinitialised
    to restore correspondence:
    
    ``` example
    bench reinit-params
    ```
    
    Benchmarking profiles serve as named sets of parameters for
    benchmarking runs, and can be listed with:
    
    ``` example
    bench list-profiles
    ```
    
    Note, that besides the main benchmarking profiles, this also lists a
    number of quicker-running auxiliary profiles, such as `short`,
    `small` and `smoke`.
    
    The content of any particular profile can be inspected as follows:
    
    ``` example
    bench show-profile dist3-50000tx-100b-100tps-16io-2000kb
    ```
    
    This structure can be used as a basis for selecting profiles, as
    follows:
    
    ``` example
    bench query-profiles '.generator.inputs_per_tx | among([1, 2])'
    ```
    
    ..or even:
    
    ``` example
    bench query-profiles 'matrix_blks_by_ios([32000, 64000], [1, 4, 16])'
    ```
    
    Once we have a satisfactory query, we can run the profiles it
    selects:
    
    ``` example
    bench profiles-jq 'matrix_blks_by_ios([32000, 64000], [1, 4, 16])'
    ```
    
    For details on the `jq` query language, please see
    <https://stedolan.github.io/jq/manual/>

4.  Note on critical blockchain parameters
    
    Some of the benchmarked protocols critically tie their genesis
    parameters to the cluster size.
    
    In case of PBFT, the PBFT signature threshold critically must not be
    less than `1 / N`, where, `N` is the producer node count.

5.  Changing the set of available profiles
    
    It's not advised to edit the cluster parameters file directly –
    because doing so would force us to update this file manually,
    whenever the `bench` script changes – we should, instead, change the
    definition of its generator.
    
    Note that this is still currently a bit ad-hoc, but will improve,
    once the declarative definition for the profile specs is implemented
    (it's well underway).

### Deployment state

The cluster deployment state is handled more-or-less transparently,
with, for example, genesis being regenerated and deployed across cluster
on minimal, as needed basis.

Whenever a need arises, deployment can be done as easily as:

``` example
bench deploy [PROFILE=default]
```

..which prepares the cluster to execution of a particular benchmark
profile.

### The benchmarking process

Following phases constitute a benchmark run:

1.  Profile activation:
    
      - genesis age check and potential regeneration
      - deployment, either just on the explorer node, or across the
        cluster, depending on circumstances

2.  Cleanup of the cluster state:
    
      - service shutdown across the cluster, including journald
      - purging of service logs, including all journald logs
      - purging of node databases
      - cleanup of the `cardano-db-sync` database
      - restart of all services, incl. nodes and the `db=sync`

3.  Initialisation
    
      - an additional genesis check, based on the its actually deployed
        value
      - initial delay, to allow nodes to connect to each other, and to
        generally establish business

4.  Registration
    
    This is when the benchmark run gets assigned a unique run id, or
    "tag", and an output folder in a '`run`' subdirectory named after
    the run id.
    
    The run id (or tag) consists of the humand-readable timestamp, in
    the form of `YYYY-MM-DD-HH.MM.PROFILENAME`.

5.  Generation
    
      - The `cardano-tx-generator` service is started,
    
      - A non-empty block is then expected to appear within the
        following `200` seconds – and if it doesn't, the benchmark run
        is aborted and its results are marked and further processed as
        broken. See the **"Broken run processing"** section for the
        details.
    
      - After a non-empty block appears, the condition changes – the
        benchmark run is considered in progress, until either:
        
          - no blocks arrive within reasonable time, in which case,
            again, the benchmark run is aborted and its results are
            marked and further processed as broken. Again, please see
            the **"Broken run processing"** section for the details.
          - a sequence of empty blocks arrives, according to a
            profile-defined length. This is considered a success, and
            leads to the following phase.

6.  Benchmark termination is simply about stopping of all key
    log-producing services.

### The capture process

The capture process deals with artifact collection and analysis
(including validation).

1.  Log fetching
    
    Logs are collected from all services/nodes material to benchmarking:
    
      - producer and observer nodes
      - transaction generator
      - `cardano-db-sync`
    
    The `cardano-db-sync` database has the SQL extraction queries
    performed on it. (For the queries, please look for the
    `scripts/NN-*.sql` files in the `cardano-benchmarking` repository).
    
    All that is collected over SSH and stored in the current benchmark
    run directory on the deployer.
    
    The fetch phase is separately available via the `bench fetch`
    subcommand, and by default fetches logs from the last run.

2.  Analysis
    
    A number of log analyses are performed on the collected logs, some
    of them coming from the `cardano-benchmarking` repository (in the
    `analyses` and `scripts` directories), and some defined locally, in
    the `bench` tool (in `bench/lib-analyses.sh`).
    
    The analyses include, but are not limited to:
    
      - log file inventory, incl. time spans between first/last
        messages,
      - per-transaction issuance/block inclusion time
      - transaction submission statistics:
          - announcement, sending, acknowledgement, loss and
            unavailability
      - submission thread trace extraction
      - per-message analyses, such as `MsgBlock`, `AddedBlockToQueue`,
        `AddedToCurrentChain`, `TraceForgeInvalidBlock` and
        `TraceMempoolRejectedTx`
      - message type summary, that lists all encountered message types,
        along with occurence counts
      - analyses derived from the above, such as:
          - Tx rejection/invalid UTxO/missing input counters
    
    The analysis phase is separately available via the `bench analyse`
    subcommand, and by default analyses logs from the last run.

3.  Validation
    
    Validation depends on the previous analyses to detect anomalies and
    provides a form of automated pass/fail classification of
    benchmarking runs based on the sanity checks defined in
    `bench/lib-sanity.sh`, such as:
    
      - log file start/stop spread being within a specified threshold,
        incl. from benchmark run start time
      - blocks being made at all
      - trailing block-free gap until cluster termination being within a
        specified threshold
      - having any transactions in blocks at all
      - having the submission process announced and send the exact same
        number of transactions as requested by benchmark profile
      - having the count of transactions seen in blocks to be within a
        specified threshold from number of transactions sent
      - having the chain density within the specified threshold
    
    The sanity check phase is separately available via the `bench
    sanity-check` subcommand, and by default checks sanity of logs from
    the last run.

4.  Packaging
    
    All the logs and the analysis results are packaged in either the
    "good" or the "bad" run result directory, in a file with name
    derived as concatenation of the profile run start timestamp and the
    profile name, optionally suffixed with `.broken` marker in case of
    broken runs.
    
    The result directories are situated on the `dev` deployer:
    
      - `bench-results`
      - `bench-results-bad`
    
    The package phase is separately available via the `bench package`
    subcommand, and by default packages the run directory from the last
    run.

### Benchmark results

Each successful benchmark run produces the following results:

1.  A run output directory, such as:
    
    ``` example
    ./runs/2020-05-27-12.02.dist3-50000tx-100b-100tps-1io-128kblk
    ```
    
    This benchmark run directory, contains:
    
    1.  `meta.json` – the run's metadata, a key piece in its processing,
    
    2.  a copy of `benchmarking-cluster-params.json`, taken during the
        **registration** phase of the **benchmark process**,
    
    3.  deployment state summaries of the cluster components, taken
        during the **registration** phase of the **benchmark process**:
        `deployment-explorer.json` and `deployment-producer.json`,
    
    4.  `meta/*` – some miscellaneous run metadata,
    
    5.  `logs/*` – various logs, both deployment, service startup and
        runtime, for all the nodes (including explorer) and the Tx
        generator. This also includes an extraction from the
        `cardano-db-sync` database.
    
    6.  `analysis.json` – a collection of small-output-volume analyses.
    
    7.  `analysis/*` – data extraction based on the available logs.
    
    8.  `tools/*` – the tools used to perform some of the analyses,
        fetched from the `cardano-benchmarking` repo.

2.  An archive in the deployment checkout, that contains the exact
    *content* of that directory, but placed in a directory with a
    user-friendly name:
    
    ``` example
    ./YYYY-MM-DD-HH.MM.$PROFILE_NAME.tar.xz
    ```
