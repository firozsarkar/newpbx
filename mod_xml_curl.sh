#!/bin/bash

set -e

echo "========================================="
echo " FreeSWITCH XML CURL Auto Installer"
echo "========================================="

FS_CONF="/etc/freeswitch"
AUTOLOAD="$FS_CONF/autoload_configs"
MODULES="$FS_CONF/modules.conf.xml"

echo "[1/8] Checking FreeSWITCH..."

if ! command -v freeswitch >/dev/null; then
    echo "FreeSWITCH not installed!"
    exit 1
fi

echo "[2/8] Enabling mod_xml_curl..."

if [ -f "$MODULES" ]; then
    sed -i '/mod_xml_curl/s/^<!--//g' $MODULES
    sed -i '/mod_xml_curl/s/-->//g' $MODULES

    grep -q "mod_xml_curl" $MODULES || \
    sed -i '/modules>/i\    <load module="mod_xml_curl"/>' $MODULES
fi

echo "[3/8] Creating xml_curl.conf.xml..."

cat > $AUTOLOAD/xml_curl.conf.xml <<EOF
<configuration name="xml_curl.conf" description="cURL XML Gateway">
  <bindings>

    <binding name="pbx_directory">
      <param name="gateway-url"
             value="https://pbx.registercamp.com/bd/pbx_handler.php"
             bindings="directory"/>
      <param name="expires" value="30"/>
    </binding>

    <binding name="pbx_gateways">
      <param name="gateway-url"
             value="https://pbx.registercamp.com/bd/pbx_handler_geteway.php"
             bindings="configuration"/>
      <param name="expires" value="30"/>
    </binding>

    <binding name="pbx_inbound">
      <param name="gateway-url"
             value="https://pbx.registercamp.com/bd/did.php"
             bindings="dialplan"/>
      <param name="expires" value="30"/>
    </binding>

  </bindings>
</configuration>
EOF

echo "[4/8] Disabling local XML configuration..."

mv $FS_CONF/dialplan/default.xml \
   $FS_CONF/dialplan/default.xml.bak 2>/dev/null || true

mv $FS_CONF/directory/default \
   $FS_CONF/directory/default.bak 2>/dev/null || true

echo "[5/8] Checking mod_xml_curl..."

if [ ! -f /usr/lib/freeswitch/mod/mod_xml_curl.so ]; then
    echo "WARNING:"
    echo "mod_xml_curl.so not found."
    echo "Please install freeswitch-mod-xml-curl"
fi

echo "[6/8] Restarting FreeSWITCH..."

systemctl restart freeswitch

sleep 5

echo "[7/8] Reloading XML..."

fs_cli -x reloadxml || true

echo "[8/8] Status"

fs_cli -x "module_exists mod_xml_curl"

echo ""
echo "========================================="
echo " Installation Complete"
echo "========================================="

echo ""
echo "Gateway URLs"
echo "-----------------------------------------"
echo "Directory     : https://pbx.registercamp.com/bd/pbx_handler.php"
echo "Configuration : https://pbx.registercamp.com/bd/pbx_handler_geteway.php"
echo "Dialplan      : https://pbx.registercamp.com/bd/did.php"
echo ""
