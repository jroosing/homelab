# K3S install guide
This guide is all about setting up a k3s cluster.

Note that this guide does NOT cover HA (High-availability) and consists of a single control plane (master node) and 2 workers (or agents).

In this guide I will use the term workers instead of agents as I have no clue what is the better one, im used to the term worker...

## Setup
In proxmox, 3 VMS with ubuntu 24.xx server, 2 CPU's, 4gb ram and 5gb disk space (depending on your work loads you may need to change these)

## Prerequisites
- 3 VMs ready, 1 master, 2 workers
- An OS installed and configured with different host names and static IP's
-- in my example they will be k3s-master, k3s-worker-1, k3s-worker-2

## Installing the master node
The installation is mostly based on [https://docs.k3s.io/quick-start]().

Run: 
```sh
curl -sfL https://get.k3s.io | sh -
```
__note:__ This sets up traefik as the ingress controller and ServiceLB (formerly known as klipper lb) as the loadbalancer. 

Using the provided loadbalancer exposes the cluster on each node ip (so master and workers).

### barebones k3s (without LB and ingress)
If youd like to configure your own LB and ingress controller, run the following command to disable traefik and the default LB

```sh
curl -sfL https://get.k3s.io | sh -s - --disable=traefik,servicelb
```

## Installing the worker nodes

```sh
curl -sfL https://get.k3s.io | K3S_URL=https://my-ip:6443 K3S_TOKEN=mytoken sh -
```

- Replace the K3S_TOKEN with your actual token which can be found at: `/var/lib/rancher/k3s/server/node-token`
- Replace "myserver" with the IP of your master node

e.g. 
```sh
sudo cat /var/lib/rancher/k3s/server/node-token
```

## Kubeconfig
This configuration describes how to access the cluster with for example kubectl or k9s. 

On your master node, copy the k3s.yaml located at `/etc/rancher/k3s/k3s.yaml`

You may have to access the file with sudo.

We need to copy this file to `$HOME/.kube/config`. Once that is done, run `kubectl get nodes` to see if you have access and if nodes are installed successfully.

__note:__ your first try will likely fail if you copy the k3s yaml to a different machine as-is. In order to fix that you need to update the ip in the config to the ip of the master node.

```sh
nano ~/.kube/config
```
The change to be done is quite obvious.

## Configuring the cluster

### metal-lb
metal lb is a loadbalancer that works well with a homelab type system

installation instructions can be found here: https://metallb.universe.tf/installation/

```sh
helm repo add metallb https://metallb.github.io/metallb
helm install metallb metallb/metallb -n metallb-system --create-namespace
```

Once installed, we need to add an address pool and layer2 advertisement. 

See [sample](../k8s/metallb/metallb.sample.yaml) on how to do so.

for the ip ranges, i used a subset of my home network

### ingress-nginx
The ingress controller can be installed in multiple ways. My favourite is HELM.

```sh
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace
```

You can check the external-ip(s) by running the following command:

`kubectl get service --namespace ingress-nginx ingress-nginx-controller --output wide --watch`

### ArgoCD gitops

Install argo cd using the following instructions:

```sh
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Once installed we can add applications. 
For my usecase, I created a repository containing helm (sub)charts that are managed by argocd such as cert-manager and reflector

#### Cert manager
Cert manager handles the (auto-renewed) certificates. The configuration in this guide will be focused on Cloudflare and letsencrypt using DNS01 challenges.

In my case, cert manager is managed [here](https://github.com/jroosing/argocd-managed-apps). 

If you don't want to use argoCD, follow [these](https://cert-manager.io/docs/installation/helm/) instructions instead.

or in short: 
```sh
helm repo add jetstack https://charts.jetstack.io --force-update
helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.15.3 \
  --set crds.enabled=true \
  --set 'extraArgs[0]=--dns01-recursive-nameservers-only' \
  --set 'extraArgs[1]=--dns01-recursive-nameservers=1.1.1.1:53'
```

__note:__ The extra args are needed for when you run your VM against for example pihole dns. In that case we need a different DNS (such as cloudflare) to validate the certs.

See the [cert-manager documentation](./k8s-cert-manager.md) for more details about cert-maanger.
 
Once installed, we need to create a couple of configurations. 

First, get an API token from cloudflare. The token needs to have read access on zone -> zone and edit access on zone -> DNS.

With the token, create the following secret:

cloudflare-api-token-secret.yaml
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: cloudflare-api-token-secret
  namespace: cert-manager
type: Opaque
stringData:
  api-token: <YOUR API TOKEN>
```

```sh
kubectl apply -f cloudflare-api-token-secret.yaml
```

This secret will be used by cert manager to allow access to the cloudflare API.

Now create a cluster issuer. The advantage of a cluster issuer compared to an issuer is that cluster issuer is cluster wide, whereas issuer is per namespace.

cert-issuer-staging.yaml
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
  namespace: cert-manager
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: <EMAIL>
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - dns01:
        cloudflare:
          email: <EMAIL>
          apiTokenSecretRef:
            name: cloudflare-api-token-secret
            key: api-token
```
In here we use apiTokenSecretRef. If you prefer to use api key isntead (which you shouldn't because it provides less security) change this to apiKeySecretRef.

This uses the letsencrypt staging ACME. You can of course change this to use production. Personally I have 2 separate configs 1 for staging, one for prod.

And last, create a certificate:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: <domain>-nl-stg-wildcard-cert
  namespace: staging
spec:
  secretName: <domain>-nl-stg-wildcard-tls
  commonName: <domain>.nl
  dnsNames:
    - '<your domain>.nl'
    - "*.<your domain>.nl"
  issuerRef:
    name: letsencrypt-staging
    kind: ClusterIssuer
  duration: 2160h # 90 days
  renewBefore: 360h # 15 days before expiration
```

The names of the secret and resource can differ, up to you how to name them.

Note that in your ingress you need to point to the same secretName, as that is where cert-manager stores the actual certificate.
The issuerRef is also important and the name should match the cluster issuer resource name created earlier.

Also make sure to change the namespace of the certificate to suit your own situation.

## Uninstall
On the master node run:

```sh
/usr/local/bin/k3s-uninstall.sh
```

on the worker nodes run:

```sh
/usr/local/bin/k3s-agent-uninstall.sh
```

This does a pretty good cleanup, and allows for quick re installations of kubernetes of a mistake is made in such a way that your cluster is no longer usable, or you just want a clean slate.