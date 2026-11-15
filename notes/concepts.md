# Core Concepts (in plain language)

Everything learned so far, explained simply. Lesson notes will be added as I go.

---

## Kubernetes in one sentence
> You tell Kubernetes **what you want** (desired state). It keeps comparing that with **what's actually running** and fixes any difference, forever.

**Analogy:** a restaurant head chef. You give the order ("3 pastas, always ready"). The chef decides which cook makes what, remakes dropped plates, and adds cooks when it gets busy.

### What Kubernetes does vs what I (the admin) do
| Kubernetes handles | I handle |
|---|---|
| Restarting crashed pods | Building the cluster (kubeadm) |
| Keeping N copies running | Writing the instructions (YAML) |
| Moving pods off dead nodes | Fixing what it can't fix itself (bad images, dead kubelets, broken control plane) |
| Routing traffic to healthy pods | Upgrades, etcd backups, certificates |
| | Security: RBAC, NetworkPolicies |

---

## Node, pod, container

```
Cluster
 └── Nodes        machines (cp, worker1, worker2)
      └── Pods     wrappers, each with its own IP
           └── Containers   the actual apps (nginx, postgres…)
```

### Node = a machine
| Type | Job |
|---|---|
| **Control-plane node** | Runs the "brain" |
| **Worker node** | Runs the apps |

Every node runs: **kubelet** (agent), **containerd** (runtime), **kube-proxy** (Service networking).

### Pod = the smallest thing Kubernetes runs
- Wraps **one or more containers** that share **one IP**, storage, and always the **same node**
- Usually 1 container. Extra helper containers are called **sidecars**.
- **Pods are temporary. They're replaced, never repaired.** A new pod gets a new name and a new IP.
  → That's why **Deployments** (keep N running) and **Services** (stable address) exist.

```bash
kubectl get nodes
kubectl get pods -A -o wide     # -A = all namespaces, -o wide = IP + node
```

---

## Control plane components

| Component | Analogy | Job | Without it… |
|---|---|---|---|
| **kube-apiserver** | Reception desk | The only entry point for everything | Nothing works, kubectl can't connect |
| **etcd** | Records room | The cluster's database | The cluster forgets everything |
| **kube-scheduler** | Dispatcher | Picks which node a new pod runs on | New pods stay `Pending` |
| **kube-controller-manager** | Supervisors | "Asked for 3, see 2 → start 1" loops | No self-healing or scaling |

### Static pods
kubeadm writes the 4 control-plane manifests into **`/etc/kubernetes/manifests/`**. The **kubelet watches that folder** and runs whatever it finds there.
- Named `<component>-<node>`, e.g. `etcd-cp`
- To fix a broken API server in the exam, you **edit the file in that folder**
- They use the **host network**, so their IP = the node IP

### Important paths
| Path | What |
|---|---|
| `/etc/kubernetes/manifests/` | Static pod manifests (control plane) |
| `/etc/kubernetes/pki/` | Certificates |
| `/etc/kubernetes/admin.conf` | Admin kubeconfig (full access!) |
| `/var/lib/kubelet/config.yaml` | Kubelet config (created by init/join) |
| `/usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf` | Kubelet systemd drop-in |
| `/var/lib/kubelet/kubeadm-flags.env` | Extra kubelet flags |

---

## CoreDNS & kube-proxy: why Services work

**Problem:** pods die and get new IPs, so you can't hardcode them.
**Solution:** a **Service** = a stable name + stable virtual IP in front of a group of pods.

| | CoreDNS 📒 | kube-proxy 🚦 |
|---|---|---|
| Job | **Name → Service IP** | **Service IP → a real pod** |
| How | Watches the API, answers DNS (`my-svc.prod.svc.cluster.local`) | Writes **iptables** rules on every node that rewrite + load-balance traffic |
| Runs as | Deployment (2 pods) | DaemonSet (1 per node) |
| Its Service | `kube-dns` → `10.96.0.10` | (none) |

