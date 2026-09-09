{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs =
    {
      self,
      nixpkgs,
      ...
    }@inputs:
    {
      nixosModules = {
        docker-compose = import ./modules/docker-compose.nix;
        neovim-with-plugins = import ./modules/neovim-with-plugins.nix;
        switch-fix = import ./modules/switch-fix.nix;
        symlink = import ./modules/symlink.nix;
        syncthing-config = import ./modules/syncthing-config.nix;
        tmux-enhanced = import ./modules/tmux-enhanced.nix;
      };
    };
}
