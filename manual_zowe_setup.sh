#!/bin/bash
################################################################################
# Manual Zowe CLI Setup - Step by Step
# Follow this to set up Zowe CLI manually and see where it fails
################################################################################

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Manual Zowe CLI Setup - Step by Step                 ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Check Zowe CLI installation
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}STEP 1: Check Zowe CLI Installation${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if command -v zowe &> /dev/null; then
    ZOWE_VERSION=$(zowe --version 2>/dev/null || echo "unknown")
    echo -e "${GREEN}✓ Zowe CLI is installed${NC}"
    echo "  Version: $ZOWE_VERSION"
else
    echo -e "${RED}✗ Zowe CLI is not installed${NC}"
    echo "  Install with: sudo npm install -g @zowe/cli@zowe-v2-lts"
    exit 1
fi
echo ""
read -p "Press Enter to continue..."

# Step 2: Set credential manager and certificate bypass
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}STEP 2: Set Credential Manager & Certificate Bypass${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
export ZOWE_CLI_IMPERATIVE_CREDENTIAL_MANAGER="imperative-credential-manager"
export NODE_TLS_REJECT_UNAUTHORIZED=0
echo -e "${GREEN}✓ Set: ZOWE_CLI_IMPERATIVE_CREDENTIAL_MANAGER=imperative-credential-manager${NC}"
echo -e "${GREEN}✓ Set: NODE_TLS_REJECT_UNAUTHORIZED=0 (for self-signed certificates)${NC}"
echo ""
read -p "Press Enter to continue..."

# Step 3: Initialize config
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}STEP 3: Initialize Zowe Config${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}IMPORTANT: Changing to home directory first...${NC}"
cd ~
export ZOWE_CLI_HOME="$HOME"
echo "Current directory: $(pwd)"
echo "ZOWE_CLI_HOME: $ZOWE_CLI_HOME"
echo ""
echo "Running: zowe config init --global-config true"
echo ""
zowe config init --global-config true
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Config initialized${NC}"
else
    echo -e "${YELLOW}⚠ Config init had issues (may already exist)${NC}"
fi
echo ""
# Check multiple possible locations
CONFIG_FOUND=false
if [ -f ~/.zowe/zowe.config.json ]; then
    echo -e "${GREEN}✓ Config file exists: ~/.zowe/zowe.config.json${NC}"
    CONFIG_FILE=~/.zowe/zowe.config.json
    CONFIG_FOUND=true
elif [ -f ~/.zowe/zosmf/profiles/zosmf_meta.yaml ]; then
    echo -e "${GREEN}✓ Config file exists: ~/.zowe/zosmf/profiles/zosmf_meta.yaml${NC}"
    CONFIG_FILE=~/.zowe/zosmf/profiles/zosmf_meta.yaml
    CONFIG_FOUND=true
elif [ -f ~/.zowe/zowe.config.yaml ]; then
    echo -e "${GREEN}✓ Config file exists: ~/.zowe/zowe.config.yaml${NC}"
    CONFIG_FILE=~/.zowe/zowe.config.yaml
    CONFIG_FOUND=true
fi

if [ "$CONFIG_FOUND" = true ]; then
    echo -e "${YELLOW}Current config:${NC}"
    cat "$CONFIG_FILE"
    echo ""
    echo -e "${YELLOW}Also checking for JSON config:${NC}"
    find ~/.zowe -name "*.json" -type f 2>/dev/null | head -5
    echo ""
    echo -e "${YELLOW}Also checking for YAML config:${NC}"
    find ~/.zowe -name "*.yaml" -type f 2>/dev/null | head -5
else
    echo -e "${RED}✗ Config file not found in expected locations!${NC}"
    echo -e "${YELLOW}Searching for any config files...${NC}"
    find ~/.zowe -type f 2>/dev/null | head -10
fi
echo ""
read -p "Press Enter to continue..."

