# Observability — progress

Legend: `[ ]` not started, `[~]` written, not submitted for review, `[!]` reviewed, needs rework, `[x]` reviewed and accepted (marked `✓`).
Update: you `[ ]` → `[~]`; Claude sets `[x] ... ✓` or `[!] reason` after review.

## Written lessons (task level)

### Lesson 1: Metrics with Prometheus (`observability/01-prometheus/`)

**A. First scrape**

- [ ] 1. Prometheus alone
- [ ] 2. Read the exposition format
- [ ] 3. Break the target
- [ ] 4. Reload without restart

**B. Exporters**

- [ ] 5. node_exporter
- [ ] 6. Host network trade-off
- [ ] 7. cAdvisor
- [ ] 8. Drop with relabeling

**C. Application metrics**

- [ ] 9. Sample app
- [ ] 10. Instrument with a client library
- [ ] 11. Load generator
- [ ] 12. Cardinality bomb

**D. PromQL**

- [ ] 13. Rate window
- [ ] 14. RED queries
- [ ] 15. Wrong aggregation
- [ ] 16. Bucket resolution
- [ ] 17. USE queries
- [ ] 18. Vector matching

**E. Rules and storage**

- [ ] 19. Recording rules
- [ ] 20. Rule unit test
- [ ] 21. Retention and storage
- [ ] 22. Mini-project: metrics baseline
- [ ] Submission: compose config, promtool check config/rules and make check clean; stack stopped; self-check questions

### Lesson 2: Visualization with Grafana (`observability/02-grafana/`)

**A. First dashboard**

- [ ] 1. Grafana service
- [ ] 2. Explore
- [ ] 3. Rate interval
- [ ] 4. RED dashboard
- [ ] 5. Heatmap

**B. Variables**

- [ ] 6. Query variable
- [ ] 7. Chained variables
- [ ] 8. Repeat

**C. USE and community dashboards**

- [ ] 9. Import Node Exporter Full
- [ ] 10. USE dashboard
- [ ] 11. Container panel

**D. Provisioning**

- [ ] 12. Datasource as code
- [ ] 13. Dashboards as code
- [ ] 14. Break provisioning
- [ ] 15. UI edits vs file

**E. Access control and annotations**

- [ ] 16. Users and folders
- [ ] 17. Query annotations
- [ ] 18. Deploy annotation via API
- [ ] 19. Mini-project: Grafana from zero
- [ ] Submission: everything restored from provisioning after down -v; make check clean, no secrets; dashboard JSON committed; stack stopped; self-check questions

### Lesson 3: Alerting (`observability/03-alerting/`)

**A. Alerting rules**

- [ ] 1. First alert rule
- [ ] 2. Tune for
- [ ] 3. Symptom alerts
- [ ] 4. Absent data
- [ ] 5. Label trap
- [ ] 6. Rule unit test

**B. Alertmanager**

- [ ] 7. Alertmanager and webhook
- [ ] 8. Grouping timers
- [ ] 9. Routing tree
- [ ] 10. Inhibition
- [ ] 11. Silences
- [ ] 12. Break the config

**C. Receivers**

- [ ] 13. Telegram receiver
- [ ] 14. Email receiver
- [ ] 15. Watchdog

**D. SLO and process**

- [ ] 16. Burn rate alert
- [ ] 17. Budget math
- [ ] 18. Runbooks
- [ ] 19. Alert review

**E. Grafana Alerting**

- [ ] 20. Grafana-managed rule
- [ ] 21. Provision alerting
- [ ] 22. Mini-project: alerting as code
- [ ] Submission: promtool check/test rules and amtool check-config clean; make check clean, no tokens; test notifications documented; no active silences, stack stopped; self-check questions

### Lesson 4: Logging with Loki and Elasticsearch (`observability/04-logging/`)

**A. Structured logging**

- [ ] 1. Structured logs in the app
- [ ] 2. Log levels
- [ ] 3. Secrets in logs

**B. Loki and Alloy**

- [ ] 4. Loki service
- [ ] 5. Alloy pipeline
- [ ] 6. Relabel to useful labels
- [ ] 7. Level as a label
- [ ] 8. Label cardinality bomb
- [ ] 9. Drop noise
- [ ] 10. Break the pipeline

