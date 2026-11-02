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

# Patches applied on top of mesa

- `mesa-implement-android_stub.patch` - android stub libraries so the driver can be hot-swapped
- `mesa-android-include-all-vulkan-extension.patch` - expose all implemented vulkan extensions
- `mesa-tu-kgsl-stability.patch` - KGSL (Adreno kernel interface) robustness fixes:
  - a fence wait on a context that KGSL invalidated after a GPU fault/hang (or detached, or whose GPU went away) now returns `VK_ERROR_DEVICE_LOST` instead of a plain `VK_TIMEOUT`, so applications stop waiting forever on a fence that can never signal
  - `submit failed` device-lost messages keep the real `errno`
  - fixes two error-path leaks of KGSL allocations (lazy BO bind failure, sparse VMA info query failure)

The driver is one binary for Adreno 6xx/7xx/8xx. The link step also aligns ELF segments to 16 KB so it loads on Android 15+ 16 KB page devices.

# Tuning knobs for Adreno 6xx

No behaviour-changing performance heuristics are patched in, because those need benchmarking on the target device and game. Turnip already reads these environment variables, set them in the host app before the driver is loaded and compare:

- `TU_AUTOTUNE_ALGO=bandwidth|profiled|profiled_imm|prefer_sysmem|prefer_gmem` - how renderpasses pick GMEM (tiled) vs SYSMEM rendering
- `TU_DEBUG=sysmem` / `TU_DEBUG=gmem` - force one rendering mode
- `TU_DEBUG=nolrz`, `TU_DEBUG=noubwc` - turn off LRZ / UBWC to isolate rendering bugs

# Credits
- https://gitlab.freedesktop.org/mesa/mesa for mesa turnip driver source
- https://github.com/v3kt0r-87/Mesa-Turnip-Builder for mesa turnip build instruction
- https://github.com/lizhangqu/dlfcn_compat for dlopen android system library
