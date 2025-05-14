{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  };


  outputs = {
    self,
    nixpkgs,
    ...
  }@inputs: {
    nixosModules = {
      docker-compose = import ./modules/docker-compose.nix;
      switch-fix = import ./modules/switch-fix.nix;
    };
  };
}
