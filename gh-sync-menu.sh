#!/usr/bin/env bash
set -e

# =============================================================================
# gh-sync-menu.sh - Interactive User Interface for gh-sync
# =============================================================================

# ANSI Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Resolve gh-sync command
GHSYNC_CMD="gh-sync"
if command -v gh-sync &> /dev/null; then
    GHSYNC_CMD="gh-sync"
elif [[ -x "./gh-sync.sh" ]]; then
    GHSYNC_CMD="./gh-sync.sh"
else
    echo -e "${RED}Error: gh-sync not found in PATH and ./gh-sync.sh not found.${NC}"
    echo "Please install gh-sync first."
    exit 1
fi

show_header() {
    clear
    echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║             gh-sync Interactive UI             ║${NC}"
    echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════╝${NC}"
    echo ""
}

pause() {
    echo -e "\n${YELLOW}Press [Enter] to continue...${NC}"
    read -r
}

while true; do
    show_header
    echo -e "Choose an action:"
    echo -e "  ${GREEN}1)${NC} Status  - Check sync status (In-sync, Modified, Missing)"
    echo -e "  ${GREEN}2)${NC} Diff    - See detailed file-by-file differences"
    echo -e "  ${GREEN}3)${NC} Push    - Copy golden source -> project"
    echo -e "  ${GREEN}4)${NC} Pull    - Copy project -> golden source"
    echo -e "  ${GREEN}5)${NC} Backups - Manage, restore, and clean backups"
    echo -e "  ${GREEN}6)${NC} Init    - Configure golden source path"
    echo -e "  ${RED}0)${NC} Exit"
    echo ""
    read -p "Select [0-6]: " choice

    case $choice in
        1)
            show_header
            echo -e "${CYAN}Running Status...${NC}"
            $GHSYNC_CMD status || true
            pause
            ;;
        2)
            show_header
            echo -e "${CYAN}Running Diff...${NC}"
            $GHSYNC_CMD diff || true
            pause
            ;;
        3)
            show_header
            echo -e "${YELLOW}${BOLD}Push: Golden Source -> Current Project${NC}"
            read -p "Dry run? (Preview only) [Y/n]: " dry_run
            opts=""
            [[ ! "$dry_run" =~ ^[Nn]$ ]] && opts="--dry-run"
            
            read -p "Only specific folders? (e.g. .github,.agents or leave empty for all): " only
            [[ -n "$only" ]] && opts="$opts --only $only"
            
            echo -e "\n${CYAN}Executing: gh-sync push ${opts}${NC}"
            $GHSYNC_CMD push $opts || true
            pause
            ;;
        4)
            show_header
            echo -e "${YELLOW}${BOLD}Pull: Current Project -> Golden Source${NC}"
            read -p "Dry run? (Preview only) [Y/n]: " dry_run
            opts=""
            [[ ! "$dry_run" =~ ^[Nn]$ ]] && opts="--dry-run"
            
            read -p "Only specific folders? (e.g. .github,.agents or leave empty for all): " only
            [[ -n "$only" ]] && opts="$opts --only $only"
            
            echo -e "\n${CYAN}Executing: gh-sync pull ${opts}${NC}"
            $GHSYNC_CMD pull $opts || true
            pause
            ;;
        5)
            while true; do
                show_header
                echo -e "${BOLD}Backup Management:${NC}"
                echo -e "  ${GREEN}1)${NC} List Available Backups"
                echo -e "  ${GREEN}2)${NC} Restore Latest Backup"
                echo -e "  ${GREEN}3)${NC} Restore Specific Backup (Interactive)"
                echo -e "  ${GREEN}4)${NC} Clean Old Backups"
                echo -e "  ${RED}0)${NC} Back to Main Menu"
                echo ""
                read -p "Select [0-4]: " b_choice
                
                case $b_choice in
                    1)
                        show_header
                        $GHSYNC_CMD backups || true
                        pause
                        ;;
                    2)
                        show_header
                        $GHSYNC_CMD restore --latest || true
                        pause
                        ;;
                    3)
                        show_header
                        $GHSYNC_CMD restore || true
                        pause
                        ;;
                    4)
                        show_header
                        read -p "Keep how many backups per folder? [Default: 5]: " keep_cnt
                        opts=""
                        [[ -n "$keep_cnt" ]] && opts="--keep $keep_cnt"
                        $GHSYNC_CMD clean $opts || true
                        pause
                        ;;
                    0)
                        break
                        ;;
                    *)
                        echo -e "${RED}Invalid option${NC}"
                        sleep 1
                        ;;
                esac
            done
            ;;
        6)
            show_header
            $GHSYNC_CMD init || true
            pause
            ;;
        0)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option. Please enter a number from 0 to 6.${NC}"
            sleep 1
            ;;
    esac
done
