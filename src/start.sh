#!/bin/bash

# Verify versions
echo "[    ] Check if Java is available..."
if java -version 2>&1 >/dev/null | grep -q "openjdk version" ; then
    echo -e "\e[1A[ \e[32mOK\e[39m ]"
elif java -version 2>&1 >/dev/null | grep -q "java version"; then
    echo -e "\e[1A[ \e[32mOK\e[39m ]"
else
    echo -e "\e[1A[\e[31mFAIL\e[39m]" >&2
    exit 2
fi
java -version

# Array for known Spigot versions having a different name
declare -A spigot_versions
spigot_versions=(
    [latest]="1.14.3"
    [1.10.2]="1.10.2-R0.1-SNAPSHOT-latest"
    [1.10]="1.10-R0.1-SNAPSHOT-latest"
    [1.9.4]="1.9.4-R0.1-SNAPSHOT-latest"
    [1.9.2]="1.9.2-R0.1-SNAPSHOT-latest"
    [1.9]="1.9-R0.1-SNAPSHOT-latest"
    [1.8.8]="1.8.8-R0.1-SNAPSHOT-latest"
    [1.8.7]="1.8.7-R0.1-SNAPSHOT-latest"
    [1.8.6]="1.8.6-R0.1-SNAPSHOT-latest"
    [1.8.5]="1.8.5-R0.1-SNAPSHOT-latest"
    [1.8.4]="1.8.4-R0.1-SNAPSHOT-latest"
    [1.8.3]="1.8.3-R0.1-SNAPSHOT-latest"
    [1.8]="1.8-R0.1-SNAPSHOT-latest"
    [1.7.10]="1.7.10-SNAPSHOT-b1657"
    [1.7.9]="1.7.9-R0.2-SNAPSHOT"
    [1.7.8]="1.7.8-R0.1-SNAPSHOT"
    [1.7.5]="1.7.5-R0.1-SNAPSHOT-1387"
    [1.7.2]="1.7.2-R0.4-SNAPSHOT-1339"
    [1.6.4]="1.6.4-R2.1-SNAPSHOT"
    [1.6.2]="1.6.2-R1.1-SNAPSHOT"
    [1.5.2]="1.5.2-R1.1-SNAPSHOT"
    [1.5.1]="1.5.1-R0.1-SNAPSHOT"
    [1.4.7]="1.4.7-R1.1-SNAPSHOT"
    [1.4.6]="1.4.6-R0.4-SNAPSHOT"
)

