#!/bin/bash
# ================================================
#  Linux System Menu
#  Created by: Rx4n
#  Version: 1.0
# ------------------------------------------------
# Please perform safe tests and if you have any 
# problems or suggestions, open an ISSUE or 
# contact us. This program is designed to help 
# Linux users with their systems.
# ================================================

# --- Basic setup ---
BASE_DIR="$HOME/linux_system_menu"
REPORTS_DIR="$BASE_DIR/reports"
LOGS_DIR="$BASE_DIR/logs"
CONF_DIR="$BASE_DIR/reports/config"
mkdir -p "$REPORTS_DIR" "$LOGS_DIR" "$CONF_DIR"

declare -A PKG_MAP_AMD
declare -A PKG_MAP_NVIDIA
declare -A PKG_MAP_INTEL
declare -A PKG_MAP_COMMON

# Common utilities
PKG_MAP_COMMON[pacman]="lshw dmidecode smartmontools pciutils lm_sensors"
PKG_MAP_COMMON[apt]="lshw dmidecode smartmontools pciutils lm-sensors"
PKG_MAP_COMMON[dnf]="lshw dmidecode smartmontools pciutils lm_sensors"
PKG_MAP_COMMON[zypper]="lshw dmidecode smartmontools pciutils lm_sensors"

# AMD GPU
PKG_MAP_AMD[pacman]="mesa vulkan-radeon xf86-video-amdgpu"
PKG_MAP_AMD[apt]="mesa-vulkan-drivers mesa-utils"   # Debian/Ubuntu variants exist; ajustar se necessário
PKG_MAP_AMD[dnf]="mesa-dri-drivers vulkan"          # nomes variam; verificar repositório da distro
PKG_MAP_AMD[zypper]="Mesa-libGL1 libvulkan1"       # placeholders, ajustar conforme openSUSE repos

# NVIDIA GPU
PKG_MAP_NVIDIA[pacman]="nvidia nvidia-utils lib32-nvidia-utils"
PKG_MAP_NVIDIA[apt]="nvidia-driver nvidia-utils"   # em Ubuntu, ubuntu-drivers autoinstall pode ser usado
PKG_MAP_NVIDIA[dnf]="kmod-nvidia xorg-x11-drv-nvidia" 
PKG_MAP_NVIDIA[zypper]="nvidia-compute-files"      # ajustar conforme repos

# INTEL GPU
PKG_MAP_INTEL[pacman]="mesa vulkan-intel intel-media-driver"
PKG_MAP_INTEL[apt]="intel-media-va-driver-non-free mesa-vulkan-drivers"
PKG_MAP_INTEL[dnf]="intel-media-driver vulkan" 
PKG_MAP_INTEL[zypper]="intel-media-driver libvulkan1"

# Microcode packages (CPU)
declare -A PKG_UCODE
PKG_UCODE[pacman_amd]="amd-ucode"
PKG_UCODE[pacman_intel]="intel-ucode"
PKG_UCODE[apt_amd]="amd64-microcode || amd-ucode || amd64-microcode"
PKG_UCODE[apt_intel]="intel-microcode"

timestamp() { date +"%Y%m%d_%H%M%S"; }
LOGFILE="$LOGS_DIR/install_$(timestamp).log"

# Simple logging helper (stdout + stderr to log)
log() {
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"
}

# --- Detect package manager for host (used by menu update/clean) ---
detect_package_manager() {
    if command -v pacman &>/dev/null; then
        linux_package_system="PACMAN"
    elif command -v apt &>/dev/null; then
        linux_package_system="APT"
    elif command -v dnf &>/dev/null; then
        linux_package_system="DNF"
    elif command -v zypper &>/dev/null; then
        linux_package_system="ZYPPER"
    else
        linux_package_system="UNKNOWN"
    fi
    echo "$linux_package_system" > "$CONF_DIR/linux_package_system.txt"
}

if [ ! -f "$CONF_DIR/linux_package_system.txt" ]; then
    detect_package_manager
else
    linux_package_system=$(cat "$CONF_DIR/linux_package_system.txt")
fi

# --- Ensure script run as root for installer parts ---
ensure_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "This operation requires root. Please run the script with sudo or as root."
        exit 1
    fi
}

