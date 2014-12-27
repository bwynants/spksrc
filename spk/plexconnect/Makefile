SPK_NAME = plexconnect
SPK_VERS = 0.5
SPK_REV = 4
#BETA=1
SPK_ICON = src/plexconnect.png
DSM_UI_DIR = app

DEPENDS  =
SPK_DEPENDS = "Python>2.7.6"

MAINTAINER = bwynants
DESCRIPTION = PlexConnect: Plex @ aTV - think different. Package to show Plex content on your unhacked AppleTV 2 or 3.
RELOAD_UI = yes
DISPLAY_NAME = PlexConnect
CHANGELOG = "Better integration with synology to survive DSM updates"
HELPURL = http://forums.plexapp.com/index.php/topic/72356-plexconnect-on-synology/
HOMEPAGE   = https://github.com/iBaa/PlexConnect
LICENSE    = GPL

WIZARDS_DIR = src/wizard/

INSTALLER_SCRIPT = src/installer.sh
SSS_SCRIPT       = src/dsm-control.sh

INSTALL_PREFIX = /usr/local/$(SPK_NAME)

COPY_TARGET = nop
POST_STRIP_TARGET = plexconnect_extra_install

FIRMWARE=5.0-4418

# Pure Python package, make sure ARCH is not defined
override ARCH=

include ../../mk/spksrc.spk.mk

.PHONY: plexconnect_extra_install
plexconnect_extra_install: $(STAGING_DIR)/share/PlexConnect
	install -m 755 -d $(STAGING_DIR)/app
	install -m 755 -d $(STAGING_DIR)/var
	install -m 755 -d $(STAGING_DIR)/etc/certificates
	install -m 644 src/app/config $(STAGING_DIR)/app/config
	install -m 755 src/app/httpd-vhosts.conf-plexconnect $(STAGING_DIR)/etc/httpd-vhosts.conf-plexconnect
	install -m 755 src/app/httpd-ssl-vhosts.conf-plexconnect $(STAGING_DIR)/etc/httpd-ssl-vhosts.conf-plexconnect
	install -m 755 src/app/certificates/* $(STAGING_DIR)/etc/certificates/
	install -m 755 src/share/PlexConnect/Settings.cfg $(STAGING_DIR)/share/PlexConnect/Settings.cfg
	install -m 755 -d $(STAGING_DIR)/app/images
	for size in 16 24 32 48; do \
		convert $(SPK_ICON) -thumbnail $${size}x$${size} \
	         $(STAGING_DIR)/app/images/$(SPK_NAME)-$${size}.png ; \
	done

$(STAGING_DIR)/share/PlexConnect:
	install -m 755 -d $(STAGING_DIR)/share
	cd $(STAGING_DIR)/share && git clone --single-branch -b master https://github.com/iBaa/PlexConnect.git
	cd $(STAGING_DIR)/share/PlexConnect && git checkout 90e0f4618590a1c5284283f63dffb1ac624027d8
	# cd $(STAGING_DIR)/share/PlexConnect && git am < $(STAGING_DIR)/../../src/share/PlexConnect/patch.diff
	rm -fr $(STAGING_DIR)/share/PlexConnect/.git $(STAGING_DIR)/share/PlexConnect/.gitignore
