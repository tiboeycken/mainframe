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
echo ""
echo -e "${BLUE}Default connection details:${NC}"
echo "  - Host: 204.90.115.200"
echo "  - Port: 10443 (IMPORTANT: Not 443!)"
echo "  - User: Your z/OS user ID"
echo "  - Password: Your z/OS password"
echo ""
echo -e "${YELLOW}Press Enter to configure Zowe CLI, or Ctrl+C to skip and configure later...${NC}"
read -r

# Fix keyring issue on headless systems (Raspberry Pi without X11)
echo -e "${GREEN}Configuring Zowe CLI to work without keyring (headless mode)...${NC}"
export ZOWE_CLI_IMPERATIVE_CREDENTIAL_MANAGER="imperative-credential-manager"
# Also set for future sessions
if ! grep -q "ZOWE_CLI_IMPERATIVE_CREDENTIAL_MANAGER" ~/.bashrc 2>/dev/null; then
    echo 'export ZOWE_CLI_IMPERATIVE_CREDENTIAL_MANAGER="imperative-credential-manager"' >> ~/.bashrc
    echo -e "${GREEN}✓ Added to ~/.bashrc for future sessions${NC}"
fi
if [ -f ~/.zshrc ] && ! grep -q "ZOWE_CLI_IMPERATIVE_CREDENTIAL_MANAGER" ~/.zshrc 2>/dev/null; then
    echo 'export ZOWE_CLI_IMPERATIVE_CREDENTIAL_MANAGER="imperative-credential-manager"' >> ~/.zshrc
fi
echo -e "${GREEN}✓ Keyring bypass configured${NC}"
echo ""

# Check if config already exists
CONFIG_FILE="$HOME/.zowe/zowe.config.json"
PROFILE_NAME="default"

# Initialize config if it doesn't exist
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${GREEN}Initializing Zowe CLI configuration...${NC}"
    zowe config init --global-config false 2>/dev/null || {
        echo -e "${YELLOW}Config init had issues, continuing anyway...${NC}"
    }
fi

# Check if profile already exists in config
if [ -f "$CONFIG_FILE" ]; then
    if grep -q "profiles.zosmf.$PROFILE_NAME" "$CONFIG_FILE" 2>/dev/null; then
        echo -e "${YELLOW}Profile '$PROFILE_NAME' exists. Checking port configuration...${NC}"
        
        # Check current port from config
        CURRENT_PORT=$(zowe config get profiles.zosmf.$PROFILE_NAME.port 2>/dev/null || echo "unknown")
        echo "  Current port in profile: $CURRENT_PORT"
        
        if [ "$CURRENT_PORT" != "10443" ] && [ "$CURRENT_PORT" != "unknown" ]; then
            echo -e "${RED}✗ Wrong port detected ($CURRENT_PORT). Must fix to 10443${NC}"
            echo -e "${YELLOW}Updating profile with correct port...${NC}"
            ZOWE_USER=""  # Force recreation
        else
            echo -e "${YELLOW}Update existing profile? (y/n)${NC}"
            read -r update_response
            if [[ "$update_response" =~ ^[Yy]$ ]]; then
                ZOWE_USER=""  # Force update
            else
                echo -e "${YELLOW}Skipping profile update${NC}"
                ZOWE_USER="SKIP"
            fi
        fi
    fi
fi

