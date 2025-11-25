{ dirName, lib, ... }:
{
  # checkConflicts validates that there are no overlapping keys between
  # regular and with-inputs directories. Having the same name in both
  # locations is likely a mistake by the flake author.
  checkConflicts =
    outputType: regular: withInputs:
    let
      conflicts = builtins.filter (name: regular ? ${name}) (builtins.attrNames withInputs);
      hasConflicts = builtins.length conflicts > 0;
    in
    if hasConflicts then
      throw ''
        nixDir found conflicting ${outputType} entries in both regular and with-inputs directories:
        ${lib.concatStringsSep ", " conflicts}

        Each entry should exist in either the regular directory OR the with-inputs directory, not both.

        Regular: ${dirName}/${outputType}/
        With-inputs: ${dirName}/with-inputs/${outputType}/

        Please move or rename the conflicting entries.
      ''
    else
      regular // withInputs;

  # filterByPlatform filters packages based on meta.platforms and meta.broken attributes.
  # Packages without meta.platforms are available on all systems.
  # Packages with meta.broken = true are always filtered out.
  filterByPlatform =
    system: packages:
    lib.filterAttrs (
      _name: pkg:
      let
        # Check if this is actually a derivation
        isDrv = lib.isDerivation pkg;

        # Get meta.platforms, default to null (all platforms supported)
        platforms = pkg.meta.platforms or null;

        # Check if package is marked as broken
        broken = pkg.meta.broken or false;

        # Determine if the package is supported on this system
        isSupported =
          if platforms == null then
            true # No restriction = all platforms supported
          else if builtins.isList platforms then
            builtins.elem system platforms
          else
            false; # Invalid platforms value, filter it out
      in
      isDrv && !broken && isSupported
    ) packages;
}
