#!/bin/sh

# Package
PACKAGE="plexconnect"
DNAME="PlexConnect"

# Others
TMP_DIR="${SYNOPKG_PKGDEST}/../../@tmp"
INSTALL_DIR="/usr/local/${PACKAGE}"
PLEXCONNECT_DIR="${INSTALL_DIR}/share/${DNAME}"
CFG_FILE="${PLEXCONNECT_DIR}/Settings.cfg"
INSTALLER_LOG="/tmp/installer.log"

APACHE_DIR="/etc/httpd"
HTTPD_CONF_USER="${APACHE_DIR}/conf/httpd.conf-user"
PLEX_VHOST="${INSTALL_DIR}/etc/${PACKAGE}-vhosts.conf"
PLEX_SSL_VHOST="${INSTALL_DIR}/etc/${PACKAGE}-ssl-vhosts.conf"

if [ "${pc_internal_dns}" == "true" ]; then
    pc_internal_dns="True"
else
    pc_internal_dns="False"
fi

if [ "${pc_host_marketwatch}" == "true" ]; then
    pc_host_name="secure.marketwatch.com" && cert_name="marketwatch"
elif [ "${pc_host_imovie}" == "true" ]; then
    pc_host_name="www.icloud.com"         && cert_name="icloud"
else
    pc_host_name="trailers.apple.com"     && cert_name="trailers"
fi

httpd_reload() {
  /usr/syno/sbin/synoservicecfg --reload httpd-user
}

installer_log() {
  return
  #echo "INSTALLER: ${1}" >> "${INSTALLER_LOG}"
}

preinst ()
{
  installer_log "-- preinst"
  exit 0
}

postinst ()
{
  installer_log "-- postinst"

  # Link
  ln -s ${SYNOPKG_PKGDEST} ${INSTALL_DIR}

  # Create user
  adduser -h ${INSTALL_DIR} -g "${DNAME} User" -G users -s /bin/sh -S -D ${PACKAGE}

  # cleanup leftover from older installer
  rm -rf "${APACHE_DIR}/sites-enabled-user/${PACKAGE}-vhosts.conf"

  # Create the certificates
  #openssl req -new -nodes -newkey rsa:2048 -out "${INSTALL_DIR}/etc/certificates/${cert_name}.pem" -keyout "${INSTALL_DIR}/etc/certificates/${cert_name}.key" -x509 -days 7300 -subj "/C=US/CN=${pc_host_name}"
  #openssl x509 -in "${INSTALL_DIR}/etc/certificates/${cert_name}.pem" -outform der -out "${INSTALL_DIR}/etc/certificates/${cert_name}.cer" && cat "${INSTALL_DIR}/etc/certificates/${cert_name}.key" >> "${INSTALL_DIR}/etc/certificates/${cert_name}.pem"

  # get IP
  sIPNAS=`/usr/syno/sbin/synonet --show | grep -m 1 IP:  | awk -F: '{gsub(/[ \t]+/, "", $2); print $2}'`
  # get DNS
  sIPDNS=`/usr/syno/sbin/synonet --show | grep -m 1 DNS: | awk -F: '{gsub(/[ \t]+/, "", $2); print $2}'`

  # Edit the configuration according to the wizard or system settings
  sed -i -e "s|%logpath%|${INSTALL_DIR}/var|g" "${CFG_FILE}"
  sed -i -e "s|%ip_dnsmaster%|${sIPDNS}|g" "${CFG_FILE}"
  sed -i -e "s|%enable_dnsserver%|${pc_internal_dns}|g" "${CFG_FILE}"
  sed -i -e "s|%hosttointercept%|${pc_host_name}|g" "${CFG_FILE}"
  sed -i -e "s|%certfile%|${INSTALL_DIR}/etc/certificates/${cert_name}.pem|g" "${CFG_FILE}"

  sed -i -e "s|%cert_name%|${cert_name}|g" "${PLEX_VHOST}"
  sed -i -e "s|%pc_host_name%|${pc_host_name}|g" "${PLEX_VHOST}"
  sed -i -e "s|%pc_ip_nas%|${sIPNAS}|g" "${PLEX_VHOST}"

  sed -i -e "s|%cert_name%|${cert_name}|g" "${PLEX_SSL_VHOST}"
  sed -i -e "s|%pc_host_name%|${pc_host_name}|g" "${PLEX_SSL_VHOST}"
  sed -i -e "s|%pc_ip_nas%|${sIPNAS}|g" "${PLEX_SSL_VHOST}"

  # create symbolic links
  ln -s "${PLEX_VHOST}" "${APACHE_DIR}/sites-enabled-user/httpd-vhosts.conf-${PACKAGE}"
  # no HTTPS for now
  #  ln -s "${PLEX_SSL_VHOST}" "${APACHE_DIR}/sites-enabled-user/httpd-ssl-vhosts.conf-${PACKAGE}"

  # make a copy of HTTPD_CONF_USER
  cp ${HTTPD_CONF_USER} ${HTTPD_CONF_USER}.bak
  # include our VHOST_FILE
  echo "Include ${APACHE_DIR}/sites-enabled-user/httpd-vhosts.conf-${PACKAGE}" >> ${HTTPD_CONF_USER}

  # make a copy of HTTPD_SSL_CONF_USER
  #cp ${HTTPD_SSL_CONF_USER} ${HTTPD_SSL_CONF_USER}.bak
  # include our VHOST_SSL_FILE
  #echo "Include ${APACHE_DIR}/sites-enabled-user/httpd-ssl-vhosts.conf-${PACKAGE}" >> ${HTTPD_SSL_CONF_USER}

  httpd_reload

  # Correct the files ownership
  chown -R ${PACKAGE}:root ${SYNOPKG_PKGDEST}

  exit 0
}

