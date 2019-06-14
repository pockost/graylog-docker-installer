#!/usr/bin/env bash

# A best practices Bash script template with many useful functions. This file
# combines the source.sh & script.sh files into a single script. If you want
# your script to be entirely self-contained then this should be what you want!

# A better class of script...
set -o errexit          # Exit on most errors (see the manual)
set -o errtrace         # Make sure any error trap is inherited
set -o nounset          # Disallow expansion of unset variables
set -o pipefail         # Use last non-zero exit code in a pipeline
#set -o xtrace          # Trace the execution of the script (debug)

# DESC: Handler for unexpected errors
# ARGS: $1 (optional): Exit code (defaults to 1)
# OUTS: None
function script_trap_err() {
    local exit_code=1

    # Disable the error trap handler to prevent potential recursion
    trap - ERR

    # Consider any further errors non-fatal to ensure we run to completion
    set +o errexit
    set +o pipefail

    # Validate any provided exit code
    if [[ ${1-} =~ ^[0-9]+$ ]]; then
        exit_code="$1"
    fi

    # Output debug data if in Cron mode
    if [[ -n ${cron-} ]]; then
        # Restore original file output descriptors
        if [[ -n ${script_output-} ]]; then
            exec 1>&3 2>&4
        fi

        # Print basic debugging information
        printf '%b\n' "$ta_none"
        printf '***** Abnormal termination of script *****\n'
        printf 'Script Path:            %s\n' "$script_path"
        printf 'Script Parameters:      %s\n' "$script_params"
        printf 'Script Exit Code:       %s\n' "$exit_code"

        # Print the script log if we have it. It's possible we may not if we
        # failed before we even called cron_init(). This can happen if bad
        # parameters were passed to the script so we bailed out very early.
        if [[ -n ${script_output-} ]]; then
            printf 'Script Output:\n\n%s' "$(cat "$script_output")"
        else
            printf 'Script Output:          None (failed before log init)\n'
        fi
    fi

    # Exit with failure status
    exit "$exit_code"
}


# DESC: Handler for exiting the script
# ARGS: None
# OUTS: None
function script_trap_exit() {
    cd "$orig_cwd"

    # Remove Cron mode script log
    if [[ -n ${cron-} && -f ${script_output-} ]]; then
        rm "$script_output"
    fi

    # Remove script execution lock
    if [[ -d ${script_lock-} ]]; then
        rmdir "$script_lock"
    fi

    # Restore terminal colours
    printf '%b' "$ta_none"
}


