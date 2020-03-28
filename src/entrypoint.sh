#!/bin/bash

# Prevents unwanted error messages to be diplayed to the console
#
# disableErrorMesssages
disableErrorMesssages() {
    exec 3>&2
    exec 2>/dev/null
}

# Enables regular error messages
#
# enableErrorMessages
enableErrorMessages() {
    exec 2>&3
}

# Creates a file
#
# createFile <file_location>
createFile() {
    disableErrorMesssages
    touch "$1"

    # Fixes file not found
    # TODO: Find a better (more efficient) solution
    sleep 0.5

    enableErrorMessages
}

# Gets the settings value inside a .properties file containing key=value elements.
#
# getProperties <filename> <key>
getProperties() {
    disableErrorMesssages
    if [ -s "$1" ]; then
        # https://gist.github.com/marcelbirkner/9b133f800d7d3fc5d828#gistcomment-2855532
        property=$(sed -n "/^[ tab]*$2[ tab]*/p" "$1")
        if [[ $property =~ ^([ tab]*"$2"[ tab]*=)(.*) ]]; then
            echo "${BASH_REMATCH[2]}"
        fi
    fi
    enableErrorMessages
}

# Changes the settings in a .properties file containing key=value elements.
#
# setProperties <filename> <key> <value>
setProperties() {
    disableErrorMesssages

    # Create the file if it doesn't exist yet
    if [ ! -f "$1" ]; then
        createFile "$1"
    fi

    # Check if the key exists
    grep -q "^$2\s*\=" "$1"

    if [ $? -ne 0 ]; then
        # If it doesn't exist, add new line
        echo "$2=$3" >>"$1"
    else
        # Otherwise, overwrite the line
        sed -i "/^$2\s*=/ c $2=$3" "$1"
    fi

    # Return state
    if [ $? -eq 0 ]; then
        return 0 # OK
    else
        return 1 # FAIL
    fi
    enableErrorMessages
}

# Basically like setProperties, but checks if it is necessary to change something.
#
# updateProperties <filename> <key> <value>
updateProperties() {
    echo "[    ] Setting '$2' to '$3' inside '$1'..."
    if [ "$(getProperties "$1" "$2")" != "$3" ]; then
        setProperties "$1" "$2" "$3"
        local _result=$?
        if [ "$_result" -eq 0 ]; then
            echo -e "\e[1A[ \e[32mOK\e[39m ]"
        elif [ "$_result" -eq 1 ]; then
            echo -e "\e[1A[\e[31mFAIL\e[39m]"
            exit 1
        fi
    else
        echo -e "\e[1A[\e[33mSKIP\e[39m]"
    fi
}

# Reads the contents of a .yml file and finds the key's value
# https://stackoverflow.com/questions/29969527/linux-shell-get-value-of-a-field-from-a-yml-file/29971515
#
# getYaml <filename> <key>
getYaml() {
    disableErrorMesssages
    if [ -s "$1" ]; then
        echo "$(yq ."$2" "$1")"
    fi
    enableErrorMessages
}

# Add function to change YAML configs
# https://github.com/Gallore/yaml_cli
# https://unix.stackexchange.com/questions/338781/is-it-possible-to-modify-a-yml-file-via-shell-script
#
# setYaml <filename> <key> <value>
setYaml() {
    disableErrorMesssages

    # Create the file if it doesn't exist yet
    if [ ! -f "$1" ]; then
        createFile "$1"
    fi

    if [ ! -s "$1" ]; then
        # Fixes "Error: argument of type 'NoneType' is not iterable"
        echo "help-the-parser: null" >"$1"
    fi

    # Use "yaml_cli" to add the key if it doesn't exist yet, otherwise use "yq" to overwrite
    if [ "$(getYaml "$1" "$2")" == "" ]; then
        local _new_key="${2//[.]/:}"
        _new_key="${_new_key//\"/}"

        # https://stackoverflow.com/questions/806906/how-do-i-test-if-a-variable-is-a-number-in-bash
        if [[ $3 =~ ^[+-]?[0-9]+([.][0-9]+)?$ ]]; then
            yaml_cli -f "$1" -n "$_new_key" "$3"
        elif [[ $3 =~ ^(true|false)$ ]]; then
            yaml_cli -f "$1" -b "$_new_key" "$3"
        else
            yaml_cli -f "$1" -s "$_new_key" "$3"
        fi

    else
        yq -yi ."$2=$3" "$1"
    fi

    # Return state
    if [ $? -eq 0 ]; then
        return 0 # OK
    else
        return 1 # FAIL
    fi
    enableErrorMessages
}

