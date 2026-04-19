---
name: bash-trap-cleanup
type: tacit
problem: Bash script trap cleanup handler does not fire when script receives SIGKILL signal directly
cause: SIGKILL cannot be trapped by design so cleanup code in EXIT trap never executes on kill -9 event
solution: Use separate sidecar process or systemd unit with cleanup in PostStop directive for kill-9 safety
prevention: Avoid reliance on bash trap for critical cleanup write checkpoint files between steps instead
related_files:
  - scripts/deploy.sh
  - scripts/rollback.sh
---

# Bash Trap Cleanup Limits

Documented pattern about signal handling boundaries in shell scripts.
