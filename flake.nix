{
  description = "zenful nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, nix-homebrew, home-manager }:
  let
    configuration = { pkgs, config, ... }: {
      
      # --- System Settings ---
      nixpkgs.config.allowUnfree = true;
      nix.settings.experimental-features = [ "nix-command" "flakes" ];
      
      system.configurationRevision = self.rev or self.dirtyRev or null;
      system.stateVersion = 6;
      nixpkgs.hostPlatform = "aarch64-darwin";

      # --- System Packages (OS Level Tools) ---
      environment.systemPackages = [
        pkgs.mkalias
        pkgs.git
        pkgs.neofetch
        pkgs.tmux
        pkgs.aria2
        pkgs.maccy
      ];

      # --- MacOS Defaults ---
      system.defaults = {
        dock.autohide = true;
        finder.AppleShowAllExtensions = true;
      };
      
      # --- User Configuration ---
      users.users.dniel = {
        name = "dniel";
        home = "/Users/dniel";
      };
      system.primaryUser = "dniel";

      # --- Homebrew Config ---
      homebrew = {
        enable = true;
        onActivation = {
          autoUpdate = true;
          upgrade = true;
          cleanup = "zap";
        };
        brews = [
          "mas"
          "composer"
          "mysql"
          "lazygit"
          "tea"
          "ghostscript"
        ];
        casks = [
          "hammerspoon"
          "firefox"
          "iina"
          "the-unarchiver"
          "iterm2"
          "ghostty"        
          "orbstack"      
          "steam"
          "chromedriver"
          "localsend"
        ];
      };

      fonts.packages = with pkgs; [
        nerd-fonts.jetbrains-mono
        nerd-fonts.fira-code
        liberation_ttf
        inter
        ubuntu-classic
        fira-code
        jetbrains-mono
        noto-fonts
        noto-fonts-cjk-sans
        noto-fonts-color-emoji
      ];

      # --- Activation Script (Fix Spotlight Indexing for Nix Apps) ---
      system.activationScripts.applications.text = let
        env = pkgs.buildEnv {
          name = "system-applications";
          paths = config.environment.systemPackages;
          pathsToLink = [ "/Applications" ];
        };
      in pkgs.lib.mkForce ''
        echo "setting up /Applications..." >&2
        rm -rf /Applications/Nix\ Apps
        mkdir -p /Applications/Nix\ Apps
        find ${env}/Applications -maxdepth 1 -type l -exec readlink -f '{}' \; | while read -r src; do
          app_name=$(basename "$src")
          echo "copying $src" >&2
          ${pkgs.mkalias}/bin/mkalias "$src" "/Applications/Nix Apps/$app_name"
        done
      '';
    };
  in
  {
    darwinConfigurations."mac" = nix-darwin.lib.darwinSystem {
      modules = [
        configuration
        nix-homebrew.darwinModules.nix-homebrew
        {
          nix-homebrew = {
            enable = true;
            enableRosetta = true;
            user = "dniel";
            autoMigrate = true;
          };
        }
        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.dniel = { pkgs, ... }: {
            
            home.stateVersion = "24.05";

            # ─────────────────────────────────────────────────────────────────
            # ENV VARIABLES
            # Diset di sini agar semua program (termasuk Neovim) bisa membaca.
            # ─────────────────────────────────────────────────────────────────
            home.sessionVariables = {
              # JAVA_HOME → path JDK 21 dari nix store, selalu konsisten
              JAVA_HOME  = "${pkgs.jdk21}";
              # LOMBOK_JAR → dipakai ftplugin/java.lua untuk vmArgs jdtls
              LOMBOK_JAR = "${pkgs.lombok}/share/java/lombok.jar";
            };

            home.sessionPath = [
              "${pkgs.jdk21}/bin"
            ];

            # ─────────────────────────────────────────────────────────────────
            # GLOBAL DEVELOPMENT STACK
            # ─────────────────────────────────────────────────────────────────
            home.packages = with pkgs; [
              # 1. Shell Utils & Search
              zsh-powerlevel10k
              meslo-lgs-nf
              ripgrep
              fd
              fzf
              tldr
              wget
              curl
              unzip

              # 2. Golang
              go
              gopls
              delve

              # 3. Node.js / Web
              nodejs_22
              yarn
              
              # 4. PHP
              php

              # 5. Python
              python3

              # 6. C/C++
              gcc
              gnumake
              cmake

              # 7. C# / .NET
              dotnet-sdk

              # ── 8. Java Stack ────────────────────────────────────────────
              jdk21            # JDK 21 LTS — runtime + compiler (javac, java)
              maven            # Build tool berbasis XML (pom.xml) — umum di kampus
              gradle           # Build tool modern (build.gradle) — alternatif Maven
              google-java-format # Formatter resmi gaya Google
              lombok           # Annotation processor: @Getter, @Setter, @Builder, dll
              # ─────────────────────────────────────────────────────────────

              # Linux-like tools
              coreutils
              eza
              bat
              zoxide
              yazi
              btop
              jq

              # Fun
              ani-cli
              ffmpeg
              mpv

              # Database
              postgresql
              openssl 
              zlib

              # Web dev
              posting
              docker_29
              docker-compose
              drawio
            ];

            # ─────────────────────────────────────────────────────────────────
            # NEOVIM
            # extraPackages = binary yang di-inject ke dalam PATH wrapper nvim.
            # Ini memastikan jdtls, java, dan formatter selalu tersedia
            # bahkan jika user menjalankan nvim dari luar shell (contoh: GUI).
            # ─────────────────────────────────────────────────────────────────
            programs.neovim = {
              enable = true;
              defaultEditor = true;
              viAlias = true;
              vimAlias = true;
              extraPackages = with pkgs; [
                gcc
                gnumake
                nodejs_22
                ripgrep
                fd
                unzip
                tree-sitter

                # ── Java untuk Neovim ───────────────────────────────────────
                jdt-language-server  # JDTLS — binary `jdtls` dipanggil nvim-jdtls
                jdk21                # Java runtime yang dipakai jdtls
                google-java-format   # Dipakai conform.nvim untuk format-on-save
                # ────────────────────────────────────────────────────────────
              ];
            };

            # --- Zsh Config ---
            programs.zsh = {
              enable = true;
              enableCompletion = true;
              autosuggestion.enable = true;
              syntaxHighlighting.enable = true;

              shellAliases = {
                ls = "eza --icons";
                ll = "eza -l --icons --git -a";
                lt = "eza --tree --level=2 --icons";
              };
              
              oh-my-zsh = {
                enable = true;
                plugins = [ "git" "sudo" "docker" "web-search" ];
              };

              initExtra = ''
                source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
                [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
              '';
            };

            programs.zoxide = {
              enable = true;
              enableZshIntegration = true;
              options = [ "--cmd cd" ];
            };

            programs.tmux = {
              enable = true;
              shortcut = "a";
              baseIndex = 1;
              extraConfig = ''
                bind | split-window -h
                bind - split-window -v
                unbind '"'
                unbind %
                bind h select-pane -L
                bind j select-pane -D
                bind k select-pane -U
                bind l select-pane -R
                set -g mouse on
              '';
            };
          };
        }
      ];
    };
  };
}
