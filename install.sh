# Set global values
STEPCOUNTER=false # Changes to true if user choose to install Tux Everywhere
DEBUG_MODE=false # Set to true to enable debug mode (no screen clearing and verbose logging)
YELLOW='\033[1;33m'
LIGHT_GREEN='\033[1;32m'
LIGHT_RED='\033[1;31m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

# Function to clear screen only if not in debug mode
function clear_screen {
    if [ "$DEBUG_MODE" = false ]; then
        printf "\033c"
    else
        echo ""
        echo "${BLUE}[DEBUG] --- Screen would be cleared here ---${NC}"
        echo ""
    fi
}

# Function for debug logging
function debug_log {
    if [ "$DEBUG_MODE" = true ]; then
        echo "${BLUE}[DEBUG] $1${NC}"
    fi
}

# Function to fix a broken alternatives system for Plymouth themes
function fix_alternatives_system {
    debug_log "Checking and fixing alternatives system for Plymouth themes"

    # Check if default.plymouth is not managed by alternatives system
    if [ -e "$PLYMOUTH_THEME_DIR/default.plymouth" ] && [ ! -L "$PLYMOUTH_THEME_DIR/default.plymouth" -o "$(readlink -f "$PLYMOUTH_THEME_DIR/default.plymouth" 2>/dev/null)" != "/etc/alternatives/default.plymouth" ]; then
        printf "${YELLOW}Found incorrect default.plymouth configuration. Fixing it...${NC}\n"
        debug_log "Removing incorrect default.plymouth file/link"

        # Backup the existing file if it's not a symlink
        if [ ! -L "$PLYMOUTH_THEME_DIR/default.plymouth" ]; then
            sudo mv "$PLYMOUTH_THEME_DIR/default.plymouth" "$PLYMOUTH_THEME_DIR/default.plymouth.backup.$(date +%Y%m%d%H%M%S)"
            debug_log "Backed up original file to default.plymouth.backup.$(date +%Y%m%d%H%M%S)"
        else
            sudo rm "$PLYMOUTH_THEME_DIR/default.plymouth"
        fi

        # Check if we're installing - if so, only then reset all alternatives
        # This avoids the issue of removing all themes during uninstall
        if [[ "${FUNCNAME[1]}" == "install" ]]; then
            debug_log "Called from install function, safe to reset all alternatives"
            # Reset the alternatives system only during installation
            if command -v update-alternatives >/dev/null 2>&1; then
                debug_log "Resetting alternatives system for default.plymouth"
                sudo update-alternatives --remove-all default.plymouth 2>/dev/null
            fi
        else
            debug_log "Not called from install function, will not reset all alternatives"
            # Create a symlink to /etc/alternatives/default.plymouth
            sudo ln -sf /etc/alternatives/default.plymouth "$PLYMOUTH_THEME_DIR/default.plymouth"
        fi

        return 0
    fi

    debug_log "Plymouth alternatives configuration appears to be correct"
    return 1
}

