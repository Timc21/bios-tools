#!/bin/bash
# desc:  Monitor PCIe LTSSM link state transitions
# repo:  https://github.com/Timc21/bios_tools
# usage: ./ltssm_go.sh <bdf> [loop_count]

bdf="$1"
ltssm_reg="0x520"

if [[ -n "$2" ]]; then
	loopnum="$2"
else
	loopnum=10
fi

# Check input
if [[ -z "$bdf" ]]; then
	echo "Usage: $0 <bdf>   (e.g. $0 3a:02.0)"
	exit 1
fi

echo Checking PCIe port $bdf


decode_ltssm() {
    local ltssm_value=$1

    # Extract main state (bits 31:28)
    local main=$(( (ltssm_value >> 28) & 0xF ))
    # Extract substate (bits 27:24)
    local sub=$(( (ltssm_value >> 24) & 0xF ))

    # Decode main
    case $main in
        0) main_str="DETECT" ;;
        1) main_str="POLLING" ;;
        2) main_str="CONFIG" ;;
        3) main_str="UP" ;;
        4) main_str="RECOVERY" ;;
        5) main_str="LOOPBACK" ;;
        6) main_str="HOTRESET" ;;
        7) main_str="DISABLED" ;;
        8) main_str="RECEQUAL" ;;
        9) main_str="UPL1" ;;
        *) main_str="UNKNOWN" ;;
    esac

    # Decode substate based on main
    case $main_str in
        DETECT)
            case $sub in
                0) sub_str="DET_QUIET_RST" ;;
                1) sub_str="DET_QUIET_ENTER" ;;
                2) sub_str="DET_QUIET" ;;
                3) sub_str="DET_ACT_128US" ;;
                4) sub_str="RST_ASSERT" ;;
                5) sub_str="DET_ACT2_128US" ;;
                6) sub_str="DET_POL" ;;
                7) sub_str="DET_EXIT_SQUELCH" ;;
                8) sub_str="DET_ACTIVE" ;;
                9) sub_str="DET_RECOMBINE" ;;
                10) sub_str="DET_TRANS_GEN1" ;;
                11) sub_str="DET_EXITP2" ;;
                12) sub_str="DET_SLEEPRST" ;;
                13) sub_str="DET_SLEEP" ;;
                *) sub_str="UNKNOWN" ;;
            esac
            ;;
        POLLING)
            case $sub in
                0) sub_str="POL_ACTIVE" ;;
                1) sub_str="POL_CONFIG" ;;
                2) sub_str="POL_COMP_G1" ;;
                4) sub_str="POL_COMP_G2_ENTRY" ;;
                5) sub_str="POL_COMP_G2_PREP" ;;
                6) sub_str="POL_COMP_G2" ;;
                7) sub_str="POL_PDP" ;;
                8) sub_str="POL_COMP_G2_EXIT" ;;
                9) sub_str="POL_COMP_G2_WAIT" ;;
                10) sub_str="POL_COMP_G2_PREP_WAIT" ;;
                11) sub_str="POL_COMP_G1_EIOS" ;;
                12) sub_str="POL_CHECK_COMPL" ;;
                13) sub_str="POL_COMP_G2_IDLE_WAIT" ;;
                14) sub_str="POL_EIOS" ;;
                15) sub_str="POL_PDP_TS" ;;
                *) sub_str="UNKNOWN" ;;
            esac
            ;;
        CONFIG)
            case $sub in
                0) sub_str="CFG_LNKWID_START" ;;
                1) sub_str="CFG_LNKWID_ACCEPT" ;;
                2) sub_str="CFG_LANENUM_WAIT" ;;
                3) sub_str="CFG_LANENUM_ACCEPT" ;;
                4) sub_str="CFG_COMPLETE" ;;
                5) sub_str="CFG_IDLE" ;;
                6) sub_str="CFG_LNKWID_START_REC" ;;
                7) sub_str="CFG_IDLE_OLD" ;;
                8) sub_str="CFG_LWS_WAIT_FOR_TS" ;;
                9) sub_str="CFG_LNKWID_START_UPCFG" ;;
                10) sub_str="CFG_LNKWID_START_UPCFG_PREP_EXIT_MASTER" ;;
                11) sub_str="CFG_LNKWID_START_UPCFG_PREP_EXIT_SLAVE" ;;
                *) sub_str="UNKNOWN" ;;
            esac
            ;;
        UP)
            case $sub in
                0) sub_str="UP_L0" ;;
                1) sub_str="UP_UNDEF_1" ;;
                2) sub_str="UP_UNDEF_2" ;;
                3) sub_str="UP_UNDEF_3" ;;
                4) sub_str="UP_TXL0S_WAIT4EIOS" ;;
                5) sub_str="UP_TXL0S_IDLE" ;;
                6) sub_str="UP_TXL0S_PREP_EXIT" ;;
                7) sub_str="UP_TXL0S_FTS" ;;
                8) sub_str="UP_L1L2_ENTRY" ;;
                9) sub_str="UP_L1_IDLE_WAIT" ;;
                10) sub_str="UP_L1_IDLE" ;;
                11) sub_str="UP_L1_EXIT" ;;
                12) sub_str="UP_UPSTREAM_L1L2_EIOS" ;;
                13) sub_str="UP_L2_IDLE_WAIT" ;;
                14) sub_str="UP_L2_IDLE" ;;
                15) sub_str="UP_UNDEF_15" ;;
                *) sub_str="UNKNOWN" ;;
            esac
            ;;
        UPL1)
            case $sub in
                0) sub_str="UPL1_IDLE_WAIT" ;;
                1) sub_str="UPL1_L1p0" ;;
                2) sub_str="UPL1_L1p1" ;;
                3) sub_str="UPL1_L1p2ENTRY" ;;
                4) sub_str="UPL1_L1p2IDLE" ;;
                5) sub_str="UPL1_L1p2EXIT" ;;
                6) sub_str="UPL1_EXIT" ;;
                *) sub_str="UNKNOWN" ;;
            esac
            ;;
        RECOVERY)
            case $sub in
                0) sub_str="REC_COMPLETE" ;;
                1) sub_str="REC_RCVRCFG" ;;
                2) sub_str="REC_RCVRLOCK" ;;
                3) sub_str="REC_IDLE" ;;
                4) sub_str="REC_SPEED" ;;
                5) sub_str="REC_RCVRCFG_SPEED" ;;
                6) sub_str="REC_WAIT_FOR_GEN_TRANS" ;;
                7) sub_str="REC_EQUAL" ;;
                10) sub_str="REC_SPEED_IDLE" ;;
                11) sub_str="REC_SPEED_WAIT_1US_PREP" ;;
                12) sub_str="REC_SPEED_WAIT_1US" ;;
                13) sub_str="REC_WAIT_EXIT_EI" ;;
                14) sub_str="REC_WAIT_BITLOCK_TO" ;;
                *) sub_str="UNKNOWN" ;;
            esac
            ;;
        RECEQUAL)
            case $sub in
                0) sub_str="REQ_PH01_PRELCK" ;;
                1) sub_str="REQ_PH0" ;;
                2) sub_str="REQ_PH1" ;;
                4) sub_str="REQ_SEVA_SYNC" ;;
                5) sub_str="REQ_SEVA" ;;
                8) sub_str="REQ_MEVA_PRELCK" ;;
                9) sub_str="REQ_MEVA_LCK" ;;
                10) sub_str="REQ_MEVA_RUNWT4SUM" ;;
                11) sub_str="REQ_MEVA_RUN" ;;
                12) sub_str="REQ_MEVA_EVL" ;;
                *) sub_str="UNKNOWN" ;;
            esac
            ;;
        LOOPBACK)
            case $sub in
                0) sub_str="LB_ENTRY_S" ;;
                1) sub_str="LB_ACTIVE_S" ;;
                2) sub_str="LB_EXIT_S" ;;
                3) sub_str="LB_EXIT1" ;;
                4) sub_str="LB_ENTRY_M" ;;
                5) sub_str="_LB_ACTIVE_M" ;;
                8) sub_str="LB_EXIT_M" ;;
                9) sub_str="LB_SPEED_CHANGE" ;;
                10) sub_str="LB_SEND_EIOS" ;;
                11) sub_str="LB_SPEED_PREP_EXIT" ;;
                12) sub_str="LB_SPEED_IDLE_WAIT" ;;
                *) sub_str="UNKNOWN" ;;
            esac
            ;;
        HOTRESET)
            case $sub in
                0) sub_str="SUB_HR_ENTRY" ;;
                1) sub_str="SUB_HR_MAS" ;;
                2) sub_str="SUB_HR_SLV" ;;
                4) sub_str="TS1" ;;
                5) sub_str="TS2" ;;
                6) sub_str="EIOS" ;;
                7) sub_str="EIOS_FLUSH" ;;
                *) sub_str="UNKNOWN" ;;
            esac
            ;;
        DISABLED)
            case $sub in
                0) sub_str="DIS_TS1" ;;
                1) sub_str="DIS_EIOS" ;;
                2) sub_str="DIS_EIOS" ;;
                3) sub_str="DIS_SUCC" ;;
                4) sub_str="DIS_SUCC_WAIT" ;;
                5) sub_str="DIS_EXIT" ;;
                *) sub_str="UNKNOWN" ;;
            esac
            ;;
        *)
            sub_str="UNKNOWN" ;;
    esac

    echo "$main_str.$sub_str"
}


for i in $(seq 1 "$loopnum"); do
	# Print if presence detect status bit is 1b
	lspci -s "$bdf" -vvv | grep -iP '(SltSta).*?(PresDet\+)'
	
	# Print LTSSM state
	LTSSM=$(setpci -s "$bdf" "${ltssm_reg}.L" 2>/dev/null)
	echo "LTSSM register ${ltssm_reg} = $LTSSM -- $(decode_ltssm "$((0x$LTSSM))")"
done
