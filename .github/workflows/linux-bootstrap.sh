#!/usr/bin/env bash

set -e
export TMPDIR=/tmp
export WORKFLOW_ROOT=${TMPDIR}/Builder/repos/futurerestore/.github/workflows
export DEP_ROOT=${TMPDIR}/Builder/repos/futurerestore/dep_root
export BASE=${TMPDIR}/Builder/repos/futurerestore/

#sed -i 's/deb\.debian\.org/ftp.de.debian.org/g' /etc/apt/sources.list
sed -i \
  -e 's|deb http://deb.debian.org/debian buster main|deb http://archive.debian.org/debian buster main contrib non-free|g' \
  -e 's|deb http://deb.debian.org/debian-security buster/updates main|deb http://archive.debian.org/debian-security buster/updates main contrib non-free|g' \
  -e 's|deb http://deb.debian.org/debian buster-updates main|deb http://archive.debian.org/debian buster-backports main contrib non-free|g' \
  /etc/apt/sources.list
apt-get -qq update
apt-get -yqq dist-upgrade
apt-get install --no-install-recommends -yqq zstd curl gnupg2 lsb-release wget software-properties-common build-essential git autoconf automake libtool-bin pkg-config cmake zlib1g-dev libminizip-dev libpng-dev libreadline-dev libbz2-dev libudev-dev libudev1
cp -RpP /usr/bin/ld /
rm -rf /usr/bin/ld /usr/lib/x86_64-linux-gnu/lib{usb-1.0,png*,readline}.so*
chown -R 0:0 ${BASE}
cd ${BASE}
git submodule update --init --recursive
cd ${WORKFLOW_ROOT}
curl -sO https://apt.llvm.org/llvm.sh
chmod +x llvm.sh
./llvm.sh 15 all
ln -sf /usr/bin/ld.lld-15 /usr/bin/ld
ln -sf /usr/bin/clang-15 /usr/bin/clang
ln -sf /usr/bin/clang++-15 /usr/bin/clang++
# Resolve latest Linux deps from versions index (Release/Debug)
LINUX_DEPS_BASE="https://cdn.cryptiiiic.com/deps/static/Linux/x86_64"
VERSIONS_TXT="$(curl -fsSL ${LINUX_DEPS_BASE}/versions.txt)"

# Expect lines like: LATEST_RELEASE=Linux_x86_64_1720751343_Release.tar.zst
#                    LATEST_DEBUG=Linux_x86_64_1720751343_Debug.tar.zst
LATEST_RELEASE="$(printf '%s\n' "$VERSIONS_TXT" | awk -F= '/^LATEST_RELEASE=/{print $2}')"
LATEST_DEBUG="$(printf '%s\n' "$VERSIONS_TXT" | awk -F= '/^LATEST_DEBUG=/{print $2}')"

# Fallback if keys aren’t present
if [ -z "$LATEST_RELEASE" ] || [ -z "$LATEST_DEBUG" ]; then
  echo "Failed to resolve latest Linux deps. Check ${LINUX_DEPS_BASE}/ for available tarballs." >&2
  exit 1
fi

curl -fSLo Linux_x86_64_Release.tar.zst "${LINUX_DEPS_BASE}/${LATEST_RELEASE}"
curl -fSLo Linux_x86_64_Debug.tar.zst   "${LINUX_DEPS_BASE}/${LATEST_DEBUG}"

# Extract into expected dep_root layout
mkdir -p "${DEP_ROOT}/Linux_x86_64_Release" "${DEP_ROOT}/Linux_x86_64_Debug"
tar --zstd -xvf Linux_x86_64_Release.tar.zst -C "${DEP_ROOT}/Linux_x86_64_Release"
tar --zstd -xvf Linux_x86_64_Debug.tar.zst   -C "${DEP_ROOT}/Linux_x86_64_Debug"

curl -sLO https://github.com/Kitware/CMake/releases/download/v3.23.2/cmake-3.23.2-linux-x86_64.tar.gz &
wait
rm -rf ${DEP_ROOT}/{lib,include} || true
mkdir -p ${DEP_ROOT}/Linux_x86_64_{Release,Debug}
tar xf Linux_x86_64_Release_Latest.tar.zst -C ${DEP_ROOT}/Linux_x86_64_Release &
tar xf Linux_x86_64_Debug_Latest.tar.zst -C ${DEP_ROOT}/Linux_x86_64_Debug &
tar xf linux_fix.tar.zst -C ${TMPDIR}/Builder &
tar xf cmake-3.23.2-linux-x86_64.tar.gz
cp -RpP cmake-3.23.2-linux-x86_64/* /usr/local/ || true
wait
rm -rf *.zst *.gz cmake-* llvm.sh
cd ${WORKFLOW_ROOT}
