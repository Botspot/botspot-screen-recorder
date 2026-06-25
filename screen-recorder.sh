#!/bin/bash

IFS=$'\n'
DIRECTORY="$(readlink -f "$(dirname "$0")")"

yadflags=(--class media-record --name media-record --center --window-icon=media-record --title="Botspot's Screen Recorder" --separator='\n')
ffmpeg_main_flags=(-loglevel warning -hide_banner)

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
  local names="$(echo "$sources" | grep -E 'Name: (alsa_input|bluez_input)' | awk '{print $2}')"
  local name
  local found=
  for name in $names ;do
    found=yes
    echo -n "$name"$'\t'
    echo "$sources" | tr '\n' '\r' | sed 's/\r\r/\n/g ; s/\r//g' | grep -F "Name: $name" | grep -o 'device.description = [^'$'\t]*\|alsa.card_name = [^'$'\t]*' | tail -1 | awk -F'"' '{print $2}'
  done
  
  if [ -z "$found" ];then
    echo #always output at least a newline
  fi
}

list_webcams() { #/dev/video*\tpretty name
  #find valid webcams that can be captured
  local line
  local word
  local resolution
  local found=
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
            found=yes
            echo "$word"$'\t'"$(echo "$v4l2_output" | grep 'Card type' | awk -F': ' '{print $2}') $(echo "$resolution" | awk -F'\t' '{print $2}')"
          done
        fi
      fi
    done
  done
  
  if [ -z "$found" ];then
    echo #always output at least a newline
  fi
}

list_screens() { #HDMI-*\tpretty name
  #find valid, enabled displays
  local line
  local found=
  for line in $(wlr-randr | grep -v '^ ' | awk '{print $1}') ;do
    found=yes
    #display is enabled, so return it
    echo -n "$line"$'\t'
    echo "$line" | sed 's/-[A-Z]-/ /g ; s/-/ /g'
  done
  
  if [ -z "$found" ];then
    echo #always output at least a newline
  fi
}

list_resolutions() { #list handpicked subset of resolutions supported by given webcam: ###x###\tpretty name
  local resolutions="$(v4l2-ctl --device=$1 --list-formats-ext | grep Size | sed 's/^.*Size: .* //g' | sort -u | sort -nr)"
  
  #be aspect ratio agnostic: print 16:9 if available, otherwise 4:3, not both
  echo "$resolutions" | grep -m1 '432x240\|320x240' | awk -Fx '{print $1"x"$2"\t"$2"p"}' #240p
  echo "$resolutions" | grep -m1 '864x480\|640x480' | awk -Fx '{print $1"x"$2"\t"$2"p"}' #480p
  echo "$resolutions" | grep -m1 '1280x720\|1280x720' | awk -Fx '{print $1"x"$2"\t"$2"p"}' #720p
  echo "$resolutions" | grep -m1 '1920x1080' | awk -Fx '{print $1"x"$2"\t"$2"p"}' #1080p (doesn't have a 4:3 equivalent on my webcam at least)
}

favor_option() { #given a list of options on stdin, favor $1 if found
  local input="$(cat)"
  
  echo "$input" | grep -xF "$1"
  echo "$input" | grep -vxF "$1"
}

