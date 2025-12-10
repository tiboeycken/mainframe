#!/bin/bash
################################################################################
# OpsDash Kiosk Mode Setup for Raspberry Pi
# Sets up automatic browser launch in full-screen kiosk mode on boot
################################################################################

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

OPSDASH_URL="http://localhost:8501"
STREAMLIT_PORT=8501

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     OpsDash Kiosk Mode Setup                              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if running on Raspberry Pi with desktop
if [ ! -d /etc/xdg/autostart ]; then
    echo -e "${YELLOW}Warning: Desktop environment not detected. Kiosk mode requires a desktop.${NC}"
    echo -e "${YELLOW}Install desktop: sudo apt-get install -y raspberrypi-ui-mods${NC}"
    exit 1
fi

# Get Pi's IP address
PI_IP=$(hostname -I | awk '{print $1}')

echo -e "${YELLOW}This will set up kiosk mode to display OpsDash in full-screen on boot.${NC}"
echo -e "${YELLOW}The dashboard will be accessible at: http://$PI_IP:$STREAMLIT_PORT${NC}"
echo ""
echo -e "${YELLOW}Continue? (y/n)${NC}"
read -r response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    exit 0
fi

# Install required packages
echo -e "${GREEN}Installing required packages...${NC}"
sudo apt-get update
sudo apt-get install -y \
    chromium-browser \
    unclutter \
    xdotool \
    x11-xserver-utils \
    matchbox-window-manager

# Create kiosk startup script
echo -e "${GREEN}Creating kiosk startup script...${NC}"
sudo tee /usr/bin/opsdash-kiosk.sh > /dev/null <<'EOF'
#!/bin/bash
# Hide cursor
unclutter -idle 0.5 -root &

# Disable screen blanking
xset s off
xset -dpms
xset s noblank

# Wait for network and OpsDash to be ready
sleep 10
while ! curl -s http://localhost:8501 > /dev/null 2>&1; do
    echo "Waiting for OpsDash to start..."
    sleep 5
done

# Launch Chromium in kiosk mode
chromium-browser \
    --noerrdialogs \
    --disable-infobars \
    --kiosk \
    --incognito \
    --disable-restore-session-state \
    --disable-session-crashed-bubble \
    --disable-features=TranslateUI \
    --app=http://localhost:8501
EOF

sudo chmod +x /usr/bin/opsdash-kiosk.sh

# Create autostart entry
echo -e "${GREEN}Setting up autostart...${NC}"
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/opsdash-kiosk.desktop <<EOF
[Desktop Entry]
Type=Application
Name=OpsDash Kiosk
Exec=/usr/bin/opsdash-kiosk.sh
Icon=chromium-browser
Comment=OpsDash Mainframe Dashboard
X-GNOME-Autostart-enabled=true
EOF

# Alternative: Use system-wide autostart (requires sudo)
echo ""
echo -e "${YELLOW}Choose autostart method:${NC}"
echo "  1) User autostart (recommended) - Only for current user"
echo "  2) System-wide autostart - For all users"
read -r choice

if [ "$choice" = "2" ]; then
    sudo tee /etc/xdg/autostart/opsdash-kiosk.desktop > /dev/null <<EOF
[Desktop Entry]
Type=Application
Name=OpsDash Kiosk
Exec=/usr/bin/opsdash-kiosk.sh
Icon=chromium-browser
Comment=OpsDash Mainframe Dashboard
X-GNOME-Autostart-enabled=true
EOF
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Kiosk Mode Setup Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}Kiosk mode will start automatically on next boot.${NC}"
echo ""
echo -e "${BLUE}To test kiosk mode now:${NC}"
echo "  ${GREEN}/usr/bin/opsdash-kiosk.sh${NC}"
echo ""
echo -e "${BLUE}To disable kiosk mode:${NC}"
echo "  Remove: ${GREEN}~/.config/autostart/opsdash-kiosk.desktop${NC}"
echo "  Or: ${GREEN}sudo rm /etc/xdg/autostart/opsdash-kiosk.desktop${NC}"
echo ""
echo -e "${BLUE}Keyboard shortcuts in kiosk mode:${NC}"
echo "  ${GREEN}Alt+F4${NC} - Exit full-screen"
echo "  ${GREEN}Ctrl+Shift+Q${NC} - Quit browser"
echo ""