if [ "$ZOWE_USER" != "SKIP" ]; then
    # Get credentials if not already set
    if [ -z "$ZOWE_USER" ]; then
        echo -e "${YELLOW}Enter your z/OS user ID:${NC}"
        read -r ZOWE_USER
        echo -e "${YELLOW}Enter your z/OS password (hidden):${NC}"
        read -rs ZOWE_PASS
        echo ""
    fi
    
    echo -e "${GREEN}Configuring Zowe CLI profile with port 10443...${NC}"
    echo -e "${YELLOW}IMPORTANT: Make sure port is 10443, not 443!${NC}"
    echo -e "${YELLOW}Using new Zowe CLI v2 config method (config set)${NC}"
    
    # Ensure the credential manager env var is set
    export ZOWE_CLI_IMPERATIVE_CREDENTIAL_MANAGER="imperative-credential-manager"
    
    # Use new config set method (Zowe CLI v2)
    echo -e "${YELLOW}Setting profile configuration...${NC}"
    
    # Set host
    zowe config set profiles.zosmf.$PROFILE_NAME.host 204.90.115.200 --global-config false 2>/dev/null || true
    
    # Set port (IMPORTANT: 10443, not 443)
    zowe config set profiles.zosmf.$PROFILE_NAME.port 10443 --global-config false 2>/dev/null || true
    
    # Set user (secure)
    echo "$ZOWE_PASS" | zowe config set profiles.zosmf.$PROFILE_NAME.user "$ZOWE_USER" --secure --global-config false 2>/dev/null || {
        # Fallback if secure doesn't work
        zowe config set profiles.zosmf.$PROFILE_NAME.user "$ZOWE_USER" --global-config false 2>/dev/null || true
    }
    
    # Set password (secure)
    echo "$ZOWE_PASS" | zowe config set profiles.zosmf.$PROFILE_NAME.password "$ZOWE_PASS" --secure --global-config false 2>/dev/null || {
        # Fallback if secure doesn't work
        echo "$ZOWE_PASS" | zowe config set profiles.zosmf.$PROFILE_NAME.password "$ZOWE_PASS" --global-config false 2>/dev/null || true
    }
    
    # Set reject-unauthorized
    zowe config set profiles.zosmf.$PROFILE_NAME.reject-unauthorized false --global-config false 2>/dev/null || true
    
    # Set as default
    zowe config set defaults.zosmf $PROFILE_NAME --global-config false 2>/dev/null || true
    
    echo -e "${GREEN}✓ Profile configuration completed${NC}"
    
    # Wait a moment for file system to sync
    sleep 1
    
    # Verify configuration was saved
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}✗ Config file was not created!${NC}"
        echo -e "${YELLOW}Checking if .zowe directory exists...${NC}"
        
        if [ ! -d ~/.zowe ]; then
            echo -e "${RED}✗ .zowe directory does not exist!${NC}"
            echo -e "${YELLOW}This suggests Zowe CLI configuration failed completely${NC}"
            echo -e "${YELLOW}You may need to configure manually:${NC}"
            echo "  ${GREEN}zowe config init${NC}"
            echo "  ${GREEN}zowe config set profiles.zosmf.default.host 204.90.115.200${NC}"
            echo "  ${GREEN}zowe config set profiles.zosmf.default.port 10443${NC}"
            echo "  ${GREEN}zowe config set profiles.zosmf.default.user $ZOWE_USER --secure${NC}"
        else
            echo -e "${YELLOW}.zowe directory exists but config file is missing${NC}"
        fi
    else
        echo -e "${GREEN}✓ Config file exists: $CONFIG_FILE${NC}"
        
        # Verify port was saved correctly
        VERIFY_PORT=$(zowe config get profiles.zosmf.$PROFILE_NAME.port --global-config false 2>/dev/null || echo "unknown")
        if [ "$VERIFY_PORT" != "10443" ]; then
            echo -e "${RED}✗ Port verification failed! Port is: $VERIFY_PORT${NC}"
            echo -e "${YELLOW}Fixing port in config file...${NC}"
            
            # Manual fix: Edit config JSON directly
            if [ -f "$CONFIG_FILE" ]; then
                # Replace port in JSON file
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    sed -i '' "s/\"port\":[[:space:]]*[0-9]*/\"port\": 10443/g" "$CONFIG_FILE"
                    sed -i '' "s/\"port\":[[:space:]]*\"[0-9]*\"/\"port\": \"10443\"/g" "$CONFIG_FILE"
                else
                    sed -i "s/\"port\":[[:space:]]*[0-9]*/\"port\": 10443/g" "$CONFIG_FILE"
                    sed -i "s/\"port\":[[:space:]]*\"[0-9]*\"/\"port\": \"10443\"/g" "$CONFIG_FILE"
                fi
                echo -e "${GREEN}✓ Config file fixed manually${NC}"
                
                # Verify again
                VERIFY_PORT=$(zowe config get profiles.zosmf.$PROFILE_NAME.port --global-config false 2>/dev/null || echo "unknown")
                echo "  Port after fix: $VERIFY_PORT"
            fi
        else
            echo -e "${GREEN}✓ Port verified: $VERIFY_PORT${NC}"
        fi
        
        # Verify profile can be read
        VERIFY_HOST=$(zowe config get profiles.zosmf.$PROFILE_NAME.host --global-config false 2>/dev/null || echo "unknown")
        if [ "$VERIFY_HOST" != "unknown" ]; then
            echo -e "${GREEN}✓ Profile configuration is valid${NC}"
            echo "  Host: $VERIFY_HOST"
            echo "  Port: $VERIFY_PORT"
        else
            echo -e "${YELLOW}⚠ Config file exists but profile may not be configured correctly${NC}"
        fi
    fi
