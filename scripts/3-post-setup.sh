#!/usr/bin/env bash
echo -ne "
-------------------------------------------------------------------------
   █████╗ ██████╗  ██████╗██╗  ██╗████████╗██╗████████╗██╗   ██╗███████╗
  ██╔══██╗██╔══██╗██╔════╝██║  ██║╚══██╔══╝██║╚══██╔══╝██║   ██║██╔════╝
  ███████║██████╔╝██║     ███████║   ██║   ██║   ██║   ██║   ██║███████╗
  ██╔══██║██╔══██╗██║     ██╔══██║   ██║   ██║   ██║   ██║   ██║╚════██║
  ██║  ██║██║  ██║╚██████╗██║  ██║   ██║   ██║   ██║   ╚██████╔╝███████║
  ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝   ╚═╝   ╚═╝   ╚═╝    ╚═════╝ ╚══════╝
-------------------------------------------------------------------------
                    Automated Arch Linux Installer
                        SCRIPTHOME: ArchTitus
-------------------------------------------------------------------------

Final Setup and Configurations
"
source ${HOME}/ArchTitus/configs/setup.conf

# Thunderbolt keyboard freezing fix
echo -e '#!/bin/bash\necho 1 > /sys/bus/pci/rescan' > /usr/local/bin/thunderbolt-rescan.sh
chmod +x /usr/local/bin/thunderbolt-rescan.sh
echo 'ACTION=="change", SUBSYSTEM=="thunderbolt", ATTR{authorized}=="1", RUN+="/usr/local/bin/thunderbolt-rescan.sh"' > /etc/udev/rules.d/98-thunderbolt-rescan.rules

curl -LJO https://raw.githubusercontent.com/osandov/osandov-linux/master/scripts/btrfs_map_physical.c
gcc -O2 -o btrfs_map_physical btrfs_map_physical.c
if [[ "${FS}" == "btrfs" ]]; then
  root="LABEL=ROOT"
elif [[ "${FS}" == "luks" ]]; then
  root="/dev/mapper/ROOT"
fi

echo -e "Setting up Grub"
grub-install --efi-directory=/boot ${DISK}
if [[ "${FS}" == "luks" ]]; then
  sed -i "s%GRUB_CMDLINE_LINUX_DEFAULT=\"%GRUB_CMDLINE_LINUX_DEFAULT=\"cryptdevice=UUID=${ENCRYPTED_PARTITION_UUID}:ROOT root=$root %g" /etc/default/grub
fi
if $SWAPFILE; then
  tmp="$(./btrfs_map_physical /swap/swapfile | head -n2 | tail -n1 | awk '{print $6}')"
  sed -i "s|loglevel|resume=$root resume_offset=$tmp loglevel|" /etc/default/grub
fi
rm -f btrfs_map_physical.c btrfs_map_physical
# set kernel parameter for adding splash screen
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& splash /' /etc/default/grub
# Setup theming
THEME_DIR="/boot/grub/themes"
THEME_NAME=arch-silence
mkdir -p "${THEME_DIR}/${THEME_NAME}"
cd ${HOME}/ArchTitus
cp -a configs${THEME_DIR}/${THEME_NAME}/* ${THEME_DIR}/${THEME_NAME}
grep "GRUB_THEME=" /etc/default/grub 2>&1 >/dev/null && sed -i '/GRUB_THEME=/d' /etc/default/grub
echo "GRUB_THEME=\"${THEME_DIR}/${THEME_NAME}/theme.txt\"" >> /etc/default/grub
# Setup multi-boot
if [[ $MULTIBOOT == true ]]; then
  sed -i "s/^GRUB_DISABLE_OS_PROBER=.*|^#GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/" /etc/default/grub
fi
grub-mkconfig -o /boot/grub/grub.cfg

echo -ne "
-------------------------------------------------------------------------
                    Enabling Plymouth Boot Splash
-------------------------------------------------------------------------
"
if  [[ ${FS} == "luks" ]]; then
  sed -i 's/HOOKS=(base udev*/& plymouth/' /etc/mkinitcpio.conf # add plymouth after base udev
  sed -i 's/HOOKS=(base udev \(.*block\) /&plymouth-/' /etc/mkinitcpio.conf # create plymouth-encrypt after block hook
