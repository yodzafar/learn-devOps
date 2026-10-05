# Kubernetes — progress

Legend: `[ ]` not started, `[~]` written, not submitted for review, `[!]` reviewed, needs rework, `[x]` reviewed and accepted (marked `✓`).
Update: you `[ ]` → `[~]`; Claude sets `[x] ... ✓` or `[!] reason` after review.

## Written lessons (task level)

### Lesson 1: Introduction to Kubernetes (`kubernetes/01-intro/`)

**A. Cluster and components**

- [ ] 1. Install tools
- [ ] 2. Create a cluster
- [ ] 3. Control plane pods
- [ ] 4. Static pods
- [ ] 5. Container runtime

**B. API and objects**

- [ ] 6. API resources
- [ ] 7. kubectl explain
- [ ] 8. Object anatomy
- [ ] 9. Raw API

**C. Reconciliation**

- [ ] 10. Self-healing
- [ ] 11. Ownership chain
- [ ] 12. Scheduler down
- [ ] 13. Spec vs status

**D. kubeconfig and namespaces**

- [ ] 14. kubeconfig anatomy
- [ ] 15. Two clusters
- [ ] 16. Namespaces

**E. Labels and selectors**

- [ ] 17. Labels and selectors
- [ ] 18. Break the selector
- [ ] 19. Labels vs annotations

**F. Integration**

- [ ] 20. Request trace
- [ ] Submission: README with all tasks, `make check` clean, no kubeconfig or secrets in the folder, extra clusters deleted, self-check questions

### Lesson 2: Cluster setup, single node and multi node (`kubernetes/02-cluster-setup/`)

**A. kind**

- [ ] 1. Multi-node kind
- [ ] 2. Node internals
- [ ] 3. Pinned node image
- [ ] 4. Load a local image

**B. minikube**

- [ ] 5. minikube cluster

**C. k3s on Multipass VMs**

- [ ] 6. Multipass VMs
- [ ] 7. k3s server
- [ ] 8. Join agents
- [ ] 9. Remote kubeconfig
- [ ] 10. Bundled components
- [ ] 11. Node failure

**D. kubeadm on Multipass VMs**

- [ ] 12. Prepare nodes
- [ ] 13. kubeadm init
- [ ] 14. Install CNI
- [ ] 15. Join a worker
- [ ] 16. Certificates and manifests
- [ ] 17. Break the kubelet

**E. Verification and management**

- [ ] 18. Health check script
- [ ] 19. Merge kubeconfigs
- [ ] 20. Managed cluster comparison
- [ ] 21. Teardown audit
- [ ] Submission: README, `kind-multi.yaml` and `cluster-health.sh` present, `make check` clean, no tokens or kubeconfigs committed, Multipass VMs and extra clusters deleted, self-check questions

### Lesson 3: First application deployment, nginx (`kubernetes/03-first-deploy/`)

**A. Imperative**

- [ ] 1. Imperative deployment
- [ ] 2. Generate manifests

**B. Declarative**

- [ ] 3. Deployment manifest
- [ ] 4. Service and port-forward
- [ ] 5. kubectl diff
- [ ] 6. Drift

**C. Inspection**

- [ ] 7. Describe and events
- [ ] 8. Logs
- [ ] 9. Exec and debug

**D. Rollout**

- [ ] 10. Rolling update
- [ ] 11. Failed rollout
- [ ] 12. Rollback

**E. ConfigMap**

- [ ] 13. nginx config from ConfigMap
- [ ] 14. Config update
- [ ] 15. Broken config

**F. Ingress**

- [ ] 16. Ingress routing
- [ ] 17. Path routing
- [ ] 18. Ingress ecosystem status

**G. Debugging**

- [ ] 19. Pending pod
- [ ] 20. Config error

**H. Integration**

- [ ] 21. Static site
- [ ] Submission: README and manifests, `make check` clean, server dry-run of `manifests/site/` clean, namespaces deleted, cloud-provider-kind stopped, self-check questions

### Lesson 4: Workload types (`kubernetes/04-workloads/`)

**A. Pod**

- [ ] 1. Bare pod
- [ ] 2. Pod phases
- [ ] 3. Graceful shutdown
- [ ] 4. Shared namespaces

**B. Init and sidecar containers**

- [ ] 5. Init container
- [ ] 6. Native sidecar

**C. Probes**

- [ ] 7. Readiness probe
- [ ] 8. Liveness probe
- [ ] 9. Startup probe

**D. Resources**

