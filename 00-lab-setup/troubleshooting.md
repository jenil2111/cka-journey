# Troubleshooting Log

Real problems I hit while building the lab. Every one of them is also a realistic CKA exam scenario.

> **Method I follow every time:** read the error → find the evidence (`status`, `logs`, `describe`, `journalctl`) → fix the cause → **verify** → make sure it survives a reboot.

---

## #1 · `SystemdCgroup = false` on worker1

**Symptom:** the node-check line showed
```
SystemdCgroup = false
```
on worker1, while cp showed `true`.

**Why it matters:** the kubelet uses the `systemd` cgroup driver. If containerd uses `cgroupfs`, two managers fight over the same resources, and pods restart randomly once the node joins. Nothing errors loudly at install time, which is what makes this dangerous.

**Fix:**
```bash
sudo vim /etc/containerd/config.toml     # /SystemdCgroup → true
sudo systemctl restart containerd        # a config change does nothing until restart!
grep SystemdCgroup /etc/containerd/config.toml
systemctl is-active containerd
```

**Lesson:** *edit config → restart the service → verify.*

---

## #2 · tigera-operator in `CrashLoopBackOff` (Calico 3.33 on K8s 1.34)

**Symptom:**
```
tigera-operator   tigera-operator-...   0/1   CrashLoopBackOff   4 (44s ago)
```
No `calico-system` namespace. Node stayed `NotReady`, CoreDNS `Pending`.

**Investigation:**
```bash
kubectl logs -n tigera-operator deploy/tigera-operator --previous
```
```
[ERROR] v3 CRD mode requires MutatingAdmissionPolicy support (Kubernetes 1.32+), which this cluster does not serve
```

**Cause:** Calico 3.33's new "v3 CRD mode" depends on the MutatingAdmissionPolicy API, which is **not enabled by default on Kubernetes 1.34**.

**Fix:** remove 3.33 completely, install **Calico 3.31.4** (classic CRDs):
```bash
kubectl delete -f custom-resources.yaml --ignore-not-found
kubectl delete -f https://raw.githubusercontent.com/projectcalico/calico/v3.33.0/manifests/tigera-operator.yaml --ignore-not-found
kubectl delete -f https://raw.githubusercontent.com/projectcalico/calico/v3.33.0/manifests/v3_projectcalico_org-v1beta1.yaml --ignore-not-found
kubectl get crd | grep -c -E 'projectcalico|tigera'    # 0
# then install 3.31.4 (see lab setup §7)
```

**Lessons:**
- `CrashLoopBackOff` → **`kubectl logs --previous`** shows the crashed run's output. The answer is usually in the last line.
- "Latest" isn't always right. Check version compatibility before installing add-ons.
- `kubectl delete -f <file>` cleanly reverses `kubectl create -f <file>`.

---

## #3 · `kubeadm join` failed on worker2: swap came back

**Symptom:**
```
[WARNING Swap]: swap is supported for cgroup v2 only...
[kubelet-check] The kubelet is not healthy after 4m0s
error execution phase kubelet-wait-bootstrap: failed while waiting for the kubelet to start
```

**Investigation:**
```bash
free -h | grep Swap                           # ~3.8Gi → swap is ON
sudo journalctl -u kubelet -n 20 --no-pager   # kubelet refuses to run with swap
```

**Cause:** worker2 was prepared with a script whose permanent-swap line was
```bash
sed -i "/ swap / s/^/#/" /etc/fstab
```
It looks for `swap` surrounded by **spaces**, but Ubuntu writes `/etc/fstab` with **tabs**:
```
/swap.img	none	swap	sw	0	0
```
So the line was never commented out. `swapoff -a` only lasted until the next reboot (the snapshot power-cycle), and swap returned.

**Fix:**
```bash
sudo swapoff -a
sudo vim /etc/fstab                # comment out /swap.img
free -h | grep Swap                # 0B
sudo kubeadm reset -f              # clean up the half-finished join
sudo kubeadm join ...              # join again
```

A second attempt **without** `kubeadm reset` failed with:
```
[ERROR FileAvailable--etc-kubernetes-kubelet.conf]: /etc/kubernetes/kubelet.conf already exists
[ERROR FileAvailable--etc-kubernetes-pki-ca.crt]: /etc/kubernetes/pki/ca.crt already exists
```
These are leftovers from the failed join, and `kubeadm reset -f` removes them.

**Lessons:**
- Always verify that "permanent" changes actually **survive a reboot**.
- Use `\s` (any whitespace) in sed patterns: `sed -i '/\sswap\s/ s/^/#/' /etc/fstab`
- Failed `init`/`join` → **`kubeadm reset -f`** before retrying.
- Multi-step fix → **verify each step** before running the next.

---

## Small gotchas
| Gotcha | Fix |
|---|---|
| `kubeadm join` → `user is not running as root` | Use `sudo` (or `sudo !!` to repeat the last command with sudo) |
| `the bootstrap token is invalid` | The command still had placeholder values, so copy the real line from `kubeadm token create --print-join-command` |
| PowerShell loop pasted into a Linux shell → `syntax error near unexpected token` | Check your prompt: `user@node:~$` = Linux, `PS C:\>` = Windows |
| Typed a command while a script was still running | The input was swallowed by the running program. Wait for the prompt. |
