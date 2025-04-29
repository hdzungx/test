#!/bin/bash

# Installation functions
install_pacman_package() {
  if pacman -Q "$1" &>/dev/null ; then
    echo "$1 is already installed. Skipping..."
  else
    echo "Installing $1 ..."
    sudo pacman -S --noconfirm "$1"
    if ! pacman -Q "$1" &>/dev/null ; then
      echo "$1 failed to install. Please check manually."
      exit 1
    fi
  fi
}

install_aur_package() {
  if paru -Q "$1" &>/dev/null ; then
    echo "$1 is already installed. Skipping..."
  else
    echo "Installing $1 ..."
    paru -S --noconfirm "$1"
    if ! paru -Q "$1" &>/dev/null ; then
      echo "$1 failed to install. Please check manually."
      exit 1
    fi
  fi
}

# Update system
sudo pacman -Syu --noconfirm

# Essential packages
pacman_packages=(
    ## Display Manager & Shell
    sddm
    zsh

    ## Fonts
    ttf-hack-nerd
    ttf-jetbrains-mono-nerd

    ## Terminal & File Manager
    kitty
    nemo
    unrar
    ranger
    ueberzug

    ## Wayland & Hyprland Environment
    hyprland
    swaybg
    waybar
    hypridle
    dunst
    rofi
    grim
    slurp
    swappy
    qt5-wayland
    qt6-wayland
    qt5ct
    qt6ct
    qt5-graphicaleffects
    qt5-svg
    qt5-quickcontrols2

    ## XDG & Desktop Portal
    xdg-desktop-portal
    xdg-desktop-portal-gtk
    xdg-desktop-portal-wlr
    xdg-desktop-portal-hyprland
    xdg-user-dirs

    ## System Utilities
    brightnessctl
    htop
    btop
    nvtop
    fastfetch
    fzf
    cliphist
    wl-clipboard
    playerctl
    parallel
    ark
    nano
    neovim
    wget
    curl
    git
    gnupg
    udiskie
    polkit-gnome
    libnotify

    ## Development Tools
    base-devel
    cmake
    gdb
    python
    python-pip
    lua

    ## Audio
    pipewire
    pipewire-pulse
    pipewire-audio
    pipewire-jack
    pipewire-alsa
    wireplumber
    pavucontrol
    pamixer
    python-pyalsa

    ## Input Method (Vietnamese & GTK/Qt Support)
    fcitx5
    fcitx5-qt
    fcitx5-gtk
    fcitx5-unikey
    kcm-fcitx5

    ## Network & Bluetooth
    networkmanager
    bluez
    bluez-utils
    blueman

    ## VPN Tools
    openvpn             
    zenity   

    ## Desktop Integration
    gvfs

    ## Keyring 
    gnome-keyring
    libsecret

    ## Browsers & Media
    firefox
    vlc
)

# AUR Packages
aur_packages=(
    swaylock-effects-git
    bibata-cursor-theme-bin 
    tela-circle-icon-theme-dracula 
    visual-studio-code-bin   
    telegram-desktop-bin
    cava
    cmatrix-git
    peaclock
    pipes.sh
)

## Nvidia
nvidia_pkg=(
    nvidia-dkms
    nvidia-utils
    nvidia-settings
    libva
    libva-nvidia-driver
)

# Install paru if not present
if ! command -v paru &>/dev/null; then
    echo "Installing paru..."
    git clone https://aur.archlinux.org/paru.git
    cd paru || exit
    makepkg -si --noconfirm
    cd ..
    rm -rf paru
fi

# Install official packages
for package in "${pacman_packages[@]}"; do
  install_pacman_package "$package"
done

# Install AUR packages
for package in "${aur_packages[@]}"; do
  install_aur_package "$package"
done