function install {
    clear_screen
    header "TUX PLYMOUTH THEME" "$1"
    debug_log "Starting installation process"

    # Check for plymouth-themes package first
    if command -v apt >/dev/null 2>&1; then
        printf "${YELLOW}Checking for plymouth-themes package...${NC}\n"
        debug_log "Checking if plymouth-themes package is installed"

        PLYMOUTH_THEMES_INSTALLED=false
        # Check if plymouth-themes package is already installed
        if dpkg -l | grep -q "plymouth-themes"; then
            printf "${LIGHT_GREEN}The plymouth-themes package is already installed.${NC}\n"
            debug_log "plymouth-themes package is already installed"
            PLYMOUTH_THEMES_INSTALLED=true
        else
            # Ask user if they want to install plymouth-themes package
            printf "${YELLOW}The plymouth-themes package provides a convenient way to manage Plymouth themes.${NC}\n"
            printf "${YELLOW}Would you like to install it? (Recommended)${NC}\n"
            select yn in "Yes" "No"; do
                case $yn in
                    Yes )
                        printf "${YELLOW}Installing plymouth-themes package...${NC}\n"
                        debug_log "Installing plymouth-themes package"
                        check_sudo
                        sudo apt update
                        sudo apt install -y plymouth-themes
                        printf "${LIGHT_GREEN}Plymouth themes package installed.${NC}\n"
                        debug_log "plymouth-themes package installed"
                        PLYMOUTH_THEMES_INSTALLED=true
                        break;;
                    No )
                        printf "${YELLOW}Skipping plymouth-themes package installation.${NC}\n"
                        debug_log "User declined to install plymouth-themes package"
                        break;;
                esac
            done
        fi
    else
        debug_log "apt command not found, cannot check or install plymouth-themes package"
    fi

    # Find Plymouth theme directory
    PLYMOUTH_THEME_DIR=""
    # Check common locations
    for dir in "/usr/share/plymouth/themes" "/lib/plymouth/themes" "/usr/lib/plymouth/themes"; do
        if [ -d "$dir" ]; then
            PLYMOUTH_THEME_DIR="$dir"
            debug_log "Found Plymouth theme directory at: $dir"
            break
        fi
    done

    # If not found in common locations, try to find it using the plymouth binary
    if [ -z "$PLYMOUTH_THEME_DIR" ]; then
        debug_log "Plymouth theme directory not found in common locations, trying to find using plymouth binary"
        PLYMOUTH_BIN=$(which plymouth 2>/dev/null)
        if [ -n "$PLYMOUTH_BIN" ]; then
            debug_log "Plymouth binary found at: $PLYMOUTH_BIN"
            # Get plymouth base directory from the binary location
            PLYMOUTH_BASE=$(dirname $(dirname "$PLYMOUTH_BIN"))
            debug_log "Plymouth base directory: $PLYMOUTH_BASE"
            # Try to find themes directory
            for dir in "$PLYMOUTH_BASE/share/plymouth/themes" "$PLYMOUTH_BASE/lib/plymouth/themes"; do
                if [ -d "$dir" ]; then
                    PLYMOUTH_THEME_DIR="$dir"
                    debug_log "Found Plymouth theme directory at: $dir"
                    break
                fi
            done
        else
            debug_log "Plymouth binary not found"
        fi
    fi

    # Here we check if Plymouth themes directory is found
    if [ -n "$PLYMOUTH_THEME_DIR" ]; then
        check_sudo
        debug_log "Proceeding with installation"

        # Get the directory where the script is located
        SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
        SRC_DIR="$SCRIPT_DIR/src"
        debug_log "Script directory: $SCRIPT_DIR"
        debug_log "Source directory: $SRC_DIR"

        # Check if source directory exists
        if [ ! -d "$SRC_DIR" ]; then
            printf "${LIGHT_RED}Could not find the theme source directory: $SRC_DIR${NC}\n"
            printf "Make sure the 'src' directory is in the same location as this script.\n"
            echo ""
            debug_log "Source directory not found, exiting"
            read -n1 -r -p "Press any key to continue..." key
            exit 1
        fi

        # Install the theme
        printf "${YELLOW}Found Plymouth themes directory at: $PLYMOUTH_THEME_DIR${NC}\n"
        printf "${YELLOW}Installing Tux Plymouth theme...${NC}\n"
        echo ""

        # Copy theme files
        debug_log "Copying files from $SRC_DIR to $PLYMOUTH_THEME_DIR/"
        sudo cp -r "$SRC_DIR" "$PLYMOUTH_THEME_DIR/"

        # Use rsync if available, otherwise use cp
        debug_log "Checking if rsync is available"
        if command -v rsync >/dev/null 2>&1; then
            debug_log "Running rsync to place files in final location"
            sudo rsync -a "$PLYMOUTH_THEME_DIR/src/" "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/"
        else
            debug_log "rsync not found, using mkdir and cp instead"
            # Create the destination directory first
            sudo mkdir -p "$PLYMOUTH_THEME_DIR/tux-plymouth-theme"
            # Copy all files from source to destination
            sudo cp -r "$PLYMOUTH_THEME_DIR/src/"* "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/"
        fi

        debug_log "Removing temporary src directory from $PLYMOUTH_THEME_DIR/src"
        sudo rm -r "$PLYMOUTH_THEME_DIR/src"

        # Ensure the theme directory exists before proceeding
        if [ ! -d "$PLYMOUTH_THEME_DIR/tux-plymouth-theme" ]; then
            printf "${LIGHT_RED}Failed to create the theme directory.${NC}\n"
            debug_log "Theme directory not created, installation failed"
            echo ""
            read -n1 -r -p "Press any key to continue..." key
            exit 1
        fi

        # Ensure proper permissions on theme files
        debug_log "Setting permissions on theme directory"
        sudo chmod -R 755 "$PLYMOUTH_THEME_DIR/tux-plymouth-theme"

        # Update the config in the .plymouth file to point to the correct location
        debug_log "Updating paths in .plymouth configuration file"
        if [ -f "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux-plymouth-theme.plymouth" ]; then
            sudo sed -i "s|ImageDir=.*|ImageDir=$PLYMOUTH_THEME_DIR/tux-plymouth-theme|g" "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux-plymouth-theme.plymouth"
            sudo sed -i "s|ScriptFile=.*|ScriptFile=$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux-plymouth-theme.script|g" "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux-plymouth-theme.plymouth"
            debug_log "Successfully updated configuration file"
        else
            # If the configuration file doesn't exist, create it
            debug_log "Configuration file not found, creating a new one"
            echo "[Plymouth Theme]" | sudo tee "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux-plymouth-theme.plymouth" > /dev/null
            echo "Name=tux-plymouth-theme" | sudo tee -a "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux-plymouth-theme.plymouth" > /dev/null
            echo "Description=A theme that features the Tux himself at boot and shutdown." | sudo tee -a "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux-plymouth-theme.plymouth" > /dev/null
            echo "ModuleName=script" | sudo tee -a "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux-plymouth-theme.plymouth" > /dev/null
            echo "" | sudo tee -a "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux-plymouth-theme.plymouth" > /dev/null
            echo "[script]" | sudo tee -a "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux-plymouth-theme.plymouth" > /dev/null
            echo "ImageDir=$PLYMOUTH_THEME_DIR/tux-plymouth-theme" | sudo tee -a "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux-plymouth-theme.plymouth" > /dev/null
            echo "ScriptFile=$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux-plymouth-theme.script" | sudo tee -a "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux-plymouth-theme.plymouth" > /dev/null
        fi

        # Make sure the theme directory contains all required files from src/tux
        if [ -d "$SRC_DIR/tux" ]; then
            printf "${YELLOW}Copying additional Tux assets from src/tux directory...${NC}\n"
            debug_log "Copying Tux assets from $SRC_DIR/tux/ to $PLYMOUTH_THEME_DIR/tux-plymouth-theme/"
            sudo cp -r "$SRC_DIR/tux/"* "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/"
        else
            debug_log "No tux directory found in src"
        fi

        # Check if script file exists, if not, copy it from source
        if [ ! -f "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux-plymouth-theme.script" ]; then
            debug_log "Script file missing, checking source directory"
            if [ -f "$SRC_DIR/tux-plymouth-theme.script" ]; then
                debug_log "Copying script file from source directory"
                sudo cp "$SRC_DIR/tux-plymouth-theme.script" "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/"
            else
                debug_log "Script file not found in source directory, creating a minimal script"
                echo "Window.SetBackgroundTopColor (0, 0, 0);           # black" | sudo tee "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux-plymouth-theme.script" > /dev/null
                echo "Window.SetBackgroundBottomColor (0, 0, 0);        # black" | sudo tee -a "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux-plymouth-theme.script" > /dev/null
                echo 'logo.image = Image("tux.png");' | sudo tee -a "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux-plymouth-theme.script" > /dev/null
                echo 'logo.sprite = Sprite(logo.image);' | sudo tee -a "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux-plymouth-theme.script" > /dev/null
                echo 'logo.sprite.SetX (Window.GetWidth() / 2 - logo.image.GetWidth() / 2);' | sudo tee -a "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux-plymouth-theme.script" > /dev/null
                echo 'logo.sprite.SetY (Window.GetHeight() / 2 - logo.image.GetHeight() / 2);' | sudo tee -a "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux-plymouth-theme.script" > /dev/null

                # This is a critical error, notify user
                printf "${LIGHT_RED}Warning: Script file not found in source, created minimal version. Theme may not work as expected.${NC}\n"
                debug_log "Created minimal script file due to missing source"
            fi
        fi

        # Make sure there's at least one image file (tux.png)
        if [ ! -f "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux.png" ]; then
            debug_log "Tux image not found, checking for other PNG files"

            # Check if there are any PNG files we can rename to tux.png
            PNG_FILES=$(find "$PLYMOUTH_THEME_DIR/tux-plymouth-theme" -name "*.png" | head -n 1)

            if [ -n "$PNG_FILES" ]; then
                debug_log "Found PNG file: $PNG_FILES, copying as tux.png"
                sudo cp "$PNG_FILES" "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux.png"
            else
                debug_log "No PNG files found, creating fallback ASCII art Tux"
                # Create a simple ASCII art Tux as a fallback
                echo "P3" | sudo tee "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux.ppm" > /dev/null
                echo "# ASCII art Tux" | sudo tee -a "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux.ppm" > /dev/null
                echo "64 64" | sudo tee -a "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux.ppm" > /dev/null
                echo "255" | sudo tee -a "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux.ppm" > /dev/null

                # Fill with black pixels
                for i in $(seq 1 4096); do
                    echo "0 0 0" | sudo tee -a "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux.ppm" > /dev/null
                done

                # Convert to PNG if ImageMagick is available
                if command -v convert >/dev/null 2>&1; then
                    debug_log "Converting PPM to PNG using ImageMagick"
                    sudo convert "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux.ppm" "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux.png"
                    sudo rm "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux.ppm"
                else
                    debug_log "ImageMagick not available, renaming PPM to PNG"
                    sudo mv "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux.ppm" "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux.png"
                fi

                # This is a critical error, notify user
                printf "${LIGHT_RED}Warning: Tux image not found, created placeholder. Theme will not display correctly.${NC}\n"
                printf "${YELLOW}Please manually add a proper tux.png file to $PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux.png${NC}\n"
                debug_log "Created placeholder Tux image"
            fi
        fi

        clear_screen
        header "TUX PLYMOUTH THEME" "$1"
        printf "${LIGHT_GREEN}Theme files installed. Setting as default...${NC}\n"

        # Use the plymouth-set-default-theme command if the package is installed
        if command -v plymouth-set-default-theme >/dev/null 2>&1 && [ "$PLYMOUTH_THEMES_INSTALLED" = true ]; then
            printf "${YELLOW}Using plymouth-set-default-theme to set Tux as default...${NC}\n"
            debug_log "Using plymouth-set-default-theme to set Tux as default and update initramfs"

            # Use the -R flag to both set the theme and update initramfs in one command
            sudo plymouth-set-default-theme tux-plymouth-theme -R

            if [ $? -eq 0 ]; then
                debug_log "Successfully set tux-plymouth-theme as default using plymouth-set-default-theme"
                printf "${LIGHT_GREEN}Successfully set Tux as your default boot theme!${NC}\n"
            else
                debug_log "Error setting theme with plymouth-set-default-theme"
                printf "${LIGHT_RED}Error setting theme with plymouth-set-default-theme. Falling back to alternatives system.${NC}\n"
                # Fall back to alternatives system
                use_alternatives_system
            fi
        else
            debug_log "plymouth-set-default-theme not available, using alternatives system"
            printf "${YELLOW}plymouth-set-default-theme not available. Using alternatives system...${NC}\n"
            # Use the alternatives system as a fallback
            use_alternatives_system
        fi

        clear_screen
        header "TUX PLYMOUTH THEME" "$1"
        printf "${LIGHT_GREEN}TUX successfully moved in as your new Boot Logo.${NC}\n"
        echo ""
        GNOME_SHELL_THEME_DIR=$(find /usr -name "gnome-shell" -type d 2>/dev/null | grep "share/gnome-shell/theme" | head -n 1)
        if [ -n "$GNOME_SHELL_THEME_DIR" ]; then
        printf "${YELLOW}Would you like to change the purple and orange in the lockscreen to black \nand grey (to better match your new Boot Logo?)${NC}\n"
        select yn in "Yes" "No"; do
            case $yn in
                Yes ) echo "Making some of the purple go away."
                        sudo sed -i 's_background: #2c001e url(resource:///org/gnome/shell/theme/noise-texture.png);_background: #000;_g' "$GNOME_SHELL_THEME_DIR/ubuntu.css"
                        sudo sed -i 's_background-color: #dd4814;_background-color: #2f343f;_g' "$GNOME_SHELL_THEME_DIR/ubuntu.css"
                        sudo sed -i 's_border-right: 2px solid #dd4814;_border-right: 2px solid #2f343f;_g' "$GNOME_SHELL_THEME_DIR/ubuntu.css"
                    printf "${LIGHT_GREEN}Done.${NC}\n"
                    break;;
                No ) echo "Purple stays."
                    break;;
            esac
        done
        fi
    else
        printf "\033c"
        header "TUX PLYMOUTH THEME" "$1"
        printf "${LIGHT_RED}Couldn't find the Plymouth themes folder.${NC}\n"
        echo "Check out our website for manual instructions where you can comment questions and solutions:"
        echo "https://tux4ubuntu.org"
        echo ""
        echo "Otherwise, read the instructions more carefully before continuing :)"
    fi

    echo ""
    read -n1 -r -p "Press any key to continue..." key
    exit
}

