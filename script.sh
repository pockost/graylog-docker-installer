#!/usr/bin/env bash

# A best practices Bash script template with many useful functions. This file
# sources in the bulk of the functions from the source.sh file which it expects
# to be in the same directory. Only those functions which are likely to need
# modification are present in this file. This is a great combination if you're
# writing several scripts! By pulling in the common functions you'll minimise
# code duplication, as well as ease any potential updates to shared functions.

# A better class of script...
set -o errexit          # Exit on most errors (see the manual)
set -o errtrace         # Make sure any error trap is inherited
set -o nounset          # Disallow expansion of unset variables
set -o pipefail         # Use last non-zero exit code in a pipeline
#set -o xtrace          # Trace the execution of the script (debug)

# DESC: Usage help
# ARGS: None
# OUTS: None
function script_usage() {
    cat << EOF
Usage:
     -h|--help                  Displays this help
     -v|--verbose               Displays verbose output
    -nc|--no-colour             Disables colour output
    -y|--yes                    Automatic yes to prompts
EOF
}


# DESC: Parameter parser
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: Variables indicating command-line parameters and options
function parse_params() {
    local param
    APT_YES_OPTION=""
    while [[ $# -gt 0 ]]; do
        param="$1"
        shift
        case $param in
            -h|--help)
                script_usage
                exit 0
                ;;
            -v|--verbose)
                verbose=true
                ;;
            -nc|--no-colour)
                no_colour=true
                ;;
            -y|--yes)
                cron=true
                assume_yes=true
                APT_YES_OPTION="-y"
                ;;
            *)
                script_exit "Invalid parameter was provided: $param" 2
                ;;
        esac
    done

}

function welcome() {
  pretty_print "Welcome to graylog installer provided by POCKOST SAS"
  pretty_print ""
  pretty_print "This script will"
  pretty_print ""
  pretty_print " - Install docker engine"
  pretty_print " - Install docker-compose"
  pretty_print " - Configure some kernel parameter for Elasticsearch to work"
  pretty_print " - Start a graylog project within docker"
  pretty_print ""

  pretty_print "Are you sure ? [N/y]" $fg_blue true
  if [[ -z ${assume_yes-} ]]; then
    read PROCEED
  else
    PROCEED=yes
  fi
  case ${PROCEED:-"n"} in
    [Yy]* ) echo "Starting installation" ;;
    [Nn]* ) script_exit "Exiting..." 1 ;;
  esac

  pretty_print "Check we are root or sudo is installed"
  check_superuser || script_exit "Please install sudo or run as root"

}

function install_docker() {
  verbose_print "Check OS Distro is Debian"

  OS_DISTRO=$( awk '{ print $1 }' /etc/issue )

  echo
  if [ "${OS_DISTRO}" != "Debian" ] ; then
    pretty_print "This script only work on debian" $fg_red
    script_exit "Exiting ..." 2
  fi

  verbose_print "Start installing docker"
  pretty_print "Start docker installation"

  verbose_print "Update APT source"
  run_as_root apt-get update

  verbose_print "Install prerequisite"
  run_as_root apt-get install ${APT_YES_OPTION} apt-transport-https ca-certificates curl gnupg2 software-properties-common

  verbose_print "Add docker apt PGP key"
  run_as_root bash -c 'curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -'

  verbose_print "Add docker apt repository"
  run_as_root add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"

  verbose_print "Update APT source"
  run_as_root apt-get update

  verbose_print "Install docker"
  run_as_root apt-get install ${APT_YES_OPTION} docker-ce docker-ce-cli containerd.io

  verbose_print "Add current user in docker group"
  run_as_root adduser -quiet $USER docker

  pretty_print "Docker installation completed" $fg_magenta

  pretty_print "Start docker-compose installation"

  verbose_print "Download docker-compose script"
  run_as_root curl -L "https://github.com/docker/compose/releases/download/1.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

  verbose_print "Chmod docker compose"
  run_as_root chmod +x /usr/local/bin/docker-compose

  pretty_print "docker-compose installation completed" $fg_magenta
}

function configure_kernel() {
  pretty_print "Configuring kernel"

  pretty_print "Set vm.max_map_count to 262144"
  run_as_root sysctl -w vm.max_map_count=262144
  run_as_root bash -c "echo vm.max_map_count=262144 | tee /etc/sysctl.d/999-graylog-max_map_count.cfg"

  pretty_print "Set vm.swappiness to 1"
  run_as_root bash -c "echo vm.swappiness=1 | tee /etc/sysctl.d/999-graylog-swappiness.cfg"
  run_as_root sysctl -w vm.swappiness=1

  pretty_print "Kernel configuration completed" $fg_magenta
}


