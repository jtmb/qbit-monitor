<h1 align="center">
  <a href="https://github.com/jtmb">
    <img src="https://upload.wikimedia.org/wikipedia/commons/thumb/6/66/New_qBittorrent_Logo.svg/1200px-New_qBittorrent_Logo.svg.png" alt="Logo" width="125" height="125">
  </a>
</h1>

<div align="center">
  <b>qbit-monitor</b> - Monitor your qBittorrent WEBUI and get push notifications.
  <br />
  <br />
  <a href="https://github.com/jtmb/qbit-monitor/issues/new?assignees=&labels=bug&title=bug%3A+">Report a Bug</a>
  ·
  <a href="https://github.com/jtmb/qbit-monitor/issues/new?assignees=&labels=enhancement&template=02_FEATURE_REQUEST.md&title=feat%3A+">Request a Feature</a>
  .
  <a href="https://hub.docker.com/repository/docker/jtmb92/qbit-monitor/general">Docker Hub</a>
</div>
<br>
<details open="open">
<summary>Table of Contents</summary>

- [About](#about)
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

### <h1>About ( What problem does this solve? )</h1>

Monitors your qBittorrent for new / completed torrents and notifies on discord, also handles qbittorrent meta data stuck torrents.

The GluetenVPN container allows for port forwarding with PROTONVPN with the unfortunate downside that PROTON assigns a random port everytime you restart your container. This application will check the vpn forewarded port and update your qbittorrent application automatically.

## Prerequisites

- Docker installed on your system

### <h2>Getting Started</h2>
### [Docker Image](https://hub.docker.com/r/jtmb92/qbit-monitor)
```docker
 docker pull jtmb92/qbit-monitor
```

### Running on Docker Compose  
Run on Docker Compose (this is the recommended way) by running the command "docker compose up -d".  
```yaml
services:
    qbit-monitor:
        image: docker.io/jtmb92/qbit-monitor
        container_name: qbit-monitor
        depends_on:
            qbittorrent:
                condition: service_started
                restart: true
        environment:
            QBITTORRENT_HOST: "http://192.168.0.5:8112"
            QBITTORRENT_USERNAME: "admin"
            QBITTORRENT_PASSWORD: "admin1234"
            CHECK_INTERVAL_TORRENT_MONITORING: 10s
            CHECK_INTERVAL_FORWARDED_PORT: 1h
            NOTIFIED_FILE: notified_torrents.txt
            PORT_FORWARD_FILE: /mnt/gluetun/forwarded_port
            WAIT_TIME: "10s"
            PUID: "1000"
            PGID: "1000"
            TZ: America/New_York
            DISCORD_WEBHOOK_URL: xxxx

        volumes:
        - /mnt/gluetun:/mnt/gluetun
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
        - /mnt/gluetun:/mnt/gluetun
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