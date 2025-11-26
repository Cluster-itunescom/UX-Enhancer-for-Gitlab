# Quick demo: using a remote raw URL to share CI templates

This repository includes an example showing how to use GitLab's `include` to pull a CI template stored in a remote project as a raw URL.

Why this is useful
- Fast to set up for testing or demos
- No need to create a group template or manage permissions

Security note
- Using a raw remote URL (especially a public raw URL) is risky: any change in the remote file will affect your pipeline. For production use prefer a group repository + project include (or pinned refs/tags).

Files added in this repo for demonstration
- `/.gitlab-ci.yml` — example project CI that `include`s the remote `nodejs-defaults.yml`.
- `/templates/nodejs-defaults.yml` — the template file you can host in a remote repo and reference as raw.
- `/scripts/publish_template_to_gitlab.sh` — helper script to publish templates into a GitLab repo via API.

Example include (in this repo's `.gitlab-ci.yml`):

```
include:
  - remote: 'https://gitlab.com/your-group/ci-templates/-/raw/main/templates/nodejs-defaults.yml'
```

How to use
1. Put `templates/nodejs-defaults.yml` in a (remote) GitLab repo under `your-group/ci-templates` on branch `main`.
2. Update `.gitlab-ci.yml` `remote` URL to point to the raw file.
3. Commit to your project: pipelines will fetch the remote template and run jobs as defined.

Publishing the template to GitLab automatically
----------------------------------------------

This repository includes a helper script `scripts/publish_template_to_gitlab.sh` to create or update the template file in a GitLab project using the GitLab API. Use this when you want to publish the `templates/` files from this repository to a GitLab repo (e.g. `your-group/ci-templates`) so they can be included remotely.

Prerequisites
- A Personal Access Token (PAT) with `api` or `write_repository` scope.

Quick example

```bash
export GITLAB_TOKEN="<your-token>"
# optional: export GITLAB_HOST="gitlab.com"  # default
./scripts/publish_template_to_gitlab.sh --project "your-group/ci-templates" --branch main \
  --src ./templates/nodejs-defaults.yml --dst templates/nodejs-defaults.yml
```

Notes about PAT creation
- On gitlab.com, go to User Settings → Access Tokens and create a token with the minimum scope required. For publishing template files, `api` or `write_repository` is needed. Avoid using tokens with elevated scopes longer than necessary.

Testing/verification steps
--------------------------
1. Publish the template to your template project (see example above).
2. Make the template project accessible to the target project (public, or same group, or ensure token access). If using raw includes, the raw URL must be reachable without additional auth unless you configure protected access via a token.
3. In a test project, add or update `.gitlab-ci.yml` to include the raw URL (or `project` include). Example:

```yaml
include:
  - remote: 'https://gitlab.com/your-group/ci-templates/-/raw/main/templates/nodejs-defaults.yml'

stages:
  - lint
  - test
  - build
```

4. Push the `.gitlab-ci.yml` change in the test project and check the pipeline. The jobs defined in the remote template should appear and run.

Alternative (safer) — use `project:` include
------------------------------------------------
If the template repo lives on the same GitLab instance, prefer `project:` include which uses GitLab's internal permissions instead of a raw URL.

Example (`project` include):

```yaml
include:
  - project: 'your-group/ci-templates'
    ref: 'main'
    file: '/templates/nodejs-defaults.yml'

stages:
  - lint
  - test
  - build
```

Notes:
- `project:` include is resolved by GitLab using internal auth; the target project needs read access to the template project (same group or role configured). This avoids exposing a raw file publically.
- If needing a pinned version use `ref: 'v1.0.0'` or a tag/sha instead of `main` to limit changes.

Verification checklist
- Publish the template in the template project (via the script or Git push).
- Choose `remote` (raw) or `project` include in your test project.
- Push a `.gitlab-ci.yml` to your test project.
- Open the pipeline in GitLab and confirm the included jobs show up and run as expected.


Security reminder
-----------------
- If your template contains secrets or relies on protected variables, manage them in the **target project's** CI/CD variables, not inside the template file. Using `project:` includes (within the same GitLab instance) is safer than public raw URLs for production.
