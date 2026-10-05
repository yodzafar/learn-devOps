# Git (Version Control System) — progress

Legend: `[ ]` not started, `[~]` written, not submitted for review, `[!]` reviewed, needs rework, `[x]` reviewed and accepted (marked `✓`).
Update: you `[ ]` → `[~]`; Claude sets `[x] ... ✓` or `[!] reason` after review.

## Written lessons (task level)

### Lesson 1: Commits and the object model (`git/01-commits/`)

**A. Object model**

- [ ] 1. Anatomy of a commit
- [ ] 2. Content addressing
- [ ] 3. Snapshot not diff
- [ ] 4. Blob without a commit
- [ ] 5. Parent chain

**B. Staging and commits**

- [ ] 6. Patch staging
- [ ] 7. Commit message
- [ ] 8. Reading history
- [ ] 9. Rename detection

**C. .gitignore**

- [ ] 10. Ignore rules
- [ ] 11. Already tracked file
- [ ] 12. Leaked secret

**D. Undoing**

- [ ] 13. Restore variants
- [ ] 14. Three resets
- [ ] 15. Squash with soft reset
- [ ] 16. Revert vs reset
- [ ] 17. Reflog rescue
- [ ] 18. What reflog cannot save
- [ ] 19. Clean dry run

**E. Mini-project**

- [ ] 20. Messy history repair
- [ ] Submission: README complete, .gitignore copy saved, no .env in course repo, `make check` clean, scratch repos removed, self-check questions

### Lesson 2: Branches and merge (`git/02-branches-merge/`)

**A. Branches and HEAD**

- [ ] 1. Branch is a file
- [ ] 2. Detached HEAD
- [ ] 3. Delete and restore

**B. Merge**

- [ ] 4. Fast-forward vs merge commit
- [ ] 5. ff-only refusal
- [ ] 6. Three-way merge
- [ ] 7. Conflict resolution
- [ ] 8. Semantic conflict
- [ ] 9. Revert a merge

**C. Rebase and history rewriting**

- [ ] 10. Rebase changes SHAs
- [ ] 11. Rebase conflict sides
- [ ] 12. Abort and recover
- [ ] 13. Interactive rebase
- [ ] 14. Autosquash
- [ ] 15. Split a commit
- [ ] 16. Rebase onto

**D. Cherry-pick, stash, tags**

- [ ] 17. Backport with cherry-pick
- [ ] 18. Stash internals
- [ ] 19. Tags

**E. Bisect and mini-project**

- [ ] 20. Manual bisect
- [ ] 21. bisect run
- [ ] 22. Release branch drill
- [ ] Submission: README complete with graphs, `task_21.sh` saved, `make check` clean, scratch repos removed, self-check questions

### Lesson 3: Remotes and pull requests (`git/03-remotes-pr/`)

**A. Remotes, fetch, pull**

- [ ] 1. Bare repository
- [ ] 2. Stale tracking ref
- [ ] 3. Inspect before integrating
- [ ] 4. Divergent pull
- [ ] 5. Upstream tracking
- [ ] 6. Prune

**B. Push and force**

- [ ] 7. Non-fast-forward rejection
- [ ] 8. Force overwrites work
- [ ] 9. force-with-lease
- [ ] 10. Rewriting your own branch

**C. SSH and signing**

- [ ] 11. SSH key and config
- [ ] 12. Forged author
- [ ] 13. SSH signing

**D. Forks and pull requests**

- [ ] 14. Fork and upstream
- [ ] 15. PR refs
- [ ] 16. Merge methods
- [ ] 17. Review round
- [ ] 18. Workflow decision

**E. Hooks**

- [ ] 19. commit-msg hook
- [ ] 20. pre-push guard
- [ ] 21. pre-commit framework
- [ ] 22. Team repo setup
- [ ] Submission: README complete, hook scripts and pre-commit config saved, `make check` clean, no keys or tokens committed, scratch repos and GitHub test repos cleaned up, self-check questions

### Lesson 4: Git hostings (`git/04-hostings/`)

**A. Comparison and gh CLI**

- [ ] 1. Hosting choice
- [ ] 2. gh auth
- [ ] 3. Repo from the terminal
- [ ] 4. Raw API

**B. Tokens and deploy keys**

- [ ] 5. Fine-grained token
- [ ] 6. Token in the URL
- [ ] 7. Deploy key
- [ ] 8. Machine identity

**C. Gitea**

- [ ] 9. Compose up
- [ ] 10. Admin and users
- [ ] 11. SSH and HTTPS access
- [ ] 12. Data survives
- [ ] 13. One-time migration
- [ ] 14. Pull mirror
- [ ] 15. Mirror is not backup
- [ ] 16. GitLab on paper

**D. Repository settings**

- [ ] 17. Branch protection as code
- [ ] 18. CODEOWNERS
- [ ] 19. Secrets
- [ ] 20. Protection on Gitea

**E. Module mini-project**

- [ ] 21. Production-ready repository
- [ ] Submission: README complete, `compose.yaml`/`CODEOWNERS`/`protection.json`/`RUNBOOK.md` saved, `make check` clean, no secrets committed, Gitea stack and volume removed, GitHub test repos, tokens and deploy keys deleted, self-check questions
