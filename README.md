# docker-spigot
Use the Minecraft Spigot server as a Docker container

Docker | Travis (master) | Travis (develop)
--- | --- | ---
![Docker Stars](https://img.shields.io/docker/stars/d3strukt0r/spigot.svg)<br />![Docker Pulls](https://img.shields.io/docker/pulls/d3strukt0r/spigot.svg) | ![Travis (.com) branch](https://img.shields.io/travis/com/D3strukt0r/docker-spigot/master) | ![Travis (.com) branch](https://img.shields.io/travis/com/D3strukt0r/docker-spigot/develop)

## Getting Started

These instructions will cover usage information and for the docker container

### Prerequisities

In order to run this container you'll need docker installed.

*   [Windows](https://docs.docker.com/windows/started)
*   [OS X](https://docs.docker.com/mac/started/)
*   [Linux](https://docs.docker.com/linux/started/)

### Usage

#### Docker CLI

To start the server use the following command:
```shell script
docker run -i -t -p 25565:25565 -v $(pwd)/data:/data d3strukt0r/spigot
```

##### `-i -t`
To be able to type commands directly in your terminal `-i -t` or `-it`. To detach from the terminal use `Ctrl + P + Q`. To start it detached from the beginning use `-d`

##### `-p 25565:25565`
Spigot uses `25565` as a default port, however, if you use Spigot or a similar app, change the port to something else (`-p 25566:25565`).

##### `-v $(pwd)/data:/data`
It is not necessary to add any volumes, but if you do add it (`-v <host_dir>:/data`), your data will be saved. If you don't add it, it is impossible to change any config file, or add plugins.

##### `d3strukt0r/spigot`
This is the repository on Docker Hub.

##### `-Xms512M -Xmx512M`
To add arguments, like memory limit, simply add them after the repo inside the command. Or when using a `docker-compose.yml` file, put it inside `command: ...`.

```shell script
docker run -d -p 25565:25577 -v $(pwd)/data:/data --name spigot d3strukt0r/spigot -Xms512M -Xmx512M
```

##### `-d`
Run detached (in the background)

##### `--name spigot`
Give this container a name for easier reference later on.

#### Docker CLI (with `screen`)

However there is no way to attach back to it, so instead use a library in linux which is known as "screen":

```shell script
screen -d -m -S "spigot" docker run -i -t -p 25565:25577 -v $(pwd)/data:/data d3strukt0r/spigot -Xms512M -Xmx512M
```

##### `screen -d -m -S "spigot"`
Creates like a window in the terminal which you can easily leave and enter.

You can detach from the window using `CTRL` + `a` and then `d`.

To reattach first find your screen with `screen -r`. And if you gave it a name, you can skip this.

Then enter `screen -r spigot` or `screen -r 00000.pts-0.office` (or whatever was shown with `screen -r`)

#### Docker Compose

Example `docker-compose.yml` file:
```yml
version: '2'

services:
  spigot:
    image: d3strukt0r/spigot
    command: -Xms512M -Xmx512M
    ports:
      - 25565:25577
    volumes:
      - ./data:/data
```

And then use `docker-compose up` or `docker-compose up -d` for detached. Again using the experience with linux's `screen` library

**Important**

When configuring the server you **HAVE TO** use following option in your `server.properties` file
```properties
server-ip=0.0.0.0
server-port=25565
```

**Hint**

If you need to add another port to your docker container, use `--expose` in your command.

#### Volumes

* `/data` - (Optional)

Here go all data files, like: configs, plugins, logs, icons

## Built With

* [Java](https://www.java.com/de/) - Programming Language
* [OpenJDK](https://hub.docker.com/_/openjdk) - The Java conatainer in Docker
* [BungeeCord](https://ci.md-5.net/job/BungeeCord/) - The main software
* [Travis CI](https://travis-ci.com/) - Automatic CI (Testing) / CD (Deployment)
* [Docker](https://www.docker.com/) - Building a Container for the Server

## Find Us

* [GitHub](https://github.com/D3strukt0r/docker-spigot)
* [Docker Hub](https://hub.docker.com/r/d3strukt0r/spigot)

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct, and the process for submitting pull requests to us.

## Versioning

We use [SemVer](http://semver.org/) for versioning. For the versions available, see the
[tags on this repository](https://github.com/D3strukt0r/docker-spigot/tags).

## Authors

* **Manuele Vaccari** - [D3strukt0r](https://github.com/D3strukt0r) - *Initial work*

See also the list of [contributors](https://github.com/D3strukt0r/docker-spigot/contributors) who
participated in this project.

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE.txt](LICENSE.txt) file for details

## Acknowledgments

* Kjell Havnesköld with [nimmis/docker-spigot](https://github.com/nimmis/docker-spigot)
* Sylvain CAU with [AshDevFr/docker-spigot](https://github.com/AshDevFr/docker-spigot)
* Hat tip to anyone whose code was used
* Inspiration
* etc
