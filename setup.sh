#!/data/data/com.termux/files/usr/bin/sh

MODE=""
BRANCH="merged"

# Installer
INSTALL_SSHD=""
INSTALL_EVENTS="" # this doesn't do anything yet
NO_AUTOSTART=""
NO_INPUT=""
SKIP_UNINSTALL=0
SKIP_WYOMING=0
SKIP_OWW=0
SKIP_SQUEEZELITE=0
INTERACTIVE=0

# Config
SELECTED_WAKE_WORD="ok_nabu"
SELECTED_DEVICE_NAME=""
HASS_TOKEN=""
HASS_URL="http://homeassistant.local:8123"

# Wake sounds
SELECTED_WAKE_SOUND="./sounds/awake.wav"
SELECTED_DONE_SOUND="./sounds/done.wav"
SELECTED_TIMER_DONE_SOUND="./sounds/timer_finished.wav"
SELECTED_TIMER_REPEAT="5 0.5"

for i in "$@"; do
  case $i in
    --wake-word=*)
      SELECTED_WAKE_WORD="${i#*=}"
      shift
      ;;
    --device-name=*)
      SELECTED_DEVICE_NAME="${i#*=}"
      shift
      ;;
    --wake-sound=*)
      SELECTED_WAKE_SOUND="${i#*=}"
      shift
      ;;
    --done-sound=*)
      SELECTED_DONE_SOUND="${i#*=}"
      shift
      ;;
    --timer-finished-sound=*)
      SELECTED_TIMER_DONE_SOUND="${i#*=}"
      shift
      ;;
    --timer-finished-repeat=*)
      SELECTED_TIMER_REPEAT="${i#*=}"
      shift
      ;;
    --branch=*)
      BRANCH="${i#*=}"
      shift
      ;;
    --hass-token=*)
      HASS_TOKEN="${i#*=}"
      shift
      ;;
    --hass-url=*)
      HASS_URL="${i#*=}"
      shift
      ;;
    --install)
      MODE="INSTALL"
      shift
      ;;
    --uninstall)
      MODE="UNINSTALL"
      shift
      ;;
    --configure)
      MODE="CONFIGURE"
      shift
      ;;
    --no-autostart)
      NO_AUTOSTART=1
      shift
      ;;
    --skip-cleanup)
      SKIP_UNINSTALL=1
      shift
      ;;
    --skip-wyoming)
      SKIP_WYOMING=1
      shift
      ;;
    --skip-wakeword)
      SKIP_OWW=1
      shift
      ;;
    --skip-squeezelite)
      SKIP_SQUEEZELITE=1
      shift
      ;;
    --install-ssh)
      INSTALL_SSHD=1
      shift
      ;;
    --install-events)
      INSTALL_EVENTS=1
      shift
      ;;
    -q)
      NO_INPUT=1
      shift
      ;;
    -i)
      INTERACTIVE=1
      shift
      ;;
    -*|--*)
      echo "Unknown option $i"
      exit 1
      ;;
    *)
      ;;
  esac
done

echo "Mode: $BRANCH"

preinstall () {
    echo "Running pre-install"
    echo "Enter home directory"
    cd ~

    echo "Update packages and index"
    pkg up

    echo "Ensure wget is available..."
    if ! command -v wget > /dev/null 2>&1; then
        echo "Installing wget..."
        pkg install wget -y
        if ! command -v wget > /dev/null 2>&1; then
            echo "ERROR: Failed to install wget" >&2
            exit 1
        fi
    fi

    echo "Ensure Python + pip is available..."
    if ! command -v python3 > /dev/null 2>&1; then
        echo "Installing python..."
        pkg install python python-pip -y
        if ! command -v python3 > /dev/null 2>&1; then
            echo "ERROR: Failed to install python3" >&2
            exit 1
        fi
    fi

    echo "Ensure git is available..."
    if ! command -v git > /dev/null 2>&1; then
        echo "Installing git..."
        pkg install git -y
        if ! command -v git > /dev/null 2>&1; then
            echo "ERROR: Failed to install git" >&2
            exit 1
        fi
    fi

    echo "Ensure Termux Services is available..."
    if ! command -v sv-enable > /dev/null 2>&1; then
        echo "Installing service bus..."
        pkg install termux-services -y
        if ! command -v sv-enable > /dev/null 2>&1; then
            echo "ERROR: Failed to install termux-services" >&2
            exit 1
        else
            echo "Termux Services has been installed. Restart Termux to continue."
            exit 1
        fi
    fi

    echo "Ensure termux-api is available..."
    if ! command -v termux-microphone-record > /dev/null 2>&1; then
        echo "Installing termux-api..."
        pkg install termux-api -y
        if ! command -v termux-microphone-record > /dev/null 2>&1; then
            echo "ERROR: Failed to install termux-api (termux-microphone-record not found)" >&2
            exit 1
        fi
    fi

    echo "Ensure sox is available..."
    if ! command -v rec > /dev/null 2>&1; then
        echo "Installing sox..."
        pkg install sox -y
        if ! command -v rec > /dev/null 2>&1; then
            echo "ERROR: Failed to install sox (rec not found)" >&2
            exit 1
        fi
        if ! command -v play > /dev/null 2>&1; then
            echo "ERROR: Failed to install sox (play not found)" >&2
            exit 1
        fi
    fi

    if [ "$SKIP_UNINSTALL" = "0" ]; then
        echo "Clean up potential garbage that might otherwise get in the way..."
        cleanup
    fi

}