favor_option_gently() { #given a list of options on stdin, favor $1 even if not found
  echo "$1"
  grep -vxF "$1"
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
  local lastfile="$(find "$dirname" -maxdepth 1 -type f -regex ".*/${name_no_number}[0-9][0-9]*\.${file_extension}" | sort -V | tail -1)"
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

process_exists() { #return 0 if the $1 PID is running, otherwise 1
  [ -z "$1" ] && error "process_exists(): no PID given!"
  
  if [ -f "/proc/$1/status" ];then
    return 0
  else
    return 1
  fi
}

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

#clean up any accidentally left behind modules from unsafe shutdowns
for id in $(pactl list modules short | grep 'bsr_audio_mix' | awk '{print $1}'); do pactl unload-module "$id"; done

slurp_function() { #populate the crop field with the output from slurp
  echo -n $1: #if new options are added to YAD, be sure to edit the arg where this function runs!
  slurp
  true
}
export -f slurp_function

while true;do #repeat the gui until user exits
  
  cleanup_commands=""
  mpv_pid="" #clear this out to prevent false positive detected crashed preview videos
  
  #set default values before reading config file
  downscale_enabled=FALSE
  mirror_enabled=TRUE
  sysaudio_enabled=TRUE
  output_file="~/Videos/recording.mkv"
  geometry=''
  reencode=TRUE
  
  #get options used last time (read config file)
  if [ -f ~/.config/botspot-screen-recorder.conf ];then
    source ~/.config/botspot-screen-recorder.conf
  fi
  
  #ensure the filename is unique
  output_file="$(unique_filename "$(echo "$output_file" | sed "s+\~/+$HOME/+g ; s+\./+$PWD+g")")"
  #yad file browser does not recognize ~/, so it falls back to pwd, so we set the pwd to the parent directory of the file.
  cd "$(dirname "$output_file")"
  #replace $HOME with ~/ in output_file
  output_file="$(echo "$output_file" | sed "s+^${HOME}/+~/+g")"
  
  #main configuration window
  output="$(yad "${yadflags[@]}" --form --align=center \
    --text="<big><b>Botspot's Screen Recorder</b>       <a href="\""https://github.com/sponsors/botspot"\"">Donate</a></big>" \
    --field='Screen::CB' "$(list_screens | awk -F'\t' '{print $2}' | sed '$ s/$/\nnone/' | favor_option "$screen" | tr '\n' '!' | sed 's/!$// ; s/^!//')" \
    --field='Downscale screen 2X':CHK "$downscale_enabled" \
    --field="Frame rate::CBE" "$(echo -e 'maximum\n30\n20\n15\n10\n5\n1' | favor_option_gently "$fps" | tr '\n' '!' | sed 's/!$// ; s/^!//')" \
    --field="Quality::CB" "$(echo -e 'Medium\nLow\nHigh' | favor_option "$quality" | tr '\n' '!' | sed 's/!$// ; s/^!//')" \
    --field="Crop boundaries::RO" "$geometry" \
    --field="Set crop boundaries!edit-select-all-symbolic:FBTN" '@bash -c "slurp_function 5"' \
    --field='Webcam::CB' "$(list_webcams | awk -F'\t' '{print $2}' | sed '$ s/$/\nnone/' | favor_option "$webcam" | tr '\n' '!' | sed 's/!$// ; s/^!//')" \
    --field="Mirror webcam:CHK" "$mirror_enabled" \
    --field='Microphone::CB' "$(list_microphones | awk -F'\t' '{print $2}' | sed '$ s/$/\nnone/' | favor_option "$microphone" | tr '\n' '!' | sed 's/!$// ; s/^!//')" \
    --field='Record system audio:CHK' "$sysaudio_enabled" \
    --field="Output file::SFL" "$output_file" \
    --field='Optimize file size:CHK' "$reencode" \
    --button="Preview"!view-reveal-symbolic:2 \
    --button="Start recording"!media-record-symbolic:0 \
    --file-filter="Supported file formats: .mp3 .wav .mp4 .mkv .gif .webp | *.mp3 *.wav *.mp4 *.mkv *.gif *.webp")"
  case $? in #get button clicked
    0)
      mode=normal
      ;;
    2)
      mode=preview
      ;;
    *)
      exit 0 #yad window closed
      ;;
  esac
  
  output="$(echo "$output" | grep -vF 'Opening in existing browser session.')" #workaround chromium output from donate button shifting everything down a line
  
  screen="$(echo "$output" | sed -n 1p)"
  downscale_enabled="$(echo "$output" | sed -n 2p)"
  fps="$(echo "$output" | sed -n 3p)"
  quality="$(echo "$output" | sed -n 4p)"
  geometry="$(echo "$output" | sed -n 5p)"
  webcam="$(echo "$output" | sed -n 7p)"
  mirror_enabled="$(echo "$output" | sed -n 8p)"
  microphone="$(echo "$output" | sed -n 9p)"
  sysaudio_enabled="$(echo "$output" | sed -n 10p)"
  output_file="$(echo "$output" | sed -n 11p)"
  reencode="$(echo "$output" | sed -n 12p)"
  
  file_extension="${output_file##*.}"
  if [ -z "$output_file" ];then
    #default filename if unset
    output_file="$(unique_filename "$HOME/Videos/recording.mkv")"
  elif [[ "$output_file" != *'.'* ]];then
    #default file extension
    output_file+='.mkv'
  fi
  
  #save gui selected values to conf file before making them machine readible
  echo "screen='$screen'
