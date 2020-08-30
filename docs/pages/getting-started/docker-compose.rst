==========================
Using Docker Compose
==========================

Configuring
==========================

Create a file called :code:`docker-compose.yml` under e. g. :code:`/opt/mc-server` and add:

.. code-block:: yaml

    version: '2'

    services:
      spigot_1:
        image: d3strukt0r/spigot
        ports:
          - 25565:25565
        volumes:
          - ./data:/data
        environment:
          - JAVA_MAX_MEMORY=1G
          - EULA=true

Starting the server
==========================

.. code-block:: bash

    docker-compose up -d

Reading the logs
==========================

.. code-block:: bash

   docker-compose logs -f

Sending commands
==========================

.. code-block:: bash

    docker-compose exec spigot_1 console "<command>"

Stopping the server
==========================

.. code-block:: bash

   docker-compose down
