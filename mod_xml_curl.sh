#!/bin/bash

set -u

# ============================================================
# FreeSWITCH XML CURL Auto Installer
# Directory + Configuration + Dialplan
# ============================================================

FS_CONF="/etc/freeswitch"
AUTOLOAD="$FS_CONF/autoload_configs"
MODULES="$AUTOLOAD/modules.conf.xml"
PRELOAD="$AUTOLOAD/pre_load_modules.conf.xml"
XMLCURL="$AUTOLOAD/xml_curl.conf.xml"

DIRECTORY_URL="https://pbx.registercamp.com/bd/pbx_handler.php"
GATEWAY_URL="https://pbx.registercamp.com/bd/pbx_handler_geteway.php"
DIALPLAN_URL="https://pbx.registercamp.com/bd/did.php"

BACKUP_DIR="/root/freeswitch_xmlcurl_backup_$(date +%Y%m%d_%H%M%S)"

# ============================================================
# Colors
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================
# Functions
# ============================================================

success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error_msg() {
    echo -e "${RED}[ERROR]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

die() {
    error_msg "$1"
    exit 1
}

# ============================================================
# Header
# ============================================================

clear

echo "=========================================================="
echo "       FreeSWITCH XML CURL Auto Installer"
echo "=========================================================="
echo ""
echo "Directory     : $DIRECTORY_URL"
echo "Configuration : $GATEWAY_URL"
echo "Dialplan      : $DIALPLAN_URL"
echo ""
echo "=========================================================="
echo ""

# ============================================================
# Root Check
# ============================================================

if [ "$(id -u)" -ne 0 ]; then
    die "Please run this script as root."
fi

# ============================================================
# Detect FreeSWITCH
# ============================================================

echo "[1/10] Checking FreeSWITCH..."

if command -v freeswitch >/dev/null 2>&1; then
    FS_BIN="$(command -v freeswitch)"
    success "FreeSWITCH binary found: $FS_BIN"
else
    die "FreeSWITCH is not installed or freeswitch command was not found."
fi

# ============================================================
# Detect Configuration Directory
# ============================================================

echo ""
echo "[2/10] Checking FreeSWITCH configuration..."

if [ ! -d "$FS_CONF" ]; then
    die "FreeSWITCH configuration directory not found: $FS_CONF"
fi

if [ ! -d "$AUTOLOAD" ]; then
    die "FreeSWITCH autoload_configs directory not found: $AUTOLOAD"
fi

success "Configuration directory found."

# ============================================================
# Backup
# ============================================================

echo ""
echo "[3/10] Creating backup..."

mkdir -p "$BACKUP_DIR"

if [ -f "$MODULES" ]; then
    cp -a "$MODULES" "$BACKUP_DIR/"
fi

if [ -f "$PRELOAD" ]; then
    cp -a "$PRELOAD" "$BACKUP_DIR/"
fi

if [ -f "$XMLCURL" ]; then
    cp -a "$XMLCURL" "$BACKUP_DIR/"
fi

success "Backup created:"
echo "       $BACKUP_DIR"

# ============================================================
# Check mod_xml_curl module
# ============================================================

echo ""
echo "[4/10] Checking mod_xml_curl module..."

MOD_PATHS=(
    "/usr/lib/freeswitch/mod/mod_xml_curl.so"
    "/usr/local/freeswitch/mod/mod_xml_curl.so"
    "/usr/lib64/freeswitch/mod/mod_xml_curl.so"
)

MOD_XML_CURL=""

for path in "${MOD_PATHS[@]}"; do
    if [ -f "$path" ]; then
        MOD_XML_CURL="$path"
        break
    fi
done

if [ -z "$MOD_XML_CURL" ]; then
    MOD_XML_CURL="$(find /usr /usr/local -type f -name "mod_xml_curl.so" 2>/dev/null | head -n 1)"
fi

if [ -n "$MOD_XML_CURL" ]; then
    success "mod_xml_curl.so found:"
    echo "       $MOD_XML_CURL"
else
    error_msg "mod_xml_curl.so was not found."

    echo ""
    echo "Trying to detect package manager..."

    if command -v apt-get >/dev/null 2>&1; then
        info "Debian/Ubuntu detected."
        echo ""
        echo "Installing FreeSWITCH XML CURL package..."

        apt-get update -y >/dev/null 2>&1 || true

        apt-get install -y freeswitch-mod-xml-curl || {
            warning "Package installation failed."
            warning "Your FreeSWITCH installation may be from source."
        }

    elif command -v dnf >/dev/null 2>&1; then
        info "RHEL/AlmaLinux/Rocky detected."

        dnf install -y freeswitch-mod-xml-curl || {
            warning "Package installation failed."
        }

    elif command -v yum >/dev/null 2>&1; then
        info "YUM detected."

        yum install -y freeswitch-mod-xml-curl || {
            warning "Package installation failed."
        }
    fi

    # Search again
    MOD_XML_CURL="$(find /usr /usr/local -type f -name "mod_xml_curl.so" 2>/dev/null | head -n 1)"

    if [ -z "$MOD_XML_CURL" ]; then
        die "mod_xml_curl.so could not be installed/found."
    fi

    success "mod_xml_curl.so is now available:"
    echo "       $MOD_XML_CURL"
fi

# ============================================================
# Enable mod_xml_curl
# ============================================================

echo ""
echo "[5/10] Enabling mod_xml_curl..."

if [ ! -f "$MODULES" ]; then
    die "modules.conf.xml not found: $MODULES"
fi

# Remove existing mod_xml_curl lines from main modules file
sed -i '/<load module="mod_xml_curl"\/>/d' "$MODULES"
sed -i '/<!--.*mod_xml_curl.*-->/d' "$MODULES"

# Create pre_load_modules.conf.xml
# XML CURL should be available early when used for configuration.
cat > "$PRELOAD" <<'EOF'
<configuration name="pre_load_modules.conf" description="Modules">
    <modules>
        <load module="mod_xml_curl"/>
    </modules>
</configuration>
EOF

success "mod_xml_curl configured for early loading."

# ============================================================
# Create xml_curl.conf.xml
# ============================================================

echo ""
echo "[6/10] Creating xml_curl.conf.xml..."

cat > "$XMLCURL" <<EOF
<configuration name="xml_curl.conf" description="cURL XML Gateway">

    <bindings>

        <!-- Directory / SIP User Authentication -->
        <binding name="pbx_directory">
            <param name="gateway-url"
                   value="$DIRECTORY_URL"
                   bindings="directory"/>
            <param name="timeout" value="10"/>
            <param name="connect-timeout" value="5"/>
            <param name="cache" value="false"/>
        </binding>

        <!-- Gateway / Configuration -->
        <binding name="pbx_configuration">
            <param name="gateway-url"
                   value="$GATEWAY_URL"
                   bindings="configuration"/>
            <param name="timeout" value="10"/>
            <param name="connect-timeout" value="5"/>
            <param name="cache" value="false"/>
        </binding>

        <!-- Dialplan -->
        <binding name="pbx_dialplan">
            <param name="gateway-url"
                   value="$DIALPLAN_URL"
                   bindings="dialplan"/>
            <param name="timeout" value="10"/>
            <param name="connect-timeout" value="5"/>
            <param name="cache" value="false"/>
        </binding>

    </bindings>

</configuration>
EOF

success "xml_curl.conf.xml created."

# ============================================================
# Validate XML files
# ============================================================

echo ""
echo "[7/10] Validating XML configuration..."

if command -v xmllint >/dev/null 2>&1; then

    if xmllint --noout "$XMLCURL" >/dev/null 2>&1; then
        success "xml_curl.conf.xml XML syntax is valid."
    else
        error_msg "xml_curl.conf.xml contains invalid XML."
        xmllint --noout "$XMLCURL"
        exit 1
    fi

    if xmllint --noout "$PRELOAD" >/dev/null 2>&1; then
        success "pre_load_modules.conf.xml XML syntax is valid."
    else
        error_msg "pre_load_modules.conf.xml contains invalid XML."
        xmllint --noout "$PRELOAD"
        exit 1
    fi

else
    warning "xmllint is not installed. Skipping XML syntax validation."
fi

# ============================================================
# Test API URLs
# ============================================================

echo ""
echo "[8/10] Testing API URLs..."

test_url() {

    local NAME="$1"
    local URL="$2"

    echo ""
    echo "Testing $NAME"
    echo "URL: $URL"

    HTTP_CODE=$(curl \
        -L \
        -k \
        -s \
        -o /tmp/xmlcurl_test_response \
        -w "%{http_code}" \
        --connect-timeout 10 \
        --max-time 20 \
        "$URL" 2>/dev/null || echo "000")

    if [ "$HTTP_CODE" = "200" ]; then

        success "$NAME returned HTTP 200."

        if grep -q "<document" /tmp/xmlcurl_test_response 2>/dev/null; then
            success "$NAME returned FreeSWITCH XML document."
        else
            warning "$NAME returned HTTP 200 but response does not contain <document>."
            echo ""
            echo "Response preview:"
            head -c 500 /tmp/xmlcurl_test_response
            echo ""
        fi

    else

        error_msg "$NAME returned HTTP $HTTP_CODE."

        echo ""
        echo "Response:"
        head -c 1000 /tmp/xmlcurl_test_response 2>/dev/null || true
        echo ""

        return 1
    fi
}

API_FAILED=0

test_url "Directory API" "$DIRECTORY_URL" || API_FAILED=1
test_url "Configuration API" "$GATEWAY_URL" || API_FAILED=1
test_url "Dialplan API" "$DIALPLAN_URL" || API_FAILED=1

rm -f /tmp/xmlcurl_test_response

if [ "$API_FAILED" -eq 1 ]; then
    warning "One or more API tests failed."
    warning "FreeSWITCH XML CURL may not work until the API returns valid XML."
else
    success "All API endpoints are reachable."
fi

# ============================================================
# Restart FreeSWITCH
# ============================================================

echo ""
echo "[9/10] Restarting FreeSWITCH..."

if systemctl restart freeswitch; then
    sleep 8
    success "FreeSWITCH restarted."
else
    error_msg "FreeSWITCH restart failed."

    echo ""
    echo "Last FreeSWITCH log:"
    journalctl -u freeswitch -n 80 --no-pager

    exit 1
fi

# ============================================================
# Reload XML
# ============================================================

echo ""
echo "Reloading XML..."

fs_cli -x "reloadxml" >/tmp/fs_reloadxml 2>&1 || true

cat /tmp/fs_reloadxml

rm -f /tmp/fs_reloadxml

sleep 3

# ============================================================
# Final Module Check
# ============================================================

echo ""
echo "[10/10] Final verification..."
echo ""

MODULE_STATUS=$(fs_cli -x "module_exists mod_xml_curl" 2>/dev/null | tr -d '\r\n')

echo "mod_xml_curl status: $MODULE_STATUS"

if [ "$MODULE_STATUS" = "true" ]; then
    success "mod_xml_curl is LOADED."
else

    error_msg "mod_xml_curl is NOT loaded."

    echo ""
    echo "Trying manual module load..."

    LOAD_RESULT=$(fs_cli -x "load mod_xml_curl" 2>&1 || true)

    echo "$LOAD_RESULT"

    sleep 3

    MODULE_STATUS=$(fs_cli -x "module_exists mod_xml_curl" 2>/dev/null | tr -d '\r\n')

    if [ "$MODULE_STATUS" = "true" ]; then
        success "mod_xml_curl loaded successfully."
    else
        error_msg "mod_xml_curl still could not be loaded."

        echo ""
        echo "=========================================================="
        echo " FreeSWITCH Diagnostic Information"
        echo "=========================================================="

        echo ""
        echo "Module file:"
        echo "$MOD_XML_CURL"

        echo ""
        echo "Module exists:"
        fs_cli -x "module_exists mod_xml_curl" 2>&1 || true

        echo ""
        echo "Loaded modules:"
        fs_cli -x "show modules" 2>&1 | grep -i "xml_curl" || true

        echo ""
        echo "FreeSWITCH service status:"
        systemctl --no-pager --full status freeswitch 2>&1 | tail -n 40

        echo ""
        echo "Recent XML CURL errors:"
        journalctl -u freeswitch -n 150 --no-pager 2>&1 \
            | grep -i -E "xml_curl|mod_xml|error|failed|cannot|undefined" \
            | tail -n 80 || true

        echo ""
        echo "=========================================================="
        echo " Installation completed WITH ERRORS"
        echo "=========================================================="

        exit 1
    fi
fi

# ============================================================
# Show XML CURL config
# ============================================================

echo ""
echo "Current XML CURL configuration:"
echo "----------------------------------------------------------"

cat "$XMLCURL"

echo ""
echo "----------------------------------------------------------"

# ============================================================
# Final Result
# ============================================================

echo ""
echo "=========================================================="
echo "        XML CURL INSTALLATION SUCCESSFUL"
echo "=========================================================="

echo ""
echo "FreeSWITCH:"
echo "  Status        : RUNNING"

echo ""
echo "mod_xml_curl:"
echo "  Status        : LOADED"

echo ""
echo "XML CURL Backup:"
echo "  $BACKUP_DIR"

echo ""
echo "Gateway URLs:"
echo "----------------------------------------------------------"
echo "Directory:"
echo "$DIRECTORY_URL"

echo ""
echo "Configuration:"
echo "$GATEWAY_URL"

echo ""
echo "Dialplan:"
echo "$DIALPLAN_URL"

echo ""
echo "Configuration File:"
echo "$XMLCURL"

echo ""
echo "=========================================================="
echo "                 ALL DONE"
echo "=========================================================="
echo ""
