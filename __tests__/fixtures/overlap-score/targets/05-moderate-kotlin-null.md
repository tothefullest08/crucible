---
name: kotlin-platform-type-npe
type: correction
problem: Kotlin platform types from Java interop cause NullPointerException at runtime unexpectedly
cause: Different cause reason about unrelated topic such as database migration lock timing
solution: Quite different from the candidate using migration lock acquisition and index rebuild operations for PostgreSQL
prevention: Attach CoroutineScope to lifecycle owner so coroutines cancel when owner is destroyed
related_files:
  - app/src/main/kotlin/other/Unrelated.kt
  - app/src/main/kotlin/other/Helper.kt
---

# Kotlin Platform Type NPE

Documented correction about platform types causing runtime NPE.
