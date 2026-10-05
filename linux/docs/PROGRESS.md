# Linux (Operating Systems) — progress

Legend: `[ ]` not started, `[~]` written, not submitted for review, `[!]` reviewed, needs rework, `[x]` reviewed and accepted (marked `✓`).
Update: you `[ ]` → `[~]`; Claude sets `[x] ... ✓` or `[!] reason` after review.

## Written lessons (task level)

### Lesson 1: Introduction to Linux (`linux/01-intro/`)

**A. Kernel and distro**

- [ ] 1. Kernel version
- [ ] 2. Distro identity
- [ ] 3. Shared kernel
- [ ] 4. Userland origin

**B. Boot**

- [ ] 5. Boot artifacts
- [ ] 6. PID 1
- [ ] 7. Boot timing
- [ ] 8. Kernel messages

**C. Filesystem**

- [ ] 9. Root tour
- [ ] 10. One program, four places
- [ ] 11. Virtual filesystems
- [ ] 12. Process as files
- [ ] 13. Device files

**D. Terminal and shell**

- [ ] 14. Which shell
- [ ] 15. Builtin or binary
- [ ] 16. Command anatomy
- [ ] 17. Keyboard signals

**E. Help system**

- [ ] 18. man sections
- [ ] 19. Reading a man page
- [ ] 20. Three help sources
- [ ] 21. Minimal image

**F. Final task**

- [ ] 22. System passport
- [ ] Submission: README complete, `make check` clean, no leftover containers, self-check questions

### Lesson 2: Distributions and the lab (`linux/02-distros/`)

**A. Identifying a distro**

- [ ] 1. os-release fields
- [ ] 2. Four images
- [ ] 3. Detection one-liner
- [ ] 4. Tool presence

**B. Multipass**

- [ ] 5. Install Multipass
- [ ] 6. Launch the lab VM
- [ ] 7. VM versus container
- [ ] 8. Exec and transfer
- [ ] 9. Snapshot and restore
- [ ] 10. Delete and recover

**C. Family differences**

- [ ] 11. First package install
- [ ] 12. Package naming
- [ ] 13. Package ownership
- [ ] 14. Family layout
- [ ] 15. Backported fixes

**D. Releases and EOL**

- [ ] 16. EOL in practice
- [ ] 17. Support table
- [ ] 18. Kernel per distro

**E. Final task**

- [ ] 19. Distro decision
- [ ] 20. Lab cheat sheet
- [ ] Submission: README complete, `make check` clean, containers removed, `lab` VM stopped with `clean` snapshot, self-check questions

### Lesson 3: Basic commands (`linux/03-basic-commands/`)

**A. Navigation and ls**

- [ ] 1. Absolute and relative
- [ ] 2. ls columns
- [ ] 3. Sorting listings
- [ ] 4. Hidden files

**B. Create, copy, move, delete**

- [ ] 5. Tree in one command
- [ ] 6. Three timestamps
- [ ] 7. cp destination semantics
- [ ] 8. cp -r versus cp -a
- [ ] 9. mv and inodes
- [ ] 10. rm safety
- [ ] 11. Empty variable trap

**C. Reading files**

- [ ] 12. less navigation
- [ ] 13. Look before cat

**D. Globbing**

- [ ] 14. Glob preview
- [ ] 15. Brace versus glob
- [ ] 16. Unquoted pattern
- [ ] 17. Hidden and recursive

**E. find**

- [ ] 18. find by tests
- [ ] 19. exec forms
- [ ] 20. delete placement

**F. History**

- [ ] 21. History mechanics

**G. Final task**

- [ ] 22. Project cleanup
- [ ] Submission: README complete, `make check` clean, playground removed, `lab` VM stopped, self-check questions

### Lesson 4: Terminal editors (Nano, Vim) (`linux/04-editors/`)

**A. Nano**

- [ ] 1. Nano basics
- [ ] 2. Nano config
- [ ] 3. Default editor

**B. Vim basics**

- [ ] 4. vimtutor
- [ ] 5. Modes and exit
- [ ] 6. Motions drill
- [ ] 7. Operator grammar
- [ ] 8. Dot and undo

**C. Search and replace**

- [ ] 9. Search
- [ ] 10. Substitute
- [ ] 11. Global command

**D. Visual mode and indentation**

- [ ] 12. Block edit
- [ ] 13. Tabs in YAML

**E. Configuration**

- [ ] 14. Minimal vimrc

**F. Survival**

- [ ] 15. Swap file
- [ ] 16. Read-only file
- [ ] 17. Frozen terminal
- [ ] 18. No editor at all

**G. Final task**

- [ ] 19. Config edit
- [ ] 20. Speed run
- [ ] Submission: README with keystrokes, `nanorc`/`vimrc`/`sshd_config.lab` saved, `make check` clean, VM files restored, self-check questions

