## Plan: Diagnose & Accelerate Builds

Investigate why current OpenWRT-CI firmware builds take 2–3 hours while Kiddin9/kwrt completes in minutes, then outline actionable optimizations to shrink second-build times through caching, workflow tweaks, and possible prebuilt assets.

### Steps
1. Map build flow by reviewing `diy.sh`, `Scripts/init_build_environment.sh`, `Scripts/Settings.sh`, `Scripts/Packages.sh` to list every clean/install step and identify repeated heavy operations.
2. Inventory existing reuse by checking `Config/*.txt`, `files/etc/config` overlays, and build artifacts to see whether `dl/`, `staging_dir/`, and toolchains survive between runs.
3. Analyse kwrt accelerators using `devices/common/diy.sh`, `devices/**/diy.sh`, and `devices/common/patches/china_mirrors.patch.b` to document prebuilt feed usage, mirror setup, and selective rebuild patterns.
4. Propose cache-friendly adjustments (persist `dl/` and `staging_dir/`, enable `ccache` in `Scripts/function.sh`, skip redundant `feeds update/install`, reuse `tmp/` for second compile) and note required script changes.
5. Identify advanced accelerators (e.g., own `kwrt-packages`-style binary feed, imagebuilder-based rebuilds, CI artefact caching, build matrix) and outline prerequisites for adoption.

### Further Considerations
1. Do we have persistent storage in CI to retain `dl/`, `staging_dir/`, and `build_dir` between runs? Option A keep-all, B partial, C none.
2. Should we mirror kwrt’s prebuilt feed approach or prefer native incremental builds? Option A external feed, B local cache, C hybrid.
