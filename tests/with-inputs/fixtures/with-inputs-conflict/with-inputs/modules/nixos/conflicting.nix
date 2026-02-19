inputs:
{ ... }:
{
  # With-inputs module - conflicts with regular module
  _meta.type = "with-inputs";
  _meta.inputCount = builtins.length (builtins.attrNames inputs);
}
