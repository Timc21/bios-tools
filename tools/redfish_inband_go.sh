#!/bin/bash
# desc:  In-band Redfish BIOS configuration via BMC
# repo:  https://github.com/Timc21/bios_tools
# usage: ./redfish_inband_go.sh

##############################################
# Config
##############################################

BMC_IP="169.254.0.17"
HOST_IP="169.254.0.18"
BMC_USER="admin"
BMC_PASS=

URL="https://${BMC_IP}/redfish/v1/Systems/Self/Bios/SD"

if [ -z "$BMC_PASS" ]; then
	echo "BMC ID: $BMC_USER"
	read -s -p "BMC Passowrd: " BMC_PASS
	echo
fi


##############################################
# Find USB Interface
##############################################

find_usb_if()
{
    ls -l /sys/class/net | awk '/usb/ {print $9; exit}'
}

##############################################
# Setup Network
##############################################

setup_network()
{
    IFACE=$(find_usb_if)

    if [ -z "$IFACE" ]; then
        echo "[ERROR] USB interface not found"
        exit 1
    fi

    ip addr show "$IFACE" | grep -q "$HOST_IP"

    if [ $? -ne 0 ]; then
        ip addr add ${HOST_IP}/255.255.0.0 dev "$IFACE" 2>/dev/null
    fi

    ip link set "$IFACE" up

    ping -c 1 -W 1 ${BMC_IP} >/dev/null 2>&1

    if [ $? -ne 0 ]; then
        echo "[ERROR] Cannot reach BMC (${BMC_IP})"
        exit 1
    fi
}

##############################################
# Get ETag
##############################################

get_etag()
{
    curl -skI \
    -u ${BMC_USER}:${BMC_PASS} \
    ${URL} \
    | sed -n 's/ETag: "\(.*\)"/\1/p' \
    | tr -d '\r'
}

##############################################
# Get Attribute
##############################################

get_attr()
{
    ATTR=$1

    VALUE=$(curl -sk \
    	-u ${BMC_USER}:${BMC_PASS} \
    	${URL} \
    	| grep -o "${ATTR}\":\"[^\"]*" \
    	| cut -d'"' -f3)
    echo "${ATTR}=${VALUE}"
}

##############################################
# Set Attribute
##############################################

set_attr()
{
    ATTR=$1
    VALUE=$2

    ETAG=$(get_etag)

    if [ -z "$ETAG" ]; then
        echo "[ERROR] Failed to get ETag"
        exit 1
    fi

    echo "[INFO] ETag = $ETAG"

    HTTP_CODE=$(
    curl -sk \
    -w "%{http_code}" \
    -u ${BMC_USER}:${BMC_PASS} \
    -X PATCH \
    -H "Content-Type: application/json" \
    -H "If-Match: \"$ETAG\"" \
    -d "{\"Attributes\":{\"${ATTR}\":\"${VALUE}\"}}" \
    ${URL}
    )

    JSON="{\"Attributes\":{\"${ATTR}\":\"${VALUE}\"}}"

    echo "[INFO] HTTP Code = $HTTP_CODE"

    CURRENT=$(get_attr "$ATTR")

    echo
    echo "Verify:"
    echo "$CURRENT"

    RESULT=$(echo "$CURRENT" | cut -d'=' -f2)

    if [ "$RESULT" = "$VALUE" ]; then
        echo "[PASS]"
    else
        echo "[FAIL]"
    fi
}

##############################################
# List All BIOS Attributes
##############################################
list_attr()
{
    curl -sk \
    -u ${BMC_USER}:${BMC_PASS} \
    ${URL} |
    sed 's/.*"Attributes":{//;s/}.*//' |
    tr ',' '\n' |
    sed 's/"//g;s/:/=/'
}

##############################################
# Show Interface
##############################################

show_info()
{
    echo "USB Interface : $(find_usb_if)"
    echo "BMC IP        : ${BMC_IP}"
    echo "Host IP       : ${HOST_IP}"
    echo "ETag          : $(get_etag)"
}

##############################################
# Main
##############################################

case "$1" in

    get)
        setup_network
        get_attr "$2"
        ;;

    set)
        setup_network
        set_attr "$2" "$3"
        ;;

    etag)
        setup_network
        get_etag
        ;;

    list)
	setup_network
	list_attr
	;;

    info)
        setup_network
        show_info
        ;;

    *)

        echo ""
        echo "Usage:"
        echo "  $0 info"
        echo "  $0 etag"
	echo "  $0 list"
        echo "  $0 get <Attribute>"
        echo "  $0 set <Attribute> <Value>"
        echo ""
        echo "Examples:"
        echo "  $0 get ElcDebugMode"
        echo "  $0 set ElcDebugMode Disabled"
        echo "  $0 set Bay10Enable Enabled"
        echo ""
        ;;
esac
