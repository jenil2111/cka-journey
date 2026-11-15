#!/usr/bin/env bash
# prep-node.sh: prepare an Ubuntu 24.04 node for kubeadm (S-M-S-C-K)
#
#   S  Swap off
#   M  Modules (overlay, br_netfilter)
#   S  Sysctl (bridge traffic through iptables, IP forwarding)
#   C  Containerd (with SystemdCgroup = true)
#   K  Kube tools (kubelet, kubeadm, kubectl, held)
#
# Usage:  sudo ./prep-node.sh [k8s-minor-version]     e.g. sudo ./prep-node.sh v1.34
#
# NOTE: in the CKA exam there are no scripts. Know how to do every step by hand.

set -euo pipefail

K8S_VERSION="${1:-v1.34}"

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo $0 ${K8S_VERSION}" >&2
  exit 1
fi

echo "== S: Swap off =="
swapoff -a
# \s matches tabs AND spaces (Ubuntu's fstab uses tabs; '/ swap /' would not match)
sed -i '/\sswap\s/ s/^\([^#]\)/#\1/' /etc/fstab

echo "== M: Kernel modules =="
cat > /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

echo "== S: Sysctl =="
cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system > /dev/null

echo "== C: containerd =="
apt-get update -qq
apt-get install -y -qq containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

echo "== K: Kube tools (${K8S_VERSION}) =="
apt-get install -y -qq apt-transport-https ca-certificates curl gpg
mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL "https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/Release.key" \
  | gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/ /" \
  > /etc/apt/sources.list.d/kubernetes.list
apt-get update -qq
apt-get install -y -qq kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

echo
echo "== VERIFY =="
FAIL=0
check() { if eval "$2" > /dev/null 2>&1; then echo "  ✅ $1"; else echo "  ❌ $1"; FAIL=1; fi; }

check "Swap is off"                  "[ \"\$(swapon --show | wc -l)\" -eq 0 ]"
check "Swap disabled in /etc/fstab"  "! grep -E '^[^#].*\sswap\s' /etc/fstab"
check "overlay loaded"               "lsmod | grep -q '^overlay'"
check "br_netfilter loaded"          "lsmod | grep -q '^br_netfilter'"
check "ip_forward = 1"               "[ \"\$(sysctl -n net.ipv4.ip_forward)\" = 1 ]"
check "bridge-nf-call-iptables = 1"  "[ \"\$(sysctl -n net.bridge.bridge-nf-call-iptables)\" = 1 ]"
check "SystemdCgroup = true"         "grep -q 'SystemdCgroup = true' /etc/containerd/config.toml"
check "containerd active"            "systemctl is-active --quiet containerd"
check "kubeadm installed"            "command -v kubeadm"
check "kube packages held"           "[ \"\$(apt-mark showhold | grep -cE '^(kubelet|kubeadm|kubectl)$')\" -eq 3 ]"

echo
if [[ $FAIL -eq 0 ]]; then
  echo "Node ready for 'kubeadm init' or 'kubeadm join'. Reboot once and re-check to be sure."
else
  echo "Some checks failed. Fix them before running kubeadm." >&2
  exit 1
fi
