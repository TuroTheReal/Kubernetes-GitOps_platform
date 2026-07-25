# Guide pas-à-pas — Part 1 : K3s + Vagrant

> Objectif : 2 VMs, K3s en mode server sur l'une, agent sur l'autre.
> Critere de succes : `kubectl get nodes` montre 2 nodes `Ready`.

## Avertissement provider (a lire avant)

Ce guide part sur **VirtualBox** (le mieux documente, celui des machines 42 x86).

- **Mac Intel / PC Linux** : VirtualBox OK.
- **Mac Apple Silicon (M1/M2/M3...)** : VirtualBox ne tourne pas nativement. Il faut un autre provider (ex. `parallels` ou `qemu`/`libvirt`) et une box compatible arm64. La logique du guide reste la meme, seuls le bloc `provider` et la `box` changent. A adapter selon ta machine.

Rappel sujet : tout le projet se fait **dans une VM hote**. En pratique tu lances Vagrant depuis cette VM (ou depuis une machine 42).

---

## Structure du dossier `p1`

```text
p1/
├── Vagrantfile
└── scripts/
    ├── server.sh
    └── worker.sh
```

Le sujet impose : scripts dans `scripts/`, configs dans `confs/` (ici pas de confs pour P1).

---

## 1. Le Vagrantfile (commenté)

```ruby
# -*- mode: ruby -*-

# Un seul endroit a changer : ton login 42.
# Le sujet impose : hostname = <login> + "S" (server) et <login> + "SW" (worker).
LOGIN       = "login"          # <-- REMPLACE par ton login 42
SERVER_NAME = "#{LOGIN}S"
WORKER_NAME = "#{LOGIN}SW"
SERVER_IP   = "192.168.56.110"
WORKER_IP   = "192.168.56.111"

Vagrant.configure("2") do |config|
  # Box commune : une distro Linux, derniere stable.
  # bento/* supporte plusieurs providers (VirtualBox, Parallels, VMware).
  config.vm.box              = "bento/ubuntu-22.04"
  config.vm.box_check_update = false

  # ---------- SERVER : K3s en mode controller ----------
  config.vm.define SERVER_NAME do |server|
    server.vm.hostname = SERVER_NAME
    # Reseau prive : IP dediee sur l'interface secondaire.
    server.vm.network "private_network", ip: SERVER_IP

    # Ressources minimales imposees (1 CPU, 512 ou 1024 Mo).
    server.vm.provider "virtualbox" do |vb|
      vb.name   = SERVER_NAME   # nom de la VM dans VirtualBox
      vb.cpus   = 1
      vb.memory = 1024
    end

    # Provisioning : on delegue toute l'install a un script (bonne pratique,
    # plutot que d'empiler du shell inline dans le Vagrantfile).
    # On passe l'IP en argument pour que le script sache a quoi se lier.
    server.vm.provision "shell", path: "scripts/server.sh", args: [SERVER_IP]
  end

  # ---------- WORKER : K3s en mode agent ----------
  config.vm.define WORKER_NAME do |worker|
    worker.vm.hostname = WORKER_NAME
    worker.vm.network "private_network", ip: WORKER_IP

    worker.vm.provider "virtualbox" do |vb|
      vb.name   = WORKER_NAME
      vb.cpus   = 1
      vb.memory = 1024
    end

    # L'agent a besoin de l'IP du server + du token (voir worker.sh).
    worker.vm.provision "shell", path: "scripts/worker.sh", args: [SERVER_IP, WORKER_IP]
  end
end
```

**Points cles :**

- `config.vm.define` = pattern multi-machines. Vagrant demarre les VMs dans l'ordre de definition (server puis worker), donc le token du server existe avant que le worker en ait besoin.
- SSH sans password : Vagrant le configure tout seul (cle inseree a la creation). Aucune action de ta part, c'est deja "modern practice".
- `args:` passe les IPs au script : pas de valeur en dur dans le shell, tout vient du Vagrantfile.

---

## 2. scripts/server.sh (commenté)

