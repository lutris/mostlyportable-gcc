#!/bin/bash

# Created by: Tk-Glitch <ti3nou at gmail dot com>

# This script creates portable x86_64 GCC/MingW builds - You'll need basic development tools installed (base-devel, build-essential or similar for your distro)
# It is bound to the libc/binutils version of the host system, so cross-distro portability only works for a given libc/binutils version combo

cat << 'EOM'
       .---.`               `.---.
    `/syhhhyso-           -osyhhhys/`
   .syNMdhNNhss/``.---.``/sshNNhdMNys.
   +sdMh.`+MNsssssssssssssssNM+`.hMds+
   :syNNdhNNhssssssssssssssshNNhdNNys:
    /ssyhhhysssssssssssssssssyhhhyss/
    .ossssssssssssssssssssssssssssso.     (Mostly)
   :sssssssssssssssssssssssssssssssss:    Portable
  /sssssssssssssssssssssssssssssssssss/        GCC/MingW
 :sssssssssssssoosssssssoosssssssssssss:
 osssssssssssssoosssssssoossssssssssssso
 osssssssssssyyyyhhhhhhhyyyyssssssssssso
 /yyyyyyhhdmmmmNNNNNNNNNNNmmmmdhhyyyyyy/
  smmmNNNNNNNNNNNNNNNNNNNNNNNNNNNNNmmms
   /dNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNd/
    `:sdNNNNNNNNNNNNNNNNNNNNNNNNNds:`
       `-+shdNNNNNNNNNNNNNNNdhs+-`
             `.-:///////:-.`

EOM

