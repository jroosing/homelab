# Traefik
In this setup, traefik is running as a separate LXC. I tend to restart VM's and stuff often, hence I separated Traefik from my docker VM.
Now I can cause mayham in my docker VM without affecting my proxy. 

Note that Traefik has excellent docker support, and I highly encourage to also look into that as it allows other docker containers to self register,
which is a feature we lose using this setup as we don't have access to the docker daemon (at least not without being hacky).

## Setup
Traefik is running in an LXC created via the tteck helper scripts: [https://tteck.github.io/Proxmox/]().
My LXC is configured to run a single CPU, 2GB RAM and 12GB storage.

## Config
Assuming the helper script is used, the static and dynamic config can be found at /etc/traefik.
traefik.yaml contains your static configuration and I typically create a dynamic folder containing the dynamic config.

_note:_ in the config, any value between <> is something you will need to replace with your own value

An important difference is that for static config changes you need to restart traefik, dynamic changes can be picked up automagically.

In my /etc/traefik I have the following layout:

- ssl/acme.json (make sure this file has chmod 600 rights applied)
- conf.d (directory containing dynamic config)
- traefik.yaml

Inside conf.d I host a couple of yaml files:

- core.yaml (contains for example middleware that I apply to all app routers)
- [APP].yaml (e.g. pihole.yaml, plex.yaml, etc..)
  - Note that you can also just throw all config in one file but for me it became hard to manage

Apart from the config in this directory, no other configuration is needed.

## Cloudflare
For my traefik setup, I use cloudflare and letsencrypt.
In order to set this up, it is assumed you have a domain available in cloudflare and have your basic account setup.

### API KEY
1. Log in to cloudflare. On the top right side, click on your profile icon and select "My Profile".
2. Select API Tokens in the menu on the left
3. Click the "Create Token" button
4. Find "Custom token" and click the "Get started" button
5. Give your token a descriptive name
6. For permissions we need 2 entries: Zone -> Zone -> Read and Zone -> DNS -> Edit
7. For Zone Resources select "Include" and "All zones from an account"
8. Click "Continue to summary"
9. Create the token and note down the actual api token. You will _NOT_ be able to retrieve it again. Losing it means creating a new api key.

## Setting up the traefik service in the LXC
```batch
nano /etc/systemd/system/traefik.service
```

Under the [Service] section add a new key value:

`Environment="CF_DNS_API_TOKEN=<YOUR TOKEN>"`

The service should look something like this:

```toml
[Unit]
Description=Traefik is an open-source Edge Router that makes publishing your services a fun and easy experience

[Service]
Type=notify
Environment="CF_DNS_API_TOKEN=<YOUR TOKEN>"
ExecStart=/usr/bin/traefik --configFile=/etc/traefik/traefik.yaml
Restart=on-failure
ExecReload=/bin/kill -USR1 $MAINPID

[Install]
WantedBy=multi-user.target
```

run `systemctl daemon-reload` and `service traefik restart`.

## Note
When modifying static configuration i.e. traefik.yaml, restart traefik to apply the changes (e.g. `service traefik restart`)

### acme.json
When your config is in place, make sure this file is empty (you can test by using letsencrypt staging, see [traefik.yaml](../traefik/traefik.yaml)).
and restart traefik. Given that the configuration is correct, traefik wil fill this file with certificates for the main and sans domain defined in my case in [core.yaml](../traefik/dynamic/core.yaml).

### traefik.yaml
In this static config we define a couple of important things:

#### global

We want to check for the availability of new versions so that we know when to upgrade and enable/disable anonymous usage, up to you to send or not

```yaml
global:
  checkNewVersion: true
  sendAnonymousUsage: false
```

#### dashboard

```yaml
api:
  dashboard: true
  insecure: false
  debug: false
  disableDashboardAd: true
```

1. Enable dashboard
2. Put it behind some kind of authentication
3. by default debug false, we enable it when we need it
4. Apperantly there are ads? Haven't checked, but disable if you don't want em

### Logging

Define where logs are placed and how long before rotating etc.

#### entryPoints

Define the web (http) and websecure (https) endpoint (up to you how to name them)

These are the entry points into traefik, so for all defined routers such as for pihole, proxmox and of course traefik itself.
In the static config, we enable port 80 and 443 on the internal network.

#### providers

Here you can enable different types of providers such as a directory containing files which traefik wil need to parse (allows the dynamic config)
but also for example docker. If you have access to the docker daemon, you can add it here, and allow apps on the same docker network to be self registering

#### certificateResolvers

This is the configuration for an ACME provider (like let's encrypt) for automatic certificate generation.

This needs to be defined in static config according to [traefik](https://doc.traefik.io/traefik/https/acme/)
For this particular setup we use dnsChallenge as the ACME challenge.

### dynamic/core.yaml

This contains some useful and (for me) common middlewares and other reusable bits n bobs

#### routers.dashboard

This is the config to allow us to reach traefik by using a DNS record: traefik.<yourdomain>.nl
The dashboard has some specific important bits that other routers dont have.

Note the service: api@internal and middlewares: - auth

#### catchall

Any traffic to the traefik ip that is unknown will fall into this entry point and result in a 503
This is not a must, i just found it nice.

#### services

Here we tell where to proxy to. For example a request comes in for pihole.<yourdomain>.nl, in the services we will specify to which scheme, ip and port we need to redirect. 

For the catchall, we leave the loadbalancer empty as we dont want to redirect.

#### middlewares

contains some useful middlewares, for example redirecting to https, enabling authentication, default headers we want to include, etc.

#### tls
Here we define the TLS versions to allow, and the certificate resolver (in my case thats cloudflare).
We also define the main and sans here, which are the domains we want to resolve the certificates for.

Main is typically just <domain>.nl (no subdomain)
and sans is a list of subdomains, or a wildcard.

In my case i defined the sans as *.<yourdomain>.nl. but you could also have *.home.<yourdomain>.nl, etc.

#### <app>.yaml

These files contain the router, service and if needed middlewares specific to these apps