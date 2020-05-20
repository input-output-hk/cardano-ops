# Cardano benchmarking infrastructure

### Contents

1.  *Bird's eye overview*
2.  *Quick action -- running a benchmark without much ado*
3.  *Conceptual overview*
4.  *Benchmark operation*
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
  - A number of cluster deployments, on the development deployer, that
    have `cardano-ops` checkouts & benchmarking configuration set up in
    each of them, in the form of `benchmarking-cluster-params.json`
    files.

<!-- end list -->

1.  Clusters
    
    Benchmarking clusters are available on the development deployer, and
    currently include:
    
      - remote-dev-cluster-3
      - remote-dev-cluster-6
      - remote-dev-cluster-9
      - remote-dev-cluster-12

2.  The `bench` command
    
    Benchmarking clusters are controlled using the `bench` command,
    which is equivalent to an alias of `./scripts/bench.sh` in the
    current development checkout.
    
    The command automates a significant part of the benchmarking
    workflow:
    
      - definition of multiple benchmarking profiles
      - generating genesis
      - deploying the cluster
      - running the benchmark profiles
      - collecting & doing basic analysis on the logs
      - packaging the profile run data
    
    The command has a fairly helpful `--help` & `--help-full` flags.

### Quick action – running a benchmark without much ado

1.  Access the cluster deployment environment:
    
      - log into the development deployer
      - `cd $CLUSTER`
      - update the `cardano-ops` checkout to the desired version
      - enter the `nix-shell`

2.  Ensure the cluster params file (`benchmarking-cluster-params.json`)
    is up-to-date with the current `cardano-ops` checkout:
    
    ``` example
    bench reinit-params
    ```
    
    This step is only necessary when `cardano-ops` is updated in a major
    way, which is rarely the case.

3.  The easiest way to run the full suite of benchmark profiles is to
    issue:
    
    ``` example
    bench all
    ```
    
    That's it\!

4.  Otherwise, if willing to benchmark just a single profile, we might
    need to redeploy the cluster:
    
    ``` example
    bench deploy
    ```
    
    This is, generally speaking, only necessary in the following
    situations:
    
      - after genesis update (which is performed by `bench genesis`),
        and
      - after `cardano-node` pin changes.

5.  At this point you are prepared to run a benchmark – either for a
    single profile:
    
    ``` example
    bench bench-profile [PROFILE]
    ```
    
    The profile name is optional, and defaults to `default`, which
    refers to a profile specified in the cluster params file (see the
    `.meta.default_profile` JSON key).
    
    Normally, the default profile is the first one listed.

6.  Every benchmark run provides an archive at the root of the cluster's
    deployment checkout, f.e.:
    
    ``` example
    2020-05-19-22.21.dist6-50000tx-100b-1i-1o-100tps.tar.xz
    ```

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
    state*, and so, indirectly, by the *source pins* and the chosen
    *benchmarking profile*.
    
    It consists of several phases: **cleanup**, **initialisation**,
    **registration**, **generation** and **termination**.

10. **Benchmarking run** is a closely related concept that denotes a
    particular, parametrised instance of the *benchmarking process*,
    that was executed at a certain time.
    
    Each *benchmarking run* is assigned a unique **tag**, that coincides
    with the name of a subdirectory under `./runs` in the deployment
    checkout.

11. The **benchmarking batch** is a set of **benchmarking runs** for all
    *benchmarking profiles* defined by the *benchmarking parameters* of
    the particular cluster..

12. The **capture process**, that follows the *benchmarking process*,
    collects and processes the post-benchmarking cluster state, and
    ultimately provides the **benchmark results**.
    
    It consists of: **log fetching**, **analysis** and **packaging**.

13. **Benchmark results**, consist of the *logs* and results of their
    *analysis*.

### Benchmark operation

**WARNING 1**: it is strongly discouraged to edit the `cardano-ops`
deployment checkout, as this severely impedes collaboration.

It is, instead, advised to add on the developer's machine, a remote for
the `cardano-ops` deployment checkout, and push to that. Note, that even
the branch currently checked out on the deployer can be pushed to – the
checkout will be magically updated, provided there were no local
changes.

**WARNING 2**: it is strongly discouraged to operate the cluster outside
of the permanent screen session on the `dev` deployer – this raises the
possibilty of conflicting deployments and discarded benchmark results.

It's easy to join the screen session:

``` example
screen -x bench
```

### Parametrisation – source pins and and benchmarking profiles

TODO

1.  Source pins
    
    **Source pins** specify versions of software components deployed on
    the benchmarking cluster.
    
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

2.  Profiles and the benchmarking cluster parameters file
    
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
    
    Benchmarking profiles serve as named sets of parameters for
    benchmarking runs, and can be listed with:
    
    ``` example
    bench list-profiles                                   # ..or just 'bench ps'
    ```
    
    As mentioned in the *Quick action* section, we can run benchmarks
    per-profile:
    
    ``` example
    bench bench-profile dist3-50000tx-100b-1i-1o-100tps   # defaults to 'default'
    ```
    
    ..or for all defined profiles:
    
    ``` example
    bench bench-all
    ```
    
    1.  Changing the set of available profiles
        
        It's not advised to edit the cluster parameters file directly –
        because doing so would force us to update this file manually,
        whenever the `bench` script changes – we should, instead, change
        the definition of its generator.
        
        Note that this is still currently a bit ad-hoc, but will
        improve, once the declarative definition for the profile specs
        is implemented.

### Deployment state

1.  State handling
    
    There is an ongoing effort to handle deployment state transparently,
    on a minimal, as-needed basis – as implied by the *benchmarking
    process*.
    
    We'll only cover this shortly, therefore:
    
    1.  genesis can be generated for a particular profile by:
        
        ``` example
        bench genesis [PROFILE=default]
        ```
    
    2.  deployment can be initiated by:
        
        ``` example
        bench deploy [PROFILE=default]
        ```

### The benchmarking process

TODO

1.  Cleanup

2.  Initialisation

3.  Registration

4.  Generation

5.  Termination

### The capture process

TODO

1.  Log fetching

2.  Analysis

3.  Packaging

### Benchmark results

Each successful benchmark run produces the following results:

1.  A run output directory, such as:
    
    ``` example
    ./runs/1589819135.27a0a9dc.refinery-manager.pristine.node-66f0e6d4.tx50000.l100.i1.o1.tps100
    ```
    
    This directory (also called "tag", internally), contains:
    
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
    
    6.  `analysis/*` – some light extraction based on the available
        logs.
    
    7.  `tools/*` – the tools used to perform the above extraction,
        fetched from the `cardano-benchmarking` repo.

2.  An archive in the deployment checkout, that contains the exact
    *content* of that directory, but placed in a directory with a
    user-friendly name:
    
    ``` example
    ./YYYY-MM-DD.$PROFILE_NAME.tar.xz
    ```
