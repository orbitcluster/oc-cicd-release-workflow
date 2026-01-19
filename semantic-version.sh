#!/bin/bash
set -eo pipefail

if [[ "$RUNNER_DEBUG" == "1" ]]; then
  set -x
fi

usage() {
  echo "Usage: $0 [-c] [-d]"
  echo "  -c  Configure components tagging (only effective on main branch)"
  echo "  -d  Enable dry-run mode"
  exit 1
}

SEMANTIC_RELEASE_VERSION="24"
DRY_RUN="false"
CONFIGURE_COMPONENTS="false"

while getopts "cd" opt; do
  case $opt in
    c)
      CONFIGURE_COMPONENTS="true"
      ;;
    d)
      DRY_RUN="true"
      ;;
    *)
      usage
      ;;
  esac
done

if [[ "$CONFIGURE_COMPONENTS" == "true" ]] && [[ "$GITHUB_REF_NAME" == "main" ]]; then
  export TAG_COMPONENTS="true"
fi

# Install dependencies
npm install --no-save semantic-release@$SEMANTIC_RELEASE_VERSION \
  @semantic-release/commit-analyzer \
  @semantic-release/release-notes-generator \
  @semantic-release/exec \
  semantic-release-major-tag \
  @semantic-release/github \
  conventional-changelog-conventionalcommits

CMD="npx semantic-release"
if [[ "$DRY_RUN" == "true" ]]; then
  # Dry-run Configuration
  unset GITHUB_ACTIONS
  if [[ "$GITHUB_EVENT_NAME" == "pull_request" ]]; then
    BRANCH="$GITHUB_HEAD_REF"
  else
    BRANCH="$GITHUB_REF_NAME"
  fi

  # actions/checkout leaves HEAD detached.
  # When unsetting GITHUB_ACTIONS, semantic-release relies on git to find the branch.
  # We must attach HEAD to the branch name.
  if [[ -n "$BRANCH" ]]; then
    echo "Ensuring we are on branch: $BRANCH"
    git checkout -B "$BRANCH"
  fi

  CMD="$CMD --dry-run --no-ci --branches $BRANCH"
  CMD="$CMD --extends $GITHUB_ACTION_PATH/release.config.js"
  CMD="$CMD --repository-url https://github.com/$GITHUB_REPOSITORY"
else
  # Release Mode Configuration
  unset GITHUB_EVENT_NAME
  CMD="$CMD --extends $GITHUB_ACTION_PATH/release.config.js"
  CMD="$CMD --repository-url https://github.com/$GITHUB_REPOSITORY"
fi

# Execute semantic-release
# We use eval or simply run it. Since CMD is simple, we can run it.
# But let's print it for clarity if debug
if [[ "$RUNNER_DEBUG" == "1" ]]; then
  echo "Executing: $CMD"
fi
$CMD

# Ensure version files exist to avoid errors
touch LAST_VERSION.txt
touch VERSION.txt

LAST_VERSION=$(cat LAST_VERSION.txt)
VERSION=$(cat VERSION.txt)

# Set Outputs
# Ensure GITHUB_OUTPUT is set, otherwise default to stdout for local testing
if [[ -z "$GITHUB_OUTPUT" ]]; then
  GITHUB_OUTPUT="/dev/stdout"
fi

echo "last-version=$LAST_VERSION" >> "$GITHUB_OUTPUT"

IS_NEW_RELEASE="false"
if [[ -n "$VERSION" ]]; then
  IS_NEW_RELEASE="true"
fi
echo "is-new-release=$IS_NEW_RELEASE" >> "$GITHUB_OUTPUT"

FINAL_VERSION="$VERSION"
if [[ -z "$VERSION" ]] && [[ "$GITHUB_REF_NAME" == "main" ]]; then
  FINAL_VERSION="$LAST_VERSION"
fi
echo "version=$FINAL_VERSION" >> "$GITHUB_OUTPUT"
