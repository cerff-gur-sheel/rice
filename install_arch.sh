#!/bin/bash
set -e

skip_format=false
clean_disks=false
disk_hdd="/dev/sda"
disk_nvme="/dev/nvme0n1"

show_help() {
    cat <<EOF
Uso: $0 [OPÇÕES]

Opções:
  --skip-format         Pula a formatação e montagem dos discos.
  --clean-disks         Zera os primeiros 100MB dos discos antes da formatação.
  --disk_hdd=DISCO      Define o disco HDD (padrão: /dev/sdb).
  --disk_nvme=DISCO     Define o disco NVMe (padrão: /dev/nvme0n1).
  -h, --help            Exibe esta mensagem de ajuda e sai.

Exemplo:
  $0 --disk_hdd=/dev/sdc --disk_nvme=/dev/nvme1n1 --clean-disks
EOF
}

# Parse argumentos
for arg in "$@"; do
    case $arg in
        -h|--help)
            show_help
            exit 0
            ;;
        --skip-format)
            skip_format=true
            echo "[INFO] Formatação e montagem serão puladas."
            ;;
        --clean-disks)
            clean_disks=true
            echo "[INFO] Os discos serão limpos antes da formatação."
            ;;
        --disk_hdd=*)
            disk_hdd="${arg#*=}"
            echo "[INFO] HDD definido para: $disk_hdd"
            ;;
        --disk_nvme=*)
            disk_nvme="${arg#*=}"
            echo "[INFO] NVMe definido para: $disk_nvme"
            ;;
        *)
            echo "[ERRO] Opção inválida: $arg"
            show_help
            exit 1
            ;;
    esac
done

ask() {
    read -rp "$1: " "$2"
}

echo "[INFO] Solicitação de dados do usuário..."
ask "Digite o nome do host" hostname
ask "Digite o nome do usuário" username
cd ~

if ! $skip_format; then

    if $clean_disks; then
        echo "[INFO] Limpando SSD (NVMe) $disk_nvme..."
        dd if=/dev/zero of=$disk_nvme bs=1M count=100 status=progress
        sync
        echo "[INFO] Limpando HDD $disk_hdd..."
        dd if=/dev/zero of=$disk_hdd bs=1M count=100 status=progress
        sync
        echo "[OK] Limpeza dos discos concluída."
    fi

    echo "[INFO] Iniciando particionamento do SSD (NVMe) $disk_nvme..."
    sgdisk --zap-all $disk_nvme
    sgdisk -n1:0:+512M -t1:ef00 -c1:"EFI System" $disk_nvme
    sgdisk -n2:0:0     -t2:8300 -c2:"Linux root"  $disk_nvme
    partprobe $disk_nvme
    echo "[OK] Particionamento do SSD concluído."

    echo "[INFO] Iniciando particionamento do HDD $disk_hdd..."
    sgdisk --zap-all $disk_hdd
    sgdisk -n1:0:0 -t1:8300 -c1:"Linux data" $disk_hdd
    partprobe $disk_hdd
    echo "[OK] Particionamento do HDD concluído."

    echo "[INFO] Formatando partições..."
    mkfs.fat -F32 ${disk_nvme}p1
    mkfs.btrfs -f ${disk_nvme}p2
    mkfs.ext4 -F ${disk_hdd}1
    echo "[OK] Formatação concluída."

    echo "[INFO] Montando sistemas de arquivos..."
    mount -t btrfs ${disk_nvme}p2 /mnt
    mkdir -p /mnt/boot /mnt/home /mnt/media
    mount ${disk_nvme}p1 /mnt/boot
    mount ${disk_hdd}1 /mnt/home
    mkdir -p /mnt/home/media
    mount --bind /mnt/home/media /mnt/media
    echo "[OK] Montagem concluída."
else
    echo "[INFO] Pulando formatação e montagem conforme solicitado."
fi

echo "[INFO] Instalando pacotes base..."
pacstrap -K /mnt base base-devel linux linux-firmware linux-headers grub efibootmgr fish neovim sudo git btrfs-progs zram-generator networkmanager ly mesa hyprland hyprpaper hyprpicker hyprutils hypridle hyprlock kitty nerd-fonts git gnome-themes-extra wireplumber pipewire-alsa playerctl brightnessctl wl-clipboard jq

