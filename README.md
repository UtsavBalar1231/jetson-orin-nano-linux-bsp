# Bloom Mobile Device BSP

## Setting up the workspace directory

First, let's create a workspace directory named `$WORKSPACE` where all
necessary files will be downloaded, built, and stored.

```bash
export WORKSPACE=/home/<user>/l4t
mkdir -p $WORKSPACE
```

Now, let's clone the BSP repository:

```bash
cd $WORKSPACE
git clone git@github.com:bootkernel/mobile-device-carrier-board.git bsp
cd $WORKSPACE/bsp
```

## Building the project

### Downloading the Nvidia Linux SDK

To start, download the required software including Jetson Linux BSP, rootfs,
and AArch64 gcc 11 toolchain:

```bash
./bsp.sh -u
```

### Installing flash tool dependencies

Make sure to install the flash tool dependencies. For Debian-like systems, run:

```bash
cd $WORKSPACE/Linux_for_Tegra
sudo ./tools/l4t_flash_prerequisites.sh
```

### Preloading rootfs with NVIDIA utils

Next, preload the rootfs with NVIDIA utilities:

```bash
cd $WORKSPACE/Linux_for_Tegra
sudo ./apply_binaries.sh
```

### Building the kernel

Build the kernel using the following command:

```bash
cd $WORKSPACE/bsp
./bsp.sh -k
```

After building, the output binary files will be located out-of-tree in the
`$WORKSPACE/bsp/out` directory:

```bash
# modules
ls -l $WORKSPACE/bsp/out/modules_install
# kernel image
ls -l $WORKSPACE/bsp/out/arch/arm64/boot/Image
# DTB files
ls -l $WORKSPACE/bsp/out/arch/arm64/boot/dts/*.dtb
```

### Patching the L4T BSP

Install the compiled kernel, DTB, kernel modules, and board configuration for
`flash.sh` and **MB2 (BCT)**:

```bash
cd $WORKSPACE/bsp
./bsp.sh -b
# sudo will be required for the last step.
```

## Flashing the board

### Debug UART

Ensure that the Debug USB port is connected to your host PC and the FTDI chip
is enumerated:

```bash
lsusb -d 0403:
# Bus 001 Device 118: ID 0403:6015 Future Technology Devices International, Ltd Bridge(I2C/SPI/UART/FIFO)
sudo dmesg | grep FTDI
# [1740634.745814] usb 1-4: FTDI USB Serial Device converter now attached to ttyUSB0
```

Run the terminal (e.g., minicom) to monitor the debug output:

```bash
sudo minicom -b 115200 -D /dev/ttyUSB0
```

Keep minicom open in a separate terminal tab throughout the flashing process.

### Recovery mode

Enter Recovery Mode before flashing:

- Connect the Recovery USB port to your host PC
- Restart the Jetson board in the FORCE_RECOVERY mode:
  - Ensure the board is powered
  - Press and release the POWER button
- Press and hold the FORCE_RECOVERY (“RECOV”) button
- Press and release the RESET button
- Release the FORCE_RECOVERY button
- Check if the board is detected in recovery mode (e.g., via `lsusb`):

```text
vid 0955 pid 7323, NVIDIA Corp. APX
```

To verify communication with the board in recovery mode, execute:

```bash
cd $WORKSPACE/Linux_for_Tegra
sudo ./flash.sh -Z p3768-0000-p3767-0000-bloom internal
```

### Flashing the QSPI

Ensure all SoC bootloaders and firmware files are up-to-date.
Enter recovery mode and run:

```bash
cd $WORKSPACE/Linux_for_Tegra
sudo ./flash.sh p3768-0000-p3767-0000-bloom internal
```

or

```bash
sudo ./bsp.sh -f
```

The board should reboot, display the UEFI prompt on Debug UART, execute the
L4TLauncher bootloader, and prompt for initial system configuration.
