# shellcheck shell=bash disable=SC2148

__check_os() {
  local majorversion system_ok=1 install_bash=0 install_coreutils=0 install_gawk=0
  local install_podman=0 install_sed=0 __mokostype=linux

  if [[ -d /System/Library/CoreServices ]]; then
    [[ -e /opt/homebrew/bin/bash ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
    # We're on macOS, check for a recent Bash
    if command -v bash &>/dev/null; then
      majorversion=$(bash --version | head -n 1 | sed 's/^.*version \([0-9]*\).*/\1/')
    else
      echo "No version of Bash was found which is strange. Aborting."
      exit 1
    fi
    if [[ ${majorversion} -lt 5 ]]; then
      install_bash=1
      system_ok=0
    fi
    if ! command -v tac &>/dev/null; then
      install_coreutils=1
      system_ok=0
    fi
    if ! command -v gawk &>/dev/null; then
      install_gawk=1
      system_ok=0
    fi
    if ! command -v gsed &>/dev/null; then
      install_sed=1
      system_ok=0
    fi
    if ! command -v podman &>/dev/null; then
      install_podman=1
      system_ok=0
    fi

    if [[ ${system_ok} -eq 0 ]]; then
      echo "Your system requires some extra packages to be installed."
      echo "This script can install them for you."
      echo
      read -r -p 'Install extra packages? (y/N) ' ans
      if [[ ${ans} == "y" ]]; then
        if ! command -v brew &>/dev/null; then
          echo 'Homebrew is required to install extra packages.'
          echo 'You can install this yourself by following the instructions at https://brew.sh'
          echo
          read -r -p 'Should I install Homebrew now? (y/N) ' ans
          if [[ ${ans} == "y" ]]; then
            # Install Homebrew
            echo -n "Installing Homebrew, with:"
            echo " /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            echo
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            retval=$?
            if [[ retval -ne 0 ]]; then
              echo "Homebrew install failed."
              echo "Please try to install Homebrew manually using the above commmand."
              exit 1
            fi
            if [[ ! -e /opt/homebrew/bin/brew ]]; then
              echo "Homebrew did not seem install to /opt/homebrew."
              echo "Mok expects 'brew' to be in /opt/homebrew/bin/brew but it's not there."
              echo "Cannot continue. Please report this issue on GitHub."
              exit 1
            fi
            eval "$(/opt/homebrew/bin/brew shellenv)"
          else
            echo "Aborting due to missing 'Homebrew'."
            exit 1
          fi
        fi
        if [[ ! -e /opt/homebrew/bin/brew ]]; then
          echo "Mok expects 'brew' to be in /opt/homebrew/bin/brew but it's not there."
          echo "Cannot continue. Please report this issue on GitHub."
          exit 1
        fi
        eval "$(/opt/homebrew/bin/brew shellenv)"
        if [[ ${install_bash} -eq 1 ]]; then
          read -r -p 'Bash 5 is not installed. Install? (y/N) ' ans
          if [[ ${ans} == "y" ]]; then
            brew install bash
          else
            echo "Aborting due to missing 'Bash 5'."
            exit 1
          fi
        fi
        if [[ ${install_coreutils} -eq 1 ]]; then
          read -r -p 'Coreutils is not installed. Install? (y/N) ' ans
          if [[ ${ans} == "y" ]]; then
            brew install coreutils
          else
            echo "Aborting due to missing 'coreutils'."
            exit 1
          fi
        fi
        if [[ ${install_gawk} -eq 1 ]]; then
          read -r -p 'Gawk is not installed. Install? (y/N) ' ans
          if [[ ${ans} == "y" ]]; then
            brew install gawk
          else
            echo "Aborting due to missing 'gawk'."
            exit 1
          fi
        fi
        if [[ ${install_sed} -eq 1 ]]; then
          read -r -p 'GNU-Sed is not installed. Install? (y/N) ' ans
          if [[ ${ans} == "y" ]]; then
            brew install gnu-sed
          else
            echo "Aborting due to missing 'sed'."
            exit 1
          fi
        fi
        if [[ ${install_podman} -eq 1 ]]; then
          read -r -p 'Podman is not installed. Install? (y/N) ' ans
          if [[ ${ans} == "y" ]]; then
            brew install podman
          else
            echo "Aborting due to missing 'podman'."
            exit 1
          fi
        fi
      else
        echo "Aborting due to missing packages."
        exit 1
      fi
    fi
  fi
}

[[ __homebrew -ne 1 ]] && __check_os

[[ -d /System/Library/CoreServices && -e /opt/homebrew/bin/bash && __homebrew -ne 1 ]] && {
  eval "$(/opt/homebrew/bin/brew shellenv)"
  export __mokostype=macos
  export __homebrew=1
  sed() {
    gsed "$@"
  }
  export -f sed
  exec bash "$0" "$@"
}

__mokostype="${__mokostype:-linux}"