# Helper function to use the alternatives system as a fallback
function use_alternatives_system {
    # Fix any broken Plymouth alternatives configuration
    fix_alternatives_system

    # Check if alternatives system is available
    if command -v update-alternatives >/dev/null 2>&1; then
        # Properly register the theme with update-alternatives
        printf "${YELLOW}Registering theme with update-alternatives...${NC}\n"
        debug_log "Found update-alternatives command"

        # Make sure the .plymouth file exists before continuing
        if [ ! -f "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux-plymouth-theme.plymouth" ]; then
            printf "${LIGHT_RED}Error: Theme configuration file missing, cannot register theme.${NC}\n"
            debug_log "Theme configuration file missing, cannot register theme"
            read -n1 -r -p "Press any key to continue..." key
            exit 1
        fi

        # Remove any previous registration to avoid duplicates
        debug_log "Removing any previous theme registration"
        sudo update-alternatives --remove default.plymouth "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux-plymouth-theme.plymouth" 2>/dev/null

        # Register the theme with a high priority to make it appear in the list
        debug_log "Registering theme with priority 100"
        if sudo update-alternatives --install "/usr/share/plymouth/themes/default.plymouth" default.plymouth "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux-plymouth-theme.plymouth" 100 2>/dev/null; then
            debug_log "Theme registered successfully with update-alternatives"
        else
            debug_log "Error registering theme with update-alternatives"
            printf "${LIGHT_RED}Error registering theme with update-alternatives.${NC}\n"

            # Try with absolute path to update-alternatives
            debug_log "Trying with absolute path to update-alternatives"
            ALTERNATIVE_PATH=$(which update-alternatives)
            if [ -n "$ALTERNATIVE_PATH" ]; then
                debug_log "Using update-alternatives at $ALTERNATIVE_PATH for direct installation"
                if sudo "$ALTERNATIVE_PATH" --install "/usr/share/plymouth/themes/default.plymouth" default.plymouth "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux-plymouth-theme.plymouth" 100 2>/dev/null; then
                    debug_log "Direct registration successful"
                else
                    debug_log "Direct registration failed, cannot continue"
                    printf "${LIGHT_RED}Failed to register theme. Your Plymouth setup may be non-standard.${NC}\n"
                    printf "${YELLOW}Please manually run: sudo update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth $PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux-plymouth-theme.plymouth 100${NC}\n"
                fi
            else
                debug_log "Could not find update-alternatives command path"
                printf "${LIGHT_RED}Cannot find update-alternatives command. Manual configuration required.${NC}\n"
                printf "${YELLOW}Please manually run: sudo update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth $PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux-plymouth-theme.plymouth 100${NC}\n"
            fi
        fi

        # Verify the theme is registered
        echo "Verifying theme registration..."
        ALT_LIST=$(sudo update-alternatives --list default.plymouth 2>/dev/null)
        debug_log "Alternatives list: $ALT_LIST"
        if echo "$ALT_LIST" | grep -q "tux-plymouth-theme"; then
            printf "${LIGHT_GREEN}✓ Theme successfully registered with alternatives system.${NC}\n"
            debug_log "Theme registration verified successfully"

            # Set as default
            sudo update-alternatives --set default.plymouth "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux-plymouth-theme.plymouth"
            debug_log "Set tux-plymouth-theme as default using update-alternatives --set"
        else
            printf "${LIGHT_RED}✗ Theme registration issue detected.${NC}\n"
            printf "${YELLOW}Please manually run: sudo update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth $PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux-plymouth-theme.plymouth 100${NC}\n"
            debug_log "Theme not found in alternatives list"
        fi
    else
        printf "${YELLOW}update-alternatives command not found. Cannot register theme properly.${NC}\n"
        debug_log "update-alternatives command not found"
        printf "${LIGHT_RED}Your system doesn't support the alternatives system. Plymouth themes may not work correctly.${NC}\n"
        printf "${YELLOW}Please ensure your distribution supports plymouth themes.${NC}\n"
    fi

    printf "${YELLOW}Updating initramfs. This could take a while.${NC}\n"
    debug_log "Updating initramfs"
    sudo update-initramfs -u;
    debug_log "initramfs update completed"
}

