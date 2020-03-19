# docker-spigot

Use the Minecraft Spigot server as a Docker container

**Project**
[Docker][docker] | [License][license]
--- | ---
![Docker Stars][docker-stars-icon]<br />![Docker Pulls][docker-pulls-icon] | ![License][license-icon]

**master**-branch (alias stable, latest)
[Travis][travis] | [Docs][rtfd]
--- | ---
![Build status][travis-master-icon] | ![Docs build status][rtfd-master-icon]

**develop**-branch (alias nightly)

[Travis][travis] | [Docs][rtfd]
--- | ---
![Build status][travis-develop-icon] | ![Docs build status][rtfd-develop-icon]

[license]: https://github.com/D3strukt0r/docker-spigot/blob/master/LICENSE.txt
[docker]: https://hub.docker.com/repository/docker/d3strukt0r/spigot
[travis]: https://travis-ci.com/github/D3strukt0r/docker-spigot
[docker-stars-icon]: https://img.shields.io/docker/stars/d3strukt0r/spigot.svg
[rtfd]: https://docker-spigot-docs.manuele-vaccari.ch/

[license-icon]: https://img.shields.io/github/license/d3strukt0r/docker-spigot
[docker-pulls-icon]: https://img.shields.io/docker/pulls/d3strukt0r/spigot.svg
[travis-master-icon]: https://img.shields.io/travis/com/D3strukt0r/docker-spigot/master
[travis-develop-icon]: https://img.shields.io/travis/com/D3strukt0r/docker-spigot/develop
[rtfd-master-icon]: https://img.shields.io/readthedocs/docker-spigot/master
[rtfd-develop-icon]: https://img.shields.io/readthedocs/docker-spigot/develop

## Getting Started

These instructions will cover usage information and for the docker container

For more in-depth docs, please visit the [Docs](https://docker-spigot-docs.manuele-vaccari.ch) page

### Prerequisities

In order to run this container you'll need docker installed.

* [Windows](https://docs.docker.com/docker-for-windows/install/)
* [OS X](https://docs.docker.com/docker-for-mac/install/)
* [Linux](https://docs.docker.com/install/linux/docker-ce/ubuntu/)

### Usage

#### Docker CLI

```shell script
docker run -it \
           -p 25565:25565 \
           -v $(pwd)/data:/data \
           -e JAVA_MAX_MEMORY=1G \
           -e EULA=true \
           d3strukt0r/spigot
```

#### Docker CLI (detached)

```shell script
docker run -d \
           -p 25565:25565 \
           -v $(pwd)/data:/data \
           -e JAVA_MAX_MEMORY=1G \
           -e EULA=true \
           --name spigot \
           d3strukt0r/spigot
```

However there is no way to attach back to it, so instead use a library in linux which is known as "screen" and shown in the next section.

#### Docker CLI (with `screen`)

```shell script
screen -d -m -S "spigot" \
  docker run -it \
             -p 25565:25565 \
             -v $(pwd)/data:/data \
             -e JAVA_MAX_MEMORY=1G \
             -e EULA=true \
             d3strukt0r/spigot
```

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
    ports:
      - 25565:25565
    volumes:
      - ./data:/data
    environment:
      - JAVA_MAX_MEMORY=1G
      - EULA=true
```

And then use `docker-compose up` or `docker-compose up -d` for detached. Again using the experience with linux's `screen` library

**Important**

When configuring the server you **HAVE TO** use following option in your `server.properties` file
```properties
server-ip=0.0.0.0
```

**Hint**

If you need to add another port to your docker container, use `-p xxxxx:xxxxx` in your command.

## Built With

* [OpenJDK](https://hub.docker.com/_/openjdk) - The Java conatainer in Docker
* [Spigot](https://www.spigotmc.org/wiki/spigot/) - The main software
* [Travis CI](https://travis-ci.com/) - Automatic CI (Testing) / CD (Deployment)
* [Docker](https://www.docker.com/) - Building a Container for the Server

## Find Us

* [GitHub](https://github.com/D3strukt0r/docker-spigot)
* [Docker Hub](https://hub.docker.com/r/d3strukt0r/spigot)

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct, and the process for submitting pull requests to us.

## Versioning

There is no versioning in this project. Only the develop for nightly builds, and the master branch which builds latest and all minecraft versions.

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
