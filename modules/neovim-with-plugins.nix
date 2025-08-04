{ pkgs, lib, config, ... }:
with lib;
let
  cfg = config.programs.neovim-with-plugins;

  # recursively get plugin dependencies
  # partial application of foldl'...
  foldPlugins = builtins.foldl' (
    acc: next:
      acc
      ++ [
        next
      ]
      ++ (foldPlugins (next.dependencies or []))
  ) [];

  # .. which is actually called on cfg.startPlugins
  startPluginsWithDeps = unique (foldPlugins cfg.startPlugins);

  # python
  # TODO: probably need python dependencies
  # python3Env = pkgs.python3.pkgs.python.withPackages
  #   (ps: [ ps.pynvim ] ++ (extraPython3Packages ps) ++ (lib.concatMap (f: f ps) pluginPython3Packages));
  python3Env = pkgs.python3.pkgs.python.withPackages
    (ps: [ ps.pynvim ]);

  packageName = "myNvimPackage";

  # packpath / runtimepath
  packpath = pkgs.runCommandLocal "packpath" {} ''
    mkdir -p $out/pack/${packageName}/{start,opt}
    ${
      concatMapStringsSep
      "\n"
      (plugin: "ln -vsfT ${plugin} $out/pack/${packageName}/start/${lib.getName plugin}")
      startPluginsWithDeps
    }
  '';

  nvim-with-plugins = pkgs.symlinkJoin {
    name = "neovim-impure";
    paths = [
      pkgs.neovim-unwrapped
      python3Env
    ];
    nativeBuildInputs = [
      pkgs.makeWrapper
    ];
    postBuild = ''
      # reads user's standard .config/nvim
      wrapProgram $out/bin/nvim \
        --add-flags '--cmd' \
        --add-flags "'set packpath^=${packpath} | set runtimepath^=${packpath}'"

      makeWrapper ${python3Env.interpreter} $out/bin/nvim-python3 --unset PYTHONPATH --unset PYTHONSAFEPATH
    '';
    passthru = {
      inherit packpath;
    };
  };
in {
  options = {
    programs.neovim-with-plugins = {
      enable = mkEnableOption (mdDoc "Enable with plugins, no configuration");

      startPlugins = mkOption {
        type = types.listOf types.package;
        default = [];
        example = [
          pkgs.vimPlugins.yazi-nvim
        ];
        description = mdDoc ''
          List of plugin pkgs, will go into `start`. An attempt will be made to resolve
          dependencies for plugins from nixpkgs.vimPlugins.
        '';
      };

      initLuaFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        example = ./init.lua;
        description = mdDoc ''
          Path to init.lua which will be copied to /nix/store; this will be added to the wrapper, and thus bypass ~/.config/nvim/init.lua file or symlink.
        '';
      };
    };
  };

  config = mkIf cfg.enable {

    environment.systemPackages = [
      nvim-with-plugins
    ];
  };
}