**C. LogQL**

- [ ] 11. Filters and parsers
- [ ] 12. Filter order
- [ ] 13. Pattern parser
- [ ] 14. Metric queries
- [ ] 15. Logs on the dashboard
- [ ] 16. Log-based alert
- [ ] 17. Retention

**D. Elasticsearch and Kibana**

- [ ] 18. Single-node Elasticsearch
- [ ] 19. Index and mapping
- [ ] 20. Ship and explore
- [ ] 21. Mini-project: logs in the stack
- [ ] Submission: compose config clean, Alloy components healthy; make check clean, no secrets in log samples; logs-es profile and its volumes removed; stack stopped; self-check questions

### Lesson 5: Distributed tracing (`observability/05-tracing/`)

**A. Two services and propagation**

- [ ] 1. Second service
- [ ] 2. Trace by hand
- [ ] 3. Console exporter
- [ ] 4. Read traceparent
- [ ] 5. Break propagation

**B. Jaeger**

- [ ] 6. Jaeger all-in-one
- [ ] 7. Find the slow and the failed
- [ ] 8. Manual span
- [ ] 9. Restart loses traces

**C. Tempo and TraceQL**

- [ ] 10. Tempo service
- [ ] 11. Receiver on localhost
- [ ] 12. TraceQL queries
- [ ] 13. Head sampling
- [ ] 14. Service graph and span metrics

**D. Correlation**

- [ ] 15. Trace ID in logs
- [ ] 16. Logs to trace
- [ ] 17. Trace to logs
- [ ] 18. Exemplars
- [ ] 19. Mini-project: find the slow hop
- [ ] Submission: checkout trace spans both services in Tempo; correlations provisioned as code; make check clean; jaeger profile off, stack stopped; self-check questions

### Lesson 6: Continuous profiling (`observability/06-profiling/`)

**A. Pyroscope and the first profile**

- [ ] 1. Pyroscope service
- [ ] 2. Profile the app
- [ ] 3. Idle vs loaded
- [ ] 4. Self vs total
- [ ] 5. Break the push

**B. CPU hot path**

- [ ] 6. Plant a hot path
- [ ] 7. Find it in the flame graph
- [ ] 8. Blast radius
- [ ] 9. Trace vs profile
- [ ] 10. Fix and diff
- [ ] 11. Labels per route

**C. Memory**

- [ ] 12. Plant a leak
- [ ] 13. Find the leak
- [ ] 14. OOM and limits
- [ ] 15. Allocation churn

**D. Cost and wrap-up**

- [ ] 16. Measure overhead
- [ ] 17. Pull vs push
- [ ] 18. Mini-project: profile-driven fix
- [ ] Submission: hot path and leak fixed with before/after diffs; Pyroscope data source and dashboard provisioned; make check clean; temporary limits reverted, stack stopped; self-check questions

### Lesson 7: OpenTelemetry and module mini-project (`observability/07-opentelemetry/`)

**A. Collector basics**

- [ ] 1. Collector with debug exporter
- [ ] 2. Declared but not wired
- [ ] 3. Traces through the Collector
- [ ] 4. Shell-less image
- [ ] 5. Processors

**B. Metrics and logs via OTel**

- [ ] 6. OTLP metrics to Prometheus
- [ ] 7. Names changed
- [ ] 8. Resource attributes as labels
- [ ] 9. No up metric
- [ ] 10. OTLP logs to Loki
- [ ] 11. Stdout or OTLP logs
- [ ] 12. Span metrics connector

**C. Sampling and resilience**

- [ ] 13. Tail sampling
- [ ] 14. Backend down
- [ ] 15. Watch the Collector

**D. Mini-project**

- [ ] 16. Stack as code
- [ ] 17. Dashboards and alerts
- [ ] 18. Fault injection
- [ ] 19. Simulated incident
- [ ] 20. Postmortem
- [ ] 21. Close the gap
- [ ] Submission: compose config, Collector validate, promtool and amtool checks clean; make check clean, no secrets; stack README and postmortem written; whole module torn down with volumes; self-check questions
