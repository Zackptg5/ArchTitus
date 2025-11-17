#!/usr/bin/env bash
echo "Installing flatpak packages"
sudo pacman -S --noconfirm --needed flatpak
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
while read -r line; do
  pkg="$(echo $line | awk '{print $1}')"
  name="$(echo $line | awk '{print $2}')"
  echo "INSTALLING: $name"
  sudo flatpak install flathub $pkg -y
done < ~/flatpak.txt

# Easyeffects Profiles
echo 1 | bash -c "$(curl -fsSL https://raw.githubusercontent.com/JackHack96/PulseEffects-Presets/master/install.sh)"

# --Gnome only--
sudo flatpak install flathub "io.github.realmazharhussain.GdmSettings" -y

# Enable extensions
echo "Making gnome tweaks"
#gnome-extensions enable auto-move-windows@gnome-shell-extensions.gcampax.github.com
gnome-extensions enable drive-menu@gnome-shell-extensions.gcampax.github.com
gnome-extensions enable places-menu@gnome-shell-extensions.gcampax.github.com
gnome-extensions enable system-monitor@gnome-shell-extensions.gcampax.github.com
#gnome-extensions enable windows-navigator@gnome-shell-extensions.gcampax.github.com
#gnome-extensions enable workspace-indicator@gnome-shell-extensions.gcampax.github.com
gnome-extensions enable user-theme@gnome-shell-extensions.gcampax.github.com # Enable user-theme extension for shell theming
which pamac &>/dev/null && gnome-extensions enable pamac-updates@manjaro.org

# Enable fractional scaling in wayland
gsettings set org.gnome.mutter experimental-features "['scale-monitor-framebuffer', 'xwayland-native-scaling']"

# Applying tweaks/fixes
gsettings set org.gnome.desktop.default-applications.terminal exec 'gnome-terminal'
# Appears broken for now
# git clone https://github.com/Zackptg5/gnome-dash-fix
# chmod +x gnome-dash-fix/interactive.py
# ./gnome-dash-fix/interactive.py

echo "Set font to 'MesloLGNS NF Regular' in Gnome Terminal before first launching it!"
echo -e "Here's 3rd party extensions I use (grab them from extensions.gnome.org):
AppIndicator
Bluetooth Quick Connect
Caffeine
Clipboard Indicator
Dash to Dock
GSConnect
PaperWM
Quick Setting Tweaker
"
echo "You can also modify lockscreen settings with Login Manager Settings App"

# --AUR only--
# Apply theming
gsettings set org.gnome.desktop.interface gtk-theme "Orchis-Pink-Dark"
gsettings set org.gnome.desktop.interface icon-theme "Tela-circle-dracula-dark"
gsettings set org.gnome.shell.extensions.user-theme name "Orchis-Pink-Dark"