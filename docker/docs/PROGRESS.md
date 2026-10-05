# Containerization (Docker) — progress

Legend: `[ ]` not started, `[~]` written, not submitted for review, `[!]` reviewed, needs rework, `[x]` reviewed and accepted (marked `✓`).
Update: you `[ ]` → `[~]`; Claude sets `[x] ... ✓` or `[!] reason` after review.

## Written lessons (task level)

### Lesson 1: Containers (`docker/01-containers/`)

**A. A container is a process**

- [ ] 1. Architecture chain
- [ ] 2. Same kernel
- [ ] 3. PID namespace
- [ ] 4. Namespace IDs
- [ ] 5. cgroup files

**B. Lifecycle**

- [ ] 6. Run modes
- [ ] 7. Lifecycle states
- [ ] 8. Exit codes
- [ ] 9. PID 1 and SIGTERM
- [ ] 10. The --rm flag

**C. Ports, env, diagnostics**

- [ ] 11. Port publishing
- [ ] 12. Environment variables
- [ ] 13. Logs
- [ ] 14. Exec and diff
- [ ] 15. Inspect format

**D. Limits and restart**

- [ ] 16. OOM kill
- [ ] 17. CPU throttling
- [ ] 18. Fork limit
- [ ] 19. Restart policies

**E. Final**

- [ ] 20. Break and diagnose
- [ ] 21. Container report script
- [ ] 22. Cleanup
- [ ] Submission: `make check` and shellcheck clean, lesson containers removed, `app.env` not committed, self-check questions

### Lesson 2: Images (`docker/02-images/`)

**A. Image anatomy**

- [ ] 1. Layers and history
- [ ] 2. Overlay mounts
- [ ] 3. Tag vs digest
- [ ] 4. Deleted file stays

**B. Node.js app**

- [ ] 5. Naive Dockerfile
- [ ] 6. Cache ordering
- [ ] 7. dockerignore
- [ ] 8. Multi-stage Node
- [ ] 9. Signals and exec form
- [ ] 10. Non-root check

**C. Go app**

- [ ] 11. Multi-stage Go
- [ ] 12. scratch vs distroless
- [ ] 13. Build args and labels
- [ ] 14. CMD and ENTRYPOINT
- [ ] 15. Multi-platform build

**D. Security and registry**

- [ ] 16. Leaked secret
- [ ] 17. Dockerfile lint
- [ ] 18. Vulnerability scan
- [ ] 19. Push to registry

**E. Final**

- [ ] 20. Image checklist
- [ ] 21. Cleanup
- [ ] Submission: `make check` clean, `docker build --check` clean for both final Dockerfiles, no tokens or tarballs in the folder, `lesson02/*` images removed, logged out, self-check questions

### Lesson 3: Volumes and networks (`docker/03-volumes-networks/`)

**A. Volumes and mounts**

- [ ] 1. Writable layer is ephemeral
- [ ] 2. Named volume
- [ ] 3. Volume pre-population
- [ ] 4. Bind mount config
- [ ] 5. -v vs --mount
- [ ] 6. tmpfs and read-only
- [ ] 7. Volume lifecycle

**B. Backup and permissions**

- [ ] 8. Backup and restore
- [ ] 9. Logical backup
- [ ] 10. Root-owned files
- [ ] 11. Permission denied

**C. Networking**

- [ ] 12. Default bridge
- [ ] 13. User-defined bridge DNS
- [ ] 14. Network isolation
- [ ] 15. veth pairs
- [ ] 16. localhost trap
- [ ] 17. host and none
- [ ] 18. NAT rules

**D. Healthcheck**

- [ ] 19. Healthcheck states
- [ ] 20. Broken healthcheck

**E. Final**

- [ ] 21. Two-tier app by hand
- [ ] 22. Cleanup
- [ ] Submission: `make check` and shellcheck clean, no `l3-` containers, volumes or networks left, archives and dumps not committed, self-check questions

### Lesson 4: Docker Compose (`docker/04-compose/`)

**A. Basics**

- [ ] 1. First compose file
- [ ] 2. Idempotent up
- [ ] 3. Project name collision
- [ ] 4. Service DNS

**B. Stack**

- [ ] 5. App and Postgres
- [ ] 6. Healthy dependency
- [ ] 7. Redis and migrate job
- [ ] 8. nginx reverse proxy
- [ ] 9. Persistence check

**C. Configuration**

- [ ] 10. Interpolation and .env
- [ ] 11. env_file vs .env
- [ ] 12. Secrets
- [ ] 13. Profiles
- [ ] 14. Override files

**D. Workflow**

- [ ] 15. Compose watch
- [ ] 16. Stale upstream
- [ ] 17. Scale
- [ ] 18. Logs and failure

**E. Final**

- [ ] 19. Production-like stack
- [ ] 20. Cleanup
- [ ] Submission: `make check` clean, `docker compose config -q` passes for base and prod, `.env` and secrets not committed, `.env.example` present, project resources removed, self-check questions

### Lesson 5: Orchestration introduction (Docker Swarm and Kubernetes) (`docker/05-orchestration-intro/`)

**A. Swarm basics (single node)**

- [ ] 1. Swarm init
- [ ] 2. Service and tasks
- [ ] 3. Self-healing
- [ ] 4. Scaling
- [ ] 5. VIP and service DNS

**B. Updates and secrets**

- [ ] 6. Rolling update
- [ ] 7. Failed update and rollback
- [ ] 8. Secrets
- [ ] 9. Secret rotation
- [ ] 10. Compose to stack

**C. Multi-node (dind)**

- [ ] 11. Three-node cluster
- [ ] 12. Scheduling and routing mesh
- [ ] 13. Node failure and drain
- [ ] 14. Quorum reasoning

**D. Kubernetes taste**

- [ ] 15. Concept mapping
- [ ] 16. kind taste
- [ ] 17. Read a manifest

**E. Module mini-project**

- [ ] 18. Stack hardening
- [ ] 19. Zero-downtime release
- [ ] 20. Bad release drill
- [ ] 21. Runbook
- [ ] 22. Cleanup
- [ ] Submission: `make check` and shellcheck clean, `docker stack config` passes, swarm left, dind and kind clusters removed, no secrets, tokens or kubeconfig committed, self-check questions
