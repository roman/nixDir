{ self, ... }:

{
  default = final: prev:
    {
      my-hello = self.packages.${prev.system}.hello;
    };
}