# NVIDIA driver installation prompt
read -p 'Do you want to install NVIDIA drivers? (y/N) ' confirmation
confirmation=$(echo "$confirmation" | tr '[:lower:]' '[:upper:]')
if [[ "$confirmation" == 'Y' ]]; then
  echo "Installing additional Nvidia packages..."
  for krnl in $(cat /usr/lib/modules/*/pkgbase); do
    for NVIDIA in "${krnl}-headers" "${nvidia_pkg[@]}"; do
      install_pacman_package "$NVIDIA"
    done
  done

  # Check if the Nvidia modules are already added in mkinitcpio.conf and add if not
  if grep -qE '^MODULES=.*nvidia. *nvidia_modeset.*nvidia_uvm.*nvidia_drm' /etc/mkinitcpio.conf; then
    echo "Nvidia modules already included in /etc/mkinitcpio.conf"
  else
    sudo sed -Ei 's/^(MODULES=\([^\)]*)\)/\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
    echo "Nvidia modules added in /etc/mkinitcpio.conf"
  fi

  sudo mkinitcpio -P

  # Additional Nvidia steps
  NVEA="/etc/modprobe.d/nvidia.conf"
  if [ -f "$NVEA" ]; then
    echo "Seems like nvidia-drm modeset=1 is already added in your system..moving on."
  else
    echo "Adding options to $NVEA..."
    sudo echo -e "options nvidia_drm modeset=1 fbdev=1" | sudo tee -a /etc/modprobe.d/nvidia.conf
  fi

  # Additional for GRUB users
  if [ -f /etc/default/grub ]; then
      if ! sudo grep -q "nvidia-drm.modeset=1" /etc/default/grub; then
          sudo sed -i -e 's/\(GRUB_CMDLINE_LINUX_DEFAULT=".*\)"/\1 nvidia-drm.modeset=1"/' /etc/default/grub
          echo "nvidia-drm.modeset=1 added to /etc/default/grub"
      fi
      if ! sudo grep -q "nvidia_drm.fbdev=1" /etc/default/grub; then
          sudo sed -i -e 's/\(GRUB_CMDLINE_LINUX_DEFAULT=".*\)"/\1 nvidia_drm.fbdev=1"/' /etc/default/grub
          echo "nvidia_drm.fbdev=1 added to /etc/default/grub"
      fi
      sudo grub-mkconfig -o /boot/grub/grub.cfg
  else
      echo "/etc/default/grub does not exist"
  fi

  # Blacklist nouveau
  if [[ -z $blacklist_nouveau ]]; then
    read -n1 -rep "Would you like to blacklist nouveau? (y/n)" blacklist_nouveau
  fi
  echo
  if [[ $blacklist_nouveau =~ ^[Yy]$ ]]; then
    NOUVEAU="/etc/modprobe.d/nouveau.conf"
    if [ -f "$NOUVEAU" ]; then
      echo "Seems like nouveau is already blacklisted..moving on."
    else
      echo "blacklist nouveau" | sudo tee -a "$NOUVEAU"
      if [ -f "/etc/modprobe.d/blacklist.conf" ]; then
        echo "install nouveau /bin/true" | sudo tee -a "/etc/modprobe.d/blacklist.conf"
      else
        echo "install nouveau /bin/true" | sudo tee "/etc/modprobe.d/blacklist.conf"
      fi
    fi
  else
    echo "Skipping nouveau blacklisting."
  fi

fi
# Final message
echo "All packages installed successfully."

# start services
sudo systemctl enable NetworkManager
sudo systemctl enable bluetooth.service
sudo systemctl start NetworkManager
sudo systemctl start bluetooth.service
sudo systemctl enable sddm.service
systemctl --user enable gnome-keyring-daemon.service
systemctl --user start gnome-keyring-daemon.service

# Install zsh plugin
if [[ ! -d $HOME/.oh-my-zsh ]]; then
  export CHSH='yes'
  export RUNZSH='no'
  export KEEP_ZSHRC='yes'
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  # Install zsh-autosuggestions and zsh-syntax-highlighting
  echo -e "\n\nClone zsh-autosuggestion and zsh-syntax-highlighting\n\n"
  git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
fi

# Set open in terminal in nemo
gsettings set org.cinnamon.desktop.default-applications.terminal exec kitty

git config --global core.editor "nano"

cp -r .config "$HOME"
cp -r .icons "$HOME"
cp -r ./.local $HOME
cp -r bin "$HOME"
find ~/bin -type f -name "*.sh" -exec chmod +x {} \;
cp .zshrc $HOME
sudo cp -r sddm_theme/catppuccin-mocha /usr/share/sddm/themes/
sudo cp sddm_theme/sddm.conf /etc/
echo 'Installation complete!'