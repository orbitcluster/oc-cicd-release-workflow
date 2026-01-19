# Orbit Cluster CICD Release Workflow

This repository hosts a composite GitHub Action and reusable workflows to automate semantic versioning and releases using `semantic-release`.

## 🔄 Workflow Overview

The system is designed to automatically determine the next version number based on commit messages (Conventional Commits), generate changelogs, create GitHub Releases, and update Git tags. It supports both "Dry Run" mode (for PRs) and actual Release mode (for merges to `main`).

### 🧩 Components

#### 1. `action.yml` (The Core Action)
This is the heart of the repository. It is a **Composite Action** that defines the logic for running the release process.

*   **Responsibility**:
    *   Setup Node.js environment.
    *   Install `semantic-release` and plugins.
    *   Execute the `semantic-version.sh` orchestration script.
    *   Validate Pull Request titles to enforce Conventional Commits.
    *   Output the calculated version numbers.
*   **Inputs**:
    *   `github-token` (Required): Token to authenticate with GitHub.
    *   `dry-run` (Default: `false`): Logic to simulate release without publishing.
    *   `create-component-tags` (Default: `true`): Whether to create major/minor tags (e.g., `v1`, `v1.2`).
    *   `fail-on-no-release`: If `true`, the action fails if no new version triggers.
*   **Outputs**:
    *   `release-version`: The new version (e.g., `1.2.0`).
    *   `last-version`: The previous version.
    *   `is-new-release`: `true` if a release was created.

#### 2. `version.yml` (Reusable Workflow)
This is a **Reusable Workflow** (`on: workflow_call`) that makes the core action easily consumable by *other* repositories within the organization.

*   **Responsibility**: Wraps the core action in a job mechanism so it can be referenced via `uses: orbitcluster/oc-cicd-release-workflow/.github/workflows/version.yml@v1`.
*   **Inputs**: It accepts no input triggers but passes context data to the inner action.
*   **Outputs**: Re-exports all outputs from the core action (`release-version`, etc.) so the caller workflow can use them.
*   **Hardcoded Behavior**: It explicitly invokes the version `v1` of this action (`orbitcluster/oc-cicd-release-workflow@v1`).

#### 3. `.github/workflows/main.yml` (CI Pipeline)
This is the CI workflow for *this repository itself*.

*   **Responsibility**:
    *   **Linting**: Runs `pre-commit` hooks (yamllint, actionlint, etc.).
    *   **Self-Test**: Runs the local version of the action (`uses: ./`) to verify it works.
    *   **Consistency Check (`check-workflow-sync`)**:
        *   **Goal**: Ensure `version.yml` points to the correct Major version.
        *   **Logic**:
            1.  Gets the *next* release version from the `semantic-version` job (e.g., `2.0.0`).
            2.  Reads `.github/workflows/version.yml` to see which version tag it uses (e.g., `uses: ...@v1`).
            3.  **Validation**: If the new release is `v2.x.x` but `version.yml` is hardcoded to `@v1`, the job **fails**.
        *   **Reasoning**: This prevents a scenario where we release a Breaking Change (Major version bump) but users consuming the reusable workflow continue using the old Major version unknowingly. It forces the maintainer to explicitly update `version.yml` to `@v2` when a breaking change is released.
*   **Triggers**:
    *   `push` to `main`: Triggers a real release.
    *   `pull_request` to `main`: Triggers a dry-run release.

#### 4. `semantic-version.sh` (The Script)
A Bash script that orchestrates `semantic-release`.

*   **Responsibility**:
    *   Dynamic Configuration: Switches flags based on `dry-run` status.
    *   Branch Detection: Handles `detached HEAD` state during dry-runs by explicitly checking out the branch.
    *   Output Management: Writes results to `GITHUB_OUTPUT`.

---

## 🔗 Data Flow & Linkage

How do these files interact?

1.  **Trigger**: A developer pushes code or opens a PR.
    *   -> `main.yml` starts.

2.  **Execution (`main.yml` -> `action.yml`)**:
    *   `main.yml` calls the action using `uses: ./`.
    *   **Passes Inputs**:
        *   `dry-run`: Calculated dynamically (`${{ github.ref_name != 'main' }}`).
        *   `github-token`: `${{ github.token }}`.

3.  **Logic (`action.yml` -> `semantic-version.sh`)**:
    *   `action.yml` sets up the environment and calls `semantic-version.sh`.
    *   **Passes Flags**: `-d` if dry-run is true, `-c` if component tags are enabled.

4.  **Calculation (`semantic-version.sh` -> `semantic-release`)**:
    *   The script constructs the `semantic-release` command string.
    *   If **Dry Run**: It forces `git checkout` to the PR branch and runs with `--dry-run --no-ci`.
    *   `semantic-release` analyzes commits and configuration (`release.config.js`).

5.  **Output (`semantic-release` -> `action.yml` -> `main.yml`)**:
    *   Script captures the version from calculations.
    *   Script writes to `$GITHUB_OUTPUT` (`version=1.2.3`).
    *   `action.yml` maps these script outputs to Action Outputs.
    *   `main.yml` (or any caller of `version.yml`) receives `release-version` to tag Docker images, update manifests, etc.

## 📦 Usage for Other Repos

To use this workflow in another repository:

```yaml
jobs:
  release:
    uses: orbitcluster/oc-cicd-release-workflow/.github/workflows/version.yml@v1
    secrets: inherit
```
