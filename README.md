# docker-spigot
Use the Minecraft Spigot server as a Docker container

![Docker Stars](https://img.shields.io/docker/stars/d3strukt0r/spigot.svg)
![Docker Pulls](https://img.shields.io/docker/pulls/d3strukt0r/spigot.svg)

## Getting Started

These instructions will cover usage information and for the docker container

### Prerequisities

In order to run this container you'll need docker installed.

*   [Windows](https://docs.docker.com/windows/started)
*   [OS X](https://docs.docker.com/mac/started/)
*   [Linux](https://docs.docker.com/linux/started/)

### Usage

#### Container Parameters

To start the server use the command given below. To be able to type commands directly in your terminal `-i -t` or `-it`. To detach from the terminal use `Ctrl + P + Q`. To start it detached from the beginning use `-d`

Spigot uses `25565` as a default port, however, if you use BungeeCord or a similar app, change the port to something else (`-p 25566:25565`).

It is not necessary to add any volumes, but if you do add it (`-v <host_dir>:/data`), your data will be saved. If you don't add it, it is impossible to change any config file, or add plugins.

```shell
docker run -i -t -p 25565:25565 -v D:\spigot_data:/data d3strukt0r/spigot
```

In addition, use the environment variables from the next paragraphs to your desire with e. g. `-e JAVA_MEMORY=1G`.

**Important**

When configuring the server you **HAVE TO** use following option in your `server.properties` file
```properties
server-ip=0.0.0.0
server-port=25565
```

**Hint**

If you need to add another port to your docker container, use `--expose` in your command.

#### Environment Variables

*   `SPIGOT_BASE_URL` - (Default: [https://cdn.getbukkit.org/spigot/spigot-]())

    The base URL from where to get the file

*   `SPIGOT_VERSION` - (Default: `latest`)

    The build version to download (the default is set to take the last one)

*   `SPIGOT_FILE_URL` - (Default: `.jar`)

    The end part of the URL

*   `SPIGOT_URL` - (Default: `${BUNGEECORD_BASE_URL}${BUNGEECORD_VERSION}${BUNGEECORD_FILE_URL}`)

    Can be set to something completely custom

*   `JAVA_MEMORY` - (Default: `512M`)

    The Java memory heap size to specify to the JVM.

*   `JAVA_BASE_MEMORY` - (Default: `${JAVA_MEMORY}`)

    Can be set to use a different initial heap size.

*   `JAVA_MAX_MEMORY` - (Default: `${JAVA_MEMORY}`)

    Can be set to use a different max heap size.

*   `JAVA_OPTIONS` - (No default value)

    Additional -X options to pass to the JVM.

#### Volumes

*   `/data` - (Optional)

    Here go all data files, like: configs, plugins, logs, icons

#### Useful File Locations

*   `/app/start.sh` - This is the start script, which gets all the files and starts the server.

*   `/app` - This is directory created in the Docker environment, and where all files will be put.

## Built With

*   [OpenJDK v12](https://hub.docker.com/_/openjdk)
*   [Spigot](https://getbukkit.org/download/spigot)

## Find Us

*   [GitHub](https://github.com/D3strukt0r/docker-spigot)
*   [Docker Hub](https://hub.docker.com/r/d3strukt0r/spigot)

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct, and the process for submitting pull requests to us.

## Versioning

We use [SemVer](http://semver.org/) for versioning. For the versions available, see the
[tags on this repository](https://github.com/D3strukt0r/docker-spigot/tags).

## Authors

*   **Manuele Vaccari** - *Initial work* - [D3strukt0r](https://github.com/D3strukt0r)

See also the list of [contributors](https://github.com/D3strukt0r/docker-spigot/contributors) who
participated in this project.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.

## Acknowledgments

*   Kjell Havnesköld with [nimmis/docker-spigot](https://github.com/nimmis/docker-spigot)
*   Sylvain CAU with [AshDevFr/docker-spigot](https://github.com/AshDevFr/docker-spigot)
