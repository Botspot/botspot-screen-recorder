# Botspot's Screen Recorder
Best all-in-one screen recording utility for Wayland - super lightweight, just one shell script

Enough fiddling with wf-recorder, this is built on top and is better.  
![20250214_07h20m18s_grim](https://github.com/user-attachments/assets/e904c7cb-cd17-440c-acee-5f91a058946f)
![20250214_07h25m33s_grim](https://github.com/user-attachments/assets/85b010e0-c973-4db9-b14f-3561c8b36f6f)
### Download and run:
```
git clone https://github.com/Botspot/botspot-screen-recorder
./botspot-screen-recorder/screen-recorder.sh
```
Required dependencies: (installed by the script on first run) `slurp ffmpeg git meson ninja-build mpv`  
Note: wf-recorder is compiled from source on first run.

This will soon be added to [Pi-Apps](https://github.com/Botspot/pi-apps) and a menu launcher will be added then. For now while this is in beta testing, just run it in a terminal to make troubleshooting easier if something does not function correctly.
# Feedback requested!!
This is meant to become the SimpleScreenRecorder for Wayland. Contact me if you want to see a feature or option added, or if anything is not working as expected.

Currently, Botspot's Screen Recorder can be used to:
- Record the screen and webcam. The webcam feed can be resized, paused, and moved in real time. Double-click the webcam feed to toggle fullscreen.
- Record only the screen.
- Record only the webcam.
- Record only audio.
- Capture both the system's speaker output and microphone input, or any combination of the two.
- Choose what part of the screen to record (crop feature)
- Downscale the recorded screen by a factor of 2. For example, a 1920x1080 screen recording can be saved as a 960x540 video file to reduce filesize and CPU usage.

Notable open source projects used in this project:
- [MPV](https://github.com/mpv-player/mpv) for the on-screen webcam feed
- [wf-recorder](https://github.com/ammen99/wf-recorder) for recording the screen
- [ffmpeg](https://ffmpeg.org/) for recording webcam only or audio only

How long did it take to write the code for this? Just one night of coding nonstop instead of sleeping. From start to finish it was roughly 9 hours.
