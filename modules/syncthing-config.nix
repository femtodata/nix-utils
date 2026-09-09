{
  config,
  lib,
  options,
  ...
}:
with lib;
let
  cfg = config.services.syncthing-config;
in
{
  options = with lib; {
    services.syncthing-config = {
      enable = mkEnableOption (mdDoc "enable");
      devices = mkOption {
        default = { };
        description = mkDoc ''
          example goes here
        '';
        type = types.attrsOf (
          types.submodule (
            { name, ... }:
            {
              options = {
                id = mkOption {
                  type = types.str;
                };
                addresses = mkOption {
                  type = types.listOf types.str;
                  default = [ "dynamic" ];
                };
                user = mkOption {
                  type = types.str;
                  default = options.services.syncthing.user.default;
                  description = ''
                    if unset, uses services.syncthing.defaultUser
                  '';
                };
                group = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = ''
                    if unset, uses services.syncthing.defaultGroup
                  '';
                };
                dataDir = mkOption {
                  type = types.path;
                  default = options.services.syncthing.dataDir.default;
                };
                configDir = mkOption {
                  type = types.path;
                  default = options.services.syncthing.configDir.default;
                };
                openDefaultPorts = mkOption {
                  type = types.bool;
                  default = true;
                };
                extraSettings = mkOption {
                  type = types.attrs;
                  default = { };
                  description = ''
                    Additional settings to be merged into syncthing.services.settings
                  '';
                };
              };
            }
          )
        );
      };
      folders = mkOption {
        default = { };
        description = mkDoc ''
          example goes here
        '';
        type = types.attrsOf (
          types.attrsOf (
            types.submodule {
              options = {
                path = mkOption {
                  type = types.nullOr types.path;
                  default = null;
                };
                versioning = mkOption {
                  type = types.nullOr types.attrs;
                  default = null;
                };
              };
            }
          )
        );
      };
      thisDevice = mkOption {
        description = mkDoc ''
          This device, which should be one that is defined in `devices`.
        '';
        type = types.str;
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = (hasAttr cfg.thisDevice cfg.devices);
        message = ''
          `thisDevice` must be defined in `devices`.
        '';
      }
    ];

    services.syncthing =
      let
        device = getAttr cfg.thisDevice cfg.devices;
        devices = filterAttrs (n: v: n != cfg.thisDevice) cfg.devices;
        folders = filterAttrs (n: v: hasAttr cfg.thisDevice v) cfg.folders;
      in
      mkMerge [
        { enable = true; }
        (filterAttrs (
          n: v:
          !(elem n [
            "id"
            "addresses"
            "extraSettings"
          ])
        ) device)
        {
          settings = mkMerge [
            device.extraSettings
            { devices = mapAttrs (n: v: getAttrs [ "id" "addresses" ] v) devices; }
            {
              folders = mapAttrs (
                folderName: folderDef:
                mkMerge [
                  (getAttr cfg.thisDevice folderDef)
                  {
                    devices = (mapAttrsToList (n: v: n) (filterAttrs (_n: _v: _n != cfg.thisDevice) folderDef));
                  }
                ]
              ) folders;
            }
          ];
        }
      ];
  };
}