function uninstall {
    clear_screen
    header "TUX PLYMOUTH THEME" "$1"
    debug_log "Starting uninstall process"
    printf "${LIGHT_RED}Really sure you want to uninstall TUX BOOT THEME from your boot screen"
    printf "(Plymouth)?${NC}\n"
    echo ""
    echo "(Type 1 or 2, then press ENTER)"
    select yn in "Yes" "No"; do
        case $yn in
            Yes )
                clear_screen
                header "TUX PLYMOUTH THEME" "$1"
                debug_log "User confirmed uninstall"

                # Find Plymouth theme directory
                PLYMOUTH_THEME_DIR=""
                # Check common locations
                for dir in "/usr/share/plymouth/themes" "/lib/plymouth/themes" "/usr/lib/plymouth/themes"; do
                    if [ -d "$dir" ]; then
                        PLYMOUTH_THEME_DIR="$dir"
                        debug_log "Found Plymouth theme directory at: $dir"
                        break
                    fi
                done

                # If not found in common locations, try to find it using the plymouth binary
                if [ -z "$PLYMOUTH_THEME_DIR" ]; then
                    debug_log "Plymouth theme directory not found in common locations, trying to find using plymouth binary"
                    PLYMOUTH_BIN=$(which plymouth 2>/dev/null)
                    if [ -n "$PLYMOUTH_BIN" ]; then
                        debug_log "Plymouth binary found at: $PLYMOUTH_BIN"
                        # Get plymouth base directory from the binary location
                        PLYMOUTH_BASE=$(dirname $(dirname "$PLYMOUTH_BIN"))
                        debug_log "Plymouth base directory: $PLYMOUTH_BASE"
                        # Try to find themes directory
                        for dir in "$PLYMOUTH_BASE/share/plymouth/themes" "$PLYMOUTH_BASE/lib/plymouth/themes"; do
                            if [ -d "$dir" ]; then
                                PLYMOUTH_THEME_DIR="$dir"
                                debug_log "Found Plymouth theme directory at: $dir"
                                break
                            fi
                        done
                    else
                        debug_log "Plymouth binary not found"
                    fi
                fi

                if [ -z "$PLYMOUTH_THEME_DIR" ]; then
                    printf "${LIGHT_RED}Couldn't find the Plymouth themes folder.${NC}\n"
                    echo "Check out our website for manual instructions where you can comment questions and solutions:"
                    echo "https://tux4ubuntu.org"
                    debug_log "Plymouth theme directory not found, exiting uninstall"
                    break
                fi

                # Instead of using fix_alternatives_system, which can remove all themes,
                # we'll carefully check only if our theme is the default and handle accordingly
                debug_log "Checking Plymouth alternatives setup for removal"

                # Check if default.plymouth is directly linked to our theme (not through alternatives)
                if [ -L "$PLYMOUTH_THEME_DIR/default.plymouth" ] && [ "$(readlink "$PLYMOUTH_THEME_DIR/default.plymouth" 2>/dev/null)" == "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux-plymouth-theme.plymouth" ]; then
                    debug_log "Found direct symlink to our theme, will remove it carefully"
                    # Direct symlink detected, we need to find another theme to set as default
                    ALT_THEME=""

                    # Find first available theme that's not ours
                    for theme_file in "$PLYMOUTH_THEME_DIR"/*/*.plymouth; do
                        if [[ "$theme_file" != *"tux-plymouth-theme"* ]]; then
                            ALT_THEME="$theme_file"
                            debug_log "Found alternative theme: $ALT_THEME"
                            break
                        fi
                    done

                    if [ -n "$ALT_THEME" ]; then
                        debug_log "Setting $ALT_THEME as default temporarily"
                        sudo ln -sf "$ALT_THEME" "$PLYMOUTH_THEME_DIR/default.plymouth"
                    fi
                fi

                if [ -d "$PLYMOUTH_THEME_DIR/tux-plymouth-theme" ]; then
                    # Properly remove theme registration before deleting files
                    if command -v update-alternatives >/dev/null 2>&1; then
                        printf "${YELLOW}Removing theme registration...${NC}\n"
                        debug_log "Removing theme registration from alternatives system"
                        # Only remove our specific theme, not all themes
                        sudo update-alternatives --remove default.plymouth "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux-plymouth-theme.plymouth" 2>/dev/null
                    fi

                    # Remove theme files
                    debug_log "Removing theme directory: $PLYMOUTH_THEME_DIR/tux-plymouth-theme"
                    sudo rm -rf "$PLYMOUTH_THEME_DIR/tux-plymouth-theme"

                    clear_screen
                    header "TUX PLYMOUTH THEME" "$1"
                    echo "If you have more than one theme, choose below which one you want as default."
                    echo "on boot now when Tux is removed."
                    echo ""
                    read -n1 -r -p "Press any key to continue..." key
                    debug_log "Showing available themes with update-alternatives --config"
                    sudo update-alternatives --config default.plymouth 2>/dev/null || echo "No alternative themes found."
                    echo "Updating initramfs. This could take a while."
                    debug_log "Updating initramfs"
                    sudo update-initramfs -u;
                    debug_log "initramfs update completed"
                    clear_screen

                    # Find GNOME Shell theme directory
                    debug_log "Searching for GNOME Shell theme directory"
                    GNOME_SHELL_THEME_DIR=$(find /usr -name "gnome-shell" -type d 2>/dev/null | grep "share/gnome-shell/theme" | head -n 1)
                    if [ -n "$GNOME_SHELL_THEME_DIR" ]; then
                        debug_log "Found GNOME Shell theme directory at: $GNOME_SHELL_THEME_DIR"
                        # Restore original colors
                        if [ -f "$GNOME_SHELL_THEME_DIR/ubuntu.css" ]; then
                            debug_log "Restoring original colors in GNOME Shell theme"
                            sudo sed -i 's_background: #000;_background: #2c001e url(resource:///org/gnome/shell/theme/noise-texture.png);_g' "$GNOME_SHELL_THEME_DIR/ubuntu.css"
                            sudo sed -i 's_background-color: #2f343f;_background-color: #dd4814;_g' "$GNOME_SHELL_THEME_DIR/ubuntu.css"
                            sudo sed -i 's_border-right: 2px solid #2f343f;_border-right: 2px solid #dd4814;_g' "$GNOME_SHELL_THEME_DIR/ubuntu.css"
                        else
                            debug_log "ubuntu.css not found in GNOME Shell theme directory"
                        fi
                    else
                        debug_log "GNOME Shell theme directory not found"
                    fi

                    header "TUX PLYMOUTH THEME" "$1"
                    echo "Tux is successfully removed from your boot."
                    printf "${LIGHT_GREEN}TUX Boot Logo theme is successfully uninstalled.${NC}\n"
                    debug_log "Uninstall completed successfully"
                else
                    printf "${LIGHT_RED}TUX Plymouth theme not found. Nothing to uninstall.${NC}\n"
                    debug_log "TUX theme directory not found at $PLYMOUTH_THEME_DIR/tux-plymouth-theme"
                fi

                # After theme uninstallation (successful or not), ask about removing plymouth-themes package
                if dpkg -l | grep -q "plymouth-themes"; then
                    printf "${YELLOW}Do you also want to remove the plymouth-themes package?${NC}\n"
                    printf "${YELLOW}(Only remove it if you don't need it for other themes)${NC}\n"
                    select remove_pkg in "Yes" "No"; do
                        case $remove_pkg in
                            Yes )
                                printf "${YELLOW}Removing plymouth-themes package...${NC}\n"
                                debug_log "Removing plymouth-themes package"
                                sudo apt remove -y plymouth-themes
                                printf "${LIGHT_GREEN}Plymouth themes package removed.${NC}\n"
                                debug_log "plymouth-themes package removed"
                                break;;
                            No )
                                printf "${YELLOW}Keeping plymouth-themes package installed.${NC}\n"
                                debug_log "User chose to keep plymouth-themes package"
                                break;;
                        esac
                    done
                fi
                break;;
            No )
                clear_screen
                header "TUX PLYMOUTH THEME" "$1"
                echo "Awesome! Tux smiles and gives you a pat on the shoulder."
                debug_log "User cancelled uninstall"
            break;;
        esac
    done
    echo ""
    read -n1 -r -p "Press any key to continue..." key
    exit
}

function header {
    var_size=${#1}
    # 80 is a full width set by us (to work in the smallest standard terminal window)
    if [ $STEPCOUNTER = false ]; then
        # 80 - 2 - 1 = 77 to allow space for side lines and the first space after border.
        len=$(expr 77 - $var_size)
    else
        # "Step X/X " is 9
        # 80 - 2 - 1 - 9 = 68 to allow space for side lines and the first space after border.
        len=$(expr 68 - $var_size)
    fi
    ch=' '
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    printf "║"
    printf " ${YELLOW}$1${NC}"
    printf '%*s' "$len" | tr ' ' "$ch"
    if [ $STEPCOUNTER = true ]; then
        printf "Step "${LIGHT_GREEN}$2${NC}
        printf "/5 "
    fi
    printf "║\n"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo ""
}

function check_sudo {
    debug_log "Checking sudo access"
    if sudo -n true 2>/dev/null; then
        debug_log "User has sudo access without password"
        :
    else
        debug_log "Sudo password will be required"
        printf "Oh, TUX will ask below about sudo rights to copy and install everything...\n\n"
    fi
}

function goto_tux4ubuntu_org {
    echo ""
    printf "${YELLOW}Launching website in your favourite browser...${NC}\n"
    debug_log "Opening tux4ubuntu.org website"
    x-www-browser https://tux4ubuntu.org/portfolio/plymouth &
    echo ""
    sleep 2
    read -n1 -r -p "Press any key to continue..." key
    exit
}

function manual_theme_selection {
    clear_screen
    header "MANUAL THEME SELECTION" "$1"
    debug_log "Starting manual theme selection"

    # Find Plymouth theme directory
    PLYMOUTH_THEME_DIR=""
    # Check common locations
    for dir in "/usr/share/plymouth/themes" "/lib/plymouth/themes" "/usr/lib/plymouth/themes"; do
        if [ -d "$dir" ]; then
            PLYMOUTH_THEME_DIR="$dir"
            debug_log "Found Plymouth theme directory at: $dir"
            break
        fi
    done

    if [ -z "$PLYMOUTH_THEME_DIR" ]; then
        printf "${LIGHT_RED}Couldn't find the Plymouth themes folder.${NC}\n"
        debug_log "Plymouth theme directory not found"
        echo ""
        read -n1 -r -p "Press any key to continue..." key
        return
    fi

    if [ ! -d "$PLYMOUTH_THEME_DIR/tux-plymouth-theme" ]; then
        printf "${LIGHT_RED}Tux theme directory not found. Please install the theme first.${NC}\n"
        debug_log "Tux theme directory not found at: $PLYMOUTH_THEME_DIR/tux-plymouth-theme"
        echo ""
        read -n1 -r -p "Press any key to continue..." key
        return
    fi

    # Check for broken alternatives configuration and fix it
    fix_alternatives_system

    printf "${YELLOW}Setting Tux as the default Plymouth theme...${NC}\n"
    debug_log "Setting Tux as default theme via alternatives system"

    # Use the alternatives system properly
    if command -v update-alternatives >/dev/null 2>&1; then
        debug_log "Using update-alternatives to set Tux as default theme"
        # First make sure the theme is registered
        sudo update-alternatives --remove default.plymouth "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux-plymouth-theme.plymouth" 2>/dev/null
        sudo update-alternatives --install "/usr/share/plymouth/themes/default.plymouth" default.plymouth "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux-plymouth-theme.plymouth" 100
        # Set it as default
        sudo update-alternatives --set default.plymouth "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux-plymouth-theme.plymouth"
        debug_log "Theme set as default using alternatives system"
    else
        printf "${LIGHT_RED}update-alternatives command not found. Cannot set theme properly.${NC}\n"
        debug_log "update-alternatives command not found"
    fi

    # Update initramfs
    printf "${YELLOW}Updating initramfs. This could take a while.${NC}\n"
    debug_log "Updating initramfs"
    sudo update-initramfs -u
    debug_log "initramfs update completed"

    clear_screen
    header "MANUAL THEME SELECTION" "$1"
    printf "${LIGHT_GREEN}Tux Plymouth theme has been manually set as the default theme.${NC}\n"
    echo "You may need to reboot to see the changes."
    debug_log "Manual theme selection completed successfully"
    echo ""
    read -n1 -r -p "Press any key to continue..." key
}

function verify_theme {
    clear_screen
    header "VERIFY THEME INSTALLATION" "$1"
    debug_log "Starting theme verification"

    # Find Plymouth theme directory
    PLYMOUTH_THEME_DIR=""
    # Check common locations
    for dir in "/usr/share/plymouth/themes" "/lib/plymouth/themes" "/usr/lib/plymouth/themes"; do
        if [ -d "$dir" ]; then
            PLYMOUTH_THEME_DIR="$dir"
            debug_log "Found Plymouth theme directory at: $dir"
            break
        fi
    done

    if [ -z "$PLYMOUTH_THEME_DIR" ]; then
        printf "${LIGHT_RED}Couldn't find the Plymouth themes folder.${NC}\n"
        debug_log "Plymouth theme directory not found"
        echo ""
        read -n1 -r -p "Press any key to continue..." key
        return
    fi

    # Check if theme directory exists
    if [ ! -d "$PLYMOUTH_THEME_DIR/tux-plymouth-theme" ]; then
        printf "${LIGHT_RED}Tux theme directory not found at: $PLYMOUTH_THEME_DIR/tux-plymouth-theme${NC}\n"
        printf "The theme is not installed or was installed to a different location.\n"
        debug_log "Tux theme directory not found at: $PLYMOUTH_THEME_DIR/tux-plymouth-theme"
    else
        printf "${LIGHT_GREEN}✓ Theme directory found at: $PLYMOUTH_THEME_DIR/tux-plymouth-theme${NC}\n"
        debug_log "Theme directory found"

        # Check for key files
        if [ -f "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux-plymouth-theme.plymouth" ]; then
            printf "${LIGHT_GREEN}✓ Theme configuration file found${NC}\n"
            debug_log "Theme configuration file found"
        else
            printf "${LIGHT_RED}✗ Theme configuration file missing${NC}\n"
            debug_log "Theme configuration file missing"
        fi

        if [ -f "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux-plymouth-theme.script" ]; then
            printf "${LIGHT_GREEN}✓ Theme script file found${NC}\n"
            debug_log "Theme script file found"
        else
            printf "${LIGHT_RED}✗ Theme script file missing${NC}\n"
            debug_log "Theme script file missing"
        fi

        # Check for Tux image files
        TUX_FILES_COUNT=$(find "$PLYMOUTH_THEME_DIR/tux-plymouth-theme" -type f -name "*.png" | wc -l)
        debug_log "Found $TUX_FILES_COUNT image files"
        if [ "$TUX_FILES_COUNT" -gt 0 ]; then
            printf "${LIGHT_GREEN}✓ Found $TUX_FILES_COUNT image files${NC}\n"
        else
            printf "${LIGHT_RED}✗ No image files found${NC}\n"
        fi
    fi

    # Check if the theme is registered in alternatives
    if command -v update-alternatives >/dev/null 2>&1; then
        debug_log "Checking theme registration in alternatives system"
        ALT_LIST=$(sudo update-alternatives --list default.plymouth 2>/dev/null)
        debug_log "Alternatives list: $ALT_LIST"
        if echo "$ALT_LIST" | grep -q "tux-plymouth-theme"; then
            printf "${LIGHT_GREEN}✓ Theme is registered with alternatives system${NC}\n"
            debug_log "Theme is registered with alternatives system"
        else
            printf "${LIGHT_RED}✗ Theme is not registered with alternatives system${NC}\n"
            printf "Command to register: sudo update-alternatives --install $PLYMOUTH_THEME_DIR/default.plymouth default.plymouth $PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux-plymouth-theme.plymouth 100\n"
            debug_log "Theme is not registered with alternatives system"
        fi
    fi

    # Check current default theme
    debug_log "Checking current default theme"
    DEFAULT_THEME=$(readlink -f "$PLYMOUTH_THEME_DIR/default.plymouth" 2>/dev/null)
    if [ -n "$DEFAULT_THEME" ]; then
        printf "Current default theme: $DEFAULT_THEME\n"
        debug_log "Current default theme: $DEFAULT_THEME"
        if echo "$DEFAULT_THEME" | grep -q "tux-plymouth-theme"; then
            printf "${LIGHT_GREEN}✓ Tux is set as the default theme${NC}\n"
            debug_log "Tux is set as the default theme"
        else
            printf "${LIGHT_RED}✗ Tux is not set as the default theme${NC}\n"
            debug_log "Tux is not set as the default theme"
        fi
    else
        printf "${LIGHT_RED}✗ Could not determine current default theme${NC}\n"
        debug_log "Could not determine current default theme"
    fi

    echo ""
    printf "${YELLOW}Tip: If the theme doesn't appear in the list, try using the 'Manual Theme Selection'${NC}\n"
    printf "${YELLOW}option from the main menu to directly set Tux as the default theme.${NC}\n"
    debug_log "Theme verification completed"

    echo ""
    read -n1 -r -p "Press any key to continue..." key
}

function toggle_debug_mode {
    if [ "$DEBUG_MODE" = true ]; then
        DEBUG_MODE=false
        echo "Debug mode turned OFF"
    else
        DEBUG_MODE=true
        echo "Debug mode turned ON"
        echo "Now all commands will be shown, and screen will not be cleared"
    fi
    sleep 2
}

function save_debug_logs {
    LOG_FILE="tux-plymouth-debug-$(date +%Y%m%d-%H%M%S).log"
    clear_screen
    header "SAVE DEBUG LOGS" "$1"
    printf "${YELLOW}Saving debug logs to $LOG_FILE...${NC}\n"

    # Create a temporary file with debug info
    echo "TUX Plymouth Theme Debug Log - $(date)" > "$LOG_FILE"
    echo "----------------------------------------" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"

    # System information
    echo "SYSTEM INFORMATION:" >> "$LOG_FILE"
    echo "-------------------" >> "$LOG_FILE"
    echo "Distribution: $(lsb_release -d 2>/dev/null | cut -f2- || echo 'Unknown')" >> "$LOG_FILE"
    echo "Kernel: $(uname -r)" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"

    # Plymouth package information
    echo "PLYMOUTH PACKAGES:" >> "$LOG_FILE"
    echo "-----------------" >> "$LOG_FILE"
    dpkg -l | grep plymouth >> "$LOG_FILE" 2>&1
    echo "" >> "$LOG_FILE"

    # Plymouth theme directories
    echo "PLYMOUTH THEME DIRECTORIES:" >> "$LOG_FILE"
    echo "-------------------------" >> "$LOG_FILE"
    for dir in "/usr/share/plymouth/themes" "/lib/plymouth/themes" "/usr/lib/plymouth/themes"; do
        if [ -d "$dir" ]; then
            echo "Directory exists: $dir" >> "$LOG_FILE"
            echo "Contents:" >> "$LOG_FILE"
            ls -la "$dir" >> "$LOG_FILE" 2>&1
        else
            echo "Directory does not exist: $dir" >> "$LOG_FILE"
        fi
        echo "" >> "$LOG_FILE"
    done

    # Check Tux theme directory
    echo "TUX THEME STATUS:" >> "$LOG_FILE"
    echo "----------------" >> "$LOG_FILE"
    PLYMOUTH_THEME_DIR=""
    for dir in "/usr/share/plymouth/themes" "/lib/plymouth/themes" "/usr/lib/plymouth/themes"; do
        if [ -d "$dir" ]; then
            PLYMOUTH_THEME_DIR="$dir"
            break
        fi
    done

    if [ -n "$PLYMOUTH_THEME_DIR" ] && [ -d "$PLYMOUTH_THEME_DIR/tux-plymouth-theme" ]; then
        echo "Tux theme found at: $PLYMOUTH_THEME_DIR/tux-plymouth-theme" >> "$LOG_FILE"
        echo "Theme files:" >> "$LOG_FILE"
        ls -la "$PLYMOUTH_THEME_DIR/tux-plymouth-theme" >> "$LOG_FILE" 2>&1

        if [ -f "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux-plymouth-theme.plymouth" ]; then
            echo "" >> "$LOG_FILE"
            echo "Plymouth configuration file contents:" >> "$LOG_FILE"
            cat "$PLYMOUTH_THEME_DIR/tux-plymouth-theme/tux-plymouth-theme.plymouth" >> "$LOG_FILE" 2>&1
        fi
    else
        echo "Tux theme directory not found" >> "$LOG_FILE"
    fi

    # Check alternatives configuration
    echo "" >> "$LOG_FILE"
    echo "PLYMOUTH ALTERNATIVES:" >> "$LOG_FILE"
    echo "---------------------" >> "$LOG_FILE"
    if command -v update-alternatives >/dev/null 2>&1; then
        echo "update-alternatives command is available" >> "$LOG_FILE"
        echo "Default Plymouth theme alternatives:" >> "$LOG_FILE"
        sudo update-alternatives --list default.plymouth >> "$LOG_FILE" 2>&1
        echo "" >> "$LOG_FILE"
        echo "Current default theme:" >> "$LOG_FILE"
        readlink -f "$PLYMOUTH_THEME_DIR/default.plymouth" >> "$LOG_FILE" 2>&1
    else
        echo "update-alternatives command is not available" >> "$LOG_FILE"
    fi

    # Display completion message
    printf "${LIGHT_GREEN}Debug logs have been saved to: $LOG_FILE${NC}\n"
    printf "You can attach this file when reporting issues.\n"
    echo ""
    read -n1 -r -p "Press any key to continue..." key
}

function use_plymouth_theme_selector {
    clear_screen
    header "PLYMOUTH THEME SELECTOR" "$1"
    debug_log "Starting plymouth theme selector"

    # Check if plymouth-themes package is installed
    if dpkg -l | grep -q "plymouth-themes"; then
        printf "${YELLOW}Starting the Plymouth Theme Selector...${NC}\n"
        debug_log "Using plymouth-set-default-theme selector"

        # Check if tux theme is installed
        if [ -d "/usr/share/plymouth/themes/tux-plymouth-theme" ]; then
            printf "${LIGHT_GREEN}The Tux theme is installed and should appear in the list.${NC}\n"
        else
            printf "${YELLOW}Note: The Tux theme doesn't appear to be installed yet.${NC}\n"
            printf "${YELLOW}You may want to install it first using option 1 from the main menu.${NC}\n"
        fi

        echo ""

        # Run the theme selector to list available themes
        printf "${YELLOW}Available Plymouth themes:${NC}\n"
        sudo plymouth-set-default-theme --list
        echo ""

        # If Tux theme is installed, offer a quick select option
        if [ -d "/usr/share/plymouth/themes/tux-plymouth-theme" ]; then
            printf "${YELLOW}Would you like to set Tux as your default theme?${NC}\n"
            select yn in "Yes" "No, select another theme"; do
                case $yn in
                    Yes )
                        printf "${YELLOW}Setting Tux as your default theme...${NC}\n"
                        debug_log "Setting tux-plymouth-theme as default using plymouth-set-default-theme -R"
                        sudo plymouth-set-default-theme tux-plymouth-theme -R
                        printf "${LIGHT_GREEN}Tux set as default theme and initramfs updated.${NC}\n"
                        break;;
                    "No, select another theme" )
                        break;;
                esac
            done
        fi

        if [ ! -d "/usr/share/plymouth/themes/tux-plymouth-theme" ] || [ "$yn" = "No, select another theme" ]; then
            printf "${YELLOW}Enter the name of the theme you want to use:${NC}\n"
            read theme_name

            if [ -n "$theme_name" ]; then
                printf "${YELLOW}Setting theme and updating initramfs. This could take a while...${NC}\n"
                debug_log "Setting $theme_name as default using plymouth-set-default-theme -R"
                sudo plymouth-set-default-theme $theme_name -R
                printf "${LIGHT_GREEN}Theme set to '$theme_name' successfully.${NC}\n"
                debug_log "Theme set to '$theme_name' using plymouth-set-default-theme with -R flag"
            else
                printf "${YELLOW}No theme selected, keeping current theme.${NC}\n"
            fi
        fi
    else
        printf "${LIGHT_RED}Plymouth themes package is not installed.${NC}\n"
        printf "${YELLOW}Would you like to install it now?${NC}\n"
        select yn in "Yes" "No"; do
            case $yn in
                Yes )
                    printf "${YELLOW}Installing plymouth-themes package...${NC}\n"
                    debug_log "Installing plymouth-themes package"
                    check_sudo
                    sudo apt update
                    sudo apt install -y plymouth-themes

                    printf "${LIGHT_GREEN}Plymouth themes package installed.${NC}\n"
                    printf "${YELLOW}Returning to this menu option will now show the theme selector.${NC}\n"
                    debug_log "plymouth-themes package installed"
                    break;;
                No )
                    printf "${YELLOW}Skipping plymouth-themes package installation.${NC}\n"
                    debug_log "User declined to install plymouth-themes package"
                    break;;
            esac
        done
    fi

    echo ""
    read -n1 -r -p "Press any key to continue..." key
}

while :
do
    if [ "$DEBUG_MODE" = false ]; then
    clear
    fi
    if [ -z "$1" ]; then
        :
    else
        STEPCOUNTER=true
    fi
    header "TUX PLYMOUTH THEME" "$1"
    # Menu system as found here: http://stackoverflow.com/questions/20224862/bash-script-always-show-menu-after-loop-execution
    cat<<EOF
Type one of the following numbers/letters:

1) Install                                - Install Boot Logo theme
2) Uninstall                              - Uninstall Boot Logo theme
3) Manual Theme Selection                 - Directly set Tux as default theme
4) Verify Theme Installation              - Verify theme installation
5) Plymouth Theme Selector                - Use the plymouth-set-default-theme tool
--------------------------------------------------------------------------------
6) Read Instructions                      - Open up tux4ubuntu.org
--------------------------------------------------------------------------------
D) Toggle Debug Mode                      - Currently: $([ "$DEBUG_MODE" = true ] && echo "ON" || echo "OFF")
L) Save Debug Logs                        - Save diagnostic information to a file
Q) Skip                                   - Quit Boot Logo theme installer

(Press Control + C to quit the installer all together)
EOF
    read -n1 -s
    case "$REPLY" in
    "1")    install $1;;
    "2")    uninstall $1;;
    "3")    manual_theme_selection $1;;
    "4")    verify_theme $1;;
    "5")    use_plymouth_theme_selector $1;;
    "6")    goto_tux4ubuntu_org;;
    "D")    toggle_debug_mode;;
    "d")    toggle_debug_mode;;
    "L")    save_debug_logs $1;;
    "l")    save_debug_logs $1;;
    "S")    exit                      ;;
    "s")    exit                      ;;
    "Q")    exit                      ;;
    "q")    exit                      ;;
     * )    echo "invalid option"     ;;
    esac
    sleep 1
done