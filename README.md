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

## 📝 Conventional Commits & Versioning

This workflow uses the **Conventional Commits** standard to determine the next version number.

| Commit Type | Description | Release Type | Example |
| :--- | :--- | :--- | :--- |
| **`feat`** | A new feature | **Minor** (`1.1.0` -> `1.2.0`) | `feat: add new search api` |
| **`fix`** | A bug fix | **Patch** (`1.1.0` -> `1.1.1`) | `fix: null pointer exception` |
| **`perf`** | Performance improvement | **Patch** | `perf: optimize query` |
| **`chore`** | Maintenance/Cleanup | **Patch** | `chore: update dependencies` |
| **`refactor`** | Code restructuring | **Patch** | `refactor: extract method` |
| **`revert`** | Reverting a commit | **Patch** | `revert: undo recent change` |
| **`style`** | Formatting (white-space, etc) | **No Release** | `style: fix indentation` |
| **`docs`** | Documentation changes | **No Release** | `docs: update readme` |
| **`test`** | Adding tests | **No Release** | `test: add unit tests` |
| **`ci`** | CI config changes | **No Release** | `ci: update workflow` |
| **`build`** | Build system changes | **No Release** | `build: update npm scripts` |

### 💥 Breaking Changes (Major)

To trigger a **Major** release (e.g., `1.0.0` -> `2.0.0`), use a `!` after the type or include `BREAKING CHANGE:` in the footer.

*   `feat!: remove deprecated api`
*   Footer key: `BREAKING CHANGE: API endpoint /v1/auth is removed.`

---

## 🔗 Data Flow & Linkage

How do these files interact?

```mermaid
sequenceDiagram
    participant User
    participant Main as main.yml<br>(Workflow)
    participant Action as action.yml<br>(Composite Action)
    participant Script as semantic-version.sh<br>(Script)
    participant SR as semantic-release<br>(Tool)

    User->>Main: Push / PR (Trigger)
    Main->>Action: Call uses: ./
    Note right of Main: Passes: github-token, dry-run

    Action->>Script: Run script
    Note right of Action: Args: -d (if dry-run), -c

    Script->>Script: Check Flags & Branch

    alt Dry Run
        Script->>Script: git checkout -B branch
        Script->>SR: npx semantic-release --dry-run
    else Release
        Script->>SR: npx semantic-release
    end

    SR->>Script: Return new version
    Script->>Action: Set GITHUB_OUTPUT
    Action->>Main: Map to steps output
    Main->>Main: Use version (Tag, Deploy, etc.)
```

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

There are two methods to consume this release workflow.

### Option 1: Direct Action Usage (Recommended)
Use this if you need to run the release logic as a step within your own job (e.g., for tighter integration).

```mermaid
sequenceDiagram
    participant OtherRepo as Other Repo<br>(CI Job)
    participant Action as action.yml<br>(Composite Action)

    Note right of OtherRepo: Step: orbitcluster/oc-cicd-release-workflow@v1
    OtherRepo->>Action: Call uses: ...@v1
    Note right of OtherRepo: with: github-token, dry-run

    Action->>OtherRepo: Return outputs to steps context

    OtherRepo->>OtherRepo: Use ${{ steps.release.outputs.release-version }}
```

```yaml
steps:
  - id: release
    uses: orbitcluster/oc-cicd-release-workflow@v1
    with:
      github-token: ${{ github.token }}
```

### Option 2: Reusable Workflow
This method isolates the release logic in a separate job.

```mermaid
sequenceDiagram
    participant OtherRepo as Other Repo<br>(CI Workflow)
    participant Version as version.yml<br>(Reusable Workflow)
    participant Action as action.yml<br>(Core Action)

    OtherRepo->>Version: Call uses: .../version.yml@v1
    Note right of OtherRepo: permissions: write-all

    Version->>Action: Call uses: ./
    Action->>Version: Return outputs (release-version, etc)
    Version->>OtherRepo: Forward outputs

    OtherRepo->>OtherRepo: Use ${{ needs.release.outputs.release-version }}
```

```yaml
jobs:
  release:
    uses: orbitcluster/oc-cicd-release-workflow/.github/workflows/version.yml@v1
    secrets: inherit
```
