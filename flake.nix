{
  description = "diffusers: version-bumped ahead of nixpkgs through a Python package overlay.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    flake-lib = {
      url = "github:jgus/flake-lib/v1";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
    huggingface-hub = {
      url = "github:jgus/huggingface-hub-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
      inputs.flake-lib.follows = "flake-lib";
    };
  };

  outputs = { nixpkgs, flake-utils, flake-lib, huggingface-hub, ... }:
    let
      pin = import ./pin.nix;
      inherit (pin) version hash;
      source = { type = "pypi"; pname = "diffusers"; format = "sdist"; };
      diffusersOverlay = final: prev: {
        pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
          (pyfinal: pyprev: {
            diffusers = pyprev.diffusers.overridePythonAttrs (old: {
              inherit version;
              doCheck = false;
              dependencies = final.lib.filter
                (dependency: (dependency.pname or null) != "huggingface-hub")
                (old.dependencies or [ ]) ++ [
                pyfinal.huggingface-hub
              ];
              src = pyfinal.fetchPypi { inherit version hash; pname = "diffusers"; };
            });
          })
        ];
      };
      overlay = nixpkgs.lib.composeManyExtensions [
        huggingface-hub.overlays.default
        diffusersOverlay
      ];
    in
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ overlay ];
          };
        in
        {
          packages = {
            diffusers = pkgs.python3.pkgs.diffusers;
            default = pkgs.python3.pkgs.diffusers;
            update-version = flake-lib.lib.mkUpdateVersion {
              inherit pkgs source;
              buildAttr = "diffusers";
              siblings = [
                {
                  reqName = "huggingface-hub";
                  pypiName = "huggingface-hub";
                  flakeRepo = "jgus/huggingface-hub-flake";
                  mode = "resolve";
                }
              ];
              siblingRefsInPin = true;
            };
            update-branches = flake-lib.lib.mkUpdateBranches { inherit pkgs source; pinSchema = "pypi"; };
          };
        }) // {
      overlays.default = overlay;
    };
}
