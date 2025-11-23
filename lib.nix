{ dirName, lib, ... }: {
  # checkConflicts validates that there are no overlapping keys between
  # regular and with-inputs directories. Having the same name in both
  # locations is likely a mistake by the flake author.
  checkConflicts = outputType: regular: withInputs:
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
}
