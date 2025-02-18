#!/bin/bash

IFS=$'\n'
DIRECTORY="$(readlink -f "$(dirname "$0")")"

yadflags=(--class media-record --name media-record --center --window-icon=media-record --title="Botspot's Screen Recorder" --separator='\n')

error() { #red text and exit 1
  echo -e "\e[91m$1\e[0m" 1>&2
  exit 1
}

status() { #cyan text to indicate what is happening
  echo -e "\e[96m$1\e[0m" 1>&2
}

list_microphones() { #technical name\tpretty name
  #find valid audio inputs
  local sources="$(pactl list sources)" #avoid running this several times
  local names="$(echo "$sources" | grep 'Name: alsa_input' | awk '{print $2}')"
  local name
  for name in $names ;do
    echo -n "$name"$'\t'
    echo "$sources" | tr '\n' '\r' | sed 's/\r\r/\n/g ; s/\r//g' | grep -F "Name: $name" | grep -o 'alsa.card_name = [^'$'\t]*' | awk -F'"' '{print $2}'
  done
}

list_webcams() { #/dev/video*\tpretty name
  #find valid webcams that can be captured
  local line
  local word
  local resolution
  for line in $(v4l2-ctl --list-devices 2>/dev/null | tr '\n' '\r' | sed 's/\r\r/\n/g ; s/\r//g' | grep -v pispbe) ;do
    local IFS=$'\t'
    #echo "line: $line"
    for word in $line ;do
      if [[ "$word" == /dev/video* ]];then
        #echo "word: $word"
        local v4l2_output="$(v4l2-ctl --device=$word --all)"
        if echo "$v4l2_output"  | tr -d '\n' | grep -q $'Device Caps.*\tVideo Capture' ;then
          #device valid, return it for each supported resolution
          IFS=$'\n'
          for resolution in $(list_resolutions "$word") ;do
            echo "$word"$'\t'"$(echo "$v4l2_output" | grep 'Card type' | awk -F': ' '{print $2}') $(echo "$resolution" | awk -F'\t' '{print $2}')"
          done
        fi
      fi
    done
  done
}

list_monitors() { #HDMI-*\tpretty name
  #find valid, enabled displays
  local line
  for line in $(wlr-randr | grep -v '^ ' | awk '{print $1}') ;do
    #display is enabled, so return it
    echo -n "$line"$'\t'
    echo "$line" | sed 's/-[A-Z]-/ /g ; s/-/ /g'
  done
}

list_resolutions() { #list handpicked subset of resolutions supported by given webcam: ###x###\tpretty name
  v4l2-ctl --device=$1 --list-formats-ext | grep Size | sed 's/^.*Size: .* //g' | sort -u | sort -n | grep '640x480\|1280x720' | awk -Fx '{print $1"x"$2"\t"$2"p"}'
}

favor_option() { #given a list of options on stdin, favor $1 if found
  local input="$(cat)"
  
  echo "$input" | grep -xF "$1"
  echo "$input" | grep -vxF "$1"
}

unique_filename() { #given a file $1, add a number before the file extension to make it unique
  #this function may seem unnecessarily complex. It is. But it has to be.
  #I want it to handle an incomplete sequence of pre-existing filenames correctly - not filling in the first gap but instead continuing the sequence from the greatest one.
  #also it should leave filenames that don't exist unchanged
  #and add an appropriate numeric suffix otherwise.
  local basename="${1##*/}" #filename without full paths
  local file_extension="${basename##*.}" #just the file extension
  local rawname="${basename%.*}" #basename without file extension
  local dirname="${1%/*}" #directory containing file
  
  #if numeric suffix already in filename, split it out
  local number="${rawname##*[!0-9]}"
  local name_no_number="${rawname%$number}" #part of basename without the number suffix
  
  #if no number in filename, and file exists, add number
  if [ -z "$number" ] && [ ! -f "${dirname}/${name_no_number}.${file_extension}" ];then
    #no number given, and file does not exist, so return that filename unchanged
    echo "$1"
    return 0
  fi
  
  #echo -e "basename: $basename\nfile_extension: $file_extension\nrawname: $rawname\ndirname: $dirname\nnumber: $number\nname_no_number: $name_no_number"
  
  #find the last file in the numeric sequence
  local lastfile="$(find "$dirname" -type f -regex ".*/${name_no_number}[0-9][0-9]*\.${file_extension}" | sort -V | tail -1)"
  #this could be empty, if $1 has no number, and that file exists, then we should assign the number 1
  [ -z "$lastfile" ] && lastfile="${dirname}/${name_no_number}0.${file_extension}"
  #echo "lastfile: $lastfile"
  
  #now determine what the next file in the sequence would be
  basename="${lastfile##*/}" #filename without full paths
  rawname="${basename%.*}" #basename without file extension
  number="${rawname##*[!0-9]}"
  name_no_number="${rawname%$number}" #part of basename without the number suffix
  
  #return new filename that continues the sequence and does not exist
  echo "${dirname}/${name_no_number}$((number+1)).${file_extension}"
}

