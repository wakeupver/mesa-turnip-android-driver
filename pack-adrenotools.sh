#!/bin/sh
# Pack a built turnip library into an AdrenoTools driver package (meta.json + library),
# the format imported by Winlator, Eden/yuzu forks and other libadrenotools based
# driver managers.
#
# usage: pack-adrenotools.sh <mesa-source-dir> <label> <libvulkan_freedreno.so> <out.zip>
set -eu

if [ $# -ne 4 ]; then
    echo "usage: $0 <mesa-source-dir> <label> <libvulkan_freedreno.so> <out.zip>" >&2
    exit 2
fi

mesa_dir=$1
label=$2
lib=$3
out=$4

# AdrenoTools driver packages ship the driver under the Adreno Vulkan HAL name,
# both as file name and as soname.
libname=vulkan.adreno.so
author=${GITHUB_REPOSITORY_OWNER:-unknown}

# the values below end up in meta.json unescaped
for v in "$label" "$author"; do
    case $v in
        '' | *[!A-Za-z0-9._-]*)
            echo "error: unexpected characters in '$v'" >&2
            exit 2
            ;;
    esac
done

# Vulkan header version of this mesa. turnip reports 1.4.<it> on Adreno 7xx+ and
# up to 1.3.<it> on Adreno 6xx.
hdr=$(sed -n 's|.*#define <name>VK_HEADER_VERSION</name> \([0-9][0-9]*\)</type>.*|\1|p' \
      "$mesa_dir/src/vulkan/registry/vk.xml" 2>/dev/null | head -n 1)
if [ -n "$hdr" ]; then
    driver_version="Vulkan 1.4.$hdr"
else
    driver_version="Vulkan 1.4"
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cp "$lib" "$tmp/$libname"
# --page-size: whatever patchelf has to add must stay 16 KB aligned (Android 15+
# devices with 16 KB pages refuse to load anything less)
patchelf --page-size 16384 --set-soname "$libname" "$tmp/$libname"

# fail the build instead of publishing a driver the loader can not use
if ! readelf -d "$tmp/$libname" | grep -q "(SONAME).*\[$libname\]"; then
    echo "error: soname of the packed library is not $libname" >&2
    exit 1
fi
if ! readelf --dyn-syms -W "$tmp/$libname" | grep -qE ' HMI(@.*)?$'; then
    echo "error: HMI (Vulkan HAL entry point) is not exported by $lib" >&2
    exit 1
fi
for align in $(readelf -lW "$tmp/$libname" | awk '$1 == "LOAD" { print $NF }'); do
    if [ $((align)) -lt 16384 ]; then
        echo "error: a LOAD segment is aligned to $align, below 16 KB" >&2
        exit 1
    fi
done

cat > "$tmp/meta.json" <<EOF
{
  "schemaVersion": 1,
  "name": "Mesa Turnip $label",
  "description": "Mesa Turnip $label for Adreno 6xx/7xx/8xx (KGSL). Reports Vulkan 1.4 on 7xx and newer, up to 1.3 on 6xx.",
  "author": "$author",
  "packageVersion": "1",
  "vendor": "Mesa",
  "driverVersion": "$driver_version",
  "minApi": 26,
  "libraryName": "$libname"
}
EOF

case $out in
    /*) out_abs=$out ;;
    *) out_abs=$PWD/$out ;;
esac
rm -f "$out_abs"
(cd "$tmp" && zip -q -9 "$out_abs" meta.json "$libname")

echo "created $out_abs"
unzip -l "$out_abs"
