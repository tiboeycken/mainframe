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

# Clone or update OpsDash repository
echo -e "${GREEN}[5/8] Setting up OpsDash directory...${NC}"

# Ask for GitHub repository URL
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}GitHub Repository Setup${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Enter your GitHub repository URL (e.g., https://github.com/username/opsdash.git)"
echo "Or press Enter to use a default/test setup"
read -r GITHUB_REPO

if [ -z "$GITHUB_REPO" ]; then
    echo -e "${YELLOW}No repository URL provided.${NC}"
    echo -e "${YELLOW}You can manually clone your repo later or set it up manually.${NC}"
    mkdir -p "$OPSDASH_DIR"
    cd "$OPSDASH_DIR"
    
    if [ ! -f "opsdash_web.py" ]; then
        echo -e "${RED}Error: opsdash_web.py not found${NC}"
        echo -e "${YELLOW}Please clone your repository or copy files manually${NC}"
        exit 1
    fi
else
    # Clone repository
    if [ -d "$OPSDASH_DIR/.git" ]; then
        echo -e "${YELLOW}Repository already exists. Updating...${NC}"
        cd "$OPSDASH_DIR"
        git pull
    else
        echo -e "${GREEN}Cloning repository from GitHub...${NC}"
        git clone "$GITHUB_REPO" "$OPSDASH_DIR" || {
            echo -e "${RED}Error: Failed to clone repository${NC}"
            echo -e "${YELLOW}Please check the URL and try again${NC}"
            exit 1
        }
        cd "$OPSDASH_DIR"
    fi
fi

# Check for required files
if [ ! -f "opsdash_web.py" ]; then
    echo -e "${RED}Error: opsdash_web.py not found in $OPSDASH_DIR${NC}"
    echo -e "${YELLOW}Please ensure the repository contains opsdash_web.py${NC}"
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

# Configure Zowe CLI
echo -e "${GREEN}[8/8] Configuring Zowe CLI...${NC}"
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Zowe CLI Configuration${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "You need to configure Zowe CLI to connect to your mainframe."
echo "You'll be prompted for:"
echo "  - Host: 204.90.115.200 (or your z/OSMF host)"
echo "  - Port: 10443 (or your z/OSMF port)"
echo "  - User: Your z/OS user ID"
echo "  - Password: Your z/OS password"
echo ""
echo -e "${YELLOW}Press Enter to start Zowe configuration, or Ctrl+C to skip and configure later...${NC}"
read -r

# Test Zowe connection
if zowe zosmf check status; then
    echo -e "${GREEN}✓ Zowe CLI is already configured and working!${NC}"
else
    echo -e "${YELLOW}Configuring Zowe CLI profile...${NC}"
    echo -e "${YELLOW}Follow the prompts to enter your mainframe connection details${NC}"
    zowe zosmf check status || echo -e "${YELLOW}Zowe configuration will need to be completed manually${NC}"
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
ExecStart=$OPSDASH_DIR/venv/bin/streamlit run opsdash_web.py --server.address=$STREAMLIT_ADDRESS --server.port=$STREAMLIT_PORT --server.headless=true
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
echo -e "${YELLOW}Optional - Kiosk Mode Setup:${NC}"
echo "  Run: ${GREEN}bash setup_kiosk_mode.sh${NC} (if you want full-screen browser on boot)"
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

