# Volume Bar Theme

A small rooted LG webOS app that replaces the native volume bar with the CleanYourTV Pill, Capsule or Dial theme. For `external_arc`, the displayed number comes from `com.webos.service.eim/getArcVolume`; the audio master service supplies mute and output state.

Requires a rooted TV with Homebrew Channel and ARC/eARC volume reporting. Open the app, choose a theme and select Enable. Disable restores the LG volume OSD setting saved during setup.

Build: `sh scripts/package.sh`
