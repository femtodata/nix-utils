{
  config,
  pkgs,
  lib,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkOption
    mkPackageOption
    mkIf
    types
    optionalString
    ;

  cfg = config.programs.tmux-enhanced;

  pluginName = p: if types.package.check p then p.pname else p.plugin.pname;

  pluginModule = types.submodule {
    options = {
      plugin = mkOption {
        type = types.package;
        description = "Path of the configuration file to include.";
      };

      extraConfig = mkOption {
        type = types.lines;
        description = "Additional configuration for the associated plugin.";
        default = "";
      };
    };
  };

  defaultKeyMode = "emacs";
  defaultResize = 5;
  defaultShortcut = "b";
  defaultTerminal = "screen";

  boolToStr = value: if value then "on" else "off";

  tmuxConf = ''
    ${optionalString cfg.sensibleOnTop ''
      # ============================================= #
      # Start with defaults from the Sensible plugin  #
      # --------------------------------------------- #
      run-shell ${pkgs.tmuxPlugins.sensible.rtp}
      # ============================================= #
    ''}
    set  -g default-terminal "${cfg.terminal}"
    set  -g base-index      ${toString cfg.baseIndex}
    setw -g pane-base-index ${toString cfg.baseIndex}
    set  -g history-limit   ${toString cfg.historyLimit}

    ${optionalString cfg.newSession "new-session"}

    ${optionalString cfg.reverseSplit ''
      bind v split-window -h
      bind s split-window -v
    ''}

    set -g status-keys ${cfg.keyMode}
    set -g mode-keys   ${cfg.keyMode}

    ${optionalString (cfg.keyMode == "vi" && cfg.customPaneNavigationAndResize) ''
      bind -N "Select pane to the left of the active pane" h select-pane -L
      bind -N "Select pane below the active pane" j select-pane -D
      bind -N "Select pane above the active pane" k select-pane -U
      bind -N "Select pane to the right of the active pane" l select-pane -R

      bind -r -N "Resize the pane left by ${toString cfg.resizeAmount}" \
        H resize-pane -L ${toString cfg.resizeAmount}
      bind -r -N "Resize the pane down by ${toString cfg.resizeAmount}" \
        J resize-pane -D ${toString cfg.resizeAmount}
      bind -r -N "Resize the pane up by ${toString cfg.resizeAmount}" \
        K resize-pane -U ${toString cfg.resizeAmount}
      bind -r -N "Resize the pane right by ${toString cfg.resizeAmount}" \
        L resize-pane -R ${toString cfg.resizeAmount}
    ''}

    ${
      if cfg.prefix != null then
        ''
          # rebind main key: ${cfg.prefix}
          unbind C-${defaultShortcut}
          set -g prefix ${cfg.prefix}
          bind -N "Send the prefix key through to the application" \
            ${cfg.prefix} send-prefix
        ''
      else
        optionalString (cfg.shortcut != defaultShortcut) ''
          # rebind main key: C-${cfg.shortcut}
          unbind C-${defaultShortcut}
          set -g prefix C-${cfg.shortcut}
          bind -N "Send the prefix key through to the application" \
            ${cfg.shortcut} send-prefix
          bind C-${cfg.shortcut} last-window
        ''
    }

    ${optionalString cfg.disableConfirmationPrompt ''
      bind-key -N "Kill the current window" & kill-window
      bind-key -N "Kill the current pane" x kill-pane
    ''}

    set  -g mouse             ${boolToStr cfg.mouse}
    set  -g focus-events      ${boolToStr cfg.focusEvents}
    setw -g aggressive-resize ${boolToStr cfg.aggressiveResize}
    setw -g clock-mode-style  ${if cfg.clock24 then "24" else "12"}
    set  -s escape-time       ${toString cfg.escapeTime}
    set  -g history-limit     ${toString cfg.historyLimit}

    ${cfg.extraConfigBeforePlugins}

    ${lib.optionalString (cfg.plugins != [ ]) ''
      # Run plugins
      ${lib.concatMapStringsSep "\n" (x: "run-shell ${x.rtp}") cfg.plugins}

    ''}

    ${cfg.extraConfig}
  '';

in
{
  ###### interface

  options = {
    programs.tmux-enhanced = {

      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Whenever to configure {command}`tmux` system-wide.";
        relatedPackages = [ "tmux" ];
      };

      package = mkPackageOption pkgs "tmux" { };

      aggressiveResize = mkOption {
        default = false;
        type = types.bool;
        description = ''
          Resize the window to the size of the smallest session for which it is the current window.
        '';
      };

      baseIndex = mkOption {
        default = 0;
        example = 1;
        type = types.int;
        description = "Base index for windows and panes.";
      };

      clock24 = mkOption {
        default = false;
        type = types.bool;
        description = "Use 24 hour clock.";
      };

      customPaneNavigationAndResize = mkOption {
        default = false;
        type = types.bool;
        description = "Override the hjkl and HJKL bindings for pane navigation and resizing in VI mode.";
      };

      disableConfirmationPrompt = mkOption {
        default = false;
        type = types.bool;
        description = ''
          Disable confirmation prompt before killing a pane or window
        '';
      };

      escapeTime = mkOption {
        default = 500;
        example = 0;
        type = types.int;
        description = "Time in milliseconds for which tmux waits after an escape is input.";
      };

      extraConfigBeforePlugins = mkOption {
        default = "";
        description = ''
          Additional contents of /etc/tmux.conf, to be run before sourcing plugins.
        '';
        type = types.lines;
      };

      extraConfig = mkOption {
        default = "";
        description = ''
          Additional contents of /etc/tmux.conf, to be run after sourcing plugins.
        '';
        type = types.lines;
      };

      focusEvents = mkOption {
        default = false;
        type = types.bool;
        description = ''
          On supported terminals, request focus events and pass them through to
          applications running in tmux.
        '';
      };

      historyLimit = mkOption {
        default = 2000;
        example = 5000;
        type = types.int;
        description = "Maximum number of lines held in window history.";
      };

      keyMode = mkOption {
        default = defaultKeyMode;
        example = "vi";
        type = types.enum [
          "emacs"
          "vi"
        ];
        description = "VI or Emacs style shortcuts.";
      };

      mouse = mkEnableOption "mouse support";

      newSession = mkOption {
        default = false;
        type = types.bool;
        description = "Automatically spawn a session if trying to attach and none are running.";
      };

      reverseSplit = mkOption {
        default = false;
        type = types.bool;
        description = "Reverse the window split shortcuts.";
      };

      resizeAmount = mkOption {
        default = defaultResize;
        example = 10;
        type = types.int;
        description = "Number of lines/columns when resizing.";
      };

      sensibleOnTop = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Run the sensible plugin at the top of the configuration. It
          is possible to override the sensible settings using the
          {option}`programs.tmux.extraConfig` option.
        '';
      };

      prefix = mkOption {
        default = null;
        example = "C-a";
        type = types.nullOr types.str;
        description = ''
          Set the prefix key. Overrules the "shortcut" option when set.
        '';
      };

      shortcut = mkOption {
        default = defaultShortcut;
        example = "a";
        type = types.str;
        description = "Ctrl following by this key is used as the main shortcut.";
      };

      terminal = mkOption {
        default = defaultTerminal;
        example = "screen-256color";
        type = types.str;
        description = ''
          Set the $TERM variable. Use tmux-direct if italics or 24bit true color
          support is needed.
        '';
      };

      secureSocket = mkOption {
        default = true;
        type = types.bool;
        description = ''
          Store tmux socket under /run, which is more secure than /tmp, but as a
          downside it doesn't survive user logout.
        '';
      };

      plugins = mkOption {
        default = [ ];
        type = types.listOf types.package;
        description = "List of plugins to install.";
        example = lib.literalExpression "[ pkgs.tmuxPlugins.nord ]";
      };

      withUtempter = mkOption {
        description = ''
          Whether to enable libutempter for tmux.
          This is required so that tmux can write to /var/run/utmp (which can be queried with `who` to display currently connected user sessions).
          Note, this will add a guid wrapper for the group utmp!
        '';
        default = true;
        type = types.bool;
      };
    };
  };

  ###### implementation

  config = mkIf cfg.enable {
    environment = {
      etc."tmux.conf".text = tmuxConf;

      systemPackages = [ cfg.package ] ++ cfg.plugins;

      variables = {
        TMUX_TMPDIR = lib.optional cfg.secureSocket ''''${XDG_RUNTIME_DIR:-"/run/user/$(id -u)"}'';
      };
    };
    security.wrappers = mkIf cfg.withUtempter {
      utempter = {
        source = "${pkgs.libutempter}/lib/utempter/utempter";
        owner = "root";
        group = "utmp";
        setuid = false;
        setgid = true;
      };
    };
  };

}
