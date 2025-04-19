#!/bin/bash
#
# ASD (AnmiTali Software Distribution) asr (as root)
# Build and installation script
#
# Author: AnmiTaliDev
# License: Apache 2.0

# Text formatting
BOLD="\033[1m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
RESET="\033[0m"

# Default installation paths
PREFIX="/usr"
SYSCONFDIR="/etc"
VARDIR="/var"
BINDIR="$PREFIX/bin"
CONFIG_FILE="$SYSCONFDIR/asr.conf"
LOG_FILE="$VARDIR/log/asr.log"

# Display help message
show_help() {
    echo "ASD (AnmiTali Software Distribution) asr (as root) build script"
    echo "A complete alternative to sudo for executing commands with root privileges"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --prefix=PREFIX        Installation prefix [$PREFIX]"
    echo "  --sysconfdir=DIR       System configuration directory [$SYSCONFDIR]"
    echo "  --vardir=DIR           Variable data directory [$VARDIR]"
    echo "  --help                 Display this help and exit"
    echo
    echo "This script must be run as root to properly set up asr."
}

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root.${RESET}"
    exit 1
fi

# Parse command line arguments
for arg in "$@"; do
    case $arg in
        --prefix=*)
            PREFIX="${arg#*=}"
            BINDIR="$PREFIX/bin"
            ;;
        --sysconfdir=*)
            SYSCONFDIR="${arg#*=}"
            CONFIG_FILE="$SYSCONFDIR/asr.conf"
            ;;
        --vardir=*)
            VARDIR="${arg#*=}"
            LOG_FILE="$VARDIR/log/asr.log"
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option: $arg${RESET}"
            show_help
            exit 1
            ;;
    esac
done

# Check for required tools
check_tool() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}Error: Required tool '$1' not found.${RESET}"
        echo "Please install the necessary package and run the script again."
        exit 1
    fi
}

echo -e "${BOLD}Checking for required build tools...${RESET}"
check_tool gcc
check_tool make
check_tool install

# Check for required libraries
check_header() {
    echo -n "Checking for $1.h... "
    if echo "#include <$1.h>" | gcc -E - &>/dev/null; then
        echo -e "${GREEN}found${RESET}"
        return 0
    else
        echo -e "${RED}not found${RESET}"
        return 1
    fi
}

# Check all required headers
required_headers=(
    "stdio"
    "stdlib"
    "string"
    "unistd"
    "pwd"
    "grp"
    "sys/types"
    "sys/stat"
    "sys/wait"
    "errno"
    "shadow"
    "crypt"
    "fcntl"
    "time"
    "limits"
    "termios"
)

missing_headers=0
for header in "${required_headers[@]}"; do
    if ! check_header "$header"; then
        missing_headers=$((missing_headers + 1))
    fi
done

if [ $missing_headers -gt 0 ]; then
    echo -e "${RED}Error: $missing_headers required header(s) not found.${RESET}"
    echo "Please install the necessary development packages and run the script again."
    exit 1
fi

# Make sure the source directory exists
if [ ! -d "src" ]; then
    echo -e "${YELLOW}Creating src directory...${RESET}"
    mkdir -p src
fi

# Check if the source file exists
if [ ! -f "src/main.c" ]; then
    echo -e "${RED}Error: Source file 'src/main.c' not found.${RESET}"
    echo "Please make sure the file exists and run the script again."
    exit 1
fi

# Update source file with correct paths
echo -e "${BOLD}Updating source code with installation paths...${RESET}"
sed -i "s|#define CONFIG_FILE \"[^\"]*\"|#define CONFIG_FILE \"$CONFIG_FILE\"|g" src/main.c
sed -i "s|#define LOG_FILE \"[^\"]*\"|#define LOG_FILE \"$LOG_FILE\"|g" src/main.c

# Compile the program
echo -e "${BOLD}Compiling asr...${RESET}"
gcc -Wall -Wextra -pedantic -O3 -D_FORTIFY_SOURCE=2 \
    -Wl,-z,relro,-z,now -o asr src/main.c -lcrypt

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Compilation failed.${RESET}"
    exit 1
fi

echo -e "${GREEN}Compilation successful.${RESET}"

# Create directories for installation
echo -e "${BOLD}Creating installation directories...${RESET}"
mkdir -p "$BINDIR"
mkdir -p "$SYSCONFDIR"
mkdir -p "$(dirname "$LOG_FILE")"

# Install the binary
echo -e "${BOLD}Installing asr binary...${RESET}"
install -m 755 asr "$BINDIR/asr"
chown root:root "$BINDIR/asr"
chmod 4755 "$BINDIR/asr"  # Set SUID bit

# Create config file if it doesn't exist
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${BOLD}Creating configuration file...${RESET}"
    cat > "$CONFIG_FILE" << EOF
# ASR Configuration File
# Format: username:all|cmd1,cmd2,cmd3
# Example: root:all
# Example: admin:all
# Example: user:/bin/ls,/usr/bin/apt,/usr/bin/apt-get,/bin/cat
EOF
    chown root:root "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
fi

# Create log file if it doesn't exist
if [ ! -f "$LOG_FILE" ]; then
    echo -e "${BOLD}Creating log file...${RESET}"
    touch "$LOG_FILE"
    chown root:root "$LOG_FILE"
    chmod 600 "$LOG_FILE"
fi

echo -e "${GREEN}${BOLD}Installation complete!${RESET}"
echo
echo -e "${BOLD}Installation summary:${RESET}"
echo -e "  Binary installed to: ${BOLD}$BINDIR/asr${RESET}"
echo -e "  Configuration file: ${BOLD}$CONFIG_FILE${RESET}"
echo -e "  Log file: ${BOLD}$LOG_FILE${RESET}"
echo
echo -e "${YELLOW}Note:${RESET} Make sure to edit the configuration file to specify which users can execute commands."
echo -e "You can edit it with: ${BOLD}vi $CONFIG_FILE${RESET}"
echo
echo -e "Usage examples:"
echo -e "  ${BOLD}asr /bin/ls /etc${RESET}        # Run ls with root privileges"
echo -e "  ${BOLD}asr -l${RESET}                 # List allowed commands for current user"
echo -e "  ${BOLD}asr -e${RESET}                 # Edit configuration file (requires root)"
echo

# Make the script executable
chmod +x build.sh