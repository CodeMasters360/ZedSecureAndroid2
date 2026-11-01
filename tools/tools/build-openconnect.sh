#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API=24
ABIS="arm64-v8a armeabi-v7a x86_64"
WORK="/tmp/openconnect-build"
JNI="$ROOT/app/src/main/jniLibs"

# پیدا کردن مسیر NDK
newest=$(ls -1 "$ANDROID_HOME/ndk" 2>/dev/null | sort -V | tail -1)
NDK="$ANDROID_HOME/ndk/$newest"
TOOLCHAIN="$NDK/toolchains/llvm/prebuilt/linux-x86_64"
export PATH="$TOOLCHAIN/bin:$PATH"

mkdir -p "$WORK"
echo ">>> Cloning OpenConnect source..."
if [ ! -d "$WORK/openconnect" ]; then
  git clone --depth 1 --branch "v9.12" https://gitlab.com/openconnect/openconnect.git "$WORK/openconnect"
fi

for abi in $ABIS; do
  case "$abi" in
    arm64-v8a)   host=aarch64-linux-android; cc=aarch64-linux-android$API-clang ;;
    armeabi-v7a) host=arm-linux-androideabi; cc=armv7a-linux-androideabi$API-clang ;;
    x86_64)      host=x86_64-linux-android;  cc=x86_64-linux-android$API-clang ;;
  esac

  build="$WORK/$abi"
  rm -rf "$build" && mkdir -p "$build"
  cp -r "$WORK/openconnect" "$build/src"
  export CC="$cc" AR=llvm-ar RANLIB=llvm-ranlib STRIP=llvm-strip

  echo ">>> Compiling libopenconnect.so for $abi..."
  (cd "$build/src" &&
    ./autogen.sh >/dev/null 2>&1 &&
    LDFLAGS="-Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384" \
    ./configure --host="$host" \
      --disable-nls \
      --without-libpcsclite \
      --without-stoken \
      --without-libpskc \
      --without-gssapi \
      --with-openssl \
      --enable-shared \
      --disable-static >/dev/null 2>&1 &&
    make -j"$(nproc)" libopenconnect.la >/dev/null 2>&1
  )

  mkdir -p "$JNI/$abi"
  cp "$build/src/.libs/libopenconnect.so" "$JNI/$abi/libopenconnect.so"
  llvm-strip "$JNI/$abi/libopenconnect.so"
  echo ">>> Successfully placed libopenconnect.so in $abi"
done
