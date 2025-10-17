{ pkgs, ... }:
let
  switch-fix = pkgs.writeShellScriptBin "switch-fix" ''
    sudo nix-env --profile /nix/var/nix/profiles/system --set /run/current-system
    sudo /run/current-system/bin/switch-to-configuration switch
  '';
  boot-fix = pkgs.writeShellScriptBin "boot-fix" ''
    sudo nix-env --profile /nix/var/nix/profiles/system --set $1
    sudo $1/bin/switch-to-configuration boot
  '';
  rollback-profile-base = "/var/lib/nix-autorollback";
  rollback-profile-path = "${rollback-profile-base}/profile";
  rollback-profile-switch-path = "${rollback-profile-base}/profile-switch";
  rollback-delay = "90";

  set-rollback = pkgs.writeShellScriptBin "set-rollback" ''
    if [ -d ${rollback-profile-switch-path} ]; then
      echo "Error: rollback-profile-switch-path at ${rollback-profile-switch-path} exists"
    else
      sudo ln -sf $(readlink /run/current-system) ${rollback-profile-path}
    fi
  '';

  set-rollback-switch = pkgs.writeShellScriptBin "set-rollback-switch" ''
    if [ -d ${rollback-profile-path} ]; then
      echo "Error: rollback-profile-switch-path at ${rollback-profile-switch-path} exists"
    else
      sudo ln -sf $(readlink /run/current-system) ${rollback-profile-switch-path}
    fi
  '';

  cancel-rollback = pkgs.writeShellScriptBin "cancel-rollback" ''
    sudo systemctl stop nix-autorollback.service
    if [ -d ${rollback-profile-path} ]; then
      sudo rm ${rollback-profile-path}
    fi
    if [ -d ${rollback-profile-switch-path} ]; then
      sudo rm ${rollback-profile-switch-path}
    fi
  '';
in
{
  systemd.tmpfiles.rules = [ 
    "d ${rollback-profile-base} 0755 root root - -" 
  ];

  environment.systemPackages = [
    switch-fix
    boot-fix
    set-rollback
    set-rollback-switch
    cancel-rollback
  ];

  systemd.services."nix-autorollback" = {
    description = "rollback to set profile unless stopped";
    wantedBy = [ "sysinit.target" ];
    script = ''
      if [ -d ${rollback-profile-path} ]; then
        ${pkgs.util-linux}/bin/wall -t 5 "Autorollback in ${rollback-delay}"
        echo "Autorollback in ${rollback-delay}"
        ${pkgs.coreutils}/bin/sleep ${rollback-delay}
        ${pkgs.util-linux}/bin/wall "Rolling back to $(readlink ${rollback-profile-path})"
        echo "Rolling back to $(readlink ${rollback-profile-path})"
        ${pkgs.nix}/bin/nix-env --profile /nix/var/nix/profiles/system --set $(readlink ${rollback-profile-path})
        $(readlink ${rollback-profile-path})/bin/switch-to-configuration boot
        rm ${rollback-profile-path}
        ${pkgs.systemd}/bin/shutdown -r now
      elif [ -d ${rollback-profile-switch-path} ]; then
        ${pkgs.util-linux}/bin/wall -t 5 "Autorollback (switch) in ${rollback-delay}"
        echo "Autorollback in ${rollback-delay}"
        ${pkgs.coreutils}/bin/sleep ${rollback-delay}
        ${pkgs.util-linux}/bin/wall "Rolling back to $(readlink ${rollback-profile-switch-path})"
        echo "Rolling back to $(readlink ${rollback-profile-switch-path})"
        ${pkgs.nix}/bin/nix-env --profile /nix/var/nix/profiles/system --set $(readlink ${rollback-profile-switch-path})
        $(readlink ${rollback-profile-switch-path})/bin/switch-to-configuration switch
        rm ${rollback-profile-switch-path}
      fi
    '';
    serviceConfig = {
      Type = "simple";
      User = "root";
    };
  };
}
