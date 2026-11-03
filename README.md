# mesa turnip android driver
mesa turnip driver for android

![download](https://img.shields.io/github/downloads/nihui/mesa-turnip-android-driver/total.svg)

Download prebuilt binary at https://github.com/nihui/mesa-turnip-android-driver/releases/latest

This turnip driver library can be used with ncnn vulkan loader [simplevk.h](https://github.com/Tencent/ncnn/blob/master/src/simplevk.h)

```cpp
#include "simplevk.h"

ncnn::load_vulkan_driver("libvulkan_freedreno.so");

// now you call any global vulkan functions
// ncnn::vkGetInstanceProcAddr
// ncnn::vkEnumerateInstanceExtensionProperties
// ncnn::vkCreateInstance
// ncnn::vkEnumerateInstanceLayerProperties

// any vulkan api entrypoint can be retrieved from vkGetInstanceProcAddr

ncnn::unload_vulkan_driver();
```

- Hot-swap android vulkan driver at runtime
- Full support for Adreno 6xx/7xx/8xx series
- Better performance than the system blobs
- Can be used directly in your application
- All vulkan extensions implemented are enabled
- Support Android 8.0 or later

# AdrenoTools driver package

Every release also ships `mesa-turnip-adrenotools-<version>.zip`: the driver as `vulkan.adreno.so` plus a `meta.json`. This is the package format that Winlator, Eden/yuzu forks and other libadrenotools based driver managers import directly, import the zip as it is.

# Patches applied on top of mesa

- `mesa-implement-android_stub.patch` - android stub libraries so the driver can be hot-swapped
- `mesa-android-include-all-vulkan-extension.patch` - expose all implemented vulkan extensions
- `mesa-tu-kgsl-wait-fixes.patch` - KGSL (Adreno kernel interface) fence and semaphore wait fixes:
  - polls no longer block until the GPU catches up. KGSL reads a timeout of 0 as "wait forever" (`adreno_drawctxt_wait()` in the kernel), so `vkGetFenceStatus`, `vkGetSemaphoreCounterValue` and the timeline semaphore emulation, which polls every pending point on each query, signal and submit, stalled the CPU on the GPU. Polls now read the retired timestamp instead. This is the performance fix
  - a wait on a context that KGSL invalidated after a GPU fault/hang, or detached, returns `VK_ERROR_DEVICE_LOST` instead of a plain timeout, and a wait that completes while reporting a context fault (`EPROTO`) is no longer taken for a timeout
  - waiting for any of several timestamps waits for the earliest one, not the latest
- `mesa-tu-kgsl-stability.patch` - KGSL robustness fixes:
  - merging a pending timestamp with a sync fd into one wait list (for example a timeline wait plus an Android swapchain acquire fence) used the wrong object, it could crash or drop the timestamp dependency
  - `submit failed` messages keep the real `errno`
  - fixes two error-path leaks of KGSL allocations (lazy BO bind failure, sparse VMA info query failure)

The two KGSL patches are independent of each other.

The driver is one binary for Adreno 6xx/7xx/8xx. The link step also aligns ELF segments to 16 KB so it loads on Android 15+ 16 KB page devices.

# Tuning knobs for Adreno 6xx

Apart from the wait fix above, no performance heuristics are patched in, because those need benchmarking on the target device and game. Turnip already reads these environment variables, set them in the host app before the driver is loaded and compare:

- `TU_AUTOTUNE_ALGO=bandwidth|profiled|profiled_imm|prefer_sysmem|prefer_gmem` - how renderpasses pick GMEM (tiled) vs SYSMEM rendering
- `TU_DEBUG=sysmem` / `TU_DEBUG=gmem` - force one rendering mode
- `TU_DEBUG=nolrz`, `TU_DEBUG=noubwc` - turn off LRZ / UBWC to isolate rendering bugs

# Credits
- https://gitlab.freedesktop.org/mesa/mesa for mesa turnip driver source
- https://github.com/v3kt0r-87/Mesa-Turnip-Builder for mesa turnip build instruction
- https://github.com/lizhangqu/dlfcn_compat for dlopen android system library
