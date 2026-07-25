# Guide pas-à-pas — Part 2 : K3s + 3 apps + Ingress

> Objectif : 1 VM, K3s server, 3 apps web routees par Host sur 192.168.56.110.
> Critere de succes : les 3 Host renvoient la bonne app, app2 a 3 replicas.

C'est ici que tu apprends le **modele objet K8s** : Pod -> Deployment -> Service -> Ingress. Relis la section "Objets K8s essentiels" de [note.md](note.md) avant de commencer.

## Structure du dossier `p2`

```text
p2/
├── Vagrantfile
├── scripts/
│   └── server.sh
└── confs/
    ├── app1.yaml       # Deployment + Service (1 replica)
    ├── app2.yaml       # Deployment + Service (3 replicas)
    ├── app3.yaml       # Deployment + Service (1 replica, defaut)
    └── ingress.yaml    # routing par Host
```

---

## 1. Vagrantfile (1 seule machine)

Identique a P1 mais une seule VM. On reutilise la detection d'interface et l'install K3s server.

```ruby
# -*- mode: ruby -*-
LOGIN     = "login"          # <-- ton login 42
SERVER_IP = "192.168.56.110"

Vagrant.configure("2") do |config|
  config.vm.box              = "bento/ubuntu-22.04"
  config.vm.box_check_update = false

  config.vm.define "#{LOGIN}S" do |server|
    server.vm.hostname = "#{LOGIN}S"
    server.vm.network "private_network", ip: SERVER_IP

    server.vm.provider "virtualbox" do |vb|
      vb.name   = "#{LOGIN}S"
      vb.cpus   = 1
      vb.memory = 1024
    end

    server.vm.provision "shell", path: "scripts/server.sh", args: [SERVER_IP]
  end
end
```

---

## 2. scripts/server.sh

```bash
#!/bin/bash
set -e

SERVER_IP="$1"
IFACE=$(ip -o -4 addr show | awk -v ip="$SERVER_IP" '$0 ~ ip {print $2}')

# Install K3s server (comme P1).
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --node-ip=${SERVER_IP} \
  --flannel-iface=${IFACE} \
  --write-kubeconfig-mode=644" sh -

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" >> /home/vagrant/.bashrc

# Attendre que le node soit pret, puis appliquer tous les manifests du dossier confs.
kubectl wait --for=condition=Ready node --all --timeout=120s
kubectl apply -f /vagrant/confs/
```

---

## 3. Les manifests (dossier `confs`)

**Image** : `paulbouwer/hello-kubernetes` affiche une page avec un texte personnalisable via la variable `MESSAGE`. Une seule image, 3 messages -> 3 apps distinctes. Verifie le tag sur [Docker Hub](https://hub.docker.com/r/paulbouwer/hello-kubernetes/tags) (ex. `1.10.1`), le conteneur ecoute sur le port 8080.

### confs/app1.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app1
  template:
    metadata:
      labels:
        app: app1          # ce label est la cle : le Service et le Deployment se retrouvent par la
    spec:
      containers:
        - name: app1
          image: paulbouwer/hello-kubernetes:1.10.1
          ports:
            - containerPort: 8080
          env:
            - name: MESSAGE
              value: "Hello from APP1"
---
apiVersion: v1
kind: Service
metadata:
  name: app1-service
spec:
  selector:
    app: app1              # cible tous les Pods portant app=app1
  ports:
    - port: 80             # port du Service
      targetPort: 8080     # port du conteneur
```

### confs/app2.yaml

Identique a app1 en remplacant `app1` par `app2`, le MESSAGE par "APP2", et surtout :

```yaml
spec:
  replicas: 3              # <-- les 3 replicas exiges par le sujet
```

### confs/app3.yaml

Identique a app1 en remplacant `app1` par `app3` et le MESSAGE par "APP3" (1 replica).

### confs/ingress.yaml

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: apps-ingress
spec:
  rules:
    - host: app1.com                 # si Host = app1.com -> app1
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: app1-service
                port:
                  number: 80
    - host: app2.com                 # si Host = app2.com -> app2
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: app2-service
                port:
                  number: 80
  defaultBackend:                    # tout le reste -> app3 (cas "otherwise")
    service:
      name: app3-service
      port:
        number: 80
```

Le `defaultBackend` gere elegamment le "sinon app3" du sujet.

---

## 4. Lancer et verifier

```bash
cd p2
vagrant up
vagrant ssh login S           # ou <LOGIN>S

# Verifier que tout est la
kubectl get pods              # app2 doit avoir 3 pods
kubectl get svc
kubectl get ingress
```

Test du routing (depuis la VM ou l'hote qui joint 192.168.56.110) :

```bash
curl -H "Host: app1.com" http://192.168.56.110    # -> APP1
curl -H "Host: app2.com" http://192.168.56.110    # -> APP2
curl http://192.168.56.110                        # -> APP3 (defaut)
```

**Critere de succes** : les 3 commandes renvoient la bonne app, `kubectl get pods` montre 3 replicas pour app2, et tu sais afficher l'Ingress (`kubectl describe ingress apps-ingress`) en defense.

---

## Le pont Traefik

L'Ingress que tu viens d'ecrire est consomme par le **Traefik embarque** dans K3s (ton Ingress controller). Verifie-le :

```bash
kubectl get pods -n kube-system | grep traefik
```

Tu passes de "routing par labels Docker" (ce que tu connais) a "routing par objet Ingress" : meme moteur Traefik, autre facon de le declarer.

---

## Debug rapide

- **404 partout** : l'Ingress ne trouve pas les Services. Verifier que les `selector` des Services matchent bien les `labels` des Pods (`kubectl get pods --show-labels`).
- **Pod en `ImagePullBackOff`** : mauvais nom d'image / tag. Verifier le tag sur Docker Hub.
- **`curl` timeout** : tu n'attaques pas la bonne IP, ou Traefik n'ecoute pas. `kubectl get svc -n kube-system traefik` doit exposer 80/443.
- **app2 n'a pas 3 pods** : `replicas: 3` oublie, ou pas assez de ressources sur la VM.

---

## Reutilise / neuf

- **Reutilise** : le reflexe replicas (Swarm), le routing Traefik, l'install K3s de P1.
- **Neuf** : ecrire des manifests YAML (Deployment/Service/Ingress), le couple label/selector, le `defaultBackend`.