# DESC: Exit script with the given message
# ARGS: $1 (required): Message to print on exit
#       $2 (optional): Exit code (defaults to 0)
# OUTS: None
function script_exit() {
    if [[ $# -eq 1 ]]; then
        printf '%s\n' "$1"
        exit 0
    fi

    if [[ ${2-} =~ ^[0-9]+$ ]]; then
        printf '%b\n' "$1"
        # If we've been provided a non-zero exit code run the error trap
        if [[ $2 -ne 0 ]]; then
            script_trap_err "$2"
        else
            exit 0
        fi
    fi

    script_exit 'Missing required argument to script_exit()!' 2
}


# DESC: Generic script initialisation
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: $orig_cwd: The current working directory when the script was run
#       $script_path: The full path to the script
#       $script_dir: The directory path of the script
#       $script_name: The file name of the script
#       $script_params: The original parameters provided to the script
#       $ta_none: The ANSI control code to reset all text attributes
# NOTE: $script_path only contains the path that was used to call the script
#       and will not resolve any symlinks which may be present in the path.
#       You can use a tool like realpath to obtain the "true" path. The same
#       caveat applies to both the $script_dir and $script_name variables.
function script_init() {
    # Useful paths
    readonly orig_cwd="$PWD"
    readonly script_path="${BASH_SOURCE[0]}"
    readonly script_dir="$(dirname "$script_path")"
    readonly script_name="$(basename "$script_path")"
    readonly script_params="$*"

    # Important to always set as we use it in the exit handler
    readonly ta_none="$(tput sgr0 2> /dev/null || true)"
}


# DESC: Initialise colour variables
# ARGS: None
# OUTS: Read-only variables with ANSI control codes
# NOTE: If --no-colour was set the variables will be empty
function colour_init() {
    if [[ -z ${no_colour-} ]]; then
        # Text attributes
        readonly ta_bold="$(tput bold 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly ta_uscore="$(tput smul 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly ta_blink="$(tput blink 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly ta_reverse="$(tput rev 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly ta_conceal="$(tput invis 2> /dev/null || true)"
        printf '%b' "$ta_none"

        # Foreground codes
        readonly fg_black="$(tput setaf 0 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_blue="$(tput setaf 4 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_cyan="$(tput setaf 6 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_green="$(tput setaf 2 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_magenta="$(tput setaf 5 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_red="$(tput setaf 1 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_white="$(tput setaf 7 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly fg_yellow="$(tput setaf 3 2> /dev/null || true)"
        printf '%b' "$ta_none"

        # Background codes
        readonly bg_black="$(tput setab 0 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_blue="$(tput setab 4 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_cyan="$(tput setab 6 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_green="$(tput setab 2 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_magenta="$(tput setab 5 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_red="$(tput setab 1 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_white="$(tput setab 7 2> /dev/null || true)"
        printf '%b' "$ta_none"
        readonly bg_yellow="$(tput setab 3 2> /dev/null || true)"
        printf '%b' "$ta_none"
    else
        # Text attributes
        readonly ta_bold=''
        readonly ta_uscore=''
        readonly ta_blink=''
        readonly ta_reverse=''
        readonly ta_conceal=''

        # Foreground codes
        readonly fg_black=''
        readonly fg_blue=''
        readonly fg_cyan=''
        readonly fg_green=''
        readonly fg_magenta=''
        readonly fg_red=''
        readonly fg_white=''
        readonly fg_yellow=''

        # Background codes
        readonly bg_black=''
        readonly bg_blue=''
        readonly bg_cyan=''
        readonly bg_green=''
        readonly bg_magenta=''
        readonly bg_red=''
        readonly bg_white=''
        readonly bg_yellow=''
    fi
}


# DESC: Initialise Cron mode
# ARGS: None
# OUTS: $script_output: Path to the file stdout & stderr was redirected to
function cron_init() {
    if [[ -n ${cron-} ]]; then
        # Redirect all output to a temporary file
        readonly script_output="$(mktemp --tmpdir "$script_name".XXXXX)"
        exec 3>&1 4>&2 1>"$script_output" 2>&1
    fi
}


# DESC: Acquire script lock
# ARGS: $1 (optional): Scope of script execution lock (system or user)
# OUTS: $script_lock: Path to the directory indicating we have the script lock
# NOTE: This lock implementation is extremely simple but should be reliable
#       across all platforms. It does *not* support locking a script with
#       symlinks or multiple hardlinks as there's no portable way of doing so.
#       If the lock was acquired it's automatically released on script exit.
function lock_init() {
    local lock_dir
    if [[ $1 = 'system' ]]; then
        lock_dir="/tmp/$script_name.lock"
    elif [[ $1 = 'user' ]]; then
        lock_dir="/tmp/$script_name.$UID.lock"
    else
        script_exit 'Missing or invalid argument to lock_init()!' 2
    fi

    if mkdir "$lock_dir" 2> /dev/null; then
        readonly script_lock="$lock_dir"
        verbose_print "Acquired script lock: $script_lock"
    else
        script_exit "Unable to acquire script lock: $lock_dir" 2
    fi
}


# DESC: Pretty print the provided string
# ARGS: $1 (required): Message to print (defaults to a green foreground)
#       $2 (optional): Colour to print the message with. This can be an ANSI
#                      escape code or one of the prepopulated colour variables.
#       $3 (optional): Set to any value to not append a new line to the message
# OUTS: None
function pretty_print() {
    if [[ $# -lt 1 ]]; then
        script_exit 'Missing required argument to pretty_print()!' 2
    fi

    if [[ -z ${no_colour-} ]]; then
        if [[ -n ${2-} ]]; then
            printf '%b' "$2"
        else
            printf '%b' "$fg_green"
        fi
    fi

    # Print message & reset text attributes
    if [[ -n ${3-} ]]; then
        printf '%s%b' "$1" "$ta_none"
    else
        printf '%s%b\n' "$1" "$ta_none"
    fi
}


# DESC: Only pretty_print() the provided string if verbose mode is enabled
# ARGS: $@ (required): Passed through to pretty_pretty() function
# OUTS: None
function verbose_print() {
    if [[ -n ${verbose-} ]]; then
        pretty_print "$@"
    fi
}


# DESC: Combines two path variables and removes any duplicates
# ARGS: $1 (required): Path(s) to join with the second argument
#       $2 (optional): Path(s) to join with the first argument
# OUTS: $build_path: The constructed path
# NOTE: Heavily inspired by: https://unix.stackexchange.com/a/40973
function build_path() {
    if [[ $# -lt 1 ]]; then
        script_exit 'Missing required argument to build_path()!' 2
    fi

    local new_path path_entry temp_path

    temp_path="$1:"
    if [[ -n ${2-} ]]; then
        temp_path="$temp_path$2:"
    fi

    new_path=
    while [[ -n $temp_path ]]; do
        path_entry="${temp_path%%:*}"
        case "$new_path:" in
            *:"$path_entry":*) ;;
                            *) new_path="$new_path:$path_entry"
                               ;;
        esac
        temp_path="${temp_path#*:}"
    done

    # shellcheck disable=SC2034
    build_path="${new_path#:}"
}


# DESC: Check a binary exists in the search path
# ARGS: $1 (required): Name of the binary to test for existence
#       $2 (optional): Set to any value to treat failure as a fatal error
# OUTS: None
function check_binary() {
    if [[ $# -lt 1 ]]; then
        script_exit 'Missing required argument to check_binary()!' 2
    fi

    if ! command -v "$1" > /dev/null 2>&1; then
        if [[ -n ${2-} ]]; then
            script_exit "Missing dependency: Couldn't locate $1." 1
        else
            verbose_print "Missing dependency: $1" "${fg_red-}"
            return 1
        fi
    fi

    verbose_print "Found dependency: $1"
    return 0
}


# DESC: Validate we have superuser access as root (via sudo if requested)
# ARGS: $1 (optional): Set to any value to not attempt root access via sudo
# OUTS: None
function check_superuser() {
    local superuser test_euid
    if [[ $EUID -eq 0 ]]; then
        superuser=true
    elif [[ -z ${1-} ]]; then
        if check_binary sudo; then
            pretty_print 'Sudo: Updating cached credentials ...'
            if ! sudo -v; then
                verbose_print "Sudo: Couldn't acquire credentials ..." \
                              "${fg_red-}"
            else
                test_euid="$(sudo -H -- "$BASH" -c 'printf "%s" "$EUID"')"
                if [[ $test_euid -eq 0 ]]; then
                    superuser=true
                fi
            fi
        fi
    fi

    if [[ -z ${superuser-} ]]; then
        verbose_print 'Unable to acquire superuser credentials.' "${fg_red-}"
        return 1
    fi

    verbose_print 'Successfully acquired superuser credentials.'
    return 0
}


# DESC: Run the requested command as root (via sudo if requested)
# ARGS: $1 (optional): Set to zero to not attempt execution via sudo
#       $@ (required): Passed through for execution as root user
# OUTS: None
function run_as_root() {
    if [[ $# -eq 0 ]]; then
        script_exit 'Missing required argument to run_as_root()!' 2
    fi

    local try_sudo
    if [[ ${1-} =~ ^0$ ]]; then
        try_sudo=true
        shift
    fi

    if [[ $EUID -eq 0 ]]; then
        "$@"
    elif [[ -z ${try_sudo-} ]]; then
        sudo -H -- "$@"
    else
        script_exit "Unable to run requested command as root: $*" 1
    fi
}


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
