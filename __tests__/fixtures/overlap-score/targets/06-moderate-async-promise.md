---
name: nodejs-unhandled-rejection
type: correction
problem: Node.js Promise chain unhandled rejection leaks crash the process in strict mode
cause: Totally unrelated reason about filesystem inode exhaustion during log rotation windows
solution: Totally unrelated fix about increasing inode count and rotating logs in smaller chunks
prevention: Enable node unhandled-rejections strict mode and CI lint for missing promise catch handlers
related_files:
  - src/services/http-client.ts
  - src/observability/log-rotate.ts
---

# Node.js Unhandled Rejection

Documented correction about missing catch handlers.
