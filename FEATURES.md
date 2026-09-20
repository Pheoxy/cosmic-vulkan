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
| SHM screencopy (screenshots, screen capture) | ✅ | ⚠️ | The exported Vulkan swapchain image now requests `TRANSFER_SRC` usage (probed per format/modifier, falling back to the plain color-attachment-only image on hardware that doesn't support it) so it can be used as a `Blit` source. Verified 2026-09-19/20 (screenshots and Discord capture produce frames). Remaining capture issues (frame refusals during a share, SHM-only readback cost) are tracked in `ISSUES.md` |
| Dmabuf import/export | ✅ | ✅ | Vulkan renderer-tracked rebinds now preserve buffer contents across a rebind instead of losing them |
| Runtime renderer selection | n/a (default) | ✅ | `COSMIC_RENDERER` environment variable; no compile-time feature flag required to switch between renderers |
| Multi-GPU / hybrid graphics (PRIME offload) | ✅ | ✅ | Both renderers share the same `GpuManager`/`MultiRenderer` multi-GPU infrastructure |
| Adaptive sync / VRR | ✅ | ✅ | |
| Hardware cursor plane assignment | ✅ | ⚠️ | Intermittent fallback to software cursor compositing observed under Vulkan; not yet confirmed whether this is Vulkan-specific or a shared code path also affected under GLES |
| Screen filter (invert, colorblind correction) | ✅ | ⚠️ | Colorblind/greyscale correction is pure `CTM` and no longer touches `GAMMA_LUT` at all, so it works in hardware regardless of whether `GAMMA_LUT` itself is writable on a given CRTC. `invert` still needs `GAMMA_LUT` (an affine transform `CTM` can't express); GLES's own pre-existing compositing shader is unaffected by any of this (GLES always used it for invert regardless). Under Vulkan there is still no shader implementation at all for invert (by original design, no Vulkan port was ever built), so on a CRTC where `GAMMA_LUT` isn't writable, `invert` under Vulkan currently has no effect - see `ISSUES.md`. Fix applied, needs a reboot to verify |
| Night light (color temperature) | n/a (new) | ✅ | Server-side `wlr-gamma-control-unstable-v1` in `cosmic-comp`; `cosmic-settings`' own toggle is a client of it. Scoped to a fixed-temperature on/off toggle for now, no schedule automation yet. A requested color-temperature ramp is a pure per-channel linear scale, so on a CRTC where `GAMMA_LUT` itself isn't writable it's automatically upgraded to an equivalent hardware `CTM` instead (vendor-agnostic - based on the shape of the ramp, not the GPU) - see `diagonal_scale_from_ramp` in `ISSUES.md`. Fix applied, needs a reboot to verify |
| Screen sharing (`wlr-screencopy`-style output capture) | ✅ | ⚠️ | Shares `send_screencopy_result_vulkan` with the SHM screencopy row above. Verified working 2026-09-19; but a share currently refuses ~20 compositor frames/s (`locally owned` swapchain slot after the capture blit) and the capture is SHM-only under Vulkan - see `ISSUES.md` |
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
