{
  description = "zenful nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    home-manager.url = "github:nix-community/home-manager";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, nix-homebrew, home-manager }:
  let
    configuration = { pkgs, config, ... }: {
      # List packages installed in system profile. To search by name, run:
      # $ nix-env -qaP | grep wget
      nixpkgs.config.allowUnfree = true;
 
      environment.systemPackages =
        [ pkgs.neovim
	  pkgs.mkalias
	  pkgs.git
	  pkgs.neofetch
	  pkgs.tmux
        ];

      users.users.dniel = {
        name = "dniel";
        home = "/Users/dniel";
      };

      system.primaryUser = "dniel";

      homebrew = {
      	enable = true;
	brews = [
	  "mas"
	];
	casks = [
	  "hammerspoon"
	  "firefox"
	  "iina"
	  "the-unarchiver"
	  "iterm2"
	];
	masApps = {
	};
	onActivation.cleanup = "zap";
	onActivation.autoUpdate = true ;
	onActivation.upgrade = true ;
      };

      fonts.packages = [
      	pkgs.nerd-fonts.jetbrains-mono
      ];

	
      # Necessary for using flakes on this system.
      nix.settings.experimental-features = ["nix-command flakes"];

      # Enable alternative shell support in nix-darwin.
      # programs.fish.enable = true;

      # Set Git commit hash for darwin-version.
      system.configurationRevision = self.rev or self.dirtyRev or null;

      # Used for backwards compatibility, please read the changelog before changing.
      #system default settings
      system.defaults = {
        dock.autohide = true;
        finder.AppleShowAllExtensions = true;
      };

      system.activationScripts.applications.text = let
        env = pkgs.buildEnv {
          name = "system-applications";
          paths = config.environment.systemPackages;
          pathsToLink = ["/Applications"];
        };
      in pkgs.lib.mkForce ''
        # Set up applications.
        echo "setting up /Applications..." >&2
        rm -rf /Applications/Nix\ Apps
        mkdir -p /Applications/Nix\ Apps
        find ${env}/Applications -maxdepth 1 -type l -exec readlink -f '{}' \; | while read -r src; do
          app_name=$(basename "$src")
          echo "copying $src" >&2
          ${pkgs.mkalias}/bin/mkalias "$src" "/Applications/Nix Apps/$app_name"
        done
      '';

      # $ darwin-rebuild changelog
      system.stateVersion = 6;

      # The platform the configuration will be used on.
      nixpkgs.hostPlatform = "aarch64-darwin";

      #default mac 


    };
  in
  {
    # Build darwin flake using:
    # $ darwin-rebuild build --flake .#simple
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
            
            # State Version Home Manager
            home.stateVersion = "24.05";

	    home.packages = [
	      pkgs.zsh-powerlevel10k
	      pkgs.meslo-lgs-nf
	    ];

            # Setup Oh My Zsh Disini
            programs.zsh = {
              enable = true;
              enableCompletion = true;
              autosuggestion.enable = true;
              syntaxHighlighting.enable = true;
              
              oh-my-zsh = {
                enable = true;
                plugins = [ "git" "sudo" "docker" "web-search"];
              };

	      initExtra = ''
	      # Load Powerlevel10k dari Nix Store
                source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
                
                # Load config p10k jika file-nya ada (hasil dari p10k configure)
                [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
              '';
            };
          };
        }
      ];
    };
  };
}
