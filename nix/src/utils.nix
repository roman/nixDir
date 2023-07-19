nixDirInputs: { inputs
              , injectOverlays ? [ ]
              , ...
              } @ buildFlakeCfg:

let
  inherit (inputs) self nixpkgs;
  inherit (nixpkgs) lib;

  getFlakeInput = inputName: inputUrl:
    if lib.hasAttr inputName inputs then
      inputs.${inputName}
    else
      throw ''
        nixDir requires you to add the following setup to your `flake.nix`:

        {
          inputs = {
            # ...
            ${inputName}.url = "${inputUrl}";
            # ...
          };
          # ...
        }
      '';


  # doesOverlayExists check if the given overlayName is present in the flake's
  # overlays attribute-set.
  doesOverlayExist = overlayName:
    builtins.hasAttr overlayName self.overlays;

  # overlaysToInject creates an attribute-set with the names of the
  # flake overlays to import.
  #
  # TODO: add unit tests for this constant
  overlaysToInject =
    # do not validate empty case as it is impossible to create an empty
    # overlays entry using nixDir
    builtins.foldl'
      (acc: overlayName:
        # validate that the overlay we want injected in the pkgs import is not
        # used
        if doesOverlayExist overlayName then
          acc // { "${overlayName}" = true; }
        else
          let
            availableOverlays =
              builtins.concatStringsSep ", "
                (builtins.attrNames self.overlays);
          in
          throw ''
            nixDir is confused, it can't find the overlay `${overlayName}` in this flake's overlays set.

            Available options are: ${availableOverlays}
          ''
      )
      { }
      injectOverlays;

  # shouldInjectOverlay receives an overlay name and returns if the overlay
  # should be applied or not
  shouldInjectOverlay = overlayName:
    if builtins.typeOf injectOverlays == "bool" then
      true
    else
      builtins.hasAttr overlayName overlaysToInject;

  # getPkgs returns the nixpkgs repository for the given system with optional
  # embedded overlays from the self flake.
  getPkgs = system:
    if self ? overlays
    then
    # when current flake has overlays, attempt to include the overlays that got
    # specified in the `injectOverlays` option.
      import nixpkgs
        {
          inherit system;
          overlays =
            builtins.attrValues
              (lib.filterAttrs
                (overlayName: _: shouldInjectOverlay overlayName)
                self.overlays);
        }
    else
      import nixpkgs {
        inherit system;
      };

  # eachSystemMapWithPkgs calls the `flake-util.lib.eachSystemMapWith` utility,
  # but instead of providing a system, it provides the nixpkgs import with the
  # nixDir flake's overlays injected.
  eachSystemMapWithPkgs = systems: f:
    nixDirInputs.utils.lib.eachSystemMap
      systems
      (system: f (getPkgs system));

  # applyFlakeOutput will apply the given entry to the final outputs result if check
  # is true
  applyFlakeOutput = check: entry0: outputs:
    let
      entry =
        if builtins.isFunction entry0
        then entry0 outputs
        else entry0;
    in
    if check
    then nixDirInputs.nixpkgs.lib.recursiveUpdate outputs entry
    else outputs;

in
{
  inherit getPkgs getFlakeInput eachSystemMapWithPkgs applyFlakeOutput;
}
