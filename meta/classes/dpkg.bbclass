# This software is a part of ISAR.
# Copyright (C) 2015-2018 ilbers GmbH

inherit dpkg-base

PACKAGE_ARCH ?= "${DISTRO_ARCH}"

DPKG_PREBUILD_ENV_FILE="${WORKDIR}/dpkg_prebuild.env"

do_prepare_build_append() {
    env > ${DPKG_PREBUILD_ENV_FILE}
}

# Build package from sources using build script
dpkg_runbuild() {
    E="${@ isar_export_proxies(d)}"
    E="${@ isar_export_ccache(d)}"
    export DEB_BUILD_OPTIONS="${@ isar_deb_build_options(d)}"
    export DEB_BUILD_PROFILES="${@ isar_deb_build_profiles(d)}"
    export PARALLEL_MAKE="${PARALLEL_MAKE}"

    env | while read -r line; do
        # Filter the same lines
        grep -q "^${line}" ${DPKG_PREBUILD_ENV_FILE} && continue
        # Filter some standard variables
        echo ${line} | grep -q "^HOME=" && continue
        echo ${line} | grep -q "^PWD=" && continue

        var=$(echo "${line}" | cut -d '=' -f1)
        value=$(echo "${line}" | cut -d '=' -f2-)
        sbuild_export $var "$value"

        # Don't warn some variables
        [ "${var}" = "PARALLEL_MAKE" ] && continue
        [ "${var}" = "CCACHE_DIR" ] && continue
        [ "${var}" = "PATH_PREPEND" ] && continue
        [ "${var}" = "DEB_BUILD_OPTIONS" ] && continue
        [ "${var}" = "DEB_BUILD_PROFILES" ] && continue

        bbwarn "Export of '${line}' detected, please migrate to templates"
    done

    distro="${DISTRO}"
    if [ ${ISAR_CROSS_COMPILE} -eq 1 ]; then
        distro="${HOST_DISTRO}"
    fi

    deb_dl_dir_import "${WORKDIR}/rootfs" "${distro}"

    deb_dir="/var/cache/apt/archives/"
    ext_deb_dir="/home/builder/${PN}/rootfs/${deb_dir}"

    ( flock 9
        grep -qxF '$apt_keep_downloaded_packages = 1;' ${SCHROOT_USER_HOME}/.sbuildrc ||
            echo '$apt_keep_downloaded_packages = 1;' >> ${SCHROOT_USER_HOME}/.sbuildrc
    ) 9>"${TMPDIR}/sbuildrc.lock"

    profiles=$(grep "DEB_BUILD_PROFILES" ${SBUILD_CONFIG} | tail -n1 | cut -d "'" -f 4)
    if [ ${ISAR_CROSS_COMPILE} -eq 1 ]; then
        profiles="${profiles} cross nocheck"
    fi
    if [ ! -z "$profiles" ]; then
        profiles=$(echo --profiles="$profiles" | sed -e 's/ \+/,/g')
    fi

    export SBUILD_CONFIG="${SBUILD_CONFIG}"

    sbuild -A -n -c ${SBUILD_CHROOT} --extra-repository="${ISAR_APT_REPO}" \
        --host=${PACKAGE_ARCH} --build=${SBUILD_HOST_ARCH} ${profiles} \
        --no-run-lintian --no-run-piuparts --no-run-autopkgtest \
        --chroot-setup-commands="cp -n --no-preserve=owner ${ext_deb_dir}/*.deb -t ${deb_dir}/ || :" \
        --finished-build-commands="rm -f ${deb_dir}/sbuild-build-depends-main-dummy_*.deb" \
        --finished-build-commands="cp -n --no-preserve=owner ${deb_dir}/*.deb -t ${ext_deb_dir}/ || :" \
        --debbuildopts="--source-option=-I" \
        --build-dir=${WORKDIR} ${WORKDIR}/${PPS}

    deb_dl_dir_export "${WORKDIR}/rootfs" "${distro}"
}
