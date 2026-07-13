#!/bin/bash
# desc:  Configure PCIe AER/DPC on Intel Root Ports
# repo:  https://github.com/Timc21/bios_tools
# usage: ./hybrid_aer.sh [OPTIONS]


# Intel PCIe Root Ports
ROOT_PORTS=$(lspci -d 8086: | grep "PCI bridge" | cut -d' ' -f1)

if [ -z "$ROOT_PORTS" ]; then
    echo "No PCIe Root Ports found."
    exit 1
fi

DPC_DISABLE=false
DPC_FATAL=false
DPC_ALL=false
DPC_MSG=false
CTO_ENABLE=false
RP_PIO=false

show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --dpc_dis                   Disable DPC on CPU root ports"
    echo "  --dpc_fatal                 Enable DPC Trigger for Fatal"
    echo "  --dpc_all                   Enable DPC Trigger for both Fatal and Non-Fatal"
    echo "  --dpc_msg                   Enable DPC ERR_COR message"
    echo "  --cto_en                    Enable CTO (Completion Timeout) error reporting"
    echo "  --rppio                     Configure RPPIO error reporting (for IIO Root Ports)"
    echo "  --help                      Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 --dpc_dis --cto_en"
    exit 0
}

for arg in "$@"; do
    case "$arg" in
        --dpc_dis) DPC_DISABLE=true ;;
        --dpc_fatal) DPC_FATAL=true ;;
        --dpc_all) DPC_ALL=true ;;
        --dpc_msg) DPC_MSG=true ;;
        --cto_en) CTO_ENABLE=true ;;
        --rppio) RP_PIO=true ;;
		--help)	show_help ;;
        *) echo "Use --help to see available options."; exit 1 ;;
    esac
done

for RP in $ROOT_PORTS; do
    echo "Configuring Root Port $RP..."

    #change rooterrcmd register bits 2:0 value to 0b001.
    #this will enable MSI for correctable errors only.se
    setpci -s "$RP" 0x12c.L=0x1:0x7 || echo "Failed to set ROOTERRCMD on $RP"

    #change rootctl register bits 2:0 value to 0b110.
    #this will enable SMI for uncorrectable errors, and
    #disable SMI for correctable erorrs.
    setpci -s "$RP" 0x5c.L=0x6:0x7 || echo "Failed to set ROOTCTL on $RP"

	#change dpcctl register bits 1:0 value to 0b00.
	#this will disable DPC on the CPU root ports only.
	#DPC on switch downstream ports will remain enabled.
    if $DPC_DISABLE; then
        echo "Disabling DPC on $RP..."
        setpci -s "$RP" 0x1a4.L=0x00000000:0x00030000 || echo "Failed to disable DPC on $RP"
    fi

    #change dpcctl register bits 1:0 value to 0b01.
    #this will enable DPC Trigger for Fatal on the CPU root ports only.
    if $DPC_FATAL; then
        echo "Enabling DPC Trigger for Fatal on $RP..."
        setpci -s "$RP" 0x1a4.L=0x00010000:0x00030000 || echo "Failed to enable DPC Trigger for Fatal on $RP"
    fi

    #change dpcctl register bits 1:0 value to 0b10.
    #this will enable DPC Trigger for Fatal and Non-Fatal on the CPU root ports only.
    if $DPC_ALL; then
        echo "Enabling DPC Trigger for Fatal and Non-Fatal on $RP..."
        setpci -s "$RP" 0x1a4.L=0x00020000:0x00030000 || echo "Failed to enable DPC Trigger for Fatal and Non-Fatal on $RP"
    fi

	#change dpcctl register bits 4 value to 1b.
	#this will enable he sending of an ERR_COR Message to 
	#indicate that DPC has been triggered.
    if $DPC_MSG; then
        echo "Enabling DPC ERR_COR message on $RP..."
        setpci -s "$RP" 0x1a4.L=0x00100000:0x00100000 || echo "Failed to enable DPC ERR_COR message on $RP"
    fi

	#change erruncmsk register bit 14 value to 0b0.
	#this will unmask 'completion timeout' error reporting
    if $CTO_ENABLE; then
        echo "Enabling CTO error reporting on $RP..."
        setpci -s "$RP" 0x108.L=0x0:0x4000 || echo "Failed to enable CTO error reporting on $RP"
    fi

    #Set RPPIO error reporting
	#The offset 0x1bx is for IIO root port
    if $RP_PIO; then
        echo "Configuring RPPIO error reporting on $RP..."
		# Mask
        setpci -s "$RP" 0x1b0.L=0x00000001 || echo "Failed to set RPPIO Mask on $RP"
		# Severity
        setpci -s "$RP" 0x1b4.L=0x00070707 || echo "Failed to set RPPIO Severity on $RP"
		# SysError
        setpci -s "$RP" 0x1b8.L=0x00060606 || echo "Failed to set RPPIO SysError on $RP"
		# Exception
        setpci -s "$RP" 0x1bc.L=0x00000000 || echo "Failed to set RPPIO Exception on $RP"
    fi
done
echo "done"
