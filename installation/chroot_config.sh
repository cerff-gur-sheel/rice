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
askpass "Insert root password" root_pass
ask "Insert username" username
askpass "Insert user password" user_pass
echo "Hostname: $hostname"
echo "Username: $username"
echo "Starting installation process..."

### on chroot 

# GRUB
#
echo "[INFO] Configuring GRUB..."
if [ -d /sys/firmware/efi/efivars ]; then
  grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ArchGrub --recheck
else
  grub-install --target=i386-pc /dev/sda
fi
grub-mkconfig -o /boot/grub/grub.cfg
echo "[INFO] GRUB configured"

# TIME
#
echo "[INFO] Setting timezone..."
ln -sf /usr/share/zoneinfo/America/Recife /etc/localtime
timedatectl set-ntp true
hwclock --systohc
echo "[INFO] Generating locale..."
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=br-abnt2" > /etc/vconsole.conf

# HOST
#
echo "[INFO] Setting hostname and hosts..."
echo "$hostname" > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1 localhost" >> /etc/hosts
echo "127.0.1.1 $hostname" >> /etc/hosts
echo "[INFO] Hostname set to $hostname"

# USER AND ROOT
#
echo "[INFO] Creating user $username..."
useradd -m -G wheel -s /bin/fish "$username"
echo "$username:$user_pass" | chpasswd
echo "[INFO] User $username created with specified password."
echo "root:$root_pass" | chpasswd

echo "[INFO] Enabling sudo for wheel group..."
(
  sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
  echo "[INFO] Sudo enabled for wheel group"
)

# ZRAM
#
echo "[INFO] Configuring ZRAM..."
(
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
	echo "[INFO] ZRAM configured"
)

# pacamn
#
echo "[INFO] Configuring Pacman"
(
	pacman-key --init 
	pacman-key --populate archlinux
	pacman -Syyu
	pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
	pacman-key --lsign-key 3056513887B78AEB
	pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
	pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

	cat > /etc/pacman.conf << PACMANCONF
#
# /etc/pacman.conf
#
# See the pacman.conf(5) manpage for option and repository directives

#
# GENERAL OPTIONS
#
[options]
RootDir     = /
DBPath      = /var/lib/pacman/
CacheDir    = /var/cache/pacman/pkg/
LogFile     = /var/log/pacman.log
GPGDir      = /etc/pacman.d/gnupg/
HookDir     = /etc/pacman.d/hooks/
HoldPkg     = pacman glibc
#XferCommand = /usr/bin/curl -L -C - -f -o %o %u
#XferCommand = /usr/bin/wget --passive-ftp -c -O %o %u
CleanMethod = KeepInstalled
Architecture = auto

#
# Ignored Packages
#

#IgnorePkg   =
#IgnoreGroup =

#NoUpgrade   =
#NoExtract   =


#
# Misc options
#

Color
CheckSpace
ParallelDownloads = 15
DownloadUser = alpm
#NoProgressBar
#DisableSandbox
#VerbosePkgLists
#UseSyslog
ILoveCandy

SigLevel    = Required DatabaseOptional
LocalFileSigLevel = Optional

#
# REPOSITORIES
#

[core]
Include = /etc/pacman.d/mirrorlist

[extra]
Include = /etc/pacman.d/mirrorlist

[multilib]
Include = /etc/pacman.d/mirrorlist

#[core-testing]
#Include = /etc/pacman.d/mirrorlist

#[extra-testing]
#Include = /etc/pacman.d/mirrorlist

#[multilib-testing]
#Include = /etc/pacman.d/mirrorlist

[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
	PACMANCONF
	pacman -Syu
	pacman-key --init 
  pacman-key --populate archlinux
	pacman -Syy
)

echo "[INFO] Instaling somethings..."

# graphcs
pacman -Syy mesa vulkan-intel lib32-vulkan-intel

# audio
pacman -Syy pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber alsa-tools alsa-utils

# fonts
pacman -Syy nerd-fonts noto-fonts noto-fonts-emoji

# keyring
pacman -Syy gnome-keyring libsecret gnome-themes-extra

# theming
pacman -Syy nwg-look qt5ct qt6ct

# hyprland
pacman -Syy hyprland waybar wofi hyprpicker hyprlock swww kitty

echo "[INFO] Disabling password for sudo..."
{
  echo "$username ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$username && chmod 440 /etc/sudoers.d/$username
}

echo "[INFO] Installing yay and enabling AUR..."
(
  runuser -u "$username" -- bash -c '
  cd ~
  git clone https://aur.archlinux.org/yay.git
  cd yay
  makepkg -si --noconfirm
  cd ~
  rm -rf yay
  '
)

echo "[INFO] Generating initramfs..."
(
  pacman -Syy --noconfirm linux linux-firmware
  mkinitcpio -P
) 

echo "[INFO] Installing displaylink via yay..."
(
  runuser -u "$username" -- yay -Syy --noconfirm evdi displaylink zen-browser-bin unityhub vesktop-bin visual-studio-code-bin
)

# programs that I use must
pacman -Syy steam telegram-desktop strawberry


echo "[INFO] Enabling essential services..."
(
  systemctl enable NetworkManager
  systemctl enable ly
  systemctl enable displaylink.service
)

echo "[INFO] Setting up rice..."
(
  runuser -u "$username" -- bash -c '
  git clone https://github.com/cerff-gur-sheel/rice.git ~/.config/rice
  ./~/.config/rice/setup.sh
  '
  echo "[INFO] Rice setup completed"
)


echo "[INFO] Setting default shell to fish for root and $username..."
{
  chsh -s /bin/fish root
  chsh -s /bin/fish "$username"
}

echo "[INFO] Removing temporary sudoers file for $username..."
{
  rm -f /etc/sudoers.d/$username
}

