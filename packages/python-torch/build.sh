TERMUX_PKG_HOMEPAGE=https://pytorch.org/
TERMUX_PKG_DESCRIPTION="Tensors and Dynamic neural networks in Python"
TERMUX_PKG_LICENSE="BSD 3-Clause"
TERMUX_PKG_MAINTAINER="@termux"
TERMUX_PKG_VERSION="2.10.0"
TERMUX_PKG_REVISION=3
TERMUX_PKG_SRCURL=git+https://github.com/pytorch/pytorch
TERMUX_PKG_UPDATE_TAG_TYPE="latest-release-tag"
TERMUX_PKG_DEPENDS="abseil-cpp, libc++, libopenblas, libprotobuf, python, python-numpy, python-pip"
TERMUX_PKG_BUILD_DEPENDS="vulkan-headers, vulkan-loader-android"
TERMUX_PKG_HOSTBUILD=true
TERMUX_PKG_PYTHON_COMMON_BUILD_DEPS="wheel, pyyaml, typing_extensions"
TERMUX_PKG_PYTHON_CROSS_BUILD_DEPS="numpy"

TERMUX_PKG_EXTRA_CONFIGURE_ARGS="
-DCMAKE_POLICY_VERSION_MINIMUM=3.5
-DANDROID_NO_TERMUX=OFF
-DBUILD_CUSTOM_PROTOBUF=OFF
-DBUILD_PYTHON=ON
-DBUILD_TEST=OFF
-DCMAKE_BUILD_TYPE=Release
-DCMAKE_INSTALL_PREFIX=${TERMUX_PKG_SRCDIR}/torch
-DCMAKE_PREFIX_PATH=${TERMUX_PYTHON_HOME}/site-packages
-DPython_NumPy_INCLUDE_DIR=${TERMUX_PYTHON_HOME}/site-packages/numpy/_core/include
-DNATIVE_BUILD_DIR=${TERMUX_PKG_HOSTBUILD_DIR}
-DTORCH_BUILD_VERSION=${TERMUX_PKG_VERSION}
-DONNX_USE_PROTOBUF_SHARED_LIBS=ON
-DUSE_NUMPY=ON
-DUSE_CUDA=OFF
-DUSE_FAKELOWP=OFF
-DUSE_FBGEMM=OFF
-DUSE_ITT=OFF
-DUSE_MAGMA=OFF
-DUSE_NCCL=OFF
-DUSE_NNPACK=ON
-DUSE_XNNPACK=ON
-DUSE_PYTORCH_QNNPACK=ON
-DUSE_VULKAN=ON
-DUSE_DISTRIBUTED=ON
-DUSE_OPENMP=ON
-DBLAS=OpenBLAS
-DUSE_EIGEN_FOR_BLAS=OFF
-DUSE_MKLDNN=OFF
-DANDROID_NDK=${NDK}
-DANDROID_NDK_HOST_SYSTEM_NAME=linux-$HOSTTYPE
"

TERMUX_PKG_RM_AFTER_INSTALL="
lib/pkgconfig
lib/cmake/fmt
lib/libfmt.a
include/fmt
"

termux_step_host_build() {
    termux_setup_cmake
    cmake "$TERMUX_PKG_SRCDIR/third_party/sleef"
    make -j "$TERMUX_PKG_MAKE_PROCESSES" mkrename mkrename_gnuabi mkmasked_gnuabi mkalias mkdisp
}

termux_step_pre_configure() {
    # --- OTIMIZAÇÕES DE HARDWARE (O PONTO CHAVE) ---
    # Ativa instruções específicas para ARMv8.6-A (BF16, I8MM, DotProd)
    # Trocamos -Oz por -O3 para máxima performance computacional
    export CFLAGS=" -march=armv8.6-a+fp16+dotprod+i8mm+bf16 -O3"
    export CXXFLAGS=" -march=armv8.6-a+fp16+dotprod+i8mm+bf16 -O3"
    LDFLAGS+=" -fopenmp -static-openmp"

    export PYTHONPATH="${PYTHONPATH}:${TERMUX_PKG_SRCDIR}"
    find "$TERMUX_PKG_SRCDIR" -name CMakeLists.txt -o -name '*.cmake' ! -name 'VulkanCodegen*' |
        xargs -n 1 sed -i \
            -e 's/\([^A-Za-z0-9_]ANDROID\)\([^A-Za-z0-9_]\)/\1_NO_TERMUX\2/g' \
            -e 's/\([^A-Za-z0-9_]ANDROID\)$/\1_NO_TERMUX/g'

    termux_setup_protobuf

    TERMUX_PKG_EXTRA_CONFIGURE_ARGS+="
    -DPython_EXECUTABLE=$(command -v python3)
    -DPROTOBUF_PROTOC_EXECUTABLE=$(command -v protoc)
    -DCAFFE2_CUSTOM_PROTOC_EXECUTABLE=$(command -v protoc)
    "

    ln -sf "$TERMUX_PKG_BUILDDIR" build
}

termux_step_make_install() {
    export PYTORCH_BUILD_VERSION=${TERMUX_PKG_VERSION}
    export PYTORCH_BUILD_NUMBER=0
    pip -v install --no-deps --no-build-isolation --prefix $TERMUX_PREFIX "$TERMUX_PKG_SRCDIR"
    ln -sfr ${TERMUX_PYTHON_HOME}/site-packages/torch/lib/*.so ${TERMUX_PREFIX}/lib
}
