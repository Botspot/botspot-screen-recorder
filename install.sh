#!/bin/bash

#Delete this file to prevent BSR from attempting to update itself or install dependencies.

if [ -z "$DIRECTORY" ];then
  echo "Please do not run this script individually!"$'\n'"This script is meant to be run by the main screen-recorder.sh script."$'\n'"If you wish to install botspot-screen-recorder and not run it, use this command: $(dirname "$0")/screen-recorder.sh install"
  exit 1
fi

#apt_install array is pre-populated by the parent screen-recorder.sh script
if [ ! -z "${apt_install[*]}" ] && command -v apt >/dev/null;then
  status "Installing dependencies..."
  sudo apt install -y "${apt_install[@]}" || error "dependency installation failed"
elif [ ! -z "${apt_install[*]}" ] ;then
  error "Dependencies need to be installed, but your OS does not appear to use the apt command. You will need to install these dependencies yourself: ${apt_install[*]}"
fi

#install wf-recorder >= 0.5.0                 grep here improves app launch speed
if ! command -v wf-recorder >/dev/null || (! grep -qF 0.5.0 /usr/local/bin/wf-recorder && [ "$(echo -e "0.5.0\n$(wf-recorder -v | awk '{print $2}')" | sort -V | head -n1)" != 0.5.0 ]);then
  status "Compiling wf-recorder..."
  sudo apt install -y libwayland-dev wayland-protocols libavutil-dev libavfilter-dev libavdevice-dev libavcodec-dev libavformat-dev libswscale-dev libpulse-dev libgbm-dev libpipewire-0.3-dev libdrm-dev || error "dependency installation failed"
  rm -rf wf-recorder
  git clone https://github.com/ammen99/wf-recorder || error "failed to download wf-recorder git repo"
  cd wf-recorder
  meson setup build --prefix=/usr/local --buildtype=release || error "failed to run meson build for wf-recorder"
  ninja -C build || error "failed to run ninja -C build for wf-recorder"
  sudo ninja -C build install || error "failed to run sudo ninja -C build install for wf-recorder"
fi

#add menu launcher
if [ ! -f ~/.local/share/applications/bsr.desktop ];then
  mkdir -p ~/.local/share/applications
  echo "[Desktop Entry]
Version=1.0
Name=Botspot Screen Recorder
GenericName=Screen/Webcam Recording Software
Comment=Screen/Webcam/Audio Recorder for Wayland
Exec=$0
Icon=media-record
Terminal=false
Type=Application
Categories=AudioVideo;Recorder;
StartupNotify=true
StartupWMClass=media-record" > ~/.local/share/applications/bsr.desktop
  echo "Created menu launcher file at ~/.local/share/applications/bsr.desktop"
fi

#exit now if given 'install' flag - for use in pi-apps
[ "$1" == install ] && exit 0

#check for updates
localhash="$(cd "$DIRECTORY" ; git rev-parse HEAD)"
latesthash="$(git ls-remote https://github.com/Botspot/botspot-screen-recorder HEAD | awk '{print $1}')"
if [ "$localhash" != "$latesthash" ] && [ ! -z "$latesthash" ] && [ ! -z "$localhash" ];then
  echo "Auto-updating BSR for the latest features and improvements..."
  (cd "$DIRECTORY"
  git restore . #abandon changes to tracked files (otherwise users who modified this script are left behind)
  git -c color.ui=always pull | cat #piping through cat makes git noninteractive
  exit "${PIPESTATUS[0]}")
  
  if [ $? == 0 ];then
    echo "git pull finished. Reloading script..."
    "$DIRECTORY/screen-recorder.sh" "$@"
    exit $?
  else
    echo "git pull failed. Continuing..."
  fi
fi
