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
  echo "usage: ${BASH_SOURCE[0]##*/} -i image-name [OPTIONS]"
  echo "  -i | --image-name   : name of the Docker image to be created (required)"
  echo "  -p | --docker-path  : Docker file \"context\" (defaults to \".\")"
  echo "  -f | --docker-file  : Dockerfile script name (defaults to \"Dockerfile\")"
  echo "  -h | --help         : This help message"
  echo " ";
  exit "$1"
}

function FncParseArgs()
{
  while [ "$1" != "" ]; do
    case "$1" in
      (-i | --image-name)   dockerImage="$2"; shift; shift;;  # assign Docker image name
      (-p | --docker-path)  dockerPath="$2";  shift; shift;;  # get Dockerfile context
      (-f | --docker-file)  dockerFile="$2";  shift; shift;;  # get name of Dockerfile
      (-h | --help)  printf "\nDisplaying help\n";  FncUsage 1;; # show usage and exit
      (*)            printf "\nUnknown argument\n"; FncUsage 1;; # show usage and exit
    esac
  done

  # set defaults for optional args
  if [ -z "${dockerPath}" ]; then dockerPath="."; fi
  # we actually default to ${dockerPath}/DockerFile -> "context"/Dockerfile
  if [ -z "${dockerFile}" ]; then dockerFile="Dockerfile"; fi

  # validate all args
  if [   -z "${dockerImage}" ]; then printf "\nERROR: bad -i argument\n"; FncUsage 1; fi
  if [ ! -d "${dockerPath}" ];  then printf "\nERROR: bad -p argument\n"; FncUsage 1; fi
  if [ ! -r "${dockerFile}" ];  then printf "\nERROR: bad -f argument\n"; FncUsage 1; fi
}
FncParseArgs "$@"


# ############################################################################

# Build base Docker image.

echo "INFO: Building Docker image named: \"${dockerImage}\""
docker build -t ${dockerImage}:base --build-arg USER_UID="$(id -u)" --no-cache -f ${dockerFile} ${dockerPath}
