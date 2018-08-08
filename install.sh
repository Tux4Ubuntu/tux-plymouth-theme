# Set global values
STEPCOUNTER=false # Changes to true if user choose to install Tux Everywhere
YELLOW='\033[1;33m'
LIGHT_GREEN='\033[1;32m'
LIGHT_RED='\033[1;31m'
NC='\033[0m' # No Color

function install {
    printf "\033c"
    header "TUX PLYMOUTH THEME" "$1"
    
    # Here we check if OS is supported
    # More info on other OSes regarding plymouth: http://brej.org/blog/?p=158
    if [ -d "/usr/share/plymouth/themes/" ]; then
    # Control will enter here if $DIRECTORY exists.
        check_sudo

        # Want the folder where the script is (can't use pwd since that gives us from where the script where run, which often is tux-install but not when we run locally)
        DIR=${BASH_SOURCE}
        DIR=${DIR%"install.sh"}
        sudo cp -r $DIR/src /usr/share/plymouth/themes/
        sudo rsync -a /usr/share/plymouth/themes/src/ /usr/share/plymouth/themes/tux-plymouth-theme/
        #sudo mv /usr/share/plymouth/themes/src/ /usr/share/plymouth/themes/tux-plymouth-theme/
        sudo rm -r /usr/share/plymouth/themes/src
        # Then we can add it to default.plymouth and update update-initramfs accordingly
        sudo update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/tux-plymouth-theme/tux-plymouth-theme.plymouth 100;
        printf "\033c"
        header "TUX PLYMOUTH THEME" "$1"
        printf "${YELLOW}Below you will see a list with all themes available to choose tux in the\n"
        printf "Plymouth menu next (if you want Tux that is ;)${NC}\n"
        echo ""
        read -n1 -r -p "Press any key to continue..." key
        sudo update-alternatives --config default.plymouth;
        printf "${YELLOW}Updating initramfs. This could take a while.${NC}\n"
        sudo update-initramfs -u;
        printf "\033c"
        header "TUX PLYMOUTH THEME" "$1"
        printf "${LIGHT_GREEN}TUX successfully moved in as your new Boot Logo.${NC}\n"


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

function uninstall { 
    printf "\033c"
    header "TUX PLYMOUTH THEME" "$1"
    printf "${LIGHT_RED}Really sure you want to uninstall TUX BOOT THEME from your boot screen"
    printf "(Plymouth)?${NC}\n"
    echo ""
    echo "(Type 1 or 2, then press ENTER)"            
    select yn in "Yes" "No"; do
        case $yn in
            Yes ) 
                printf "\033c"
                header "TUX PLYMOUTH THEME" "$1"
                # uninstall_not_found "plymouth-themes xclip"
                folder_to_delete=$plymouth_dir/themes/tux-plymouth-theme
                if [ -f $folder_to_delete ] ; then
                    sudo rm -r $folder_to_delete
                fi
                printf "\033c"
                header "TUX PLYMOUTH THEME" "$1"
                echo "Below you will see a list with all themes available, choose a new theme to view"
                echo "on boot now when Tux is removed."
                echo ""
                read -n1 -r -p "Press any key to continue..." key
                sudo update-alternatives --config default.plymouth;
                echo "Updating initramfs. This could take a while."
                sudo update-initramfs -u;
                printf "\033c"
                header "TUX PLYMOUTH THEME" "$1"
                echo "Tux is successfully removed from your boot."
                printf "${LIGHT_GREEN}TUX Boot Logo theme is successfully uninstalled.${NC}\n"
                break;;
            No )
                printf "\033c"
                header "TUX PLYMOUTH THEME" "$1"
                echo "Awesome! Tux smiles and gives you a pat on the shoulder."
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
    if sudo -n true 2>/dev/null; then 
        :
    else
        printf "Oh, TUX will ask below about sudo rights to copy and install everything...\n\n"
    fi
}

function goto_tux4ubuntu_org {
    echo ""
    printf "${YELLOW}Launching website in your favourite browser...${NC}\n"
    x-www-browser https://tux4ubuntu.org/portfolio/plymouth &
    echo ""
    sleep 2
    read -n1 -r -p "Press any key to continue..." key
    exit
}

while :
do
    clear
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
--------------------------------------------------------------------------------
3) Read Instructions                      - Open up tux4ubuntu.org      
--------------------------------------------------------------------------------   
Q) Skip                                   - Quit Boot Logo theme installer 

(Press Control + C to quit the installer all together)
EOF
    read -n1 -s
    case "$REPLY" in
    "1")    install $1;;
    "2")    uninstall $1;;
    "3")    goto_tux4ubuntu_org;;
    "S")    exit                      ;;
    "s")    exit                      ;;
    "Q")    exit                      ;;
    "q")    exit                      ;;
     * )    echo "invalid option"     ;;
    esac
    sleep 1
done