Flow: `pod → "where is my-svc?" → CoreDNS: 10.96.0.50 → kube-proxy rules: → 10.244.2.7`

`10.96.0.50` is **virtual**. No machine owns it, and only kube-proxy's rules make it work. That's why `br_netfilter` + `bridge-nf-call-iptables = 1` are needed.

**Exam checks:**
```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns         # is DNS up?
kubectl run test --image=busybox:1.36 --rm -it -- nslookup my-svc
kubectl get endpoints my-svc     # empty → selector doesn't match pod labels
```

---

## Namespaces
A namespace = a **folder inside the cluster**. Created automatically by the **API server**:

| Namespace | Purpose |
|---|---|
| `default` | Where things go if you don't say otherwise |
| `kube-system` | Kubernetes' own components. Don't put apps here. |
| `kube-public` | Readable by anyone, holds `cluster-info` (used by `kubeadm join`) |
| `kube-node-lease` | Node heartbeats (~10 s). No heartbeat → `NotReady` |

⚠️ **Exam trap:** kubectl defaults to `default`. Forgetting `-n <ns>` = lost marks. Use `-A` for all namespaces.

---

## kubeconfig: how kubectl knows where and who
```
clusters:  WHERE   server: https://192.168.11.10:6443 + CA cert
users:     WHO     client certificate + key
contexts:  cluster + user pairs (name: user@cluster)
current-context:   the one in use now
```
```bash
kubectl config view                  # secrets shown as DATA+OMITTED
kubectl config get-contexts          # list (* = current)
kubectl config use-context <name>    # switch (every exam task starts with this!)
kubectl config current-context
```

---

## Networking basics

### CIDR notation
`10.244.0.0/16` → the first **16 bits** (2 numbers) are fixed → `10.244.0.0`–`10.244.255.255` = 65,536 IPs.
`/24` → first 3 numbers fixed → 256 IPs.

### Pod CIDR rules
1. Must not overlap node, service, home LAN, VPN or Docker (`172.17.0.0/16`) ranges
2. Use a private range (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`)
3. Big enough (`/16` standard)
4. Must match the CNI's config
5. Hard to change later, so choose carefully at `kubeadm init`

### CNI = the pod network plugin
Gives pods IPs, connects pods across nodes, (optionally) enforces NetworkPolicy.

| | Flannel | Calico |
|---|---|---|
| Pod networking | ✅ | ✅ |
| Setup | One file | Operator-based |
| **Enforces NetworkPolicy** | ❌ (policies silently ignored!) | ✅ |
| Default CIDR | `10.244.0.0/16` | `192.168.0.0/16` |

*(Full CNI comparison, including Cilium and others, comes in Lesson 5.)*

---

## Reading pod status
| Status | Meaning | First move |
|---|---|---|
| `Pending` | Not placed on a node yet | `kubectl describe pod` → Events |
| `ContainerCreating` | Placed, pulling images | Wait, or describe if stuck |
| `Init:0/3` | Init containers (setup steps) running | Wait, or check init container logs |
| `Running` + `READY 0/1` | Running but not passing readiness yet | Wait, or check probes |
| `CrashLoopBackOff` | Starts → crashes → restarts, waiting longer each time | **`kubectl logs <pod> --previous`** |
| `ImagePullBackOff` | Can't download the image | Check image name/tag |

A **climbing** RESTARTS count is the warning sign, not a single restart.

## Reading `systemctl status kubelet`
| You see | Meaning | Fix |
|---|---|---|
| `○ inactive (dead)` | Stopped | `systemctl start kubelet` **+ `enable`** |
| `activating (auto-restart)` | Crashing in a loop | `journalctl -u kubelet -n 50` → read why |
| `● active (running)` | Healthy | (none) |
| `enabled` on the Loaded line | Starts at boot | (none) |

---

## kubectl pattern
```
kubectl <action> <thing> [name] [-n namespace] [options]
         get      pods     web    -n prod        -o wide
```
Actions: `get`, `describe`, `logs`, `create`, `apply`, `delete`, `edit`, `explain`