# ------------------------------
# Generic update & clean funcs
# (kept simple, same as previous pattern)
# ------------------------------
update() {
    clear
    log "Starting system update (host distro: $linux_package_system)..."
    case "$linux_package_system" in
        "PACMAN") sudo pacman -Syu --noconfirm |& tee -a "$LOGFILE" ;;
        "APT") sudo apt update -y |& tee -a "$LOGFILE" && sudo apt upgrade -y |& tee -a "$LOGFILE" ;;
        "DNF") sudo dnf upgrade --refresh -y |& tee -a "$LOGFILE" ;;
        "ZYPPER") sudo zypper refresh |& tee -a "$LOGFILE" && sudo zypper update -y |& tee -a "$LOGFILE" ;;
        *) log "Package manager not detected on host." ;;
    esac
    log "Update finished."
    read -p "Press ENTER to continue..." _
}

clean() {
    clear
    log "Starting cleaning routine on host..."
    read -p "Clear package manager cache? [y/N] " ans_cache
    if [[ "$ans_cache" =~ ^[Yy]$ ]]; then
        case "$linux_package_system" in
            "PACMAN") sudo pacman -Sc --noconfirm |& tee -a "$LOGFILE" ;;
            "APT") sudo apt clean && sudo apt autoclean |& tee -a "$LOGFILE" ;;
            "DNF") sudo dnf clean all |& tee -a "$LOGFILE" ;;
            "ZYPPER") sudo zypper clean --all |& tee -a "$LOGFILE" ;;
            *) log "No package manager detected." ;;
        esac
    fi

    read -p "Remove orphan packages? [y/N] " ans_orphans
    if [[ "$ans_orphans" =~ ^[Yy]$ ]]; then
        case "$linux_package_system" in
            "PACMAN")
                orphans=$(pacman -Qtdq 2>/dev/null)
                if [ -n "$orphans" ]; then
                    sudo pacman -Rns $orphans --noconfirm |& tee -a "$LOGFILE"
                else
                    log "No orphans found."
                fi
                ;;
            "APT")
                sudo apt autoremove --purge -y |& tee -a "$LOGFILE" ;;
            "DNF")
                sudo dnf autoremove -y |& tee -a "$LOGFILE" ;;
            "ZYPPER")
                log "Zypper orphan removal not fully automated here." ;;
            *) log "No package manager detected." ;;
        esac
    fi

    read -p "Clear journal logs older than 3 days? [y/N] " ans_logs
    if [[ "$ans_logs" =~ ^[Yy]$ ]]; then
        sudo journalctl --vacuum-time=3d |& tee -a "$LOGFILE"
    fi

    read -p "Empty user thumbnails cache (~/.cache/thumbnails)? [y/N] " ans_thumbs
    if [[ "$ans_thumbs" =~ ^[Yy]$ ]]; then
        rm -rf ~/.cache/thumbnails/* 2>/dev/null
        log "Thumbnail cache cleared."
    fi

    read -p "Empty user cache (~/.cache)? [y/N] " ans_cacheuser
    if [[ "$ans_cacheuser" =~ ^[Yy]$ ]]; then
        rm -rf ~/.cache/* 2>/dev/null
        log "User cache cleared."
    fi

    read -p "Empty Trash (~/.local/share/Trash)? [y/N] " ans_trash
    if [[ "$ans_trash" =~ ^[Yy]$ ]]; then
        rm -rf ~/.local/share/Trash/* 2>/dev/null
        log "Trash emptied."
    fi

    log "Cleaning routine finished."
    read -p "Press ENTER to continue..." _
}

# ------------------------------
# Reports (kept mostly as you had)
# ------------------------------
full_report() {
    clear
    log "[*] Generating full system report..."
    mkdir -p "$REPORTS_DIR"
    command -v lshw &>/dev/null && sudo lshw -short > "$REPORTS_DIR/report_hardware.txt" 2>/dev/null
    lscpu > "$REPORTS_DIR/report_cpu.txt"
    lspci | grep -E "VGA|3D" > "$REPORTS_DIR/report_gpu.txt"
    command -v dmidecode &>/dev/null && sudo dmidecode -t memory > "$REPORTS_DIR/report_memory.txt" 2>/dev/null
    lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,LABEL,UUID > "$REPORTS_DIR/report_disk.txt"
    disk=$(lsblk -nd -o NAME | head -n 1)
    if command -v smartctl &>/dev/null; then
        sudo smartctl -a /dev/$disk > "$REPORTS_DIR/report_smart.txt" 2>/dev/null
    else
        echo "smartctl not installed." > "$REPORTS_DIR/report_smart.txt"
    fi
    case "$linux_package_system" in
        "PACMAN") pacman -Q > "$REPORTS_DIR/report_packages.txt" ;;
        "APT") dpkg -l > "$REPORTS_DIR/report_packages.txt" ;;
        "DNF") dnf list installed > "$REPORTS_DIR/report_packages.txt" ;;
        "ZYPPER") zypper se --installed-only > "$REPORTS_DIR/report_packages.txt" ;;
        *) echo "Package manager not detected." > "$REPORTS_DIR/report_packages.txt" ;;
    esac
    systemctl list-units --type=service --state=running > "$REPORTS_DIR/report_services.txt"
    sudo lspci -k | grep -EA3 'VGA|3D|Display' > "$REPORTS_DIR/report_drivers.txt"
    uname -a > "$REPORTS_DIR/report_kernel.txt"
    lsmod > "$REPORTS_DIR/report_modules.txt"
    du -h --max-depth=2 /home | sort -hr | head -n 30 > "$REPORTS_DIR/report_home_storage.txt"
    df -h > "$REPORTS_DIR/report_system_storage.txt"
    du -sh /var/cache/pacman/pkg 2>/dev/null > "$REPORTS_DIR/report_cache_packages.txt"
    sudo du -ah /var/log | sort -hr | head -n 20 > "$REPORTS_DIR/report_logs.txt"
    free -h > "$REPORTS_DIR/report_swap_memory.txt"
    swapon --show > "$REPORTS_DIR/report_swap_details.txt"
    vmstat -s > "$REPORTS_DIR/report_vmstat.txt"
    cat /proc/swaps > "$REPORTS_DIR/report_swap_proc.txt"
    top -b -n1 | head -n 30 > "$REPORTS_DIR/report_process.txt"
    cd "$REPORTS_DIR"
    cat report_*.txt > full_report.txt
    clear
    read -p "Show 'Full Report' log? [y/n] " show_full_report
    if [[ "$show_full_report" =~ ^[Yy]$ ]]; then
        clear
        less full_report.txt
    fi
}

storage() {
    clear
    du -h --max-depth=2 /home | sort -hr | head -n 30 > "$REPORTS_DIR/report_home_storage.txt"
    df -h > "$REPORTS_DIR/report_system_storage.txt"
    echo "Reports saved in $REPORTS_DIR"
    read -p "Press ENTER to continue..." _
}

install_packages() {
    local pkgs=("$@")
    if [ "${#pkgs[@]}" -eq 0 ]; then
        return 0
    fi
    case "$PKG_MANAGER" in
        pacman)
            sudo pacman -Syu --noconfirm "${pkgs[@]}"
            ;;
        apt)
            sudo apt update
            sudo DEBIAN_FRONTEND=noninteractive apt install -y "${pkgs[@]}"
            ;;
        dnf)
            sudo dnf install -y "${pkgs[@]}"
            ;;
        zypper)
            sudo zypper -n install "${pkgs[@]}"
            ;;
        *)
            echo "Unknown package manager. Install manually: ${pkgs[*]}"
            return 1
            ;;
    esac
}

detect_gpu_vendor() {
    # Return: AMD, NVIDIA, INTEL, UNKNOWN
    if ! command -v lspci &>/dev/null; then
        echo "UNKNOWN"
        return
    fi
    local v
    v=$(lspci -nnk | tr '[:upper:]' '[:lower:]' | grep -E "vga|3d" | head -n1 || true)
    if [ -z "$v" ]; then
        echo "UNKNOWN"
        return
    fi
    if echo "$v" | grep -q "nvidia"; then
        echo "NVIDIA"
    elif echo "$v" | grep -Eq "amd|advanced micro devices|ati"; then
        echo "AMD"
    elif echo "$v" | grep -q "intel"; then
        echo "INTEL"
    else
        echo "UNKNOWN"
    fi
}

install_drivers_for_vendor() {
    local vendor="$1"
    log "Installing drivers for vendor: $vendor (pkg manager: $PKG_MANAGER)"
    case "$vendor" in
        NVIDIA)
            if [ "$PKG_MANAGER" = "apt" ] && command -v ubuntu-drivers &>/dev/null; then
                echo "Ubuntu/Debian detected with ubuntu-drivers available."
                read -p "Do you want to use 'ubuntu-drivers autoinstall' to automatically install NVIDIA drivers? [y/N]: " yn
                if [[ "$yn" =~ ^[Yy]$ ]]; then
                    sudo ubuntu-drivers autoinstall
                    return
                fi
            fi
            IFS=' ' read -r -a pkgs <<< "${PKG_MAP_NVIDIA[$PKG_MANAGER]:-nvidia nvidia-utils}"
            install_packages "${pkgs[@]}"
            ;;
        AMD)
            IFS=' ' read -r -a pkgs <<< "${PKG_MAP_AMD[$PKG_MANAGER]:-mesa vulkan-radeon}"
            install_packages "${pkgs[@]}"
            ;;
        INTEL)
            IFS=' ' read -r -a pkgs <<< "${PKG_MAP_INTEL[$PKG_MANAGER]:-mesa vulkan-intel}"
            install_packages "${pkgs[@]}"
            ;;
        *)
            echo "Vendor desconhecido. Nada a instalar."
            ;;
    esac
}

drivers_menu() {
    echo -e "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo -e "===-----     Linux Driver Installer     -----==="
    echo -e "==-----         Created By: Rx4n         -----=="
    echo -e "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo "[1] Automatically detect GPU and suggest driver."
    echo "[2] NVIDIA"
    echo "[3] AMD (AMDGPU / Mesa)"
    echo "[4] INTEL (Mesa / Vulkan)"
    echo ""
    echo "[0] Back"
    echo -e "--------------------------------------"
    read -p ">> " opt
    case "$opt" in
        1)
            vendor=$(detect_gpu_vendor)
            echo "Detecção: $vendor"
            if [ "$vendor" = "UNKNOWN" ]; then
                echo "The GPU could not be detected automatically."
                return 0
            fi
            read -p "Do you want to install drivers for $vendor now? [y/N]: " yn
            if [[ "$yn" =~ ^[Yy]$ ]]; then
                install_drivers_for_vendor "$vendor"
            fi
            ;;
        2)
            install_drivers_for_vendor "NVIDIA"
            ;;
        3)
            install_drivers_for_vendor "AMD"
            ;;
        4)
            install_drivers_for_vendor "INTEL"
            ;;
        0)
            return 0
            ;;
        *)
            echo "Invalid Input!"
            sleep 0.4
            ;;
    esac
}

REQUIRED_CMDS=(lshw dmidecode smartctl lspci lsblk sensors)

check_required_packages() {
    local missing=()
    for cmd in "${REQUIRED_CMDS[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [ "${#missing[@]}" -eq 0 ]; then
        echo "All the necessary commands are installed."
        return 0
    fi

    echo "Comandos faltantes: ${missing[*]}"
    # Map commands to distro packages
    local to_install=()
    for cmd in "${missing[@]}"; do
        case "$cmd" in
            lshw)
                case "$PKG_MANAGER" in
                    pacman) to_install+=("lshw");;
                    apt) to_install+=("lshw");;
                    dnf) to_install+=("lshw");;
                    zypper) to_install+=("lshw");;
                    *) to_install+=("lshw");;
                esac
                ;;
            dmidecode)
                to_install+=("dmidecode")
                ;;
            smartctl)
                # package smartmontools provides smartctl in most distros
                to_install+=("smartmontools")
                ;;
            lspci)
                # pciutils provides lspci
                to_install+=("pciutils")
                ;;
            lsblk)
                # util-linux provides lsblk, usually installed by default
                to_install+=("util-linux")
                ;;
            sensors)
                # lm_sensors / lm-sensors
                if [ "$PKG_MANAGER" = "pacman" ]; then
                    to_install+=("lm_sensors")
                else
                    to_install+=("lm-sensors")
                fi
                ;;
            *)
                to_install+=("$cmd")
                ;;
        esac
    done

    # Remove duplicates
    IFS=$'\n' to_install=($(sort -u <<<"${to_install[*]}"))
    unset IFS

    echo "Pacotes sugeridos para instalação: ${to_install[*]}"
    read -p "Deseja instalar os pacotes sugeridos agora? [y/N]: " yn2
    if [[ "$yn2" =~ ^[Yy]$ ]]; then
        install_packages "${to_install[@]}"
    fi
}

# ------------------------------
# Arch automatic installer
# Fully automatic: formats, partitions, mounts, installs, configures.
# Prompts for:
#   - target disk (e.g. /dev/sda or /dev/nvme0n1)
#   - swap size (GB)
#   - username
#   - hostname
#   - root password and user password
# Safety checks + confirmation before destructive actions.
# Logs written to $LOGFILE.
# ------------------------------
arch_auto_installer() {
    ensure_root

    log "=== Arch Automatic Installer started ==="
    echo
    echo "WARNING: This operation WILL WIPE the chosen disk."
    echo "Make sure you booted from an Arch live USB and selected the correct disk device."
    echo

    read -p "Target disk (e.g. /dev/sda or /dev/nvme0n1): " TARGET_DISK
    # Basic validation
    if [ ! -b "$TARGET_DISK" ]; then
        log "ERROR: Device $TARGET_DISK not found or not a block device."
        echo "Device not found. Aborting."
        read -p "Press ENTER to continue..." _
        return 1
    fi

    # If NVMe, partitions use p1/p2..., else s1/s2...
    PART_SUFFIX=""
    case "$TARGET_DISK" in
        *nvme*) PART_SUFFIX="p" ;;
        *) PART_SUFFIX="" ;;
    esac

    read -p "Swap size in GB (e.g. 4): " SWAP_GB
    if ! [[ "$SWAP_GB" =~ ^[0-9]+$ ]]; then
        log "Invalid swap size. Using 4 GB default."
        SWAP_GB=4
    fi

    read -p "New username (will be created): " NEW_USER
    if [ -z "$NEW_USER" ]; then
        log "No username entered. Aborting."
        echo "Username required. Aborting."
        read -p "Press ENTER to continue..." _
        return 1
    fi

    read -p "Hostname for the new system (e.g. archbox): " NEW_HOSTNAME
    if [ -z "$NEW_HOSTNAME" ]; then
        log "No hostname entered. Aborting."
        read -p "Press ENTER to continue..." _
        return 1
    fi

    echo
    echo "Summary of choices:"
    echo "  Disk: $TARGET_DISK"
    echo "  Swap: ${SWAP_GB}G"
    echo "  Username: $NEW_USER"
    echo "  Hostname: $NEW_HOSTNAME"
    echo
    read -p "Type 'I AGREE' to confirm wiping $TARGET_DISK and proceed: " CONFIRM
    if [ "$CONFIRM" != "I AGREE" ]; then
        log "User did not confirm. Aborting installer."
        echo "Confirmation failed. Aborting."
        read -p "Press ENTER to continue..." _
        return 1
    fi

    # -----------------------------------------
    # Partitioning plan:
    #   1: EFI 512M (type EF00)
    #   2: SWAP  (size SWAP_GB)
    #   3: ROOT (rest)
    # -----------------------------------------
    log "Starting partitioning on $TARGET_DISK..."
    # Wipe existing partition table
    log "Running wipefs and sgdisk --zap-all (this erases all partitions)."
    wipefs -a "$TARGET_DISK" |& tee -a "$LOGFILE"
    sgdisk --zap-all "$TARGET_DISK" |& tee -a "$LOGFILE"
    # create partitions
    EFI_SIZE="+512M"
    SWAP_SIZE="+${SWAP_GB}G"
    # create EFI
    sgdisk -n 1:0:$EFI_SIZE -t 1:ef00 -c 1:"EFI System" "$TARGET_DISK" |& tee -a "$LOGFILE"
    # create swap
    sgdisk -n 2:0:$SWAP_SIZE -t 2:8200 -c 2:"Linux Swap" "$TARGET_DISK" |& tee -a "$LOGFILE"
    # create root (rest)
    sgdisk -n 3:0:0 -t 3:8300 -c 3:"Linux Root" "$TARGET_DISK" |& tee -a "$LOGFILE"

    partprobe "$TARGET_DISK" 2>/dev/null || true
    sleep 1

    # partition paths (respect nvme naming)
    if [[ "$TARGET_DISK" =~ nvme ]]; then
        EFI_PART="${TARGET_DISK}${PART_SUFFIX}1"
        SWAP_PART="${TARGET_DISK}${PART_SUFFIX}2"
        ROOT_PART="${TARGET_DISK}${PART_SUFFIX}3"
    else
        EFI_PART="${TARGET_DISK}${PART_SUFFIX}1"
        SWAP_PART="${TARGET_DISK}${PART_SUFFIX}2"
        ROOT_PART="${TARGET_DISK}${PART_SUFFIX}3"
    fi

    log "Partitions created: EFI=$EFI_PART SWAP=$SWAP_PART ROOT=$ROOT_PART"

    # Format partitions
    log "Formatting partitions..."
    mkfs.fat -F32 "$EFI_PART" |& tee -a "$LOGFILE"
    mkswap "$SWAP_PART" |& tee -a "$LOGFILE"
    swapon "$SWAP_PART" |& tee -a "$LOGFILE"
    mkfs.ext4 -F "$ROOT_PART" |& tee -a "$LOGFILE"

    # Mount
    log "Mounting partitions..."
    mount "$ROOT_PART" /mnt |& tee -a "$LOGFILE"
    mkdir -p /mnt/boot
    mount "$EFI_PART" /mnt/boot |& tee -a "$LOGFILE"

    # Install base system using pacstrap
    log "Installing base system (pacstrap)..."
    pacstrap -K /mnt base linux linux-firmware nano networkmanager grub efibootmgr base-devel linux-headers git wget curl |& tee -a "$LOGFILE"

    # Generate fstab
    log "Generating fstab..."
    genfstab -U /mnt >> /mnt/etc/fstab
    log "fstab generated:"
    cat /mnt/etc/fstab | tee -a "$LOGFILE"

    # Arch-chroot configuration block
    log "Entering arch-chroot to configure system..."
    # We'll pass variables via environment to the chroot commands
    arch-chroot /mnt /bin/bash -e <<EOF |& tee -a "$LOGFILE"
set -e
# timezone
ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
hwclock --systohc

# locale
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen || true
sed -i 's/^#pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/' /etc/locale.gen || true
locale-gen
echo "LANG=pt_BR.UTF-8" > /etc/locale.conf

# hostname and hosts
echo "$NEW_HOSTNAME" > /etc/hostname
cat > /etc/hosts <<HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${NEW_HOSTNAME}.localdomain ${NEW_HOSTNAME}
HOSTS

# root password: will be set after chroot (prompt)
echo "Please set root password now (you will be prompted):"
passwd root

# create user, add to wheel and set password
useradd -m -G wheel -s /bin/bash "$NEW_USER"
echo "Set password for user $NEW_USER:"
passwd "$NEW_USER"

# allow wheel sudo (uncomment wheel line)
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers || true

# enable NetworkManager
systemctl enable NetworkManager

# install grub
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# update system and finish
pacman -Syu --noconfirm
EOF

    # After chroot ends
    log "Arch chroot configuration finished."

    # Finalize: unmount, swapoff, reboot prompt
    log "Finalizing installation: unmounting and turning off swap..."
    swapoff "$SWAP_PART" |& tee -a "$LOGFILE"
    umount -R /mnt |& tee -a "$LOGFILE"
    sync

    log "Installation complete! You can now reboot into your new Arch Linux system."

    echo
    echo "========================================"
    echo "  Installation finished successfully!"
    echo "  Disk: $TARGET_DISK"
    echo "  Hostname: $NEW_HOSTNAME"
    echo "  User: $NEW_USER"
    echo "========================================"
    echo
    read -p "Do you want to restart now? [y/N]: " reboot_choice
    if [[ "$reboot_choice" =~ ^[Yy]$ ]]; then
        log "Rebooting system..."
        reboot
    else
        log "Installation finished. Please reboot manually when ready."
    fi

}

# ------------------------------
# Installer menu wrapper
# ------------------------------
option_arch_auto() {
    clear
    echo -e "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo -e "===-----      Arch Linux Installer      -----==="
    echo -e "==-----        * Automatic Mode *        -----=="
    echo -e "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo
    echo "This will perform a FULL automatic installation on the selected disk."
    echo "You will be prompted for target disk, swap size, username and hostname."
    echo "All steps and outputs are logged to $LOGFILE"
    echo
    read -p "Press ENTER to start the automatic installer (or CTRL+C to abort)..." _
    arch_auto_installer
    read -p "Press ENTER to return to installer menu..." _
}

# ------------------------------
# Menus & options
# ------------------------------
option_reports() {
    case $1 in
        0) return 0 ;;
        1) full_report ;;
        2) storage ;;
        9) config_reports ;;
        *) echo "Invalid Input!" && sleep 0.4 ;;
    esac
}

reports() {
    while true; do
        clear
        echo -e "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        echo -e "===----- Linux System Reports -----==="
        echo -e "==-----    Created by: Rx4n    -----=="
        echo -e "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        echo -e "[1] Full Report"
        echo -e "[2] Storage Report"
        echo -e "[9] Configuration"
        echo -e ""
        echo -e "[0] Back"
        echo -e "--------------------------------------"
        read -p ">> " choice
        if [ "$choice" = "0" ]; then
            break
        else
            option_reports "$choice"
        fi
    done
}

config_reports() {
    while true; do
        clear
        echo -e "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        echo -e "===----- Report Configuration -----==="
        echo -e "==-----    Created by: Rx4n    -----=="
        echo -e "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        echo -e "[1] Set Package System"
        echo -e "[0] Back"
        echo -e "--------------------------------------"
        read -p ">> " choice
        case $choice in
            0) break ;;
            1)
                clear
                echo -e "Choose Package Manager:"
                echo -e "[1] APT"
                echo -e "[2] PACMAN"
                echo -e "[3] DNF"
                echo -e "[4] ZYPPER"
                echo -e "[0] Back"
                read -p ">> " pkg
                case $pkg in
                    0) ;;
                    1) linux_package_system="APT" ;;
                    2) linux_package_system="PACMAN" ;;
                    3) linux_package_system="DNF" ;;
                    4) linux_package_system="ZYPPER" ;;
                    *) echo "Invalid input!" && sleep 0.4 ;;
                esac
                echo "$linux_package_system" > "$CONF_DIR/linux_package_system.txt"
                ;;
            *) echo "Invalid Input!" && sleep 0.4 ;;
        esac
    done
}

option_menu() {
    case $1 in
        0) clear; exit 0 ;;
        1) update ;;
        2) reports ;;
        3) clean ;;
        4) read -p "Are you sure you want to reboot the host? [y/N] " r && [[ "$r" =~ ^[Yy]$ ]] && reboot ;;
        5) # Arch Installer menu
            while true; do
                clear
                echo -e "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
                echo -e "===----- Arch Installer Menu  -----==="
                echo -e "==-----    Created by: Rx4n    -----=="
                echo -e "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
                echo -e "[1] Automatic Install (wipe disk and install)"
                echo -e "[2] Manual Install (not implemented yet)"
                echo -e "[0] Back"
                echo -e "--------------------------------------"
                read -p ">> " choice
                case $choice in
                    0) break ;;
                    1) option_arch_auto ;;
                    2) echo "Manual mode not implemented yet." ; sleep 1 ;;
                    *) echo "Invalid input!" ; sleep 0.4 ;;
                esac
            done
            ;;
        6) drivers_menu ;;
        9) config_menu ;;
        *) echo "Invalid Input!"; sleep 0.4 ;;
    esac
}

config_menu() {
    while true; do
        clear
        echo -e "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        echo -e "===-----  Menu Configuration  -----==="
        echo -e "==-----    Created by: Rx4n    -----=="
        echo -e "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        echo -e "[1] Set Package System"
        echo -e "[0] Back"
        echo -e "--------------------------------------"
        read -p ">> " choice
        case $choice in
            0) break ;;
            1)
                clear
                echo -e "Choose Package Manager:"
                echo -e "[1] APT"
                echo -e "[2] PACMAN"
                echo -e "[3] DNF"
                echo -e "[4] ZYPPER"
                echo -e "[0] Back"
                read -p ">> " pkg
                case $pkg in
                    0) ;;
                    1) linux_package_system="APT" ;;
                    2) linux_package_system="PACMAN" ;;
                    3) linux_package_system="DNF" ;;
                    4) linux_package_system="ZYPPER" ;;
                    *) echo "Invalid input!" ; sleep 0.4 ;;
                esac
                echo "$linux_package_system" > "$CONF_DIR/linux_package_system.txt"
                ;;
            *) echo "Invalid Input!" ; sleep 0.4 ;;
        esac
    done
}

# Main menu
menu() {
    clear
    echo -e "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo -e "===-----  Linux System Menu   -----==="
    echo -e "==-----    Created by: Rx4n    -----=="
    echo -e "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo -e "[1] Update"
    echo -e "[2] Linux System Reports"
    echo -e "[3] Clean System"
    echo -e "[4] Reboot"
    echo -e "[5] Arch Installer"
    echo -e "[6] Install Drivers"
    echo -e "[7] Show/Install 'Required Packages'"
    echo -e "[9] Configuration"
    echo -e ""
    echo -e "[0] Exit"
    echo -e "--------------------------------------"
    read -p ">> " choice
    option_menu "$choice"
}

# loop
while true; do
    menu
done