### Lesson 5: Shell and environment (`linux/05-shell/`)

**A. Variables and PATH**

- [ ] 1. Shell versus environment
- [ ] 2. Run versus source
- [ ] 3. One-shot variable
- [ ] 4. PATH lookup
- [ ] 5. 126 and 127

**B. Startup files**

- [ ] 6. Load order trace
- [ ] 7. Alias scope
- [ ] 8. Cron-like environment

**C. Quoting**

- [ ] 9. Three quote types
- [ ] 10. Command substitution
- [ ] 11. Word splitting bug

**D. Redirection and exit codes**

- [ ] 12. stdout and stderr
- [ ] 13. sudo redirect trap
- [ ] 14. Truncation trap
- [ ] 15. Here-document
- [ ] 16. Exit codes
- [ ] 17. pipefail

**E. sudo**

- [ ] 18. sudo inspection
- [ ] 19. Restricted sudo rule
- [ ] 20. Broken sudoers

**F. Script**

- [ ] 21. First script
- [ ] 22. shellcheck
- [ ] Submission: README complete, scripts shellcheck-clean, `make check` clean, `deploy` user and sudoers file removed, self-check questions

### Lesson 6: Files: permissions, links, archives (`linux/06-files/`)

**A. Permissions**

- [ ] 1. Reading modes
- [ ] 2. Octal and symbolic
- [ ] 3. Directory bits
- [ ] 4. Delete without write
- [ ] 5. First match wins
- [ ] 6. Path traversal
- [ ] 7. umask
- [ ] 8. Recursive chmod trap

**B. Ownership and special bits**

- [ ] 9. chown rules
- [ ] 10. Shared directory
- [ ] 11. Sticky bit
- [ ] 12. setuid audit

**C. Links**

- [ ] 13. Hard link
- [ ] 14. Symlink
- [ ] 15. Relative symlink trap
- [ ] 16. Release switch
- [ ] 17. System links

**D. Archives**

- [ ] 18. tar roundtrip
- [ ] 19. tar pitfalls
- [ ] 20. Ownership in archives
- [ ] 21. Compression compare

**E. Final task**

- [ ] 22. Backup script
- [ ] Submission: README complete, `task_22.sh` shellcheck-clean, `make check` clean, test users and directories removed, self-check questions

### Lesson 7: Text processing (`linux/07-text/`)

**A. Viewing and streams**

- [ ] 1. First look
- [ ] 2. tail -f and rotation
- [ ] 3. SIGPIPE

**B. grep**

- [ ] 4. Counting 404
- [ ] 5. Context and recursion
- [ ] 6. Regex
- [ ] 7. grep in scripts

**C. cut, sort, uniq, tr**

- [ ] 8. passwd fields
- [ ] 9. uniq needs sort
- [ ] 10. Sort keys
- [ ] 11. tr and line endings
- [ ] 12. cut limits

**D. sed**

- [ ] 13. Substitute
- [ ] 14. Print and delete
- [ ] 15. In-place safely

**E. awk**

- [ ] 16. Fields and filters
- [ ] 17. Aggregation
- [ ] 18. Group by
- [ ] 19. Custom separator

**F. xargs**

- [ ] 20. xargs and spaces
- [ ] 21. Parallel xargs

**G. Final task**

- [ ] 22. Log report
- [ ] Submission: README complete, `task_22.sh` and `report.txt` saved, shellcheck clean, log file not committed, `make check` clean, self-check questions

### Lesson 8: Viewing server resources (`linux/08-resources/`)

**A. Overview and CPU**

- [ ] 1. Load vs cores
- [ ] 2. CPU saturation
- [ ] 3. Single hot core
- [ ] 4. Find the process
- [ ] 5. First vmstat line

**B. Memory**

- [ ] 6. Reading free
- [ ] 7. Page cache in action
- [ ] 8. Memory pressure
- [ ] 9. OOM in a cgroup
- [ ] 10. oom_score

**C. Disk**

- [ ] 11. df vs du
- [ ] 12. Deleted but open
- [ ] 13. I/O wait

**D. Logs and services**

- [ ] 14. journalctl filters
- [ ] 15. Trace a sudo call
- [ ] 16. dmesg
- [ ] 17. Services inventory

**E. Capstone**

- [ ] 18. 60 seconds script
- [ ] 19. Blind diagnosis
- [ ] Submission: make check clean, VM load and big files cleaned up, oomtest container removed, self-check questions

### Lesson 9: Process management (`linux/09-processes/`)

**A. Process model and inspection**

- [ ] 1. Process tree
- [ ] 2. fork and exec
- [ ] 3. ps columns
- [ ] 4. Explore /proc
- [ ] 5. Process states

**B. Job control**

- [ ] 6. jobs, bg, fg
- [ ] 7. SIGHUP on disconnect
- [ ] 8. nohup and disown
- [ ] 9. Reparenting

**C. Signals**

