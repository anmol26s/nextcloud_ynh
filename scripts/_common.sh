#
# Common variables
#

APPNAME="nextcloud"

# Nextcloud version
VERSION="9.0.51"

# Package name for Nextcloud dependencies
DEPS_PKG_NAME="nextcloud-deps"

# Remote URL to fetch Nextcloud tarball
NEXTCLOUD_SOURCE_URL="https://download.nextcloud.com/server/releases/nextcloud-${VERSION}.tar.bz2"

# Remote URL to fetch Nextcloud tarball checksum
NEXTCLOUD_SOURCE_SHA256="e085a20e9d85d238239e7e9f714325aee1f0fe949dcace2dbc2e7abaf3041e78"

# App package root directory should be the parent folder
PKGDIR=$(cd ../; pwd)

#
# Common helpers
#

# Download and extract Nextcloud sources to the given directory
# usage: extract_nextcloud DESTDIR [AS_USER]
extract_nextcloud() {
  local DESTDIR=$1
  local AS_USER=${2:-admin}

  # retrieve and extract Roundcube tarball
  nc_tarball="/tmp/nextcloud.tar.bz2"
  rm -f "$nc_tarball"
  wget -q -O "$nc_tarball" "$NEXTCLOUD_SOURCE_URL" \
    || ynh_die "Unable to download Nextcloud tarball"
  echo "$NEXTCLOUD_SOURCE_SHA256 $nc_tarball" | sha256sum -c >/dev/null \
    || ynh_die "Invalid checksum of downloaded tarball"
  exec_as "$AS_USER" tar xjf "$nc_tarball" -C "$DESTDIR" --strip-components 1 \
    || ynh_die "Unable to extract Nextcloud tarball"
  rm -f "$nc_tarball"

  # apply patches
  (cd "$DESTDIR" \
   && for p in ${PKGDIR}/patches/*.patch; do \
        exec_as "$AS_USER" patch -p1 < $p; done) \
    || ynh_die "Unable to apply patches to Nextcloud"
}

# Execute a command as another user
# usage: exec_as USER COMMAND [ARG ...]
exec_as() {
  local USER=$1
  shift 1

  if [[ $USER = $(whoami) ]]; then
    eval "$@"
  else
    # use sudo twice to be root and be allowed to use another user
    sudo sudo -u "$USER" "$@"
  fi
}

# Execute a command with occ as a given user from a given directory
# usage: exec_occ WORKDIR AS_USER COMMAND [ARG ...]
exec_occ() {
  local WORKDIR=$1
  local AS_USER=$2
  shift 2

  (cd "$WORKDIR" && exec_as "$AS_USER" \
      php occ --no-interaction --no-ansi "$@")
}
