#!/usr/bin/env bash
# PIS NodeImageBuildTime customization: bake a PINNED NVIDIA driver into the STANDARD ROOT.
# On current (post-AgentBaker #9694) gen2 VHDs the node carries no /opt/azure/aks-gpu/dkms-marker,
# so CSE cleanUpPrebakedGPUDriver early-returns and this driver survives a --gpu-driver None pool
# with NO workaround. 570.x/580.95 fail to compile on kernel 6.8.0-1073-azure (4-arg
# pci_resize_resource backport); 595.91.07 builds and supports H100 (Hopper).
set -euxo pipefail

DRIVER_VERSION="595.91.07"
RUN="NVIDIA-Linux-x86_64-${DRIVER_VERSION}.run"
URL="https://us.download.nvidia.com/XFree86/Linux-x86_64/${DRIVER_VERSION}/${RUN}"
# SHA256 of the exact runfile this codelab validated. Verifying it before running
# the installer guards against a tampered download / unexpected upstream change.
# If you change DRIVER_VERSION, update this to that runfile's published checksum.
DRIVER_SHA256="ca23c88dd24b07a191644e1e11cfb7bcdd7537305749af40f980018b095e6313"

apt-get update
apt-get install -y build-essential dkms curl

curl -fsSL -o "/tmp/${RUN}" "$URL"
echo "${DRIVER_SHA256}  /tmp/${RUN}" | sha256sum -c -   # aborts the bake on mismatch
chmod +x "/tmp/${RUN}"
# Install into the standard root with DKMS; no X, no questions.
"/tmp/${RUN}" --silent --dkms --no-questions --ui=none --no-x-check --install-libglvnd

# Autoload modules after reboot (the .run ships no persistenced unit).
cat > /etc/modules-load.d/nvidia-custom.conf <<MODS
nvidia
nvidia_uvm
nvidia_modeset
nvidia_drm
MODS

cat > /opt/pis-marker <<MARKER
pis_customized=true
example=custom-driver
driver_version=${DRIVER_VERSION}
install=standard-root .run --dkms
workaround=none
MARKER

# Evidence for the codelab validation block.
/usr/bin/nvidia-smi -L || true
ls -la /opt/azure/aks-gpu/dkms-marker 2>&1 || echo "dkms-marker ABSENT (expected on post-#9694 VHD)"

# Keep the prepared VHD lean: drop the installer and apt metadata.
rm -f "/tmp/${RUN}"
rm -rf /var/lib/apt/lists/*
