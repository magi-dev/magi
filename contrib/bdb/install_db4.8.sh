#!/bin/sh
# Copyright (c) 2017-2021 The Bitcoin Core developers
# Copyright (c) 2024 The Magi Core developers
# Distributed under the MIT software license, see the accompanying
# file COPYING or http://www.opensource.org/licenses/mit-license.php.

# Install libdb4.8 (Berkeley DB).

export LC_ALL=C
set -e

# Set the magi root directory
BASE_DIR=$(dirname "$(pwd -P)")

if [ "$0" != "../contrib/bdb/install_db4.8.sh" ]; then
  echo "Usage: $0 [<base_path>] [<extra-bdb-configure-flag> ...]"
  echo
  echo "Must run the script from the magi src directory"
  exit 1
fi

if [ -z "${1}" ]; then
  BDB_PREFIX="${BASE_DIR}/depends/build/bdb"
else
  BDB_PREFIX="$1"; shift;
fi

BDB_VERSION='db-4.8.30.NC'
BDB_HASH='12edc0df75bf9abd7f82f821795bcee50f42cb2e5f76a6a281b85732798364ef'
BDB_URL="https://download.oracle.com/berkeley-db/${BDB_VERSION}.tar.gz"

check_exists() {
  command -v "$1" >/dev/null
}

sha256_check() {
  # Args: <sha256_hash> <filename>
  #
  if [ "$(uname)" = "FreeBSD" ]; then
    # sha256sum exists on FreeBSD, but takes different arguments than the GNU version
    sha256 -c "${1}" "${2}"
  elif check_exists sha256sum; then
    echo "${1} ${2}" | sha256sum -c
  elif check_exists sha256; then
    echo "${1} ${2}" | sha256 -c
  else
    echo "${1} ${2}" | shasum -a 256 -c
  fi
}

http_get() {
  # Args: <url> <filename> <sha256_hash>
  #
  # It's acceptable that we don't require SSL here because we manually verify
  # content hashes below.
  #
  if [ -f "${2}" ]; then
    echo "File ${2} already exists; not downloading again"
  elif check_exists curl; then
    curl --insecure --retry 5 "${1}" -o "${2}"
  elif check_exists wget; then
    wget --no-check-certificate "${1}" -O "${2}"
  else
    echo "Simple transfer utilities 'curl' and 'wget' not found. Please install one of them and try again."
    exit 1
  fi

  sha256_check "${3}" "${2}"
}

# Ensure the commands we use exist on the system
if ! check_exists patch; then
    echo "Command-line tool 'patch' not found. Install patch and try again."
    exit 1
fi

mkdir -p "${BDB_PREFIX}"
http_get "${BDB_URL}" "${BDB_PREFIX}/${BDB_VERSION}.tar.gz" "${BDB_HASH}"
cd "$BDB_PREFIX"
tar -xzf ${BDB_VERSION}.tar.gz -C "$BDB_PREFIX"
cd "${BDB_VERSION}"

# Apply a patch necessary when building with clang and c++11 (see https://community.oracle.com/thread/3952592)
patch --ignore-whitespace -p1 < "${BASE_DIR}/contrib/bdb/bdb.patch"


# The packaged config.guess and config.sub are ancient (2009) and can cause build issues.
# Replace them with modern versions.
CONFIG_GUESS_URL='https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=4550d2f15b3a7ce2451c1f29500b9339430c877f'
CONFIG_GUESS_HASH='c8f530e01840719871748a8071113435bdfdf75b74c57e78e47898edea8754ae'
CONFIG_SUB_URL='https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=4550d2f15b3a7ce2451c1f29500b9339430c877f'
CONFIG_SUB_HASH='3969f7d5f6967ccc6f792401b8ef3916a1d1b1d0f0de5a4e354c95addb8b800e'

rm -f "dist/config.guess"
rm -f "dist/config.sub"

http_get "${CONFIG_GUESS_URL}" dist/config.guess "${CONFIG_GUESS_HASH}"
http_get "${CONFIG_SUB_URL}" dist/config.sub "${CONFIG_SUB_HASH}"

cd build_unix/

"${BDB_PREFIX}/${BDB_VERSION}/dist/configure" \
  --enable-cxx --disable-shared --disable-replication --with-pic --prefix="${BDB_PREFIX}" \
  "${@}"

make install

# Remove the tarball
rm "${BDB_PREFIX}/${BDB_VERSION}.tar.gz"

echo
echo "db-4.8 build complete."
echo "Successfully installed to ${BDB_PREFIX}"
