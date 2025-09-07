{
  description = "An aria2 Exporter for Prometheus";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    {
      self,
      nixpkgs,
      ...
    }@inputs:
    let
      inherit (self) outputs;
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: (forSystem system f));
      forSystem =
        system: f:
        f rec {
          inherit system;
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
          };
          lib = pkgs.lib;
        };
    in
    {
      overlays.default = final: prev: {
        aria2_exporter = final.buildGoModule rec {
          name = "aria2_exporter";
          src = self;
          subPackages = [ "." ];
          vendorHash = "sha256-AZWUTXp68fwqISxW26WQKtsuvO5b145P2K6pkTTuLoA=";
          doCheck = false;
        };
      };

      nixosModules.aria2_exporter = {
        imports = [ ./module.nix ];
        nixpkgs.overlays = [
          self.overlays.default
        ];
      };

      devShells = forAllSystems (
        { system, pkgs, ... }:
        {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              go
              gopls
            ];
          };
        }
      );

      checks = forAllSystems (
        { system, pkgs, ... }:
        {
          integration-test = pkgs.testers.runNixOSTest ./test.nix;
        }
      );

      packages = forAllSystems (
        { system, pkgs, ... }:
        {
          inherit (pkgs) aria2_exporter;
        }
      );

      hydraJobs = {
        integration-test = builtins.mapAttrs (_: value: value) outputs.checks;
        build = builtins.mapAttrs (_: value: value) outputs.packages;
      };
    };
}
