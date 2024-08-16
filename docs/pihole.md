# Pihole
I am running Pihole as a proxmox LXC. This makes it lightweight and self contained. 

Find tteck's helper script [here](https://tteck.github.io/Proxmox/)

## Setup
This is an LXC with the following specs: 1gb of memory, 1 core and 12GB disk

Note that I always configured pihole via the ui so far, so no config files this time.

## DNS setup

Navigate to "Settings" -> "DNS"

Enable any upstream DNS Servers. I typically use Quad9 and cloudflare, but you could also use a second pihole for example.

In the interface settings, use "Allow only local requests". Don't know why, but it works and its a recommended setting, so it must be correct(?)

### DNS advanced settrings
Check the "Never forward non-FQDN A and AAAA queries" and "Never forward reverse lookups for private ip ranges" checkboxes.
Sounds safe to do this. Dont know the details. Still learning here...

Enable DNSSEC, unless it breaks stuff for you, then disable it :)

## Local DNS and traefik
Navigate to "Local DNS" -> "DNS Records".

If you use a reverse proxy like traefik, we only need 1 entry here, as everything should go to traefik who will then safely redirect to the correct services accordingly.

For the domain, enter traefik.<yourdomain>.com. Or whatever name you want to give it (make it logical to yourself).
For the IP enter the IP of the reverse proxy machine.

### CNAMES (especially useful with reverse proxy)
If you do use a reverse proxy, create the other entries as cnames. a CNAME allows us to define domains and point them to a different domain.

This is useful in case of a reverse proxy because if we point all cnames to the traefik.<yourdomain>.com we just created instead of the IP and
for whatever reason the reverse proxy IP changes, we only have to change it in one place (the DNS Record). The CNAME's will automagically go along to that new IP.

## Credits
Special thanks to all adlist maintainers for making our internet lives better and safer