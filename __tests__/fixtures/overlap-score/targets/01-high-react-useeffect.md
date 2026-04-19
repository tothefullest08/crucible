---
name: react-useeffect-deps
type: correction
problem: React useEffect hook dependency array missing values causes stale closure bug
cause: useEffect dependency array missing referenced values leads to stale closure capture
solution: Add all referenced values to useEffect dependency array including props state and callbacks
prevention: Enable eslint-plugin-react-hooks exhaustive-deps rule to detect missing dependencies
related_files:
  - src/hooks/useFetch.ts
  - src/components/UserProfile.tsx
---

# React useEffect Dependency Array

Existing documented correction about stale closure.
