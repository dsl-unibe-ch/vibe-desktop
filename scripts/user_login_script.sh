#!/bin/bash

# VIBE login script
# This script is part of the VIBE project. It is run during user login to provide the customization (wallpaper, menu) for the user.

STORAGE_LOCATION=/storage/research/dsl_vibe_rs/environments/$VIBE_STAGE
MENU_FILE=${XDG_CONFIG_HOME}/menus/applications-merged/vibe.menu
ICON_PATH=.local/share/icons/vibe
APPLICATION_DIR=${XDG_DATA_HOME}/applications
DIRECTORY_DIR=${XDG_DATA_HOME}/desktop-directories
WALLPAPER=${PROFILE_DIR}/Wallpaper/vibe_wallpaper.png
## Default Ubelix modules that will get loaded when the desktop is started
DEFAULT_MODULES="Anaconda3"

echo "[User Login Script] Running the $VIBE_STAGE VIBE user login script..."
echo "[User Login Script] User profile data located at $PROFILE_DIR"

# [Wallpaper] Set wallpaper 
/usr/bin/mkdir -p "$(dirname ${WALLPAPER})"
## Ensure the vibe wallpaper is available for the user if it is missing
if [ ! -f ${WALLPAPER} ]; then
    cp ${STORAGE_LOCATION}/desktop/vibe_wallpaper.png ${WALLPAPER}

    # Set the wallpaper image
    apptainer exec instance://$INSTANCE_NAME xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorVNC-0/workspace0/last-image -s ${WALLPAPER} -t string --create

    # Change the wallpaper style to 'Scaled'
    apptainer exec instance://$INSTANCE_NAME xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorVNC-0/workspace0/image-style -s 4 -t int --create

    # Set the background colour to black
    apptainer exec instance://$INSTANCE_NAME xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorVNC-0/workspace0/rgba1 --create -t 'double' -t 'double' -t 'double' -t 'double' -s 0.000000 -s 0.000000 -s 0.000000 -s 1.000000
fi

## Replace the wallpaper if the default changed
if [ $(md5sum ${STORAGE_LOCATION}/desktop/vibe_wallpaper.png | cut -d " " -f1) != $(md5sum ${WALLPAPER} | cut -d " " -f1) ]; then
  cp ${STORAGE_LOCATION}/desktop/vibe_wallpaper.png ${WALLPAPER}
fi

# [Modules] Load the default modules
echo "[User Login Script] Loading the default modules: ${DEFAULT_MODULES}"
module load ${DEFAULT_MODULES}
echo "[User Login Script] The following modules were loaded: $(module -t -b list)"

# [Menu] Copy the menu files from the default dir
## Ensure the folders exist
mkdir -p ${APPLICATION_DIR}
mkdir -p ${DIRECTORY_DIR}
mkdir -p $(dirname ${MENU_FILE})
mkdir -p ${PROFILE_DIR}/${ICON_PATH}

## applications folder
rm -f ${APPLICATION_DIR}/vibe-*

cp -r ${STORAGE_LOCATION}/desktop/menu/applications/* ${APPLICATION_DIR}

## desktop-directories folder
rm -f ${DIRECTORY_DIR}/vibe-*

cp -r ${STORAGE_LOCATION}/desktop/menu/desktop-directories/* ${DIRECTORY_DIR}

## menu files
if [ -f ${MENU_FILE} ]; then
  rm -f ${MENU_FILE}
fi

cp ${STORAGE_LOCATION}/desktop/menu/vibe.menu ${MENU_FILE}

## Ensure that the "<Menuname>VIBE</Menuname>" entry exists in the layout section of the xfce-applications.menu file
### Copy the default menu if no custom configuration exists yet
if [ ! -f ${XDG_CONFIG_HOME}/menus/xfce-applications.menu ]; then
  cp /etc/xdg/menus/xfce-applications.menu ${XDG_CONFIG_HOME}/menus/xfce-applications.menu
fi

### Add the entry for VIBE to the layout if it does not exist yet
if ! grep -q "<Menuname>VIBE</Menuname>" ${XDG_CONFIG_HOME}/menus/xfce-applications.menu; then
  # Add the VIBE menu entry to the default xfce menu layout if it does not yet exist
  sed -i 's#<Menuname>Settings</Menuname>#<Menuname>VIBE</Menuname>\n\t\t<Menuname>Settings</Menuname>#g' ${XDG_CONFIG_HOME}/menus/xfce-applications.menu
fi

## Copy the icon files from the template
rm -f ${PROFILE_DIR}/${ICON_PATH}/*

cp -r ${STORAGE_LOCATION}/desktop/menu/icons/* ${PROFILE_DIR}/${ICON_PATH}/

## Set the proper icon path
sed -i "s|#HOME#|${PROFILE_DIR}|g" ${APPLICATION_DIR}/*
sed -i "s|#HOME#|${PROFILE_DIR}|g" ${DIRECTORY_DIR}/*

# [Screensaver] Disable the screensaver (as it causes the VNC connection to close)
xset s off
xset s noblank

# [Default Browser] Overwrite firefox with containerized version
## Ensure the users local folder exists
mkdir -p $PROFILE_DIR/.local/bin
## Copy the firefox script from the defaults
cp ${STORAGE_LOCATION}/desktop/browser/firefox $PROFILE_DIR/.local/bin/
chmod +x $PROFILE_DIR/.local/bin/firefox
## Copy the custom browser config for xfce4
mkdir -p ${XDG_DATA_HOME}/xfce4/helpers/
cp ${STORAGE_LOCATION}/desktop/browser/custom-WebBrowser.desktop ${XDG_DATA_HOME}/xfce4/helpers/custom-WebBrowser.desktop
sed -i "s|#HOME#|${PROFILE_DIR}|g" ${XDG_DATA_HOME}/xfce4/helpers/custom-WebBrowser.desktop
## Set the custom-WebBrowser in the users xfce4/helpers.rc
helpers_rc_path="${XDG_CONFIG_HOME}/xfce4/helpers.rc"
if [ ! -f $helpers_rc_path ]; then
	echo "WebBrowser=custom-WebBrowser" > $helpers_rc_path
fi
sed -i "s/WebBrowser=firefox/WebBrowser=custom-WebBrowser/g" $helpers_rc_path
## Set the custom browser as default for the html mime types
gio mime text/html xfce4-web-browser.desktop
gio mime x-scheme-handler/http xfce4-web-browser.desktop
gio mime x-scheme-handler/https xfce4-web-browser.desktop
