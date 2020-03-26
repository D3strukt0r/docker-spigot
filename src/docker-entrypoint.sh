#!/bin/bash

echo "Starting entrypoint..."

# Gets the settings value inside a .properties file containing key=value elements.
# Authors: adorogensky <https://gist.github.com/marcelbirkner/9b133f800d7d3fc5d828#gistcomment-2855532>
#
# getProperties <filename> <key>
getProperties() {
    exec 3>&2
    exec 2>/dev/null

    local _result
    property=$(sed -n "/^[ tab]*$2[ tab]*/p" "$1")
    if [[ $property =~ ^([ tab]*"$2"[ tab]*=)(.*) ]]; then
        _result=${BASH_REMATCH[2]}
    fi
    echo "$_result"

    exec 2>&3
}

# Changes the settings in a .properties file containing key=value elements.
#
# setProperties <filename> <key> <value>
setProperties() {
    exec 3>&2
    exec 2>/dev/null

    grep -q "^$2\s*\=" "$1"

    if [ $? -ne 0 ]; then
        # Add new line
        echo "$2=$3" >>"$1"
    else
        # Overwrite a line
        sed -i "/^$2\s*=/ c $2=$3" "$1"
    fi

    if [ $? -eq 0 ]; then
        echo "0" # OK
    else
        echo "1" # FAIL
    fi

    exec 2>&3
}

# Reads the contents of a .yml file and finds the key's value
# https://stackoverflow.com/questions/29969527/linux-shell-get-value-of-a-field-from-a-yml-file/29971515
#
# getYaml <filename> <key>
getYaml() {
    exec 3>&2
    exec 2>/dev/null

    local _result
    _result=$(shyaml get-value "$2" < "$1")
    echo "$_result"

    exec 2>&3
}

# Add function to change YAML configs
# https://github.com/Gallore/yaml_cli
# https://unix.stackexchange.com/questions/338781/is-it-possible-to-modify-a-yml-file-via-shell-script
#
# setYaml <filename> <processes...>
setYaml() {
    exec 3>&2
    exec 2>/dev/null

    yaml_cli -f "$1" "${@:2}"

    if [ $? -eq 0 ]; then
        echo "0" # OK
    else
        echo "1" # FAIL
    fi

    exec 2>&3
}

# Creates the eula.txt file with the default contents
createEula() {
    if [ ! -s "eula.txt" ]; then
        exec 3>&2
        exec 2>/dev/null
        {
            echo "#By changing the setting below to TRUE you are indicating your agreement to our EULA (https://account.mojang.com/documents/minecraft_eula)."
            echo "#$(date)"
            echo "eula=false"
        } >>eula.txt

        if [ $? -eq 0 ]; then
            echo "0" # OK
        else
            echo "1" # FAIL
        fi

        exec 2>&3
    else
        echo "2" # SKIP
    fi
}

# Create eula.txt if it does not exist
echo "[    ] Creating EULA..."
_result=$(createEula)
if [ "$_result" -eq 0 ]; then
    echo -e "\e[1A[ \e[32mOK\e[39m ]"
elif [ "$_result" -eq 1 ]; then
    echo -e "\e[1A[\e[31mFAIL\e[39m]"
    exit 1
else
    echo -e "\e[1A[\e[33mSKIP\e[39m]"
fi

# Set EULA parameter
if [ "$EULA" != "true" ]; then
    EULA="false"
fi
echo "[    ] Setting EULA to '$EULA'..."
if [ "$(getProperties eula.txt eula)" != "$EULA" ]; then
    _result=$(setProperties eula.txt "eula" "$EULA")
    if [ "$_result" -eq 0 ]; then
        echo -e "\e[1A[ \e[32mOK\e[39m ]"
    elif [ "$_result" -eq 1 ]; then
        echo -e "\e[1A[\e[31mFAIL\e[39m]"
        exit 1
    fi
else
    echo -e "\e[1A[\e[33mSKIP\e[39m]"
fi

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
echo "[    ] Setting 'server-ip' to '0.0.0.0' inside 'server.properties'..."
if [ "$(getProperties server.properties server-ip)" != "0.0.0.0" ]; then
    _result=$(setProperties server.properties server-ip 0.0.0.0)
    if [ "$_result" -eq 0 ]; then
        echo -e "\e[1A[ \e[32mOK\e[39m ]"
    elif [ "$_result" -eq 1 ]; then
        echo -e "\e[1A[\e[31mFAIL\e[39m]"
        exit 1
    fi
else
    echo -e "\e[1A[\e[33mSKIP\e[39m]"
fi

# Checks if BungeeCord has to access this server
if [ "$BUNGEECORD" != "true" ]; then
    BUNGEECORD="false"
fi
echo "[    ] Setting parameters, so that BungeeCord can access..."
echo "[    ] Setting 'online-mode' to 'false' inside 'server.properties'..."
if [ "$(getProperties server.properties online-mode)" != "false" ]; then
    _result=$(setProperties server.properties online-mode false)
    if [ "$_result" -eq 0 ]; then
        echo -e "\e[1A[ \e[32mOK\e[39m ]"
    elif [ "$_result" -eq 1 ]; then
        echo -e "\e[1A[\e[31mFAIL\e[39m]"
        exit 1
    fi
else
    echo -e "\e[1A[\e[33mSKIP\e[39m]"
fi
echo "[    ] Setting 'settings.connection-throttle' to '-1' inside 'bukkit.yml'..."
if [ "$(getYaml bukkit.yml settings.connection-throttle)" != "-1" ]; then
    _result=$(setYaml bukkit.yml -n settings:connection-throttle -1)
    if [ "$_result" -eq 0 ]; then
        echo -e "\e[1A[ \e[32mOK\e[39m ]"
    elif [ "$_result" -eq 1 ]; then
        echo -e "\e[1A[\e[31mFAIL\e[39m]"
        exit 1
    fi
else
    echo -e "\e[1A[\e[33mSKIP\e[39m]"
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
echo "[    ] Starting Minecraft server..."
tail -f $_console_input | tee /dev/console | $(which java) $JAVA_OPTIONS -jar /app/spigot.jar --nogui "$@"
