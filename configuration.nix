# initial configuration nix
# to fullfill packer steps
# https://github.com/nh2/nixos-ami-building
{ config, modulesPath, lib, pkgs, ... }:
{

  imports = [
    "${modulesPath}/virtualisation/amazon-image.nix"
    #import-placeholder
    {

      # NVIDIA
      # ------

      # enable unfree packages like the nvidia driver
      nixpkgs.config.allowUnfree = true;

      # enable the nvidia driver
      services.xserver.videoDrivers = [ "nvidia" ];
      hardware.opengl.enable = true;

      # > nix repl
      # nix-repl> :l <nixpkgs>
      # nix-repl> pkgs.linuxPackages.nvidea <TAB>

      # g3 uses NVIDIA Tesla M60 GPUs
      # (https://aws.amazon.com/ec2/instance-types/g3/)
      # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/os-specific/linux/nvidia-x11/default.nix < list of versions
      # https://www.nvidia.de/Download/index.aspx?lang=de < find driver
      hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.production;

      # CUDA setup.
      environment.systemPackages = [
        pkgs.cudatoolkit
      ];

    }
    {

      # enable docker
      # -------------
      virtualisation.docker.enable = true;
      virtualisation.docker.enableNvidia = true;
      hardware.opengl.driSupport32Bit = true;

      environment.systemPackages = [
        pkgs.docker-compose
      ];
    }
    {
      # netdata
      # -------
      networking.firewall.allowedTCPPorts = [ 19999 ];
      services.netdata = {
        config = {
          global = {
            "memory mode" = "ram";
            "debug log" = "none";
            "access log" = "none";
            "error log" = "syslog";
          };
        };
      };
    }
  ];

  ec2.hvm = true;
  system.stateVersion = "22.05";

  environment.systemPackages = [
    pkgs.curl
    pkgs.git
    pkgs.htop
    pkgs.vim
    pkgs.wget
    pkgs.silver-searcher
    pkgs.zip
  ];

  environment.variables.EDITOR = "vim";

}
