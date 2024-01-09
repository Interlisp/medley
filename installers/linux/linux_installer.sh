#! /bin/sh

get_distro () {

  
  # try various methods, in order of preference, to detect distro
  # store result in variable '$distro'
  #
  distro=$(lsb_release -i -s 2>/dev/null)
  #
  if test -z "${distro}" -a -e /etc/os-release
  then
    distro=$(awk -F= '$1 == "ID" {print $2}' /etc/os-release)
  fi
  #
  if test -z "${distro}" -a -e /etc/lib/os-release
  then
    distro=$(awk -F= '$1 == "ID" {print $2}' /etc/lib/os-release)
  fi
  #
  if test -z "${distro}" -a -e /etc/lsb-release
  then
    distro=$(awk -F= '$1 == "DISTRIB_ID" {print $2}' /etc/lib/lsb-release)
  fi
  #
  if test -z "${distro}" -a -e /etc/debian_version
  then
    distro="debian"
  fi
  #
  ls /etc/*-release >/dev/null
  if test $? -eq 0 -a -z "${distro}"
  then
    distro=$(cat /etc/*-release | awk -F= '$1 == "ID" {print $2}' | tail -n 1)
  fi
  #
  if test -z "${distro}"
  then
    distro="unknown"
  fi

  # convert to lowercase
  distro=$(printf '%s\n' "${distro}" | LC_ALL=C tr '[:upper:]' '[:lower:]')

  echo ${distro}

}

is_pkg_installed_cmd () {
  distro="$1"
  if test -z ${distro};
  then
    distro="$(get_distro)"
  fi
  case "${distro}" in

    alpine)
      cmd="apk info"
      ;;

    arch | endeavouros | manjaro)
      cmd="pacman -Q"
      ;;
    debian | mint | mxlinux | popos | raspian | ubuntu | zorinos)
      cmd="dpkg -l"
      ;;

    centos | fedora)
      cmd="rpm -qa"
      ;;

    opensuse)
      cmd="zypper search -is"
      ;;

    *)
      echo "Warning: do not know which package manager to use for distro: ${distro}"
      ;;

  esac

  echo "${cmd}"
}

distro=$(get_distro)
echo "Distro is ${distro}"
is_installed=$(is_pkg_installed_cmd "${distro}")
echo "is_installed cmd is: ${is_installed}"

