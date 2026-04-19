---
name: python-gil-concurrency
type: tacit
problem: Python global interpreter lock contention slows CPU-bound threaded workloads significantly
cause: GIL serializes bytecode execution across threads preventing parallelism on multicore CPUs
solution: Use multiprocessing module or native extensions that release GIL around heavy computation
prevention: Profile bytecode workload before choosing threading model benchmark single vs multi process
related_files:
  - workers/cpu_pool.py
  - workers/parallel_runner.py
---

# Python GIL Concurrency

Documented pattern about CPU-bound parallelism.
