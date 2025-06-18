#!/bin/bash
set -e 

exec_mode="safe"
home_dev=""
root_dev=""
packs=""

show_help() {
    cat <<EOF
Use: $0 [OPTIONS]

Options:
  -h, --help            Show this help message and exit.

Example:
  $0 
EOF
}

# Parse arguments
for arg in "$@"; do
  case $arg in
  -h | --help)
    show_help
    exit 0
    ;;
  --root-dev=*)
    root_dev="${arg#*=}"
    ;;
  --home-dev=*)
    home_dev="${arg#*=}"
    ;;
  packs=*)
    packs="${arg#*=}"
    ;;
  *)
    echo "[ERROR] Invalid option: $arg"
    show_help
    exit 1
    ;;
  esac
done

hostname=""
username=""
user_pass=""
root_pass=""

ask() {
  read -rp "$1: " "$2"
}

askpass() {
  while true; do
    read -s -p "$1: " "$2"
    echo
    read -s -p "Confirm $1: " confirm_pass
    echo
    if [ "$confirm_pass" = "${!2}" ]; then
      break
    else
      echo "[ERROR] Passwords do not match. Please try again."
    fi
  done
}

ask "Insert hostname" hostname
ask "Insert username" username
askpass "Insert user password" user_pass
askpass "Insert root password" root_pass

echo "[INFO] User data collected successfully."
if [ "$exec_mode" == "safe" ]; then
  echo "[INFO] Safe mode is enabled. No disk operations will be performed."
  else
  echo "[INFO] Proceeding with disk operations..."
  genfstab -U /mnt >> /mnt/etc/fstab
fi

<<PACKGS
linux
linux-firmware
linux-headers
grub
efibootmgr
os-prober
btrfs-progs
base
base-devel
fish
neovim
sudo
git
zram-generator
networkmanager
ly
mesa
hyprland
hyprpaper
hyprpicker
hyprutils
hypridle
hyprlock
kitty
nerd-fonts
gnome-themes-extra
wireplumber
pipewire-alsa
playerctl
brightnessctl
wl-clipboard
jq
PACKGS

<<ADDITIONAL_PACKAGES
$packs
ADDITIONAL_PACKAGES

pacstrap -K /mnt $PACKGS $ADDITIONAL_PACKAGES

timezone(){
  ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
  hwclock --systohc
}

locales(){
  echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
  locale-gen
  echo "LANG=en_US.UTF-8" > /etc/locale.conf
  echo "KEYMAP=br-abnt2" > /etc/vconsole.conf
}

grub(){
  sed -i 's/^GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX="rootfstype=btrfs"/' /etc/default/grub
  grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
  grub-mkconfig -o /boot/grub/grub.cfg
}

zram(){
  cat > /etc/systemd/zram-generator.conf <<ZRAM
[zram0]
zram-size = min(ram, 8192) + max(ram / 4, 2048)
compression-algorithm = lz4 zstd (threshold=3000)
ZRAM
  cat > /etc/sysctl.d/99-memory.conf <<SYSCTL
# These settings are meant to be used with ZRAM with LZ4 + ZSTD compression.
# Tested on different real hardware combinations (between 2GB and 64GB RAM).
# Author: Myghi63

# Increased swappiness ensures earlier use of swap space (which is fast with ZRAM).
# You can increase this value up to 200 to get better compression, at the cost of more CPU cycles.
vm.swappiness=100

# Higher values can improve system responsiveness and decrease write operations to the disk.
# Lower values helps to deal with too much memory pressure.
vm.dirty_ratio=10
vm.dirty_background_ratio=5

# Reduce inode/dentry caching to prioritize active memory. Higher values = more aggressive cache drop.
# Decrease this value to 80 or a bit less when dealing with slow storage drives.
vm.vfs_cache_pressure=200

# Prevent thrashing and system lockups by freeing memory earlier.
vm.watermark_scale_factor=200
vm.watermark_boost_factor=100

# Keep at least 200MB of free RAM in order to avoid freezes.
vm.min_free_kbytes=204800

# Prevent page-cluster read-ahead (which massively slows ZRAM performance).
vm.page-cluster=0

# Needed for large apps and modern games to avoid mmap failures.
vm.max_map_count=1048576

# References:
# www.kernel.org/doc/html/latest/admin-guide/sysctl/vm.html
# wiki.archlinux.org/title/Zram#Optimizing_swap_on_zram
# www.reddit.com/r/linux_gaming/comments/vla9gd/comment/ie1cnrh/
# www.reddit.com/r/linux/comments/3h7w8f/better_linux_disk_caching_performance_with/
SYSCTL
}

aur(){
  runuser -u "$username" -- bash -c '
  cd ~
  git clone https://aur.archlinux.org/yay.git
  cd yay
  makepkg -si --noconfirm
  cd ~
  rm -rf yay
  '
}

rice(){
  runuser -u "$username" -- bash -c '
  git clone https://github.com/cerff-gur-sheel/rice.git
  cd rice
  ./setup_rice.sh
  cd ~
  rm -rf rice
  '
}

arch-chroot /mnt /bin/bash <<ARCHROOT
#!/bin/bash
set -e
log() {
  echo "[INFO] \$1"
}

log "Configuring timezone and clock..."
timezone

log "Generating locale..."
locales

log "Setting hostname and hosts..."
echo "$hostname" > /etc/hostname
log "Configuring GRUB..."
grub
log "Creating user $username..."
useradd -m -G wheel -s /bin/fish "$username"
log "Setting passwords for $username and root..."
echo "$username:$user_pass" | chpasswd
echo "root:$root_pass" | chpasswd
log "Enabling sudo for wheel group..."
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
log "Configuration completed successfully."

log "Generating initramfs..."
mkinitcpio -P

log "Configuring ZRAM..."
zram

log "Installing yay and enabling AUR..."
aur
log "Installing displaylink via yay..."
runuser -u "$username" -- yay -S --noconfirm evdi displaylink

log "Habilitando serviços essenciais..."
systemctl enable NetworkManager
systemctl enable ly
systemctl enable displaylink.service 

rice
log "Rice setup completed."

echo "You can now exit the chroot environment and reboot."
exit 0
ARCHROOT