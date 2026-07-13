#!/bin/bash
# desc:  Inject PCIe errors (CE/UCE/NUCE) via ACPI EINJ
# repo:  https://github.com/Timc21/bios_tools
# usage: ./einj_go.sh [--ce|--nuce|--uce] [--c num]


ce_inject=false
nuce_inject=false
uce_inject=false
loop_cnt=10

#This BDF is for OCP root port, Please change it if you want to change other ports
bdf=0x260800
#bdf=0xb70800

help() {
    echo "Usage: $0 [--ce] [--nuce] [--uce] [--c num]"
    echo "  '--ce'     Inject Correctable Error"
    echo "  '--nuce'   Inject Non-Fatal Uncorrectable Error"
    echo "  '--uce'    Inject Fatal Uncorrectable Error"
    echo "  '--c num'  Set loop count (default: 10)"
	echo "  This script enjects error to OCP root port '26:01.0', Please change it if you want to change other ports. "
    exit 1
}


while [[ $# -gt 0 ]]; do
    case "$1" in
        --ce) ce_inject=true ;;
        --nuce) nuce_inject=true ;;
        --uce) uce_inject=true ;;
        --c)
            if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
                loop_cnt=$2
                shift
            else
                echo "Error: --c requires a positive integer."
                help
            fi
            ;;
        *) help ;;
    esac
    shift
done


$ce_inject || $nuce_inject || $uce_inject || help


modprobe einj param_extension=1

echo 0x4 > /sys/kernel/debug/apei/einj/flags
echo $bdf > /sys/kernel/debug/apei/einj/param4
echo 0xfffffffffffff000 > /sys/kernel/debug/apei/einj/param2


for ((i = 0; i < loop_cnt; i++)); do
    sleep 0.05
    
    $ce_inject && echo "Inject CE $i..." && echo 0x40 > /sys/kernel/debug/apei/einj/error_type && echo 1 > /sys/kernel/debug/apei/einj/error_inject
    $nuce_inject && echo "Inject Fatal UCE $i..." && echo 0x80 > /sys/kernel/debug/apei/einj/error_type && echo 1 > /sys/kernel/debug/apei/einj/error_inject
    $uce_inject && echo "Inject Fatal UCE $i..." && echo 0x100 > /sys/kernel/debug/apei/einj/error_type && echo 1 > /sys/kernel/debug/apei/einj/error_inject

    sleep 0.1
done

echo "done"