- [ ] 10. Signal table
- [ ] 11. Exit codes
- [ ] 12. STOP and CONT
- [ ] 13. trap script
- [ ] 14. Delayed trap
- [ ] 15. pkill safely
- [ ] 16. PID 1 ignores signals

**D. Priority and zombies**

- [ ] 17. nice under contention
- [ ] 18. renice limits
- [ ] 19. Make a zombie

**E. Capstone**

- [ ] 20. Graceful worker
- [ ] Submission: make check clean, no leftover test processes or containers, self-check questions

### Lesson 10: User management (`linux/10-users/`)

**A. Account files**

- [ ] 1. Who am I
- [ ] 2. Account inventory
- [ ] 3. shadow fields

**B. Creating and modifying**

- [ ] 4. useradd defaults
- [ ] 5. Proper user
- [ ] 6. The -aG trap
- [ ] 7. Group takes effect on login
- [ ] 8. Password aging
- [ ] 9. Locking is not enough
- [ ] 10. Deleting a user

**C. sudo**

- [ ] 11. su vs sudo
- [ ] 12. Scoped sudoers
- [ ] 13. Break sudoers safely
- [ ] 14. Shell escape

**D. SSH and service accounts**

- [ ] 15. Key login for a new user
- [ ] 16. Break key auth
- [ ] 17. Service account

**E. Capstone**

- [ ] 18. Onboarding script
- [ ] 19. Offboarding and cleanup
- [ ] Submission: make check clean, no hashes or private keys in repo, only deploy and demoapp left in VM, visudo -c clean, self-check questions

### Lesson 11: Service management (systemd) (`linux/11-systemd/`)

**A. systemctl and existing units**

- [ ] 1. Read a unit
- [ ] 2. start vs enable
- [ ] 3. mask
- [ ] 4. Dependencies and targets

**B. Your own service**

- [ ] 5. First unit
- [ ] 6. Break ExecStart
- [ ] 7. Forgot daemon-reload
- [ ] 8. Environment file
- [ ] 9. Logs
- [ ] 10. Graceful stop

**C. Restart and dependencies**

- [ ] 11. Restart policies
- [ ] 12. Crash loop
- [ ] 13. After vs Requires
- [ ] 14. Resource limit

**D. Overrides and timers**

- [ ] 15. Drop-in override
- [ ] 16. Timer
- [ ] 17. Same job in cron

**E. Capstone**

- [ ] 18. Hardened service
- [ ] 19. Runbook and cleanup
- [ ] Submission: make check clean, unit files saved without secrets, no failed or test units in VM, self-check questions

### Lesson 12: Package management (`linux/12-packages/`)

**A. apt and dpkg**

- [ ] 1. Inventory
- [ ] 2. Which package owns it
- [ ] 3. Stale lists
- [ ] 4. Install lifecycle
- [ ] 5. Dependencies
- [ ] 6. Slim Dockerfile
- [ ] 7. Interactive prompt

**B. Repositories and signatures**

- [ ] 8. Read the sources
- [ ] 9. Add a third-party repo
- [ ] 10. Break the signature
- [ ] 11. Why not apt-key
- [ ] 12. Hold and pin
- [ ] 13. Unattended upgrades

**C. dnf and rpm**

- [ ] 14. dnf basics
- [ ] 15. provides and repos
- [ ] 16. check-update exit code
- [ ] 17. Same task, two families

**D. Capstone**

- [ ] 18. snap on your machine
- [ ] 19. Package audit script
- [ ] 20. Cleanup
- [ ] Submission: make check clean, no third-party repos, keys, pins or holds left in VM, test images removed, self-check questions

### Lesson 13: Disks and filesystems (`linux/13-disks/`)

**A. Devices and inodes**

- [ ] 1. Map your disks
- [ ] 2. stat and inodes
- [ ] 3. Loop devices
- [ ] 4. Partition table

**B. Filesystems, mount, fstab**

- [ ] 5. mkfs and mount
- [ ] 6. Mount hides content
- [ ] 7. Target is busy
- [ ] 8. Inode exhaustion
- [ ] 9. fstab with UUID
- [ ] 10. Break fstab safely

**C. Swap**

- [ ] 11. Swapfile
- [ ] 12. Swap under pressure

**D. LVM**

- [ ] 13. PV, VG, LV
- [ ] 14. Extend online
- [ ] 15. Grow the pool
- [ ] 16. Snapshot
- [ ] 17. xfs cannot shrink

**E. Mini-project (lessons 8-13)**

- [ ] 18. Project: storage
- [ ] 19. Project: operations
- [ ] 20. Project: incident drill
- [ ] 21. Project: reboot and runbook
- [ ] 22. Cleanup
- [ ] Submission: make check clean, project files saved, VM cleaned (fstab, VG, loops, swapfile) and reboots cleanly, workstation untouched, self-check questions
