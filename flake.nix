{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    colmena.url = "github:zhaofengli/colmena";
    terranix = {
      url = "github:terranix/terranix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs-fmt = {
      url = "github:nix-community/nixpkgs-fmt";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs =
    { self
    , colmena
    , flake-utils
    , nixpkgs
    , nixpkgs-fmt
    , nixpkgs-unstable
    , terranix
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      ssh-key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC6uza62+Go9sBFs3XZE2OkugBv9PJ7Yv8ebCskE5WYPcahMZIKkQw+zkGI8EGzOPJhQEv2xk+XBf2VOzj0Fto4nh8X5+Llb1nM+YxQPk1SVlwbNAlhh24L1w2vKtBtMy277MF4EP+caGceYP6gki5+DzlPUSdFSAEFFWgN1WPkiyUii15Xi3QuCMR8F18dbwVUYbT11vwNhdiAXWphrQG+yPguALBGR+21JM6fffOln3BhoDUp2poVc5Qe2EBuUbRUV3/fOU4HwWVKZ7KCFvLZBSVFutXCj5HuNWJ5T3RuuxJSmY5lYuFZx9gD+n+DAEJt30iXWcaJlmUqQB5awcB1S2d9pJ141V4vjiCMKUJHIdspFrI23rFNYD9k2ZXDA8VOnQE33BzmgF9xOVh6qr4G0oEpsNqJoKybVTUeSyl4+ifzdQANouvySgLJV/pcqaxX1srSDIUlcM2vDMWAs3ryCa0aAlmAVZIHgRhh6wa+IXW8gIYt+5biPWUuihJ4zGBEwkyVXXf2xsecMWCAGPWPDL0/fBfY9krNfC5M2sqxey2ShFIq+R/wMdaI7yVjUCF2QIUNiIdFbJL6bDrDyHnEXJJN+rAo23jUoTZZRv7Jq3DB/A5H7a73VCcblZyUmwMSlpg3wos7pdw5Ctta3zQPoxoAKGS1uZ+yTeZbPMmdbw==";
      terraform = pkgs.writers.writeBashBin "terraform" ''
        export AWS_ACCESS_KEY_ID=`${pkgs.pass}/bin/pass development/aws/access_id`
        export AWS_SECRET_ACCESS_KEY=`${pkgs.pass}/bin/pass development/aws/secret_key`
        export TF_VAR_MY_IP=`curl https://checkip.amazonaws.com`"/32"
        ${pkgs.terraform}/bin/terraform "$@"
      '';
      packer = pkgs.writers.writeBashBin "packer" ''
        export AWS_ACCESS_KEY_ID=`${pkgs.pass}/bin/pass development/aws/access_id`
        export AWS_SECRET_ACCESS_KEY=`${pkgs.pass}/bin/pass development/aws/secret_key`
        ${pkgs.packer}/bin/packer "$@"
      '';
      steampipe = pkgs.writers.writeBashBin "steampipe" ''
        export AWS_ACCESS_KEY_ID=`${pkgs.pass}/bin/pass development/aws/access_id`
        export AWS_SECRET_ACCESS_KEY=`${pkgs.pass}/bin/pass development/aws/secret_key`
        ${pkgs.steampipe}/bin/steampipe "$@"
      '';
      nixfmt = nixpkgs-fmt.defaultPackage.${system};
      terraformConfiguration = terranix.lib.terranixConfiguration {
        inherit system;
        extraArgs = { };
        modules = [ ./terranix-configuration.nix ];
      };
    in
    {
      # shells
      # ------
      devShells.${system} = {
        default = pkgs.mkShell {
          buildInputs = [
            terraform
            packer
            steampipe
            terranix.defaultPackage.${system}
          ];
        };
      };

      apps.${system} = {

        # packer
        # ------

        # nix run ".#build"
        build = {
          type = "app";
          program = toString (pkgs.writers.writeBash "build" ''
            ${packer}/bin/packer build .
          '');
        };

        # terranix
        # --------

        # nix run
        default = {
          type = "app";
          program = toString (pkgs.writers.writeBash "default" ''
            cat ${terraformConfiguration} | ${pkgs.jq}/bin/jq
          '');
        };
        # nix run ".#apply"
        apply = {
          type = "app";
          program = toString (pkgs.writers.writeBash "apply" ''
            if [[ -e config.tf.json ]]; then rm -f config.tf.json; fi
            cp ${terraformConfiguration} config.tf.json \
              && ${terraform}/bin/terraform init \
              && ${terraform}/bin/terraform apply
          '');
        };
        # nix run ".#destroy"
        destroy = {
          type = "app";
          program = toString (pkgs.writers.writeBash "destroy" ''
            if [[ -e config.tf.json ]]; then rm -f config.tf.json; fi
            cp ${terraformConfiguration} config.tf.json \
              && ${terraform}/bin/terraform init \
              && ${terraform}/bin/terraform destroy
          '');
        };

        log = self.apps.${system}.logs;
        logs =
          let
            ip = (import ./configuration-target.nix).deployment.targetHost;
          in
          {
            type = "app";
            program = toString (pkgs.writers.writeBash "logs" ''
              ssh root@${ip} journalctl -f -n 100
            '');
          };

        log-ui = self.apps.${system}.logs-ui;
        logs-ui =
          let
            ip = (import ./configuration-target.nix).deployment.targetHost;
          in
          {
            type = "app";
            program = toString (pkgs.writers.writeBash "logs" ''
              ssh root@${ip} journalctl -u stable-diffusion-ui -f -n 100
            '');
          };

        nvidia = self.apps.${system}.nvidia-stats;
        nvidia-stats =
          let
            ip = (import ./configuration-target.nix).deployment.targetHost;
          in
          {
            type = "app";
            program = toString (pkgs.writers.writeBash "nvidia-stats" ''
              watch -n 10 ssh root@${ip} nvidia-smi
            '');
          };

        harvest = self.apps.${system}.download-images;
        download-images =
          let
            ip = (import ./configuration-target.nix).deployment.targetHost;
          in
          {
            type = "app";
            program = toString (pkgs.writers.writeBash "download-images" ''
              mkdir -p ~/Pictures/Darktable/stable-diffusion/
              rsync \
                --append \
                -avz  \
                root@${ip}:/srv/stable-diffusion/output/ \
                ~/Pictures/Darktable/stable-diffusion/
            '');
          };

        restart =
          let
            ip = (import ./configuration-target.nix).deployment.targetHost;
          in
          {
            type = "app";
            program = toString (pkgs.writers.writeBash "restart-service" ''
              ssh root@${ip} systemctl restart stable-diffusion-ui
            '');
          };

        # nix run ".#fmt"
        fmt = {
          type = "app";
          program = toString (pkgs.writers.writeBash "fmt" ''
            ${packer}/bin/packer fmt .
            ${nixfmt}/bin/nixpkgs-fmt .
          '');
        };

      };

      # provisioning
      # ------------
      colmena = {
        meta = {
          specialArgs = { inherit ssh-key; };
          nixpkgs = import nixpkgs {
            inherit system;
            overlays = [
              (_self: _super: {
                # we assign the overlay created before to the overlays of nixpkgs.
                unstable = nixpkgs-unstable.legacyPackages.${pkgs.system};
              })
            ];
          };
        };
        gpu-monster = {
          imports = [
            ./configuration-target.nix
            ./configuration-ui.nix
            ./configuration.nix
          ];
        };
      };
    };
}