#get options used last time
if [ -f ~/.config/botspot-screen-recorder.conf ];then
  source ~/.config/botspot-screen-recorder.conf
  
  #replace $HOME with ~/ in output_file
  output_file="$(unique_filename "$(echo "$output_file" | sed "s+\~/+$HOME/+g ; s+\./+$PWD+g")")"
else
  #set default values for what needs it
  downscale_enabled=FALSE
  mirror_enabled=TRUE
  sysaudio_enabled=TRUE
  output_file="~/Videos/recording.mkv"
  geometry=''
fi
output_file="$(echo "$output_file" | sed "s+^${HOME}/+~/+g")"

apt_install=()
if ! command -v slurp >/dev/null ;then
  apt_install+=(slurp)
fi
if ! command -v ffmpeg >/dev/null ;then
  apt_install+=(ffmpeg)
fi
if ! command -v ninja >/dev/null ;then
  apt_install+=(ninja-build)
fi
if ! command -v git >/dev/null ;then
  apt_install+=(git)
fi
if ! command -v meson >/dev/null ;then
  apt_install+=(meson)
fi
if ! command -v mpv >/dev/null ;then
  apt_install+=(mpv)
fi
if ! command -v yad >/dev/null ;then
  apt_install+=(yad)
fi
if ! command -v g++ >/dev/null ;then
  apt_install+=(g++)
fi
if ! command -v wlr-randr >/dev/null ;then
  apt_install+=(wlr-randr)
fi
if ! command -v v4l2-ctl >/dev/null ;then
  apt_install+=(v4l-utils)
fi

if [ ! -z "${apt_install[*]}" ];then
  status "Installing dependencies..."
  sudo apt install -y "${apt_install[@]}" || error "dependency installation failed"
fi

#install wf-recorder >= 0.5.0
if ! command -v wf-recorder >/dev/null || [ "$(echo -e "0.5.0\n$(wf-recorder -v | awk '{print $2}')" | sort -V | head -n1)" != 0.5.0 ];then
  status "Compiling wf-recorder..."
  sudo apt install -y wayland-protocols libavutil-dev libavfilter-dev libavdevice-dev libavcodec-dev libavformat-dev libswscale-dev libpulse-dev libgbm-dev libpipewire-0.3-dev libdrm-dev || error "dependency installation failed"
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

slurp_function() { #populate the crop field with the output from slurp
  echo -n 4:
  slurp
  true
}
export -f slurp_function
#main configuration window
output="$(yad "${yadflags[@]}" --form --align=center \
  --text="<big><b>Botspot's Screen Recorder</b>       <a href="\""https://github.com/sponsors/botspot"\"">Donate</a></big>" \
  --field='Screen::CB' "$(list_monitors | awk -F'\t' '{print $2}' | sed '$ s/$/\nnone/' | favor_option "$monitor" | tr '\n' '!' | sed 's/!$//')" \
  --field='Downscale screen 2X':CHK "$downscale_enabled" \
  --field="Screen recording FPS::CB" "$(echo -e 'maximum\n30\n20\n15\n10\n5\n1' | favor_option "$fps" | tr '\n' '!' | sed 's/!$//')" \
  --field="Crop boundaries::RO" "$geometry" \
  --field="Set crop boundaries:FBTN" '@bash -c slurp_function' \
  --field='Webcam::CB' "$(list_webcams | awk -F'\t' '{print $2}' | sed '$ s/$/\nnone/' | favor_option "$webcam" | tr '\n' '!' | sed 's/!$//')" \
  --field="Mirror webcam:CHK" "$mirror_enabled" \
  --field='Microphone::CB' "$(list_microphones | awk -F'\t' '{print $2}' | sed '$ s/$/\nnone/' | favor_option "$microphone" | tr '\n' '!' | sed 's/!$//')" \
  --field='Record system audio:CHK' "$sysaudio_enabled" \
  --field="Output file::SFL" "$output_file" \
  --button="Start recording"!media-record:0)" || exit 0

