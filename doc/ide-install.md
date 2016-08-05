# IDE installation

See http://www.libelium.com/downloads/documentation/quickstart_guide.pdf

    # Install dependencies
    sudo apt-get install default-jre gcc-avr avr-libc

    # Download IDE
    sudo mkdir -p /opt/tarballs
    cd /opt/tarballs
    sudo wget http://downloads.libelium.com/waspmote-pro-ide-v04-linux64.zip
    
    # Install IDE
    sudo unzip waspmote-pro-ide-v04-linux64.zip
    sudo mv waspmote-pro-ide-v04-linux64 /opt/
    sudo chmod -R o+rx /opt/waspmote-pro-ide-v04-linux64

# Configure USB access

    usermod -a -G dialout lora

## Optional, grant access to USB device

First, check that product name is correct and equal to "FT232R USB UART".

    # See http://weininger.net/how-to-write-udev-rules-for-usb-devices.html
    sudo lsusb | grep "Future Technology" | cut -d":" -f1
    # returns "Bus 005 Device 005"
    PERIPH_PATH=$(udevadm info -q path -n /dev/bus/usb/005/005)
    sudo udevadm info -a -p "$PERIPH_PATH"

### Allow USB device access to 'lora' group
 
    sudo sh -c "echo 'SUBSYSTEMS==\"usb\", ATTRS{product}==\"FT232R USB UART\", GROUP=\"lora\"'" > /etc/udev/rules.d/10-local.rules
    sudo service udev restart
    # unplug and reboot the device
    sudo lsusb | grep "Future Technology" | cut -d":" -f1
    # returns "Bus 005 Device 006"
    ls -rtl /dev/bus/usb/005/006
    # returns "crw-rw-r-- 1 root lora 189, 517 Aug  5 13:04 /dev/bus/usb/005/006"