downscale_enabled='$downscale_enabled'
geometry='$geometry'
quality='$quality'
webcam='$webcam'
mirror_enabled='$mirror_enabled'
microphone='$microphone'
sysaudio_enabled='$sysaudio_enabled'
fps='$fps'
output_file='$output_file'
reencode='$reencode'" | tee ~/.config/botspot-screen-recorder.conf #use tee so the config values are also sent to stdout
  
  #convert pretty names to machine names ("none" option is converted to empty value)
  microphone="$(list_microphones | grep -m1 $'\t'"$microphone"'$' | awk -F'\t' '{print $1}')"
  [ "$webcam" != none ] && webcam_resolution="$(list_resolutions "$(list_webcams | grep $'\t'"$webcam"'$' | awk -F'\t' '{print $1}')" | grep -m1 $'\t'"$(echo "$webcam" | awk '{print $NF}')"'$' | awk -F'\t' '{print $1}')"
  webcam="$(list_webcams | grep -m1 $'\t'"$webcam"'$' | awk -F'\t' '{print $1}')"
  screen="$(list_screens | grep $'\t'"$screen"'$' | awk -F'\t' '{print $1}')"
  output_file="$(echo "$output_file" | sed "s+\~/+$HOME/+g ; s+\./+$PWD+g")"
  
  #MKV file used for recording; will be converted into final filetype, or re-encoded if necessary
  intermediate_output_file="${output_file}.tmp"
  
  capturing_audio=FALSE
  if [ "$sysaudio_enabled" == TRUE ] || [ ! -z "$microphone" ];then
    capturing_audio=TRUE
  fi
  capturing_video=FALSE
  if [ ! -z "$webcam" ] || [ ! -z "$screen" ];then
    capturing_video=TRUE
  fi
  
  if [[ ! "$file_extension" =~ ^(mp3|wav|mp4|mkv|gif|webp)$ ]];then
    yad "${yadflags[@]}" --text="Unsupported file format: $file_extension"$'\n'"Supported file formats: .mp3 .wav .mp4 .mkv .gif .webp" --button=OK:0
    #immediately go back to the top of the loop
    continue
  elif [ "$capturing_audio" == TRUE ] && [[ "$file_extension" =~ ^(gif|webp)$ ]];then
    yad "${yadflags[@]}" --text="You have audio inputs selected, but the .$file_extension file extension only allows video."$'\n'"Please change file formats, or disable audio inputs." --button=OK:0
    continue
  elif [ "$capturing_video" == TRUE ] && [[ "$file_extension" =~ ^(mp3|wav)$ ]];then
    yad "${yadflags[@]}" --text="You have video inputs selected, but the .$file_extension file extension only allows audio."$'\n'"Please change file formats, or disable video inputs." --button=OK:0
    continue
  fi
  
  #variables to hold flags passed to mpv and wf-recorder
  mpv_flags=()
  recorder_flags=()
  hflip_flag=()
  ffmpeg_webcam_input_flags=()
  
  #parse inputs - webcam mirror
  if [ "$mirror_enabled" == TRUE ];then
    hflip_flag=(-vf hflip)
  fi
  
  #parse inputs - fps
  if [ "$fps" != maximum ];then
    recorder_flags+=(-B "$fps" -r "$fps")
    ffmpeg_webcam_input_flags+=(-framerate $fps)
    mpv_flags+=(--vf=fps=$fps) #also limit webcam feed fps
  fi
  
  #parse inputs - quality
  case "$quality" in
    High)
      crf=12
      ;;
    Medium)
      crf=21
      ;;
    Low)
      crf=28
      ;;
    *)
      error "Unknown quality value '$quality'!"
      ;;
  esac
  recorder_flags+=(-p crf=$crf)
  
  #parse inputs - screen
  if [ ! -z "$screen" ];then
    recorder_flags+=(-o "$screen")
  fi
  
  #parse inputs - set a webcam resolution now
  if [ ! -z "$webcam_resolution" ] && [ ! -z "$webcam" ];then
    v4l2-ctl --device="$webcam" --set-fmt-video=width=$(echo "$webcam_resolution" | awk -Fx '{print $1}'),height=$(echo "$webcam_resolution" | awk -Fx '{print $2}')
  fi
  
  #parse inputs - downscaling
  if [ "$downscale_enabled" == TRUE ];then
    recorder_flags+=(-F 'scale=iw*0.5:ih*0.5')
  fi
  
  #parse inputs - geometry (crop boundaries)
  if [ ! -z "$geometry" ];then
    #handle edge case: if downscale 2x is enabled and geometry is specified, ensure that geometry is divisible by 4
    if [ "$downscale_enabled" == TRUE ];then
      #extract width and height
      [[ $geometry =~ ^([0-9]+,[0-9]+)[[:space:]]+([0-9]+)+x([0-9]+)$ ]]
      offset="${BASH_REMATCH[1]}"
      w="${BASH_REMATCH[2]}"
      h="${BASH_REMATCH[3]}"
      # Round width and height to nearest multiple of 4
      (( w = (w + 2) / 4 * 4 ))
      (( h = (h + 2) / 4 * 4 ))
      geometry="${offset} ${w}x${h}"
    fi
    
    recorder_flags+=(-g "$geometry")
  fi
  echo $geometry
  
  #handle preview mode
  if [ $mode == preview ];then
    
    #disable making pulse sink and audio capture for video preview, unless we're previewing audio only (these values are not saved to config file)
    if [ "$capturing_video" == TRUE ];then
      sysaudio_enabled=FALSE
      microphone=''
      capturing_audio=FALSE
    fi
    
    #try to reduce preview latency
    recorder_flags+=(-p tune=zerolatency)
    
    #write video to a pipe which we will preview with mpv
    rm -f /tmp/preview_pipe
    mkfifo /tmp/preview_pipe || exit 1
    output_file=/tmp/preview_pipe
    intermediate_output_file=/tmp/preview_pipe
  fi
  
  #audio handling, if enabled
  if [ "$capturing_audio" == TRUE ];then
    #stop easyeffects because it breaks the pipeline for whatever reason and prevents audio capture
    killall easyeffects 2>/dev/null
    
    #make a custom pulseaudio sink that merges microphone and system audio
    device1="$(pactl load-module module-null-sink sink_name=bsr_audio_mix sink_properties=device.description="bsr_audio_mix")"
    if [ -z "$device1" ];then
      error "Failed to use pulseaudio to make a null sink! Please refer to any errors above."
    fi
    
    # Force unmute the virtual sink, as the OS may restore a previous muted state
    pactl set-sink-mute bsr_audio_mix 0 2>/dev/null

    device2=''
    device3=''
    if [ ! -z "$microphone" ];then
      #if capturing microphone, set its input volume to 100% and explicitly unmute it
      pactl set-source-volume "$microphone" 100% || error "Failed to set microphone volume for '$microphone' to 100%"
      pactl set-source-mute "$microphone" 0 2>/dev/null
      
      #make it an input to this pulseaudio loopback device
      if [ ! -z "$screen" ];then
        #add a 80ms audio latency if recording the screen, to prevent voice from being ahead of on-screen video feed
        device2="$(pactl load-module module-loopback source="$microphone" sink=bsr_audio_mix latency_msec=80)"
      else
        #not screen recording, so don't add latency
        device2="$(pactl load-module module-loopback source="$microphone" sink=bsr_audio_mix)"
      fi
    fi
    
    if [ "$sysaudio_enabled" == TRUE ];then
      #if capturing system audio, make it an input to this pulseaudio monitor device
      device3="$(pactl load-module module-loopback source=pipewiresrc.monitor sink=bsr_audio_mix)"
      #This captures system audio always at 100% regardless of system volume. Bug or feature? You decide.
    fi
    
    #make sure to remove these virtual audio devices on script exit
    cleanup_commands="pactl unload-module $device1 2>/dev/null
    pactl unload-module $device2 2>/dev/null
    pactl unload-module $device3 2>/dev/null"
    trap "$cleanup_commands" EXIT
    
    #only if audio is enabled should we tell wf-recorder to record this monitor
    #this way if audio capture is disabled it does not fallback to the default monitor (see issue #5)
    recorder_flags+=(--audio=bsr_audio_mix.monitor)
    #do the same for ffmpeg (increased thread queue reduces the risk of desynced audio)
    ffmpeg_audio_flags=(-f pulse -thread_queue_size 1024 -i bsr_audio_mix.monitor)
  else
    status "not making bsr_audio_mix.monitor"
    ffmpeg_audio_flags=()
  fi
  
  #ensure containing directory for output file
  mkdir -p "$(dirname "$output_file")"
  
  if [ ! -z "$screen" ];then
    #screen recording mode (with or without webcam preview)
    
    #display webcam if enabled
    if [ ! -z "$webcam" ];then
      recording_mode="screen + on-screen webcam feed"
      
      mpv av://v4l2:"$webcam" "${mpv_flags[@]}" "${hflip_flag[@]}" --title="BSR webcam feed" --no-audio --profile=low-latency --untimed=yes --video-latency-hacks=yes --wayland-disable-vsync=yes --script="${DIRECTORY}/webcam-view.lua" &
      cleanup_commands+=$'\n'"kill $! 2>/dev/null"
    else
      recording_mode="screen only"
    fi
    
    #record screen
    recorder_command() { #define a function, so this can easily be re-run later for pause/resume with a different $intermediate_output_file
      wf-recorder -y -f "$intermediate_output_file" -m matroska -c libx264 -p preset=ultrafast "${recorder_flags[@]}" &
      internal_recorder_pid=$!
      trap "kill -INT $internal_recorder_pid 2>/dev/null" EXIT
      wait $internal_recorder_pid
    }
    recorder_command &
    recorder_pid=$!
    
  elif [ ! -z "$webcam" ];then
    recording_mode="webcam only"
    #webcam only recording mode
    rm -f /tmp/mjpeg_pipe
    mkfifo /tmp/mjpeg_pipe || exit 1

    #use mjpeg if the webcam supports it, for optimal preview performance
    if v4l2-ctl --device="$webcam" --list-formats-ext | grep -q MJPG ;then
      ffmpeg_webcam_input_flags+=(-input_format mjpeg)
    fi

    # Determine input mapping: If audio is enabled, pulse is input 0 and webcam is input 1.
    if [ "$capturing_audio" == TRUE ];then
      v_map="1:v"
      a_args=(-map 0:a -c:a aac)
    else
      v_map="0:v"
      a_args=() # Empty array, no audio mapping or codec needed
    fi

    recorder_command() { #define a function, so this can easily be re-run later for pause/resume with a different $intermediate_output_file
      #set to true to encode as mjpeg (no conversion), otherwise encode as h264
      if false;then
        ffmpeg "${ffmpeg_main_flags[@]}" "${ffmpeg_audio_flags[@]}" -y -f v4l2 "${ffmpeg_webcam_input_flags[@]}" -i "$webcam" \
        -map "$v_map" "${a_args[@]}" -c:v copy "$intermediate_output_file" \
        -f mpegts /tmp/mjpeg_pipe &>/dev/null &
      else
        if [ $mode == normal ];then
          #record webcam mode: encode as h264 for file, keep original mjpeg stream for mpv preview; make the preview pipe non-fatal, so recording continues if the preview window is closed
          ffmpeg "${ffmpeg_main_flags[@]}" "${ffmpeg_audio_flags[@]}" -y -f v4l2 "${ffmpeg_webcam_input_flags[@]}" -i "$webcam" \
          -map "$v_map" "${a_args[@]}" -c:v libx264 -preset ultrafast -crf $crf -f matroska "$intermediate_output_file" \
          -map "$v_map" -c:v copy -an -f matroska >(trap '' PIPE; tee /tmp/mjpeg_pipe >/dev/null) &
        elif [ $mode == preview ];then
          #just do webcam preview only - avoid encoding data for /dev/null, and here we want to stop streaming when mpv closes
          ffmpeg "${ffmpeg_main_flags[@]}" -y -f v4l2 "${ffmpeg_webcam_input_flags[@]}" -i "$webcam" \
          -map "$v_map" -c:v copy -an -f matroska /tmp/mjpeg_pipe &
        fi
      fi
      internal_recorder_pid=$!
      trap "kill -INT $internal_recorder_pid 2>/dev/null" EXIT
      wait $internal_recorder_pid
    }
    recorder_command &
    recorder_pid=$!
    
    #still show webcam: --loop-playlist=inf makes it stay open and resume playback after ffmpeg is restarted from a pause/resume event
    mpv /tmp/mjpeg_pipe "${mpv_flags[@]}" "${hflip_flag[@]}" --title="BSR webcam feed" --no-audio --profile=low-latency --untimed=yes --video-latency-hacks=yes --wayland-disable-vsync=yes --autofit=1280x720 --script="${DIRECTORY}/webcam-view.lua" \
      --loop-playlist=inf &
    mpv_pid=$!
    cleanup_commands+=$'\n'"kill $mpv_pid 2>/dev/null
    rm -f /tmp/mjpeg_pipe"
    
  elif [ "$capturing_audio" == TRUE ];then
    recording_mode="audio only"
    #audio only recording mode
    if [ $mode == normal ];then
      recorder_command() { #define a function, so this can easily be re-run later for pause/resume with a different $intermediate_output_file
        ffmpeg "${ffmpeg_main_flags[@]}" "${ffmpeg_audio_flags[@]}" -y -c:a aac -f matroska "$intermediate_output_file" &
        internal_recorder_pid=$!
        trap "kill -INT $internal_recorder_pid 2>/dev/null" EXIT
        wait $internal_recorder_pid
      }
      recorder_command &
      recorder_pid=$!
    elif [ $mode == preview ];then
      #preview audio stereo graph with minimum latency
      ffmpeg "${ffmpeg_main_flags[@]}" "${ffmpeg_audio_flags[@]}" -fflags nobuffer -flags low_delay -flush_packets 1 -probesize 32 -analyzeduration 0 -f s16le -ac 2 -ar 48000 - | \
        mpv - --demuxer=rawaudio --demuxer-rawaudio-channels=2 --demuxer-rawaudio-rate=48000 --demuxer-rawaudio-format=s16le --demuxer-readahead-secs=0 \
        --audio-buffer=0 --speed=1.2 --untimed=yes --cache=no --no-osc --profile=low-latency --video-latency-hacks=yes --wayland-disable-vsync=yes \
        --autofit=1280x720 --vf=fps=15 --mute=yes --video=no --really-quiet --title="BSR audio preview" \
        --lavfi-complex="[aid1]asplit[ao][a]; color=c=black:s=1280x720 [bg];
          [a]showwaves=s=1280x720:mode=cline:colors=#00ff66|#00ff66:r=15:split_channels=1:scale=log:draw=full [vol];
          [bg][vol]overlay=x=(W-w)/2:y=(H-h)/2 [vo]" &
      recorder_pid=$!
    fi
    
  else
    yad "${yadflags[@]}" --text="<b><big>Error</big></b>\nRefusing to record nothing. :)" \
      --button=Close:0
    continue #go back to start of the loop; no cleanup necessary
  fi
  status "BSR recording mode: $recording_mode"
  
  cleanup_commands+=$'\n'"kill -INT $recorder_pid 2>/dev/null"
  trap "$cleanup_commands" EXIT
  
  #handle normal recording mode
  if [ $mode == normal ];then
    
    #handle pause/resume: ffmpeg and wf-recorder desync audio and video, and the video freezes if the process is stopped and continued.
    #As a workaround, pausing kills the recorder and resuming starts another recording, then they are all stitched together.
    
    pause_function() { #in yad process: handle pause button click events - get current state from the label, then change the label to the other state while toggling pause
      if [ "$1" == "▶ Recording" ];then
        echo "pause requested" 1>&2
        echo -n 2:"⏸ Paused"
      else
        echo "resume requested" 1>&2
        echo -n 2:"▶ Recording"
      fi
      #wait for main process to notify that the operation was completed
      cat "$yad_communication_fifo" >/dev/null
    }
    export -f pause_function #make this function available to yad
    
    merge_pause_fragment() { #in main process: function used in 2 places to merge a second pause-fragment video file with the main video file
      if [ -f "${intermediate_output_file}.pausefrag" ];then
        #use ffmpeg concat filter to merge the videos
        if echo "file $intermediate_output_file"$'\n'"file ${intermediate_output_file}.pausefrag" | ffmpeg -y -f concat -safe 0 -i /dev/stdin -c copy -f matroska "${intermediate_output_file}.tmp";then
          #remove both original files, rename this file to the original filename
          rm -f "$intermediate_output_file" "${intermediate_output_file}.pausefrag"
          mv "${intermediate_output_file}.tmp" "$intermediate_output_file"
        else
          error "failed to join video file fragments from pausing! Your main video file is saved to: $intermediate_output_file Your last pause segment is saved to: ${intermediate_output_file}.pausefrag"
        fi
      fi
    }
    
    currently_paused=no
    
    #make a communication pipe to cause a delay between clicking pause, and the status message updating in yad
    yad_communication_fifo="$(mktemp -u)"
    mkfifo "$yad_communication_fifo" #make named pipe
    cleanup_commands+=$'\n'"rm $yad_communication_fifo"
    export yad_communication_fifo #let pause_function see it
    
    while read -t 1 line || true ;do #read input from yad, but also iterate this loop once every second as a watchdog
      echo "loop received line: $line"
      if [ -z "$line" ];then
        #line is empty due to 1-second read time limit - watchdog mode: check if recorder crashed, and warn the user if so
        if [ $currently_paused == no ] && ! process_exists $recorder_pid ;then
          #recorder crashed: cleanup, display an error, exit script
          eval "$cleanup_commands"
          yad "${yadflags[@]}" --text="<b><big>Error</big></b>\nRecording stopped :(\nRun BSR in a terminal to see what the error was." \
            --image=media-record --image-on-top --form \
            --button=Close:0
          exit 1
        fi
        
      else #received non-empty line
        case "$line" in
          'yad stopped')
            status "Stopping recording and saving file..."
            
            # Send a single interrupt signal and wait for FFmpeg to finish saving the file
            kill -INT $recorder_pid 2>/dev/null
            wait $recorder_pid 2>/dev/null
            
            #if the just-recorded video is a pause-fragment, concatenate it to the end of the main video
            merge_pause_fragment
            
            # Run the remaining cleanup commands (PulseAudio, mpv)
            eval "$cleanup_commands"
            
            # Clear the variable so the eval at the bottom of the loop doesn't double-kill
            cleanup_commands="" 
            break
            ;;
          YAD_PID=*)
            #remember the yad pid in this parent process so we can kill it later
            yadpid="$(echo "$line" | awk -F= '{print $2}')"
            ;;
          'pause requested')
            #user clicked pause button in yad
            
            #stop recording
            kill -INT $recorder_pid
            wait $recorder_pid 2>/dev/null
            
            #if the just-recorded video is a pause-fragment, concatenate it to the end of the main video
            merge_pause_fragment
            
            currently_paused=yes #disable the recorder crash watchdog, as we intend for it to be stopped
            
            #notify yad that recording is paused
            echo > "$yad_communication_fifo"
            ;;
          'resume requested')
            
            #start recording again, this time to our pause-fragment filename
            intermediate_output_file="${intermediate_output_file}.pausefrag" recorder_command &
            recorder_pid=$! #remember this new recorder pid
            
            currently_paused=no #enable the recorder crash watchdog
            
            #notify yad that recording is resumed
            echo > "$yad_communication_fifo"
            
            #fix edge case in webcam-only mode: if ffmpeg is restarted and mpv preview was already closed, it will block recording to the file.
            #detect this situation and flush the preview pipe to allow successful recording
            if [ ! -z "$mpv_pid" ] && ! process_exists "$mpv_pid" ;then
              cat /tmp/mjpeg_pipe >/dev/null &
              mpv_pid=$!
              cleanup_commands+=$'\n'"kill $mpv_pid 2>/dev/null"
            fi
            ;;
        esac
      fi
      
    done < <(yad "${yadflags[@]}" --text="<b><big>Botspot's Screen Recorder:</big></b>\nRecording $recording_mode" \
      --image=media-record --image-on-top --form \
      --field='Pause recording!media-playback-pause-symbolic':FBTN '@bash -c "pause_function %2"' \
      --field=:RO '▶ Recording' \
      --field=$'\n<big>                      Stop recording                      </big>\n':FBTN 'bash -c "kill $YAD_PID"' --no-buttons 2>&1 & YAD_PID=$!; echo "YAD_PID=$YAD_PID"; wait $YAD_PID; echo 'yad stopped')
    
    if { [ "$reencode" == TRUE ] && [ ! -z "$screen$webcam" ]; } || [ "$file_extension" != "mkv" ];then
      # process the output file
      if [ "$reencode" == TRUE ] && [ ! -z "$screen$webcam" ] && [[ "$file_extension" =~ ^(mp4|mkv)$ ]];then
        conversion_message="Optimizing video and saving as $file_extension..."
      else
        conversion_message="Converting video to $file_extension..."
      fi
      status "$conversion_message"
      
      ffmpeg_post_flags=()
      if [[ "$file_extension" =~ ^(mp3|wav)$ ]]; then
        ffmpeg_post_flags+=(-vn)
      else
        if [ "$reencode" == TRUE ] && [ ! -z "$screen$webcam" ] && [[ "$file_extension" =~ ^(mp4|mkv)$ ]];then
          ffmpeg_post_flags+=(-c:v libx264 -preset slower -crf $crf)
        elif [ ! -z "$screen$webcam" ] && [[ "$file_extension" =~ ^(mp4|mkv)$ ]]; then
          ffmpeg_post_flags+=(-c:v copy)
        fi
        
        if [[ "$file_extension" =~ ^(gif|webp)$ ]]; then
          ffmpeg_post_flags+=(-loop 0)
        fi
        if [[ "$file_extension" == "webp" ]]; then
          # -lossless 0 is strictly required to prevent OOM memory crashes.
          ffmpeg_post_flags+=(-c:v libwebp -lossless 0 -compression_level 4 -q:v 50 -loop 0)
        elif [[ "$file_extension" == "gif" ]]; then
          # generate optimal palette for high quality gif colors
          ffmpeg_post_flags+=(-loop 0 -filter_complex "split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse")
        fi
        if [[ "$file_extension" =~ ^(mp4|mkv)$ ]]; then
          ffmpeg_post_flags+=(-c:a copy)
        else
          ffmpeg_post_flags+=(-an)
        fi
      fi
      
      ffmpeg "${ffmpeg_main_flags[@]}" -nostats -progress /dev/stdout -y -i "$intermediate_output_file" \
        "${ffmpeg_post_flags[@]}" "$output_file" | \
        while read line ;do
          if [[ "$line" == out_time=* ]];then
            echo -e '\f'
            echo "Processing progress: $line" | sed 's/out_time=//g'
          elif [ "$line" == progress=end ];then
            before_size="$(wc -c "$intermediate_output_file" 2>/dev/null | awk '{print $1}')"
            after_size="$(wc -c "$output_file" 2>/dev/null | awk '{print $1}')"
            [ -z "$before_size" ] && before_size=1
            [ -z "$after_size" ] && after_size=1
            echo -e '\f'
            if [ "$before_size" -lt "$after_size" ];then
              echo "File processed from $(echo "$before_size" | numfmt --to=iec)B to $(echo "$after_size" | numfmt --to=iec)B - a $((after_size*100/before_size-100))% size increase." | tee /dev/stderr
            else
              echo "File processed from $(echo "$before_size" | numfmt --to=iec)B to $(echo "$after_size" | numfmt --to=iec)B - a $((100-after_size*100/before_size))% reduction!" | tee /dev/stderr
            fi
            echo "You can close this window now."
          fi
        done | yad "${yadflags[@]}" --text="$conversion_message" --width=600 --text-info --wrap --tail --back=black --fore='#00ccff' --button=Close:0
      if [ ${PIPESTATUS[0]} == 0 ] && [ -s "$output_file" ];then
        #video was successfully processed
        status "Processing complete; removing temporary file $intermediate_output_file"
        rm -f "$intermediate_output_file"
      else
        #video was unsuccessfully processed
        error "Processing the file failed! Please refer to errors above. Your raw video is saved to $intermediate_output_file"
      fi
    else
      #no re-encoding needed, and format is mkv
      mv -f "$intermediate_output_file" "$output_file"
    fi
    
  #handle preview mode
  elif [ $mode == preview ];then
    yad "${yadflags[@]}" --text="<b><big>Botspot's Screen Recorder:</big></b>\nPreviewing $recording_mode" \
      --image=view-reveal-symbolic --image-on-top --form \
      --field=$'\n<big>                      Stop previewing                      </big>\n':FBTN 'bash -c "kill $YAD_PID"' --no-buttons &
    yadpid=$!
    
    #only preview the screen
     #don't launch a duplicate webcam preview in webcam-only mode
      #audio-only preview is handled in the recording section
    if [ ! -z "$screen" ];then
      mpv /tmp/preview_pipe --title="BSR screen preview" --ao=null --audio-file=av://lavfi:anullsrc \
        --mc=0 --msg-level=all=error --framedrop=vo \
        --demuxer-lavf-o=fflags=+nobuffer --demuxer-readahead-secs=0 --cache=no --no-osc \
        --profile=low-latency --video-latency-hacks=yes \
        --autofit=1280x720 --script="${DIRECTORY}/webcam-view.lua" &
      mpvpid=$!
    fi
    #stop the preview when yad or the recorder stops
    wait -n $recorder_pid $yadpid
    kill $mpvpid $yadpid 2>/dev/null
  fi
  
  #between loop repeats, ensure A/V processes and pulse sinks are cleaned up
  eval "$cleanup_commands"
  
done
