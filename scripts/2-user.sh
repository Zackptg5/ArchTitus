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

Installing AUR Softwares
"
source $HOME/ArchTitus/configs/setup.conf

cd ~
mkdir "/home/$USERNAME/.cache"
touch "/home/$USERNAME/.cache/zshhistory"
git clone "https://github.com/ChrisTitusTech/zsh"
# Zsh doesn't read inputrc and so some keys like 'del' won't work right. Add keybindings
echo "$(sed -n 's/^/bindkey /; s/: / /p' /etc/inputrc)" >> zsh/.zshrc
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k
ln -s ~/zsh/.zshrc ~/.zshrc
sudo chsh -s $(which zsh) $(whoami) 
# Change editor to nano
sed -i "s/EDITOR=.*/EDITOR=nano/" zsh/.zshrc
sed -i "s/EDITOR=.*/EDITOR=nano/" zsh/aliasrc

# Install DE
sudo pacman -S --noconfirm --needed - < $HOME/ArchTitus/pkg-files/${DESKTOP_ENV}.txt
if [[ $DESKTOP_ENV == "gnome" ]] && [[ ${AUR_HELPER} == "pamac" ]]; then
  sudo pacman -Rdd --noconfirm gnome-software
fi

# Add Chaotic AUR
echo "Adding Chaotic AUR"
sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
sudo pacman-key --lsign-key 3056513887B78AEB
sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
sudo bash -c "echo -e \"[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\" >> /etc/pacman.conf"
sudo pacman -Sy
sudo pacman -S --noconfirm --needed - < $HOME/ArchTitus/pkg-files/chaoticaur-pkgs.txt

if [[ -f "$HOME/ArchTitus/pkg-files/${DESKTOP_ENV}-chaoticaur.txt" ]]; then
  sudo pacman -S --noconfirm --needed - < $HOME/ArchTitus/pkg-files/${DESKTOP_ENV}-chaoticaur.txt
fi

if [[ ${AUR_HELPER} != "none" ]]; then

  # Debug symbols take forever, don't bother
  debug_workaround() {
    mkdir temp
    cd temp
    yay -G - < $1
    sed -i "s/\!strip')/\!strip' '\!debug')/" */PKGBUILD
    for i in *; do
      cd $i
      makepkg -si --noconfirm --needed
      cd ..
    done
    cd ..
    rm -rf temp
  }

  sudo pacman -S yay --noconfirm --needed # Use yay temporarily - pamac doesn't work right during install
  if [[ ${AUR_HELPER} == "pamac" ]]; then
    sudo pacman -Rdd --noconfirm archlinux-appstream-data
    sudo pacman -S --noconfirm archlinux-appstream-data-pamac pamac-nosnap # Replace default with pamac
  fi
  # yay -S --noconfirm --needed - < $HOME/ArchTitus/pkg-files/aur-pkgs.txt
  debug_workaround $HOME/ArchTitus/pkg-files/aur-pkgs.txt
  mkdir -p $HOME/.ICAClient/cache
  cp /opt/Citrix/ICAClient/config/{All_Regions,Trusted_Region,Unknown_Region,canonicalization,regions}.ini $HOME/.ICAClient/
  if [[ -f "$HOME/ArchTitus/pkg-files/${DESKTOP_ENV}-aur.txt" ]]; then
    # yay -S --noconfirm --needed - < $HOME/ArchTitus/pkg-files/${DESKTOP_ENV}-aur.txt
    debug_workaround $HOME/ArchTitus/pkg-files/${DESKTOP_ENV}-aur.txt
  fi

  # Add advcpmv alias
  sed -i -e "s/alias cp=.*/alias cp='advcp -g'/" -e "s/alias mv=.*/alias mv='advmv -g'/" ~/zsh/aliasrc

  sudo ln -sf /usr/share/plymouth/themes/arch-breeze/logo_symb_blue.png /usr/share/plymouth/themes/arch-breeze/logo.png
fi

# Install virtualization packages if chosen
if [[ $VIRT == "true" ]]; then
  sudo pacman -S --noconfirm --needed - < $HOME/ArchTitus/pkg-files/virtualization.txt
fi

# Theming DE
export PATH=$PATH:~/.local/bin
if [[ ${DESKTOP_ENV} == "kde" ]]; then
  sudo ln -sf /usr/share/plymouth/themes/arch-breeze/logo_symb_white.png /usr/share/plymouth/themes/arch-breeze/logo.png
  pip install konsave
  konsave -i ~/ArchTitus/configs/kde.knsv
  sleep 1
  konsave -a kde
fi

# Firefox touchscreen scrolling fix
[ -f /etc/security/pam_env.conf ] && sudo bash -c 'echo "MOZ_USE_XINPUT2 DEFAULT=1" >> /etc/security/pam_env.conf' || sudo bash -c 'echo "MOZ_USE_XINPUT2 DEFAULT=1" >> /usr/share/security/pam_env.conf'

echo -ne "
-------------------------------------------------------------------------
                    SYSTEM READY FOR 3-post-setup.sh
-------------------------------------------------------------------------
"
exit