preuninst ()
{
  installer_log "-- preuninst"

  if [ "${SYNOPKG_PKG_STATUS}" == "UNINSTALL" ]; then
    # Remove the user (if not upgrading)
    deluser ${PACKAGE}
  fi

  exit 0
}

postuninst ()
{
  installer_log "-- postuninst"
  rm -rf ${INSTALL_DIR}

  # remove httpd-vhosts.conf-plexconnect and httpd-ssl-vhosts.conf-plexconnect
  sed -i -e "/^Include .*-vhosts.conf-${PACKAGE}$/d" ${HTTPD_CONF_USER}

  #remove symbolic links
  rm -rf "${APACHE_DIR}/sites-enabled-user/httpd-vhosts.conf-${PACKAGE}"
  rm -rf "${APACHE_DIR}/sites-enabled-user/httpd-ssl-vhosts.conf-${PACKAGE}"

  # restart apache
  httpd_reload

  exit 0
}

preupgrade ()
{
  installer_log "-- preupgrade ${TMP_DIR}/${PACKAGE}"

  rm -rf ${TMP_DIR}/${PACKAGE}
  mkdir -p ${TMP_DIR}/${PACKAGE}

  # backup plexconnect (could be git copy we need to restore and it contains the settings)
  installer_log "backup old ${DNAME} files"
  cp -r ${PLEXCONNECT_DIR} ${TMP_DIR}/${PACKAGE}/

  # backup etc
  installer_log "backup etc"
  mkdir -p ${TMP_DIR}/${PACKAGE}/etc
  cp ${INSTALL_DIR}/etc/* ${TMP_DIR}/${PACKAGE}/etc

  exit 0
}

postupgrade ()
{
  installer_log "-- postupgrade ${TMP_DIR}/${PACKAGE}"

  # Restore needed for settings and some files

  if [ -d ${TMP_DIR}/${PACKAGE}/${DNAME}/.git ]; then
    installer_log "full restore and git pull to update"
    rm -r {PLEXCONNECT_DIR}
    mv -f ${TMP_DIR}/${PACKAGE}/${DNAME} ${INSTALL_DIR}/share/
    git --git-dir=${PLEXCONNECT_DIR}/.git pull || true
  else
    installer_log "restore only configuration"
    mv -f ${TMP_DIR}/${PACKAGE}/${DNAME}/*.cfg ${PLEXCONNECT_DIR}/
  fi

  # restore certificates
  if [ -f ${TMP_DIR}/${PACKAGE}/etc/certificates/*.cer ]; then
    installer_log "restore certificates"
    mv -f ${TMP_DIR}/${PACKAGE}/etc/certificates/* ${INSTALL_DIR}/etc/certificates/
  fi

  # restore vhost
  if [ -f ${TMP_DIR}/${PACKAGE}/etc/${PACKAGE}*-vhost.conf ]; then
    installer_log "restore certificates"
    mv -f ${TMP_DIR}/${PACKAGE}/etc/${PACKAGE}*-vhost.conf ${INSTALL_DIR}/etc/
  fi

  # restart apache
  httpd_reload

  # remove temp files
  rm -fr ${TMP_DIR}/${PACKAGE}

  # Correct the files ownership
  chown -R ${PACKAGE}:root ${SYNOPKG_PKGDEST}

  exit 0
}
