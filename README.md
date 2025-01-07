## Wyoming Satellite on Android

This project provides a simple way of setting up Wyoming Satellite, OpenWakeWord and Squeezelite on Android inside of Termux.

### Prerequisites

- Install [Termux](https://github.com/termux/termux-app) (open source terminal emulator app)
- Install [Termux:API](https://github.com/termux/termux-api) (necessary to get mic access)
- Install [Termux:Boot](https://github.com/termux/termux-boot) and [open it once + disable battery optimization for Termux & Termux:Boot](https://wiki.termux.com/wiki/Termux:Boot) (only required if you want wyoming-satellite to autostart when your device restarts)

Install Termux via F-Droid or from the GitHub APKs. The version on Google Play should be treated as an unofficial fork [Termux Play Store](https://github.com/termux/termux-app/discussions/4000) as not all features are available in this version due to Google Play publishing policies.

### How to install

For a default install, Open Termux and run:

``` Bash
(command -v wget > /dev/null 2>&1 || (echo "Installing wget..." && pkg install -y wget)) && bash <(wget -qO- https://raw.githubusercontent.com/pantherale0/wyoming-satellite-termux/refs/heads/merged/setup.sh) --install

```

The above script will configure dependancies and install Wyoming as a service inside of Termux. This will be set to auto start on boot.

A wakelock will be used to keep the services operational in the background.

The default parameters will:
1. Install Wyoming, OpenWakeWord and Squeezelite
2. Set the wake word to `Ok Nabu`
3. Set the Home Assistant device name to the make and model of the Android device.
4. Auto launch Wyoming and OpenWakeWord at the end of installation.

To customize this behaviour, see configuration parameters below.

### Command line parameters

`--install`: Install Wyoming and OpenWakeWord

`--uninstall`: Cleanup and uninstall Wyoming and OpenWakeWord

`--configure`: Reconfigure existing install with updated options

#### Configuration paramters

`--wake-word=<wake_word>`: Specify a wakeword to use (defaults to Ok Nabu), must be a supported wakeword by the OpenWakeWord project:
<pre>
    ok_nabu: Ok Nabu
    alexa: Alexa
    hey_mycroft: Hey Mycroft
    hey_jarvis: Hey Jarvis
    hey_rhasspy: Hey Rhasspy
</pre>

`--device-name=`: Specify a custom device name to use (defaults to make + model of device)

`--wake-sound=`: Full path to a wake sound file (played by the Satellite after using the wakeword). WAV file only.

`--done-sound=`: Full path to a sound file that is played by the satellite after you have finished speaking. WAV file only.

`--timer-finished-sound=`: Full path to a sound file that is played once a timer has finished. WAV file only

`--timer-finished-repeat=<repeats> <delay>`: Repeat the timer finished sound where <repeats> is the number of times to repeat the WAV, and <delay> is the number of seconds to wait between repeats.

#### Install parameters

`--skip-cleanup`: Skip running uninstall and cleanup during installation

`--skip-wyoming`: Skip installing the Wyoming Satellite

`--skip-wakeword`: Skip installing OpenWakeWord

`--skip-squeezelite`: Skip installing a Squeezelite player

`--install-ssh`: Install a SSH server (openssh) for remote commandline access

`--install-events`: Install a Wyoming event forwarder to broadcast events onto the Home Assistant event bus

`--no-autostart`: Don't start Wyoming at the end of installation

`-q`: Bypass additional prompts that require pressing the enter key to continue

#### Home Assistant Event Bus

NOT TESTED!

You can optionally install a forwarding service that will forward all Wyoming events onto the event bus.

The following parameters are required:

`--hass-url`: The local URL to your Home Assistant instance (for example, http://192.168.1.2:8123)

`--hass-token`: The [long lived access token](https://community.home-assistant.io/t/how-to-get-long-lived-access-token/162159/5?u=11harveyj) to access your Home Assistant instance

Logs will be available in the "wyoming-events.log" file

### How to uninstall

Open Termux and run:

``` Bash
bash <(wget -qO- https://raw.githubusercontent.com/pantherale0/wyoming-satellite-termux/refs/heads/merged/setup.sh) --uninstall
```

### Reconfigure install

Open Termux and run:
``` Bash
bash <(wget -qO- https://raw.githubusercontent.com/pantherale0/wyoming-satellite-termux/refs/heads/merged/setup.sh) --configure
```

Without any command line flags, the install will reset to a default state. See the configuration section above for supported flags.

### Integrate into HomeAssistant

- Click below link to setup Wyoming on Home Assistant

[![Open your Home Assistant instance and start setting up a new integration.](https://my.home-assistant.io/badges/config_flow_start.svg)](https://my.home-assistant.io/redirect/config_flow_start/?domain=wyoming)

- It should ask you for a host and a port now. Enter the IP address of your Android device into the host-field (if unsure what you IP is, run `ifconfig` in Termux and check the output, it will most likely start with `192.`) and enter 10700 in the port-field.

### Stopping / starting service

- To stop the service, run `sv down wyoming`
- To start the service, run `sv up wyoming`

### Using

As this is a Wyoming Satellite, you should be able to start using just by saying your wake word that you configured during setup, for example, say "Alexa, What is the time" and the device should pickup and respond using you default Assist pipeline in Home Assistant. 

The Assist pipeline can be changed in Home Assistant, look for the entity under Integrations > Wyoming > `Device Name` > Assistant

### Supported devices

- Lenovo ThinkSmart View
- Microsoft Surface Go 2 (BlissOS 15)
- Lenovo Smart Clock 2
