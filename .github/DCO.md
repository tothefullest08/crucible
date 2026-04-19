# Developer Certificate of Origin

Contributions to **harness** are accepted under the Developer Certificate of Origin (DCO) v1.1. The full, unmodified text of the DCO follows. The canonical copy lives at <https://developercertificate.org>.

---

```
Developer Certificate of Origin
Version 1.1

Copyright (C) 2004, 2006 The Linux Foundation and its contributors.

Everyone is permitted to copy and distribute verbatim copies of this
license document, but changing it is not allowed.


Developer's Certificate of Origin 1.1

By making a contribution to this project, I certify that:

(a) The contribution was created in whole or in part by me and I
    have the right to submit it under the open source license
    indicated in the file; or

(b) The contribution is based upon previous work that, to the best
    of my knowledge, is covered under an appropriate open source
    license and I have the right under that license to submit that
    work with modifications, whether created in whole or in part
    by me, under the same open source license (unless I am
    permitted to submit under a different license), as indicated
    in the file; or

(c) The contribution was provided directly to me by some other
    person who certified (a), (b) or (c) and I have not modified
    it.

(d) I understand and agree that this project and the contribution
    are public and that a record of the contribution (including all
    personal information I submit with it, including my sign-off) is
    maintained indefinitely and may be redistributed consistent with
    this project or the open source license(s) involved.
```

---

## How to sign off

Add a `Signed-off-by:` trailer to every commit. The trailer must match the author name and email on the commit.

### Automatic (recommended)

```bash
git commit -s -m "feat: add new skill"
```

The `-s` flag appends the sign-off automatically.

### Manual

If you prefer to write it yourself, append this line to the commit message body:

```
Signed-off-by: Your Name <you@example.com>
```

### Amending existing commits

For the most recent commit:

```bash
git commit --amend -s --no-edit
```

For a whole series:

```bash
git rebase --signoff <base-branch>
```

---

## Verification policy

- Every commit in a pull request must carry a valid `Signed-off-by:` trailer.
- PRs missing sign-offs will be asked to rebase before merge.
- A GitHub Actions DCO bot (placeholder — to be enabled in a future release) will flag missing sign-offs automatically once wired up.

If you have questions about what the DCO means for a specific contribution, open an issue before sending the PR.
