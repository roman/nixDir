# Regular package without inputs parameter (backward compatibility test)
{ writeText, ... }: writeText "simple-package" "This is a simple portable package"
