# Botspot's Screen Recorder (BSR)
Best all-in-one screen recording utility for Wayland
- Super lightweight
- Just one shell script
- Aligns with KISS principles
- Optimized for low-spec Single Board Computers that lack GPU-accelerated video encoding

Enough fiddling with all the other poorly optimized Wayland screen recorders missing critical features. BSR is better.  

Currently, BSR can be used to:
- Record the screen and webcam. The webcam feed can be paused, resized, and moved in real time. Double-click the webcam feed to toggle fullscreen.
- Record only the screen.
- Record only the webcam.
- Record only audio.
- Capture both the system's speaker output and microphone input, or any combination of the two.
- Choose what area of the screen to record (crop feature)
- Downscale the recorded screen by a factor of 2. For example, a 1920x1080 screen can be encoded as a 960x540 video file to reduce filesize and CPU usage.

![20250214_07h20m18s_grim](https://github.com/user-attachments/assets/e904c7cb-cd17-440c-acee-5f91a058946f)
![20250214_07h25m33s_grim](https://github.com/user-attachments/assets/85b010e0-c973-4db9-b14f-3561c8b36f6f)
### Supported systems:
- Anything running Wayland. X11 is not supported. Go use SimpleScreenRecorder on X11.
- For audio capture, your system needs to be running PipeWire on top of Pulseaudio. If your system only uses Pulseaudio, contact me and I can try to see how possible it is to add support for your setup. It should be easy.
- This should run great on any modern Raspberry Pi OS distro, but should be cross-platform to run on any CPU architecture and modern distro without problems.

### Debian packages to install
None. The script installs them for you. For the sake of completeness, here they are:
```
slurp ffmpeg ninja-build git meson mpv yad g++ wlr-randr v4l-utils wayland-protocols libavutil-dev libavfilter-dev libavdevice-dev libavcodec-dev libavformat-dev libswscale-dev libpulse-dev libgbm-dev libpipewire-0.3-dev libdrm-dev
```
### Download and run:
```
git clone https://github.com/Botspot/botspot-screen-recorder
./botspot-screen-recorder/screen-recorder.sh
```

### Usage
1. Run the script
2. Choose your options and click Next
3. Stop the recording when done.
4. Profit.
5. Your settings are saved to `~/.config/botspot-screen-recorder.conf` for next time.

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
This is meant to become the SimpleScreenRecorder for Wayland. Contact me if you want to see a feature or option added, or if anything is not working as expected.

### Notable open source projects used in BSR:
- [MPV](https://github.com/mpv-player/mpv) for the on-screen webcam feed
- [wf-recorder](https://github.com/ammen99/wf-recorder) for recording the screen
- [ffmpeg](https://ffmpeg.org/) used in the background for conversion and encoding

### How long did it take to write BSR?
Just one night of coding nonstop instead of sleeping. From start to finish it was roughly 9 hours to write these 300 lines of shell script.