echo "[OK] Pacotes instalados."

echo "[INFO] Gerando arquivo fstab..."
# Limpa fstab antes para evitar duplicações em execuções repetidas
> /mnt/etc/fstab
genfstab -U /mnt >> /mnt/etc/fstab

echo -e "\n--- /etc/fstab gerado ---"
cat /mnt/etc/fstab
echo -e "--- Fim do fstab ---\n"

echo "[INFO] Iniciando configuração dentro do chroot..."

arch-chroot /mnt /bin/bash <<EOF
set -e

log() {
    echo "[CHROOT] \$1"
}

log "Configurando fuso horário e relógio..."
ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
hwclock --systohc

log "Gerando localidade..."
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

log "Configurando teclado..."
echo "KEYMAP=br-abnt2" > /etc/vconsole.conf

log "Definindo hostname e hosts..."
echo "$hostname" > /etc/hostname
cat > /etc/hosts <<HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   $hostname.localdomain $hostname
HOSTS

log "Configurando GRUB..."
sed -i 's/^GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX="rootfstype=btrfs"/' /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

log "Criando usuário $username..."
useradd -m -G wheel -s /bin/fish "$username"

log "Definindo senhas para $username e root..."

# Define senha para o usuário
read -s -p "Digite a senha para $username: " user_pass
echo
read -s -p "Confirme a senha para $username: " user_pass_confirm
echo

if [ "$user_pass" != "$user_pass_confirm" ]; then
    echo "As senhas não coincidem. Abortando."
    exit 1
fi

# Define senha para root
read -s -p "Digite a senha para root: " root_pass
echo
read -s -p "Confirme a senha para root: " root_pass_confirm
echo

if [ "$root_pass" != "$root_pass_confirm" ]; then
    echo "As senhas não coincidem. Abortando."
    exit 1
fi

# Aplica as senhas
echo "$username:$user_pass" | chpasswd
echo "root:$root_pass" | chpasswd


log "Configurando sudo para grupo wheel..."
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

log "Gerando initramfs..."
mkinitcpio -P

log "Configurando ZRAM..."
cat > /etc/systemd/zram-generator.conf <<ZRAM
[zram0]
zram-size = ram
compression-algorithm = zstd
ZRAM

log "Instalando yay e habilitando AUR..."

# Clona e instala o yay como o usuário normal
runuser -u "$username" -- bash -c '
cd ~
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
cd ~
rm -rf yay
'

log "Instalando displaylink via yay..."

runuser -u "$username" -- yay -S --noconfirm evdi displaylink

log "displaylink instalado via yay."


log "yay instalado com sucesso."

log "Habilitando repositório Chaotic AUR..."

pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
pacman-key --lsign-key 3056513887B78AEB

pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" >> /etc/pacman.conf

log "Sincronizando pacotes com Chaotic AUR..."
pacman -Syu --noconfirm

log "Habilitando serviços essenciais..."
systemctl enable NetworkManager
systemctl enable ly
systemctl enable displaylink.service 


log "Buscando URL do setup_rice.sh da última release..."

REPO_API="https://api.github.com/repos/cerff-gur-sheel/rice/releases/latest"
DOWNLOAD_URL=$(curl -s $REPO_API | jq -r '.assets[] | select(.name=="setup_rice.sh") | .browser_download_url')

if [[ -z "$DOWNLOAD_URL" ]]; then
    echo "Erro: não foi possível encontrar setup_rice.sh na última release."
    exit 1
fi

log "URL encontrada: $DOWNLOAD_URL"

runuser -u "$username" -- bash -c "
cd ~
curl -LO $DOWNLOAD_URL
chmod +x setup_rice.sh
./setup_rice.sh
rm setup_rice.sh
"

log "Configuração concluída."
EOF

if ! $skip_format; then
    echo "[INFO] Desmontando sistemas de arquivos..."
    umount -R /mnt
    sync
else
    echo "[INFO] Pulando desmontagem de sistemas de arquivos conforme solicitado."
fi

echo "[INFO] Reiniciando sistema..."
reboot

