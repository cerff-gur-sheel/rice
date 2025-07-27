#!/bin/bash

DEVICE=""

# Parse da flag --device
for arg in "$@"; do
  case $arg in
    --device=*)
      DEVICE="${arg#*=}"
      shift
      ;;
    *)
      echo "Uso: $0 --device=/dev/sdX"
      exit 1
      ;;
  esac
done

if [[ -z "$DEVICE" ]]; then
  echo "Erro: você deve fornecer --device=/dev/sdX"
  exit 1
fi


	# Criação das partições
echo "$DEVICE partitions created"
(
	parted "$DEVICE" --script \
		mklabel gpt \
		mkpart ESP fat32 1MiB 513MiB \
		set 1 esp on \
		mkpart primary ext4 513MiB 220GiB \
		mkpart primary ext4 220GiB 919GiB
)

# Define as partições
EFI_DEV="${DEVICE}1"
ROOT_DEV="${DEVICE}2"
HOME_DEV="${DEVICE}3"

# Formatações
echo "formating devices" 
(
	mkfs.fat -F32 "$EFI_DEV"
	mkfs.btrfs -f "$ROOT_DEV"
	mkfs.btrfs -f "$HOME_DEV"
)
# Montagem e criação dos subvolumes

echo "mouting partitions ..."
(
	# root
	mount "$ROOT_DEV" /mnt
	btrfs subvolume create /mnt/@
	umount /mnt

	# home
	mount "$HOME_DEV" /mnt
	btrfs subvolume create /mnt/@home
	umount /mnt

	# monting all
	mount -o noatime,compress=zstd,subvol=@ "$ROOT_DEV" /mnt
	mount --mkdir -o noatime,compress=zstd,subvol=@home "$HOME_DEV" /mnt/home
	mount --mkdir "$EFI_DEV" /mnt/boot
)

echo "[INFO] Configuring Pacman"
(
	pacman-key --init 
	pacman-key --populate archlinux
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
	PACMANCONF
	pacman -Syu
	pacman-key --init 
  pacman-key --populate archlinux
	pacman -Syy
)

pacstrap -K /mnt base base-devel linux linux-firmware linux-headers \
	btrfs-progs grub efibootmgr zram-generator networkmanager git \
	mesa vulkan-intel lib32-vulkan-intel \
	pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber \
	alsa-tools alsa-utils \
	nerd-fonts noto-fonts noto-fonts-emoji \
	gnome-keyring libsecret gnome-themes-extra \
	nwg-look qt5ct qt6ct \
	hyprland waybar wofi hyprpicker hyprlock swww kitty fish wl-clipboard \
	steam telegram-desktop strawberry btop ly \
	nemo nemo-fileroller nemo-preview nemo-seahorse nemo-share nemo-terminal \
	krita opentabletdriver 

genfstab -U /mnt >> /mnt/etc/fstab

cp ~/rice/installation/chroot_config.sh /mnt/chroot_config.sh
arch-chroot /mnt << CHROOT
cd /
chmod +x /chroot_config.sh
./chroot_config.sh
rm -rf chroot_config.sh
CHROOT
