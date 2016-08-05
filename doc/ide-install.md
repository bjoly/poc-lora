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
