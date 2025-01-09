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
(command -v wget > /dev/null 2>&1 || (echo "Installing wget..." && pkg install -y wget)) && bash <(wget -qO- https://raw.githubusercontent.com/pantherale0/wyoming-satellite-termux/refs/heads/main/setup.sh)
```

The above script will display a GUI based installer for this suite of applications.

A wakelock will be used to keep the services operational in the background.

The default parameters will:
1. Install Wyoming, OpenWakeWord and Squeezelite
2. Set the wake word to `Ok Nabu`
3. Set the Home Assistant device name to the make and model of the Android device.
4. Auto launch Wyoming and OpenWakeWord at the end of installation.

### Command line parameters

`--install`: Install Wyoming and OpenWakeWord

`--uninstall`: Cleanup and uninstall Wyoming and OpenWakeWord

`--configure`: Reconfigure existing install with updated options

#### Configuration Parameters

* **`--wake-word=<wake_word>`:** Specify a wake word to use (defaults to "Ok Nabu"). 
    * Must be a supported wake word by the OpenWakeWord project:
        * `ok_nabu`
        * `alexa`
        * `hey_mycroft`
        * `hey_jarvis`
        * `hey_rhasspy` 

* **`--device-name=`:** Specify a custom device name to use (defaults to the make + model of the device).

* **`--wake-sound=`:** Full path to a wake sound file (played by the Satellite after using the wake word). 
    * Must be a WAV file.

* **`--done-sound=`:** Full path to a sound file that is played by the Satellite after you have finished speaking. 
    * Must be a WAV file.

* **`--timer-finished-sound=`:** Full path to a sound file that is played once a timer has finished.
    * Must be a WAV file.

* **`--timer-finished-repeat=<repeats> <delay>`:** 
    * Repeat the timer finished sound where:
        * `<repeats>` is the number of times to repeat the WAV.
        * `<delay>` is the number of seconds to wait between repeats. 

#### Install Parameters

* **`--skip-cleanup`:** Skip running uninstall and cleanup steps during installation.

* **`--skip-wyoming`:** Skip installing the Wyoming Satellite software itself.

* **`--skip-wakeword`:** Skip installing the OpenWakeWord engine used for wake word detection.

* **`--skip-squeezelite`:** Skip installing the Squeezelite player software.

* **`--install-ssh`:** Install an SSH server (openssh) to enable remote command-line access to the device.

* **`--install-events`:** Install a Wyoming event forwarder to broadcast events to the Home Assistant event bus.

* **`--no-autostart`:** Prevent Wyoming from automatically starting at the end of the installation process.

* **`-q`:** Bypass confirmation prompts that normally require pressing Enter to continue.

#### Home Assistant Event Bus

Optionally, you can install a service to forward Wyoming events to your Home Assistant instance's event bus.

**Required Parameters:**

* **`--hass-url`:** The local URL of your Home Assistant instance (e.g., http://192.168.1.2:8123).

* **`--hass-token`:** A [long-lived access token](https://community.home-assistant.io/t/how-to-get-long-lived-access-token/162159/5?u=11harveyj) to access your Home Assistant instance.

**Logs:**

* All Wyoming event forwarding logs will be recorded in the "wyoming-events.log" file.

#### Available events:

| Event Type | Event Description | Extra Event Data |
|---|---|---|
| wyoming_satellite-connected | Satellite has connected to Home Assistant | |
| wyoming_run-satellite | Satellite has started | |
| wyoming_streaming-stopped | Satellite has stopped streaming audio to or from Home Assistant | |
| wyoming_run-pipeline | Satellite has started a new pipeline run | |
| wyoming_detection | Wakeword detection event | `name`, `timestamp` |
| wyoming_streaming-started | Satellite has started to stream audio to or from Home Assistant | |
| wyoming_transcribe | Transcribe request started | `language` |
| wyoming_voice-started | Voice detected | |
| wyoming_voice-stopped | Voice finished | |
| wyoming_transcript | Transcribe response (intent) | `text` |
| wyoming_synthesize | Response from Assist Pipeline | `text`, `voice` |
| wyoming_audio-start | Audio playback started | `rate`, `width`, `channels`, `timestamp` |
| wyoming_audio-stop | Audio playback stopped | |
| wyoming_played | Audio playback finished | |

And any other event from Wyoming.

### How to uninstall

Open Termux and run:

``` Bash
bash <(wget -qO- https://raw.githubusercontent.com/pantherale0/wyoming-satellite-termux/refs/heads/main/setup.sh) --uninstall
```

### Reconfigure install

Open Termux and run:
``` Bash
bash <(wget -qO- https://raw.githubusercontent.com/pantherale0/wyoming-satellite-termux/refs/heads/main/setup.sh) --configure
```

Without any command line flags, the install will reset to a default state. See the configuration section above for supported flags.

### Integrate into HomeAssistant

- Click below link to setup Wyoming on Home Assistant

[![Open your Home Assistant instance and start setting up a new integration.](https://my.home-assistant.io/badges/config_flow_start.svg)](https://my.home-assistant.io/redirect/config_flow_start/?domain=wyoming)

- It should ask you for a host and a port now. Enter the IP address of your Android device into the host-field (if unsure what you IP is, run `ifconfig` in Termux and check the output, it will most likely start with `192.`) and enter 10700 in the port-field.

### Stopping / starting service

- To stop the service, run `wyoming-cli --stop`
- To start the service, run `wyoming-cli --start`

### Using

As this is a Wyoming Satellite, you should be able to start using just by saying your wake word that you configured during setup, for example, say "Alexa, What is the time" and the device should pickup and respond using you default Assist pipeline in Home Assistant. 

The Assist pipeline can be changed in Home Assistant, look for the entity under Integrations > Wyoming > `Device Name` > Assistant

### Supported devices

- Lenovo ThinkSmart View
- Microsoft Surface Go 2 (BlissOS 15)
- Lenovo Smart Clock 2
