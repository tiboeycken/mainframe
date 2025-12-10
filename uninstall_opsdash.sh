#!/bin/bash
################################################################################
# OpsDash Uninstall Script for Raspberry Pi
# Removes OpsDash service, kiosk mode, and optionally all files
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

OPSDASH_DIR="$HOME/opsdash"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     OpsDash Uninstall Script                           ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if running as root for some operations
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}Warning: Running as root. Some operations may affect system files.${NC}"
fi

# Stop and disable service
echo -e "${GREEN}[1/5] Stopping and removing OpsDash service...${NC}"
if systemctl is-active --quiet opsdash 2>/dev/null; then
    echo -e "${YELLOW}Stopping opsdash service...${NC}"
    sudo systemctl stop opsdash
fi

if systemctl is-enabled --quiet opsdash 2>/dev/null; then
    echo -e "${YELLOW}Disabling opsdash service...${NC}"
    sudo systemctl disable opsdash
fi

if [ -f /etc/systemd/system/opsdash.service ]; then
    echo -e "${YELLOW}Removing service file...${NC}"
    sudo rm /etc/systemd/system/opsdash.service
    sudo systemctl daemon-reload
    sudo systemctl reset-failed
    echo -e "${GREEN}✓ Service removed${NC}"
else
    echo -e "${YELLOW}Service file not found${NC}"
fi

# Remove kiosk mode
echo -e "${GREEN}[2/5] Removing kiosk mode...${NC}"

# Remove user autostart
if [ -f ~/.config/autostart/opsdash-kiosk.desktop ]; then
    echo -e "${YELLOW}Removing user autostart...${NC}"
    rm ~/.config/autostart/opsdash-kiosk.desktop
    echo -e "${GREEN}✓ User autostart removed${NC}"
fi

# Remove system-wide autostart
if [ -f /etc/xdg/autostart/opsdash-kiosk.desktop ]; then
    echo -e "${YELLOW}Removing system-wide autostart...${NC}"
    sudo rm /etc/xdg/autostart/opsdash-kiosk.desktop
    echo -e "${GREEN}✓ System autostart removed${NC}"
fi

# Remove kiosk script
if [ -f /usr/bin/opsdash-kiosk.sh ]; then
    echo -e "${YELLOW}Removing kiosk script...${NC}"
    sudo rm /usr/bin/opsdash-kiosk.sh
    echo -e "${GREEN}✓ Kiosk script removed${NC}"
fi

# Kill any running kiosk processes
if pgrep -f "opsdash-kiosk" > /dev/null; then
    echo -e "${YELLOW}Stopping running kiosk processes...${NC}"
    pkill -f "opsdash-kiosk" || true
    sleep 2
fi

# Remove OpsDash directory
echo -e "${GREEN}[3/5] Removing OpsDash files...${NC}"
if [ -d "$OPSDASH_DIR" ]; then
    echo -e "${YELLOW}OpsDash directory found: $OPSDASH_DIR${NC}"
    echo -e "${YELLOW}Remove OpsDash directory and all files? (y/n)${NC}"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Removing $OPSDASH_DIR...${NC}"
        rm -rf "$OPSDASH_DIR"
        echo -e "${GREEN}✓ OpsDash directory removed${NC}"
    else
        echo -e "${YELLOW}Keeping OpsDash directory${NC}"
    fi
else
    echo -e "${YELLOW}OpsDash directory not found at $OPSDASH_DIR${NC}"
fi

# Optional: Remove dependencies
echo -e "${GREEN}[4/5] Dependency cleanup...${NC}"
echo -e "${YELLOW}Remove installed dependencies? (y/n)${NC}"
echo -e "${YELLOW}This will remove: Node.js, Zowe CLI, Python packages, etc.${NC}"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Removing dependencies...${NC}"
    
    # Remove Zowe CLI
    if command -v zowe &> /dev/null; then
        echo -e "${YELLOW}Removing Zowe CLI...${NC}"
        sudo npm uninstall -g @zowe/cli || true
    fi
    
    # Remove Node.js (optional - be careful!)
    echo -e "${YELLOW}Remove Node.js? (y/n)${NC}"
    echo -e "${RED}Warning: This will remove Node.js completely. Only do this if you don't need it for other projects.${NC}"
    read -r node_response
    if [[ "$node_response" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Removing Node.js...${NC}"
        sudo apt-get remove -y nodejs npm || true
        sudo apt-get autoremove -y || true
    fi
    
    # Remove Python packages (only Streamlit from this project)
    if [ -d "$OPSDASH_DIR/venv" ]; then
        echo -e "${YELLOW}Python virtual environment was in OpsDash directory${NC}"
        echo -e "${YELLOW}(Already removed if you deleted the directory)${NC}"
    fi
    
    echo -e "${GREEN}✓ Dependency cleanup complete${NC}"
else
    echo -e "${YELLOW}Skipping dependency removal${NC}"
fi

# Clean up logs
echo -e "${GREEN}[5/5] Cleaning up logs...${NC}"
if command -v journalctl &> /dev/null; then
    echo -e "${YELLOW}Clear OpsDash service logs? (y/n)${NC}"
    read -r log_response
    if [[ "$log_response" =~ ^[Yy]$ ]]; then
        sudo journalctl --vacuum-time=1s --unit=opsdash || true
        echo -e "${GREEN}✓ Logs cleared${NC}"
    fi
fi

# Summary
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Uninstall Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Removed:${NC}"
echo "  ✓ OpsDash systemd service"
echo "  ✓ Kiosk mode autostart"
echo "  ✓ Kiosk script"
if [ ! -d "$OPSDASH_DIR" ]; then
    echo "  ✓ OpsDash directory"
fi
echo ""
echo -e "${YELLOW}Note: If you want to reinstall, run:${NC}"
echo "  ${GREEN}git clone https://github.com/tiboeycken/opsdash.git${NC}"
echo "  ${GREEN}cd opsdash && ./setup_raspberry_pi.sh${NC}"
echo ""
echo -e "${BLUE}To verify removal:${NC}"
echo "  ${GREEN}systemctl status opsdash${NC} (should show 'not found')"
echo "  ${GREEN}ls ~/.config/autostart/opsdash-kiosk.desktop${NC} (should show 'not found')"
echo ""

