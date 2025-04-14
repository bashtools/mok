# shellcheck shell=bash disable=SC2148

declare __mokostype

set_arch() {
  if [[ ${__mokostype} == "linux" ]]; then
    # Is this machine x86 or arm?
    if [[ $(uname -m) == "x86_64" ]]; then
      export __mokarch=x86_64
    elif [[ $(uname -m) == "aarch64" ]]; then
      export __mokarch=arm64
    fi
  elif [[ ${__mokostype} == "macos" ]]; then
    # Is this machine x86 or arm?
    if [[ $(uname -m) == "x86_64" ]]; then
      export __mokarch=x86_64
    elif [[ $(uname -m) == "arm64" ]]; then
      export __mokarch=arm64
    fi
  fi
}

set_arch