install_ssh () {
    pkg install openssh -y
    sshd
}

install_squeezelite () {
    echo "allow-external-apps=true" >> ~/.termux/termux.properties
    pkg install squeezelite -y
    echo "Squeezelite installed"
}

install_events () {
    mkdir -p ~/wyoming-events
    wget "https://raw.githubusercontent.com/pantherale0/wyoming-satellite-termux/refs/heads/$BRANCH/wyoming-events.py" -O ~/wyoming-events/wyoming-events.py
    echo "Configuring events"
    python3 -m pip install wyoming aiohttp # ensure required libs are installed
    sed -i "s|^export EVENTS_ENABLED=.*$|export EVENTS_ENABLED=true|" $PREFIX/var/service/wyoming/run
    sed -i "s|^export HASS_TOKEN=.*$|export HASS_TOKEN=\"$HASS_TOKEN\"|" $PREFIX/var/service/wyoming/run
    sed -i "s|^export HASS_URL=.*$|export HASS_URL=\"$HASS_URL\"|" $PREFIX/var/service/wyoming/run
}

configure () {
    echo "Configuring Wyoming options..."
    sed -i "s|^export CUSTOM_DEV_NAME=.*$|export CUSTOM_DEV_NAME=\"$SELECTED_DEVICE_NAME\"|g" $PREFIX/var/service/wyoming/run 
    sed -i "s|^export WAKESOUND=.*$|export WAKESOUND=\"$SELECTED_WAKE_SOUND\"|g" $PREFIX/var/service/wyoming/run
    sed -i "s|^export DONESOUND=.*$|export DONESOUND=\"$SELECTED_DONE_SOUND\"|g" $PREFIX/var/service/wyoming/run
    sed -i "s|^export TIMERFINISHEDSOUND=.*|export TIMERFINISHEDSOUND=\"$SELECTED_TIMER_DONE_SOUND\"|g" $PREFIX/var/service/wyoming/run
    sed -i "s|^export TIMERFINISHEDREPEAT=.*$|export TIMERFINISHEDREPEAT=\"$SELECTED_TIMER_REPEAT\"|g" $PREFIX/var/service/wyoming/run

    echo "Configuring OpenWakeWord..."
    # OWW
    sed -i "s/^export SELECTED_WAKE_WORD=.*$/export SELECTED_WAKE_WORD=\"$SELECTED_WAKE_WORD\"/" $PREFIX/var/service/wyoming/run
    if [ "$SKIP_OWW" = "0" ]; then
        sed -i 's/^export OWW_ENABLED=.*$/export OWW_ENABLED=true/' $PREFIX/var/service/wyoming/run
    fi
}

cleanup () {
    echo "Stopping and killing any remaining Wyoming instances"
    sv down wyoming
    killall python3
    sv-disable wyoming

    echo "Deleting files and directories related to the project..."
    rm -f ~/tmp.wav
    rm -f ~/pulseaudio-without-memfd.deb 
    rm -f ~/.termux/boot/services-autostart
    rm -rf $PREFIX/var/service/wyoming
    rm -rf ~/wyoming-satellite
    rm -rf ~/wyoming-openwakeword

    echo "Removing squeezelite"
    pkg remove squeezelite -y
    sv down squeezelite
    sv-disable squeezelite
    rm -rf $PREFIX/var/service/squeezelite
}

uninstall () {
    echo "Uninstalling custom pulseaudio build if it is installed..."
    if command -v pulseaudio > /dev/null 2>&1; then
        export ARCH="$(termux-info | grep -A 1 "CPU architecture:" | tail -1)" 
        echo "Architecture: $ARCH"
        if [ "$ARCH" = "arm" ]; then
            pkg remove -y pulseaudio
        fi
    fi

    if [ "$MODE" = "UNINSTALL" ]; then
        if command -v sv > /dev/null 2>&1; then
            echo "Would you like to remove Termux Services? [y/N]"
            read remove_services
            if [ "$remove_services" = "y" ] || [ "$remove_services" = "Y" ]; then
                pkg uninstall termux-services -y
            fi
        fi
    fi
}

