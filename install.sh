#!/bin/bash
set -e

DISK="/dev/nvme0n1"   # ⚠️ Укажи свой диск: /dev/sda, /dev/nvme0n1 и т.д.
HOSTNAME="archlinux"
USERNAME="user"
PASSWORD="1234"

echo "[1/12] Включение NTP"
timedatectl set-ntp true

echo "[2/12] Очистка диска и создание разделов (4 ГБ EFI)"
wipefs -a "$DISK"
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart ESP fat32 1MiB 4097MiB
parted -s "$DISK" set 1 esp on
parted -s "$DISK" mkpart primary ext4 4097MiB 100%

EFI="${DISK}p1"
ROOT="${DISK}p2"

echo "[3/12] Форматирование разделов"
mkfs.fat -F32 "$EFI"
mkfs.ext4 "$ROOT"

echo "[4/12] Монтирование"
mount "$ROOT" /mnt
mkdir -p /mnt/boot/efi
mount "$EFI" /mnt/boot/efi

echo "[5/12] Установка базовой системы"
pacstrap /mnt base base-devel linux linux-firmware vim sudo grub efibootmgr networkmanager git --noconfirm

echo "[6/12] Генерация fstab"
genfstab -U /mnt >> /mnt/etc/fstab

echo "[7/12] Настройка системы в chroot"
arch-chroot /mnt /bin/bash <<EOF
ln -sf /usr/share/zoneinfo/Europe/Kyiv /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1   localhost" >> /etc/hosts
echo "::1         localhost" >> /etc/hosts
echo "127.0.1.1   $HOSTNAME.localdomain $HOSTNAME" >> /etc/hosts

echo "root:$PASSWORD" | chpasswd

useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers

systemctl enable NetworkManager

echo "[8/12] Установка GRUB"
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

echo "[9/12] Клонирование HyDE"
sudo -u $USERNAME git clone --depth 1 https://github.com/HyDE-Project/HyDE /home/$USERNAME/HyDE
chown -R $USERNAME:$USERNAME /home/$USERNAME/HyDE
EOF

echo "[10/12] Готово!"
echo "[11/12] Размонтирование"
umount -R /mnt

echo "[12/12] Перезагрузка"
reboot
