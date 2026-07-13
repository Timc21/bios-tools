# 🔧 BIOS Debug Tools

A collection of scripts for BIOS/UEFI debugging, PCIe diagnostics, and system analysis on Intel server platforms.

## Tools

| Tool | Description | Platform |
|------|-------------|----------|
| [memmap_go.sh](tools/memmap_go.sh) | Summarize `/proc/iomem` memory map with MTRR cross-check | Linux |
| [chk_pci_reg.sh](tools/chk_pci_reg.sh) | Dump PCIe Root Port and Endpoint config registers | Linux |
| [ltssm_go.sh](tools/ltssm_go.sh) | Monitor PCIe LTSSM link state transitions | Linux |
| [einj_go.sh](tools/einj_go.sh) | Inject PCIe errors (CE/UCE/NUCE) via EINJ for RAS testing | Linux |
| [hybrid_aer.sh](tools/hybrid_aer.sh) | Configure PCIe AER/DPC settings on Intel Root Ports | Linux |
| [reboot_go.sh](tools/reboot_go.sh) | Automated reboot cycle test with counter | Linux |
| [redfish_inband_go.sh](tools/redfish_inband_go.sh) | In-band Redfish BIOS configuration via BMC | Linux |
| [build_ami.py](tools/build_ami.py) | AMI Aptio V BIOS build automation script | Windows |
| [json_trans.py](tools/json_trans.py) | Extract and pretty-print JSON from raw text/log files | Python |

## Quick Start

### Download a single tool

```bash
# Example: download memmap_go.sh
curl -O https://raw.githubusercontent.com/Timc21/bios_tools/main/tools/memmap_go.sh
chmod +x memmap_go.sh
```

### Clone entire repo

```bash
git clone https://github.com/Timc21/bios_tools.git
cd Tim_bios_tools/tools
chmod +x *.sh
```

---

## Tool Details

### memmap_go.sh
Parses `/proc/iomem` and summarizes physical memory layout grouped by type. Includes MTRR settings and System RAM coverage verification.

```bash
sudo ./memmap_go.sh              # Live system
./memmap_go.sh saved_iomem.txt   # From file
```

### chk_pci_reg.sh
Dumps PCIe configuration registers for Root Ports and Endpoints. Useful for checking link status, AER capability, device IDs.

```bash
sudo ./chk_pci_reg.sh            # Dump all RP + EP
sudo ./chk_pci_reg.sh --rp      # Root Ports only
```

### ltssm_go.sh
Monitors PCIe Link Training and Status State Machine (LTSSM) state for a given BDF. Useful for debugging link instability.

```bash
sudo ./ltssm_go.sh 3a:02.0       # Monitor BDF 3a:02.0
sudo ./ltssm_go.sh 3a:02.0 100   # 100 iterations
```

### einj_go.sh
Injects PCIe errors via ACPI EINJ (Error Injection) table for RAS validation testing.

```bash
sudo ./einj_go.sh --ce            # Correctable Error
sudo ./einj_go.sh --uce           # Fatal Uncorrectable Error
sudo ./einj_go.sh --nuce --c 50   # Non-Fatal UCE, 50 loops
```

### hybrid_aer.sh
Configures PCIe Advanced Error Reporting (AER) and Downstream Port Containment (DPC) on Intel Root Ports.

```bash
sudo ./hybrid_aer.sh             # Show current AER/DPC status
```

### reboot_go.sh
Sets up automatic reboot cycling via cron for boot stability testing. Maintains a reboot counter log.

```bash
sudo ./reboot_go.sh --start      # Start auto-reboot cycle
sudo ./reboot_go.sh --stop       # Stop auto-reboot cycle
```

### redfish_inband_go.sh
Performs in-band Redfish operations to read/write BIOS settings via BMC's Redfish API.

```bash
./redfish_inband_go.sh           # Interactive BMC connection
```

### build_ami.py
Automates AMI Aptio V BIOS build process (VeB-based). Supports clean build, incremental build, and FSP rebuild.

```bash
python build_ami.py jabileaglestream2s KingRanch      # Normal build
python build_ami.py jabileaglestream2s KingRanch -a   # Full rebuild
```

### json_trans.py
Extracts JSON content from messy log/text files and pretty-prints it. Useful for parsing Redfish responses or BIOS config dumps.

```bash
python json_trans.py input.txt                  # Print to stdout
python json_trans.py input.txt output.json      # Save to file
```

---

## Related Projects

- [Tim_UefiMtrrDump](https://github.com/Timc21/Tim_UefiMtrrDump) — UEFI PEI/DXE module to dump MTRR at multiple boot stages

## License

BSD-2-Clause
