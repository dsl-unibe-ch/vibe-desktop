#!/bin/bash
# This script creates the menu structure for the VIBE desktop. It is part of the VIBE project from University of Bern.
# It is intended to be run after creating / updating container images. The script creates all files required for the custom XDG menu and stores them at $DEFAULTS_DIR (a shared folder) where a login script can copy them from for each user.
# See https://wiki.dsl.unibe.ch/wiki/vibe/view/VIBE%20Desktop/XFCE%20Customizations/#HApplicationshortcuts (Internal wiki) for more information.
set -e

# Get the stage the script is running in first
RUNTIME_DIR=$(dirname $(readlink -f "$0"))
STAGE=${RUNTIME_DIR##*/}

# Common locations of shared storage
STORAGE_LOCATION="/storage/research/dsl_vibe_rs"
STAGE_DIR="$STORAGE_LOCATION/environments/$STAGE"
BUILD_FILE_DIR="$STORAGE_LOCATION/repos/vibe-applications${STAGE/vibe-desktop/}"
CONTAINER_IMAGE_FOLDER="$STAGE_DIR/containers"
APPLICATION_LAUNCHER_SCRIPT="$STAGE_DIR/scripts/application_launcher.sh"
DEFAULTS_APPLICATION_DIR="$STAGE_DIR/desktop/menu/applications"
DEFAULTS_DIRECTORY_DIR="$STAGE_DIR/desktop/menu/desktop-directories"
DEFAULTS_MENU_FILE="$STAGE_DIR/desktop/menu/vibe.menu"
DEFAULTS_ICON_DIR="$STAGE_DIR/desktop/menu/icons"
DEFAULT_ICON="$STAGE_DIR/desktop/vibe_logo.png"

# desktop-specific paths
PROFILE_DIR="$HOME/.vibe/$STAGE"
ICON_PATH=".local/share/icons/vibe"

# build script specific variables
TMP_DIR=$(mktemp -d)/vibe/menu-builder
VIBE_DOCUMENTATION_URL="https://dsl-unibe-ch.github.io/vibe-documentation/"
DEBUG=false

if [ $1 ] && [ $1 == '--debug' ]; then
  DEBUG='true'
  echo "DEBUG enabled."
fi

# function to find the icon for menu entries
# expects the name to search for (name of a container, application, category or lab)
get_icon () {

  # We get 'fiji-base-2.16.0.sif' (container) or 'fiji' (application / category / lab) as item here
  local item=$1
  # check if we get a container name or a category / application / lab
  if [[ $item == *.sif ]]; then
    local isContainer='true'
    local itemname=${item::-4}
  else
    local itemname=${item}
  fi
  local iconfile

  ##  Search for an container-specific icon inside the container folder
  if [ ${isContainer} ] && [ ${isContainer} == 'true' ]; then

    iconfile=$(find $DEFAULTS_ICON_DIR -name $itemname.ico -o -name $itemname.svg -o -name $itemname.png)

    # Switch to application-specific icon if no container-specific is available
    if [ -z "$iconfile" ]; then
      itemname=$(echo "${itemname}" | awk -F '-' '{print $1}')
    fi
  fi

  if [ -z "$iconfile" ]; then

    ### if no container-specific icon is available, look for an application-specific one
    iconfile=$(find $DEFAULTS_ICON_DIR -name $itemname.ico -o -name $itemname.svg -o -name $itemname.png)
  fi

  if [ -z "$iconfile" ]; then

    ### if also no application-specific icon is available, use the default one
    iconfile=$DEFAULT_ICON
  fi

  # Return the filename only
  echo $(basename $iconfile)
}

# Ensure the folders exist
mkdir -p $(dirname $DEFAULTS_MENU_FILE)
mkdir -p $DEFAULTS_APPLICATION_DIR
mkdir -p $DEFAULTS_DIRECTORY_DIR
mkdir -p $DEFAULTS_ICON_DIR
mkdir -p $PROFILE_DIR/$ICON_PATH
mkdir -p $TMP_DIR

# # Ensure the temp dir is empty (remove files from previous failed runs)
rm -rf $TMP_DIR/*

# Create a list with all containers, applications and workflow categories from the available containers
unset CATEGORY_APPLICATION_LIST
unset DEFAULT_APPLICATION_LIST
unset LAB_LIST
unset WORKFLOW_LIST
unset CONTAINER_LIST
unset CATEGORY_LIST

# Find and copy all icon files to the default icon directory
find $BUILD_FILE_DIR -maxdepth 3 -type f -name \*.ico -o -name \*.svg -o -name \*.png -exec cp "{}" $DEFAULTS_ICON_DIR \;
cp $DEFAULT_ICON $DEFAULTS_ICON_DIR

# Remove the old desktop files
rm -f $DEFAULTS_APPLICATION_DIR/vibe-*.desktop

# Find all container files and build groups based on their labels. The groups are then used to construct the menu structure from.
for file in $(find $CONTAINER_IMAGE_FOLDER -type f -iname *.sif); do
  ## Get the proper container name from the filename
  filename=$(basename $file)
  container_name="${filename%.*}"
  ## Parse all container labels for later
  label_application=$(apptainer inspect $file | awk '/Application/ {sub($1 FS,""); print $0}')
  label_categories=$(apptainer inspect $file | awk '/Category/ {sub($1 FS,""); print $0}')
  default_label=$(apptainer inspect $file | awk '/Default/ {sub($1 FS,""); print $0}')
  label_gpu=$(apptainer inspect $file | awk '/GPU/ {sub($1 FS,""); print $0}')
  label_lab=$(apptainer inspect $file | awk '/Lab/ {sub($1 FS,""); print $0}')

  ## Create one launcher per entry in the 'Application' label
  for application in $label_application; do

    if [ $DEBUG == 'true' ]; then
      echo "Processing Container $container_name, Application $application"
    fi

    echo "$application" >> $TMP_DIR/application_list.txt

    ### Collect all categories for the container
    app_categories=""
    if [ -n "$label_categories" ]; then
      for category in $label_categories; do
        echo "$category" >> $TMP_DIR/category_list.txt
        echo "$category-$application" >> $TMP_DIR/category_app_list.txt
        app_categories="${app_categories};vibe-workflow-$category-$application"
      done
    fi

    if [ -n "$label_lab" ]; then
      for lab in $label_lab; do
        app_categories="${app_categories};vibe-lab-$lab-$application"
        echo "$lab" >> $TMP_DIR/lab_list.txt
        echo "$lab-$application" >> $TMP_DIR/lab_app_list.txt
      done
    fi

    if [ $default_label ] && [ $default_label == 'true' ]; then
      app_categories="${app_categories};vibe-default-$application"
      echo $application >> $TMP_DIR/default_list.txt
    fi

    ### Remove the first semicolon of the categories list
    if [[ ${app_categories:0:1} == ";" ]]; then
        app_categories="${app_categories:1}"
    fi

    ### Find and copy the icon file for the container
    ### Check if $application is a substring of the container name ($filename). This allows
    ### us to get the correct icon for additional applications inside the container.
    if [[ $filename == "$application"*  ]]; then
      ICONNAME=$(get_icon "$filename")
      if [ $DEBUG == 'true' ]; then
        echo "Got icon $ICONNAME"
      fi
    else
      ICONNAME=$(get_icon "$application")
    fi

    ### Create the .desktop entry
    ### The ICON path gets adjusted in the user_login_script.sh as it is unique for each user
    desktop_entry_name=
    desktop_entry_name="$application ($container_name) [VIBE]"
    echo -e "[Desktop Entry]\nName=$desktop_entry_name\nExec=$APPLICATION_LAUNCHER_SCRIPT $file $application\nIcon=#HOME#/$ICON_PATH/$ICONNAME\nTerminal=true\nType=Application\nCategories=${app_categories}" > $DEFAULTS_APPLICATION_DIR/vibe-"$application"_"$container_name".desktop

    if [ $DEBUG == 'true' ]; then
      echo "Container $container_name has Applications: $application and categories: $app_categories"
    fi

  done
done

# Create the menu structure for default applications, labs and workflows

# First, sort the lists and remove duplicates
if [ -f $TMP_DIR/default_list.txt ]; then
  SORTED_DEFAULT_APPLICATION_LIST=$(cat $TMP_DIR/default_list.txt | sort | uniq)
fi
if [ -f $TMP_DIR/lab_list.txt ]; then
  SORTED_LAB_LIST=$(cat $TMP_DIR/lab_list.txt | sort | uniq)
fi
if [ -f $TMP_DIR/lab_list.txt ]; then
  SORTED_LAB_APP_LIST=$(cat $TMP_DIR/lab_app_list.txt | sort | uniq)
fi
if [ -f $TMP_DIR/category_list.txt ]; then
  SORTED_CATEGORY_LIST=$(cat $TMP_DIR/category_list.txt | sort | uniq)
fi
if [ -f $TMP_DIR/category_app_list.txt ]; then
  SORTED_CATEGORY_APP_LIST=$(cat $TMP_DIR/category_app_list.txt | sort | uniq)
fi

if [ $DEBUG == 'true' ]; then
  # DEBUG
  echo ""
  echo "DEBUG: Parsed lists"

  echo "SORTED_DEFAULT_APPLICATION_LIST:"
  echo "$SORTED_DEFAULT_APPLICATION_LIST"
  echo ""
  echo "SORTED_LAB_LIST"
  echo "$SORTED_LAB_LIST"
  echo ""
  echo "SORTED_LAB_APP_LIST"
  echo "$SORTED_LAB_APP_LIST"
  echo ""
  echo "SORTED_CATEGORY_LIST"
  echo "$SORTED_CATEGORY_LIST"
  echo ""
  echo "SORTED_CATEGORY_APP_LIST"
  echo "$SORTED_CATEGORY_APP_LIST"
fi

# Remove old desktop files
rm -f $DEFAULTS_DIRECTORY_DIR/vibe-*.directory

ICONNAME=$(get_icon "vibe")

# Create the top 'VIBE' menu entry (static)
echo -e "[Desktop Entry]\nVersion=1.1\nType=Directory\nName=VIBE\nIcon=folder" > $DEFAULTS_DIRECTORY_DIR/vibe.directory

if [ $DEBUG == 'true' ]; then
  echo -e "\nCreating the menu file $DEFAULTS_MENU_FILE:"
fi

# Create the vibe.menu file
## [Header]
echo -e '<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n<!DOCTYPE Menu\n  PUBLIC '-//freedesktop//DTD Menu 1.0//EN'\n  'http://standards.freedesktop.org/menu-spec/menu-1.0.dtd'>' > $DEFAULTS_MENU_FILE
echo -e "<!-- Do not edit manually - generated and managed via the VIBE menu_builder.sh script -->\n<Menu>\n<Name>Applications</Name>" >> $DEFAULTS_MENU_FILE

## top static part of the menu structure
## [Applications -> VIBE] section
echo -e "<Menu>\n<Name>VIBE</Name>\n<Directory>vibe.directory</Directory>" >> $DEFAULTS_MENU_FILE
echo -e "<Include>\n<Category>vibe</Category>\n</Include>" >> $DEFAULTS_MENU_FILE

## VIBE Documentation
### Create the VIBE Documentation entry at top level
echo -e "[Desktop Entry]\nName=VIBE Documentation\nExec=$APPLICATION_LAUNCHER_SCRIPT $CONTAINER_IMAGE_FOLDER/firefox-base-latest.sif firefox $VIBE_DOCUMENTATION_URL\nIcon=#HOME#/$ICON_PATH/vibe_help.png\nTerminal=true\nType=Application\nCategories=vibe" > $DEFAULTS_APPLICATION_DIR/vibe-documentation.desktop

## Default applications
### Create the default application menu directory (static menu)
if [[ -n $SORTED_DEFAULT_APPLICATION_LIST ]]; then
  ICONNAME=$(get_icon "vibe-applications")
  echo -e "[Desktop Entry]\nVersion=1.1\nType=Directory\nName=VIBE Applications\nIcon=$icon" > $DEFAULTS_DIRECTORY_DIR/vibe-default.directory
fi

### [Applications -> VIBE -> VIBE Applications] section
echo -e "<Menu>\n<Name>VIBE Applications</Name>\n<Directory>vibe-default.directory</Directory>" >> $DEFAULTS_MENU_FILE

### individual entries for each application
for defaultentry in $SORTED_DEFAULT_APPLICATION_LIST; do
  if [ $DEBUG == 'true' ]; then
  echo "Processing default entry $defaultentry"
  fi

  ICONNAME=$(get_icon "$defaultentry")

  #### Create the sub menu directories for default applications from $TMP_DIR/default_list.txt
  echo -e "[Desktop Entry]\nVersion=1.1\nType=Directory\nName=$defaultentry\nIcon=#HOME#/$ICON_PATH/$ICONNAME" > $DEFAULTS_DIRECTORY_DIR/vibe-default-$defaultentry.directory

  #### Add sub menu entry to menu file.
  echo -e "<Menu>\n<Name>$defaultentry</Name>\n<Directory>vibe-default-$defaultentry.directory</Directory>\n<Include>\n<Category>vibe-default-$defaultentry</Category>\n</Include>\n</Menu>" >> $DEFAULTS_MENU_FILE
done

## end [Applications -> VIBE -> VIBE Applications] section
echo -e "</Menu>" >> $DEFAULTS_MENU_FILE

## Labs

### Create top lab menu directory (static)
if [[ -n $SORTED_LAB_LIST ]]; then
  ICONNAME=$(get_icon "vibe-labs")
  echo -e "[Desktop Entry]\nVersion=1.1\nType=Directory\nName=VIBE Labs\nIcon=#HOME#/$ICON_PATH/$ICONNAME" > $DEFAULTS_DIRECTORY_DIR/vibe-labs.directory
fi

### [Applications -> VIBE -> Labs] section
echo -e "<Menu>\n<Name>Labs</Name>\n<Directory>vibe-labs.directory</Directory>" >> $DEFAULTS_MENU_FILE

### individual entries for each lab
for labentry in $SORTED_LAB_LIST; do
  if [ $DEBUG == 'true' ]; then
  echo -e "\nProcessing lab entry $labentry with entries:\n$(echo "$SORTED_LAB_APP_LIST" | grep $labentry)"
  fi

  ICONNAME=$(get_icon "$labentry")

  #### Create lab menu directories from $TMP_DIR/lab_list.txt
  echo -e "[Desktop Entry]\nVersion=1.1\nType=Directory\nName=$labentry\nIcon=#HOME#/$ICON_PATH/$ICONNAME" > $DEFAULTS_DIRECTORY_DIR/vibe-lab-$labentry.directory

  #### Add sub menu entry to menu file.
  echo -e "<Menu>\n<Name>$labentry</Name>\n<Directory>vibe-lab-$labentry.directory</Directory>" >> $DEFAULTS_MENU_FILE

  #### [Applications -> VIBE -> Labs -> Application] sections
  for labapp in $SORTED_LAB_APP_LIST; do
    if [[ $labapp == "$labentry-"* ]]; then
      if [ $DEBUG == 'true' ]; then
        echo "Processing lab app entry $labapp"
      fi

      ##### Create sub menu directories for labs from $TMP_DIR/lab_app_list.txt
      labapp_name=$(echo $labapp | sed "s/$labentry-//")

      ICONNAME=$(get_icon "$labapp_name")

      echo -e "[Desktop Entry]\nVersion=1.1\nType=Directory\nName=$labapp_name\nIcon=#HOME#/$ICON_PATH/$ICONNAME" > $DEFAULTS_DIRECTORY_DIR/vibe-lab-$labapp.directory

      ##### Add the menu entry
      echo -e "<Menu>\n<Name>$labapp</Name>\n<Directory>vibe-lab-$labapp.directory</Directory>\n<Include>\n<Category>vibe-lab-$labapp</Category>\n</Include>\n</Menu>" >> $DEFAULTS_MENU_FILE
    fi
  done

  echo -e "</Menu>" >> $DEFAULTS_MENU_FILE

done

## end [Applications -> VIBE -> Labs] section
echo -e "</Menu>" >> $DEFAULTS_MENU_FILE

## Workflows

### Create top workflow menu directory (static)
if [[ -n $SORTED_CATEGORY_LIST ]]; then
  ICONNAME=$(get_icon "vibe-workflows")
  echo -e "[Desktop Entry]\nVersion=1.1\nType=Directory\nName=VIBE Workflows\nIcon=#HOME#/$ICON_PATH/$ICONNAME" > $DEFAULTS_DIRECTORY_DIR/vibe-workflow.directory
fi

### [Applications -> VIBE -> Workflows] section
echo -e "<Menu>\n<Name>Workflows</Name>\n<Directory>vibe-workflow.directory</Directory>" >> $DEFAULTS_MENU_FILE

### individual entries for each category / workflow
for catentry in $SORTED_CATEGORY_LIST; do
  if [ $DEBUG == 'true' ]; then
    echo -e "\nProcessing category entry $catentry with entries:\n$(echo "$SORTED_CATEGORY_APP_LIST" | grep $catentry)"
  fi

  ICONNAME=$(get_icon "$catentry")

  #### Create the category / workflow menu directories from $TMP_DIR/category_list.txt
  echo -e "[Desktop Entry]\nVersion=1.1\nType=Directory\nName=$catentry\nIcon=#HOME#/$ICON_PATH/$ICONNAME" > $DEFAULTS_DIRECTORY_DIR/vibe-workflow-$catentry.directory

  #### Add the menu entry
  echo -e "<Menu>\n<Name>$catentry</Name>\n<Directory>vibe-workflow-$catentry.directory</Directory>" >> $DEFAULTS_MENU_FILE

  #### [Applications -> VIBE -> Workflows -> Application] sections
  for categoryapp in $SORTED_CATEGORY_APP_LIST; do
    if [[ $categoryapp == "$catentry-"* ]]; then
      if [ $DEBUG == 'true' ]; then
        echo "Processing category app entry $categoryapp"
      fi

      ##### Create sub-category menu directories (workflows-$category-$application) from $TMP_DIR/category_app_list.txt
      capp_name=$(echo $categoryapp | sed "s/$catentry-//")

      ICONNAME=$(get_icon "$capp_name")

      echo -e "[Desktop Entry]\nVersion=1.1\nType=Directory\nName=$capp_name\nIcon=#HOME#/$ICON_PATH/$ICONNAME" > $DEFAULTS_DIRECTORY_DIR/vibe-workflow-$categoryapp.directory

      ##### Add the menu entry
      echo -e "<Menu>\n<Name>$categoryapp</Name>\n<Directory>vibe-workflow-$categoryapp.directory</Directory>\n<Include>\n<Category>vibe-workflow-$categoryapp</Category>\n</Include>\n</Menu>" >> $DEFAULTS_MENU_FILE
    fi
  done

  echo -e "</Menu>" >> $DEFAULTS_MENU_FILE

done

## end [Applications -> VIBE -> Workflows] section
echo -e "</Menu>" >> $DEFAULTS_MENU_FILE

## static end of the menu structure
## end [Applications -> VIBE]
echo -e "</Menu>\n</Menu>" >> $DEFAULTS_MENU_FILE

# Cleanup: Remove temp files
if [ $DEBUG == 'true' ]; then
  echo "Debug is enabled. Keeping temporary build directory: $TMP_DIR"
else
  rm -rf $TMP_DIR/
fi
