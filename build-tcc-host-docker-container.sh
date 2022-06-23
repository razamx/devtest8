#!/usr/bin/env bash

# Copyright (c) 2022, Intel Corporation. All rights reserved.


# ############################################################################

# TODO: Fix local user uid:gid problems: image local user vs container local user.
#       At the moment, container must be same local user that created the image.
#       Last link (below) looks most promising.
#  see: https://stackoverflow.com/questions/57776452/is-it-possible-to-map-a-user-inside-the-docker-container-to-an-outside-user
#  see: https://jtreminio.com/blog/running-docker-containers-as-current-host-user
#  see: https://devops.sentianse.com/blog/docker-run-mirror-host-user


# ############################################################################

# Process and validate arguments supplied on the command-line.

function FncUsage()
{
  echo " ";
  echo "usage: ${BASH_SOURCE[0]##*/} -i image-name:tag [OPTIONS]"
  echo "  -i | --image-name   : Name:Tag of the Docker image to use as base (required)"
  echo "  -b | --build-dir    : Local build folder (defaults to \"build\")"
  echo "  -n | --name         : Name of the Docker container being created (optional)"
  echo "  -h | --help         : This help message"
  echo " ";
  echo "NOTE: The container being created assumes that a copy of these tcc-tools repos:"
  echo " ";
  echo "* libraries.compute.tcc-tools"
  echo "* libraries.compute.tcc-tools.infrastructure"
  echo " ";
  echo "are located in the local build folder specified with the --build-dir option"
  echo "(which defaults to \"build\" and is relative to the location of this script)."
  echo "The tcc repos should be checked out to the branch/tag/commit that is appropriate"
  echo "for performing the build within the container."
  echo " ";
  exit "$1"
}

function FncParseArgs()
{
  while [ "$1" != "" ]; do
    case "$1" in
      (-i | --image-name) dockerImage="$2"; shift; shift;;  # Docker image that is basis for the container
      (-b | --build-dir)  dockerPath="$2";  shift; shift;;  # location of "volume" to attach to the container
      (-n | --name)       dockerName="$2";  shift; shift;;  # set name of the container being created
      (-h | --help) printf "\nDisplaying help\n";  FncUsage 1;; # show usage and exit
      (*)           printf "\nUnknown argument\n"; FncUsage 1;; # show usage and exit
    esac
  done

  # set defaults for optional args
  if [ -z "${dockerPath}" ]; then dockerPath="$(dirname ${BASH_SOURCE[0]})/build"; fi

  # get full pathname of volume to be attached to container
  dockerPath="$(realpath -e "${dockerPath}" 2> /dev/null)"

  # validate all args
  # extract a matching Docker image "name:tag" from available images
  # if a match exists then the provided --image-name is good, else it is bad
  tmpImage="$(docker images -f reference="${dockerImage}" | awk '{if (NR>1) {printf "%s:%s\n",$1,$2}}')"
  if [   -z "${tmpImage}" ];   then printf "\nERROR: bad -i argument\n"; FncUsage 1; fi
  if [ ! -d "${dockerPath}" ]; then printf "\nERROR: bad -b argument\n"; FncUsage 1; fi
  if [   -n "${dockerName}" ]; then
    if ! [[ ${dockerName} =~ ^[a-zA-Z0-9_][a-zA-Z0-9_.-]*$ ]]; then printf "\nERROR: bad -n argument\n"; FncUsage 1; fi
  fi
}
FncParseArgs "$@"


# ############################################################################

# Build base Docker image.

echo "INFO: Creating container based on Docker image named: \"${dockerImage}\""
if [ ! -z "${dockerName}" ]; then
  dockerName="--name ${dockerName}"
fi

# figure out WORKDIR inside the Docker image
dockerWorkDir="$(docker inspect --format='{{json .Config.WorkingDir}}' "${dockerImage}")"
dockerWorkDir="$(printf '%s' "${dockerWorkDir}" | sed -e "s:\"::g")"

# create the container
docker create -ti "${dockerName}" \
              --user "$(id -u):$(id -g)" \
              --volume /etc/timezone:/etc/timezone:ro \
              --volume /etc/localtime:/etc/localtime:ro \
              --volume "${dockerPath}":"${dockerWorkDir}/build":rw \
              "${dockerImage}"