fi

# Test Zowe connection
echo ""
echo -e "${GREEN}Testing Zowe CLI connection...${NC}"
# First check if config exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}✗ Config file does not exist!${NC}"
    echo -e "${YELLOW}Cannot test connection without configuration.${NC}"
    echo -e "${YELLOW}Please configure manually:${NC}"
    if [ -n "$ZOWE_USER" ]; then
        echo "  ${GREEN}zowe config init${NC}"
        echo "  ${GREEN}zowe config set profiles.zosmf.default.host 204.90.115.200${NC}"
        echo "  ${GREEN}zowe config set profiles.zosmf.default.port 10443${NC}"
        echo "  ${GREEN}zowe config set profiles.zosmf.default.user $ZOWE_USER --secure${NC}"
        echo "  ${GREEN}zowe config set profiles.zosmf.default.password <password> --secure${NC}"
        echo "  ${GREEN}zowe config set defaults.zosmf default${NC}"
    else
        echo "  ${GREEN}zowe config init${NC}"
        echo "  ${GREEN}zowe config set profiles.zosmf.default.host 204.90.115.200${NC}"
        echo "  ${GREEN}zowe config set profiles.zosmf.default.port 10443${NC}"
        echo "  ${GREEN}zowe config set profiles.zosmf.default.user YOUR_USER --secure${NC}"
        echo "  ${GREEN}zowe config set profiles.zosmf.default.password YOUR_PASS --secure${NC}"
        echo "  ${GREEN}zowe config set defaults.zosmf default${NC}"
    fi
else
    # Try with profile first
    if zowe zosmf check status 2>/dev/null; then
        echo -e "${GREEN}✓ Zowe CLI connection successful using profile!${NC}"
    # Try with explicit parameters if profile test fails
    elif [ -n "$ZOWE_USER" ] && [ -n "$ZOWE_PASS" ]; then
        echo -e "${YELLOW}Profile test failed, trying with explicit parameters...${NC}"
        if zowe zosmf check status --host 204.90.115.200 --port 10443 --user "$ZOWE_USER" --password "$ZOWE_PASS" --reject-unauthorized false 2>/dev/null; then
            echo -e "${GREEN}✓ Zowe CLI connection successful with explicit parameters!${NC}"
            echo -e "${YELLOW}Note: Profile exists but may have wrong credentials. Connection works with explicit params.${NC}"
        else
            echo -e "${RED}✗ Zowe CLI connection failed${NC}"
            echo -e "${YELLOW}Troubleshooting:${NC}"
            echo "  1. Verify host and port: 204.90.115.200:10443"
            echo "  2. Check your credentials (password may have expired)"
            echo "  3. Ensure network connectivity: ping 204.90.115.200"
            echo "  4. Check config: zowe config get profiles.zosmf.default"
            if [ -n "$ZOWE_USER" ]; then
                echo "  5. Run manually: zowe zosmf check status --host 204.90.115.200 --port 10443 --user $ZOWE_USER --password <password> --reject-unauthorized false"
            fi
        fi
    else
        echo -e "${YELLOW}⚠ Cannot test with explicit parameters - credentials not available${NC}"
        echo -e "${YELLOW}Test manually: zowe zosmf check status${NC}"
    fi
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
Environment="ZOWE_CLI_IMPERATIVE_CREDENTIAL_MANAGER=imperative-credential-manager"
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

