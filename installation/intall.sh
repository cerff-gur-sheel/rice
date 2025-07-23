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

pacstrap -K /mnt base base-devel linux linux-firmware linux-headers btrfs-progs grub efibootmgr zram-generator networkmanager git 
genfstab -U /mnt >> /mnt/etc/fstab

cp ~/rice/installation/chroot_config.sh /mnt/chroot_config.sh
arch-chroot /mnt << CHROOT
cd /
chmod +x /chroot_config.sh
./chroot_config.sh
rm -rf chroot_config.sh
CHROOT
