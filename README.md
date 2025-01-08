<h1 align="center">
  <a href="https://github.com/jtmb">
    <img src="https://upload.wikimedia.org/wikipedia/commons/thumb/6/66/New_qBittorrent_Logo.svg/1200px-New_qBittorrent_Logo.svg.png" alt="Logo" width="125" height="125">
  </a>
</h1>

<div align="center">
  <b>qbit-port-forwarder</b> - A self hosted sciplet that forwards the qbittorrent port based off the current port set for the glueten vpn container.
  <br />
  <br />
  <a href="https://github.com/jtmb/qbit-port-forwarder/issues/new?assignees=&labels=bug&title=bug%3A+">Report a Bug</a>
  ·
  <a href="https://github.com/jtmb/qbit-port-forwarder/issues/new?assignees=&labels=enhancement&template=02_FEATURE_REQUEST.md&title=feat%3A+">Request a Feature</a>
  .
  <a href="https://hub.docker.com/repository/docker/jtmb92/qbit-port-forwarder/general">Docker Hub</a>
</div>
<br>
<details open="open">
<summary>Table of Contents</summary>

- [About](#about)
    - [Highlighted Features](#highlighted-features)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
    - [Docker Image](#docker-image)
    - [Running on Docker](#running-on-docker)
    - [Running on Docker Compose](#running-on-docker-compose)
    - [Backing up to remote locations](#backing-up-to-remote-locations)
    - [Performing an adhoc (one time) backup](#performing-an-adhoc-one-time-backup)
    ### 
- [Environment Variables Explained](#environment-variables-explained)
- [Contributing](#contributing)
- [License](#license)

</details>
<br>

---

### <h1>About</h1>

An Alpine-based microservice within Docker, designed to make forwarding vpn ports easy.

This solution proves invaluable for those who self-host torrents.

## Prerequisites

- Docker installed on your system

### <h2>Getting Started</h2>
### [Docker Image](https://hub.docker.com/r/jtmb92/ez-backups)
```docker
 docker pull jtmb92/qbit-port-forwarder
```

### Running on Docker Compose  
Run on Docker Compose (this is the recommended way) by running the command "docker compose up -d".  
```yaml
services:
    qbit-port-forwarder:
        image: docker.io/jtmb92/qbit-port-forwarder
        container_name: qbit-port-forwarder
        environment:
            container_volumes_location: '/mnt'
            node: '192.168.0.5'
            ADMIN_USER: 'brajam'
            ADMIN_PASS: '${ADMIN_PASS}'
            WAIT_TIME: '1h'
        volumes:
         - ${container_volumes_location}/gluetun:/mnt/gluetun
```

## Environment Variables explained  

```yaml
    container_volumes_location: '/mnt'
```  
Location on the host machine where volumes will be mounted.  
```yaml
    node: '192.168.0.5'
```  
The IP address of the node you wish to connect to.  
```yaml
    ADMIN_USER: 'brajam'
```  
Admin username for the service.  
```yaml
    ADMIN_PASS: '${ADMIN_PASS}'
```  
Admin password for the service. This should be set as an environment variable or a `.env` file.  
```yaml
    WAIT_TIME: '1h'
```  
Time to wait before performing a port forward operation (can be set in hours, minutes, or seconds).  
```yaml
    volumes: 
        - ${container_volumes_location}/gluetun:/mnt/gluetun
```  
The path to mount the `gluetun` directory in the container.  

## Contributing

First off, thanks for taking the time to contribute! Contributions are what makes the open-source community such an amazing place to learn, inspire, and create. Any contributions you make will benefit everybody else and are **greatly appreciated**.

Please try to create bug reports that are:

- _Reproducible._ Include steps to reproduce the problem.
- _Specific._ Include as much detail as possible: which version, what environment, etc.
- _Unique._ Do not duplicate existing opened issues.
- _Scoped to a Single Bug._ One bug per report.

## License

This project is licensed under the **GNU GENERAL PUBLIC LICENSE v3**. Feel free to edit and distribute this template as you like.

See [LICENSE](LICENSE) for more information.






docker build --platform linux/amd64 -t jtmb92/qbit-port-forwarder:amd64 .
docker push jtmb92/qbit-port-forwarder:amd64

docker build --platform linux/amd64 -t jtmb92/qbit-port-forwarder:latest .
docker push jtmb92/qbit-port-forwarder:latest