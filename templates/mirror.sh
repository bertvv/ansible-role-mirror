#! /usr/bin/bash
#
# Author: Bert Van Vreckem <bert.vanvreckem@gmail.com>
#
# PURPOSE
# See usage() for details.

### Bash settings
# abort on unbound variable
set -o nounset

### Variables
readonly script_name=$(basename "${0}")
readonly script_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
IFS=$'\t\n'   # Split on newlines and tabs (but not on spaces)

readonly lockfile_dir=/var/lock
readonly lock_fd=200
readonly logfile="/var/log/${script_name}.log"

readonly errorlog="/var/log/${script_name}-error.log"

readonly mirror_root_directory="{{ mirror_root_directory }}"

### Main functionality
main() {
  lock "${script_name}" \
    || die "An instance of ${script_name} is already running."

{% for source in mirror_sources %}
  synchronize {{ source.rsync_server }} {{ source.distro }} {{ source.version }}
{% endfor %}
}

### Helper functions

# Usage: synchronize SERVER DISTRO VERSION
#
# Synchronizes the contents of the download mirror at SERVER for the specified
# version of the distribution DISTRO
#
# Example: synchronize rsync.belnet.be centos 7
synchronize() {
  local rsync_server="${1}"
  local distro_name="${2}"
  local releasever="${3}"

  log "Starting sync from ${rsync_server} to ${mirror_root_directory}/${distro_name}/${releasever}"

  rsync \
    --archive --sparse --hard-links --copy-links --delete --partial \
    --verbose --progress \
    --exclude 'isos*' \
    "${rsync_server}::${distro_name}/${releasever}" \
    "${mirror_root_directory}/${distro_name}/${releasever}" \
    2>&1 | tee "${errorlog}"

  if [ "${PIPESTATUS[0]}" -eq "0" ]; then
    log "Finished sync successfully"
    rm "${errorlog}"
  else
    log "Sync finished with error status ${PIPESTATUS[0]}. See ${errorlog} for details."
  fi
}

# Prints a time stamp consisting of ISO-8601 date and time up to the seconds
time_stamp() {
  printf "[%s]" "$(date +'%F %T')"
}

# Prints a log message to the log file and stdout
log() {
  msg="${*}"

  printf "%s %s\n" "$(time_stamp)" "${msg}" | tee --append "${logfile}"
}

# Print an error message to the log file and stderr, and exit the script
die() {
  msg="${*}"

  printf "%s !!! %s\n" "$(time_stamp)" "${msg}" | tee --append "${logfile}" >&2
  exit 1
}

# Create a lock file, or exit the script if the lock file already exists
# because the script is already running.
lock() {
  local lock_file="${lockfile_dir}/${script_name}.lock"

  # create lock file
  eval "exec ${lock_fd}>${lock_file}"
  flock --nonblock "${lock_fd}" \
    && return 0 \
    || return 1
}

main "${@}"

