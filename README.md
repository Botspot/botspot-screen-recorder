# Botspot's Screen Recorder (BSR)
All-in-one screen recording utility for wlroots Wayland compositors like Wayfire, LabWC and Sway.  
[![badge](https://github.com/Botspot/pi-apps/blob/master/icons/badge.png?raw=true)](https://github.com/Botspot/pi-apps)  
Botspot Screen Recorder (BSR) makes it easy to record the screen on Wayland Pi OS. Without this, the only real option was to use the `wf-recorder` command-line tool, which was quite limited in features.  
BSR does use `wf-recorder` in some modes, but it can also record the webcam and the screen at the same time in a "streaming gamer" style. The webcam feed is displayed as a window on the desktop to be captured with the rest of the screen, and it can be stretched and moved in real time. BSR also supports capturing the microphone and system audio both at once, so perfect for making any sort of Linux usage tutorials without needing to buy a physical HDMI capture card.  
Of course, video encoding does use some CPU/GPU resources. There is no way around that, but BSR has been optimized as much as possible, also offering downscaling and framerate limiting to help reduce resource usage even further.  
BSR is:
- Super lightweight
- Just one shell script
- Aligned with KISS principles
- Optimized for hardware like Raspberry Pi that lacks hardware accelerated video encoding

BSR has flexible operation modes.

|  | Screen + Webcam |  Screen only | Webcam only | None |
| -- | -- | -- | -- | -- |
| **System Audio** | `✅` Supported | `✅` Supported | `✅` Supported | `✅` Supported |
| **Microphone** | `✅` Supported | `✅` Supported | `✅` Supported | `✅` Supported |
| **Both** | `✅` Supported | `✅` Supported | `✅` Supported | `✅` Supported |
| **None** | `✅` Supported | `✅` Supported | `✅` Supported |  |

- Video processing options:
  - Record a fixed rectanglular section of the screen. (crop feature)
  - Mirror the webcam feed.
  - Custom screen recording frame rate.
  - Custom video quality (high/medium/low)
  - Downscale the output video by a factor of 2. For example, a 1920x1080 screen or webcam can be encoded as 960x540 video file to reduce filesize and CPU usage.
  - Reduce video file size by 60% without quality reduction, by re-encoding the video file with libx264's `slower` compression preset.

### Screenshots:
![20250214_07h20m18s_grim](https://github.com/user-attachments/assets/13bd37ee-caf4-41cd-b6da-44ac329c73e6)  
![20250214_21h52m07s_grim](https://github.com/user-attachments/assets/98e93cd5-e1d2-4b29-a862-587b6f10ac77)


### Supported systems:
- Any distro using a [Wayland wlroots-based compositor](https://github.com/solarkraft/awesome-wlroots?tab=readme-ov-file#compositors).
- For audio capture, your system needs to be running PipeWire on top of Pulseaudio. If your system only uses Pulseaudio, contact me and I can try to see how possible it is to add support for your setup. It should be easy.

### Download and run:
```
git clone https://github.com/Botspot/botspot-screen-recorder
./botspot-screen-recorder/screen-recorder.sh
```
On first run, BSR adds a convenient launcher to the start menu. To remove it from the start menu, run `rm ~/.local/share/applications/bsr.desktop`

### Debian packages to install:
None. The script installs them for you. For the sake of completeness, here they are: (most of these are just used to compile wf-recorder)
```
slurp ffmpeg ninja-build git meson mpv yad g++ wlr-randr v4l-utils wayland-protocols libavutil-dev libavfilter-dev libavdevice-dev libavcodec-dev libavformat-dev libswscale-dev libpulse-dev libgbm-dev libpipewire-0.3-dev libdrm-dev
```
### Arch support:
[This user](https://forums.raspberrypi.com/viewtopic.php?p=2316250&sid=98556ae27fa88a9adb8a26c0adc58165#p2316250) says this command works on Arch:  
If BSR detects all necessary packages are installed, it should not try to use apt to install anything. Let me know otherwise.
```
sudo pacman -S --needed ffmpeg gcc git meson mpv ninja slurp v4l-utils wf-recorder wlr-randr yad
```

### Usage
1. Run the script.
2. Choose your options and click Start recording.
3. Stop the recording when done.
4. Profit.
5. Your chosen presets are saved to `~/.config/botspot-screen-recorder.conf` for next time.

### Tips for using the on-screen webcam feed
- It can be paused using the pause button in the middle of the window.
- It can be resized and moved in real time. Click and drag anywhere on the window to move it.
- Double-click the webcam feed to toggle fullscreen. Press Escape to exit fullscreen.
- To keep the webcam feed visible above other windows, use your Wayland compositor to do it.
  - If you are using the LabWC compositor, press Alt+Space, then click Always on Top.
  - If you are using Wayfire, I am not aware of an easy way to do this. :(

### Update to latest version
```
cd botspot-screen-recorder
git pull
```
Once this is not in beta, this will be added to [Pi-Apps](https://github.com/Botspot/pi-apps) and updates will be handled automatically then.

### Command-line flags
There are no command line flags. Go directly use wf-recorder for that. If you think I should add a new option, let me know.

### Keyboard shortcuts
This is an open discussion. Would you find it useful to launch/start/stop BSR using keyboard shortcuts? Let me know.

# Feedback requested!!
This is meant to become the SimpleScreenRecorder for wlroots. Contact me if you want to see a feature or option added, or if anything is not working as expected.

### Notable open source projects used in BSR:
- [MPV](https://github.com/mpv-player/mpv) for the on-screen webcam feed
- [wf-recorder](https://github.com/ammen99/wf-recorder) for recording the screen
- [ffmpeg](https://ffmpeg.org/) used in the background for conversion and encoding

### How long did it take to write BSR?
Just one night of coding nonstop instead of sleeping. From start to finish it was roughly 9 hours to write these 300 lines of shell script.
