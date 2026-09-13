# Feature Comparison: GLES vs. Vulkan

Status of `cosmic-comp` features under the default GLES renderer versus this
project's Vulkan renderer. "GLES" reflects upstream `cosmic-comp` as shipped;
"Vulkan" reflects the state of the `vulkan-renderer-e3d461a`/
`add-vulkan-renderer-support-cosmic-e3d461a` branches tracked by this
project. Renderer-agnostic bugs (issues that reproduce identically under
both renderers) are out of scope for this table - it only covers behavior
that actually differs between the two rendering backends.

Legend: ✅ complete/working · ⚠️ partial/intermittent · ❌ not implemented ·
❓ not yet verified under this renderer

| Feature | GLES | Vulkan | Notes |
|---|:---:|:---:|---|
| Basic window compositing | ✅ | ✅ | |
| Window shadows (blurred) | ✅ | ✅ | Vulkan shadow pipeline implemented via the generic `Frame::draw_shadow` path, not a GLES-only shader |
| SHM screencopy (screenshots, screen capture) | ✅ | ⚠️ | Vulkan path defers the SHM copy off the render-dispatch thread; GLES stays eager to match its pre-existing behavior. Under Vulkan, the screenshot tool's post-capture viewer never opens after a capture - not yet confirmed whether this is Vulkan-specific or a shared code path also affected under GLES |
| Dmabuf import/export | ✅ | ✅ | Vulkan renderer-tracked rebinds now preserve buffer contents across a rebind instead of losing them |
| Runtime renderer selection | n/a (default) | ✅ | `COSMIC_RENDERER` environment variable; no compile-time feature flag required to switch between renderers |
| Multi-GPU / hybrid graphics (PRIME offload) | ✅ | ✅ | Both renderers share the same `GpuManager`/`MultiRenderer` multi-GPU infrastructure |
| Adaptive sync / VRR | ✅ | ✅ | |
| Hardware cursor plane assignment | ✅ | ⚠️ | Intermittent fallback to software cursor compositing observed under Vulkan; not yet confirmed whether this is Vulkan-specific or a shared code path also affected under GLES |
| Screen filter / accessibility zoom postprocessing | ✅ | ❌ | Not implemented for the Vulkan renderer path yet |
| Screen sharing (`wlr-screencopy`-style output capture) | ✅ | ⚠️ | Works under Vulkan, but the shared stream's frame rate is capped to the screen-share session's own fps rather than tracking the output's real refresh rate |
| Debug/profiling tooling (Tracy, Vulkan validation layers) | n/a | ✅ | Validation layers available under debug builds via this project's dev shell |

Anything not listed here has not been specifically compared between the two
renderers and should not be assumed to work identically.

## Benchmarks

No controlled, apples-to-apples GLES-vs-Vulkan benchmark has been run yet -
entries below are placeholders for when one is. A fair comparison needs the
same scene/workload, the same `--release` build settings, and enough runs to
account for variance; ad hoc single-session frame-time impressions aren't
included here.

| Workload | GLES (avg fps / frame time) | Vulkan (avg fps / frame time) | Notes |
|---|---|---|---|
| Idle desktop | - | - | |
| Window tiling/resize stress | - | - | |
| 3D game, moderate GPU load | - | - | |
| 3D game, heavy GPU load | - | - | |

Contributions of real benchmark runs (methodology + results) are welcome.