# Download specified Spigot version if file doesn't already exist
SPIGOT_LOCATION=spigot.jar
if [[ ! -e $SPIGOT_LOCATION ]]; then
    # getbukkit.org uses different names with older versions. Get the proper one.
    SPIGOT_BASE_URL=${SPIGOT_BASE_URL:=https://cdn.getbukkit.org/spigot/spigot-}
    SPIGOT_VERSION=${SPIGOT_VERSION:=latest}
    # Check if the default domain hasn't been changed
    if [[ $SPIGOT_BASE_URL == *"getbukkit.org"* ]]; then
        # Check whether the given version is in the known naming scheme
        if [[ -v spigot_versions[$SPIGOT_VERSION] ]]; then
            SPIGOT_VERSION=${spigot_versions[$SPIGOT_VERSION]}
        fi
    fi

    echo "[    ] Downloading ${SPIGOT_URL:=${SPIGOT_BASE_URL}${SPIGOT_VERSION}${SPIGOT_FILE_URL:=.jar}}"
    if ! curl -o $SPIGOT_LOCATION -fL $SPIGOT_URL; then
        echo -e "\e[1A\e[1A\e[1A\e[1A[\e[31mFAIL\e[39m]\n\n\n" >&2
        exit 2
    else
        echo -e "\e[1A\e[1A\e[1A\e[1A[ \e[32mOK\e[39m ]\n\n\n"
    fi
fi

# Link logs folder
echo "[    ] Linking /data/logs/ from the volume"
mkdir -p /data/logs
ln -s /data/logs .
if [ $? -eq 0 ]; then
    echo -e "\e[1A[ \e[32mOK\e[39m ]"
else
    echo -e "\e[1A[\e[31mFAIL\e[39m]"
fi

# Link plugins folder
echo "[    ] Linking /data/plugins/ from the volume"
mkdir -p /data/plugins
ln -s /data/plugins .
if [ $? -eq 0 ]; then
    echo -e "\e[1A[ \e[32mOK\e[39m ]"
else
    echo -e "\e[1A[\e[31mFAIL\e[39m]"
fi

# Link all words
for dir in /data/*/ ; do
    if [ -f $dir/level.dat ]; then
        echo "[    ] Linking $dir from the volume"
        ln -s $dir .
        if [ $? -eq 0 ]; then
            echo -e "\e[1A[ \e[32mOK\e[39m ]"
        else
            echo -e "\e[1A[\e[31mFAIL\e[39m]"
        fi
    fi
done

# Link banned-ips.json
echo "[    ] Linking banned-ips.json from the volume"
touch /data/banned-ips.json
if [ ! -s /data/banned-ips.json ]; then
    echo "[]" > /data/banned-ips.json
fi
ln -s /data/banned-ips.json .
if [ $? -eq 0 ]; then
    echo -e "\e[1A[ \e[32mOK\e[39m ]"
else
    echo -e "\e[1A[\e[31mFAIL\e[39m]"
fi

# Link banned-players.json
echo "[    ] Linking banned-players.json from the volume"
touch /data/banned-players.json
if [ ! -s /data/banned-players.json ]; then
    echo "[]" > /data/banned-players.json
fi
ln -s /data/banned-players.json .
if [ $? -eq 0 ]; then
    echo -e "\e[1A[ \e[32mOK\e[39m ]"
else
    echo -e "\e[1A[\e[31mFAIL\e[39m]"
fi

# Link bukkit.yml
echo "[    ] Linking bukkit.yml from the volume"
touch /data/bukkit.yml
ln -s /data/bukkit.yml .
if [ $? -eq 0 ]; then
    echo -e "\e[1A[ \e[32mOK\e[39m ]"
else
    echo -e "\e[1A[\e[31mFAIL\e[39m]"
fi

# Link commands.yml
echo "[    ] Linking commands.yml from the volume"
touch /data/commands.yml
ln -s /data/commands.yml .
if [ $? -eq 0 ]; then
    echo -e "\e[1A[ \e[32mOK\e[39m ]"
else
    echo -e "\e[1A[\e[31mFAIL\e[39m]"
fi

# Link eula.txt
echo "[    ] Linking eula.txt from the volume"
touch /data/eula.txt
if [ ! -s /data/eula.txt ]; then
    echo "#By changing the setting below to TRUE you are indicating your agreement to our EULA (https://account.mojang.com/documents/minecraft_eula).
#$(date)
eula=false" > /data/eula.txt
fi
ln -s /data/eula.txt .
if [ $? -eq 0 ]; then
    echo -e "\e[1A[ \e[32mOK\e[39m ]"
else
    echo -e "\e[1A[\e[31mFAIL\e[39m]"
fi

# Link help.yml
echo "[    ] Linking help.yml from the volume"
touch /data/help.yml
ln -s /data/help.yml .
if [ $? -eq 0 ]; then
    echo -e "\e[1A[ \e[32mOK\e[39m ]"
else
    echo -e "\e[1A[\e[31mFAIL\e[39m]"
fi

# Link ops.json
echo "[    ] Linking ops.json from the volume"
touch /data/ops.json
if [ ! -s /data/ops.json ]; then
    echo "[]" > /data/ops.json
fi
ln -s /data/ops.json .
if [ $? -eq 0 ]; then
    echo -e "\e[1A[ \e[32mOK\e[39m ]"
else
    echo -e "\e[1A[\e[31mFAIL\e[39m]"
fi

# Link permissions.yml
echo "[    ] Linking permissions.yml from the volume"
touch /data/permissions.yml
ln -s /data/permissions.yml .
if [ $? -eq 0 ]; then
    echo -e "\e[1A[ \e[32mOK\e[39m ]"
else
    echo -e "\e[1A[\e[31mFAIL\e[39m]"
fi

# Link server.properties
echo "[    ] Linking server.properties from the volume"
touch /data/server.properties
ln -s /data/server.properties .
if [ $? -eq 0 ]; then
    echo -e "\e[1A[ \e[32mOK\e[39m ]"
else
    echo -e "\e[1A[\e[31mFAIL\e[39m]"
fi

# Link server-icon.png
echo "[    ] Linking server-icon.png from the volume"
if [ -f /data/server-icon.png ]; then
    ln -s /data/server-icon.png .
    if [ $? -eq 0 ]; then
        echo -e "\e[1A[ \e[32mOK\e[39m ]"
    else
        echo -e "\e[1A[\e[31mFAIL\e[39m]"
    fi
else
    echo -e "\e[1A[\e[33mSKIP\e[39m]"
fi

# Link spigot.yml
echo "[    ] Linking spigot.yml from the volume"
touch /data/spigot.yml
ln -s /data/spigot.yml .
if [ $? -eq 0 ]; then
    echo -e "\e[1A[ \e[32mOK\e[39m ]"
else
    echo -e "\e[1A[\e[31mFAIL\e[39m]"
fi

# Link usercache.json
echo "[    ] Linking usercache.json from the volume"
touch /data/usercache.json
ln -s /data/usercache.json .
if [ $? -eq 0 ]; then
    echo -e "\e[1A[ \e[32mOK\e[39m ]"
else
    echo -e "\e[1A[\e[31mFAIL\e[39m]"
fi

# Link whitelist.json
echo "[    ] Linking whitelist.json from the volume"
touch /data/whitelist.json
if [ ! -s /data/whitelist.json ]; then
    echo "[]" > /data/whitelist.json
fi
ln -s /data/whitelist.json .
if [ $? -eq 0 ]; then
    echo -e "\e[1A[ \e[32mOK\e[39m ]"
else
    echo -e "\e[1A[\e[31mFAIL\e[39m]"
fi

# Set variables for java runtime
echo "[    ] Setting initial memory to ${JAVA_BASE_MEMORY:=${JAVA_MEMORY:=512M}} and max to ${JAVA_MAX_MEMORY:=${JAVA_MEMORY}}"
JAVA_OPTIONS="-Xms${JAVA_BASE_MEMORY} -Xmx${JAVA_MAX_MEMORY} ${JAVA_OPTIONS}"
echo -e "\e[1A[ \e[32mOK\e[39m ]"

java $JAVA_OPTIONS -jar spigot.jar "$@"

# Worlds that have been created should be moved to /data (TODO: Symlinks are not recognized "if [ ! -L "$dir" ]")
echo ""
for dir in */ ; do
    if [[ -d $dir && ! -L $dir && -f $dir/level.dat ]]; then
        echo "[    ] Move $dir to the volume"
        mv $dir /data/
        if [[ $? -eq 0 ]]; then
            echo -e "\e[1A[ \e[32mOK\e[39m ]"
        else
            echo -e "\e[1A\e[1A[\e[31mFAIL\e[39m]\n"
        fi
    fi
done
