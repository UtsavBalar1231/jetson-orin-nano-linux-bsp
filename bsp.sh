#!/usr/bin/env bash

BSP_HOME=$(dirname $(readlink -f $0))
BSP_DIR="${BSP_HOME}/Linux_for_Tegra"
BUILD_DIR="${BUILD_DIR:-$(pwd)/build_nv_sources}"

JETSON_LINUX_MAJOR_VERSION="35"
JETSON_LINUX_MINOR_VERSION="5.0"
JETSON_LINUX_TOOLCHAIN_VERSION="2022.08-1"

OVL_DIR="${BSP_HOME}/bsp_overlay"

CROSS_COMPILE_AARCH64="${BSP_HOME}/toolchain/aarch64--glibc--stable-${JETSON_LINUX_TOOLCHAIN_VERSION}/bin/aarch64-buildroot-linux-gnu-"
KERNEL_CONFIG="tegra_defconfig"
KERNEL_DIR="${BSP_HOME}/kernel"
KERNEL_OUT_DIR="${BSP_HOME}/out"
KERNEL_FLAGS="ARCH=arm64 CROSS_COMPILE=${CROSS_COMPILE_AARCH64} O=${KERNEL_OUT_DIR} LOCALVERSION=-tegra -j$(nproc --all)"

declare -g IS_CROSS_COMPILATION=0
declare -g MENUCONFIG=0

echo "Building BSP for Jetson Linux ${JETSON_LINUX_MAJOR_VERSION}.${JETSON_LINUX_MINOR_VERSION} in: ${BSP_HOME}"

function exit_with_error() {
	echo -en "\033[0;31m"
	echo $1 1>&2
	echo -en "\033[0m"
	exit 1
}

function configure_bsp() {
	# Copy bootloader files to BSP
	cp -rvf ${OVL_DIR}/* ${BSP_DIR}/

	# Copy kernel image, dtb and modules to BSP
	cp -vf ${KERNEL_OUT_DIR}/arch/arm64/boot/dts/*.dtb ${BSP_DIR}/kernel/dtb/
	cp -vf ${KERNEL_OUT_DIR}/arch/arm64/boot/dts/*.dtbo ${BSP_DIR}/kernel/dtb/
	cp -vf ${KERNEL_OUT_DIR}/arch/arm64/boot/Image ${BSP_DIR}/kernel/Image
	pushd ${KERNEL_OUT_DIR}/modules_install
	BZIP=--fast tar --owner root --group root -cjvf ${BSP_DIR}/kernel/kernel_supplements.tbz2 lib/modules
	popd

	# Sync binaries
	pushd ${BSP_DIR}
	sudo ./apply_binaries.sh --target-overlay
	popd
}

function update_bsp() {
	if [ ! -d ${BSP_HOME}/bsp_download ]; then
		mkdir -p ${BSP_HOME}/bsp_download
	fi
	pushd ${BSP_HOME}/bsp_download

	local base_url
	base_url="https://developer.nvidia.com/downloads/embedded/l4t/r${JETSON_LINUX_MAJOR_VERSION}_release_v${JETSON_LINUX_MINOR_VERSION}/release"

	# Driver Package (BSP)
	wget --content-disposition "${base_url}/jetson_linux_r${JETSON_LINUX_MAJOR_VERSION}.${JETSON_LINUX_MINOR_VERSION}_aarch64.tbz2"

	# Sample rootfs
	wget --content-disposition "${base_url}/tegra_linux_sample-root-filesystem_r${JETSON_LINUX_MAJOR_VERSION}.${JETSON_LINUX_MINOR_VERSION}_aarch64.tbz2"

	# Bootlin Toolchain
	wget --content-disposition "${base_url%\/release}/toolchain/aarch64--glibc--stable-${JETSON_LINUX_TOOLCHAIN_VERSION}.tar.bz2"

	popd

	# Extract sources
	pushd ${BSP_HOME}
	tar -xvpf ${BSP_HOME}/bsp_download/Jetson_Linux_R${JETSON_LINUX_MAJOR_VERSION}.${JETSON_LINUX_MINOR_VERSION}_aarch64.tbz2
	if [ ! -d Linux_for_Tegra ]; then
		exit_with_error "Failed to extract Linux_for_Tegra, please check if BSP Driver package is downloaded correctly"
	fi

	tar -xvpf ${BSP_HOME}/bsp_download/Tegra_Linux_Sample-Root-Filesystem_R${JETSON_LINUX_MAJOR_VERSION}.${JETSON_LINUX_MINOR_VERSION}_aarch64.tbz2 -C Linux_for_Tegra/rootfs/

	if [ ! -d toolchain ]; then
		mkdir -p toolchain
	fi
	tar -xvpf ${BSP_HOME}/bsp_download/aarch64--glibc--stable-${JETSON_LINUX_TOOLCHAIN_VERSION}.tar.bz2 -C toolchain
	if [ ! -f ${CROSS_COMPILE_AARCH64}gcc ]; then
		exit_with_error "Failed to extract toolchain, please check if toolchain package is downloaded correctly"
	fi

	popd
}

function build_kernel() {
	if ! command -v make &>/dev/null; then
		exit_with_error "make command is not installed"
	fi

	if [[ "$(uname -m)" =~ "x86" ]]; then
		IS_CROSS_COMPILATION=1
	fi

	# Build kernel config
	make -C ${KERNEL_DIR} ${KERNEL_FLAGS} ${KERNEL_CONFIG}

	if [ $MENUCONFIG -gt 0 ]; then
		make -C ${KERNEL_DIR} ${KERNEL_FLAGS} menuconfig
		echo "menu configuration completed, exiting now"
		exit 0
	fi

	# Build kernel
	make -C ${KERNEL_DIR} ${KERNEL_FLAGS} \
		--output-sync=target Image dtbs modules

	# Install modules
	make -C ${KERNEL_DIR} ${KERNEL_FLAGS} \
		INSTALL_MOD_PATH="${KERNEL_OUT_DIR}/modules_install" --output-sync=target \
		modules_install

	# Check compilation result
	if [ -f ${KERNEL_OUT_DIR}/arch/arm64/boot/Image ]; then
		echo "Kernel successfully compiled"
	else
		exit_with_error "Missing Image file, Kernel compilation failed!"
	fi

	echo "Done, Compiled kernel, modules and dtbs in ${KERNEL_OUT_DIR}"
}

function usage() {
	cat <<EOF

Usage: $0 [options]
This script builds BSP for Jetson Linux ${JETSON_LINUX_MAJOR_VERSION}.${JETSON_LINUX_MINOR_VERSION}
It supports the following options:

	-h, --help
		Show this help message and exit

	-b, --build
		Configure BSP sources

	-u, --update
		Update BSP sources

	-k, --kernel
		Build kernel from sources

EOF
}

if [ $# -eq 0 ]; then
	usage
	exit_with_error "No options specified"
fi

while [ $# -gt 0 ]; do
	case $1 in
	-h | --help)
		usage
		exit 0
		;;
	-b | --build)
		configure_bsp
		;;
	-u | --update)
		update_bsp
		;;
	-k | --kernel)
		build_kernel
		;;
	*)
		usage
		exit_with_error "Invalid option: $1"
		;;
	esac
	shift
done
