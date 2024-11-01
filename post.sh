#!/usr/bin/bash

# WORK IN TEMP DIR
workDirName="${HOME}/buildHypr";
rm -rf $workDirName
mkdir -p $workDirName
cd $workDirName

hyprBuildInstall() {
	cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -DCMAKE_INSTALL_PREFIX:PATH=/usr -S . -B ./build
	cmake --build ./build --config Release --target $1 -j`nproc 2>/dev/null || getconf _NPROCESSORS_CONF`
	sudo cmake --install ./build
}

sudo pacman -S git curl

# INSTALL YAY
if !command -v yay &> /dev/null; then
	echo "yay not found, installing!"
	git clone --recursive https://aur.archlinux.org/yay.git
	cd yay && makepkg -si && cd ..
fi

yay -Syu

yay -S alacritty waybar-git nautilus rofi-wayland dunst grim slurp --noconfirm

# INSTALL HYPRLAND
# - hyprutils
yay -S cmake gcc make
git clone --recursive https://github.com/hyprwm/hyprutils.git
cd hyprutils && hyprBuildInstall all && cd ..

# - hyprlang
yay -S gcc-libs glibc
git clone --recursive https://github.com/hyprwm/hyprlang.git
cd hyprlang && hyprBuildInstall hyprlang && cd ..

# - hyprcursor
yay -S cairo libzip librsvg tomlplusplus gdb
git clone --recursive https://github.com/hyprwm/hyprutils.git
cd hyprcursor && hyprBuildInstall all && cd ..

# - hyprwayland-scanner
yay -S pugixml
git clone --recursive https://github.com/hyprwm/hyprwayland-scanner.git
cd hyprwayland-scanner
cmake -DCMAKE_INSTALL_PREFIX=/usr -B build
cmake --build build -j `nproc`
sudo cmake --install build
cd ..

# - xdg-desktop-portal-hyprland
yay -S libdrm libpipewire sdbus-cpp wayland qt6-base qt6-wayland xdg-desktop-portal wayland-protocols scdoc
git clone --recursive https://github.com/hyprwm/xdg-desktop-portal-hyprland
cd xdg-desktop-portal-hyprland
cmake -DCMAKE_INSTALL_LIBEXECDIR=/usr/lib -DCMAKE_INSTALL_PREFIX=/usr -B build
cmake --build build
sudo cmake --install build
cd ..

# - aquamarine
yay -S hwdata
git clone --recursive https://github.com/hyprwm/aquamarine.git
cd aquamarine && hyprBuildInstall all && cd ..

# - Hyprland
yay -S gdb ninja gcc cmake meson libxcb xcb-proto xcb-util xcb-util-keysyms libxfixes libx11 libxcomposite xorg-xinput libxrender pixman wayland-protocols cairo pango seatd libxkbcommon xcb-util-wm xorg-xwayland libinput libliftoff libdisplay-info cpio tomlplusplus xcb-util-errors
git clone --recursive https://github.com/hyprwm/Hyprland
cd Hyprland
make all && sudo make install
cd ..

# - hyprpaper
yay -S pango libjpeg-turbo libglvnd libwebp
git clone --recursive https://github.com/hyprwm/hyprpaper.git
cd hyprpaper && hyprBuildInstall hyprpaper && cd ..

# - hyprlock
yay -S pam
git clone --recursive https://github.com/hyprwm/hyprlock.git
cd hyprlock && hyprBuildInstall hyprlock && cd ..

cd ..
rm -rf $workDirName