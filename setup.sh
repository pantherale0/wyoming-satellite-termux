#!/data/data/com.termux/files/usr/bin/sh

: ${DIALOG=dialog}
: ${DIALOG_OK=0}
: ${DIALOG_CANCEL=1}
: ${DIALOG_ESC=255}
INTERACTIVE_TITLE="Home Assistant Voice Termux Installer"

MODE=""
BRANCH="main"

# Installer
INSTALL_SSHD=""
INSTALL_EVENTS=""
NO_AUTOSTART=""
NO_INPUT=""
SKIP_UNINSTALL=0
INSTALL_WYOMING=1
INSTALL_OWW=1
INSTALL_SQUEEZELITE=1
INTERACTIVE=1

# Config
SELECTED_WAKE_WORD="ok_nabu"
SELECTED_DEVICE_NAME=""
HASS_TOKEN=""
HASS_URL="http://homeassistant.local:8123"
WYOMING_SATELLITE_FLAGS="--debug"

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
      INSTALL_WYOMING=0
      shift
      ;;
    --skip-wakeword)
      INSTALL_OWW=0
      shift
      ;;
    --skip-squeezelite)
      INSTALL_SQUEEZELITE=0
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

echo "Branch: $BRANCH"

interactive_prompts () {
    ### Prompt to select options to install
    INSTALL_WYOMING=0
    INSTALL_OWW=0
    INSTALL_SQUEEZELITE=0
    INSTALL_EVENTS=0
    INSTALL_SSHD=0
    MODE="INSTALL"
    declare -a INSTALL_OPTS=($($DIALOG --backtitle "$INTERACTIVE_TITLE" \
    --clear \
	--title "Install Options" \
    --checklist "Select options to install" 15 90 5 \
            1   "Core Wyoming Satellite service." ON \
            2   "OpenWakeWord to trigger the Assist pipeline locally on device." ON \
            3   "Squeezelite to play your favourite tunes." ON \
            4   "Event forwarder to expose Wyoming Events into Home Assistant." OFF \
            5   "SSH Server to access Termux from another device." OFF 2>&1 >/dev/tty))

    for sel in "${INSTALL_OPTS[@]}"; do
        case "$sel" in
            1) INSTALL_WYOMING=1;;
            2) INSTALL_OWW=1;;
            3) INSTALL_SQUEEZELITE=1;;
            4) INSTALL_EVENTS=1;;
            5) INSTALL_SSHD=1;;
            *) echo "Unknown option!";;
        esac
    done

    if $DIALOG --stdout --title "Autostart" \
            --backtitle "$INTERACTIVE_TITLE" \
            --yesno "Enable related services to start automatically on boot?" 7 60; then
        NO_AUTOSTART=0
        $DIALOG --title "Autostart" --backtitle "$INTERACTIVE_TITLE" --msgbox "Autostart will be enabled" 6 44
    else
        NO_AUTOSTART=1
        $DIALOG --title "Autostart" --backtitle "$INTERACTIVE_TITLE" --msgbox "You will need to start services manually" 6 44
    fi

    if [ "$INSTALL_WYOMING" = "1" ]; then
        $DIALOG --title "Wyoming Configuration" --backtitle "$INTERACTIVE_TITLE" --msgbox "Satellite will be installed" 6 44
        SELECTED_WAKE_WORD=$($DIALOG --stdout --title "Wyoming Configuration" \
            --backtitle "$INTERACTIVE_TITLE" \
            --radiolist "Wakeword" 50 50 5 \
            "alexa" "Alexa" OFF \
            "ok_nabu" "Ok Nabu" ON \
            "hey_mycroft" "Hey Mycroft" OFF \
            "hey_jarvis" "Hey Jarvis" OFF \
            "hey_rhasspy" "Hey Rhasspy" OFF)
        SELECTED_DEVICE_NAME=$($DIALOG --stdout --title "Wyoming Configuration" --backtitle "$INTERACTIVE_TITLE" --inputbox "Enter a name for your device\nIt must not include spaces if the event forwarder is being installed\nExample: wyoming_kitchen_assistant" 15 50)
        WYOMING_SATELLITE_FLAGS=$($DIALOG --stdout --title "Wyoming Configuration" --backtitle "$INTERACTIVE_TITLE" --inputbox "Enter additional Wyoming Satellite startup flags" 15 50 "$WYOMING_SATELLITE_FLAGS")
    fi

    if [ "$INSTALL_EVENTS" = "1" ]; then
        $DIALOG --title "Events Configuration" --backtitle "$INTERACTIVE_TITLE" --msgbox "Events will be installed\nThe following prompts will ask for details about your Home Assistant install" 15 50
        HASS_URL=$($DIALOG --stdout --title "Events Configuration" --backtitle "$INTERACTIVE_TITLE" --inputbox "Enter the URL of your Home Assistant install" 15 50 "$HASS_URL")
        HASS_TOKEN=$($DIALOG --stdout --title "Events Configuration" --backtitle "$INTERACTIVE_TITLE" --inputbox "Enter the acces token from Home Assistant\nThis can be copied into this prompt." 15 50)
    fi
}