- [ ] 10. QoS classes
- [ ] 11. OOMKilled
- [ ] 12. Requests and scheduling

**E. Controllers**

- [ ] 13. ReplicaSet ownership
- [ ] 14. Rollout math
- [ ] 15. Stuck rollout
- [ ] 16. DaemonSet
- [ ] 17. StatefulSet identity

**F. Configuration**

- [ ] 18. ConfigMap as env and volume
- [ ] 19. Secret
- [ ] 20. Missing key

**G. Integration**

- [ ] 21. Production-ready Deployment
- [ ] Submission: README and `task_N.yaml` manifests, `make check` clean, no Secret manifests committed, namespace deleted, kind nodes restarted, self-check questions

### Lesson 5: Jobs and CronJobs (`kubernetes/05-jobs/`)

**A. Job**

- [ ] 1. First Job
- [ ] 2. Completions and parallelism
- [ ] 3. Restart policies
- [ ] 4. Backoff timing
- [ ] 5. Active deadline
- [ ] 6. TTL cleanup
- [ ] 7. Immutable template
- [ ] 8. Indexed Job
- [ ] 9. Suspend and resume

**B. CronJob**

- [ ] 10. First CronJob
- [ ] 11. Time zone
- [ ] 12. Concurrency policy
- [ ] 13. Manual trigger and suspend
- [ ] 14. Missed schedule detection

**C. Design**

- [ ] 15. Idempotent job
- [ ] 16. Database backup CronJob
- [ ] 17. Break the backup
- [ ] 18. Restore test
- [ ] Submission: README, manifests and scripts, `make check` clean, no passwords or Secret manifests committed, namespace deleted, self-check questions

### Lesson 6: Services (`kubernetes/06-services/`)

**A. ClusterIP and endpoints**

- [ ] 1. ClusterIP Service
- [ ] 2. EndpointSlices
- [ ] 3. Readiness and endpoints
- [ ] 4. Port mapping
- [ ] 5. Selector mismatch

**B. kube-proxy**

- [ ] 6. Virtual IP
- [ ] 7. Load distribution

**C. DNS**

- [ ] 8. DNS names
- [ ] 9. ndots
- [ ] 10. Headless Service
- [ ] 11. ExternalName

**D. External access**

- [ ] 12. NodePort
- [ ] 13. LoadBalancer
- [ ] 14. externalTrafficPolicy
- [ ] 15. Session affinity

**E. L7**

- [ ] 16. Gateway and HTTPRoute
- [ ] 17. Traffic split
- [ ] 18. Ingress vs Gateway

**F. Debugging**

- [ ] 19. MetalLB concepts
- [ ] 20. Debugging runbook
- [ ] 21. Two-tier application
- [ ] Submission: README and manifests, `make check` clean, namespaces deleted, cloud-provider-kind stopped and proxy containers gone, self-check questions

### Lesson 7: Storage (`kubernetes/07-storage/`)

**A. Ephemeral storage**

- [ ] 1. Container filesystem
- [ ] 2. emptyDir
- [ ] 3. Memory-backed emptyDir
- [ ] 4. hostPath

**B. PV and PVC**

- [ ] 5. Static provisioning
- [ ] 6. Binding rules
- [ ] 7. Dynamic provisioning
- [ ] 8. Data survives pod deletion
- [ ] 9. Volume pins the pod

**C. Policies**

- [ ] 10. Reclaim policy Delete
- [ ] 11. Reclaim policy Retain
- [ ] 12. PVC protection
- [ ] 13. RWO semantics
- [ ] 14. Expansion attempt

**D. StorageClass and CSI**

- [ ] 15. Custom StorageClass
- [ ] 16. CSI architecture
- [ ] 17. Stuck volume debugging

**E. Integration**

- [ ] 18. PostgreSQL with persistent data
- [ ] Submission: README and manifests, `make check` clean, no passwords committed, namespace and leftover PVs deleted, nodes uncordoned, self-check questions

### Lesson 8: Certificate management with cert-manager (`kubernetes/08-cert-manager/`)

**A. Helm**

- [ ] 1. Install Helm
- [ ] 2. Install Traefik
- [ ] 3. Release internals
- [ ] 4. Upgrade and rollback

**B. cert-manager**

- [ ] 5. Install cert-manager
- [ ] 6. Self-signed certificate
- [ ] 7. CA chain
- [ ] 8. Issuer scope

**C. Ingress and TLS**

- [ ] 9. TLS Ingress
- [ ] 10. Trust
- [ ] 11. Ownership chain

