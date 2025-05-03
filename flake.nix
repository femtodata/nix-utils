{
  inputs = {
    nixpkgs = "github:NixOS/nixpkgs/nixos-24.11";
  };

  outputs = {
    self,
    nixpkgs,
    ...
  }@inputs: 
  {
    nixosModules = {
      switch-fix = import ./modules/switch-fix.nix;
    };
  };
}
