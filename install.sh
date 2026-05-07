set -eu

LOG="pdfwrm_install.logs"

BLUE="\033[34m"   # blue
GREEN="\033[32m"  # green
RED="\033[31m"    # red
RESET="\033[0m"

if ! : >"$LOG" 2>/dev/null; then
    printf "%b\n" "${RED}✗ Unable to write log file: ${LOG}${RESET}"
    exit 1
fi

log_info() {
    printf "%b\n" "${BLUE}$1${RESET}"
}

log_success() {
    printf "%b\n" "${GREEN}✓ $1${RESET}"
}

log_fail() {
    printf "%b\n" "${RED}✗ $1 — see ${LOG}${RESET}"
}

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        log_fail "Required command not found: $1"
        exit 1
    fi
}

run_step() {
    step="$1"
    shift

    if "$@" >>"$LOG" 2>&1; then
        log_success "$step"
    else
        log_fail "$step"
        exit 1
    fi
}

is_installed() {
    dpkg -s "$1" >/dev/null 2>&1
}

# Pre-flight checks
require_cmd pkg
require_cmd dpkg

# Step 1: Update repos
log_info "1. Updating Repos"
run_step "Repo Update Done" pkg update

# Step 2: Install missing packages only
MISSING_PACKAGES=""
for pkg_name in proot proot-distro; do
    if is_installed "$pkg_name"; then
        log_success "${pkg_name} already installed, skipping"
    else
        MISSING_PACKAGES="$MISSING_PACKAGES $pkg_name"
    fi
done

if [ -n "$MISSING_PACKAGES" ]; then
    log_info "2. Installing missing packages:${MISSING_PACKAGES}"
    run_step "Packages Installed Successfully" pkg install -y $MISSING_PACKAGES
else
    log_success "All required packages are already installed"
fi

# Step 3: Storage check and setup
require_cmd termux-setup-storage

if [ -d /sdcard ] && touch /sdcard/.termux_test 2>/dev/null; then
    rm -f /sdcard/.termux_test
    log_success "Storage permission already granted"
else
    sleep 3
    run_step "Storage permission requested" sh -c "yes | termux-setup-storage"

    # Validate permission after request (wait up to 10 seconds)
    seconds_left=10
    while [ "$seconds_left" -gt 0 ]; do
        if [ -d /sdcard ] && touch /sdcard/.termux_test 2>/dev/null; then
            rm -f /sdcard/.termux_test
            log_success "Storage permission granted"
            break
        fi
        seconds_left=$((seconds_left - 1))
        sleep 1
    done

    if [ "$seconds_left" -eq 0 ]; then
        log_fail "Storage permission not granted"
        exit 1
    fi
fi

# Step 4: Install Ubuntu via proot-distro
require_cmd proot-distro
if [ -d "${PREFIX:-/data/data/com.termux/files/usr}/var/lib/proot-distro/installed-rootfs/ubuntu" ]; then
    log_success "Ubuntu container already installed"
else
    log_info "Installing Ubuntu container"
    run_step "Ubuntu installation completed" proot-distro install ubuntu
fi
echo "proot-distro login ubuntu -- /usr/bin/pdfwrm" > /data/data/com.termux/files/usr/bin/pdfwrm
chmod +x /data/data/com.termux/files/usr/bin/pdfwrm

# Step 5: Run commands inside the Ubuntu container
run_step "Running Ubuntu setup commands" sh -c "cat <<'UBUNTU_CMDS' | proot-distro login ubuntu -- /bin/sh
set -eu
apt update && apt install -y wget
wget \"https://github.com/dipanshu247k-sys/pdf-w-rm/releases/download/test/pdfwrm_1.0.0.deb\" \\
apt install -y ./pdfwrm_1.0.0.deb
echo \"Successfully Installed the tool\"
UBUNTU_CMDS"
