#!/data/data/com.termux/files/usr/bin/sh

echo "Stopping and killing any remaining Wyoming instances"
sv down wyoming
killall python3
sv-disable wyoming

echo "Deleting files and directories related to the project..."
rm -f ~/tmp.wav
rm -f ~/pulseaudio-without-memfd.deb 
rm -rf $PREFIX/var/service/wyoming
rm -rf ~/wyoming-satellite
rm -rf ~/wyoming-openwakeword

echo "Uninstalling custom pulseaudio build if it is installed..."
if command -v pulseaudio > /dev/null 2>&1; then
    export ARCH="$(termux-info | grep -A 1 "CPU architecture:" | tail -1)" 
    echo "Architecture: $ARCH"
    if [ "$ARCH" = "arm" ] ; then
        pkg remove -y pulseaudio
    fi
fi

echo "Would you like to remove Termux Services? [y/N]"
read remove_services
if [ "$remove_services" = "y" ] || [ "$remove_services" = "Y" ]; then
    rm -f ~/.termux/boot/services-autostart
    pkg uninstall termux-services -y
fi

echo "Done"
