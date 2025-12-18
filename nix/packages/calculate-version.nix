# Calculate the next semantic version based on conventional commits
{ pkgs }:
pkgs.writeShellApplication {
  name = "calculate-version";
  runtimeInputs = with pkgs; [
    git
    git-cliff
    gnused
  ];
  text = ''
    set -euo pipefail

    # Get the current branch to determine version prefix
    BRANCH=$(git rev-parse --abbrev-ref HEAD)

    # Determine version prefix from branch name
    # v3 branch -> v3.x.y, main -> v1.x.y (or whatever the default major is)
    case "$BRANCH" in
      v[0-9]*)
        # Extract major version from branch name (e.g., v3 -> 3)
        MAJOR_VERSION=''${BRANCH#v}
        ;;
      main|master)
        # Default to major version 1 for main branch
        MAJOR_VERSION="1"
        ;;
      *)
        echo "Warning: Unknown branch '$BRANCH', defaulting to major version 0" >&2
        MAJOR_VERSION="0"
        ;;
    esac

    # Get the latest tag for this major version
    LATEST_TAG=$(git tag --list "v$MAJOR_VERSION.*" --sort=-v:refname | head -n1 || echo "")

    if [ -z "$LATEST_TAG" ]; then
      # No existing tag for this major version - start at x.0.0
      echo "v$MAJOR_VERSION.0.0"
      exit 0
    fi

    # Extract current version numbers
    CURRENT_VERSION=''${LATEST_TAG#v}
    CURRENT_MAJOR=$(echo "$CURRENT_VERSION" | cut -d. -f1)
    CURRENT_MINOR=$(echo "$CURRENT_VERSION" | cut -d. -f2)
    CURRENT_PATCH=$(echo "$CURRENT_VERSION" | cut -d. -f3)

    # Get commits since the last tag
    COMMITS_SINCE_TAG=$(git log "$LATEST_TAG"..HEAD --oneline 2>/dev/null || echo "")

    if [ -z "$COMMITS_SINCE_TAG" ]; then
      # No new commits since last tag
      echo "$LATEST_TAG"
      exit 0
    fi

    # Check for feat: commits (minor bump) or other commits (patch bump)
    # Using git log with grep to find commit types
    HAS_FEAT=$(git log "$LATEST_TAG"..HEAD --pretty=format:"%s" | grep -E "^feat(\(.+\))?:" || echo "")

    if [ -n "$HAS_FEAT" ]; then
      # Minor version bump
      NEW_MINOR=$((CURRENT_MINOR + 1))
      echo "v$CURRENT_MAJOR.$NEW_MINOR.0"
    else
      # Patch version bump
      NEW_PATCH=$((CURRENT_PATCH + 1))
      echo "v$CURRENT_MAJOR.$CURRENT_MINOR.$NEW_PATCH"
    fi
  '';
}
