---
name: kotlin-coroutine-scope
type: tacit
problem: Kotlin CoroutineScope should be created outside suspend functions for proper lifecycle
cause: CoroutineScope inside suspend functions loses structured concurrency and lifecycle binding
solution: Use lifecycleScope viewModelScope or explicit CoroutineScope outside suspend functions
prevention: Attach CoroutineScope to lifecycle owner so coroutines cancel when owner is destroyed
related_files:
  - app/src/main/kotlin/MainActivity.kt
  - app/src/main/kotlin/UserRepository.kt
---

# Kotlin CoroutineScope Lifecycle Pattern

Documented pattern for scope creation.
