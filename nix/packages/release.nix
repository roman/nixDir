# Full release workflow: calculate version, generate changelog, commit, and tag
{ pkgs }:
let
  calculateVersion = import ./calculate-version.nix { inherit pkgs; };
  generateChangelog = import ./generate-changelog.nix { inherit pkgs; };
in
pkgs.writeShellApplication {
  name = "release";
  runtimeInputs = with pkgs; [
    git
    git-cliff
    gnused
  ];
  text = ''
    set -euo pipefail

    # Parse arguments
    DRY_RUN=false
    PUSH=false

    while [[ $# -gt 0 ]]; do
      case $1 in
        --dry-run)
          DRY_RUN=true
          shift
          ;;
        --push)
          PUSH=true
          shift
          ;;
        *)
          echo "Unknown option: $1" >&2
          echo "Usage: release [--dry-run] [--push]" >&2
          exit 1
          ;;
      esac
    done

    REPO_ROOT=$(git rev-parse --show-toplevel)
    cd "$REPO_ROOT"

    # Ensure working directory is clean
    if ! git diff-index --quiet HEAD --; then
      echo "Error: Working directory has uncommitted changes" >&2
      echo "Please commit or stash your changes before releasing" >&2
      exit 1
    fi

    # Calculate the next version
    echo "Calculating next version..."
    NEXT_VERSION=$(${calculateVersion}/bin/calculate-version)
    echo "Next version: $NEXT_VERSION"

    # Check if this version already exists
    if git tag --list | grep -q "^$NEXT_VERSION$"; then
      echo "Tag $NEXT_VERSION already exists. Nothing to release."
      exit 0
    fi

    if [ "$DRY_RUN" = true ]; then
      echo ""
      echo "=== DRY RUN MODE ==="
      echo "Would create release: $NEXT_VERSION"
      echo ""
      echo "Preview of changelog entry:"
      ${generateChangelog}/bin/generate-changelog
      echo ""
      echo "To perform the actual release, run without --dry-run"
      exit 0
    fi

    # Generate the changelog
    echo "Generating changelog..."
    ${generateChangelog}/bin/generate-changelog "$NEXT_VERSION"

    # Commit the changelog
    echo "Committing changelog..."
    git add CHANGELOG.md
    git commit -m "chore(release): $NEXT_VERSION"

    # Create the tag
    echo "Creating tag $NEXT_VERSION..."
    git tag -a "$NEXT_VERSION" -m "Release $NEXT_VERSION"

    echo ""
    echo "=== Release $NEXT_VERSION created locally ==="
    echo ""

    if [ "$PUSH" = true ]; then
      echo "Pushing to remote..."
      BRANCH=$(git rev-parse --abbrev-ref HEAD)
      git push origin "$BRANCH"
      git push origin "$NEXT_VERSION"
      echo "Release $NEXT_VERSION pushed to remote"
    else
      echo "To push this release to the remote, run:"
      BRANCH=$(git rev-parse --abbrev-ref HEAD)
      echo "  git push origin $BRANCH"
      echo "  git push origin $NEXT_VERSION"
    fi
  '';
}
