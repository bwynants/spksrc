#!/bin/sh

# Package
PACKAGE="plexconnect"
DNAME="PlexConnect"

# Others
TMP_DIR="${SYNOPKG_PKGDEST}/../../@tmp"
INSTALL_DIR="/usr/local/${PACKAGE}"
PLEXCONNECT_DIR="$[INSTALL_DIR}/share/PlexConnect"
CFG_FILE="${PLEXCONNECT_DIR}/Settings.cfg"
HTTPD_CONF="/etc/httpd/sites-enabled-user"
INSTALLER_LOG="/tmp/installer.log"

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

  # Create the certificates
  #openssl req -new -nodes -newkey rsa:2048 -out "${INSTALL_DIR}/etc/certificates/trailers.pem" -keyout "${INSTALL_DIR}/etc/certificates/trailers.key" -x509 -days 7300 -subj "/C=US/CN=trailers.apple.com"
  #openssl x509 -in "${INSTALL_DIR}/etc/certificates/trailers.pem" -outform der -out "${INSTALL_DIR}/etc/certificates/trailers.cer" && cat "${INSTALL_DIR}/etc/certificates/trailers.key" >> "${INSTALL_DIR}/etc/certificates/trailers.pem"

  # get IP
  sIPNAS=`/usr/syno/sbin/synonet --show | grep IP:  | awk -F: '{gsub(/[ \t]+/, "", $2); print $2}'`
  # get DNS
  sIPDNS=`/usr/syno/sbin/synonet --show | grep DNS: | awk -F: '{gsub(/[ \t]+/, "", $2); print $2}'`

  # Edit the configuration according to the wizard or system settings
  sed -i -e "s|%logpath%|${INSTALL_DIR}/var|g" "${CFG_FILE}"
  sed -i -e "s|%ip_dnsmaster%|${sIPDNS}|g" ${CFG_FILE}
  sed -i -e "s|%enable_dnsserver%|${pc_internal_dns}|g" "${CFG_FILE}"
  sed -i -e "s|%hosttointercept%|${pc_host_name}|g" "${CFG_FILE}"
  sed -i -e "s|%certfile%|${INSTALL_DIR}/etc/certificates/${cert_name}.pem|g" "${CFG_FILE}"

cat <<EOF >"${INSTALL_DIR}/etc/${PACKAGE}-vhost.conf"
    ServerName    ${pc_host_name}
    ServerAlias   atv.plexconnect
    ProxyPreserveHost On
    ProxyPass   / http://${sIPNAS}:81/ nocanon
    ProxyPassReverse  / http://${sIPNAS}:81/
EOF
cat <<EOF >"${INSTALL_DIR}/etc/${PACKAGE}-ssl-vhost.conf"
    ServerName          ${pc_host_name}
    ServerAlias         atv.plexconnect
    SSLEngine           On
    SSLCertificateFile    ${INSTALL_DIR}/etc/certificates/${cert_name}.cer
    SSLCertificateKeyFile ${INSTALL_DIR}/etc/certificates/${cert_name}.key
    SSLProxyEngine      On
    ProxyRequests       Off
    ProxyPreserveHost   On
    ProxyPass           / https://${sIPNAS}:444/
    ProxyPassReverse    / https://${sIPNAS}:444/
EOF

  # create symbolic links
  ln -s "${INSTALL_DIR}/etc/${PACKAGE}-vhost.conf" "${HTTPD_CONF}/${PACKAGE}-vhost.conf"
  # no HTTPS for now
  #  ln -s "${INSTALL_DIR}/etc/${PACKAGE}-ssl-vhost.conf" "${HTTPD_CONF}/${PACKAGE}-ssl-vhost.conf"
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

    rm -f "${HTTPD_CONF}/${PACKAGE}-vhost.conf"
    rm -f "${HTTPD_CONF}/${PACKAGE}-ssl-vhost.conf"
    # restart apache
    httpd_reload
  fi

  exit 0
}

postuninst ()
{
  installer_log "-- postuninst"
  rm -rf ${INSTALL_DIR}

  exit 0
}

preupgrade ()
{
  installer_log "-- preupgrade ${TMP_DIR}/${PACKAGE}"

  rm -rf ${TMP_DIR}/${PACKAGE}
  mkdir -p ${TMP_DIR}/${PACKAGE}

  # backup plexconnect (could be git copy we need to restore and it contains the settings)
  installer_log "backup old PlexConnect files"
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

  if [ -d ${TMP_DIR}/${PACKAGE}/PlexConnect/.git ]; then
    installer_log "full restore and git pull to update"
    rm -r {PLEXCONNECT_DIR}
    mv -f ${TMP_DIR}/${PACKAGE}/PlexConnect ${INSTALL_DIR}/share/
    git --git-dir=${PLEXCONNECT_DIR}/.git pull || true
  else
    installer_log "restore only configuration"
    mv -f ${TMP_DIR}/${PACKAGE}/PlexConnect/*.cfg ${PLEXCONNECT_DIR}/
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