install () {
    if [ "$NO_INPUT" = "" ]; then
        echo "At the end of this process a full reboot is recommended, ensure your device is completely powered down before starting back up"
        echo "This is to ensure that the require wakelocks will start correctly"
        echo "Press enter to continue, alternative press Q to exit"
        read quit
        if [ "$quit" = "q" ] || [ "$quit" = "Q" ]; then
            exit 0
        fi
    fi

    if [ "$HASS_URL" = "" ] && [ "$INSTALL_EVENTS" = "1" ]; then
        echo "Missing --hass-url parameter"
        echo "This argument is required with --install-events"
        exit 2
    fi

    if [ "$HASS_TOKEN" = "" ] && [ "$INSTALL_EVENTS" = "1" ]; then
        echo "Missing --hass-token parameter"
        echo "This argument is required with --install-events"
        exit 2
    fi

    preinstall

    echo "Starting a wakelock"
    termux-wake-lock

    echo "Checking if Linux kernel supports memfd..."
    KERNEL_MAJOR_VERSION="$(uname -r | awk -F'.' '{print $1}')"
    if [ $KERNEL_MAJOR_VERSION -le 3 ]; then
        echo "Your kernel is too old to support memfd."
        echo "Installing a custom build of pulseaudio that doesn't depend on memfd..."
        export ARCH="$(termux-info | grep -A 1 "CPU architecture:" | tail -1)"
        echo "Checking if pulseaudio is currently installed..."
        if command -v pulseaudio > /dev/null 2>&1; then
            echo "Uninstalling pulseaudio..."
            pkg remove pulseaudio -y
        fi
        echo "Downloading pulseaudio build that doesn't require memfd..."
        wget -O ./pulseaudio-without-memfd.deb "https://github.com/T-vK/pulseaudio-termux-no-memfd/releases/download/1.1.0/pulseaudio_17.0-2_${ARCH}.deb"
        echo "Installing the downloaded pulseaudio build..."
        pkg install ./pulseaudio-without-memfd.deb -y
        echo "Removing the downloaded pulseaudio build (not required after installation)..."
        rm -f ./pulseaudio-without-memfd.deb
    else
        if ! command -v pulseaudio > /dev/null 2>&1; then
            pkg install pulseaudio -y
        fi
    fi

    if ! command -v pulseaudio > /dev/null 2>&1; then
        echo "ERROR: Failed to install pulseaudio..." >&2
        exit 1
    fi

    echo "Starting test recording to trigger mic permission prompt..."
    echo "(It might ask you for mic access now. Select 'Always Allow'.)"
    termux-microphone-record -f ./tmp.wav

    echo "Quitting the test recording..."
    termux-microphone-record -q

    echo "Deleting the test recording..."
    rm -f ./tmp.wav

    echo "Temporarily load PulseAudio module for mic access..."
    if ! pactl list short modules | grep "module-sles-source" ; then
        if ! pactl load-module module-sles-source; then
            echo "ERROR: Failed to load module-sles-source" >&2
        fi
    fi

    echo "Verify that there is at least one microphone detected..."
    if ! pactl list short sources | grep "module-sles-source.c" ; then
        echo "ERROR: No microphone detected" >&2
    fi

    if [ "$SKIP_WYOMING" = "0" ]; then
        echo "Cloning Wyoming Satellite repo..."
        git clone https://github.com/rhasspy/wyoming-satellite.git

        echo "Enter wyoming-satellite directory..."
        cd wyoming-satellite

        echo "Injecting faulthandler" # https://community.home-assistant.io/t/how-to-run-wyoming-satellite-and-openwakeword-on-android/777571/101?u=11harveyj
        sed -i '/_LOGGER = logging.getLogger()/a import faulthandler, signal' wyoming_satellite/__main__.py
        sed -i '/import faulthandler, signal/a faulthandler.register(signal.SIGSYS)' wyoming_satellite/__main__.py

        echo "Running Wyoming Satellite setup script..."
        echo "This process may appear to hang on low spec hardware. Do not exit unless you are sure that that the process is no longer responding"
        ./script/setup
        cd ..

        echo "Write down the IP address (most likely starting with '192.') of your device, you should find it in the following output, press enter once complete:"
        ifconfig | grep 'inet'
        if [ "$NO_INPUT" = "" ]; then
            read
        fi

        echo "Setting up autostart..."
        mkdir -p ~/.termux/boot/
        wget -P ~/.termux/boot/ "https://raw.githubusercontent.com/pantherale0/wyoming-satellite-termux/refs/heads/$BRANCH/services-autostart"
        chmod +x ~/.termux/boot/services-autostart

        echo "Setting up wyoming service..."
        mkdir -p $PREFIX/var/service/wyoming/
        touch $PREFIX/var/service/wyoming/down # ensure the service does not start when we kill runsv
        mkdir -p $PREFIX/var/service/wyoming/log
        ln -sf $PREFIX/share/termux-services/svlogger $PREFIX/var/service/wyoming/log/run
        wget "https://raw.githubusercontent.com/pantherale0/wyoming-satellite-termux/refs/heads/$BRANCH/wyoming-satellite-android" -O $PREFIX/var/service/wyoming/run
        chmod +x $PREFIX/var/service/wyoming/run

        configure

        # events
        if [ "$INSTALL_EVENTS" = "1" ]; then
            echo "Events enabled"
            install_events
        fi

        echo "Wyoming service installed. Restarting runsv"
        killall runsv
        echo "Waiting for runsv to restart"
        sleep 5
        echo "Successfully installed and set up Wyoming Satellite"
    fi

    if [ "$SKIP_OWW" = "0" ]; then
        echo "Selected $SELECTED_WAKE_WORD"
        echo "Ensure python-tflite-runtime, ninja and patchelf are installed..."
        pkg install python-tflite-runtime ninja patchelf -y
        echo "Cloning Wyoming OpenWakeWord repo..."
        cd ~
        git clone https://github.com/rhasspy/wyoming-openwakeword.git
        echo "Enter wyoming-openwakeword directory..."
        cd wyoming-openwakeword
        echo "Allow system site packages in Wyoming OpenWakeWord setup script..."
        sed -i 's/\(builder = venv.EnvBuilder(with_pip=True\)/\1, system_site_packages=True/' ./script/setup
        echo "Running Wyoming OpenWakeWord setup script..."
        ./script/setup
        cd ..
    fi

    if [ "$SKIP_SQUEEZELITE" = "0" ]; then
        install_squeezelite
        echo "Setting up squeezelite service..."
        mkdir -p $PREFIX/var/service/squeezelite/
        touch $PREFIX/var/service/squeezelite/down # ensure the service does not start until we are ready
        mkdir -p $PREFIX/var/service/squeezelite/log
        ln -sf $PREFIX/share/termux-services/svlogger $PREFIX/var/service/squeezelite/log/run
        wget "https://raw.githubusercontent.com/pantherale0/wyoming-satellite-termux/refs/heads/$BRANCH/squeezelite-android" -O $PREFIX/var/service/squeezelite/run
        chmod +x $PREFIX/var/service/squeezelite/run
        sed -i "s|^export CUSTOM_DEV_NAME=.*$|export CUSTOM_DEV_NAME=\"$SELECTED_DEVICE_NAME\"|g" $PREFIX/var/service/squeezelite/run 
        sv-enable squeezelite
    fi

    if [ "$INSTALL_SSHD" = "1" ]; then
        echo "Installing SSH server"
        install_ssh
        echo "SSH Server installed, running on port 8022"
    fi

    if [ "$NO_AUTOSTART" = "" ]; then
        echo "Starting Wyoming service now..."
        killall python3 # ensure no processes are running before starting the service
        sv up wyoming
    fi
    sv-enable wyoming
}