**D. Renewal**

- [ ] 12. Short-lived certificate
- [ ] 13. Reload behaviour
- [ ] 14. Manual renewal

**E. ACME**

- [ ] 15. ACME staging issuer
- [ ] 16. Failing challenge
- [ ] 17. HTTP-01 vs DNS-01

**F. Integration**

- [ ] 18. Troubleshooting runbook
- [ ] 19. TLS platform
- [ ] 20. Public issuance (optional)
- [ ] Submission: README, manifests, values files and `install.sh`, `make check` clean, no keys or certificates committed, releases uninstalled, cloud resources (if any) deleted, self-check questions


### Lesson 9: CI/CD integration (`kubernetes/09-cicd-integration/`)

**A. Images and tags**

- [ ] 1. Tag vs digest
- [ ] 2. Mutable tag trap
- [ ] 3. Pipeline build by SHA
- [ ] 4. Private image pull

**B. Kustomize and Helm**

- [ ] 5. Kustomize base and overlays
- [ ] 6. ConfigMap hash rollout
- [ ] 7. Write a Helm chart
- [ ] 8. helm lint and template
- [ ] 9. Kustomize or Helm

**C. Validation**

- [ ] 10. kubeconform strict
- [ ] 11. Server dry-run
- [ ] 12. kubectl diff gate

**D. Auth and RBAC**

- [ ] 13. Deployer ServiceAccount
- [ ] 14. Kubeconfig from token
- [ ] 15. can-i audit
- [ ] 16. OIDC design

**E. Pipeline**

- [ ] 17. Validate job
- [ ] 18. Deploy with rollout gate
- [ ] 19. Break the rollout
- [ ] 20. Automatic rollback
- [ ] 21. Push model limits
- [ ] Submission: make check clean, green main run and red broken PR linked, no secrets in repo, kind cluster deleted

### Lesson 10: GitOps: Argo CD and Flux (`kubernetes/10-gitops/`)

**A. Principles and repo**

- [ ] 1. Config repo layout
- [ ] 2. Push vs pull

**B. Argo CD**

- [ ] 3. Install Argo CD
- [ ] 4. First Application
- [ ] 5. Sync vs health
- [ ] 6. Automated sync
- [ ] 7. Prune and selfHeal
- [ ] 8. Rollback the GitOps way
- [ ] 9. Sync waves and hook
- [ ] 10. App of apps
- [ ] 11. ApplicationSet
- [ ] 12. AppProject boundary

**C. Flux**

- [ ] 13. Bootstrap Flux
- [ ] 14. Flux Kustomization
- [ ] 15. Drift and prune in Flux
- [ ] 16. HelmRelease
- [ ] 17. dependsOn ordering
- [ ] 18. Image automation

**D. Comparison**

- [ ] 19. Argo CD vs Flux
- [ ] 20. Incident runbook
- [ ] Submission: make check clean, no secrets in config repo, both kind clusters deleted, token revoked and deploy key removed, repo links in README

### Lesson 11: Production high availability (`kubernetes/11-high-availability/`)

**A. Cluster and baseline**

- [ ] 1. Multi-node cluster
- [ ] 2. Default spreading
- [ ] 3. etcd quorum math

**B. Scheduling**

- [ ] 4. Required anti-affinity
- [ ] 5. Rollout deadlock
- [ ] 6. Preferred anti-affinity
- [ ] 7. Topology spread
- [ ] 8. Node affinity

**C. PDB and drain**

- [ ] 9. Drain without PDB
- [ ] 10. PDB in action
- [ ] 11. PDB that blocks drain
- [ ] 12. Unhealthy pods and PDB

**D. Node failure**

- [ ] 13. Kill a node
- [ ] 14. Tune tolerationSeconds
- [ ] 15. Node returns

**E. Priority and graceful shutdown**

- [ ] 16. Preemption
- [ ] 17. Rollout without preStop
- [ ] 18. Zero-downtime rollout
- [ ] 19. SIGTERM and PID 1

**F. Integration**

- [ ] 20. HA checklist
- [ ] Submission: make check clean, timings and failed-request counts in README, kind cluster deleted

### Lesson 12: Stateful workloads (`kubernetes/12-stateful/`)

**A. StatefulSet**

- [ ] 1. Stable identity
- [ ] 2. Pod replacement
- [ ] 3. Scale and PVC lifecycle
- [ ] 4. Partition canary
- [ ] 5. Stuck rollout
- [ ] 6. Parallel policy