output="$(echo "$output" | grep -vF 'Opening in existing browser session.')" #workaround chromium output from donate button shifting everything down a line

monitor="$(echo "$output" | sed -n 1p)"
downscale_enabled="$(echo "$output" | sed -n 2p)"
fps="$(echo "$output" | sed -n 3p)"
geometry="$(echo "$output" | sed -n 4p)"
webcam="$(echo "$output" | sed -n 6p)"
mirror_enabled="$(echo "$output" | sed -n 7p)"
microphone="$(echo "$output" | sed -n 8p)"
sysaudio_enabled="$(echo "$output" | sed -n 9p)"
output_file="$(echo "$output" | sed -n 10p)"
[ -z "$output_file" ] && output_file="$(unique_filename "$HOME/Videos/recording.mkv")"

#save gui selected values to conf file before making them machine readible
echo "monitor='$monitor'
downscale_enabled='$downscale_enabled'
geometry='$geometry'
webcam='$webcam'
mirror_enabled='$mirror_enabled'
microphone='$microphone'
sysaudio_enabled='$sysaudio_enabled'
fps='$fps'
output_file='$output_file'" | tee ~/.config/botspot-screen-recorder.conf

#convert pretty names to machine names ("none" option is converted to empty value)
microphone="$(list_microphones | grep "$microphone"'$' | awk -F'\t' '{print $1}')"
[ "$webcam" != none ] && webcam_resolution="$(list_resolutions "$(list_webcams | grep "$webcam"'$' | awk -F'\t' '{print $1}')" | grep "$(echo "$webcam" | awk '{print $NF}')" | awk -F'\t' '{print $1}')"
webcam="$(list_webcams | grep "$webcam"'$' | awk -F'\t' '{print $1}')"
monitor="$(list_monitors | grep "$monitor"'$' | awk -F'\t' '{print $1}')"
output_file="$(echo "$output_file" | sed "s+\~/+$HOME/+g ; s+\./+$PWD+g")"

#variables to hold flags passed to mpv and wf-recorder
mpv_flags=()
recorder_flags=()
hflip_flag=()
ffmpeg_resolution_flag=()

#parse inputs - webcam mirror
if [ "$mirror_enabled" == TRUE ];then
  hflip_flag=(-vf hflip)
fi

#parse inputs - fps
if [ "$fps" != maximum ];then
  recorder_flags+=(-B "$fps" -r "$fps")
  
  mpv_flags+=(--vf=fps=1) #also limit webcam fps
fi

#parse inputs - monitor
if [ ! -z "$monitor" ];then
  recorder_flags+=(-o "$monitor")
fi

#parse inputs - webcam resolution
if [ ! -z "$webcam_resolution" ] && [ ! -z "$webcam" ];then
  v4l2-ctl --device="$webcam" --set-fmt-video=width=$(echo "$webcam_resolution" | awk -Fx '{print $1}'),height=$(echo "$webcam_resolution" | awk -Fx '{print $2}')
fi

#parse inputs - downscaling
if [ "$downscale_enabled" == TRUE ];then
  recorder_flags+=(-F 'scale=iw*0.5:ih*0.5')
fi

#parse inputs - geometry (crop boundaries)
if [ ! -z "$geometry" ];then
  recorder_flags+=(-g "$geometry")
fi

