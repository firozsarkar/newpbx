#!/bin/bash

# ============================================================
# FreeSWITCH XML CURL Full Installer
# HostServerBD / Firoz Sarkar
# ============================================================

set -u

# ------------------------------------------------------------
# URLs
# ------------------------------------------------------------

DIRECTORY_URL="https://pbx.registercamp.com/bd/pbx_handler.php"
CONFIGURATION_URL="https://pbx.registercamp.com/bd/pbx_handler_geteway.php"
DIALPLAN_URL="https://pbx.registercamp.com/bd/did.php"

# ------------------------------------------------------------
# Paths
# ------------------------------------------------------------

FS_CONF="/etc/freeswitch"
AUTOLOAD="$FS_CONF/autoload_configs"
MODULES="$AUTOLOAD/modules.conf.xml"
XMLCURL="$AUTOLOAD/xml_curl.conf.xml"

BACKUP_DIR="/root/freeswitch_xmlcurl_backup_$(date +%Y%m%d_%H%M%S)"

# ------------------------------------------------------------
# Colors
# ------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ------------------------------------------------------------
# Functions
# ------------------------------------------------------------

ok() {
    echo -e "${GREEN}[OK]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

fail() {
    echo -e "${RED}[ERROR]${NC} $1"
}

die() {
    fail "$1"
    exit 1
}

line() {
    echo "------------------------------------------------------------"
}

# ------------------------------------------------------------
# Header
# ------------------------------------------------------------

clear 2>/dev/null || true

echo ""
echo "============================================================"
echo "       FreeSWITCH XML CURL FULL INSTALLER"
echo "============================================================"
echo ""
echo "Directory API     : $DIRECTORY_URL"
echo "Configuration API : $CONFIGURATION_URL"
echo "Dialplan API      : $DIALPLAN_URL"
echo ""
echo "============================================================"
echo ""

# ------------------------------------------------------------
# Root check
# ------------------------------------------------------------

if [ "$(id -u)" != "0" ]; then
    die "Please run this script as root."
fi

ok "Running as root."

# ------------------------------------------------------------
# Detect OS
# ------------------------------------------------------------

echo ""
echo "[1/12] Detecting operating system..."
line

if [ -f /etc/os-release ]; then
    . /etc/os-release

    echo "OS      : ${PRETTY_NAME:-Unknown}"
    echo "ID      : ${ID:-Unknown}"
    echo "Version : ${VERSION_ID:-Unknown}"
else
    warn "/etc/os-release not found."
fi

# ------------------------------------------------------------
# Check FreeSWITCH
# ------------------------------------------------------------

echo ""
echo "[2/12] Checking FreeSWITCH..."
line

if command -v freeswitch >/dev/null 2>&1; then

    FS_BIN="$(command -v freeswitch)"

    ok "FreeSWITCH found: $FS_BIN"

    echo ""
    echo "FreeSWITCH Version:"
    freeswitch -version 2>&1 || true

else
    die "FreeSWITCH command not found."
fi

# ------------------------------------------------------------
# Check systemd service
# ------------------------------------------------------------

echo ""
echo "[3/12] Checking FreeSWITCH service..."
line

if systemctl list-unit-files 2>/dev/null | grep -q "^freeswitch.service"; then

    ok "freeswitch.service found."

else

    warn "freeswitch.service was not found."

fi

# ------------------------------------------------------------
# Check configuration
# ------------------------------------------------------------

echo ""
echo "[4/12] Checking FreeSWITCH configuration..."
line

if [ ! -d "$FS_CONF" ]; then
    die "FreeSWITCH configuration directory not found: $FS_CONF"
fi

if [ ! -d "$AUTOLOAD" ]; then
    die "autoload_configs directory not found: $AUTOLOAD"
fi

ok "FreeSWITCH configuration directory found."

echo "Configuration : $FS_CONF"
echo "Autoload      : $AUTOLOAD"

# ------------------------------------------------------------
# Backup
# ------------------------------------------------------------

echo ""
echo "[5/12] Creating configuration backup..."
line

mkdir -p "$BACKUP_DIR"

if [ -f "$MODULES" ]; then
    cp -a "$MODULES" "$BACKUP_DIR/modules.conf.xml"
fi

if [ -f "$XMLCURL" ]; then
    cp -a "$XMLCURL" "$BACKUP_DIR/xml_curl.conf.xml"
fi

if [ -f "$AUTOLOAD/pre_load_modules.conf.xml" ]; then
    cp -a "$AUTOLOAD/pre_load_modules.conf.xml" \
        "$BACKUP_DIR/pre_load_modules.conf.xml"
fi

ok "Backup created:"
echo "$BACKUP_DIR"

# ------------------------------------------------------------
# Install curl
# ------------------------------------------------------------

echo ""
echo "[6/12] Checking required tools..."
line

if ! command -v curl >/dev/null 2>&1; then

    info "curl is not installed."

    if command -v apt-get >/dev/null 2>&1; then

        apt-get update
        apt-get install -y curl

    elif command -v dnf >/dev/null 2>&1; then

        dnf install -y curl

    elif command -v yum >/dev/null 2>&1; then

        yum install -y curl

    else
        die "Cannot install curl automatically."
    fi

fi

ok "curl is available."

# ------------------------------------------------------------
# Find mod_xml_curl
# ------------------------------------------------------------

echo ""
echo "[7/12] Checking mod_xml_curl..."
line

MOD_XML_CURL=""

SEARCH_PATHS="
/usr/lib/freeswitch/mod
/usr/lib64/freeswitch/mod
/usr/local/freeswitch/mod
/opt/freeswitch/mod
"

for DIR in $SEARCH_PATHS; do

    if [ -f "$DIR/mod_xml_curl.so" ]; then
        MOD_XML_CURL="$DIR/mod_xml_curl.so"
        break
    fi

done

# Additional search
if [ -z "$MOD_XML_CURL" ]; then

    MOD_XML_CURL="$(find \
        /usr \
        /usr/local \
        /opt \
        -type f \
        -name "mod_xml_curl.so" \
        2>/dev/null | head -n 1)"

fi

if [ -n "$MOD_XML_CURL" ]; then

    ok "mod_xml_curl.so found:"
    echo "$MOD_XML_CURL"

else

    warn "mod_xml_curl.so was NOT found."

    echo ""
    echo "Trying to install FreeSWITCH XML CURL module..."
    echo ""

    INSTALL_SUCCESS=0

    # Debian / Ubuntu
    if command -v apt-get >/dev/null 2>&1; then

        info "APT detected."

        apt-get update

        if apt-get install -y freeswitch-mod-xml-curl; then
            INSTALL_SUCCESS=1
        else
            warn "APT package freeswitch-mod-xml-curl installation failed."
        fi

    # RHEL / AlmaLinux / Rocky / CentOS
    elif command -v dnf >/dev/null 2>&1; then

        info "DNF detected."

        if dnf install -y freeswitch-mod-xml-curl; then
            INSTALL_SUCCESS=1
        else
            warn "DNF package installation failed."
        fi

    elif command -v yum >/dev/null 2>&1; then

        info "YUM detected."

        if yum install -y freeswitch-mod-xml-curl; then
            INSTALL_SUCCESS=1
        else
            warn "YUM package installation failed."
        fi

    fi

    # Search again
    MOD_XML_CURL="$(find \
        /usr \
        /usr/local \
        /opt \
        -type f \
        -name "mod_xml_curl.so" \
        2>/dev/null | head -n 1)"

    if [ -n "$MOD_XML_CURL" ]; then

        ok "mod_xml_curl.so installed successfully."
        echo "$MOD_XML_CURL"

    else

        fail "mod_xml_curl.so is still not available."

        echo ""
        echo "============================================================"
        echo " IMPORTANT"
        echo "============================================================"
        echo ""
        echo "Your FreeSWITCH installation does not currently contain"
        echo "mod_xml_curl."
        echo ""
        echo "This usually means FreeSWITCH was installed without the"
        echo "XML CURL module/package."
        echo ""

        die "Cannot continue without mod_xml_curl."

    fi

fi

# ------------------------------------------------------------
# Check modules.conf.xml
# ------------------------------------------------------------

echo ""
echo "[8/12] Configuring mod_xml_curl..."
line

if [ ! -f "$MODULES" ]; then

    warn "modules.conf.xml not found."

    cat > "$MODULES" <<'EOF'
<configuration name="modules.conf" description="Modules">
    <modules>
    </modules>
</configuration>
EOF

    ok "Created modules.conf.xml."

fi

# ------------------------------------------------------------
# Remove old mod_xml_curl entries
# ------------------------------------------------------------

cp -a "$MODULES" "$BACKUP_DIR/modules.conf.xml.before_edit"

sed -i '/mod_xml_curl/d' "$MODULES"

# ------------------------------------------------------------
# Add module
# ------------------------------------------------------------

if grep -q '<load module="mod_xml_curl"/>' "$MODULES"; then

    ok "mod_xml_curl already configured."

else

    if grep -q '</modules>' "$MODULES"; then

        sed -i \
        '/<\/modules>/i\        <load module="mod_xml_curl"/>' \
        "$MODULES"

    else

        cat >> "$MODULES" <<'EOF'

<load module="mod_xml_curl"/>
EOF

    fi

    ok "mod_xml_curl added to modules.conf.xml."

fi

# ------------------------------------------------------------
# Create XML CURL configuration
# ------------------------------------------------------------

echo ""
echo "Creating xml_curl.conf.xml..."

cat > "$XMLCURL" <<EOF
<configuration name="xml_curl.conf" description="XML CURL">

    <bindings>

        <binding name="pbx_directory">

            <param
                name="gateway-url"
                value="$DIRECTORY_URL"
                bindings="directory"
            />

            <param
                name="timeout"
                value="10"
            />

        </binding>


        <binding name="pbx_configuration">

            <param
                name="gateway-url"
                value="$CONFIGURATION_URL"
                bindings="configuration"
            />

            <param
                name="timeout"
                value="10"
            />

        </binding>


        <binding name="pbx_dialplan">

            <param
                name="gateway-url"
                value="$DIALPLAN_URL"
                bindings="dialplan"
            />

            <param
                name="timeout"
                value="10"
            />

        </binding>

    </bindings>

</configuration>
EOF

ok "xml_curl.conf.xml created."

# ------------------------------------------------------------
# XML validation
# ------------------------------------------------------------

echo ""
echo "Validating XML configuration..."

if command -v xmllint >/dev/null 2>&1; then

    if xmllint --noout "$MODULES" >/dev/null 2>&1; then
        ok "modules.conf.xml XML is valid."
    else
        fail "modules.conf.xml XML syntax error."
        xmllint --noout "$MODULES" 2>&1 || true
        exit 1
    fi

    if xmllint --noout "$XMLCURL" >/dev/null 2>&1; then
        ok "xml_curl.conf.xml XML is valid."
    else
        fail "xml_curl.conf.xml XML syntax error."
        xmllint --noout "$XMLCURL" 2>&1 || true
        exit 1
    fi

else

    warn "xmllint is not installed."
    warn "Skipping XML syntax validation."

fi

# ------------------------------------------------------------
# Show configuration
# ------------------------------------------------------------

echo ""
echo "Current mod_xml_curl configuration:"
line

cat "$XMLCURL"

line

# ------------------------------------------------------------
# API connectivity test
# ------------------------------------------------------------

echo ""
echo "[9/12] Testing API connectivity..."
line

test_api() {

    NAME="$1"
    URL="$2"

    echo ""
    echo "Testing: $NAME"
    echo "URL    : $URL"

    HTTP_CODE=$(curl \
        -L \
        -k \
        -s \
        -o /tmp/xmlcurl_response \
        -w "%{http_code}" \
        --connect-timeout 10 \
        --max-time 20 \
        "$URL" 2>/dev/null)

    if [ -z "$HTTP_CODE" ]; then
        HTTP_CODE="000"
    fi

    echo "HTTP   : $HTTP_CODE"

    if [ "$HTTP_CODE" = "200" ]; then

        ok "$NAME reachable."

        echo "Response preview:"
        head -c 300 /tmp/xmlcurl_response 2>/dev/null || true
        echo ""
        echo ""

    else

        warn "$NAME returned HTTP $HTTP_CODE."

        echo "Response:"
        head -c 500 /tmp/xmlcurl_response 2>/dev/null || true
        echo ""

    fi

}

test_api "Directory API" "$DIRECTORY_URL"

test_api "Configuration API" "$CONFIGURATION_URL"

test_api "Dialplan API" "$DIALPLAN_URL"

rm -f /tmp/xmlcurl_response

# ------------------------------------------------------------
# Restart FreeSWITCH
# ------------------------------------------------------------

echo ""
echo "[10/12] Restarting FreeSWITCH..."
line

if systemctl restart freeswitch; then

    sleep 8

    if systemctl is-active --quiet freeswitch; then
        ok "FreeSWITCH is running."
    else
        fail "FreeSWITCH is NOT running."

        echo ""
        echo "FreeSWITCH status:"
        systemctl --no-pager --full status freeswitch 2>&1 | tail -n 80

        exit 1
    fi

else

    fail "FreeSWITCH restart failed."

    echo ""
    echo "FreeSWITCH status:"
    systemctl --no-pager --full status freeswitch 2>&1 | tail -n 80

    exit 1

fi

# ------------------------------------------------------------
# Check module
# ------------------------------------------------------------

echo ""
echo "[11/12] Checking mod_xml_curl..."
line

MODULE_STATUS=$(fs_cli -x "module_exists mod_xml_curl" 2>/dev/null | tr -d '\r\n ')

echo "module_exists result: $MODULE_STATUS"

if [ "$MODULE_STATUS" = "true" ]; then

    ok "mod_xml_curl is LOADED."

else

    warn "mod_xml_curl is not loaded."

    echo ""
    echo "Trying manual module load..."

    LOAD_OUTPUT=$(fs_cli -x "load mod_xml_curl" 2>&1 || true)

    echo "$LOAD_OUTPUT"

    sleep 3

    MODULE_STATUS=$(fs_cli -x "module_exists mod_xml_curl" 2>/dev/null | tr -d '\r\n ')

    echo ""
    echo "Final module status: $MODULE_STATUS"

    if [ "$MODULE_STATUS" = "true" ]; then

        ok "mod_xml_curl loaded successfully."

    else

        fail "mod_xml_curl FAILED TO LOAD."

        echo ""
        echo "============================================================"
        echo "             DIAGNOSTIC INFORMATION"
        echo "============================================================"

        echo ""
        echo "1. Module file:"
        echo "$MOD_XML_CURL"

        echo ""
        echo "2. Module exists:"
        fs_cli -x "module_exists mod_xml_curl" 2>&1 || true

        echo ""
        echo "3. Loaded modules:"
        fs_cli -x "show modules" 2>&1 | grep -i "xml" || true

        echo ""
        echo "4. FreeSWITCH service:"
        systemctl --no-pager --full status freeswitch 2>&1 | tail -n 50

        echo ""
        echo "5. FreeSWITCH log:"
        journalctl -u freeswitch -n 150 --no-pager 2>&1 \
            | grep -i -E \
            "xml_curl|mod_xml|error|failed|cannot|undefined|symbol" \
            | tail -n 100 || true

        echo ""
        echo "6. modules.conf.xml:"
        grep -n -C 3 "xml_curl" "$MODULES" 2>/dev/null || true

        echo ""
        echo "============================================================"
        echo " INSTALLATION FAILED"
        echo "============================================================"
        echo ""

        echo "Backup:"
        echo "$BACKUP_DIR"

        exit 1
    fi

fi

# ------------------------------------------------------------
# Reload XML
# ------------------------------------------------------------

echo ""
echo "[12/12] Reloading FreeSWITCH XML..."
line

RELOAD_OUTPUT=$(fs_cli -x "reloadxml" 2>&1 || true)

echo "$RELOAD_OUTPUT"

sleep 3

# ------------------------------------------------------------
# Final checks
# ------------------------------------------------------------

echo ""
echo "============================================================"
echo "                  FINAL CHECK"
echo "============================================================"

echo ""

echo "FreeSWITCH service:"
if systemctl is-active --quiet freeswitch; then
    ok "RUNNING"
else
    fail "NOT RUNNING"
fi

echo ""

echo "mod_xml_curl:"
FINAL_STATUS=$(fs_cli -x "module_exists mod_xml_curl" 2>/dev/null | tr -d '\r\n ')

if [ "$FINAL_STATUS" = "true" ]; then
    ok "LOADED"
else
    fail "NOT LOADED"
fi

echo ""

echo "Configuration:"
echo "$XMLCURL"

echo ""

echo "Backup:"
echo "$BACKUP_DIR"

echo ""
echo "============================================================"

if [ "$FINAL_STATUS" = "true" ]; then

    echo -e "${GREEN}        XML CURL INSTALLATION SUCCESSFUL${NC}"

else

    echo -e "${RED}        XML CURL INSTALLATION FAILED${NC}"

fi

echo "============================================================"
echo ""

echo "Gateway URLs"
echo "------------------------------------------------------------"
echo "Directory     : $DIRECTORY_URL"
echo "Configuration : $CONFIGURATION_URL"
echo "Dialplan      : $DIALPLAN_URL"
echo ""

# ------------------------------------------------------------
# Exit status
# ------------------------------------------------------------

if [ "$FINAL_STATUS" = "true" ]; then
    exit 0
else
    exit 1
fi
