# Volume Bar Theme

A standalone LG webOS app built from CleanYourTV's volume-theme renderer and ARC volume handling. It includes only the Pill, Capsule and Dial volume themes and the small runtime needed to display them.

For `external_arc`, the app follows CleanYourTV's `helper/audio.js` behavior: `com.webos.service.audio/master/getVolume` supplies output and mute state, while `com.webos.service.eim/getArcVolume` supplies the displayed soundbar volume. Other outputs use the master audio volume.

Requires a rooted TV with Homebrew Channel and ARC volume reporting. Open the app, choose a theme and select **Enable**. The app saves the current LG volume OSD setting before hiding it; **Disable** restores that saved setting.

Build the IPK with `sh scripts/package.sh`.
