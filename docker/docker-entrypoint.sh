#!/bin/bash

# set -eo pipefail

# If command starts with an option (`-f` or `--some-option`), prepend main command
if [ "${1#-}" != "$1" ]; then
    set -- spigot "$@"
fi

# Logging functions
entrypoint_log() {
    local type="$1"
    shift
    printf '%s [%s] [Entrypoint]: %s\n' "$(date '+%Y-%m-%d %T %z')" "$type" "$*"
}
entrypoint_note() {
    entrypoint_log Note "$@"
}
entrypoint_warn() {
    entrypoint_log Warn "$@" >&2
}
entrypoint_error() {
    entrypoint_log ERROR "$@" >&2
    exit 1
}

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
#
# Will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
# "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature
# Read more: https://docs.docker.com/engine/swarm/secrets/
file_env() {
    local var="$1"
    local fileVar="${var}_FILE"
    local def="${2:-}"
    if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
        echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
        exit 1
    fi
    local val="$def"
    if [ "${!var:-}" ]; then
        val="${!var}"
    elif [ "${!fileVar:-}" ]; then
        val="$(<"${!fileVar}")"
    fi
    export "$var"="$val"
    unset "$fileVar"
}

# Prevents unwanted error messages to be diplayed to the console
#
# usage: disableErrorMesssages
disableErrorMesssages() {
    exec 3>&2
    exec 2>/dev/null
}

# Enables regular error messages
#
# usage: enableErrorMessages
enableErrorMessages() {
    exec 2>&3
}

# Gets the settings value inside a .properties file containing key=value elements.
#
# usage: getProperties <filename> <key>
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
# usage: setProperties <filename> <key> <value>
setProperties() {
    disableErrorMesssages

    # Create the file if it doesn't exist yet
    if [ ! -f "$1" ]; then
        touch "$1"
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
# usage: updateProperties <filename> <key> <value>
updateProperties() {
    if [ "$(getProperties "$1" "$2")" != "$3" ]; then
        setProperties "$1" "$2" "$3"
        local _result=$?
        if [ "$_result" -eq 0 ]; then
            entrypoint_note "[ OK ] Set '$2' to '$3' inside '$1'"
        elif [ "$_result" -eq 1 ]; then
            entrypoint_error "[FAIL] Set '$2' to '$3' inside '$1'"
        fi
    else
        entrypoint_note "[SKIP] Set '$2' to '$3' inside '$1'"
    fi
}

# Reads the contents of a .yml file and finds the key's value
# https://stackoverflow.com/questions/29969527/linux-shell-get-value-of-a-field-from-a-yml-file/29971515
#
# usage: getYaml <filename> <key>
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
# usage: setYaml <filename> <key> <value>
setYaml() {
    disableErrorMesssages

    # Create the file if it doesn't exist yet
    if [ ! -f "$1" ]; then
        touch "$1"
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
# usage: updateYaml <filename> <key> <value>
updateYaml() {
    if [ "$(getYaml "$1" "$2")" != "$3" ]; then
        setYaml "$1" "$2" "$3"
        local _result=$?
        if [ "$_result" -eq 0 ]; then
            entrypoint_note "[ OK ] Set '$2' to '$3' inside '$1'"
        elif [ "$_result" -eq 1 ]; then
            entrypoint_error "[FAIL] Set '$2' to '$3' inside '$1'"
        fi
    else
        entrypoint_note "[SKIP] Set '$2' to '$3' inside '$1'"
    fi
}

# Setup java
if [ "$1" = 'spigot' ]; then
    entrypoint_note 'Entrypoint script for Spigot started'

    # ----------------------------------------

    entrypoint_note 'Load various environment variables'
    envs=(
        JAVA_MEMORY
        JAVA_BASE_MEMORY
        JAVA_MAX_MEMORY
        JAVA_OPTIONS
        EULA
        BUNGEECORD
    )

    # Set empty environment variable or get content from "/run/secrets/<something>"
    for e in "${envs[@]}"; do
        file_env "$e"
    done

    # Set default environment variable values
    : "${JAVA_MEMORY:=512M}"
    : "${JAVA_BASE_MEMORY:=${JAVA_MEMORY}}"
    : "${JAVA_MAX_MEMORY:=${JAVA_MEMORY}}"
    : "${JAVA_OPTIONS:=}"
    : "${EULA:=false}"
    : "${BUNGEECORD:=false}"

    # ----------------------------------------

    # Create file if it doesn't exist yet
    if [ ! -f eula.txt ]; then
        entrypoint_note 'Creating EULA'
        touch eula.txt
    fi
    # Add file contents, if empty
    if [ ! -s eula.txt ]; then
        entrypoint_note 'Creating default EULA content'
        {
            echo '#By changing the setting below to TRUE you are indicating your agreement to our EULA (https://account.mojang.com/documents/minecraft_eula).'
            echo "#$(date)"
            echo 'eula=false'
        } >>eula.txt
    fi

    entrypoint_note 'Create/Update EULA ...'
    if [ "$EULA" != 'true' ]; then
        EULA=false
    fi
    updateProperties eula.txt eula "$EULA"

    # If EULA not accepted just stop
    if [ "$(getProperties eula.txt eula)" != 'true' ]; then
        entrypoint_error 'You need to agree to the EULA in order to run the server. Go to eula.txt for more info. Either set '\''eula=true'\'' in '\''eula.txt'\'' or run with '\''-e EULA=true'\'''
    fi

    entrypoint_note 'Set IP to be 0.0.0.0 (required for Docker)'
    updateProperties server.properties server-ip 0.0.0.0

    # Checks if BungeeCord has to access this server
    if [ "$BUNGEECORD" != 'true' ]; then
        BUNGEECORD=false
    fi
    if [ "$BUNGEECORD" = 'true' ]; then
        entrypoint_note 'Setting parameters, so that BungeeCord can access...'
        updateProperties server.properties online-mode false
        updateYaml bukkit.yml settings.\"connection-throttle\" -1
        updateYaml spigot.yml settings.bungeecord true
    fi

    # ----------------------------------------

    # Set variables for java runtime
    entrypoint_note "Setting initial memory to ${JAVA_BASE_MEMORY} and max to ${JAVA_MAX_MEMORY}"
    JAVA_OPTIONS="-Xms${JAVA_BASE_MEMORY} -Xmx${JAVA_MAX_MEMORY} ${JAVA_OPTIONS}"

    # Clear console buffers
    true >/tmp/input.buffer

    # Start the main application
    entrypoint_note "Starting Minecraft server"
    # shellcheck disable=SC2086
    tail -f /tmp/input.buffer | tee /dev/console | java $JAVA_OPTIONS -jar /opt/spigot.jar "$@" &
    interactive-console

    exit
fi

exec "$@"
