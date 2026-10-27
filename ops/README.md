# Local source-backed publication

GitHub Actions remains disabled. Commit and push the exact reviewed source to
this existing repository, then run `python3 -B ops/publish.py --repo "$PWD"
--commit <full-commit> --service qbit-monitor --apply` from the declared F-backed
operator workspace in Ubuntu WSL. No package install is required on the host.

The publisher exports committed application files only, builds fresh from the
pinned Alpine image, and publishes `jtmb92/qbit-monitor:git-<full-commit>` through
the existing Docker Hub account. An existing immutable tag is never overwritten.
The image carries repository/revision labels; remote bytes and labels are checked
after publication. The Windows helper reads the existing Credential Manager entry
into the Docker client's memory only; no credentials are written into source,
config files, command arguments or logs. Never run the helper into a terminal.

The isolated builder has 3 GiB RAM, zero swap, 1.5 CPUs, 512 processes and a 2 GiB
allocated build budget. Its state, context, client settings and scratch use the
existing F-backed task root; C: and both F: filesystems must preserve 15 GiB free.
Only the cached pinned builder image is used. Existing containers and Strata are
untouched. The publisher stops its own builder on all exits and retains complete
source/digest/resource receipts. Reconcile and remove its inactive reproducible
scratch with the project's exact ownership/process/mount checks before completion.
Do not prune shared images or volumes. Source repositories and failure evidence
are protected; receipts are not deployment acceptance.

Scan the resulting digest, review its values-only private charts change, and use
local validation -> validated -> Flux. Prove real queue cycles, native login,
forwarded-port updates, existing notification queue, alerts configuration and an
independent restart before claiming production acceptance. Do not send an extra
Discord test message without the applicable user authorization.

The clean-source check applies Windows checkout line-ending rules per command;
no global Git setting or working file is normalized. Build inputs come from raw
immutable Git blobs, independent of the working-tree CRLF representation.
