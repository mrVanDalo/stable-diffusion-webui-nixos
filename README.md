Set up an AWS machine to with stable diffusion.

# How to build

```shell
packer init .
packer build . 
```

This creates an AMI which contains the model already and all the stable-diffusion installation.
You should be able to start this AMI and under port 80 you are ready to go.

# How to Deploy

```shell
nix run ".#apply"
git add . 
colmena apply -v
```

# How to Destroy

```shell
nix run ".#destroy"
```


# Useful commands

```shell
nix run ".#harvest" # download all images to ~/Pictures/Darktable
nix run ".logs"     # shows logs
nix run ".nvidia"   # shows nvidia-smi
```

