# CI/CD — progress

Legend: `[ ]` not started, `[~]` written, not submitted for review, `[!]` reviewed, needs rework, `[x]` reviewed and accepted (marked `✓`).
Update: you `[ ]` → `[~]`; Claude sets `[x] ... ✓` or `[!] reason` after review.

## Written lessons (task level)

### Lesson 1: Introduction to CI/CD (`cicd/01-intro/`)

**A. Analysis**

- [ ] 1. Three terms
- [ ] 2. Pipeline map
- [ ] 3. Artifact or cache
- [ ] 4. Build once violation
- [ ] 5. Secret leak paths
- [ ] 6. DORA estimate
- [ ] 7. Tool choice

**B. Local pipeline**

- [ ] 8. Demo app
- [ ] 9. Dockerfile
- [ ] 10. Makefile pipeline
- [ ] 11. Fail fast
- [ ] 12. Shell variant
- [ ] 13. Immutable tag
- [ ] 14. Dirty tree guard
- [ ] 15. Promotion drill
- [ ] 16. Pipeline timing
- [ ] Submission: `make ci` passes on a clean tree and fails on a broken test, shellcheck/hadolint clean, `make check` clean, test images removed, self-check questions

### Lesson 2: GitHub Actions (`cicd/02-github-actions/`)

**A. First workflow**

- [ ] 1. Repo setup
- [ ] 2. First workflow
- [ ] 3. Break and read
- [ ] 4. actionlint
- [ ] 5. Contexts dump

**B. Speed and outputs**

- [ ] 6. Matrix
- [ ] 7. Cache
- [ ] 8. Artifacts
- [ ] 9. Job outputs
- [ ] 10. Concurrency

**C. Security**

- [ ] 11. Token permissions
- [ ] 12. Pin by SHA
- [ ] 13. Script injection
- [ ] 14. Secrets and masking

**D. Image and deploy gate**

- [ ] 15. Build and push to GHCR
- [ ] 16. Layer cache
- [ ] 17. Environment approval
- [ ] 18. Reusable workflow
- [ ] 19. Self-hosted runner analysis
- [ ] 20. Full pipeline
- [ ] Submission: actionlint clean, latest `main` run green with approved production job, SHA-tagged image in GHCR, demo secret removed, workflow copies in the work folder, `make check` clean, self-check questions

### Lesson 3: GitLab CI (`cicd/03-gitlab-ci/`)

**A. Pipeline basics**

- [ ] 1. Second remote
- [ ] 2. First pipeline
- [ ] 3. Stages vs needs
- [ ] 4. Rules
- [ ] 5. Duplicate pipelines
- [ ] 6. Variables
- [ ] 7. Cache vs artifacts
- [ ] 8. Services

**B. Runner**

- [ ] 9. Runner in Docker
- [ ] 10. Route by tags
- [ ] 11. Executor isolation
- [ ] 12. Runner concurrency

**C. Image and porting**

- [ ] 13. Build with dind
- [ ] 14. Registry and deploy token
- [ ] 15. Environments
- [ ] 16. Include and extends
- [ ] 17. Port and compare
- [ ] Submission: latest `main` pipeline green, no duplicate pipelines, SHA-tagged image in the registry, test variables and deploy token removed, runner container and volume removed, `make check` clean, self-check questions

### Lesson 4: Jenkins and TeamCity (`cicd/04-jenkins-teamcity/`)

**A. Jenkins: server**

- [ ] 1. Run Jenkins
- [ ] 2. Freestyle job
- [ ] 3. Custom image with Docker
- [ ] 4. Controller executors

**B. Jenkins: pipeline**

- [ ] 5. First Jenkinsfile
- [ ] 6. Docker agent
- [ ] 7. Break and read
- [ ] 8. Polling trigger
- [ ] 9. Parallel and stash
- [ ] 10. Credentials
- [ ] 11. Groovy interpolation trap
- [ ] 12. Manual gate
- [ ] 13. JCasC
- [ ] 14. Upkeep audit

**C. TeamCity**

- [ ] 15. Run TeamCity
- [ ] 16. Build configuration
- [ ] 17. Build chain
- [ ] 18. Kotlin DSL

**D. Summary**

- [ ] 19. Four-way comparison
- [ ] Submission: full Jenkins pipeline green with no secrets in console output, Dockerfile/plugins.txt/jenkins.yaml/Jenkinsfile/TeamCity DSL export in the work folder, PAT revoked, containers/volumes/networks removed, `make check` clean, self-check questions

### Lesson 5: Automatic deployment to a server (`cicd/05-auto-deploy/`)

**A. Server and access**

- [ ] 1. Deploy target
- [ ] 2. Deploy user
- [ ] 3. Deploy key
- [ ] 4. known_hosts
- [ ] 5. Forced command

**B. Automatic deploy**

- [ ] 6. Compose with SHA tag
- [ ] 7. Deploy job
- [ ] 8. Smoke test
- [ ] 9. Broken release
- [ ] 10. Exit code propagation
- [ ] 11. Manual rollback
- [ ] 12. Notifications

**C. Zero-downtime deploy**

- [ ] 13. Blue-green locally
- [ ] 14. Blue-green script
- [ ] 15. Graceful shutdown
- [ ] 16. Migration design
- [ ] 17. Migration step

**D. OIDC and mini-project**

- [ ] 18. OIDC to AWS
- [ ] 19. Mini-project: full pipeline
- [ ] 20. Rollback drill
- [ ] 21. Threat review
- [ ] Submission: merge to `main` reaches production untouched, broken release rolled back automatically, rollback workflow timed, no keys/tokens committed, actionlint/shellcheck/`make check` clean, cloud resources and secrets deleted and verified, self-check questions
