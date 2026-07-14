#!/bin/bash
# desc:  Summarize /proc/iomem memory map with MTRR cross-check
# repo:  https://github.com/Timc21/bios_tools
# usage: sudo ./memmap_go.sh [--detail] [saved_iomem_file]

DETAIL=0
INPUT="/proc/iomem"

for arg in "$@"; do
    case "$arg" in
        --detail|-d) DETAIL=1 ;;
        --help|-h)
            echo "Usage: sudo $0 [--detail] [iomem_file]"
            echo "  --detail, -d   Show all region lists and address map"
            echo "  Default: summary + visual map + MTRR only"
            exit 0 ;;
        *) INPUT="$arg" ;;
    esac
done

echo "============================================="
echo " Physical Memory Map Summary"
echo " Source: $INPUT"
echo "============================================="
echo ""

python3 - "$INPUT" "$DETAIL" << 'PYTHON_SCRIPT'
import sys
from collections import OrderedDict

input_file = sys.argv[1]
detail_mode = sys.argv[2] == '1'

def human_size(b):
    if b >= 1099511627776: return f"{b/1099511627776:.2f}TB"
    if b >= 1073741824: return f"{b/1073741824:.2f}GB"
    if b >= 1048576: return f"{b/1048576:.2f}MB"
    if b >= 1024: return f"{b/1024:.2f}KB"
    return f"{b}B"

def categorize(mem_type):
    t = mem_type.lower()
    if 'system ram' in t: return 'System RAM'
    elif 'acpi non-volatile' in t or 'acpi nvs' in t: return 'ACPI NVS'
    elif 'acpi' in t: return 'ACPI Tables'
    elif 'reserved' in t: return 'Reserved'
    else: return 'MMIO (PCI/Devices)'

category_order = ['System RAM', 'Reserved', 'ACPI Tables', 'ACPI NVS', 'MMIO (PCI/Devices)']
type_data = OrderedDict((cat, {'total': 0, 'count': 0, 'ranges': []}) for cat in category_order)

with open(input_file, 'r') as f:
    for line in f:
        if line[0:1] in ' \t': continue
        line = line.strip()
        if ' : ' not in line: continue
        parts = line.split(' : ', 1)
        addr_range, mem_type = parts[0].strip(), parts[1].strip()
        if '-' not in addr_range: continue
        start_hex, end_hex = addr_range.split('-', 1)
        try:
            start, end = int(start_hex, 16), int(end_hex, 16)
        except ValueError: continue
        size = end - start + 1
        cat = categorize(mem_type)
        type_data[cat]['total'] += size
        type_data[cat]['count'] += 1
        type_data[cat]['ranges'].append((start, end, size, mem_type))

# --- SUMMARY TABLE (always shown) ---
dram_total = sum(type_data[c]['total'] for c in ['System RAM', 'Reserved', 'ACPI Tables', 'ACPI NVS'])
mmio_below_4g = sum(sz for s,e,sz,n in type_data['MMIO (PCI/Devices)']['ranges'] if s < 0x100000000)
mmio_above_4g = sum(sz for s,e,sz,n in type_data['MMIO (PCI/Devices)']['ranges'] if s >= 0x100000000)

print(f"{'Category':<25} {'Size':>12}  {'Note'}")
print(f"{'-'*25} {'-'*12}  {'-'*20}")
print(f"{'System RAM':<25} {human_size(type_data['System RAM']['total']):>12}  OS usable")
print(f"{'Reserved':<25} {human_size(type_data['Reserved']['total']):>12}  FW runtime/SMM")
print(f"{'ACPI Tables':<25} {human_size(type_data['ACPI Tables']['total']):>12}  reclaimable")
print(f"{'ACPI NVS':<25} {human_size(type_data['ACPI NVS']['total']):>12}  FW persistent")
print(f"{'MMIO (below 4GB)':<25} {human_size(mmio_below_4g):>12}  PCI ECAM + BAR")
print(f"{'MMIO (above 4GB)':<25} {human_size(mmio_above_4g):>12}  64-bit PCI windows")
print(f"{'-'*25} {'-'*12}")
print(f"{'Physical DRAM':<25} {human_size(dram_total):>12}")

# --- VISUAL MAP (always shown) ---
tohm = max(e+1 for s,e,sz,n in type_data['System RAM']['ranges'])
mmio_lo_start = min((s for s,e,sz,n in type_data['MMIO (PCI/Devices)']['ranges'] if s < 0x100000000), default=0x80000000)
mmio_lo_end = max((e for s,e,sz,n in type_data['MMIO (PCI/Devices)']['ranges'] if e < 0x100000000), default=0xFFFFFFFF)
dram_lo_end = max((e for s,e,sz,n in type_data['System RAM']['ranges'] if s < 0x100000000), default=0)
dram_hi_start = min((s for s,e,sz,n in type_data['System RAM']['ranges'] if s >= 0x100000000), default=0)
dram_hi_end = max((e for s,e,sz,n in type_data['System RAM']['ranges'] if s >= 0x100000000), default=0)

