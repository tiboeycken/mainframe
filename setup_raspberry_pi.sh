#!/bin/bash
################################################################################
# OpsDash Raspberry Pi Setup Script
# This script automates the complete setup of OpsDash on a Raspberry Pi
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
OPSDASH_DIR="$HOME/opsdash"
STREAMLIT_PORT=8501
STREAMLIT_ADDRESS="0.0.0.0"  # Allow access from network

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     OpsDash Raspberry Pi Setup Script                     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if running on Raspberry Pi
if [ ! -f /proc/device-tree/model ] || ! grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
    echo -e "${YELLOW}Warning: This doesn't appear to be a Raspberry Pi. Continue anyway? (y/n)${NC}"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Update system
echo -e "${GREEN}[1/8] Updating system packages...${NC}"
sudo apt-get update
sudo apt-get upgrade -y

# Install system dependencies
echo -e "${GREEN}[2/8] Installing system dependencies...${NC}"
sudo apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    curl \
    git \
    build-essential \
    libffi-dev \
    libssl-dev \
    dbus-x11 \
    gnome-keyring \
    unclutter \
    xdotool \
    x11-xserver-utils

# Install Node.js (required for Zowe CLI)
echo -e "${GREEN}[3/8] Installing Node.js...${NC}"
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
else
    echo -e "${YELLOW}Node.js already installed: $(node --version)${NC}"
fi

# Verify Node.js installation
if ! command -v node &> /dev/null; then
    echo -e "${RED}Error: Node.js installation failed${NC}"
    exit 1
fi

echo -e "${GREEN}Node.js version: $(node --version)${NC}"
echo -e "${GREEN}npm version: $(npm --version)${NC}"

# Install Zowe CLI
echo -e "${GREEN}[4/8] Installing Zowe CLI...${NC}"
if ! command -v zowe &> /dev/null; then
    sudo npm install -g @zowe/cli@zowe-v2-lts
else
    echo -e "${YELLOW}Zowe CLI already installed: $(zowe --version)${NC}"
fi

# Verify Zowe CLI installation
if ! command -v zowe &> /dev/null; then
    echo -e "${RED}Error: Zowe CLI installation failed${NC}"
    exit 1
fi

# Setup OpsDash directory
echo -e "${GREEN}[5/8] Setting up OpsDash directory...${NC}"
mkdir -p "$OPSDASH_DIR"
cd "$OPSDASH_DIR"

# Check for required files
if [ ! -f "opsdash_web.py" ]; then
    echo -e "${RED}Error: opsdash_web.py not found in $OPSDASH_DIR${NC}"
    echo -e "${YELLOW}Please copy opsdash_web.py to $OPSDASH_DIR${NC}"
    exit 1
fi

if [ ! -f "requirements.txt" ]; then
    echo -e "${YELLOW}Warning: requirements.txt not found. Creating default...${NC}"
    echo "streamlit" > requirements.txt
fi

# Create Python virtual environment
echo -e "${GREEN}[6/8] Creating Python virtual environment...${NC}"
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies
echo -e "${GREEN}[7/8] Installing Python dependencies...${NC}"
pip install --upgrade pip
pip install -r requirements.txt

