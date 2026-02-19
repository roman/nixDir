{
  # Portable configuration - doesn't need inputs
  # Returns configuration attrset directly
  system = "x86_64-linux";
  modules = [
    (
      { ... }:
      {
        # Simple test module
        _meta.configType = "portable";
      }
    )
  ];
}
