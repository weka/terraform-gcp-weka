# Guidelines

## Scope of a change

Fix what was asked, and only that. Unrelated problems you notice along the way
stay untouched — even obvious ones, even one-line ones. Mention them and offer
to open a ticket instead.

A change is in scope only if the requested fix does not work without it.

## After any code change

Run `/simplify` once the change is complete and working. Not after each edit —
after the change as a whole.

Then make sure `pre-commit run -a` passes. `terraform_fmt` and `terraform_tflint`
are the only checks that run on a PR (`.github/workflows/tf-style-checks.yaml`);
the `terraform apply` job in `workflow.yaml` is gated behind `if: false`, so
nothing deploys the change to prove it works. Anything beyond fmt and lint is on
you to verify.

## Commit messages

One line. No body, no bullet list, no trailing explanation — if the change needs
more words than a single subject line, those words belong in the PR description,
the code, or a comment, not in the commit.

Existing history is the bar: `fix: add pre-conditions when subnets name are
provided`. Keep the conventional prefix (`feat:`, `fix:`, `chore:`, `refactor:`)
— release-drafter builds the release notes from it.

`terraform-docs: automated action` commits are CI's. Never write one by hand.

## Comments

Keep them minimal. Write a comment only when the code cannot be made obvious on
its own: a non-obvious GCP or provider constraint, a deliberate omission, a
workaround whose reason isn't visible in the diff. Do not comment what the code
already says.

The two bars in this repo both carry information the reader cannot recover from
the code:

- `versions.tf` — why `google-beta` is required at all (`max_distance` on the
  compact placement policy is a GCP Preview field the GA provider doesn't expose).
- `cloud_functions.tf` — why `REPORT_URL` is commented out rather than missing
  (a function's config may not refer to its own URI).

The test is what happens when the code is wrong. Comment what fails *silently*,
at apply time, or in only one environment — those cost a cycle to rediscover.
Say nothing about syntax, types, or provider API shape: `terraform validate` and
the provider schema reject those instantly and loudly, so the comment buys
nothing even when it is accurate.

## The function environment map and the Go code must agree

`local.cloud_internal_function_environment` and `local.status_function_environment`
in `cloud_functions.tf` are the only channel from Terraform into the function
code. The Go side reads them with `os.Getenv` and discards the parse error
(`hostsNum, _ := strconv.Atoi(os.Getenv("HOSTS_NUM"))`), so a key that Terraform
never sets arrives as `""`, `0`, or `false` with no error anywhere — not at plan,
not at apply, not in the function logs.

Add the key and its reader in the same commit. Removing or renaming a key means
removing or renaming the reader too.

## Cloud Functions and Cloud Run are two runtimes for the same three services

`cloud_run_image_prefix` selects between them via `local.is_using_cloudfunctions`.
The environment maps are shared through the locals above, so those propagate on
their own. Everything else is duplicated: the resource, the invoker IAM, and the
`*_function_uri` local.

Adding, removing, or renaming a service touches both `cloud_functions.tf` and
`cloudrun.tf`.

## A new root variable is not done until it is plumbed

Three places, one commit: `variables.tf`, the `module` block in the root `.tf`
that consumes it (e.g. `data_services.tf`), and `modules/<name>/variables.tf`.
A variable that exists only at the root is accepted silently and ignored.

The README input table is generated — terraform-docs injects it between
`BEGIN_TF_DOCS` and `END_TF_DOCS` and pushes the result back to the PR branch.
The `description` in `variables.tf` is the source; never hand-edit inside the
markers. The prose above them is hand-written and yours to keep current.

## Go changes reach a cluster only through a zip

`archive_file.function_zip` zips `cloud-functions/` and Cloud Functions builds it
server-side, so a compile error surfaces as a failed deploy several minutes into
an apply. Run `go build ./...` and `go test ./...` in `cloud-functions/` first.

`go-cloud-lib` is pinned to a pseudo-version. Bumping it is its own commit
(`fix: update go-cloud-lib ...`), not a drive-by edit inside another change.

`cloud-functions/CLAUDE.md` covers the layout of that tree.
