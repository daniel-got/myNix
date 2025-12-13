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
          cleanup = "zap"; # Hati-hati: ini akan menghapus aplikasi yang tidak terdaftar di sini
        };
        brews = [
          "mas"
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
        ];
      };

      fonts.packages = [
        pkgs.nerd-fonts.jetbrains-mono
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

            # --- GLOBAL DEVELOPMENT STACK ---
            # Ini adalah tool yang tersedia di terminal (zsh) secara global.
            home.packages = with pkgs; [
              # 1. Shell Utils & Search
              zsh-powerlevel10k
              meslo-lgs-nf
              ripgrep       # Wajib untuk Telescope/Vim
              fd            # Wajib untuk file finding
              jq            # JSON processor
              fzf           # Fuzzy finder
              tldr          # Man pages simple
              wget
              curl
              unzip

              # 2. Golang
              go
              gopls         # LSP Global
              delve         # Debugger

              # 3. Node.js / Web
              nodejs_22     # Runtime (npm/node)
              yarn
              
              # 4. PHP
              php           # PHP CLI Global

              # 5. Python
              python3       # Python 3 Runtime

              # 6. C/C++
              gcc           # GNU Compiler
              gnumake       # Make
              cmake         # Build system

              # 7. C# / .NET
              dotnet-sdk    # .NET SDK Global

              #linux looks like 
              coreutils     # GNU ls, cat, etc (supaya script linux jalan)
              eza           # ls on steroids
              bat           # cat on steroids
              zoxide        # cd on steroids
              yazi          # Terminal File Manager (Ranger killer)
              btop          # htop replacement (monitor resource)
              jq            # JSON processor
              tldr          # Man pages yang tidak membosankan

              #fun 
              ani-cli
              ffmpeg
              mpv

              #database
              postgresql
              openssl 
              zlib

              #web-developing
              posting
            ];

            # --- Neovim Config ---
            programs.neovim = {
              enable = true;
              defaultEditor = true;
              viAlias = true;
              vimAlias = true;
              # Dependency Neovim disamakan dengan home.packages agar tidak redudansi,
              # tapi tetap di-inject ke wrapper agar "pasti ada" saat nvim jalan.
              extraPackages = with pkgs; [
                gcc
                gnumake
                nodejs_22
                ripgrep
                fd
                unzip
                tree-sitter
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
                ll = "eza -l --icons --git -a"; # Bonus: List detail + git status
                lt = "eza --tree --level=2 --icons"; # Bonus: Tree view
              };
              
              oh-my-zsh = {
                enable = true;
                plugins = [ "git" "sudo" "docker" "web-search" ];
              };

              initExtra = ''
                # Load Powerlevel10k
                source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
                
                # Load p10k config
                [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
              '';
            };

            #program zoxide
            programs.zoxide = {
              enable = true;
              enableZshIntegration = true;
              options = [ "--cmd cd" ];
            };

            #programs tmux
            programs.tmux = {
              enable = true;
              shortcut = "a"; # Mengubah Prefix dari Ctrl+b jadi Ctrl+a (Jauh lebih ergonomis)
              baseIndex = 1;  # Mulai hitung window dari 1, bukan 0 (biar sesuai tombol keyboard)
              
              extraConfig = ''
                # Split panes dengan tombol yang masuk akal (| dan -)
                bind | split-window -h
                bind - split-window -v
                unbind '"'
                unbind %

                # Pindah pane pakai gaya Vim (h,j,k,l)
                bind h select-pane -L
                bind j select-pane -D
                bind k select-pane -U
                bind l select-pane -R

                # Aktifkan Mouse (biar bisa klik/resize pane pakai mouse saat malas)
                set -g mouse on
              '';
            };
          };
        }
      ];
    };
  };
}
