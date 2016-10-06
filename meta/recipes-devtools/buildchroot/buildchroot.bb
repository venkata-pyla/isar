# Root filesystem for packages building
#
# This software is a part of ISAR.
# Copyright (C) 2015-2016 ilbers GmbH

DESCRIPTION = "Multistrap development filesystem"

LICENSE = "gpl-2.0"
LIC_FILES_CHKSUM = "file://${LAYERDIR_isar}/licenses/COPYING.GPLv2;md5=751419260aa954499f7abaabaa882bbe"

PV = "1.0"

DISTRO ?= "debian-wheezy"
DISTRO_SUITE ?= "wheezy"
DISTRO_ARCH ?= "armhf"
DISTRO_COMPONENTS ?= "main contrib non-free"
DISTRO_APT_SOURCE ?= "http://httpredir.debian.org/debian"

BUILDCHROOT_PREINSTALL ?= "gcc \
                           make \
                           build-essential \
                           debhelper \
                           autotools-dev \
                           dpkg \
                           locales \
                           docbook-to-man \
                           apt \
                           automake"

WORKDIR = "${TMPDIR}/work/${PF}/${MACHINE}"

do_build[stamp-extra-info] = "${MACHINE}"

do_build() {
    # Copy config files
    install -m 644 ${THISDIR}/files/multistrap.conf.in ${WORKDIR}/multistrap.conf
    install -m 755 ${THISDIR}/files/configscript.sh ${WORKDIR}
    install -m 755 ${THISDIR}/files/setup.sh ${WORKDIR}

    # Adjust multistrap config
    sed -i 's|##BUILDCHROOT_PREINSTALL##|${BUILDCHROOT_PREINSTALL}|' ${WORKDIR}/multistrap.conf
    sed -i 's|##DISTRO##|${DISTRO}|' ${WORKDIR}/multistrap.conf
    sed -i 's|##DISTRO_APT_SOURCE##|${DISTRO_APT_SOURCE}|' ${WORKDIR}/multistrap.conf
    sed -i 's|##DISTRO_SUITE##|${DISTRO_SUITE}|' ${WORKDIR}/multistrap.conf
    sed -i 's|##DISTRO_COMPONENTS##|${DISTRO_COMPONENTS}|' ${WORKDIR}/multistrap.conf
    sed -i 's|##CONFIG_SCRIPT##|./tmp/work/${PF}/${MACHINE}/configscript.sh|' ${WORKDIR}/multistrap.conf
    sed -i 's|##SETUP_SCRIPT##|./tmp/work/${PF}/${MACHINE}/setup.sh|' ${WORKDIR}/multistrap.conf

    # Create root filesystem
    sudo multistrap -a ${DISTRO_ARCH} -d "${BUILDCHROOT_DIR}" -f "${WORKDIR}/multistrap.conf" || true

    # Install package builder script
    sudo install -m 755 ${THISDIR}/files/build.sh ${BUILDCHROOT_DIR}

    # Configure root filesystem
    sudo chroot ${BUILDCHROOT_DIR} /configscript.sh
}
