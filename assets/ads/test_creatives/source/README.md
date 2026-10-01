# Biodynamic loading creative

`Biodynamic_SF_Mobile_Test_Ad_10s.mp4` is the original user-supplied creative,
received October 1, 2026. It is a 960 × 720, 30 fps, ten-second video with audio.
The source folder is excluded from Godot import/export by `.gdignore`.

The runtime copy is `../biodynamic_mobile_loading_10s.ogv`, encoded for the
existing Godot VideoStreamPlayer. The original framing and audio are retained;
the loading UI starts playback muted. Rebuild from the project root with:

```sh
ffmpeg -i assets/ads/test_creatives/source/Biodynamic_SF_Mobile_Test_Ad_10s.mp4 \
  -map 0:v:0 -map '0:a?' -c:v libtheora -q:v 8 -pix_fmt yuv420p \
  -c:a libvorbis -q:a 4 -y assets/ads/test_creatives/biodynamic_mobile_loading_10s.ogv
```

This is a Biodynamic Restoration video. The user specified
`https://www.biodynamicusa.com` as its destination. Tapping the ad copies that
URL to the clipboard without opening a browser.