**B. PostgreSQL by hand**

- [ ] 7. Postgres StatefulSet
- [ ] 8. Data survives
- [ ] 9. Why not just replicas 3

**C. Operator**

- [ ] 10. Install CloudNativePG
- [ ] 11. CNPG cluster
- [ ] 12. Failover drill
- [ ] 13. Operator reconcile

**D. Snapshots and backup**

- [ ] 14. VolumeSnapshot
- [ ] 15. Restore from snapshot
- [ ] 16. Snapshot without the pieces
- [ ] 17. Logical backup CronJob
- [ ] 18. Backup plan

**E. Taints and tolerations**

- [ ] 19. Dedicated node
- [ ] 20. NoExecute
- [ ] 21. Database on dedicated nodes
- [ ] Submission: make check clean, failover and restore timings in README, no passwords or cloned repos committed, kind cluster deleted

### Lesson 13: Security: secrets, RBAC, network policies (`kubernetes/13-security/`)

**A. Secrets**

- [ ] 1. base64 is not encryption
- [ ] 2. Secret in etcd
- [ ] 3. Encryption at rest on k3s
- [ ] 4. Sealed Secrets
- [ ] 5. SOPS with age
- [ ] 6. External Secrets Operator

**B. RBAC**

- [ ] 7. Read-only user
- [ ] 8. Role from scratch
- [ ] 9. Privilege escalation paths
- [ ] 10. ServiceAccount token
- [ ] 11. RBAC audit

**C. NetworkPolicy**

- [ ] 12. Does my CNI enforce
- [ ] 13. Three-tier policy
- [ ] 14. DNS egress trap
- [ ] 15. AND vs OR
- [ ] 16. Cross-namespace isolation

**D. Pod Security**

- [ ] 17. Root by default
- [ ] 18. Harden a pod
- [ ] 19. Pod Security Admission

**E. Supply chain and integration**

- [ ] 20. Scan an image
- [ ] 21. Audit policy design
- [ ] 22. Secure namespace baseline
- [ ] Submission: make check clean, no secrets or private keys in repo, kind cluster and k3s VM deleted

### Lesson 14: Autoscaling: HPA, Cluster Autoscaler, KEDA (`kubernetes/14-autoscaling/`)

**A. Metrics**

- [ ] 1. metrics-server
- [ ] 2. Requests as the basis

**B. HPA**

- [ ] 3. First HPA
- [ ] 4. Verify the formula
- [ ] 5. Scale-down timing
- [ ] 6. HPA without requests
- [ ] 7. Tune behavior
- [ ] 8. replicas conflict
- [ ] 9. Wrong signal
- [ ] 10. Load test with k6

**C. VPA and nodes**

- [ ] 11. VPA recommendations
- [ ] 12. Pending pods
- [ ] 13. Node autoscaling on paper

**D. KEDA**

- [ ] 14. Install KEDA
- [ ] 15. Queue-driven scaling
- [ ] 16. Scale to zero
- [ ] 17. TriggerAuthentication
- [ ] 18. Prometheus scaler
- [ ] 19. HTTP and zero

**E. Integration**

- [ ] 20. Autoscaling design
- [ ] Submission: make check clean, timeline per test in README, kind cluster deleted

### Lesson 15: Cost optimization and final project (`kubernetes/15-cost-optimization/`)

**A. Requests and usage**

- [ ] 1. Requested vs used
- [ ] 2. Waste blocks scheduling
- [ ] 3. Right-size from data
- [ ] 4. Cutting too far

**B. Quota and LimitRange**

- [ ] 5. ResourceQuota
- [ ] 6. Quota without defaults
- [ ] 7. LimitRange bounds
- [ ] 8. Object count quota

**C. Visibility and savings**

- [ ] 9. OpenCost
- [ ] 10. Spot simulation
- [ ] 11. Scale non-prod to zero
- [ ] 12. Orphaned resources
- [ ] 13. Cost tradeoffs

**D. Final project**

- [ ] 14. Architecture and repo
- [ ] 15. Cluster and GitOps bootstrap
- [ ] 16. Platform layer
- [ ] 17. Application with TLS
- [ ] 18. Resilience and scaling
- [ ] 19. Security baseline
- [ ] 20. Observability
- [ ] 21. Backup and restore drill
- [ ] 22. Cost estimate
- [ ] Submission: make check clean, README and PROJECT.md complete with repo links, rebuild steps tested, restore drill and cost estimate documented, all resources cleaned up
