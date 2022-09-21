{ config, lib, pkgs, ... }:
{

  networking.firewall.allowedTCPPorts = [ 80 ];
  networking.firewall.allowedUDPPorts = [ 80 ];

  services.netdata.enable = true;

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    virtualHosts = {
      "stable-diffusion.example.com" = {
        default = true;
        locations."/" = {
          proxyPass = "http://localhost:7860";
          proxyWebsockets = true;
        };
        locations."/outputs".return = "301 /output";
        locations."/output" = {
          root = "/srv/stable-diffusion/";
          extraConfig = ''
            autoindex on;
            autoindex_exact_size off;
          '';
        };
      };
    };
  };


  systemd.services.stable-diffusion-ui-output-generator = {
    enable = true;
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.jq pkgs.coreutils pkgs.mustache-go ];
    script =
      let
        template = pkgs.writeText "template" ''
          <html>
          <body>
          {{#entries}}
            <a href="/output/{{path}}"><img src="/output/{{path}}"></img></a>
          {{/entries}}
          </body></html>
        '';
      in
      ''
        find /srv/stable-diffusion/output -type f \( -iname \*.jpg -o -iname \*.png \) \
            -printf '{"time":"%T@","path":"%P"}\n' | \
            jq --slurp 'sort_by(.time) | reverse' | jq '{entries:.[:30]}' > /srv/last.json
        mustache /srv/last.json ${template} > /srv/stable-diffusion/output/latest-gallery.html
      '';
    serviceConfig = {
      Restart = "always";
      RestartSec = 10;
    };
  };

  systemd.services.stable-diffusion-ui = {
    enable = true;
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.docker ];

    serviceConfig = {
      ExecStart = pkgs.writers.writeDash "stable-diffusion-start" ''
        cd /srv/stable-diffusion
        docker compose --profile auto up --build
      '';
      Type = "oneshot";
    };

  };

}
