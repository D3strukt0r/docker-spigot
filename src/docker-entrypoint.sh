#!/bin/bash

# Accept EULA if necessary
echo "[    ] Accept Mojang's EULA"
if [ "$EULA" == "true" ] && [ ! -s eula.txt ]; then
    echo -e "#By changing the setting below to TRUE you are indicating your agreement to our EULA (https://account.mojang.com/documents/minecraft_eula).\n#$(date)\neula=true" > eula.txt
    if [ $? -eq 0 ]; then
        echo -e "\e[1A[ \e[32mOK\e[39m ]"
    else
        echo -e "\e[1A[\e[31mFAIL\e[39m]"
    fi
else
    echo -e "\e[1A[\e[33mSKIP\e[39m]"
fi

# Set variables for java runtime
echo "[    ] Setting initial memory to ${JAVA_BASE_MEMORY:=${JAVA_MEMORY:=512M}} and max to ${JAVA_MAX_MEMORY:=${JAVA_MEMORY}}"
JAVA_OPTIONS="-Xms${JAVA_BASE_MEMORY} -Xmx${JAVA_MAX_MEMORY} ${JAVA_OPTIONS}"
echo -e "\e[1A[ \e[32mOK\e[39m ]"

# Console buffers
console_input="/app/input.buffer"
# Clear console buffers
> $console_input

# Start the main application
tail -f $console_input | tee /dev/console | java $JAVA_OPTIONS -jar /app/spigot.jar --nogui "$@"
