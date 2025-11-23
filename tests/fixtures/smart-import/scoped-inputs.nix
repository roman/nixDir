inputs: { pkgs, ... }: {
  # Module that uses scoped inputs
  # If scopeInputsToSystem worked, inputs.testInput.packages should be scoped
  hasTestInput = inputs ? testInput;
  testInputHasPackages = inputs.testInput ? packages;
  # This should work if packages is scoped from packages.${system}
  canAccessPackage = inputs.testInput.packages ? testPkg;
}