```bash
#!/bin/bash
set -e

SERVER_IP="$1"

# Detecte automatiquement l'interface reseau qui porte l'IP du reseau prive.
# Evite le piege eth0 vs eth1 vs enp0s8 (le sujet previent la-dessus).
IFACE=$(ip -o -4 addr show | awk -v ip="$SERVER_IP" '$0 ~ ip {print $2}')

# Install K3s en mode server.
#   --node-ip / --flannel-iface : force K3s a utiliser le reseau prive,
#     PAS l'interface NAT de Vagrant (sinon le worker ne rejoint pas).
#   --write-kubeconfig-mode=644 : rend le kubeconfig lisible par l'user vagrant
#     (sinon 'kubectl get nodes' exige sudo).
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --node-ip=${SERVER_IP} \
  --flannel-iface=${IFACE} \
  --write-kubeconfig-mode=644" sh -

# Attendre que le token soit genere, puis le copier dans le dossier synchronise
# /vagrant (partage entre l'hote et les 2 VMs) pour que le worker le lise.
while [ ! -f /var/lib/rancher/k3s/server/node-token ]; do sleep 2; done
cp /var/lib/rancher/k3s/server/node-token /vagrant/node-token

# Confort : kubectl trouve le kubeconfig automatiquement a chaque login.
echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" >> /home/vagrant/.bashrc
```

---

## 3. scripts/worker.sh (commenté)

```bash
#!/bin/bash
set -e

SERVER_IP="$1"
WORKER_IP="$2"

IFACE=$(ip -o -4 addr show | awk -v ip="$WORKER_IP" '$0 ~ ip {print $2}')

# Attendre que le server ait depose le token dans /vagrant.
while [ ! -f /vagrant/node-token ]; do sleep 2; done
TOKEN=$(cat /vagrant/node-token)

# Install K3s en mode agent :
#   K3S_URL pointe sur l'API du server (port 6443) -> bascule auto en mode agent.
#   K3S_TOKEN authentifie le join.
curl -sfL https://get.k3s.io | K3S_URL="https://${SERVER_IP}:6443" \
  K3S_TOKEN="${TOKEN}" \
  INSTALL_K3S_EXEC="agent \
  --node-ip=${WORKER_IP} \
  --flannel-iface=${IFACE}" sh -
```

**Le token, c'est quoi :** un secret partage genere par le server. L'agent le presente pour prouver qu'il a le droit de rejoindre le cluster. Ici on le transporte via le dossier synchronise `/vagrant`. Ajoute `node-token` a un `.gitignore` : un secret ne se commit pas.

---

## 4. Lancer et verifier

```bash
cd p1
vagrant up                       # cree et provisionne les 2 VMs (quelques minutes)

# Se connecter au server et verifier le cluster
vagrant ssh login S              # ou: vagrant ssh <SERVER_NAME>
kubectl get nodes -o wide
```

**Resultat attendu (critere de succes) :**

```text
NAME       STATUS   ROLES                  AGE   VERSION
loginS     Ready    control-plane,master   2m    v1.xx.x+k3s1
loginSW    Ready    <none>                 1m    v1.xx.x+k3s1
```

2 nodes `Ready` : un `control-plane` (server), un worker (`<none>`). Part 1 validee.

---

## 5. Debug rapide

- **`vagrant up` refuse l'IP 192.168.56.x** : VirtualBox restreint les host-only networks. Ajouter `* 192.168.56.0/21` dans `/etc/vbox/networks.conf` (le creer si absent), puis relancer.
- **Le worker reste `NotReady` ou n'apparait pas** : quasi toujours un probleme d'interface/IP. Verifier que K3s ecoute bien sur 192.168.56.110 (`vagrant ssh <server> -c "sudo ss -tlnp | grep 6443"`) et que `--flannel-iface` pointe la bonne interface (`ip -o -4 addr`).
- **`kubectl` demande sudo / connection refused** : le kubeconfig n'est pas lu. Verifier `--write-kubeconfig-mode=644` et `echo $KUBECONFIG`.
- **Rejouer le provisioning sans tout recreer** : `vagrant provision`. Repartir de zero : `vagrant destroy -f && vagrant up`.

---

## Ce que tu as reexploite ici

- Modele **manager/worker** = ton manager/worker Swarm.
- Le **provisioning shell** = le meme reflexe qu'Ansible (decrire l'install, pas la faire a la main).

## Ce qui etait neuf

- **Vagrant** (multi-machines, reseau prive, dossier synchronise).
- L'install **K3s** server/agent et le **join via token**.
- Premier contact avec **`kubectl`**.