#audio handling, if enabled
if [ "$sysaudio_enabled" == TRUE ] || [ ! -z "$microphone" ];then
  #make a custom pulseaudio sink that merges microphone and system audio
  device1="$(pactl load-module module-null-sink sink_name=virtual_mix sink_properties=device.description="Virtual_Mix")"
  device2=''
  device3=''
  if [ ! -z "$microphone" ];then
    #if capturing microphone, set its input volume to 100%
    pactl set-source-volume "$microphone" 100% || error "failed to set microphone volume"
    
    #make it an input to this pulseaudio loopback device
    if [ ! -z "$monitor" ];then
      #add a 80ms audio latency if recording the screen, to prevent voice from being ahead of on-screen video feed
      device2="$(pactl load-module module-loopback source="$microphone" sink=virtual_mix latency_msec=80)"
    else
      #not screen recording, so don't add latency
      device2="$(pactl load-module module-loopback source="$microphone" sink=virtual_mix)"
    fi
  fi
  
  if [ "$sysaudio_enabled" == TRUE ];then
    #if capturing system audio, make it an input to this pulseaudio monitor device
    device3="$(pactl load-module module-loopback source=pipewiresrc.monitor sink=virtual_mix)"
    #This captures system audio always at 100% regardless of system volume. Bug or feature? You decide.
  fi
  
  #make sure to remove these virtual audio devices on script exit
  cleanup_commands="pactl unload-module $device1 2>/dev/null
  pactl unload-module $device2 2>/dev/null
  pactl unload-module $device3 2>/dev/null"
  trap "$cleanup_commands" EXIT
fi

#ensure containing directory for output file
mkdir -p "$(dirname "$output_file")"

if [ ! -z "$monitor" ];then
  #screen recording mode
  
  #display webcam if enabled
  if [ ! -z "$webcam" ];then
    recording_mode="screen + on-screen webcam feed"
    
    mpv av://v4l2:"$webcam" "${mpv_flags[@]}" "${hflip_flag[@]}" --title="BSR webcam feed" --profile=low-latency --untimed=yes --video-latency-hacks=yes --wayland-disable-vsync=yes --script="${DIRECTORY}/webcam-view.lua" &
    cleanup_commands+=$'\n'"kill $! 2>/dev/null"
  else
    recording_mode="screen only"
  fi
  
  #record screen
  wf-recorder --audio=virtual_mix.monitor -y -f "$output_file" -m matroska -c libx264 -p preset=ultrafast -p crf=28 "${recorder_flags[@]}" &
  recorder_pid=$!
  
elif [ ! -z "$webcam" ];then
  recording_mode="webcam only"
  
  ffmpeg -hide_banner -y -f v4l2 -i "$webcam" -f pulse -i virtual_mix.monitor "${hflip_flag[@]}" -c:v libx264 -preset ultrafast -crf 28 -c:a aac -strict -2 "$output_file" &
  recorder_pid=$!
  
elif [ "$sysaudio_enabled" == TRUE ] || [ ! -z "$microphone" ];then
  recording_mode="audio only"
  #audio only recording mode
  ffmpeg -hide_banner -y -f pulse -i virtual_mix.monitor -c:a aac -strict -2 "$output_file" &
  recorder_pid=$!
else
  error "Refusing to record nothing :)"
fi
status "BSR recording mode: $recording_mode"

cleanup_commands+=$'\n'"kill $recorder_pid 2>/dev/null"
trap "$cleanup_commands" EXIT

mute_function() { #handle mute button click events - get current state from the label, then change the label to the other state while toggling mute
  if [ "$1" == unmuted ];then
    pactl set-sink-mute "virtual_mix" 1
    echo -n 2:muted
  else
    pactl set-sink-mute "virtual_mix" 0
    echo -n 2:unmuted
  fi
}
export -f mute_function

mute_function=()
if [ "$sysaudio_enabled" == TRUE ] || [ ! -z "$microphone" ];then
  #audio enabled, add mute button
  mute_function=(--field='Toggle mute!audio-input-mic-muted':FBTN '@bash -c "mute_function %2"' \
  --field=:RO 'unmuted')
fi

yad "${yadflags[@]}" --text="<b><big>Botspot's Screen Recorder:</big></b>\nRecording $recording_mode" \
  --image=media-record --image-on-top --form \
  "${mute_function[@]}" \
  --field=$'\n<big>                      Stop recording                      </big>\n':FBTN 'bash -c "kill $YAD_PID"' --no-buttons
kill $recorder_pid