print(f"""
 {hex(tohm):<18} TOHM
 +-------------------------------+
 |         DRAM HIGH             | {hex(dram_hi_start)}-{hex(dram_hi_end)}
 +-------------------------------+ 4GB (0x100000000)
 |         FLASH / Legacy IO     | 0xFF000000-0xFFFFFFFF
 + - - - - - - - - - - - - - - - +
 |         MMIO LOW              | {hex(mmio_lo_start)}-{hex(mmio_lo_end)}
 |         PCI ECAM + BAR space  |
 +-------------------------------+ {hex(mmio_lo_start)}
 |         Reserved / ACPI       | TSEG/DPR/Runtime/NVS
 + - - - - - - - - - - - - - - - +
 |         DRAM LOW (OS usable)  | 0x100000-{hex(dram_lo_end)}
 +-------------------------------+ 1MB (0x100000)
 |         Legacy (VGA/ROM)      | 0xA0000-0xFFFFF
 +-------------------------------+ 640KB (0xA0000)
 |         DOS Conventional      | 0x0-0x9FFFF
 +-------------------------------+ 0x0
""")

mmio_hi = [(s,e,sz,n) for s,e,sz,n in type_data['MMIO (PCI/Devices)']['ranges'] if s >= 0x100000000]
if mmio_hi:
    print(f" MMIOH: {hex(min(s for s,e,sz,n in mmio_hi))} - {hex(max(e for s,e,sz,n in mmio_hi))} ({len(mmio_hi)} windows)")

# --- DETAIL MODE: region lists + address map ---
if detail_mode:
    print(f"\n{'='*60}")
    print(f" Detailed Region List")
    print(f"{'='*60}")

    for cat in category_order:
        d = type_data[cat]
        if d['count'] == 0: continue
        print(f"\n[{cat}] ({d['count']} regions, {human_size(d['total'])})")
        for start, end, size, name in sorted(d['ranges']):
            print(f"  0x{start:012x} - 0x{end:012x} ({human_size(size):>10})  {name}")

    print(f"\n{'='*60}")
    print(f" Address Map (all entries sorted by address)")
    print(f"{'='*60}")
    print(f" {'Start':<14} {'End':<14} {'Size':>10}  {'Type'}")
    print(f" {'-'*14} {'-'*14} {'-'*10}  {'-'*20}")

    all_entries = []
    for cat in category_order:
        for start, end, size, name in type_data[cat]['ranges']:
            label = {'System RAM':'usable','Reserved':'reserved','ACPI Tables':'ACPI data','ACPI NVS':'ACPI NVS'}.get(cat, f'MMIO ({name})')
            all_entries.append((start, end, size, label))
    all_entries.sort()

    for start, end, size, label in all_entries:
        if start >= 0x100000000 and 'MMIO' in label and 'PCI Bus' in label:
            continue
        print(f" 0x{start:012x} 0x{end:012x} {human_size(size):>10}  {label}")

PYTHON_SCRIPT

echo ""
echo "============================================="
echo " MTRR Settings (/proc/mtrr)"
echo "============================================="
echo ""

if [ -f /proc/mtrr ]; then
    python3 - << 'MTRR_SCRIPT'
import re

entries = []
with open('/proc/mtrr', 'r') as f:
    for line in f:
        m = re.match(r'(reg\d+): base=0x([0-9a-f]+) \(\s*(\d+)MB\), size=\s*(\d+)MB, count=\d+: (.+)', line.strip())
        if m:
            reg, base, size_mb, mtype = m.group(1), int(m.group(2),16), int(m.group(4)), m.group(5)
            size = size_mb * 1048576
            entries.append((base, base+size-1, size, mtype, reg))

entries.sort()

def human(b):
    if b >= 1073741824: return f"{b/1073741824:.0f}GB"
    if b >= 1048576: return f"{b/1048576:.0f}MB"
    return f"{b/1024:.0f}KB"

print(f"  {'Reg':<6} {'Start':<16} {'End':<16} {'Size':>6}  {'Type'}")
print(f"  {'---':<6} {'-----':<16} {'---':<16} {'----':>6}  {'----'}")
for base, end, size, mtype, reg in entries:
    print(f"  {reg:<6} 0x{base:012x}  0x{end:012x}  {human(size):>6}  {mtype}")

print(f"\n  Default type: uncacheable (gaps = UC)")
print(f"\n  Effective cache map:")
wb_ranges = sorted([(b,e) for b,e,s,t,r in entries if t == 'write-back'])
if wb_ranges:
    prev_end = 0
    for base, end in wb_ranges:
        if base > prev_end + 1:
            print(f"  0x{prev_end+1:012x}  0x{base-1:012x}  {human(base-prev_end-1):>8}  UC (gap)")
        print(f"  0x{base:012x}  0x{end:012x}  {human(end-base+1):>8}  WB")
        prev_end = max(prev_end, end)

for base, end, size, mtype, reg in entries:
    if mtype != 'write-back':
        print(f"  0x{base:012x}  0x{end:012x}  {human(size):>8}  {mtype}")

MTRR_SCRIPT
else
    echo "  /proc/mtrr not available"
fi

echo ""
echo "Done."
