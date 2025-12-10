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

# Step 2: Set credential manager
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}STEP 2: Set Credential Manager (avoid keyring)${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
export ZOWE_CLI_IMPERATIVE_CREDENTIAL_MANAGER="imperative-credential-manager"
echo -e "${GREEN}✓ Set: ZOWE_CLI_IMPERATIVE_CREDENTIAL_MANAGER=imperative-credential-manager${NC}"
echo ""
read -p "Press Enter to continue..."

# Step 3: Initialize config
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}STEP 3: Initialize Zowe Config${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Running: zowe config init --global-config false"
echo ""
zowe config init --global-config false
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Config initialized${NC}"
else
    echo -e "${YELLOW}⚠ Config init had issues (may already exist)${NC}"
fi
echo ""
if [ -f ~/.zowe/zowe.config.json ]; then
    echo -e "${GREEN}✓ Config file exists: ~/.zowe/zowe.config.json${NC}"
    echo -e "${YELLOW}Current config:${NC}"
    cat ~/.zowe/zowe.config.json | python3 -m json.tool 2>/dev/null || cat ~/.zowe/zowe.config.json
else
    echo -e "${RED}✗ Config file not found!${NC}"
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

# Step 5: Set host
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}STEP 5: Set Host${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Running: zowe config set profiles.zosmf.default.host 204.90.115.200 --global-config false"
zowe config set profiles.zosmf.default.host 204.90.115.200 --global-config false
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Host set${NC}"
    VERIFY=$(zowe config get profiles.zosmf.default.host --global-config false 2>/dev/null)
    echo "  Verified: $VERIFY"
else
    echo -e "${RED}✗ Failed to set host${NC}"
fi
echo ""
read -p "Press Enter to continue..."

# Step 6: Set port
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}STEP 6: Set Port (IMPORTANT: 10443, not 443)${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Running: zowe config set profiles.zosmf.default.port 10443 --global-config false"
zowe config set profiles.zosmf.default.port 10443 --global-config false
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Port set${NC}"
    VERIFY=$(zowe config get profiles.zosmf.default.port --global-config false 2>/dev/null)
    echo "  Verified: $VERIFY"
    if [ "$VERIFY" != "10443" ]; then
        echo -e "${RED}✗ Port is wrong! Expected 10443, got $VERIFY${NC}"
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
echo "Running: zowe config set profiles.zosmf.default.user $ZOWE_USER --global-config false"
zowe config set profiles.zosmf.default.user "$ZOWE_USER" --global-config false
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ User set${NC}"
    VERIFY=$(zowe config get profiles.zosmf.default.user --global-config false 2>/dev/null)
    echo "  Verified: $VERIFY"
else
    echo -e "${RED}✗ Failed to set user${NC}"
fi
echo ""
read -p "Press Enter to continue..."

# Step 8: Set password
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}STEP 8: Set Password${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Running: zowe config set profiles.zosmf.default.password [hidden] --global-config false"
zowe config set profiles.zosmf.default.password "$ZOWE_PASS" --global-config false
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Password set${NC}"
    echo "  (Password stored in config)"
else
    echo -e "${RED}✗ Failed to set password${NC}"
fi
echo ""
read -p "Press Enter to continue..."

# Step 9: Set reject-unauthorized
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}STEP 9: Set reject-unauthorized${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Running: zowe config set profiles.zosmf.default.reject-unauthorized false --global-config false"
zowe config set profiles.zosmf.default.reject-unauthorized false --global-config false
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ reject-unauthorized set to false${NC}"
else
    echo -e "${YELLOW}⚠ Failed to set reject-unauthorized (may not be critical)${NC}"
fi
echo ""
read -p "Press Enter to continue..."

# Step 10: Set as default
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}STEP 10: Set Profile as Default${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Running: zowe config set defaults.zosmf default --global-config false"
zowe config set defaults.zosmf default --global-config false
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Default profile set${NC}"
    VERIFY=$(zowe config get defaults.zosmf --global-config false 2>/dev/null)
    echo "  Verified: $VERIFY"
    if [ "$VERIFY" != "default" ]; then
        echo -e "${RED}✗ Default is wrong! Expected 'default', got '$VERIFY'${NC}"
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
echo -e "${YELLOW}Complete config file:${NC}"
if [ -f ~/.zowe/zowe.config.json ]; then
    cat ~/.zowe/zowe.config.json | python3 -m json.tool 2>/dev/null || cat ~/.zowe/zowe.config.json
else
    echo -e "${RED}Config file not found!${NC}"
fi
echo ""
read -p "Press Enter to continue..."

# Step 12: Test connection with profile
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}STEP 12: Test Connection with Profile${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Running: zowe zosmf check status --zosmf-profile default"
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
echo "Running: zowe zosmf check status --host 204.90.115.200 --port 10443 --user $ZOWE_USER --password [hidden] --reject-unauthorized false"
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

