---
name: react-setstate-queue
type: tacit
problem: React setState queue behavior requires functional updates for consecutive state changes
cause: Multiple setState calls with same variable read stale closure not updated queued value
solution: Use functional setState setter callback or useEffect to react to state changes instead of reading directly
prevention: Treat state as immutable snapshot during render and never read state synchronously after setState
related_files:
  - src/components/Counter.tsx
  - src/hooks/useCounter.ts
---

# React setState Queue Behavior

Documented pattern for setState race conditions.
