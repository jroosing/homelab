# Cert manager
Cert manager is a helpful tool to manage our SSL certificates. This tool enables us to request certificates from letsencrypt and auto renew them.

## installation
In my case, cert manager is managed [here](https://github.com/jroosing/argocd-managed-apps). 

If you don't want to use argoCD, follow [these](https://cert-manager.io/docs/installation/helm/) instructions instead.

or in short (for non argocd installations): 
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

**note:** the extraArgs is needed when your are running your own DNS which can not validate cloudflare domains. Using these flags we tell cert-manager to use a different nameserver from our host (in my case I run Pihole, but the domain is hosted on cloudflare).

## Using cert-manager
There are multiple ways to use cert manager. This section aims to explain the common ones.

### ClusterIssuer vs Issuer
Both issuers will get the job done. The biggest difference is that an Issuer is namespace bound where a ClusterIssuer is not bound to a single namespace.

In order for the issuer to be able to talk to the cloudflare api, make sure to get an api token. After doing so, we create a new kubernetes secret:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: cloudflare-api-token-secret
  namespace: cert-manager
type: Opaque
stringData:
  api-token: <cloudflare-api-token>
```

An example of an issuer (using letsencrypt-**staging**)

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
  namespace: cert-manager
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: <email>
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - dns01:
        cloudflare:
          email: <email>
          apiTokenSecretRef:
            name: cloudflare-api-token-secret
            key: api-token
```

In order to use production, create a different ClusterIssuer for example named "letsencrypt-prod", make sure to remove "-staging" from the server url and change the privateKeySecretRef to a different name. 

The privateKeySecretRef does not refer to the cloudflare secret. This is a secret created by cert-manager and must be different for the staging and prod secret in order to prevent one overwriting the other (and thus breaking the other).

### Manual cert vs auto cert
Cert manager comes with an ingress-shim controller which is able to automatically request certificates based on an annotation in your ingress definition. 

Having said this, there are 2 ways to maintain your certificates. Create them manually (using the Certificate CRD) or having the ingress-shim maintain it for you. In both cases cert-manager handles the auto-renewal.

#### Automated certs (ingress-shim)
By far the simplest method.

In your **ingress**, add the following annotation: `cert-manager.io/cluster-issuer: "letsencrypt-prod"`

Having this added lets the ingress-shim know it should handle the certificate.

A (**partial**) example of an ingress:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-server-ingress
  namespace: prod
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - myapp.example.com
    secretName: myapp-example-com-prd-tls
```

#### Manual certs
To create the certificate we will use the Certificate CRD.

An example of such a certificate:
```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: example-com-stg-wildcard-cert
  namespace: cert-manager
spec:
  secretName: example-com-stg-wildcard-tls
  issuerRef:
    name: letsencrypt-staging
    kind: ClusterIssuer
  dnsNames:
    - 'example.com'
    - "*.example.com"
  duration: 2160h # 90 days
  renewBefore: 360h # 15 days before expiration
```

This defines a certificate for both the root domain example.com and a wildcard certificate *.example.com.

The main advantage over the self managed certificate is being able to add a wildcard. E.g. only needing one single certificate to handle all subdomains. 

It does come with a new challenge. the spec.secretName contains the actual certificate. This secret however by default is not available cross namespace. So when referring to this secret in the ingress in a different namespace, it will fail to find the certificate.

To fix this, you can use a tool such as [reflector](https://github.com/emberstack/kubernetes-reflector). Which is a tool to help sync secrets cross namespace.

To make the 2 work together (assuming you have reflector installed)

Add the following extra annotations to the certificates spec:
```yaml
... # omitted cert content
  secretTemplate:
    annotations:
      reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
      reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces: "cert-manager,dev,staging,prod"  # Control destination namespaces
      reflector.v1.k8s.emberstack.com/reflection-auto-enabled: "true" # Auto create reflection for matching namespaces
      reflector.v1.k8s.emberstack.com/reflection-auto-namespaces: "cert-manager,dev,staging,prod" # Control auto-reflection namespaces
```

**The secretTemplate should be on the level of spec. E.g. spec.secretTemplate.**

In these annotations you can tell reflector how to reflect the secret generated by the certificate. This way you define a single wildcard cert and you can reffer to the secret in all (configured) namespaces. 

#### Why choose one over the other?
Using the automated system (ingress-shim) a new certificate gets generated for each application / ingress. 

Using the self managed certificate gives us more control. Especially it allows us to define a wildcard certificate, which is not possible using the auto generated certificate. We can sync the generated secret (actual cert) across namespaces using something like reflector.

