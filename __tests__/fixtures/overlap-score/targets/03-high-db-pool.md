---
name: db-connection-pool-exhaustion
type: tacit
problem: Database connection pool exhaustion under concurrent load causes request timeouts
cause: Connection pool max size too small for request volume plus connection leaks cause exhaustion
solution: Increase pool max size tune idle timeout and release connections in finally blocks
prevention: Monitor connection pool metrics and load test pool capacity before production deploy
related_files:
  - src/db/pool.ts
  - src/db/index.ts
---

# DB Connection Pool Exhaustion

Resolution for pool saturation incidents.
