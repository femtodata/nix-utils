{ pkgs, lib, config, ... }:
with lib;
let
  cfg = config.services.symlink;
in {
  options = {
    services.symlink = {
      enable = mkEnableOption 
        (mdDoc "Set up symlinks, possibly impure.");
      entries = mkOption {
        default = {};
        description = mdDoc ''
          target -> src mapping
        '';
        type = types.attrsOf (types.submodule ({ targetPath, ... }: {
          options = {
            targetPath = mkOption {
              type = types.str;
              default = targetPath;
              description = ''
                symlink target
              '';
            };

            sourcePath = mkOption {
              type = types.nullOr types.path;
              default = null;
              description = ''
                Mutually exclusive with `sourcePathImpure`. Path to symlink to `targetPath`. This will be copied to /nix/store, so will be immutable.
              '';
            };

            sourcePathImpure = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = ''
                Mutually exclusive with `sourcePath`. Path to symlink to `targetPath`. This will *not* be copied to /nix/store, as we want to be able to modify on the fly. Impure!
              '';
            };
          };
        }));
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.all
          (entry: !(entry.sourcePath != null && entry.sourcePathImpure != null) 
               && !(entry.sourcePath == null && entry.sourcePathImpure == null))
          (builtins.attrValues cfg.entries)
        ;
        message = ''
          One and only one of `sourcePath` and `sourcePathImpure` must be defined;
        '';
      }
    ];

    systemd.services.generate-symlinks = let
      getSourcePath = entry: if entry.sourcePath != null
          then entry.sourcePath
          else entry.sourcePathImpure;
    in {
      description = "generate symlinks (maybe impurely)";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        RemainAfterExit = "no";
        ExecStart = pkgs.writeShellScript "generate-symlinks" ''
          set -x
          function symlink() {
            if [[ -e "$2" && ! -L "$2" ]] ; then 
                echo "$2 exists and is not a symlink. Ignoring it." >&2
                return 1
            fi
            # "ln -sf source link" follows symlinks by default on ancient BSD (thus on macOS)
            # the fix on ancient BSD is to add -h, which would be incompatible with GNU
            # which doesn't do any of this nonsense and doesn't accept -h either
            #
            # Thus we get to -f ourselves because shell scripting is jank.
            mkdir -p $(dirname $2)
            [[ -L "$2" ]] && rm "$2"
            ln -sv "$1" "$2"
          }

          ${concatStringsSep "\n" (mapAttrsToList
            (name: value: "symlink ${getSourcePath value} ${name}")
            cfg.entries)}
        '';
      };
    };
  };
}
