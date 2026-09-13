# Issue Tracking: Upstream vs. cosmic-vulkan

Bugs found while developing and stress-testing this project's Vulkan renderer,
tracked against their actual root cause and upstream status. This exists
because several of these bugs turned out to be pre-existing in upstream
`cosmic-comp`/Smithay rather than caused by the Vulkan renderer work itself -
this table is the record of which is which, so a bug doesn't get
misattributed to "Vulkan is broken" when it reproduces identically on GLES,
and so a real regression doesn't get dismissed as "that's just upstream."

Each row links to this project's own tracking issue (full investigation,
evidence, and fix status) and any known upstream issue/PR for the same bug.

Legend - **Introduced by**: `upstream` (pre-existing in `pop-os/cosmic-comp`
or Smithay, reproduces without this project's changes) · `this project`
(caused by a commit in this project's branches) · `n/a` (not a regression,
a missing feature). **Status**: 🔴 open/unfixed · 🟡 fix applied, unverified
· 🟢 fixed and verified · ⚪ not yet investigated.

| Issue | Introduced by | Status | Upstream reference | This project's tracking |
|---|---|---|---|---|
| Duplicate per-output render threads (`apply_config_for_outputs` excludes already-surfaced connectors by `Output` identity instead of connector handle, so a second config-apply pass can spawn a second thread for the same connector) | upstream | 🟡 fix applied, needs a reboot to verify | Not filed upstream as of writing | [#1](https://github.com/Pheoxy/cosmic-vulkan/issues/1) |
| Intermittent hardware cursor-plane assignment failure (software cursor fallback, tied to frame rate) | upstream | 🟡 expected fixed as a side effect of the duplicate-thread fix, needs before/after verification | [pop-os/cosmic-comp#2664](https://github.com/pop-os/cosmic-comp/issues/2664), [#1379](https://github.com/pop-os/cosmic-comp/issues/1379), [#2113](https://github.com/pop-os/cosmic-comp/issues/2113) | [#2](https://github.com/Pheoxy/cosmic-vulkan/issues/2) |
| Screenshot capture silently fails under GPU load (deferred SHM-copy safety-net timeout races the real render fence) | this project | 🔴 open | n/a - not an upstream code path | [#3](https://github.com/Pheoxy/cosmic-vulkan/issues/3) |
| XWayland `CreateNotify`/`BadWindow` race drops short-lived helper windows (Wine/Proton raw mouse input) | upstream | 🔴 open | Related: [pop-os/cosmic-comp#2255](https://github.com/pop-os/cosmic-comp/pull/2255) (different fix, same bug class) | [#4](https://github.com/Pheoxy/cosmic-vulkan/issues/4) |
| Screen sharing frame rate capped to share session's own fps instead of output refresh rate | ⚪ not yet determined | ⚪ not yet investigated | Not filed upstream as of writing | [#5](https://github.com/Pheoxy/cosmic-vulkan/issues/5) |

Feature gaps (not bugs - things this project's Vulkan renderer doesn't do yet
at all, like screen filter/zoom postprocessing) are tracked in
[FEATURES.md](FEATURES.md) instead, not here.

## Why this table exists

A bug reproducing on hybrid Intel+NVIDIA hardware while stress-testing under
real GPU load (games, screen sharing) is easy to misattribute to whichever
renderer happens to be active at the time. Several of the issues above were
initially assumed to be Vulkan-specific and turned out, on closer
investigation (source tracing, live process/kernel introspection, and
checking upstream's own issue tracker), to be pre-existing and
renderer-agnostic. Keeping that distinction explicit and sourced is the point
of this file.
