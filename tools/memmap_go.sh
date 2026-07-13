#!/bin/bash
# desc:  Summarize /proc/iomem memory map with MTRR cross-check
# repo:  https://github.com/Timc21/bios_tools
# usage: ./memmap_go.sh [/proc/iomem file or leave blank for live system]

INPUT="${1:-/proc/iomem}"

echo "============================================="
echo " Physical Memory Map Summary"
echo " Source: $INPUT"
echo "============================================="
echo ""

# Function to convert size to human readable
human_size() {
    local bytes=$1
    if [ $bytes -ge 1073741824 ]; then
        echo "$(echo "scale=2; $bytes/1073741824" | bc)GB"
    elif [ $bytes -ge 1048576 ]; then
        echo "$(echo "scale=2; $bytes/1048576" | bc)MB"
    elif [ $bytes -ge 1024 ]; then
        echo "$(echo "scale=2; $bytes/1024" | bc)KB"
    else
        echo "${bytes}B"
    fi
}

# Collect data grouped by type
declare -A type_total
declare -A type_count
declare -A type_ranges

while IFS= read -r line; do
    # Only process top-level entries (no leading spaces)
    if [[ "$line" =~ ^([0-9a-f]+)-([0-9a-f]+)\ :\ (.+)$ ]]; then
        start_hex="${BASH_REMATCH[1]}"
        end_hex="${BASH_REMATCH[2]}"
        type="${BASH_REMATCH[3]}"

        start=$((16#$start_hex))
        end=$((16#$end_hex))
        size=$((end - start + 1))
        hr=$(human_size $size)

        type_total["$type"]=$(( ${type_total["$type"]:-0} + size ))
        type_count["$type"]=$(( ${type_count["$type"]:-0} + 1 ))
        type_ranges["$type"]+="    0x${start_hex} - 0x${end_hex} (${hr})"$'\n'
    fi
done < "$INPUT"

# Print summary with ranges, sorted by type name
printf "%-35s %10s %8s\n" "Type" "Total Size" "Regions"
printf "%-35s %10s %8s\n" "===================================" "==========" "========"

for type in $(echo "${!type_total[@]}" | tr ' ' '\n' | sort); do
    size=${type_total[$type]}
    count=${type_count[$type]}
    hr=$(human_size $size)
    printf "\n%-35s %10s %8d\n" "$type" "$hr" "$count"
    echo "${type_ranges[$type]}"
done

echo ""
echo "============================================="
echo " MTRR Settings"
echo "============================================="
echo ""

if [ -f /proc/mtrr ]; then
    while IFS= read -r line; do
        if [[ "$line" =~ ^(reg[0-9]+):\ base=0x([0-9a-f]+)\ \(([^)]+)\),\ size=([0-9]+)MB,\ count=([0-9]+):\ (.+)$ ]]; then
            reg="${BASH_REMATCH[1]}"
            base="${BASH_REMATCH[2]}"
            base_hr="${BASH_REMATCH[3]}"
            size_mb="${BASH_REMATCH[4]}"
            type="${BASH_REMATCH[6]}"
            end_val=$(( 16#$base + size_mb * 1048576 - 1 ))
            end_hex=$(printf "%x" $end_val)
            printf "  %s: 0x%s - 0x%s (%sMB) [%s]\n" "$reg" "$base" "$end_hex" "$size_mb" "$type"
        else
            echo "  $line"
        fi
    done < /proc/mtrr
else
    echo "  /proc/mtrr not available"
fi

echo ""
echo "============================================="
echo " Coverage Check: System RAM vs MTRR"
echo "============================================="
echo ""

total_ram=0
ram_count=0
while IFS= read -r line; do
    if [[ "$line" =~ ^([0-9a-f]+)-([0-9a-f]+)\ :\ System\ RAM$ ]]; then
        start=$((16#${BASH_REMATCH[1]}))
        end=$((16#${BASH_REMATCH[2]}))
        size=$((end - start + 1))
        total_ram=$((total_ram + size))
        ram_count=$((ram_count + 1))
    fi
done < "$INPUT"

echo "  System RAM regions: $ram_count"
echo "  Total System RAM:   $(human_size $total_ram)"
echo ""
echo "  Verify: All System RAM ranges should fall within"
echo "  write-back MTRR regions for optimal performance."
echo ""
echo "Done."
