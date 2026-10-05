# Infrastructure as Code — progress

Legend: `[ ]` not started, `[~]` written, not submitted for review, `[!]` reviewed, needs rework, `[x]` reviewed and accepted (marked `✓`).
Update: you `[ ]` → `[~]`; Claude sets `[x] ... ✓` or `[!] reason` after review.

## Written lessons (task level)

### Lesson 1: IaC overview (`iac/01-intro/`)

**A. Analysis**

- [ ] 1. Manual build inventory
- [ ] 2. Declarative or imperative
- [ ] 3. Provisioning or configuration
- [ ] 4. Mutable vs immutable
- [ ] 5. Tool selection
- [ ] 6. License check

**B. Provisioning with bash**

- [ ] 7. Naive script
- [ ] 8. Idempotent script
- [ ] 9. Changed reporting
- [ ] 10. Drift repair
- [ ] 11. Dry run
- [ ] 12. Removal problem
- [ ] 13. Second host

**C. cloud-init**

- [ ] 14. cloud-init file
- [ ] 15. cloud-init schema error
- [ ] 16. cloud-init runs once
- [ ] 17. Pain summary
- [ ] Submission: make check clean (ShellCheck), scripts and cloud-init.yaml in the folder, all VMs deleted, self-check questions

### Lesson 2: Ansible basics (`iac/02-ansible-basics/`)

**A. Install and inventory**

- [ ] 1. Install and version
- [ ] 2. INI inventory
- [ ] 3. YAML inventory
- [ ] 4. ansible.cfg

**B. Ad-hoc commands and modules**

- [ ] 5. Ping module
- [ ] 6. Ad-hoc idempotency
- [ ] 7. Facts

**C. Playbooks**

- [ ] 8. First playbook
- [ ] 9. Check and diff
- [ ] 10. Jinja2 template
- [ ] 11. Handler
- [ ] 12. Lost handler
- [ ] 13. Variable precedence
- [ ] 14. Loops and conditionals
- [ ] 15. groups without append
- [ ] 16. changed_when and creates
- [ ] 17. failed_when
- [ ] 18. Undefined variable

**D. Mini-project**

- [ ] 19. Bash to playbook
- [ ] Submission: make check clean, playbooks pass --syntax-check and are idempotent (changed=0), no keys or passwords in the repo, VMs cleaned up, self-check questions

### Lesson 3: Ansible roles, Vault and the app server (`iac/03-ansible-roles/`)

**A. Roles and variables**

- [ ] 1. Role skeleton
- [ ] 2. Extract a role
- [ ] 3. defaults vs vars
- [ ] 4. group_vars and host_vars
- [ ] 5. Execution order

**B. Collections**

- [ ] 6. requirements.yml
- [ ] 7. Galaxy role review

**C. Vault**

- [ ] 8. Vault file
- [ ] 9. Secret leaks
- [ ] 10. Vault password file

**D. Tags, lint, inventory**

- [ ] 11. Tags
- [ ] 12. ansible-lint
- [ ] 13. Lint in CI
- [ ] 14. Molecule overview
- [ ] 15. Dynamic inventory

**E. App server project**

- [ ] 16. Base role
- [ ] 17. Firewall role
- [ ] 18. Docker role
- [ ] 19. App stack role
- [ ] 20. Docker bypasses UFW
- [ ] 21. Fresh VM proof
- [ ] Submission: make check and ansible-lint (production profile) clean, fresh VM converges and second run is changed=0, no plaintext secrets in the repo, VM deleted, self-check questions

### Lesson 4: Terraform basics (`iac/04-terraform-basics/`)

**A. Docker provider: first cycle**

- [ ] 1. Install and init
- [ ] 2. First apply
- [ ] 3. Read the state
- [ ] 4. Update or replace
- [ ] 5. Variables and outputs
- [ ] 6. Validation errors

**B. Graph, count, lifecycle**

- [ ] 7. Dependency graph
- [ ] 8. count vs for_each
- [ ] 9. Lifecycle
- [ ] 10. fmt and validate

**C. Drift and state**

- [ ] 11. Drift
- [ ] 12. Lost state
- [ ] 13. Saved plan
- [ ] 14. Docker cleanup

**D. AWS**

- [ ] 15. Provider and identity
- [ ] 16. Network
- [ ] 17. Security group
- [ ] 18. AMI data source
- [ ] 19. EC2 instance
- [ ] 20. Plan reading on AWS
- [ ] 21. S3 bucket
- [ ] 22. Destroy and verify
- [ ] Submission: make check, fmt -check and validate clean, no state/plan/keys in the repo, AWS and Docker resources destroyed and verified, self-check questions

### Lesson 5: Terraform state, modules and CI (`iac/05-terraform-state-modules/`)

**A. Remote state**

- [ ] 1. Bootstrap state bucket
- [ ] 2. Migrate state
- [ ] 3. Lock contention
- [ ] 4. State version recovery
- [ ] 5. Secrets in state

**B. State operations**

- [ ] 6. Rename with moved
- [ ] 7. Import
- [ ] 8. Remove from state
- [ ] 9. Drift detection

**C. Modules and environments**

- [ ] 10. Network module
- [ ] 11. App server module
- [ ] 12. Two environments
- [ ] 13. Registry module review
- [ ] 14. Module versioning

**D. Quality and CI**

- [ ] 15. tflint and config scan
- [ ] 16. Plan on pull request
- [ ] 17. Apply on merge

**E. Terraform + Ansible**

- [ ] 18. Inventory handoff
- [ ] 19. One command environment
- [ ] 20. Final teardown
- [ ] Submission: make check, fmt, validate and tflint clean, make up/down work from scratch, CI plan-on-PR and apply-on-merge run linked, no state/keys in the repo, AWS verified clean, self-check questions
