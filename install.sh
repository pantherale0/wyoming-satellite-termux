#!/data/data/com.termux/files/usr/bin/sh

SKIP_UNINSTALL=0

for i in "$@"; do
  case $i in
    --skip-uninstall)
      SKIP_UNINSTALL=1
      shift # past argument with no value
      ;;
    -*|--*)
      echo "Unknown option $i"
      exit 1
      ;;
    *)
      ;;
  esac
done

echo "At the end of this process a full reboot is recommended, ensure your device is completely powered down before starting back up"
echo "This is to ensure that the require wakelocks will start correctly"
echo "Press enter to continue, alternative press Q to exit"
read quit
if [ "$quit" = "q" ] || [ "$quit" = "Q" ]; then
    exit 1
fi

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

if [ "$SKIP_UNINSTALL" = "0" ]; then
    echo "Clean up potential garbage that might otherwise get in the way..."
    wget -qO- https://raw.githubusercontent.com/pantherale0/wyoming-satellite-termux/refs/heads/main/uninstall.sh | bash
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

echo "Ensure termux-api is available..."
if ! command -v termux-microphone-record > /dev/null 2>&1; then
    echo "Installing termux-api..."
    pkg install termux-api -y
    if ! command -v termux-microphone-record > /dev/null 2>&1; then
        echo "ERROR: Failed to install termux-api (termux-microphone-record not found)" >&2
        exit 1
    fi
fi

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
if ! command -v sv > /dev/null 2>&1; then
    echo "Installing service bus..."
    pkg install termux-services -y
    if ! command -v sv > /dev/null 2>&1; then
        echo "ERROR: Failed to install termux-services" >&2
        exit 1
    fi
fi

echo "Cloning Wyoming Satellite repo..."
git clone https://github.com/rhasspy/wyoming-satellite.git

echo "Enter wyoming-satellite directory..."
cd wyoming-satellite

echo "Running Wyoming Satellite setup script..."
echo "This process may appear to hang on low spec hardware. Do not exit unless you are sure that that the process is no longer responding"
./script/setup
cd ..

echo "Write down the IP address (most likely starting with '192.') of your device, you should find it in the following output, press enter once complete:"
ifconfig | grep 'inet'
read

echo "Setting up autostart..."
mkdir -p ~/.termux/boot/
wget -P ~/.termux/boot/ "https://raw.githubusercontent.com/pantherale0/wyoming-satellite-termux/refs/heads/main/services-autostart"
chmod +x ~/.termux/boot/services-autostart

echo "Setting up wyoming service..."
mkdir -p $PREFIX/var/service/wyoming/
wget -P $PREFIX/var/service/wyoming/ "https://raw.githubusercontent.com/pantherale0/wyoming-satellite-termux/refs/heads/main/wyoming-satellite-android" -O run
chmod +x $PREFIX/var/service/wyoming/run
sv enable wyoming

echo "Would you like to set a custom device name? [y/N]"
read setup_device_name
if [ "$setup_device_name" = "y" ] || [ "$setup_device_name" = "Y" ]; then
    echo "Provide the full name and press enter"
    read device_name
    sed -i "s/^export CUSTOM_DEV_NAME=false$/export CUSTOM_DEV_NAME=$device_name/" $PREFIX/var/service/wyoming/run 
fi

echo "Successfully installed and set up Wyoming Satellite"
echo "Install Wyoming OpenWakeWord as well? [y/N]"
read install_oww
if [ "$install_oww" = "y" ] || [ "$install_oww" = "Y" ]; then
    echo "Select the wake word you would like to use:"
    echo "1. Ok Nabu *"
    echo "2. Alexa"
    echo "3. Hey Mycroft"
    echo "4. Hey Jarvis"
    echo "5. Hey Rhasspy"
    read wake_word_option
    SELECTED_WAKE_WORD=""
    if [ "$wake_word_option" = "1" ] || ["$wake_word_option" = "" ]; then
        SELECTED_WAKE_WORD="ok_nabu"
    elif [ "$wake_word_option" = "2" ]; then
        SELECTED_WAKE_WORD="alexa"
    elif [ "$wake_word_option" = "3" ]; then
        SELECTED_WAKE_WORD="hey_mycroft"
    elif [ "$wake_word_option" = "4" ]; then
        SELECTED_WAKE_WORD="hey_jarvis"
    elif [ "$wake_word_option" = "5" ]; then
        SELECTED_WAKE_WORD="hey_rhasspy"
    fi
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
    echo "Ensuring OpenWakeWord is enabled..."
    sed -i 's/^export OWW_ENABLED=false$/export OWW_ENABLED=true/' $PREFIX/var/service/wyoming/run 
    echo "Setting configured wakeword..."
    sed -i "s/^export SELECTED_WAKE_WORD=false$/export SELECTED_WAKE_WORD=$SELECTED_WAKE_WORD" $PREFIX/var/service/wyoming/run
    cd ..
    echo "Launch Wyoming OpenWakeWord and Wyoming Satellite now? [y/N]"
else
    echo "Launch Wyoming Satellite now? [y/N]"
fi

read launch_now
if [ "$launch_now" = "y" ] || [ "$launch_now" = "Y" ]; then
    echo "Starting Wyoming service now..."
    sv up wyoming
fi

clear
echo "Install is now complete, the rest of the configuration can be performed in the Home Assistant UI"
echo "-----"
echo "Setup the Wyoming platform (see readme for information). Use the IP address noted earlier with"
echo "Port: 10700 (Wyoming Satellite service itself)"
echo "Port: 10400 (Wyoming OpenWakeWord, this may not be required)"
echo "-----"
echo "Press enter to continue"
read
clear
echo "Device options can now be set in the Home Assistant UI"
echo "-----"
echo "Recommended settings*"
echo "-----"
echo "Lenovo ThinkSmart View"
echo "Mic Volume: 5.0"
echo "Noise Suppression Level: Medium"
echo "-----"
echo "Press enter to exit"
read