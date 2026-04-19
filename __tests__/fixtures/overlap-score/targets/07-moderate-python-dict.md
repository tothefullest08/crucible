---
name: python-version-compat
type: tacit
problem: Python dict merge operator introduced in Python 3.9 breaks compatibility with 3.8 CI environments
cause: Some different story about GIL release timing in C extensions during memory profiling sessions
solution: Replace pipe operator with dict unpack syntax or update Python version in CI config file
prevention: Nothing to do with Python version enforcement but instead about refactoring helper modules
related_files:
  - src/extensions/gil_profile.c
  - tests/test_profiler.py
---

# Python Version Compat

Documented pattern about dict merge across versions.