if [ "$MODE" = "INSTALL" ]; then

    install
    echo "Install complete"
    if [ "$NO_INPUT" = "" ]; then
        echo "Install is now complete, the rest of the configuration can be performed in the Home Assistant UI"
        echo "-----"
        echo "Setup the Wyoming platform (see readme for information). Use the IP address noted earlier with"
        echo "Port: 10700 (Wyoming Satellite)"
        echo "If you configured the event forwarder, these will be available under 'wyoming_*'"
        echo "-----"
        echo "Press enter to continue"
        read
        echo "Device options can now be set in the Home Assistant UI"
        echo "-----"
        echo "Recommended settings*"
        echo "-----"
        echo "Lenovo ThinkSmart View"
        echo "Mic Volume: 5.0"
        echo "Noise Suppression Level: Medium"
        echo "-----"
        echo "Surface Go 2 (BlissOS 15)"
        echo "Mic Volume: 3.0"
        echo "Noise Suppresion Level: Medium"
        echo "-----"
        echo "Press enter to exit"
        read
    fi
    exit 0
fi

if [ "$MODE" = "UNINSTALL" ]; then
    cleanup
    uninstall
    echo "Uninstall complete"
    exit 0
fi

if [ "$MODE" = "CONFIGURE" ]; then
    configure
    echo "Reconfiguration complete"
    exit 0
fi

echo "Invalid mode specified, one of --install or --uninstall or --configure is required"
exit 1
