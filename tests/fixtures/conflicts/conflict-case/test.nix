{ pkgs, ... }: {
  # Conflicting file - should cause error
  testValue = "from-file";
}
