# docker-spigot

Use the Minecraft Spigot server as a Docker container

Project

[![License](https://img.shields.io/github/license/d3strukt0r/docker-spigot)][license]
[![Docker Stars](https://img.shields.io/docker/stars/d3strukt0r/spigot.svg)][docker]
[![Docker Pulls](https://img.shields.io/docker/pulls/d3strukt0r/spigot.svg)][docker]
[![GH Action CI/CD](https://github.com/D3strukt0r/docker-spigot/workflows/Check%20Outdated%20Versions/badge.svg)][gh-action]
[![GH Action CI/CD](https://github.com/D3strukt0r/docker-spigot/workflows/Update%20versions/badge.svg)][gh-action]

master-branch (alias stable, latest)

[![GH Action CI/CD](https://github.com/D3strukt0r/docker-spigot/workflows/CI/CD/badge.svg?branch=master)][gh-action]
[![Codacy grade](https://img.shields.io/codacy/grade/b674b9fdcd8a429ca863e975e685cbd1/master)][codacy]
[![Docs build status](https://img.shields.io/readthedocs/docker-spigot/master)][rtfd]

develop-branch (alias nightly)

[![GH Action CI/CD](https://github.com/D3strukt0r/docker-spigot/workflows/CI/CD/badge.svg?branch=develop)][gh-action]
[![Codacy grade](https://img.shields.io/codacy/grade/b674b9fdcd8a429ca863e975e685cbd1/develop)][codacy]
[![Docs build status](https://img.shields.io/readthedocs/docker-spigot/develop)][rtfd]

## Getting Started

These instructions will cover usage information and for the docker container

For more in-depth docs, please visit the [Docs](https://docker-spigot-docs.manuele-vaccari.ch) page

### Prerequisities

In order to run this container you'll need docker installed.

-   [Windows](https://docs.docker.com/docker-for-windows/install/)
-   [OS X](https://docs.docker.com/docker-for-mac/install/)
-   [Linux](https://docs.docker.com/install/linux/docker-ce/ubuntu/)

### Usage

#### Starting a server

```shell
docker run \
    --rm \
    -d \
    -p 25565:25565 \
    -v $(pwd)/data:/data \
    -e JAVA_MAX_MEMORY=1G \
    -e EULA=true \
    --name spigot \
    d3strukt0r/spigot
```

Hint

If you need to add another port to your docker container, use `-p xxxxx:xxxxx` in your command.

Important

When configuring the server you **HAVE TO** either leave the server-ip empty or use following option in your `server.properties` file

```properties
server-ip=0.0.0.0
```

#### Reading the logs

```shell
docker logs -f spigot
```

#### Sending commands

```shell
docker exec spigot console "<command>"
```

#### Using Docker Compose (docker-compose.yml)

```yaml
version: "2"

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

And then use `docker-compose up` or `docker-compose up -d` for detached.

## Built With

-   [OpenJDK](https://hub.docker.com/_/openjdk) - The Java conatainer in Docker
-   [Spigot](https://www.spigotmc.org/wiki/spigot/) - The main software
-   [Github Actions](https://github.com/features/actions) - Automatic CI (Testing) / CD (Deployment)
-   [Docker](https://www.docker.com/) - Building a Container for the Server

## Find Us

-   [GitHub](https://github.com/D3strukt0r/docker-spigot)
-   [Docker Hub](https://hub.docker.com/r/d3strukt0r/spigot)

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct, and the process for submitting pull requests to us.

## Versioning

There is no versioning in this project. Only the develop for nightly builds, and the master branch which builds latest and all minecraft versions.

## Authors

-   **Manuele Vaccari** - [D3strukt0r](https://github.com/D3strukt0r) - _Initial work_

See also the list of [contributors](https://github.com/D3strukt0r/docker-spigot/contributors) who participated in this project.

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE.txt](LICENSE.txt) file for details.

## Acknowledgments

-   Kjell Havnesköld with [nimmis/docker-spigot](https://github.com/nimmis/docker-spigot)
-   Sylvain CAU with [AshDevFr/docker-spigot](https://github.com/AshDevFr/docker-spigot)
-   Hat tip to anyone whose code was used
-   Inspiration
-   etc

[license]: https://github.com/D3strukt0r/docker-spigot/blob/master/LICENSE.txt
[docker]: https://hub.docker.com/repository/docker/d3strukt0r/spigot
[rtfd]: https://docker-spigot-docs.manuele-vaccari.ch/
[gh-action]: https://github.com/D3strukt0r/docker-spigot/actions
[codacy]: https://www.codacy.com/manual/D3strukt0r/docker-spigot
