#!/usr/bin/env bash
# Install one version of Zig into a directory.
#
# Usage: install.sh <version> <directory>
#
# The script downloads the Zig build for this computer from a community mirror
# of ziglang.org. It makes sure of the SHA-256 of the archive, and then it
# unpacks the archive into the directory. The Zig project asks automated
# systems to use the mirrors. Therefore the script uses ziglang.org itself only
# when each mirror fails. It tries the mirrors in a random order, so that no
# mirror gets each request.
set -euo pipefail

version="$1"
directory="$2"

case "$(uname -s)-$(uname -m)" in
  Linux-x86_64) target="x86_64-linux" ;;
  Linux-aarch64 | Linux-arm64) target="aarch64-linux" ;;
  Darwin-x86_64) target="x86_64-macos" ;;
  Darwin-arm64 | Darwin-aarch64) target="aarch64-macos" ;;
  *)
    echo "Zig has no build for $(uname -s) on $(uname -m)." >&2
    exit 1
    ;;
esac

# The SHA-256 of each build, from https://ziglang.org/download/index.json.
# After a change to the version of Zig in .tool-versions, add the new sums here.
case "${version}-${target}" in
  0.16.0-x86_64-linux) sha256="70e49664a74374b48b51e6f3fdfbf437f6395d42509050588bd49abe52ba3d00" ;;
  0.16.0-aarch64-linux) sha256="ea4b09bfb22ec6f6c6ceac57ab63efb6b46e17ab08d21f69f3a48b38e1534f17" ;;
  0.16.0-x86_64-macos) sha256="0387557ed1877bc6a2e1802c8391953baddba76081876301c522f52977b52ba7" ;;
  0.16.0-aarch64-macos) sha256="b23d70deaa879b5c2d486ed3316f7eaa53e84acf6fc9cc747de152450d401489" ;;
  *)
    echo "The script has no SHA-256 of Zig ${version} for ${target}." >&2
    echo "Add it from https://ziglang.org/download/index.json." >&2
    exit 1
    ;;
esac

file="zig-${target}-${version}.tar.xz"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

# ziglang.org gives the list of the mirrors. When it does not answer, the script
# uses this copy of the list of 2026-09-27.
fallback_mirrors="https://pkg.hexops.org/zig
https://zigmirror.hryx.net/zig
https://zig.linus.dev/zig
https://zig.squirl.dev
https://zig.mirror.mschae23.de/zig
https://ziglang.freetls.fastly.net
https://zig.tilok.dev
https://zig-mirror.tsimnet.eu/zig
https://zig.karearl.com/zig
https://pkg.earth/zig
https://fs.liujiacai.net/zigbuilds
https://zigmirror.com
https://zig.chainsafe.dev
https://zig.savalione.com
https://zig.bcr.ist
https://zig.vortan.dev/zig"

mirrors="$(curl -sSfL --max-time 30 https://ziglang.org/download/community-mirrors.txt ||
  printf '%s\n' "${fallback_mirrors}")"

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d ' ' -f 1
  else
    shasum -a 256 "$1" | cut -d ' ' -f 1
  fi
}

# Download the archive from one address, and make sure of its SHA-256. The
# arguments after the address go to curl.
fetch() {
  local url="$1"
  shift
  if ! curl -sSfL --connect-timeout 15 --max-time 600 "$@" -o "${tmp_dir}/${file}" "${url}"; then
    echo "The download from ${url} failed." >&2
    return 1
  fi
  if [ "$(sha256_of "${tmp_dir}/${file}")" != "${sha256}" ]; then
    echo "The archive from ${url} has a different SHA-256." >&2
    return 1
  fi
}

# A mirror that gives less than 500 KB/s for 20 seconds fails, and the script
# tries the next mirror. On 2026-09-27, a mirror took 5 minutes for the 55 MB of
# Zig 0.16.0, and another mirror took 21 seconds.
found=""
while IFS= read -r mirror; do
  echo "Trying ${mirror}"
  # The mirrors ask each client to give its name in the parameter `source`.
  if fetch "${mirror}/${file}?source=github-rellen-expresso" --speed-limit 500000 --speed-time 20; then
    found="${mirror}"
    break
  fi
done < <(printf '%s\n' "${mirrors}" | awk 'BEGIN { srand() } NF { print rand() "\t" $0 }' |
  sort -n | cut -f 2-)

# The last source has no limit of speed, so that a slow network still gives Zig.
if [ -z "${found}" ]; then
  echo "Each mirror failed. Trying ziglang.org." >&2
  if ! fetch "https://ziglang.org/download/${version}/${file}"; then
    echo "No source gave ${file} with the correct SHA-256." >&2
    exit 1
  fi
fi

rm -rf "${directory}"
mkdir -p "${directory}"
tar -xJf "${tmp_dir}/${file}" --strip-components=1 -C "${directory}"
echo "Zig $("${directory}/zig" version) is in ${directory}."
