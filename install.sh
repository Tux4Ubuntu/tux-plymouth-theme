# Set global values
STEPCOUNTER=false # Changes to true if user choose to install Tux Everywhere
RED='\033[0;31m'
NC='\033[0m' # No Color

function install {
    printf "\033c"
    header "Adding Tux as BOOT LOGO" "$1"
    echo "Are you ready to have Tux Plymouth Theme installed?"
    echo ""
    echo "(Type 1 or 2, then press ENTER)"            
    select yn in "Yes" "No"; do
        case $yn in
            Yes ) 
                printf "\033c"
                header "Adding Tux as BOOT LOGO" "$1"
                
                # Here we check if OS is supported
                # More info on other OSes regarding plymouth: http://brej.org/blog/?p=158
                if [ -d "/usr/share/plymouth/themes/" ]; then
                # Control will enter here if $DIRECTORY exists.
                    check_sudo
                    sudo cp -r src /usr/share/plymouth/themes/
                    sudo mv /usr/share/plymouth/themes/src/ /usr/share/plymouth/themes/tux-plymouth-theme/

                    # Then we can add it to default.plymouth and update update-initramfs accordingly
                    sudo update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/tux-plymouth-theme/tux-plymouth-theme.plymouth 100;
                    printf "\033c"
                    header "Adding Tux as BOOT LOGO" "$1"
                    echo "Below you will see a list with all themes available to choose tux in the "
                    echo "Plymouth menu next (if you want Tux that is ;)";
                    echo ""
                    read -n1 -r -p "Press any key to continue..." key
                    sudo update-alternatives --config default.plymouth;
                    echo "Updating initramfs. This could take a while."
                    sudo update-initramfs -u;
                    printf "\033c"
                    header "Adding Tux as BOOT LOGO" "$1"
                    echo "Tux successfully moved in as your new Boot Logo."


                else
                    printf "\033c"
                    header "Adding Tux as BOOT LOGO" "$1"
                    printf "${RED}COULDN'T FIND PLYMOUTH THEMES FOLDER!${NC}\n"   
                    echo "If rEFInd is installed, check out our manual instructions at:"
                    echo "https://tux4ubuntu.org"
                    echo ""
                    echo "Otherwise, read the instructions more carefully before continuing :)"
                fi
                
                break;;
            No )
                printf "\033c"
                header "Adding Tux as BOOT LOGO" "$1"
                echo "It's not that dangerous though! Feel free to try when you're ready. Tux will be waiting."
            break;;
        esac
    done
    echo ""
    read -n1 -r -p "Press any key to continue..." key
}

function uninstall { 
    printf "\033c"
    header "Removing Tux as BOOT LOGO" "$1"
    echo "Really sure you want to uninstall Tux as your boot logo?"
    echo ""
    echo "(Type 1 or 2, then press ENTER)"            
    select yn in "Yes" "No"; do
        case $yn in
            Yes ) 
                printf "\033c"
                header "Uninstalling Tux as BOOT LOGO" "$1"
                # uninstall_not_found "plymouth-themes xclip"
                folder_to_delete=$plymouth_dir/themes/tux-plymouth-theme
                if [ -f $folder_to_delete ] ; then
                    sudo rm -r $folder_to_delete
                fi
                printf "\033c"
                header "Removing Tux as BOOT LOGO" "$1"
                echo "Below you will see a list with all themes available, choose a new theme to view"
                echo "on boot when Tux is removed."
                echo ""
                read -n1 -r -p "Press any key to continue..." key
                sudo update-alternatives --config default.plymouth;
                echo "Updating initramfs. This could take a while."
                sudo update-initramfs -u;
                printf "\033c"
                header "Removing Tux as BOOT LOGO" "$1"
                echo "Tux is successfully removed from your boot."
                break;;
            No )
                printf "\033c"
                header "Removing Tux as BOOT LOGO" "$1"
                echo "Awesome! Tux smiles and gives you a pat on the shoulder."
            break;;
        esac
    done
    echo ""
    read -n1 -r -p "Press any key to continue..." key
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
    printf " $1"
    printf '%*s' "$len" | tr ' ' "$ch"
    if [ $STEPCOUNTER = true ]; then
        printf "Step "$2
        printf "/7 "
    fi
    printf "║\n"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo ""
}

function check_sudo {
    if sudo -n true 2>/dev/null; then 
        :
    else
        echo "Oh, and Tux will need sudo rights to copy and install everything, so he'll ask" 
        echo "about that soon."
        echo ""
    fi
}

function goto_tux4ubuntu_org {
    echo ""
    echo "Launching website in your favourite browser."
    x-www-browser https://tux4ubuntu.org/ &
    read -n1 -r -p "Press any key to continue..." key
    echo ""
}

while :
do
    clear
    # Menu system as found here: http://stackoverflow.com/questions/20224862/bash-script-always-show-menu-after-loop-execution
    cat<<EOF    
╔══════════════════════════════════════════════════════════════════════════════╗
║ TUX REFIND THEME ver 1.0                                   © 2018 Tux4Ubuntu ║
║ Let's Bring Tux to Ubuntu                             https://tux4ubuntu.org ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                                                                              ║
║   What do you wanna do today? (Type in one of the following numbers)         ║
║                                                                              ║
║   1) Read manual instructions                  - Open up tux4ubuntu.org      ║
║   2) Install                                   - Install the theme           ║
║   3) Uninstall                                 - Uninstall the theme         ║
║   ------------------------------------------------------------------------   ║
║   Q) Quit                                      - Quit the installer (Ctrl+C) ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    read -n1 -s
    case "$REPLY" in
    "1")    goto_tux4ubuntu_org;;
    "2")    install $1;;
    "3")    uninstall $1;;
    "Q")    exit                      ;;
    "q")    exit                      ;;
     * )    echo "invalid option"     ;;
    esac
    sleep 1
done