interactive_post_install () {
    MESSAGE=$(cat << EOF
Install is now complete, the rest of the configuration can be performed in the Home Assistant UI
-----
Setup the Wyoming platform (see readme for information). Use the IP address noted earlier with
Port: 10700 (Wyoming Satellite)
If you configured the event forwarder, these will be available under 'wyoming_*'
-----
Device options can now be set in the Home Assistant UI
-----
Recommended device settings*
-----
Lenovo ThinkSmart View
Mic Volume: 5.0
Noise Suppression Level: Medium
-----
Surface Go 2 (BlissOS 15)
Mic Volume: 3.0
Noise Suppression Level: Medium
-----
Press enter to exit
EOF
)
    $DIALOG --title "Installation Completed" --backtitle "$INTERACTIVE_TITLE" --msgbox "$MESSAGE" 20 60
    clear
}

interactive_ip_addr () {
    MESSAGE=$(ifconfig | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")
    $DIALOG --title "IP Address" --backtitle "$INTERACTIVE_TITLE" --msgbox "$MESSAGE" 20 60
    clear
}

preinstall () {
    echo "Running pre-install"
    echo "Enter home directory"
    cd ~

    touch wyoming.conf

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

    echo "Installing Wyoming CLI"
    wget "https://raw.githubusercontent.com/pantherale0/wyoming-satellite-termux/refs/heads/$BRANCH/scripts/wyoming-cli" -O $PREFIX/bin/wyoming-cli
    chmod a+x $PREFIX/bin/wyoming-cli
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
    make_service "wyoming-events" "wyoming-events-android"
    echo "EVENTS_ENABLED=true" >> $HOME/wyoming.conf
    echo "HASS_TOKEN=\"$HASS_TOKEN\"" >> $HOME/wyoming.conf
    echo "HASS_URL=\"$HASS_URL\"" >> $HOME/wyoming.conf
}

configure () {
    echo "Configuring Wyoming options..."
    echo "CUSTOM_DEV_NAME=\"$SELECTED_DEVICE_NAME\"" >> $HOME/wyoming.conf
    echo "WAKESOUND=\"$SELECTED_WAKE_SOUND\"" >> $HOME/wyoming.conf
    echo "DONESOUND=\"$SELECTED_DONE_SOUND\"" >> $HOME/wyoming.conf
    echo "TIMERFINISHEDSOUND=\"$SELECTED_TIMER_DONE_SOUND\"" >> $HOME/wyoming.conf
    echo "TIMERFINISHEDREPEAT=\"$SELECTED_TIMER_REPEAT\"" >> $HOME/wyoming.conf
    echo "WYOMING_SATELLITE_FLAGS=\"$WYOMING_SATELLITE_FLAGS\"" >> $HOME/wyoming.conf

    echo "Configuring OpenWakeWord..."
    # OWW
    echo "SELECTED_WAKE_WORD=\"$SELECTED_WAKE_WORD\"" >> $HOME/wyoming.conf
    if [ "$INSTALL_OWW" = "1" ]; then
        echo "OWW_ENABLED=true" >> $HOME/wyoming.conf
    else
        echo "OWW_ENABLED=" >> $HOME/wyoming.conf
    fi
}

cleanup () {
    echo "Stopping and killing remaining services"
    sv-disable wyoming-satellite
    sv-disable wyoming-wakeword
    sv-disable wyoming-events
    sv-disable squeezelite
    killall python3

    echo "Deleting files and directories related to the project..."
    rm -f ~/tmp.wav
    rm -f ~/pulseaudio-without-memfd.deb 
    rm -f ~/.termux/boot/services-autostart
    rm -rf ~/wyoming-satellite
    rm -rf ~/wyoming-openwakeword

    echo "Removing squeezelite"
    pkg remove squeezelite -y

    echo "Removing services"
    rm -rf $PREFIX/var/service/wyoming-*
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

make_service () {
    # Helper to make a new service
    local SVC_NAME="$1"
    local SVC_RUN_FILE="$2"
    echo "Setting up $SVC_NAME service..."
    mkdir -p $PREFIX/var/service/$SVC_NAME/
    touch $PREFIX/var/service/$SVC_NAME/down # ensure the service does not start when we kill runsv
    mkdir -p $PREFIX/var/service/$SVC_NAME/log
    ln -sf $PREFIX/share/termux-services/svlogger $PREFIX/var/service/$SVC_NAME/log/run
    wget "https://raw.githubusercontent.com/pantherale0/wyoming-satellite-termux/refs/heads/$BRANCH/services/$SVC_RUN_FILE" -O $PREFIX/var/service/$SVC_NAME/run
    chmod +x $PREFIX/var/service/$SVC_NAME/run
    echo "Installed $SVC_NAME service"
}

install () {
    if [ "$NO_INPUT" = "" ]; then
        MESSAGE=$(cat << EOF
At the end of this process a full reboot is recommended, ensure your device is completely powered down before starting back up
This is to ensure that the require wakelocks will start correctly
EOF
)
        $DIALOG --backtitle "$INTERACTIVE_TITLE" --msgbox "$MESSAGE" 20 60
        clear
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

    if [ "$INSTALL_WYOMING" = "1" ]; then
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

        if [ "$NO_INPUT" = "" ]; then
            interactive_ip_addr
        fi

        echo "Setting up autostart..."
        mkdir -p ~/.termux/boot/
        wget -P ~/.termux/boot/ "https://raw.githubusercontent.com/pantherale0/wyoming-satellite-termux/refs/heads/$BRANCH/boot/services-autostart"
        chmod +x ~/.termux/boot/services-autostart

        make_service "wyoming-satellite" "wyoming-satellite-android"

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

    if [ "$INSTALL_OWW" = "1" ]; then
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
        make_service "wyoming-wakeword" "wyoming-wakeword-android"
    fi

    if [ "$INSTALL_SQUEEZELITE" = "1" ]; then
        install_squeezelite
        echo "Setting up squeezelite service..."
        make_service "squeezelite" "squeezelite-android"
    fi

    if [ "$INSTALL_SSHD" = "1" ]; then
        echo "Installing SSH server"
        pkg install openssh -y
    fi

    if [ "$NO_AUTOSTART" = "" ]; then
        echo "Starting services now..."
        killall python3 # ensure no processes are running before starting the service
        sv-enable sshd
        sv-enable wyoming-wakeword
        sv-enable wyoming-events
        sv-enable wyoming-satellite
        sv-enable squeezelite
    fi
}

if [ "$MODE" = "" ] && [ "$INTERACTIVE" = "1" ]; then
    preinstall
    interactive_prompts
fi

if [ "$MODE" = "INSTALL" ]; then

    install
    echo "Install complete"
    if [ "$INTERACTIVE" = "1" ]; then
        interactive_post_install
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
