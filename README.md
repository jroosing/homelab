# Homelab
This document describes my homelab setup which among others includes homepage, arr stack, plex and will eventually grow with other services such as uptime kuma, etc.

*DISCLAIMER:* This project is my personal project and there will be no support whatsoever.

## How to use this repo
Each docker compose stack resides in its own folder. 
Within the folder you will find the docker-compose.yaml and other configurations sometimes prefixed with _example_.

This is done as a trigger for the user that before running everything some manual work is needed such as collecting API keys, and other variables that will typically need to be put in these files.

For example in the starr directory you will find:
- example.env
- example.zurg.yaml

Copy these files and rename them without the example prefix and fill in the blanks

Files without the example prefix can be used as is.

## Homepage
[Homepage](https://gethomepage.dev/latest/) is the dashboard from which I will access all my services.

See: [gethomepage.md](docs/gethomepage.md) for setup

## Mediacenter
Part of my homelab consists of a mediacenter revolving around the [arr stack](https://wiki.servarr.com/), [Plex](https://www.plex.tv) and [Real-Debrid](https://real-debrid.com).

This setup is heavily influenced by [this](https://github.com/naralux/mediacenter) repo. Many thanks @Naralux for the base setup that helped me along the way.

See: [mediacenter.md](docs/mediacenter.md) for setup







