#!/bin/bash
# OpsDash Raspberry Pi Startup Script
# This script sets up and starts OpsDash on Raspberry Pi

echo "🍓 Starting OpsDash on Raspberry Pi..."

# Navigate to script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Check if running on Raspberry Pi
if grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
    echo "✅ Raspberry Pi detected"
else
    echo "⚠️  Warning: May not be running on Raspberry Pi"
fi

# Check if Zowe CLI is installed
if ! command -v zowe &> /dev/null; then
    echo "❌ Zowe CLI not found. Please install it first:"
    echo "   npm install -g @zowe/cli"
    exit 1
fi

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 not found. Installing..."
    sudo apt update && sudo apt install -y python3 python3-pip
fi

# Check if Streamlit is installed
if ! python3 -c "import streamlit" 2>/dev/null; then
    echo "📦 Installing Streamlit..."
    pip3 install streamlit
fi

# Check if requirements.txt exists and install dependencies
if [ -f "requirements.txt" ]; then
    echo "📦 Installing requirements..."
    pip3 install -r requirements.txt
fi

# Check Zowe connection
echo "🔍 Checking Zowe CLI connection..."
if zowe zosmf check status &> /dev/null; then
    echo "✅ Zowe CLI connection: OK"
else
    echo "⚠️  Warning: Zowe CLI connection test failed"
    echo "   Run: zowe zosmf check status"
fi

# Determine which dashboard to run
if [ -f "pi_enhanced_dashboard.py" ]; then
    DASHBOARD_FILE="pi_enhanced_dashboard.py"
    echo "🚀 Starting enhanced Pi dashboard..."
else
    DASHBOARD_FILE="opsdash_web.py"
    echo "🚀 Starting standard dashboard..."
fi

# Get local IP address
LOCAL_IP=$(hostname -I | awk '{print $1}')
echo ""
echo "🌐 Dashboard will be available at:"
echo "   http://localhost:8501"
echo "   http://$LOCAL_IP:8501"
echo ""
echo "Press Ctrl+C to stop the dashboard"
echo ""

# Start Streamlit
streamlit run "$DASHBOARD_FILE" \
    --server.port 8501 \
    --server.address 0.0.0.0 \
    --server.headless true \
    --browser.gatherUsageStats false