# Step 4: Get credentials
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}STEP 4: Enter Credentials${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Enter your z/OS user ID:${NC}"
read -r ZOWE_USER
echo -e "${YELLOW}Enter your z/OS password (hidden):${NC}"
read -rs ZOWE_PASS
echo ""
echo -e "${GREEN}✓ Credentials entered${NC}"
echo "  User: $ZOWE_USER"
echo "  Password: [hidden]"
echo ""
read -p "Press Enter to continue..."

# Step 5: Set host (ensure we're in home directory)
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}STEP 5: Set Host${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
cd ~
export ZOWE_CLI_HOME="$HOME"
echo "Current directory: $(pwd)"
echo "Running: zowe config set profiles.zosmf.default.host 204.90.115.200 --global-config true"
zowe config set profiles.zosmf.default.host 204.90.115.200 --global-config true
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Host set${NC}"
    VERIFY=$(zowe config get profiles.zosmf.default.host --global-config true 2>/dev/null)
    echo "  Verified: $VERIFY"
    if [ -z "$VERIFY" ]; then
        echo -e "${YELLOW}⚠ Verification returned empty, trying without --global-config flag...${NC}"
        VERIFY=$(zowe config get profiles.zosmf.default.host 2>/dev/null)
        echo "  Verified (no flag): $VERIFY"
    fi
else
    echo -e "${RED}✗ Failed to set host${NC}"
fi
echo ""
read -p "Press Enter to continue..."

# Step 6: Set port
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}STEP 6: Set Port (IMPORTANT: 10443, not 443)${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
cd ~
export ZOWE_CLI_HOME="$HOME"
echo "Current directory: $(pwd)"
echo "Running: zowe config set profiles.zosmf.default.port 10443 --global-config true"
zowe config set profiles.zosmf.default.port 10443 --global-config true
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Port set command succeeded${NC}"
    VERIFY=$(zowe config get profiles.zosmf.default.port --global-config true 2>/dev/null)
    echo "  Verified (with flag): '$VERIFY'"
    if [ -z "$VERIFY" ]; then
        echo -e "${YELLOW}⚠ Verification returned empty, trying without --global-config flag...${NC}"
        VERIFY=$(zowe config get profiles.zosmf.default.port 2>/dev/null)
        echo "  Verified (no flag): '$VERIFY'"
    fi
    if [ "$VERIFY" != "10443" ] && [ -n "$VERIFY" ]; then
        echo -e "${RED}✗ Port is wrong! Expected 10443, got '$VERIFY'${NC}"
    elif [ -z "$VERIFY" ]; then
        echo -e "${RED}✗ Port verification returned empty! Config may not be saving correctly${NC}"
        echo -e "${YELLOW}Let's check the config file directly...${NC}"
        if [ -f ~/.zowe/zowe.config.json ]; then
            echo "Checking ~/.zowe/zowe.config.json:"
            grep -A 5 "port" ~/.zowe/zowe.config.json || echo "Port not found in JSON"
        fi
    fi
else
    echo -e "${RED}✗ Failed to set port${NC}"
fi
echo ""
read -p "Press Enter to continue..."

# Step 7: Set user
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}STEP 7: Set User${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
cd ~
export ZOWE_CLI_HOME="$HOME"
echo "Running: zowe config set profiles.zosmf.default.user $ZOWE_USER --global-config true"
zowe config set profiles.zosmf.default.user "$ZOWE_USER" --global-config true
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ User set${NC}"
    VERIFY=$(zowe config get profiles.zosmf.default.user --global-config true 2>/dev/null || zowe config get profiles.zosmf.default.user 2>/dev/null)
    echo "  Verified: '$VERIFY'"
else
    echo -e "${RED}✗ Failed to set user${NC}"
fi
echo ""
read -p "Press Enter to continue..."

# Step 8: Set password
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}STEP 8: Set Password${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
cd ~
export ZOWE_CLI_HOME="$HOME"
echo "Running: zowe config set profiles.zosmf.default.password [hidden] --global-config true"
zowe config set profiles.zosmf.default.password "$ZOWE_PASS" --global-config true
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Password set${NC}"
    echo "  (Password stored in config)"
else
    echo -e "${RED}✗ Failed to set password${NC}"
fi
echo ""
read -p "Press Enter to continue..."

# Step 9: Set reject-unauthorized (CRITICAL for self-signed certificates)
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}STEP 9: Set reject-unauthorized (for self-signed certificates)${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
cd ~
export ZOWE_CLI_HOME="$HOME"
export NODE_TLS_REJECT_UNAUTHORIZED=0
echo -e "${YELLOW}IMPORTANT: This is required for self-signed certificates!${NC}"
echo "Running: zowe config set profiles.zosmf.default.reject-unauthorized false --global-config true"
zowe config set profiles.zosmf.default.reject-unauthorized false --global-config true
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ reject-unauthorized set to false${NC}"
    VERIFY=$(zowe config get profiles.zosmf.default.reject-unauthorized --global-config true 2>/dev/null || \
             zowe config get profiles.zosmf.default.reject-unauthorized 2>/dev/null || \
             echo "")
    echo "  Verified: '$VERIFY'"
    if [ "$VERIFY" != "false" ]; then
        echo -e "${RED}✗ Verification failed! Expected 'false', got '$VERIFY'${NC}"
        echo -e "${YELLOW}This may cause certificate errors${NC}"
    fi
else
    echo -e "${RED}✗ Failed to set reject-unauthorized - THIS IS CRITICAL!${NC}"
    echo -e "${YELLOW}Certificate errors will occur without this${NC}"
fi
echo ""
read -p "Press Enter to continue..."

# Step 10: Set as default
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}STEP 10: Set Profile as Default${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
cd ~
export ZOWE_CLI_HOME="$HOME"
echo "Running: zowe config set defaults.zosmf default --global-config true"
zowe config set defaults.zosmf default --global-config true
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Default profile set command succeeded${NC}"
    VERIFY=$(zowe config get defaults.zosmf --global-config true 2>/dev/null || zowe config get defaults.zosmf 2>/dev/null)
    echo "  Verified: '$VERIFY'"
    if [ "$VERIFY" != "default" ] && [ -n "$VERIFY" ]; then
        echo -e "${RED}✗ Default is wrong! Expected 'default', got '$VERIFY'${NC}"
    elif [ -z "$VERIFY" ]; then
        echo -e "${RED}✗ Default verification returned empty!${NC}"
        echo -e "${YELLOW}Checking config file directly...${NC}"
        if [ -f ~/.zowe/zowe.config.json ]; then
            echo "Checking ~/.zowe/zowe.config.json:"
            grep -A 2 "defaults" ~/.zowe/zowe.config.json || echo "Defaults not found in JSON"
        fi
    fi
else
    echo -e "${RED}✗ Failed to set default profile${NC}"
fi
echo ""
read -p "Press Enter to continue..."

# Step 11: Show final config
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}STEP 11: Final Configuration${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Checking all config files:${NC}"
echo ""
if [ -f ~/.zowe/zowe.config.json ]; then
    echo -e "${GREEN}✓ Found: ~/.zowe/zowe.config.json${NC}"
    cat ~/.zowe/zowe.config.json | python3 -m json.tool 2>/dev/null || cat ~/.zowe/zowe.config.json
    echo ""
fi
if [ -f ~/.zowe/zosmf/profiles/zosmf_meta.yaml ]; then
    echo -e "${GREEN}✓ Found: ~/.zowe/zosmf/profiles/zosmf_meta.yaml${NC}"
    cat ~/.zowe/zosmf/profiles/zosmf_meta.yaml
    echo ""
fi
echo -e "${YELLOW}All files in ~/.zowe:${NC}"
find ~/.zowe -type f 2>/dev/null | head -20
echo ""
read -p "Press Enter to continue..."

# Step 12: Test connection with profile
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}STEP 12: Test Connection with Profile${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
export NODE_TLS_REJECT_UNAUTHORIZED=0
echo "Running: zowe zosmf check status --zosmf-profile default"
echo -e "${YELLOW}Note: NODE_TLS_REJECT_UNAUTHORIZED=0 is set for self-signed certificates${NC}"
echo ""
zowe zosmf check status --zosmf-profile default
PROFILE_RESULT=$?
echo ""
if [ $PROFILE_RESULT -eq 0 ]; then
    echo -e "${GREEN}✓ Connection successful with profile!${NC}"
else
    echo -e "${RED}✗ Connection failed with profile${NC}"
fi
echo ""
read -p "Press Enter to continue..."

# Step 13: Test connection without profile (uses default)
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}STEP 13: Test Connection without Profile (uses default)${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
export NODE_TLS_REJECT_UNAUTHORIZED=0
echo "Running: zowe zosmf check status"
echo ""
zowe zosmf check status
DEFAULT_RESULT=$?
echo ""
if [ $DEFAULT_RESULT -eq 0 ]; then
    echo -e "${GREEN}✓ Connection successful without profile (using default)!${NC}"
else
    echo -e "${RED}✗ Connection failed without profile${NC}"
fi
echo ""
read -p "Press Enter to continue..."

# Step 14: Test connection with explicit parameters
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}STEP 14: Test Connection with Explicit Parameters${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
export NODE_TLS_REJECT_UNAUTHORIZED=0
echo "Running: zowe zosmf check status --host 204.90.115.200 --port 10443 --user $ZOWE_USER --password [hidden] --reject-unauthorized false"
echo -e "${YELLOW}Note: Both NODE_TLS_REJECT_UNAUTHORIZED=0 and --reject-unauthorized false are set${NC}"
echo ""
zowe zosmf check status --host 204.90.115.200 --port 10443 --user "$ZOWE_USER" --password "$ZOWE_PASS" --reject-unauthorized false
EXPLICIT_RESULT=$?
echo ""
if [ $EXPLICIT_RESULT -eq 0 ]; then
    echo -e "${GREEN}✓ Connection successful with explicit parameters!${NC}"
else
    echo -e "${RED}✗ Connection failed with explicit parameters${NC}"
fi
echo ""

# Summary
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}SUMMARY${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Profile test:     $([ $PROFILE_RESULT -eq 0 ] && echo -e "${GREEN}✓ PASS${NC}" || echo -e "${RED}✗ FAIL${NC}")"
echo "Default test:     $([ $DEFAULT_RESULT -eq 0 ] && echo -e "${GREEN}✓ PASS${NC}" || echo -e "${RED}✗ FAIL${NC}")"
echo "Explicit test:    $([ $EXPLICIT_RESULT -eq 0 ] && echo -e "${GREEN}✓ PASS${NC}" || echo -e "${RED}✗ FAIL${NC}")"
echo ""
echo -e "${YELLOW}Please note which test(s) passed or failed and share the results.${NC}"
echo ""

