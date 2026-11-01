# LG webOS Volume Bar

A rooted LG webOS app that replaces the stock volume display with a selectable Pill, Capsule or Dial style. With HDMI ARC active, the displayed level is read from `com.webos.service.eim/getArcVolume`; the audio service provides output and mute state.

## Install

Build the Homebrew Channel package with `node tools/build-pages.js` followed by `python3 ipk/build.py`, then install the generated IPK from the Homebrew Channel. Open **LG webOS Volume Bar**, choose **Set up now**, then open **Settings → Experimental → Volume bar** to choose a style. **System default** restores LG's original OSD.

The installer keeps LG Home unchanged. The service starts at boot. Uninstall from the app to restore the saved OSD setting and remove the service.

Requires a rooted LG webOS 5 or newer TV with Homebrew Channel. ARC level reporting depends on firmware and the connected sound device. This package has not been verified on every TV.
