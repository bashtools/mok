__install_extra_packages() {
  # check for Homebrew
  if ! command -v brew &>/dev/null; then
    # Install Homebrew
    # /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    for i in $(seq 1 10); do
      echo -n "."
      sleep .2
    done
  fi
}

__check_os() {
  local majorversion system_ok=1 install_bash=0

  if [[ -d /System/Library/CoreServices ]]; then
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

    if [[ ${system_ok} -eq 0 ]]; then
      echo "Your system requires some extra packages to be installed."
      echo "This script can install them for you using Homebrew."
      echo
      read -r -p 'Install extra packages (y/N) ' ans
      if [[ ${ans} == "y" ]]; then
        __install_extra_packages
      else
        echo "Aborting due to missing packages."
        exit 1
      fi
    fi
  fi
}

__check_os