else
  sed -i 's/HOOKS=(base udev*/& plymouth/' /etc/mkinitcpio.conf # add plymouth after base udev
fi
if [[ $AUR_HELPER == none ]]; then # sets the theme and runs mkinitcpio
  plymouth-set-default-theme -R bgrt
else
  plymouth-set-default-theme -R arch-breeze
fi

echo -ne "
-------------------------------------------------------------------------
                    Enabling Login Display Manager
-------------------------------------------------------------------------
"
if [[ "${DESKTOP_ENV}" == "gnome" ]]; then
  systemctl enable gdm.service
elif [[ ${DESKTOP_ENV} == "kde" ]]; then
  systemctl disable sddm.service
  systemctl enable sddm-plymouth.service
elif [[ ${DESKTOP_ENV} == "cosmic" ]]; then
  systemctl enable cosmic-greeter.service
  systemctl enable power-profiles-daemon.service
fi

echo -ne "
-------------------------------------------------------------------------
                    Enabling Essential Services
-------------------------------------------------------------------------
"
systemctl enable cups.service
echo "  Cups enabled"
ntpd -qg
systemctl enable ntpd.service
echo "  NTP enabled"
systemctl enable NetworkManager.service
echo "  NetworkManager enabled"
systemctl enable bluetooth
echo "  Bluetooth enabled"
systemctl enable avahi-daemon.service
echo "  Avahi enabled"
systemctl enable fstrim.timer
echo "  Periodic Trim enabled"
systemctl enable systemd-resolved.service
echo "  Resolvconf enabled"
systemctl enable grub-btrfsd.service
echo "  Grub-btrfs snapshots enabled"

echo -ne "
-------------------------------------------------------------------------
                  Creating Snapper Config
-------------------------------------------------------------------------
"

SNAPPER_CONF="$HOME/ArchTitus/configs/etc/snapper/configs/root"
mkdir -p /etc/snapper/configs/
cp -rfv ${SNAPPER_CONF} /etc/snapper/configs/

SNAPPER_CONF_D="$HOME/ArchTitus/configs/etc/conf.d/snapper"
mkdir -p /etc/conf.d/
cp -rfv ${SNAPPER_CONF_D} /etc/conf.d/

systemctl enable snapper-cleanup.timer
systemctl enable grub-btrfs.path

echo -ne "
-------------------------------------------------------------------------
                    Cleaning
-------------------------------------------------------------------------
"
# Remove no password sudo rights
sed -i 's/^%wheel ALL=(ALL) NOPASSWD: ALL/# %wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
sed -i 's/^%wheel ALL=(ALL:ALL) NOPASSWD: ALL/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
# Add sudo rights
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

if [[ $DESKTOP_ENV != "server" ]]; then
  cp -v /home/$USERNAME/ArchTitus/scripts/4-postboot-setup.sh /home/$USERNAME/ArchTitus/pkg-files/flatpak.txt /home/$USERNAME
  chown $USERNAME:$USERNAME /home/$USERNAME/flatpak.txt /home/$USERNAME/4-postboot-setup.sh
  chmod +x /home/$USERNAME/4-postboot-setup.sh
  if [[ $DESKTOP_ENV != "gnome" ]]; then
    sed -i '/--Gnome only--/,$d' /home/$USERNAME/4-postboot-setup.sh
  elif [[ ${AUR_HELPER} == "none" ]]; then
    sed -i '/--AUR only--/,$d' /home/$USERNAME/4-postboot-setup.sh
  fi
fi
rm -r $HOME/ArchTitus /home/$USERNAME/ArchTitus

# Replace in the same state
cd $pwd
