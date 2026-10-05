# Cloud providers — progress

Legend: `[ ]` not started, `[~]` written, not submitted for review, `[!]` reviewed, needs rework, `[x]` reviewed and accepted (marked `✓`).
Update: you `[ ]` → `[~]`; Claude sets `[x] ... ✓` or `[!] reason` after review.

## Written lessons (task level)

### Lesson 1: Cloud types and differences (`cloud/01-providers/`)

**A. Service models**

- [ ] 1. Classify services
- [ ] 2. Responsibility matrix
- [ ] 3. Your own stack
- [ ] 4. Serverless limits

**B. Regions and availability zones**

- [ ] 5. Measure latency
- [ ] 6. Region differences
- [ ] 7. Failure domains
- [ ] 8. Scope of resources

**C. Responsibility and pricing**

- [ ] 9. Incident analysis
- [ ] 10. Durability is not backup
- [ ] 11. Monthly estimate
- [ ] 12. Same workload elsewhere
- [ ] 13. Purchase models
- [ ] 14. Hidden costs list

**D. Choosing**

- [ ] 15. Verify the mapping table
- [ ] 16. Managed or self-hosted
- [ ] 17. Lock-in audit
- [ ] 18. Provider decision record
- [ ] Submission: all 18 answers with sources and dates, task_5.sh and decision.md present, make check clean, no cloud resources created

### Lesson 2: First setup (`cloud/02-first-setup/`)

**A. Account and root**

- [ ] 1. Create the account
- [ ] 2. Lock down root
- [ ] 3. Budget alert

**B. IAM**

- [ ] 4. Admin identity
- [ ] 5. Install the CLI
- [ ] 6. Who am I
- [ ] 7. Implicit deny
- [ ] 8. Managed policy
- [ ] 9. Custom policy
- [ ] 10. Explicit deny wins
- [ ] 11. Assume a role
- [ ] 12. Wrong principal

**C. CLI**

- [ ] 13. Query and output
- [ ] 14. Credential precedence
- [ ] 15. Region scope

**D. Hygiene and audit**

- [ ] 16. Key rotation
- [ ] 17. Leak drill
- [ ] 18. Read CloudTrail
- [ ] 19. Identity Center
- [ ] 20. Cleanup and baseline
- [ ] Submission: root MFA on and no root keys, both budgets exist, test users/roles/policies/keys deleted (task_20.sh output), no secrets or account ID in files, make check clean

### Lesson 3: Virtual machine, network, S3 (`cloud/03-resources/`)

**A. EC2**

- [ ] 1. Preflight
- [ ] 2. Launch from the console
- [ ] 3. Instance metadata
- [ ] 4. Stop and start
- [ ] 5. Launch from the CLI
- [ ] 6. Security group behavior
- [ ] 7. User data
- [ ] 8. EBS volume

**B. Networking**

- [ ] 9. Inspect the default VPC
- [ ] 10. Build a VPC
- [ ] 11. Break the public subnet
- [ ] 12. Private instance
- [ ] 13. NAT gateway cost
- [ ] 14. NACL is stateless
- [ ] 15. Elastic IP

**C. S3**

- [ ] 16. Bucket basics
- [ ] 17. Versioning and lifecycle
- [ ] 18. Access layers
- [ ] 19. Presigned URL
- [ ] 20. Static website

**D. Integration and cleanup**

- [ ] 21. Instance role to S3
- [ ] 22. Teardown and proof
- [ ] Submission: all 22 answers and task files present, leftovers.sh output empty in all regions, bill checked, no keys or account ID in files, make check clean

### Lesson 4: Deploying applications to a server (`cloud/04-deployment/`)

**A. Server and image**

- [ ] 1. Preflight and plan
- [ ] 2. Provision the server
- [ ] 3. Ship the image

**B. Proxy, DNS, TLS**

- [ ] 4. Run the stack
- [ ] 5. DNS record
- [ ] 6. TLS with staging
- [ ] 7. Break the challenge
- [ ] 8. Production certificate
- [ ] 9. nginx and certbot

**C. Operations**

- [ ] 10. Survive a reboot
- [ ] 11. Crash loop
- [ ] 12. Secrets handling
- [ ] 13. Logs and disk
- [ ] 14. Deploy and rollback
- [ ] 15. Reduce downtime
- [ ] 16. Backup to S3
- [ ] 17. Restore drill
- [ ] 18. Hardening pass

**D. Managed options and mini-project**

- [ ] 19. Managed comparison
- [ ] 20. Runbook
- [ ] 21. Rebuild from the runbook
- [ ] 22. Teardown and proof
- [ ] Submission: all 22 answers and files (compose, Caddyfile, scripts, units, RUNBOOK.md) present, runbook tested on a fresh server, all resources and DNS record removed (leftovers.sh empty), no secrets in repo, make check clean
