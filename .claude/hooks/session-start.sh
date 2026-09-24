#!/bin/bash
# Prepare a remote Claude Code session to compile and to test this project.
#
# A local machine gets its tools from the Nix shell in flake.nix. Therefore this
# hook stops immediately when the session is not a remote session.
#
# The hook gives the session the versions of `.tool-versions`. The apt packages
# of the container are older, so each tool comes from a prebuilt archive.
# Therefore a command in a session and the same command in the workflow give the
# same result.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# Keep these versions in agreement with `.tool-versions` and with
# `.github/workflows/check.yml`.
OTP_VERSION="29.1"
ELIXIR_VERSION="1.20.4"
NODE_VERSION="24.20.0"

# The OTP release of the Elixir build. Elixir publishes one build for each OTP
# release, and the build must agree with the Erlang archive.
OTP_RELEASE="29"

OTP_DIR="/opt/otp"
ELIXIR_DIR="/opt/elixir"
NODE_DIR="/opt/node"

# The Erlang archive and the Node archive are builds for one target. A container
# of a different target needs different archives, and the versions above then
# give a file that does not exist.
if [ "$(uname -m)" != "x86_64" ] || ! grep -q 'VERSION_ID="24.04"' /etc/os-release; then
  echo "This hook needs Ubuntu 24.04 on x86_64. See docs/development.md." >&2
  exit 1
fi

# The tools that read an archive. The container gives libncurses and libssl,
# which Erlang needs at run time.
if ! command -v curl >/dev/null 2>&1 || ! command -v unzip >/dev/null 2>&1 ||
  ! command -v xz >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq curl unzip xz-utils
fi

# Erlang. The archive holds dialyzer, which `mix check` needs. `Install` writes
# the absolute path of the directory into each start script.
if [ "$(cat "${OTP_DIR}/releases/${OTP_RELEASE}/OTP_VERSION" 2>/dev/null || true)" != "${OTP_VERSION}" ]; then
  tmp_dir="$(mktemp -d)"
  curl -sSfL -o "${tmp_dir}/otp.tar.gz" \
    "https://builds.hex.pm/builds/otp/amd64/ubuntu-24.04/OTP-${OTP_VERSION}.tar.gz"
  rm -rf "${OTP_DIR}"
  mkdir -p "${OTP_DIR}"
  tar -xzf "${tmp_dir}/otp.tar.gz" --strip-components=1 -C "${OTP_DIR}"
  (cd "${OTP_DIR}" && ./Install -minimal "${OTP_DIR}" >/dev/null)
  rm -rf "${tmp_dir}"
fi

export PATH="${OTP_DIR}/bin:${PATH}"

# Elixir. The build is one zip archive for the OTP release above.
if [ "$("${ELIXIR_DIR}/bin/elixir" --short-version 2>/dev/null || true)" != "${ELIXIR_VERSION}" ]; then
  tmp_dir="$(mktemp -d)"
  curl -sSfL -o "${tmp_dir}/elixir.zip" \
    "https://builds.hex.pm/builds/elixir/v${ELIXIR_VERSION}-otp-${OTP_RELEASE}.zip"
  rm -rf "${ELIXIR_DIR}"
  mkdir -p "${ELIXIR_DIR}"
  unzip -q -o "${tmp_dir}/elixir.zip" -d "${ELIXIR_DIR}"
  rm -rf "${tmp_dir}"
fi

export PATH="${ELIXIR_DIR}/bin:${PATH}"

# Node. The container gives an older Node, and the type check and the tests must
# run on the version of `.tool-versions`.
if [ "$("${NODE_DIR}/bin/node" --version 2>/dev/null || true)" != "v${NODE_VERSION}" ]; then
  tmp_dir="$(mktemp -d)"
  curl -sSfL -o "${tmp_dir}/node.tar.xz" \
    "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz"
  rm -rf "${NODE_DIR}"
  mkdir -p "${NODE_DIR}"
  tar -xJf "${tmp_dir}/node.tar.xz" --strip-components=1 -C "${NODE_DIR}"
  rm -rf "${tmp_dir}"
fi

export PATH="${NODE_DIR}/bin:${PATH}"

# The container gives a latin1 name encoding, and Elixir expects utf8. The
# language gives the tools a utf8 output.
export ELIXIR_ERL_OPTIONS="+fnu"
export LANG="C.UTF-8"

# Keep the tools on the path for each command of the session.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  {
    echo "export PATH=\"${OTP_DIR}/bin:${ELIXIR_DIR}/bin:${NODE_DIR}/bin:\$PATH\""
    echo 'export ELIXIR_ERL_OPTIONS="+fnu"'
    echo 'export LANG="C.UTF-8"'
  } >> "${CLAUDE_ENV_FILE}"
fi

# The browser tests of `mix test --only e2e` use the Chromium of the container.
# Playwright does not find it at its own path, so the tests read the path from
# EXPRESSO_CHROMIUM. `docs/development.md` gives the details.
if [ -x /opt/pw-browsers/chromium ]; then
  export EXPRESSO_CHROMIUM="/opt/pw-browsers/chromium"
  if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    echo 'export EXPRESSO_CHROMIUM="/opt/pw-browsers/chromium"' >> "${CLAUDE_ENV_FILE}"
  fi
fi

cd "${CLAUDE_PROJECT_DIR:-.}"

# An archive of Hex or of rebar from a different OTP release does not load.
# Therefore the hook writes the archive again for each toolchain.
mix local.hex --force
mix local.rebar --force
mix deps.get
mix compile

# The tools for the presenter script. `mix compile` does not need them, and the
# type check and the tests do. package.json pins each version.
npm install --no-audit --no-fund

echo "Expresso: $(elixir --version | tail -1), $(node --version) is ready."
