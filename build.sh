#!/bin/bash

set -e

# download toolchain from https://opensource.samsung.com/uploadSearch?searchValue=toolchain 
TOOLCHAIN=$(realpath "/root/Desktop/Prj/Android/toolchain_samsung/prebuilts")

export PATH=$TOOLCHAIN/build-tools/linux-x86/bin:$PATH
export PATH=$TOOLCHAIN/build-tools/path/linux-x86:$PATH
export PATH=$TOOLCHAIN/clang/host/linux-x86/clang-r487747c/bin:$PATH
export PATH=$TOOLCHAIN/clang-tools/linux-x86/bin:$PATH
export PATH=$TOOLCHAIN/kernel-build-tools/linux-x86/bin:$PATH

echo $PATH

#TARGET_DEFCONFIG=${1:-pineapple_gki_defconfig}
TARGET_DEFCONFIG=${1:-s5e9925-g0sxxx_defconfig}

cd "$(dirname "$0")"


LOCALVERSION=-android15-Andycar-TACA-BYDA-LKM

if [ "$LTO" == "thin" ]; then
  LOCALVERSION+="-thin"
fi

ARGS="
CC=clang
ARCH=arm64
LLVM=1 LLVM_IAS=1
LOCALVERSION=$LOCALVERSION
"

# build kernel
make -j$(nproc) -C $(pwd) O=$(pwd)/out ${ARGS} $TARGET_DEFCONFIG

./scripts/config --file out/.config \
  -d UH \
  -d RKP \
  -d KDP \
  -d SECURITY_DEFEX \
  -d INTEGRITY \
  -d FIVE \
  -d TRIM_UNUSED_KSYMS

if [ "$LTO" = "thin" ]; then
  ./scripts/config --file out/.config -e LTO_CLANG_THIN -d LTO_CLANG_FULL
fi

make -j$(nproc) -C $(pwd) O=$(pwd)/out ${ARGS}

cd out
if [ ! -d AnyKernel3 ]; then
  git clone --depth=1 https://github.com/YuzakiKokuban/AnyKernel3.git -b pineapple
fi
cp arch/arm64/boot/Image AnyKernel3/zImage
name=S24_kernel_`cat include/config/kernel.release`_`date '+%Y_%m_%d'`
cd AnyKernel3
rm -f patch_linux
zip -r ${name}.zip * -x *.zip
cd ..
cp arch/arm64/boot/Image AnyKernel3/tools/kernel
cd AnyKernel3/tools
chmod +x libmagiskboot.so
lz4 boot.img.lz4
./libmagiskboot.so repack boot.img ${name}.img 
echo "boot.img output to $(realpath $name).img"
cd ..
cd ..
echo "AnyKernel3 package output to $(realpath $name).zip"