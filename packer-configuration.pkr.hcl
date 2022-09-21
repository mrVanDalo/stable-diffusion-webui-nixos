# inspired by
# https://github.com/nh2/nixos-ami-building

locals {
  region  = "us-west-2" # for the moment
  workdir = "/srv/stable-diffusion"
}

packer {
  required_plugins {
    amazon = {
      version = ">= 0.0.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "nixos" {
  ami_name        = "automatic1111-stable-diffusion-${formatdate("YYYY-MM-DD'T'hh_mm", timestamp())}"
  region          = local.region
  instance_type   = "g5.xlarge" # needs a NVIDIA card
  ami_description = <<-EOF
  ui on port 80;
  netdata on port 19999;
  /outputs to download files;
  use g5.xlarge instance type;
  EOF

  source_ami_filter {
    filters = {
      architecture = "x86_64"
      name         = "NixOS-22.05*"
    }
    most_recent = true
    owners      = ["080433136561"]
  }

  ssh_username = "root"
  ssh_timeout  = "5m" # because we restart the machine
  #ssh_keypair_name = "palo" # to work with --on-error=abort
  #ssh_agent_auth   = true   # to work with --on-error=abort

  launch_block_device_mappings {
    device_name           = "/dev/xvda"
    volume_size           = 30
    volume_type           = "gp2"
    delete_on_termination = true
  }

  run_volume_tags = {
    cost    = "ami"
    project = "stable-diffusion"
  }
  run_tags = {
    cost    = "ami"
    project = "stable-diffusion"
  }
  tags = {
    Name    = "automatic1111-stable-diffusion-${formatdate("YYYY-MM-DD'T'hh_mmZZZZ", timestamp())}"
    cost    = "ami"
    project = "stable-diffusion"
  }
  snapshot_tags = {
    Name    = "automatic1111-stable-diffusion-${formatdate("YYYY-MM-DD'T'hh_mmZZZZ", timestamp())}"
    cost    = "ami"
    project = "stable-diffusion"
  }

}

build {
  name    = "setup-stable-diffusion-resources"
  sources = ["source.amazon-ebs.nixos"]

  # setup nixos
  # -----------
  provisioner "file" {
    source      = "configuration.nix"
    destination = "/etc/nixos/"
  }

  provisioner "shell" {
    inline = [
      "nixos-rebuild boot --upgrade",
      "shutdown -r now || true" # reboot
    ]
    expect_disconnect = true
  }

  # init
  # ----
  provisioner "shell" {
    inline = [
      "git clone https://github.com/AbdBarho/stable-diffusion-webui-docker.git ${local.workdir}",
      "cd ${local.workdir}",
      "docker compose --profile download up --build",
    ]
  }

  # install all services and cleanup
  # --------------------------------
  provisioner "file" {
    source      = "configuration-ui.nix"
    destination = "/etc/nixos/"
  }
  provisioner "shell" {
    inline = [
      "sed --in-place=$ --regexp-extended 's$#import-placeholder$./configuration-ui.nix$' /etc/nixos/configuration.nix",
      "nixos-rebuild boot --upgrade",
      "df -h",
      "nix-collect-garbage -d",
      "df -h",
      "rm -rf /etc/ec2-metadata /etc/ssh/ssh_host_* /root/.ssh",
    ]
  }

}