# Configure Zowe CLI with keyring support
echo -e "${GREEN}[8/8] Configuring Zowe CLI...${NC}"
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Zowe CLI Configuration${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Setting up keyring for secure credential storage..."
echo ""

# Setup keyring (required for Zowe CLI secure storage)
export $(dbus-launch)
echo -e "${YELLOW}Enter keyring password (can be empty, just press Enter):${NC}"
gnome-keyring-daemon -r --unlock --components=secrets &

# Add keyring setup to .bashrc
if ! grep -q "dbus-launch" ~/.bashrc 2>/dev/null; then
    echo '' >> ~/.bashrc
    echo '# Keyring setup for Zowe CLI' >> ~/.bashrc
    echo 'export $(dbus-launch)' >> ~/.bashrc
    echo 'gnome-keyring-daemon -r --unlock --components=secrets &' >> ~/.bashrc
    echo -e "${GREEN}✓ Added keyring setup to ~/.bashrc${NC}"
fi

export NODE_TLS_REJECT_UNAUTHORIZED=0
if ! grep -q "NODE_TLS_REJECT_UNAUTHORIZED" ~/.bashrc 2>/dev/null; then
    echo 'export NODE_TLS_REJECT_UNAUTHORIZED=0' >> ~/.bashrc
fi

echo ""
echo -e "${BLUE}Connection details:${NC}"
echo "  - Host: 204.90.115.200"
echo "  - Port: 10443 (IMPORTANT: Not 443!)"
echo ""
echo -e "${YELLOW}Enter your z/OS user ID:${NC}"
read -r ZOWE_USER
echo -e "${YELLOW}Enter your z/OS password (hidden):${NC}"
read -rs ZOWE_PASS
echo ""

# Also create a Zowe profile (like on Windows) for compatibility
echo -e "${GREEN}Creating Zowe CLI profile (like on Windows)...${NC}"
cd ~
mkdir -p ~/.zowe

# Create profile structure
cat > ~/.zowe/zowe.config.json <<EOF
{
    "\$schema": "./zowe.schema.json",
    "profiles": {
        "zosmf": {
            "type": "zosmf",
            "properties": {
                "host": "204.90.115.200",
                "port": 10443,
                "rejectUnauthorized": false
            },
            "secure": [
                "user",
                "password"
            ]
        },
        "global_base": {
            "type": "base",
            "properties": {
                "host": "204.90.115.200",
                "rejectUnauthorized": false
            },
            "secure": [
                "user",
                "password"
            ]
        }
    },
    "defaults": {
        "zosmf": "zosmf",
        "base": "global_base"
    },
    "autoStore": true
}
EOF

# Store credentials securely using Zowe CLI with keyring
echo -e "${YELLOW}Storing credentials in Zowe profile (using keyring)...${NC}"
export NODE_TLS_REJECT_UNAUTHORIZED=0

# Set user (keyring will automatically store securely)
zowe config set profiles.zosmf.zosmf.user "$ZOWE_USER" --global-config true

# Set password (keyring will automatically store securely)
# Note: When keyring is available, Zowe CLI automatically uses it for secure fields
zowe config set profiles.zosmf.zosmf.password "$ZOWE_PASS" --global-config true

# Set base profile credentials
zowe config set profiles.base.global_base.user "$ZOWE_USER" --global-config true
zowe config set profiles.base.global_base.password "$ZOWE_PASS" --global-config true

echo -e "${GREEN}✓ Zowe profile created and credentials stored${NC}"
echo ""

# Test Zowe connection with profile
echo -e "${GREEN}Testing Zowe CLI connection...${NC}"
if zowe zosmf check status --zosmf-profile zosmf 2>/dev/null; then
    echo -e "${GREEN}✓ Zowe CLI connection successful!${NC}"
else
    echo -e "${YELLOW}⚠ Connection test failed, but profile is configured${NC}"
    echo -e "${YELLOW}  You can test manually: zowe zosmf check status --zosmf-profile zosmf${NC}"
fi

# Create systemd service for auto-start
echo ""
echo -e "${GREEN}Creating systemd service for auto-start...${NC}"
sudo tee /etc/systemd/system/opsdash.service > /dev/null <<EOF
[Unit]
Description=OpsDash Mainframe Dashboard
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$OPSDASH_DIR
Environment="PATH=$OPSDASH_DIR/venv/bin:/usr/local/bin:/usr/bin:/bin"
Environment="NODE_TLS_REJECT_UNAUTHORIZED=0"
Environment="DISPLAY=:0"
ExecStart=/bin/bash -c 'export $(dbus-launch) && gnome-keyring-daemon -r --unlock --components=secrets & sleep 2 && $OPSDASH_DIR/venv/bin/streamlit run opsdash_web.py --server.address=$STREAMLIT_ADDRESS --server.port=$STREAMLIT_PORT --server.headless=true'
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
sudo systemctl daemon-reload
sudo systemctl enable opsdash.service

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}OpsDash is now installed at: $OPSDASH_DIR${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Start the service: ${GREEN}sudo systemctl start opsdash${NC}"
echo "  2. Check status: ${GREEN}sudo systemctl status opsdash${NC}"
echo "  3. View logs: ${GREEN}sudo journalctl -u opsdash -f${NC}"
echo "  4. Access dashboard: ${GREEN}http://$(hostname -I | awk '{print $1}'):$STREAMLIT_PORT${NC}"
echo "     or from any device on your network: ${GREEN}http://raspberrypi.local:$STREAMLIT_PORT${NC}"
echo ""

# Ask if user wants to start the service now
echo -e "${YELLOW}Start OpsDash service now? (y/n)${NC}"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    sudo systemctl start opsdash
    sleep 2
    if sudo systemctl is-active --quiet opsdash; then
        echo -e "${GREEN}✓ OpsDash is now running!${NC}"
        echo -e "${GREEN}Access it at: http://$(hostname -I | awk '{print $1}'):$STREAMLIT_PORT${NC}"
    else
        echo -e "${RED}Service failed to start. Check logs: sudo journalctl -u opsdash${NC}"
    fi
fi

echo ""
echo -e "${GREEN}Setup script completed successfully!${NC}"

