#!/bin/bash
# desc:  Dump PCIe Root Port and Endpoint config registers
# repo:  https://github.com/Timc21/bios_tools
# usage: ./chk_pci_reg.sh [--rp|--all]

# Default: dump both RP and EP
DUMP_MODE="both"

# Parse command line arguments
if [ "$1" == "--rp" ]; then
    DUMP_MODE="rp-only"
elif [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --rp,        Dump only Root Ports (RP)"
    echo "  --all,       Dump both Root Ports and Endpoints (EP) [default]"
    echo "  --help, -h   Show this help message"
    exit 0
elif [ "$1" == "--all" ]; then
    DUMP_MODE="both"
elif [ -n "$1" ]; then
    echo "Unknown option: $1"
    echo "Use --help for usage information"
    exit 1
fi

# Print header
printf "================================================================================================================================\n"
printf "%-12s %-12s %-15s %-12s %-12s %-12s %-15s %-15s %-15s\n" \
"BDF" "UCE_Mask" "UCE_Severity" "CE_Mask" "DPC_Control" "RPPIO_Mask" "RPPIO_Severity" "RPPIO_SysError" "RPPIO_Exception"
printf "================================================================================================================================\n"

# Find all Intel PCIe Root Ports
ROOT_PORTS=$(lspci -d 8086:: | grep "PCI bridge" | cut -d' ' -f1)

if [ -z "$ROOT_PORTS" ]; then
    echo "No PCIe Root Ports found."
    exit 1
fi

for dev in $ROOT_PORTS; do
    # Find AER Capability Base
    AER_BASE=$(lspci -s $dev -vvv | grep -i "Advanced Error Reporting" | grep -oP '\[\K[0-9a-fA-F]+')
    
    # Find DPC Capability Base
    DPC_BASE=$(lspci -s $dev -vvv | grep -i "Downstream Port Containment" | grep -oP '\[\K[0-9a-fA-F]+')
    
    # Read registers, default to "N/A" if not found
    AER_UCE_MASK="N/A"
    AER_UCE_SEV="N/A"
    AER_CE_MASK="N/A"
    DPC_CTRL="N/A"
    RPPIO_MASK="N/A"
    RPPIO_SEV="N/A"
    RPPIO_SYSERR="N/A"
    RPPIO_EXC="N/A"
    
    if [ -n "$AER_BASE" ]; then
        AER_UCE_MASK=$(setpci -s "$dev" $(printf "%x" $((0x$AER_BASE + 0x08))).L)
        AER_UCE_SEV=$(setpci -s "$dev" $(printf "%x" $((0x$AER_BASE + 0x0c))).L)
        AER_CE_MASK=$(setpci -s "$dev" $(printf "%x" $((0x$AER_BASE + 0x14))).L)
    fi
    
    if [ -n "$DPC_BASE" ]; then
        DPC_CTRL=$(setpci -s "$dev" $(printf "%x" $((0x$DPC_BASE + 0x06))).w)
        RPPIO_MASK=$(setpci -s "$dev" $(printf "%x" $((0x$DPC_BASE + 0x10))).L)
        RPPIO_SEV=$(setpci -s "$dev" $(printf "%x" $((0x$DPC_BASE + 0x14))).L)
        RPPIO_SYSERR=$(setpci -s "$dev" $(printf "%x" $((0x$DPC_BASE + 0x18))).L)
        RPPIO_EXC=$(setpci -s "$dev" $(printf "%x" $((0x$DPC_BASE + 0x1C))).L)
    fi
    
    # Print root port row
    printf "%-12s %-12s %-15s %-12s %-12s %-12s %-15s %-15s %-15s\n" \
    "RP -$dev" "$AER_UCE_MASK" "$AER_UCE_SEV" "$AER_CE_MASK" "$DPC_CTRL" "$RPPIO_MASK" "$RPPIO_SEV" "$RPPIO_SYSERR" "$RPPIO_EXC"
    
    # Only dump endpoints if mode is "both"
    if [ "$DUMP_MODE" == "both" ]; then
        # Get secondary bus number from root port's bridge configuration
        # Secondary Bus Register is at offset 0x19 in PCI config space
        SECONDARY_BUS=$(setpci -s "$dev" 19.b 2>/dev/null)
        
        if [ -n "$SECONDARY_BUS" ]; then
            # Convert to decimal for comparison
            SEC_BUS_DEC=$((0x$SECONDARY_BUS))
            
            # Find all devices on buses downstream of this root port
            # Get subordinate bus (last bus in hierarchy)
            SUBORDINATE_BUS=$(setpci -s "$dev" 1a.b 2>/dev/null)
            if [ -n "$SUBORDINATE_BUS" ]; then
                SUB_BUS_DEC=$((0x$SUBORDINATE_BUS))
                
                # Find devices on buses from secondary to subordinate
                for bus_hex in $(seq $SEC_BUS_DEC $SUB_BUS_DEC); do
                    BUS_HEX=$(printf "%02x" $bus_hex)
                    # Find all devices on this bus
                    DOWNSTREAM_DEVS=$(lspci | grep "^$BUS_HEX:" | cut -d' ' -f1)
                    
                    for downstream_dev in $DOWNSTREAM_DEVS; do
                        # Skip the root port itself
                        if [ "$downstream_dev" != "$dev" ]; then
                            # Get device description
                            DEV_DESC=$(lspci -s "$downstream_dev" | cut -d: -f3- | sed 's/^ *//')
                            
                            # Try to read AER registers if available
                            DEV_AER_BASE=$(lspci -s "$downstream_dev" -vvv 2>/dev/null | grep -i "Advanced Error Reporting" | grep -oP '\[\K[0-9a-fA-F]+' | head -1)
                            
                            DEV_UCE_MASK="N/A"
                            DEV_UCE_SEV="N/A"
                            DEV_CE_MASK="N/A"
                            
                            if [ -n "$DEV_AER_BASE" ]; then
                                DEV_UCE_MASK=$(setpci -s "$downstream_dev" $(printf "%x" $((0x$DEV_AER_BASE + 0x08))).L 2>/dev/null)
                                DEV_UCE_SEV=$(setpci -s "$downstream_dev" $(printf "%x" $((0x$DEV_AER_BASE + 0x0c))).L 2>/dev/null)
                                DEV_CE_MASK=$(setpci -s "$downstream_dev" $(printf "%x" $((0x$DEV_AER_BASE + 0x14))).L 2>/dev/null)
                            fi
                            
                            # Print device row with indentation
                            printf "EP -%-8s %-12s %-15s %-12s %-12s %-12s %-15s %-15s %-12s  [%s]\n" \
                            "$downstream_dev" "$DEV_UCE_MASK" "$DEV_UCE_SEV" "$DEV_CE_MASK" "N/A" "N/A" "N/A" "N/A" "N/A" "$DEV_DESC"
                        fi
                    done
                done
            fi
        fi
		echo ""
    fi
    
done

