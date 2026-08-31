#!/bin/bash
# Prepare a remote Claude Code session to compile and to test this project.
#
# A local machine gets its tools from the Nix shell in flake.nix. Therefore this
# hook stops immediately when the session is not a remote session.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# The Elixir build must agree with the OTP release of the Erlang package.
ELIXIR_VERSION="1.18.4"
OTP_RELEASE="25"
ELIXIR_DIR="/opt/elixir"

# Erlang. The apt package gives OTP 25.
if ! command -v erl >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq erlang-nox erlang-dev unzip curl
fi

# Elixir. The apt package gives 1.14, and mix.exs needs 1.17 or later. Therefore
# take the build that the Elixir release gives for this OTP release.
if [ ! -x "${ELIXIR_DIR}/bin/elixir" ]; then
  tmp_dir="$(mktemp -d)"
  curl -sSfL -o "${tmp_dir}/elixir.zip" \
    "https://github.com/elixir-lang/elixir/releases/download/v${ELIXIR_VERSION}/elixir-otp-${OTP_RELEASE}.zip"
  mkdir -p "${ELIXIR_DIR}"
  unzip -q -o "${tmp_dir}/elixir.zip" -d "${ELIXIR_DIR}"
  rm -rf "${tmp_dir}"
fi

export PATH="${ELIXIR_DIR}/bin:${PATH}"

# The container gives a latin1 name encoding, and Elixir expects utf8.
export ELIXIR_ERL_OPTIONS="+fnu"

# Keep the tools on the path for each command of the session.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  {
    echo "export PATH=\"${ELIXIR_DIR}/bin:\$PATH\""
    echo 'export ELIXIR_ERL_OPTIONS="+fnu"'
  } >> "${CLAUDE_ENV_FILE}"
fi

cd "${CLAUDE_PROJECT_DIR:-.}"

mix local.hex --force --if-missing
mix local.rebar --force --if-missing
mix deps.get
mix compile

echo "Expresso: $(elixir --version | tail -1) is ready."