_nowhere="$PWD"

  user_patcher() {
  	# To patch the user because all your base are belong to us
  	local _patches=("$_nowhere"/*."${_userpatch_ext}revert")
  	if [ ${#_patches[@]} -ge 2 ] || [ -e "${_patches}" ]; then
  	  if [ "$_user_patches_no_confirm" != "true" ]; then
  	    echo -e "Found ${#_patches[@]} 'to revert' userpatches for ${_userpatch_target}:"
  	    printf '%s\n' "${_patches[@]}"
  	    read -rp "Do you want to install it/them? - Be careful with that ;)"$'\n> N/y : ' _CONDITION;
  	  fi
  	  if [ "$_CONDITION" == "y" ] || [ "$_user_patches_no_confirm" == "true" ]; then
  	    for _f in "${_patches[@]}"; do
  	      if [ -e "${_f}" ]; then
  	        echo -e "######################################################"
  	        echo -e ""
  	        echo -e "Reverting your own ${_userpatch_target} patch ${_f}"
  	        echo -e ""
  	        echo -e "######################################################"
  	        patch -Np1 -R < "${_f}"
  	        echo "# Reverted your own patch ${_f}" >> "$_nowhere"/last_build_config.log
  	      fi
  	    done
  	  fi
  	fi

  	_patches=("$_nowhere"/*."${_userpatch_ext}patch")
  	if [ ${#_patches[@]} -ge 2 ] || [ -e "${_patches}" ]; then
  	  if [ "$_user_patches_no_confirm" != "true" ]; then
  	    echo -e "Found ${#_patches[@]} userpatches for ${_userpatch_target}:"
  	    printf '%s\n' "${_patches[@]}"
  	    read -rp "Do you want to install it/them? - Be careful with that ;)"$'\n> N/y : ' _CONDITION;
  	  fi
  	  if [ "$_CONDITION" == "y" ] || [ "$_user_patches_no_confirm" == "true" ]; then
  	    for _f in "${_patches[@]}"; do
  	      if [ -e "${_f}" ]; then
  	        echo -e "######################################################"
  	        echo -e ""
  	        echo -e "Applying your own ${_userpatch_target} patch ${_f}"
  	        echo -e ""
  	        echo -e "######################################################"
  	        patch -Np1 < "${_f}"
  	        echo "# Applied your own patch ${_f}" >> "$_nowhere"/last_build_config.log
  	      fi
  	    done
  	  fi
  	fi
  }

  _exit_cleanup() {
    cd "${_nowhere}"/build && find . -maxdepth 1 -mindepth 1 -type d -exec rm -rf '{}' \;
    rm -f "${_nowhere}"/proton_binutils*.binutilspatch
    echo -e "\n## Exit cleanup complete"
  }

  trap _exit_cleanup EXIT

  _init() {
    # Load external configuration file if present. Available variable values will overwrite customization.cfg ones.
    if [ -e "$_EXT_CONFIG_PATH" ]; then
      source "$_EXT_CONFIG_PATH" && echo -e "External configuration file $_EXT_CONFIG_PATH will be used to override customization.cfg values.\n"
    fi

    if [ "$_mingwbuild" == "true" ]; then
      source "$_nowhere"/last_build_config.log
      if [ -n "$BUILT_GCC_PATH" ]; then
        CUSTOM_GCC_PATH="${BUILT_GCC_PATH}"
      fi
    fi

    echo -e "# Last mostlyportable-gcc configuration - $(date) :\n" > "$_nowhere"/last_build_config.log
    echo -e "# External configuration file $_EXT_CONFIG_PATH will be used to override customization.cfg values.\n" >> "$_nowhere"/last_build_config.log

    mkdir -p "${_nowhere}"/build

    # gcc repo
    if [ "$_use_gcc_git" == "true" ]; then
      git clone --mirror "${_gcc_git}" gcc || true
      cd "${_nowhere}"/gcc
      if [[ "${_gcc_git}" != "$(git config --get remote.origin.url)" ]] ; then
        echo "gcc is not a clone of ${_gcc_git}. Please delete gcc dir and try again."
        exit 1
      fi
      echo -e "\nPlease be patient, it might take a while...\n"
      git fetch --all -p
      rm -rf "${_nowhere}"/build/gcc && git clone "${_nowhere}"/gcc "${_nowhere}"/build/gcc
      cd "${_nowhere}"/build/gcc
      git checkout --force --no-track -B safezone origin/HEAD
      if [ -n "${_gcc_version}" ]; then
        git checkout "${_gcc_version}" || { echo -e "Git checkout failed. Please make sure you're using a valid commit id or git tag for GCC." ; exit 1; }
      fi
      git reset --hard HEAD
      git clean -xdf
      _gcc_sub="-$(git describe --long --tags --always | sed 's/\([^-]*-g\)/r\1/;s/-/./g;s/^v//;s/\//-/')"
    else
      cd "${_nowhere}"/build
      wget -c ftp://ftp.gnu.org/gnu/gcc/gcc-"${_gcc_version}"/gcc-"${_gcc_version}".tar.xz && chmod a+x gcc-"${_gcc_version}".tar.* && tar -xvJf gcc-"${_gcc_version}".tar.* >/dev/null 2>&1
      mv gcc-"${_gcc_version}" gcc
    fi

    # Set/update gcc version from source
    cd "${_nowhere}"/build/gcc/gcc
    _gcc_version=$(cat BASE-VER)

    # binutils repo
    if [ "$_use_binutils_git" == "true" ]; then
      cd "${_nowhere}"
      git clone --mirror "${_binutils_git}" binutils-git || true
      cd "${_nowhere}"/binutils-git
      if [[ "${_binutils_git}" != "$(git config --get remote.origin.url)" ]] ; then
        echo "binutils-git is not a clone of ${_binutils_git}. Please delete binutils-git dir and try again."
        exit 1
      fi
      echo -e "\nPlease be patient, it might take a while...\n"
      git fetch --all -p
      rm -rf "${_nowhere}"/build/binutils-git && git clone "${_nowhere}"/binutils-git "${_nowhere}"/build/binutils-git
      cd "${_nowhere}"/build/binutils-git
      git checkout --force --no-track -B safezone origin/HEAD
      if [ -n "${_binutils}" ]; then
        git checkout "${_binutils}" || { echo -e "Git checkout failed. Please make sure you're using a valid commit id or git tag for MinGW." ; exit 1; }
      fi
      git reset --hard HEAD
      git clean -xdf
      cd "${_nowhere}"/build
      _binutils_path="binutils-git"
    else
      cd "${_nowhere}"/build
      if [ ! -e binutils-"${_binutils}".tar.gz ]; then
        wget -c https://ftp.gnu.org/gnu/binutils/binutils-"${_binutils}".tar.gz
      fi
      chmod a+x binutils-"${_binutils}".tar.* && tar -xvf binutils-"${_binutils}".tar.* >/dev/null 2>&1
      _binutils_path="binutils-${_binutils}"
    fi

    # isl repo
    if [ "$_use_isl_git" == "true" ]; then
      cd "${_nowhere}"
      git clone --mirror "${_isl_git}" isl-git || true
      cd "${_nowhere}"/isl-git
      if [[ "${_isl_git}" != "$(git config --get remote.origin.url)" ]] ; then
        echo "isl-git is not a clone of ${_isl_git}. Please delete isl-git dir and try again."
        exit 1
      fi
      echo -e "\nPlease be patient, it might take a while...\n"
      git fetch --all -p
      rm -rf "${_nowhere}"/build/isl-git && git clone "${_nowhere}"/isl-git "${_nowhere}"/build/isl-git
      cd "${_nowhere}"/build/isl-git
      git checkout --force --no-track -B safezone origin/HEAD
      if [ -n "${_isl}" ]; then
        git checkout "${_isl}" || { echo -e "Git checkout failed. Please make sure you're using a valid commit id or git tag for MinGW." ; exit 1; }
      fi
      git reset --hard HEAD
      git clean -xdf
      ./autogen.sh
      cd "${_nowhere}"/build
      _isl_path="isl-git"
    else
      cd "${_nowhere}"/build
      if [ ! -e isl-"${_isl}".tar.gz ]; then
        wget -c http://isl.gforge.inria.fr/isl-"${_isl}".tar.gz
      fi
      chmod a+x isl-"${_isl}".tar.* && tar -xvf isl-"${_isl}".tar.* >/dev/null 2>&1
      _isl_path="isl-${_isl}"
    fi

    cd "${_nowhere}"/build

    # Download needed toolset
    if [ ! -e gmp-"${_gmp}".tar.xz ]; then
      wget -c ftp://ftp.gnu.org/gnu/gmp/gmp-"${_gmp}".tar.xz
    fi
    if [ ! -e mpfr-"${_mpfr}".tar.xz ]; then
      wget -c ftp://ftp.gnu.org/gnu/mpfr/mpfr-"${_mpfr}".tar.xz
    fi
    if [ ! -e mpc-"${_mpc}".tar.gz ]; then
      wget -c ftp://ftp.gnu.org/gnu/mpc/mpc-"${_mpc}".tar.gz
    fi

    # libelf
    if [ "$_enable_libelf" == "true" ]; then
      if [ ! -e elfutils-"${_libelf}".tar.bz2 ]; then
        wget -c https://sourceware.org/elfutils/ftp/"${_libelf}"/elfutils-"${_libelf}".tar.bz2
      fi
      _libelf_flag="--with-libelf=${_dstdir}"
      chmod a+x elfutils-"${_libelf}".tar.* && tar -xvf elfutils-"${_libelf}".tar.* >/dev/null 2>&1
    fi

    chmod a+x gmp-"${_gmp}".tar.* && tar -xvJf gmp-"${_gmp}".tar.* >/dev/null 2>&1
    chmod a+x mpfr-"${_mpfr}".tar.* && tar -xvJf mpfr-"${_mpfr}".tar.* >/dev/null 2>&1
    chmod a+x mpc-"${_mpc}".tar.* && tar -xvf mpc-"${_mpc}".tar.* >/dev/null 2>&1

    if [ -n "${CUSTOM_GCC_PATH}" ]; then
      _path_hack_prefix="${CUSTOM_GCC_PATH}/bin:${CUSTOM_GCC_PATH}/lib:${CUSTOM_GCC_PATH}/include:"
      echo -e "GCC_PATH=${CUSTOM_GCC_PATH##*/}" >> "$_nowhere"/last_build_config.log
    fi

    if [ "$_mingwbuild" == "true" ]; then
      if [ ! -e osl-"${_osl}".tar.gz ]; then
        wget -c https://github.com/periscop/openscop/releases/download/"${_osl}"/osl-"${_osl}".tar.gz
      fi
      if [ ! -e cloog-"${_cloog}".tar.gz ]; then
        wget -c https://github.com/periscop/cloog/releases/download/cloog-"${_cloog}"/cloog-"${_cloog}".tar.gz
      fi

      if [ "$_use_mingw_git" == "true" ]; then
        cd "${_nowhere}"
        git clone --mirror "${_mingw_git}" mingw-w64-git || true
        cd "${_nowhere}"/mingw-w64-git
        if [[ "${_mingw_git}" != "$(git config --get remote.origin.url)" ]] ; then
          echo "mingw-w64-git is not a clone of ${_mingw_git}. Please delete mingw-w64-git dir and try again."
          exit 1
        fi
        echo -e "\nPlease be patient, it might take a while...\n"
        git fetch --all -p
        rm -rf "${_nowhere}"/build/mingw-w64-git && git clone "${_nowhere}"/mingw-w64-git "${_nowhere}"/build/mingw-w64-git
        cd "${_nowhere}"/build/mingw-w64-git
        git checkout --force --no-track -B safezone origin/HEAD
        if [ -n "${_mingw}" ]; then
          git checkout "${_mingw}" || { echo -e "Git checkout failed. Please make sure you're using a valid commit id or git tag for MinGW." ; exit 1; }
        fi
        git reset --hard HEAD
        git clean -xdf
        cd "${_nowhere}"/build
        _mingw_path="mingw-w64-git"
      else
        cd "${_nowhere}"/build
        if [ ! -e mingw-w64-v"${_mingw}".tar.bz2 ]; then
          wget -c https://sourceforge.net/projects/mingw-w64/files/mingw-w64/mingw-w64-release/mingw-w64-v"${_mingw}".tar.bz2
        fi
        chmod a+x mingw-w64-v"${_mingw}".tar.* && tar -xvf mingw-w64-v"${_mingw}".tar.* >/dev/null 2>&1
        _mingw_path="mingw-w64-v${_mingw}"
      fi

      chmod a+x osl-"${_osl}".tar.* && tar -xvf osl-"${_osl}".tar.* >/dev/null 2>&1
      chmod a+x cloog-"${_cloog}".tar.* && tar -xvf cloog-"${_cloog}".tar.* >/dev/null 2>&1

      if [[ "$_binutils" = 2.33* ]] && [ "$_valve_patches" == "true" ]; then
        if [ ! -e "${_nowhere}/build/proton_binutils1.binutilspatch" ]; then
          wget -c -O proton_binutils1.binutilspatch https://raw.githubusercontent.com/ValveSoftware/Proton/3ad34a0b3f41bac60caea39c742de69cb0e50895/mingw-w64-patches/binutils-0001.patch
        fi
        if [ ! -e "${_nowhere}/build/proton_binutils2.binutilspatch" ]; then
          wget -c -O proton_binutils2.binutilspatch https://raw.githubusercontent.com/ValveSoftware/Proton/3ad34a0b3f41bac60caea39c742de69cb0e50895/mingw-w64-patches/binutils-0002.patch
        fi
      fi
      _path_hack="${_path_hack_prefix}${_dstdir}/i686-w64-mingw32:${_dstdir}/x86_64-w64-mingw32:${_dstdir}/libexec:${_dstdir}/bin:${_dstdir}/lib:${_dstdir}/include:${PATH}"
    else
      # Make the process use our tools as they get built
      _path_hack="${_path_hack_prefix}${_dstdir}/bin:${_dstdir}/lib:${_dstdir}/include:${PATH}"
    fi

    # user patches
    _userpatch_target="gcc"
    _userpatch_ext="gcc"
    cd "${_nowhere}"/build/gcc
    user_patcher

    _userpatch_target="binutils"
    _userpatch_ext="binutils"
    cd "${_nowhere}"/build/"${_binutils_path}"
    user_patcher

    # Proton binutils patches
    if [[ "$_binutils" = 2.33* ]] && [ "$_valve_patches" == "true" ]; then
      cd "${_nowhere}"/build/binutils-"${_binutils}"
      patch -Np1 < "${_nowhere}"/build/proton_binutils1.binutilspatch
      patch -Np1 < "${_nowhere}"/build/proton_binutils2.binutilspatch
      echo -e "# Proton binutils patches applied" >> "$_nowhere"/last_build_config.log
    fi

    # binutils 2.34 fix - https://sourceware.org/bugzilla/show_bug.cgi?id=25993#c4
    if [[ "$_binutils" = 2.34* ]]; then
      if [ ! -e "${_nowhere}/build/binutils234.binutilspatch" ]; then
        cd "${_nowhere}"/build && wget -c -O binutils234.binutilspatch https://sourceware.org/bugzilla/attachment.cgi?id=12545
      fi
      cd "${_nowhere}"/build/binutils-"${_binutils}"
      patch -Np1 < "${_nowhere}"/build/binutils234.binutilspatch
      echo -e "# Binutils 2.34 fix applied" >> "$_nowhere"/last_build_config.log
    fi

    # MinGW 8.0 libgomp fix - https://sourceforge.net/p/mingw-w64/bugs/853/
    if [[ "${_mingw}" = 8.0.* ]]; then
      if [ ! -e "${_nowhere}/build/mingw8_libgomp_fix.gccpatch" ]; then
        cd "${_nowhere}"/build && wget -c -O mingw8_libgomp_fix.gccpatch https://raw.githubusercontent.com/msys2/MINGW-packages/master/mingw-w64-gcc/0020-libgomp-Don-t-hard-code-MS-printf-attributes.patch
      fi
      cd "${_nowhere}"/build/gcc
      patch -Np1 < "${_nowhere}"/build/mingw8_libgomp_fix.gccpatch
      echo -e "# MinGW 8 libgomp fix applied" >> "$_nowhere"/last_build_config.log
    fi

  }

  _makeandinstall() {
    PATH="${_path_hack}" schedtool -B -n 1 -e ionice -n 1 make -j$(nproc) || PATH="${_path_hack}" make -j$(nproc)
    PATH="${_path_hack}" make install
  }

  _build() {
    # Clear dstdir before building
    echo -e "Cleaning up..."
    rm -rf ${_dstdir}/*

    _commonconfig="--disable-shared --enable-static"
    _targets="i686-w64-mingw32 x86_64-w64-mingw32"

    # libelf
    if [ "$_enable_libelf" == "true" ]; then
      cd "${_nowhere}"/build/elfutils-"${_libelf}"
      PATH="${_path_hack}" ./configure \
        --prefix="${_dstdir}" \
        --program-prefix="eu-" \
        --enable-deterministic-archives \
        ${_commonconfig}
      _makeandinstall || exit 1
    fi

    # gmp
    cd "${_nowhere}"/build/gmp-"${_gmp}"
    PATH="${_path_hack}" ./configure \
      --prefix="${_dstdir}" \
      ${_commonconfig}
    _makeandinstall || exit 1

    # mpfr
    cd "${_nowhere}"/build/mpfr-"${_mpfr}"
    PATH="${_path_hack}" ./configure \
      --with-gmp="${_dstdir}" \
      --prefix="${_dstdir}" \
      ${_commonconfig}
    _makeandinstall || exit 1

    # mpc
    cd "${_nowhere}"/build/mpc-"${_mpc}"
    PATH="${_path_hack}" ./configure \
      --with-gmp="${_dstdir}" \
      --with-mpfr="${_dstdir}" \
      --prefix="${_dstdir}" \
      ${_commonconfig}
    _makeandinstall || exit 1

    # isl
    cd "${_nowhere}"/build/"${_isl_path}"
    PATH="${_path_hack}" ./configure \
      --prefix="${_dstdir}" \
      ${_commonconfig}
    _makeandinstall || exit 1

    if [ "$_mingwbuild" == "true" ]; then
      # osl
      cd "${_nowhere}"/build/osl-"${_osl}"
      PATH="${_path_hack}" ./configure \
        --with-gmp="${_dstdir}" \
        --prefix="${_dstdir}" \
        ${_commonconfig}
      _makeandinstall || exit 1

      # cloog
      cd "${_nowhere}"/build/cloog-"${_cloog}"
      PATH="${_path_hack}" ./configure \
        --with-isl="${_dstdir}" \
        --with-osl="${_dstdir}" \
        --prefix="${_dstdir}" \
        ${_commonconfig}
      _makeandinstall || exit 1

      # mingw-w64-binutils
      cd "${_nowhere}"/build/"${_binutils_path}"
      #do not install libiberty
      sed -i 's/install_to_$(INSTALL_DEST) //' libiberty/Makefile.in
      # hack! - libiberty configure tests for header files using "$CPP $CPPFLAGS"
      sed -i "/ac_cpp=/s/\$CPPFLAGS/\$CPPFLAGS -O2/" libiberty/configure
      for _target in $_targets; do
        echo -e "Building ${_target} cross binutils"
        mkdir -p "${_nowhere}"/build/binutils-"${_target}" && cd "${_nowhere}"/build/binutils-"${_target}"
        PATH="${_path_hack}" "${_nowhere}"/build/"${_binutils_path}"/configure \
          --target="${_target}" \
          --enable-lto \
          --enable-plugins \
          --enable-deterministic-archives \
          --disable-multilib \
          --disable-nls \
          --disable-werror \
          --prefix="${_dstdir}" \
          ${_commonconfig}
        PATH="${_path_hack}" make -j$(nproc) || exit 1
      done
      for _target in ${_targets}; do
        echo -e "Installing ${_target} cross binutils"
        cd "${_nowhere}"/build/binutils-"${_target}"
        PATH="${_path_hack}" make install
      done

      # mingw-w64-headers
      for _target in ${_targets}; do
        echo -e "Configuring ${_target} headers"
        mkdir -p "${_nowhere}"/build/headers-"${_target}" && cd "${_nowhere}"/build/headers-"${_target}"
        PATH="${_path_hack}" "${_nowhere}"/build/"${_mingw_path}"/mingw-w64-headers/configure \
          --enable-sdk=all \
          --enable-secure-api \
          --host="${_target}" \
          --prefix="${_dstdir}"/"${_target}"
        PATH="${_path_hack}" make || exit 1
      done
      for _target in ${_targets}; do
        echo -e "Installing ${_target} headers"
        cd "${_nowhere}"/build/headers-"${_target}"
        PATH="${_path_hack}" make install
        rm "${_dstdir}"/"${_target}"/include/pthread_signal.h
        rm "${_dstdir}"/"${_target}"/include/pthread_time.h
        rm "${_dstdir}"/"${_target}"/include/pthread_unistd.h
      done

      # mingw-w64-headers-bootstrap
      _dummystring="/* Dummy header, which gets overriden, if winpthread library gets installed.  */"
      mkdir -p "${_nowhere}"/build/dummy/ && cd "${_nowhere}"/build/dummy
      echo "${_dummystring}" > pthread_signal.h
      echo "${_dummystring}" > pthread_time.h
      echo "${_dummystring}" > pthread_unistd.h
      for _target in ${_targets}; do
        install -Dm644 "${_nowhere}"/build/dummy/pthread_signal.h "${_dstdir}"/"${_target}"/include/pthread_signal.h
        install -Dm644 "${_nowhere}"/build/dummy/pthread_time.h "${_dstdir}"/"${_target}"/include/pthread_time.h
        install -Dm644 "${_nowhere}"/build/dummy/pthread_unistd.h "${_dstdir}"/"${_target}"/include/pthread_unistd.h
      done

      # Use a separate src dir for mingw-w64-gcc-base
      cp -r "${_nowhere}"/build/gcc "${_nowhere}"/build/gcc.base
      # glibc-2.31 workaround
      #sed -e '1161 s|^|//|' -i ${_nowhere}/build/gcc/libsanitizer/sanitizer_common/sanitizer_platform_limits_posix.cc
      #sed -e '1161 s|^|//|' -i ${_nowhere}/build/gcc.base/libsanitizer/sanitizer_common/sanitizer_platform_limits_posix.cc

      # mingw-w64-gcc-base
      if [ "$_dwarf2" == "true" ]; then
        _exceptions_args="--disable-sjlj-exceptions --with-dwarf2"
      else
        _exceptions_args="--disable-dw2-exceptions"
      fi
      #do not install libiberty
      sed -i 's/install_to_$(INSTALL_DEST) //' "${_nowhere}"/build/gcc.base/libiberty/Makefile.in
      # hack! - some configure tests for header files using "$CPP $CPPFLAGS"
      sed -i "/ac_cpp=/s/\$CPPFLAGS/\$CPPFLAGS -O2/" "${_nowhere}"/build/gcc.base/{libiberty,gcc}/configure
      for _target in ${_targets}; do
        echo -e "Building "${_target}" GCC C compiler"
        mkdir -p "${_nowhere}"/build/gcc-base-"${_target}" && cd "${_nowhere}"/build/gcc-base-"${_target}"
        PATH="${_path_hack}" "${_nowhere}"/build/gcc.base/configure \
          --target="${_target}" \
          --enable-languages=c,lto \
          --with-system-zlib \
          --enable-lto \
          --disable-nls \
          --enable-version-specific-runtime-libs \
          --disable-multilib \
          --enable-checking=release \
          --with-isl="${_dstdir}" \
          --with-gmp="${_dstdir}" \
          --with-mpfr="${_dstdir}" \
          --with-mpc="${_dstdir}" \
          --prefix="${_dstdir}" \
          ${_exceptions_args} \
          ${_commonconfig} \
          ${_libelf_flag}
        PATH=${_path_hack} make -j$(nproc) all-gcc || exit 1
      done
      for _target in ${_targets}; do
        echo -e "Installing ${_target} GCC C compiler"
        cd "${_nowhere}"/build/gcc-base-"${_target}"
        PATH="${_path_hack}" make install-gcc
        strip "${_dstdir}"/bin/"${_target}"-* || true
        strip "${_dstdir}"/libexec/gcc/"${_target}"/"${_gcc_version}"/{cc1,collect2,lto*} || true
      done

      # mingw-w64-crt
      for _target in ${_targets}; do
        echo -e "Building ${_target} CRT"
        if [ "${_target}" == "i686-w64-mingw32" ]; then
          _crt_configure_args="--disable-lib64 --enable-lib32"
        elif [ "${_target}" == "x86_64-w64-mingw32" ]; then
          _crt_configure_args="--disable-lib32 --enable-lib64"
        fi
        mkdir -p "${_nowhere}"/build/crt-"${_target}" && cd "${_nowhere}"/build/crt-"${_target}"
        PATH="${_path_hack}" "${_nowhere}"/build/"${_mingw_path}"/mingw-w64-crt/configure \
          --host="${_target}" \
          --enable-wildcard \
          ${_crt_configure_args} \
          --prefix="${_dstdir}"/"${_target}"
        PATH="${_path_hack}" make -j$(nproc) || exit 1
      done
      for _target in ${_targets}; do
        echo -e "Installing ${_target} crt"
        cd "${_nowhere}"/build/crt-"${_target}"
        PATH="${_path_hack}" make install
      done

      # mingw-w64-winpthreads
      for _target in ${_targets}; do
        echo -e "Building ${_target} winpthreads..."
        mkdir -p "${_nowhere}"/build/winpthreads-build-"${_target}" && cd "${_nowhere}"/build/winpthreads-build-"${_target}"
        PATH="${_path_hack}" "${_nowhere}"/build/"${_mingw_path}"/mingw-w64-libraries/winpthreads/configure \
          --host="${_target}" \
          --prefix="${_dstdir}"/"${_target}" \
          ${_commonconfig}
        PATH="${_path_hack}" make -j$(nproc) || exit 1
      done
      for _target in ${_targets}; do
        cd "${_nowhere}"/build/winpthreads-build-"${_target}"
        PATH="${_path_hack}" make install
        "${_target}"-strip --strip-unneeded "${_dstdir}"/"${_target}"/bin/*.dll  || true
      done

      # mingw-w64-gcc
      if [ "$_dwarf2" == "true" ]; then
        _exceptions_args="--disable-sjlj-exceptions --with-dwarf2"
      else
        _exceptions_args="--disable-dw2-exceptions"
      fi

      ## languages
      _mingw_lang_args="--enable-languages=c,lto,c++,objc,obj-c++"
      if [ "$_fortran" == "true" ]; then
        _mingw_lang_args+=",fortran"
      fi
      if [ "$_ada" == "true" ]; then
        _mingw_lang_args+=",ada"
      fi

      if [ "$_win32threads" == "true" ]; then
        _win32threads_args="--enable-threads=win32"
      else
        _win32threads_args="--enable-threads=posix"
      fi
      for _target in ${_targets}; do
        mkdir -p "${_nowhere}"/build/gcc-build-"${_target}" && cd "${_nowhere}"/build/gcc-build-"${_target}"
        PATH="${_path_hack}" "${_nowhere}"/build/gcc/configure \
          --with-pkgversion='TkG-mostlyportable' \
          --target="${_target}" \
          --libexecdir="${_dstdir}"/lib \
          ${_mingw_lang_args} \
          --disable-shared \
          --enable-fully-dynamic-string \
          --enable-libstdcxx-time=yes \
          --enable-libstdcxx-filesystem-ts=yes \
          --with-system-zlib \
          --enable-cloog-backend=isl \
          --enable-lto \
          --enable-libgomp \
          --disable-multilib \
          --enable-checking=release \
          --with-isl="${_dstdir}" \
          --with-gmp="${_dstdir}" \
          --with-mpfr="${_dstdir}" \
          --with-mpc="${_dstdir}" \
          --prefix="${_dstdir}" \
          ${_exceptions_args} \
          ${_fortran_args} \
          ${_win32threads_args} \
          ${_libelf_flag}
        make -j$(nproc) || exit 1
      done
      for _target in ${_targets}; do
        cd "${_nowhere}"/build/gcc-build-"${_target}"
        PATH="${_path_hack}" make install
        "${_target}"-strip "${_dstdir}"/"${_target}"/lib/*.dll || true
        strip "${_dstdir}"/bin/"${_target}"-* || true
        if [ "$_fortran" == "false" ]; then
          strip "${_dstdir}"/lib/gcc/"${_target}"/"${_gcc_version}"/{cc1*,collect2,gnat1,lto*} || true
        else
          strip "${_dstdir}"/lib/gcc/"${_target}"/"${_gcc_version}"/{cc1*,collect2,gnat1,f951,lto*} || true
        fi
        ln -s "${_target}"-gcc "${_dstdir}"/bin/"${_target}"-cc
        # mv dlls
        mkdir -p "${_dstdir}"/"${_target}"/bin/
        mv "${_dstdir}"/"${_target}"/lib/*.dll "${_dstdir}"/"${_target}"/bin/ || true
      done
      for _binaries in "${_dstdir}"/bin/*; do
        if [[ "$_binaries" != *"eu"* ]]; then
          strip "$_binaries" || true
        fi
      done
      # remove unnecessary files
      rm -rf "${_dstdir}"/share
      rm -f "${_dstdir}"/lib/libcc1.*
      # create lto plugin link
      mkdir -p "${_dstdir}"/lib/bfd-plugins
      ln -sf "../gcc/x86_64-w64-mingw32/${_gcc_version}/liblto_plugin.so" "${_dstdir}"/lib/bfd-plugins/liblto_plugin.so
    else
      export PATH=${_path_hack}

      # binutils
      cd "${_nowhere}"/build/"${_binutils_path}"
      # hack! - libiberty configure tests for header files using "$CPP $CPPFLAGS"
      sed -i "/ac_cpp=/s/\$CPPFLAGS/\$CPPFLAGS -O2/" libiberty/configure
      mkdir -p "${_nowhere}"/build/binutils-build && cd "${_nowhere}"/build/binutils-build
      "${_nowhere}"/build/"${_binutils_path}"/configure \
        --prefix=${_dstdir} \
        --with-lib-path="${_dstdir}/lib" \
        --enable-deterministic-archives \
        --enable-gold \
        --enable-ld=default \
        --enable-lto \
        --enable-plugins \
        --enable-relro \
        --enable-targets=x86_64-pep \
        --enable-threads \
        --disable-gdb \
        --disable-werror \
        --with-pic \
        --with-system-zlib \
        ${_commonconfig}
        make -j$(nproc) configure-host || exit 1
        make -j$(nproc) tooldir="${_dstdir}" || exit 1
        make -j$(nproc) prefix="${_dstdir}" tooldir="${_dstdir}" install
        # Remove unwanted files
        rm -f "${_dstdir}"/share/man/man1/{dlltool,nlmconv,windres,windmc}*

      # gcc

      ## languages
      _gcc_lang_args="--enable-languages=c,c++,lto"
      if [ "$_fortran" == "true" ]; then
        _gcc_lang_args+=",fortran"
      fi
      if [ "$_ada" == "true" ]; then
        _gcc_lang_args+=",ada"
      fi

      mkdir -p ${_nowhere}/build/gcc_build && cd ${_nowhere}/build/gcc_build
      # hack! - libiberty configure tests for header files using "$CPP $CPPFLAGS"
      sed -i "/ac_cpp=/s/\$CPPFLAGS/\$CPPFLAGS -O2/"  "${_nowhere}"/build/gcc/{libiberty,gcc}/configure
      # glibc-2.31 workaround
      #sed -e '1161 s|^|//|' -i ${_nowhere}/build/gcc/libsanitizer/sanitizer_common/sanitizer_platform_limits_posix.cc
      ${_nowhere}/build/gcc/configure \
        --with-pkgversion='TkG-mostlyportable' \
        --disable-bootstrap \
        ${_gcc_lang_args} \
        --with-gcc-major-version-only \
        --enable-linker-build-id \
        --disable-libstdcxx-pch \
        --without-included-gettext \
        --enable-libgomp \
        --enable-lto \
        --enable-threads=posix \
        --enable-tls \
        --enable-nls \
        --enable-clocale=gnu \
        --enable-libstdcxx-time=yes \
        --with-default-libstdcxx-abi=new \
        --enable-gnu-unique-object \
        --disable-vtable-verify \
        --enable-plugin \
        --enable-default-pie \
        --with-target-system-zlib=auto \
        --with-system-zlib \
        --enable-multiarch \
        --with-arch-32=i686 \
        --with-abi=m64 \
        --with-multilib-list=m32,m64 \
        --enable-multilib \
        --disable-werror \
        --enable-checking=release \
        --with-fpmath=sse \
        --prefix="${_dstdir}" \
        --with-tune=generic \
        --without-cuda-driver \
        --with-isl="${_dstdir}" \
        --with-gmp="${_dstdir}" \
        --with-mpfr="${_dstdir}" \
        --with-mpc="${_dstdir}" \
        --enable-offload-targets=nvptx-none \
        --build=x86_64-linux-gnu \
        --host=x86_64-linux-gnu \
        --target=x86_64-linux-gnu \
        ${_libelf_flag}
        #--enable-libstdcxx-debug
      make -j$(nproc) || exit 1
      make install
      ln -s gcc ${_dstdir}/bin/cc

      #libgcc
      cd ${_nowhere}/build/gcc_build
      make -C x86_64-linux-gnu/libgcc install
      make -C x86_64-linux-gnu/32/libgcc install
      make -C libcpp install
      make -C gcc install-po
      make -C x86_64-linux-gnu/libgcc install-shared
      make -C x86_64-linux-gnu/32/libgcc install-shared
      rm -f "${_dstdir}/lib/gcc/x86_64-linux-gnu/${_gcc_version}/libgcc_eh.a"
      rm -f "${_dstdir}/lib/gcc/x86_64-linux-gnu/${_gcc_version}/32/libgcc_eh.a"
      for lib in libatomic \
           libgomp \
           libitm \
           libquadmath \
           libsanitizer/{a,l,ub,t}san \
           libstdc++-v3/src \
           libvtv; do
        make -C x86_64-linux-gnu/$lib install-toolexeclibLTLIBRARIES
      done
      for lib in libatomic \
           libgomp \
           libitm \
           libquadmath \
           libsanitizer/{a,l,ub}san \
           libstdc++-v3/src \
           libvtv; do
        make -C x86_64-linux-gnu/32/$lib install-toolexeclibLTLIBRARIES
      done
      make -C x86_64-linux-gnu/libstdc++-v3/po install
    fi

    if [ "$_mingwbuild" == "true" ]; then
      _tgtname="mingw-mostlyportable"
    else
      _tgtname="gcc-mostlyportable"
    fi

    # Remove previous build based on the same version if present
    _fullversion_pathstring="${_nowhere}/${_tgtname}-${_gcc_version}${_gcc_sub}"
    if [ -d "${_fullversion_pathstring}" ]; then
      rm -rf "${_fullversion_pathstring}"
    fi

    if [ "$_mingwbuild" != "true" ]; then
      echo -e "BUILT_GCC_PATH=\"${_fullversion_pathstring}\"" >> "$_nowhere"/last_build_config.log
    fi

    mv "${_dstdir}" "${_fullversion_pathstring}" && echo -e "\n\n## Your portable ${_tgtname} build can be found at ${_fullversion_pathstring} and can be moved anywhere.\n\n"
    echo -e "## Depending on your needs, either add bin/lib/include dirs of your build to PATH or\nset CC to the bin/*tool* path to use to build your program\n(example: CC=${_fullversion_pathstring}/bin/gcc)\n"
  }

  set -e

  if [ "$1" != "gcc" ] && [ "$1" != "mingw" ] && [ "$1" != "all" ]; then
    echo -e "What do you want to build?"
    read -rp "`echo $'  > 1.GCC\n    2.MinGW-w64-GCC\n    3.Both: build GCC then build MinGW-w64-GCC with it (this can fix issues with mismatching GCC)\nchoice[1-3?]: '`" _builtype;
  fi

  if [ "$_builtype" == "3" ] || [ "$1" == "all" ]; then
    ./mostlyportable-gcc.sh gcc
    ./mostlyportable-gcc.sh mingw
  else
    if [ "$_builtype" == "2" ] || [ "$1" == "mingw" ]; then
      # mingw
      source "${_nowhere}"/mostlyportable-mingw.cfg && echo -e "\nUsing MinGW config\n"
      _mingwbuild="true"
    elif [ "$_builtype" != "2" ] && [ "$_builtype" != "3" ] || [ "$1" == "gcc" ]; then
      # gcc
      source "${_nowhere}"/mostlyportable-gcc.cfg && echo -e "\nUsing GCC config\n"
    fi
    _init && _build

    if [ ! -e "/etc/ld.so.conf.d/50-mostlyportable-gcc.conf" ] && [ ! -e "/etc/ld.so.conf.d/50-libva1.conf" ] && [ ! -e "/etc/ld.so.conf.d/50-lib32-libva1.conf" ]; then
      echo -e "  If no package currently installed adds your usual lib paths to '/etc/ld.so.conf.d/',\nyou'll need to copy the 50-mostlyportable-gcc.conf file to '/etc/ld.so.conf.d/'.\nOn Archlinux, you can alternatively install libva1 and lib32-libva1 packages to get those paths set."
      echo -e "  Do you want to copy 50-mostlyportable-gcc.conf to '/etc/ld.so.conf.d/' now? This only needs to be done once."
      read -rp "`echo $'     > N/y : '`" _ldconfmostlyportable;
      if [ "$_ldconfmostlyportable" = "y" ]; then
        sudo cp "${_nowhere}"/50-mostlyportable-gcc.conf /etc/ld.so.conf.d/ && sudo ldconfig
      else
        exit 0
      fi
    fi
  fi
