#!/usr/bin/env python3
# desc:  AMI Aptio V BIOS build automation
# repo:  https://github.com/Timc21/bios_tools
# usage: python build_ami.py <project> <veb_name> [options]
import os, shutil
import datetime
import subprocess
import sys, getopt

# ======= Default Configuration Area [Start] =======
DEFAULT_VEB_FILE_NAME = 'KingRanch'
DEFAULT_VEB_VAR = 'VeB_53_1_JRE'
DEFAULT_BIOS_PROJ_DIR = r'D:\TimChen\1_project\jabileaglestream2s'
# ======= Default Configuration Area [End] =======


def usage():
    print(f'''Usage: python {sys.argv[0]} <BIOS_PROJ_NAME> <VEB_FILE_NAME> [options]
    
    Example:
        python {sys.argv[0]} jabileaglestream2s KingRanch
        python {sys.argv[0]} jabileaglestream2s KingRanch -a

    Options:
        -h, --help     Show this help message
        -a, --all      Rebuild all (equivalent to 'make rebuild')
    ''')


def get_current_date_time_str():
    now = datetime.datetime.now()
    date_str = now.strftime('%Y-%m-%d')
    time_str = now.strftime('%H:%M:%S')
    return date_str, time_str


def set_env(VEB_FILE_NAME, VEB_VAR):
    VEB_TOOLS_DIR = rf'D:\TimChen\{VEB_VAR}\BuildTools'
    JAVA_BIN_LINK = rf'D:\TimChen\{VEB_VAR}\VisualeBios\zulu\bin'
    PYTHON_DIR = r'C:\Python38'
    EWDKAll_DIR = r'C:\EWDK'
    WINDDKx86_DIR = r'C:\WinDDK\7600.16385.1\bin\x86'
    WINDDKx86_DIR_X86 = rf'{WINDDKx86_DIR}\x86'
    WINDDKx86_DIR_AMD64 = rf'{WINDDKx86_DIR}\amd64'

    os.environ['VEB'] = VEB_FILE_NAME
    os.environ['TOOLS_DIR'] = VEB_TOOLS_DIR
    os.environ['CCX86DIR'] = WINDDKx86_DIR_X86
    os.environ['CCX64DIR'] = WINDDKx86_DIR_AMD64
    os.environ['EWDK_DIR'] = EWDKAll_DIR
    os.environ['PATH'] = (f'{PYTHON_DIR};'
                          f'{EWDKAll_DIR};'
                          f'{WINDDKx86_DIR};'
                          f'{WINDDKx86_DIR_X86};'
                          f'{WINDDKx86_DIR_AMD64};'
                          f'{VEB_TOOLS_DIR};'
                          f'{JAVA_BIN_LINK};'
                          + os.environ['PATH'])

    PATH = os.environ['PATH']
    print("\n+-------------------------------+")
    print("| Set BIOS Proj. Build Env.     |")
    print("+-------------------------------+")
    print(f"      VEB={VEB_FILE_NAME}")
    print(f"TOOLS_DIR={VEB_TOOLS_DIR}")
    print(f" CCX86DIR={WINDDKx86_DIR_X86}")
    print(f" CCX64DIR={WINDDKx86_DIR_AMD64}")
    print(f"     PATH={PATH}")


def main():
    # Handle command-line args
    try:
        opts, args = getopt.getopt(sys.argv[3:], 'ha', ["help", "all"])
    except getopt.GetoptError as err:
        print(err)
        usage()
        sys.exit(1)

    # Require at least 2 positional args
    if len(sys.argv) < 3 or '-h' in sys.argv or '--help' in sys.argv:
        usage()
        sys.exit(0)

    BIOS_PROJ_NAME = sys.argv[1]
    VEB_FILE_NAME = sys.argv[2]

    # Construct dynamic paths
    VEB_VAR = DEFAULT_VEB_VAR
    BIOS_PROJ_DIR = fr'D:\TimChen\1_project\{BIOS_PROJ_NAME}'

    # Default build command
    build_cmd = 'make'

    # Parse optional flags
    for option, value in opts:
        if option in ('-a', '--all'):
            build_cmd = 'make rebuild'

    # Start time
    date_str, start_time_str = get_current_date_time_str()

    # Build
    set_env(VEB_FILE_NAME, VEB_VAR)

    if not os.path.exists(BIOS_PROJ_DIR):
        print(f"❌ Error: BIOS project path not found: {BIOS_PROJ_DIR}")
        sys.exit(1)

    os.chdir(BIOS_PROJ_DIR)
    subprocess.run(build_cmd, shell=True)

    # Clear Tmp Files
    tmps = [
        "JabilPlatformPkg/OemRomImage/",
        "Keys/Variables/Certificates/OEM/",
        "OutImage_Prq/",
        "Intel/BirchStreamRpPkg/Tool/FTool/Flash_Image_Tool/FITmCmdGui/",
        "*.dat",
        "*.bin",
        "*.env",
        "*.bat",
        "*.txt",
        "Intel/BirchStreamFspPkg/Include/FspiUpd.h",
        "AmiChipsetModulePkg/FIT/BootGuardACM/"
    ]
    for tmp in tmps:
        try:
            subprocess.run(["git", "clean", "-fd", tmp], check=True)
            print(f"Successfully cleaned untracked files and directories in {tmp}")
        except subprocess.CalledProcessError as e:
            print(f"Git clean failed!: {e}")

    # End time
    date_str, end_time_str = get_current_date_time_str()
    start_time = datetime.datetime.strptime(start_time_str, '%H:%M:%S')
    end_time = datetime.datetime.strptime(end_time_str, '%H:%M:%S')
    total_time = end_time - start_time

    lines = [
        "BIOS Build Finished.",
        f"Start time: {date_str} {start_time_str}",
        f"End time: {date_str} {end_time_str}",
        f"Total build time: {total_time}"
    ]
    max_width = max(len(line) for line in lines)
    print("\n+" + "-" * (max_width + 2) + "+")
    for line in lines:
        print(f"| {line:<{max_width}} |")
    print("+" + "-" * (max_width + 2) + "+")


if __name__ == '__main__':
    main()
