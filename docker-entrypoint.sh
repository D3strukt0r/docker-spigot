#!/bin/bash

if [ "$EULA" == "true" ] && [ ! -s eula.txt ]; then
    echo -e "#By changing the setting below to TRUE you are indicating your agreement to our EULA (https://account.mojang.com/documents/minecraft_eula).\n#$(date)\neula=true" > eula.txt
fi

java -Xms"${JAVA_BASE_MEMORY}" -Xmx"${JAVA_MAX_MEMORY}" -jar /app/spigot.jar --no-gui
