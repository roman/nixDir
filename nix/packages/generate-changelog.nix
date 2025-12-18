# Generate changelog using git-cliff
{ pkgs }:
pkgs.writeShellApplication {
  name = "generate-changelog";
  runtimeInputs = with pkgs; [
    git
    git-cliff
  ];
  text = ''
    set -euo pipefail

    # Optional: pass a specific version as argument
    VERSION=''${1:-}

    # Find the cliff.toml config file (look in repo root)
    REPO_ROOT=$(git rev-parse --show-toplevel)
    CONFIG_FILE="$REPO_ROOT/cliff.toml"

    if [ ! -f "$CONFIG_FILE" ]; then
      echo "Error: cliff.toml not found at $CONFIG_FILE" >&2
      exit 1
    fi

    if [ -n "$VERSION" ]; then
      # Generate changelog for a specific version
      git-cliff --config "$CONFIG_FILE" --tag "$VERSION" --output "$REPO_ROOT/CHANGELOG.md"
      echo "Generated CHANGELOG.md for $VERSION"
    else
      # Generate unreleased changelog (preview mode)
      git-cliff --config "$CONFIG_FILE" --unreleased
    fi
  '';
}
