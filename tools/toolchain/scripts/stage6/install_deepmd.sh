#!/bin/bash -e

# TODO: Review and if possible fix shellcheck errors.
# shellcheck disable=SC1003,SC1035,SC1083,SC1090
# shellcheck disable=SC2001,SC2002,SC2005,SC2016,SC2091,SC2034,SC2046,SC2086,SC2089,SC2090
# shellcheck disable=SC2124,SC2129,SC2144,SC2153,SC2154,SC2155,SC2163,SC2164,SC2166
# shellcheck disable=SC2235,SC2237

[ "${BASH_SOURCE[0]}" ] && SCRIPT_NAME="${BASH_SOURCE[0]}" || SCRIPT_NAME=$0
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_NAME")/.." && pwd -P)"

source "${SCRIPT_DIR}"/common_vars.sh
source "${SCRIPT_DIR}"/tool_kit.sh
source "${SCRIPT_DIR}"/signal_trap.sh
source "${INSTALLDIR}"/toolchain.conf
source "${INSTALLDIR}"/toolchain.env

[ -f "${BUILDDIR}/setup_plumed" ] && rm "${BUILDDIR}/setup_plumed"

DEEPMD_LDFLAGS=''
DEEPMD_LIBS=''

! [ -d "${BUILDDIR}" ] && mkdir -p "${BUILDDIR}"
cd "${BUILDDIR}"

case "$with_deepmd" in
  __INSTALL__)
    echo "==================== Installing DeePMD ===================="
    echo "Installation of DeePMD-kit interface not supported yet."
    echo "Skip installation"
    with_deepmd="__DONTUSE__"
    ;;
  __SYSTEM__)
    echo "==================== Finding DeePMD from system paths ===================="
    check_lib -ldeepmd "DEEPMD"
    add_lib_from_paths DEEPMD_LDFLAGS "libdeepmd*" $LIB_PATHS
    check_lib -ltensorflow_cc "DEEPMD"
    check_lib -ltensorflow_framework "DEEPMD"
    add_lib_from_paths DEEPMD_LDFLAGS "libtensorflow*" $LIB_PATHS
    ;;
  __DONTUSE__) ;;

  *)
    echo "==================== Linking DEEPMD to user paths ===================="
    deepmd_root="$with_deepmd"
    check_dir "${deepmd_root}/include/deepmd"
    check_dir "${deepmd_root}/lib"

    case "$with_tfcc" in 
      __DONTUSE__)
        tensorflow_root="$with_deepmd"
        check_dir "${tensorflow_root}/include"
        check_dir "${tensorflow_root}/lib"
      ;;
      __INSTALL__)
        echo "Installation of TensorFlow C++ Interface not supported yet."
        echo "Skip installation."
      ;;
      __SYSTEM__)
        tensorflow_root="$with_deepmd"
        check_dir "${tensorflow_root}/include"
        check_dir "${tensorflow_root}/lib"
      ;;
      *)
        tensorflow_root="$with_tfcc"
        check_dir "${tensorflow_root}/include"
        check_dir "${tensorflow_root}/lib"
    esac
    DEEPMD_DFLAGS="-D__DEEPMD -DHIGH_PREC"
    DEEPMD_CFLAGS="-I'${deepmd_root}/include/deepmd/' -I'${tensorflow_root}/include'"
    DEEPMD_CXXFLAGS="-std=gnu++11 -I'${deepmd_root}/include/deepmd/' -I'${tensorflow_root}/include'"
    DEEPMD_LDFLAGS="-L'${deepmd_root}/lib' -L'${tensorflow_root}/lib' -Wl,--no-as-needed -Wl,-rpath='${deepmd_root}/lib' -Wl,-rpath='${tensorflow_root}/lib'"
    ;;
esac

if [ "$with_deepmd" != "__DONTUSE__" ]; then
  if [ "$DEEPMD_MODE" == "cpu"]; then
    DEEPMD_LIBS='-ldeepmd_op -ldeepmd -ldeepmd_cc -ltensorflow_cc -ltensorflow_framework -lstdc++'
  elif [[ "$DEEPMD_MODE" == "cuda" ]]; then
    DEEPMD_LIBS='-ldeepmd_op -ldeepmd -ldeepmd_cc -ldeepmd_op_cuda -ltensorflow_cc -ltensorflow_framework -lstdc++'
  if [ "$with_deepmd" != "__SYSTEM__" ]; then
    cat << EOF > "${BUILDDIR}/setup_deepmd"
prepend_path LD_LIBRARY_PATH "$pkg_install_dir/lib"
prepend_path LD_RUN_PATH "$pkg_install_dir/lib"
prepend_path LIBRARY_PATH "$pkg_install_dir/lib"
EOF
    cat "${BUILDDIR}/setup_deepmd" >> $SETUPFILE
  fi

  cat << EOF >> "${BUILDDIR}/setup_deepmd"
export DEEPMD_DFLAGS="${DEEPMD_DFLAGS}"
export DEEPMD_CFLAGS="${DEEPMD_CFLAGS}"
export DEEPMD_CXXFLAGS="${DEEPMD_CXXFLAGS}"
export DEEPMD_LDFLAGS="${DEEPMD_LDFLAGS}"
export DEEPMD_LIBS="${DEEPMD_LIBS}"
export CP_DFLAGS="\${CP_DFLAGS} ${DEEPMD_DFLAGS}"
export CP_CFLAGS="\${CP_CFLAGS} ${DEEPMD_CFLAGS}"
export CP_CXXFLAGS="\${CP_CXXFLAGS} ${DEEPMD_CXXFLAGS}"
export CP_LDFLAGS="\${CP_LDFLAGS} ${DEEPMD_LDFLAGS}"
export CP_LIBS="${DEEPMD_LIBS} \${CP_LIBS}"
EOF
fi

load "${BUILDDIR}/setup_deepmd"
write_toolchain_env "${INSTALLDIR}"

cd "${ROOTDIR}"
report_timing "deepmd"
