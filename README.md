# CKA Journey 🚀

My path to the **Certified Kubernetes Administrator (CKA)**: a real kubeadm lab built from scratch, notes in plain language, and every problem I hit along the way (plus how I fixed it).

> Exam: performance-based, live terminal, 2 hours, ~15–25 tasks, 66% to pass, Kubernetes v1.35.

---

## 📍 Roadmap

| Stage | What | Status |
|---|---|---|
| **0** | Lab setup: 4 VMs, kubeadm cluster, Calico | ✅ Done |
| **1** | Theory: 10 lessons in simple terms | 🔄 In progress |
| **2** | Practical labs on my own cluster | ⏳ |
| **3** | Exam readiness: timed drills + killer.sh | ⏳ |
| **4** | Industry-grade projects | ⏳ |

### Stage 1: Theory lessons
| # | Lesson | Exam weight |
|---|---|---|
| 1 | Key terms | foundation |
| 2 | Architecture | 25% domain |
| 3 | What happens on `kubectl apply` | foundation |
| 4 | Workloads & scheduling | 15% |
| 5 | Networking (Services, Ingress, Gateway API, NetworkPolicy, CNI comparison) | 20% |
| 6 | Storage | 10% |
| 7 | Security & RBAC | part of 25% |
| 8 | Cluster maintenance (upgrade, etcd backup/restore) | part of 25% |
| 9 | Troubleshooting | **30%** |
| 10 | Helm, Kustomize, CRDs | part of 25% |

### Stage 4: Planned projects
1. **Kubernetes attack & defence lab:** attack the cluster (RBAC abuse, token theft, container escape attempts), then defend it with Pod Security Admission, NetworkPolicies, Kyverno and Falco detection rules
2. **Production-grade GitOps platform:** Argo CD, Helm, Gateway API, cert-manager, Prometheus/Grafana, Loki
3. **NetIntent on Kubernetes:** production deployment of my network-automation project
4. **Disaster recovery & chaos:** etcd/Velero backups, chaos testing, runbooks

---

## 📂 Repo structure

```
cka-journey/
├── README.md                     ← you are here
├── 00-lab-setup/
│   ├── README.md                 ← full lab build guide (VMware → working cluster)
│   └── troubleshooting.md        ← real problems I hit and how I fixed them
├── notes/
│   └── concepts.md               ← core concepts in plain language
└── scripts/
    └── prep-node.sh              ← automates node preparation (S-M-S-C-K)
```

## 🧪 My lab at a glance

| Node | Role | IP | CPU / RAM |
|---|---|---|---|
| cp | control plane | 192.168.11.10 | 2 / 4 GB |
| worker1 | worker | 192.168.11.11 | 2 / 3 GB |
| worker2 | worker | 192.168.11.12 | 2 / 3 GB |
| spare | bare node (for join practice) | 192.168.11.13 | 2 / 3 GB |

Ubuntu Server 24.04.5 · containerd 2.2.1 · Kubernetes v1.34.13 (one version behind the exam, on purpose, to practise upgrading) · Calico 3.31.4