# Basically like setYaml, but checks if it is necessary to change something.
#
# updateYaml <filename> <key> <value>
updateYaml() {
    echo "[    ] Setting '$2' to '$3' inside '$1'..."
    if [ "$(getYaml "$1" "$2")" != "$3" ]; then
        setYaml "$1" "$2" "$3"
        local _result=$?
        if [ "$_result" -eq 0 ]; then
            echo -e "\e[1A[ \e[32mOK\e[39m ]"
        elif [ "$_result" -eq 1 ]; then
            echo -e "\e[1A[\e[31mFAIL\e[39m]"
            exit 1
        fi
    else
        echo -e "\e[1A[\e[33mSKIP\e[39m]"
    fi
}

# Create file if it doesn't exist yet
echo "[    ] Creating EULA..."
if [ ! -f eula.txt ]; then
    createFile eula.txt
fi
# Add file contents, if empty
if [ ! -s eula.txt ]; then
    {
        echo "#By changing the setting below to TRUE you are indicating your agreement to our EULA (https://account.mojang.com/documents/minecraft_eula)."
        echo "#$(date)"
        echo "eula=false"
    } >>eula.txt

    if [ $? -eq 0 ]; then
        echo -e "\e[1A[ \e[32mOK\e[39m ]"
    else
        echo -e "\e[1A[\e[31mFAIL\e[39m]"
        exit 1
    fi
else
    echo -e "\e[1A[\e[33mSKIP\e[39m]"
fi

# Set EULA parameter
if [ "$EULA" != "true" ]; then
    EULA="false"
fi
updateProperties eula.txt eula "$EULA"

# If EULA not accepted just stop
echo "[    ] Checking if EULA accepted..."
if [ "$(getProperties eula.txt eula)" != "true" ]; then
    echo -e "\e[1A[\e[31mFAIL\e[39m]"
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
    echo "You need to agree to the EULA in order to run the server. Go to eula.txt for more info."
    echo "Either set 'eula=true' in 'eula.txt' or run with '-e EULA=true'"
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' =
    exit 1
else
    echo -e "\e[1A[ \e[32mOK\e[39m ]"
fi

# IP has to be set to 0.0.0.0 or empty
updateProperties server.properties server-ip 0.0.0.0

# Checks if BungeeCord has to access this server
if [ "$BUNGEECORD" != "true" ]; then
    BUNGEECORD="false"
fi
if [ "$BUNGEECORD" == "true" ]; then
    echo "[....] Setting parameters, so that BungeeCord can access..."
    updateProperties server.properties online-mode false
    updateYaml bukkit.yml settings.\"connection-throttle\" -1
fi

# Set variables for java runtime
echo "[    ] Setting initial memory to ${JAVA_BASE_MEMORY:=${JAVA_MEMORY:=512M}} and max to ${JAVA_MAX_MEMORY:=${JAVA_MEMORY}}"
JAVA_OPTIONS="-Xms${JAVA_BASE_MEMORY} -Xmx${JAVA_MAX_MEMORY} ${JAVA_OPTIONS}"
echo -e "\e[1A[ \e[32mOK\e[39m ]"

# Console buffers
_console_input="/app/input.buffer"
# Clear console buffers
true >$_console_input

# Start the main application
echo "[....] Starting Minecraft server..."
tail -f $_console_input | tee /dev/console | $(which java) $JAVA_OPTIONS -jar /app/spigot.jar --nogui "$@"