function install_graylog_docker() {
  pretty_print "Install graylog docker compose project"

  GRAYLOG_PASSWORD_SECRET=$( openssl rand -base64 16 )

  pretty_print "Enter desired graylog root password [admin]" $fg_blue true
  read GRAYLOG_ROOT_PASSWORD
  GRAYLOG_ROOT_PASSWORD=${GRAYLOG_ROOT_PASSWORD:-admin}

  verbose_print "Root password will be ${GRAYLOG_ROOT_PASSWORD}"
  GRAYLOG_ROOT_PASSWORD_SHA2=$( echo $GRAYLOG_ROOT_PASSWORD| tr -d '\n' | sha256sum | cut -d" " -f1 )

  verbose_print "SHA256 root password is ${GRAYLOG_ROOT_PASSWORD_SHA2}"

  verbose_print "Get external IP"
  GUESS_IP=$( ip a s |grep inet|grep -v inet6|grep -v 172.1|grep -v 127.0.0.1|grep -v '10.0.2.15'|awk '{ print $2 }'|cut -d'/' -f1)
  pretty_print "What is your external IP ? [$GUESS_IP]" $fg_blue true
  if [[ -z ${assume_yes-} ]]; then
    read IP
  fi
  IP=${IP:-${GUESS_IP}}

  verbose_print "External IP will be $IP"


	verbose_print "Create project directory"
  if [ -e $HOME/docker/graylog ]
  then
    pretty_print "Docker project already exist override ? [N/y]" $fg_blue true
    if [[ -z ${assume_yes-} ]]; then
      read OVERRIDE
    else
      OVERRIDE=yes
    fi
    case ${OVERRIDE:-"n"} in
      [Yy]* ) echo "Starting installation" ;;
      * ) script_exit "Unable to create $HOME/docker/graylog directory. File exist" 3 ;;
    esac
  fi
  mkdir -p $HOME/docker/graylog

  cat <<EOF > $HOME/docker/graylog/docker-compose.yaml
version: '2'
services:
  # MongoDB: https://hub.docker.com/_/mongo/
  mongodb:
    image: mongo:3
    volumes:
      - ./data/mongodb:/data/db
  # Elasticsearch: https://www.elastic.co/guide/en/elasticsearch/reference/6.6/docker.html
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch-oss:6.6.1
    environment:
      - http.host=0.0.0.0
      - transport.host=localhost
      - network.host=0.0.0.0
      - cluster.name=graylog
      # - xpack.security.enabled=false
    volumes:
      - ./data/elasticsearch/data:/data
    ulimits:
      memlock:
        soft: -1
        hard: -1
    mem_limit: 1g
  # Graylog: https://hub.docker.com/r/graylog/graylog/
  graylog:
    image: graylog/graylog:3.0
    environment:
      # CHANGE ME (must be at least 16 characters)!
      - GRAYLOG_PASSWORD_SECRET=${GRAYLOG_PASSWORD_SECRET}
      # Password: ${GRAYLOG_ROOT_PASSWORD}
      - GRAYLOG_ROOT_PASSWORD_SHA2=${GRAYLOG_ROOT_PASSWORD_SHA2}
      - GRAYLOG_HTTP_EXTERNAL_URI=http://${IP}:9000/
    links:
      - mongodb:mongo
      - elasticsearch
    depends_on:
      - mongodb
      - elasticsearch
    volumes:
      - ./data/graylog/:/etc/graylog/
    ports:
      # Graylog web interface and REST API
      - 9000:9000
      # Syslog TCP
      - 514:514
      # Syslog UDP
      - 514:514/udp
      # GELF TCP
      - 12201:12201
      # GELF UDP
      - 12201:12201/udp
  maxmind-updater:
    image: pockost/maxmind-updater
    volumes:
      - ./data/graylog/server:/database
EOF

  cat <<EOF > $HOME/docker/graylog/viewlogs.sh
#!/bin/bash
docker-compose logs -f --tail=1000 \$1
EOF
  chmod +x $HOME/docker/graylog/viewlogs.sh

  pretty_print "Download docker image"
  pushd $HOME/docker/graylog
  docker-compose pull

  pretty_print "Start Graylog..."
  docker-compose up -d

  pretty_print "Wait to be up..."
  sleep 10
  while [ true ]
  do
    STATUS=$( docker ps --format '{{.Status}}' --filter=name=graylog_graylog | awk '{ print $1 }' )
    READY=$( docker ps --format '{{.Status}}' --filter=name=graylog_graylog | awk '{ print $NF }' )

    echo $STATUS
    echo $READY

    pretty_print "You can view startup logs in $HOME/docker/graylog by running 'bash viewlogs.sh graylog'"
    if [ $STATUS != "Up" ] ; then
      script_exit "Error when starting graylog ... Exiting ..." 5
    fi

    if [ $READY == "(healthy)" ] ; then
      break
    fi

    pretty_print "Current status : $READY"
    sleep 2
  done

  pretty_print "Graylog installation completed" $fg_magenta

}

function display_info() {
  pretty_print "Connexion information are :"
  pretty_print ""
  pretty_print "External IP(s) : $IP" $fg_blue
  pretty_print "Web access : http://${IP}:9000/" $fg_blue
  pretty_print "Admin username : admin" $fg_blue
  pretty_print "Admin password : GRAYLOG_ROOT_PASSWORD" $fg_blue
  pretty_print ""
  pretty_print "Opened port :" $fg_blue
  pretty_print " - 514 (TCP/UDP)"
  pretty_print " - 12201 (TCP/UDP)"
  pretty_print " - 9000 (TCP)"



}

# DESC: Main control flow
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: None
function main() {
    # shellcheck source=source.sh
    source "$(dirname "${BASH_SOURCE[0]}")/source.sh"

    trap script_trap_err ERR
    trap script_trap_exit EXIT

    script_init "$@"
    parse_params "$@"
    cron_init
    colour_init
    lock_init system

    welcome
    install_docker
    configure_kernel
    install_graylog_docker
    display_info
}


# Make it rain
main "$@"

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
