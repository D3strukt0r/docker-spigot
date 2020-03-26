.. role:: bash(code)
   :language: bash

==========================
Creating your first server
==========================

Starting the server
==========================

.. code-block:: bash

   docker run \
      --rm \
      -d \
      -p 25565:25565 \
      -v $(pwd)/data:/data \
      -e JAVA_MAX_MEMORY=1G \
      -e EULA=true \
      --name spigot_1 \
      d3strukt0r/spigot

--rm
--------------------------
Removes the container after it has been shut down. This means we can reuse the name later on.

-d
--------------------------
Start detached. Or leave out to watch the logs. You can then leave using :code:`CTRL` + :code:`D`

-i -t (WORK IN PROGRESS)
--------------------------
This will let you work with the console inside your container. However, this will not let you
leave but not re-enter the console, without shutting down the server. Later on, you'll learn a
workaround for this. To leave from the terminal, and let it run in the background click
:code:`CTRL + P + Q` (lift from :code:`P` and click :code:`Q` while still holding :code:`CTRL`)

-p 25565:25565
--------------------------
This opens the internal port (inside the container) to the outer worlds. You can open as many
ports for e. g. Votifier, RCON, etc. This would maybe look like
:bash:`-p 25565:25565 -p 8192:8192`.

-v $(pwd)/\data:/data
--------------------------
If you want to save your server somewhere, you need to link the directory inside your container
to your host. Before the colon goes the place on your host. After the colon goes the directory
inside the container, which is always :code:`/data`.

-e JAVA_MAX_MEMORY=1G
--------------------------
Not required but is suggested by Minecraft console. For the required amount of RAM you will need,
please consider Googling.

-e EULA=true
--------------------------
Minecraft required you to manually accept the EULA, do this by simply adding this environment
variable.

--name spigot
--------------------------
Give the container a name, for easier referencing later on.

d3strukt0r/spigot
--------------------------
This is the repository where the container is maintained. You can also specify what version you
want to use. e. g. :bash:`d3strukt0r/spigot:latest` or :bash:`d3strukt0r/spigot:1.8.8`. For all
versions check the `Tags on Docker Hub`_.

.. _`Tags on Docker Hub`: https://hub.docker.com/repository/docker/d3strukt0r/spigot/tags?page=1

Reading logs
==========================

.. code-block:: bash

   docker logs -f spigot_1

-f
--------------------------
The f stands for follow. Which basically means, don't just output the logs until now, but keep
reading, until we exit with :code:`CTRL` + :code:`D`. This will not close the server, you'll just
leave the logs.

Sending commands
==========================

.. code-block:: bash

   docker exec spigot_1 console "<command>"

Replace :code:`<command>` with the command you need. This is what you would also usually enter
inside your regular console, like e. g. :code:`op D3strukt0r`.

Stopping the server
==========================

.. code-block:: bash

   docker stop spigot_1
