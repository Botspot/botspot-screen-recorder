# Botspot's Screen Recorder (BSR)
Best all-in-one GUI screen recording utility for wlroots-based Wayland compositors like Wayfire, LabWC and Sway.
- Super lightweight
- Just one shell script
- Aligns with KISS principles
- Optimized for hardware like Raspberry Pi that lacks GPU-accelerated video encoding

Enough fiddling with the other poorly maintained screen recorders missing critical features. BSR is better.  

BSR has flexible input sources.
- Video sources:
  - Record the screen and webcam. The webcam feed is displayed in a window that is captured in the screen recording.
  - Record only the screen.
  - Record only the webcam directly using ffmpeg.
  - Record no video. (only audio)
- Audio sources:
  - Capture both system output audio and microphone input.
  - Capture only system audio.
  - Capture only microphone input.
  - Capture no audio. (only video)
- Video processing options:
  - Record a user-selected section of the screen. (crop feature)
  - Mirror the webcam feed.
  - Limit the screen recording frame rate.
  - Downscale the recorded screen by a factor of 2. For example, a 1920x1080 screen can be encoded as a 960x540 video file to reduce filesize and CPU usage.

### Screenshots:
![20250214_07h20m18s_grim](https://github.com/user-attachments/assets/13bd37ee-caf4-41cd-b6da-44ac329c73e6)  
![20250214_21h52m07s_grim](https://github.com/user-attachments/assets/2a4be825-a981-4a59-883c-47c6dc4bfe16)

### Supported systems:
- Any distro using a [Wayland wlroots-based compositor](https://github.com/solarkraft/awesome-wlroots?tab=readme-ov-file#compositors).
- For audio capture, your system needs to be running PipeWire on top of Pulseaudio. If your system only uses Pulseaudio, contact me and I can try to see how possible it is to add support for your setup. It should be easy.

### Download and run:
```
git clone https://github.com/Botspot/botspot-screen-recorder
./botspot-screen-recorder/screen-recorder.sh
```

### Debian packages to install:
None. The script installs them for you. For the sake of completeness, here they are: (most of these are just used to compile wf-recorder)
```
slurp ffmpeg ninja-build git meson mpv yad g++ wlr-randr v4l-utils wayland-protocols libavutil-dev libavfilter-dev libavdevice-dev libavcodec-dev libavformat-dev libswscale-dev libpulse-dev libgbm-dev libpipewire-0.3-dev libdrm-dev
```
### Arch support:
I don't use Arch, but in theory you just need to install `slurp ffmpeg mpv yad wlr-randr v4l-utils wf-recorder` from wherever you install packages from.

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
  - If you are using the LabWC compositor, press Alt+Space then click Always on Top.
  - If you are using Wayfire I am not aware of an easy way to do this.

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
