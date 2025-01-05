## Wyoming Satellite on Android

This project provides a simple way of setting up Wyoming Satellite and OpenWakeWord on Android.

### Prerequisites

- Install [Termux](https://github.com/termux/termux-app) (open source terminal emulator app)
- Install [Termux:API](https://github.com/termux/termux-api) (necessary to get mic access)
- (Optional) Install [Termux:Boot](https://github.com/termux/termux-boot) and [open it once + disable battery optimization for Termux & Termux:Boot](https://wiki.termux.com/wiki/Termux:Boot) (only required if you want wyoming-satellite to autostart when your device restarts)

### How to install

Open Termux and run:

``` Bash
(command -v wget > /dev/null 2>&1 || (echo "Installing wget..." && pkg install -y wget)) && bash <(wget -qO- https://raw.githubusercontent.com/pantherale0/wyoming-satellite-termux/refs/heads/main/install.sh)

```

The above script will configure dependancies and install Wyoming as a service inside of Termux. This will be set to auto start on boot.

A wakelock will be used to keep the services operational in the background.

### Command line parameters

`--skip-uninstall`: Skip running uninstall and cleanup during installation
`--skip-wyoming`: Skip installing the Wyoming Satellite
`--skip-wakeword`: Skip installing OpenWakeWord
`--wakeword=...`: Specify a wakeword to use
`--device-name=`: Specify a custom device name to use (defaults to make + model of device)

### How to uninstall

Open Termux and run:

``` Bash
wget -qO- https://raw.githubusercontent.com/pantherale0/wyoming-satellite-termux/refs/heads/main/uninstall.sh | bash
```

### Integrate into HomeAssistant

- Click below link to setup Wyoming on Home Assistant

[![Open your Home Assistant instance and start setting up a new integration.](https://my.home-assistant.io/badges/config_flow_start.svg)](https://my.home-assistant.io/redirect/config_flow_start/?domain=wyoming)

- It should ask you for a host and a port now. Enter the IP address of your Android device into the host-field (if unsure what you IP is, run `ifconfig` in Termux and check the output, it will most likely start with `192.`) and enter 10700 in the port-field.

- You may need to do this again if you have setup openwakeword, instead of port "10700" use port "10400"

### Stopping / starting service

- To stop the service, run `sv down wyoming`
- To start the service, run `sv up wyoming`

### Using

As this is a Wyoming Satellite, you should be able to start using just by saying your wake word that you configured during setup, for example, say "Alexa, What is the time" and the device should pickup and respond using you default Assist pipeline in Home Assistant. 

The Assist pipeline can be changed in Home Assistant, look for the entity under Integrations > Wyoming > `Device Name` > Assistant
