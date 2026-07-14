# BIOS Debug Tools

Scripts for BIOS/UEFI debugging, PCIe diagnostics, and system analysis on Intel server platforms.

## Tools

| Tool | Description | Platform |
|------|-------------|----------|
| [memmap_go.sh](tools/memmap_go.sh) | Physical memory map summary + visual layout + MTRR check | Linux |
| [chk_pci_reg.sh](tools/chk_pci_reg.sh) | Dump PCIe Root Port / Endpoint config registers | Linux |
| [ltssm_go.sh](tools/ltssm_go.sh) | Monitor PCIe LTSSM link state transitions | Linux |
| [einj_go.sh](tools/einj_go.sh) | Inject PCIe errors (CE/UCE/NUCE) via ACPI EINJ | Linux |
| [hybrid_aer.sh](tools/hybrid_aer.sh) | Configure PCIe AER/DPC on Intel Root Ports | Linux |
| [reboot_go.sh](tools/reboot_go.sh) | Automated reboot cycle test with counter | Linux |
| [redfish_inband_go.sh](tools/redfish_inband_go.sh) | In-band Redfish BIOS configuration via BMC | Linux |
| [build_ami.py](tools/build_ami.py) | AMI Aptio V BIOS build automation | Windows |
| [json_trans.py](tools/json_trans.py) | Extract and pretty-print JSON from raw text/log | Python |

## Quick Start

```bash
# Download single tool
curl -O https://raw.githubusercontent.com/Timc21/bios_tools/main/tools/memmap_go.sh
chmod +x memmap_go.sh

# Or clone all
git clone https://github.com/Timc21/bios_tools.git
cd bios_tools/tools && chmod +x *.sh
```

---

## memmap_go.sh

Parses `/proc/iomem` and displays:
- Summary table (System RAM / Reserved / ACPI / MMIO)
- ASCII visual memory map (DRAM / MMIO hole / MMIOH)
- MTRR register settings with effective cache map (WB/UC gaps)

```bash
sudo ./memmap_go.sh          # Default: summary + visual + MTRR
sudo ./memmap_go.sh -d       # Detail: add all region lists + address map
sudo ./memmap_go.sh file.txt # Analyze saved iomem output
```

Sample output (default mode):
```
Category                         Size  Note
------------------------- ------------  --------------------
System RAM                     63.66GB  OS usable
Reserved                      283.62MB  FW runtime/SMM
ACPI Tables                     9.00MB  reclaimable
ACPI NVS                       52.62MB  FW persistent
MMIO (below 4GB)                1.95GB  PCI ECAM + BAR
MMIO (above 4GB)                1.25TB  64-bit PCI windows
------------------------- ------------
Physical DRAM                  64.00GB

 0x1080000000       TOHM
 +-------------------------------+
 |         DRAM HIGH             | 0x100000000-0x107fffffff
 +-------------------------------+ 4GB (0x100000000)
 |         FLASH / Legacy IO     | 0xFF000000-0xFFFFFFFF
 + - - - - - - - - - - - - - - - +
 |         MMIO LOW              | 0x80000000-0xffffffff
 |         PCI ECAM + BAR space  |
 +-------------------------------+ 0x80000000
 |         Reserved / ACPI       | TSEG/DPR/Runtime/NVS
 + - - - - - - - - - - - - - - - +
 |         DRAM LOW (OS usable)  | 0x100000-0x777fffff
 +-------------------------------+ 1MB (0x100000)
 |         Legacy (VGA/ROM)      | 0xA0000-0xFFFFF
 +-------------------------------+ 640KB (0xA0000)
 |         DOS Conventional      | 0x0-0x9FFFF
 +-------------------------------+ 0x0

 MMIOH: 0x200000000000 - 0x213fffffffff (24 windows)

=============================================
 MTRR Settings (/proc/mtrr)
=============================================
  Reg    Start            End              Size  Type
  ---    -----            ---              ----  ----
  reg00  0x000000000000  0x00007fffffff    2GB  write-back
  reg01  0x000100000000  0x0001ffffffff    4GB  write-back
  ...

  Default type: uncacheable (gaps = UC)

  Effective cache map:
  0x000000000000  0x00007fffffff       2GB  WB
  0x000080000000  0x0000ffffffff       2GB  UC (gap)
  0x000100000000  0x0001ffffffff       4GB  WB
  ...
```

---

## chk_pci_reg.sh

```bash
sudo ./chk_pci_reg.sh       # All RP + EP
sudo ./chk_pci_reg.sh --rp  # Root Ports only
```

## ltssm_go.sh

```bash
sudo ./ltssm_go.sh 3a:02.0       # Monitor link state
sudo ./ltssm_go.sh 3a:02.0 100   # 100 iterations
```

## einj_go.sh

```bash
sudo ./einj_go.sh --ce            # Correctable Error injection
sudo ./einj_go.sh --uce           # Fatal Uncorrectable Error
sudo ./einj_go.sh --nuce --c 50   # Non-Fatal UCE, 50 loops
```

## hybrid_aer.sh

```bash
sudo ./hybrid_aer.sh             # Configure AER/DPC
```

## reboot_go.sh

```bash
sudo ./reboot_go.sh --start      # Start auto-reboot cycle (via cron)
sudo ./reboot_go.sh --stop       # Stop
```

## redfish_inband_go.sh

```bash
./redfish_inband_go.sh           # In-band Redfish to BMC
```

## build_ami.py

```bash
python build_ami.py jabileaglestream2s KingRanch      # Build
python build_ami.py jabileaglestream2s KingRanch -a   # Full clean rebuild
```

## json_trans.py

```bash
python json_trans.py input.txt                  # Pretty-print to stdout
python json_trans.py input.txt output.json      # Save formatted JSON
```

---

## Requirements

- `memmap_go.sh`: Linux with `python3`, root access for `/proc/iomem`
- `chk_pci_reg.sh`, `ltssm_go.sh`, `einj_go.sh`, `hybrid_aer.sh`: `setpci`, `lspci`
- `build_ami.py`: Windows, AMI Aptio V build environment

## Related Projects

- [Tim_UefiMtrrDump](https://github.com/Timc21/Tim_UefiMtrrDump) - UEFI PEI/DXE module to dump MTRR at boot stages

## License

BSD-2-Clause
