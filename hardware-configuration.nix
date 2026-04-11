{ config, lib, pkgs, modulesPath, ... }:

{ fileSystems."/boot" = {
   device = "/dev/disk/by-uuid/E440-B5Z4";
   fsType = "vfat";
 };
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/7aeaf90d-be67-4da3-baad-001f00c6a6b1";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/E440-B5Z4";
    fsType = "vfat";
    options = [ "umask=0077" ];
  };

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];

  boot.initrd.kernelModules = [ ];

  boot.kernelModules = [ ];

  boot.supportedFilesystems = [ "ext4" "vfat" ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
}
