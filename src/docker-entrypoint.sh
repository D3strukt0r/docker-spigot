#!/bin/bash

# Changes the settings in a .properties file containing key=value elements.
# setProperties <filename> <property> <value>
setProperties() {
    echo "[    ] Change '$2' to '$3' inside '$1'"

    grep -q "^$2\s*\=" $1

    if [ $? -ne 0 ] ; then
        echo "$2=$3" >> $1
    else
        sed -i "/^$2\s*=/ c $2=$3" $1
    fi

    if [ $? -eq 0 ]; then
        echo -e "\e[1A[ \e[32mOK\e[39m ]"
    else
        echo -e "\e[3A[\e[31mFAIL\e[39m]\e[2B"
    fi
}

# TODO: Add function to change YAML configs
# setYaml() {}

# Creates the eula.txt file with the default contents
createEula() {
    echo "[    ] Create eula.txt"
    if [ ! -s "eula.txt" ]; then

        echo -e "#By changing the setting below to TRUE you are indicating your agreement to our EULA (https://account.mojang.com/documents/minecraft_eula).\n#$(date)\neula=false" > eula.txt

        if [ $? -eq 0 ]; then
            echo -e "\e[1A[ \e[32mOK\e[39m ]"
        else
            echo -e "\e[2A[\e[31mFAIL\e[39m]\e[1B"
        fi
    else
        echo -e "\e[1A[\e[33mSKIP\e[39m]"
    fi
}

isEulaAccepted() {
    local OK=1
    grep eula eula.txt | grep -q 'true' && OK=0
    echo "$OK"
}

# Make sure EULA can only be "true" or "false"
if [ "$EULA" != "true" ]; then
    EULA="false"
fi

# Create eula.txt if it does not exist
createEula

# Set EULA to true if accepted
if [ "$EULA" == "true" ]; then
    setProperties eula.txt "eula" "true"
fi

# If EULA not accepted just stop
echo "[    ] Checking if EULA was accepted"
if [ $(isEulaAccepted) -eq 1 ]; then
    echo -e "\e[2A[\e[31mFAIL\e[39m]\e[1B"
    echo "======================================================================================="
    echo "You need to agree to the EULA in order to run the server. Go to eula.txt for more info."
	echo "Either set 'eula=true' in 'eula.txt'"
	echo "or run with '-e EULA=true'"
    echo "======================================================================================="
	exit 1
else
    echo -e "\e[1A[ \e[32mOK\e[39m ]"
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
tail -f $_console_input | tee /dev/console | java $JAVA_OPTIONS -jar /app/spigot.jar --nogui "$@"
