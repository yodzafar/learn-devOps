# Computer networking — progress

Legend: `[ ]` not started, `[~]` written, not submitted for review, `[!]` reviewed, needs rework, `[x]` reviewed and accepted (marked `✓`).
Update: you `[ ]` → `[~]`; Claude sets `[x] ... ✓` or `[!] reason` after review.

## Written lessons (task level)

### Lesson 1: Network types (`network/01-network-types/`)

**A. Interfaces (workstation)**

- [ ] 1. Interface inventory
- [ ] 2. Reading flags
- [ ] 3. MAC anatomy
- [ ] 4. Interface statistics
- [ ] 5. sysfs

**B. Neighbours and gateway (workstation)**

- [ ] 6. Neighbour table
- [ ] 7. Gateway MAC
- [ ] 8. Failed neighbour
- [ ] 9. Home network map

**C. Bridge and veth (Docker)**

- [ ] 10. Two hosts one LAN
- [ ] 11. Veth pairs
- [ ] 12. Bridge FDB
- [ ] 13. Network isolation

**D. ARP and frames (Docker)**

- [ ] 14. Watch ARP
- [ ] 15. ARP only once
- [ ] 16. Link down
- [ ] 17. MTU mismatch
- [ ] 18. Duplicate IP

**E. Integration**

- [ ] 19. Troubleshooting checklist
- [ ] 20. Cleanup
- [ ] Submission: all 20 answers in README, `make check` clean, lab containers and networks removed, personal addresses masked

### Lesson 2: OSI model (`network/02-osi-model/`)

**A. Model**

- [ ] 1. Layer table
- [ ] 2. Classify protocols
- [ ] 3. Classify failures
- [ ] 4. Header math

**B. tcpdump**

- [ ] 5. First capture
- [ ] 6. The -n flag
- [ ] 7. Three-way handshake
- [ ] 8. Read the payload
- [ ] 9. DNS on the wire
- [ ] 10. Refused vs timeout
- [ ] 11. Filters
- [ ] 12. Write and read pcap

**C. Across the layers**

- [ ] 13. Wireshark layers
- [ ] 14. TTL on the path
- [ ] 15. Path MTU
- [ ] 16. curl as a layer probe
- [ ] 17. Break each layer

**D. Integration**

- [ ] 18. Request journey
- [ ] 19. Runbook
- [ ] Submission: all 19 answers in README, `pcap/` gitignored, `make check` clean, netshoot container stopped

### Lesson 3: IP addressing (`network/03-ip-addressing/`)

**A. Manual calculation**

- [ ] 1. Binary conversion
- [ ] 2. Subnet facts
- [ ] 3. Same subnet or not
- [ ] 4. Private or public
- [ ] 5. Split a network
- [ ] 6. Summarize

**B. Your own network**

- [ ] 7. My addresses
- [ ] 8. DHCP lease
- [ ] 9. Docker subnets
- [ ] 10. Listen address

**C. IPv6**

- [ ] 11. IPv6 notation
- [ ] 12. IPv6 on my host

**D. Inside the VM**

- [ ] 13. Dummy interface
- [ ] 14. Missing prefix
- [ ] 15. Secondary address
- [ ] 16. Watch DORA
- [ ] 17. Lease details
- [ ] 18. ipcalc check

**E. Integration**

- [ ] 19. Address plan
- [ ] 20. Validate the plan
- [ ] Submission: all 20 answers with manual calculation steps, `plan.md` and `check_plan.py` present and working, `make check` clean, `dummy0` and Docker `tiny` network removed

### Lesson 4: Protocols (`network/04-protocols/`)

**A. TCP and UDP**

- [ ] 1. Listening sockets
- [ ] 2. Handshake by hand
- [ ] 3. TCP states
- [ ] 4. Refused, timeout, reset
- [ ] 5. Address in use
- [ ] 6. UDP is different

**B. DNS**

- [ ] 7. Record types
- [ ] 8. Trace the hierarchy
- [ ] 9. Caching and TTL
- [ ] 10. Resolver config
- [ ] 11. hosts vs DNS
- [ ] 12. Search and ndots

**C. SSH**

- [ ] 13. Key-based login
- [ ] 14. Debug a rejected key
- [ ] 15. Host key changed
- [ ] 16. ProxyJump
- [ ] 17. Local port forward
- [ ] 18. Harden sshd

**D. SMTP, HTTP, TLS**

- [ ] 19. SMTP by hand
- [ ] 20. Mail DNS audit
- [ ] 21. TLS inspection

**E. Integration**

- [ ] 22. Endpoint probe script
- [ ] Submission: all 22 answers in README, `ssh_config.example`, `sshd_hardening.conf`, `mail.txt`, `probe.sh` present, `make check` clean with no private keys, Mailpit removed, VM changes reverted, no leftover tunnels

### Lesson 5: Routing and gateway (`network/05-routing/`)

**A. Reading the routing table (workstation)**

- [ ] 1. Read my table
- [ ] 2. Route lookup
- [ ] 3. Longest prefix by hand
- [ ] 4. Tables and rules
- [ ] 5. Trace a path
- [ ] 6. AS path

**B. Namespaces and veth (VM)**

- [ ] 7. Two namespaces
- [ ] 8. Forgotten steps
- [ ] 9. Bridge as a switch

**C. Linux router (VM)**

- [ ] 10. Build the router
- [ ] 11. Default gateway
- [ ] 12. Return path
- [ ] 13. Forwarding off
- [ ] 14. Watch the hop
- [ ] 15. Traceroute in the lab
- [ ] 16. Service through the router

**D. Static routes and diagnosis (VM)**

- [ ] 17. Third network
- [ ] 18. Wrong gateway
- [ ] 19. Blackhole and prefix order
- [ ] 20. Find the fault

**E. Integration**

- [ ] 21. Lab script
- [ ] Submission: all 21 answers in README, `netlab.sh` and the fault-injection script present, `make check` clean, no namespaces, bridges or veths left in the VM, workstation routes and sysctls unchanged

### Lesson 6: Firewall, NAT, VPN (`network/06-firewall-nat-vpn/`)

**A. Firewall basics (VM)**

- [ ] 1. Baseline
- [ ] 2. First ruleset
- [ ] 3. Drop vs reject
- [ ] 4. Why established matters
- [ ] 5. Rule order and counters
- [ ] 6. Source restriction and logging
- [ ] 7. IPv6 gap
- [ ] 8. ufw

**B. NAT (VM)**

- [ ] 9. Namespace behind NAT
- [ ] 10. Masquerade
- [ ] 11. Port forwarding
- [ ] 12. DNAT from the host itself
- [ ] 13. Missing pieces

**C. Docker (workstation, read-only and containers)**

- [ ] 14. Docker NAT rules
- [ ] 15. Published port exposure

**D. WireGuard (VM)**

- [ ] 16. Tunnel between two hosts
- [ ] 17. What is on the wire
- [ ] 18. Break the tunnel
- [ ] 19. Firewall on the tunnel
- [ ] 20. Site-to-site

**E. Module mini-project**

- [ ] 21. Secure gateway
- [ ] 22. Module retrospective
- [ ] Submission: all 22 answers in README, `host.nft`, `nat.nft`, `gateway.nft`, `gateway.sh`, `verify.sh`, `wg0.conf.example` present, `make check` clean with no WireGuard private keys, `verify.sh` passes after `gateway.sh up` and everything is empty after `down`, Docker `web` container removed, VMs deleted and purged
