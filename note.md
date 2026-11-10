# Notes — Inception-of-Things (IoT)

> Fiche de concepts du projet. A remplir au fil de l'apprentissage, puis a extraire vers le vault.

## Definitions cles

**Ops (operations)** : l'exploitation / administration systeme. Installer, configurer, faire tourner et maintenir l'infra (paquets, VMs, reseau, SSH, scripts). Par opposition au dev (code applicatif) et au conceptuel. DevOps = trait d'union Dev + Ops.

**GitOps (version enfant)** : un cahier magique (Git) liste ce qui doit tourner dans la chambre (le cluster). Un robot (Argo CD) compare la chambre au cahier en continu et corrige tout ecart. On ne range jamais la chambre a la main : on modifie le cahier (`git push`), le robot fait le reste.

**GitOps (version technique)** : Git est la source de verite unique de l'etat desire ; un agent reconcilie en continu l'etat reel du cluster avec cet etat desire (reconciliation loop).

**Push CD vs Pull GitOps** :

- CD classique (Jenkins/GitHub Actions) : le pipeline POUSSE vers le cluster (`kubectl apply` depuis l'exterieur). Le cluster subit.
- GitOps : un agent DANS le cluster TIRE depuis Git et applique. Le cluster va chercher sa verite. Avantages : pas de credentials cluster exposes au CI, drift corrige automatiquement, Git = audit/rollback.

**K3s vs K3d** :

- K3s = distribution Kubernetes legere, un binaire qui tourne directement sur la machine (VM).
- K3d = ce meme K3s empaquete dans des conteneurs Docker (chaque node = un conteneur). Plus jetable, ideal local/CI.

---

## Le pont Swarm -> K8s (mon levier principal)

| Je maitrise (Swarm/Traefik) | Equivalent K8s | Effort |
| --- | --- | --- |
| `docker service` | Deployment (+ ReplicaSet) | quasi nul |
| replicas distribues | `replicas:` du Deployment | quasi nul |
| manager / worker | control-plane / worker (K3s server / agent) | faible |
| rolling update Swarm | Deployment `strategy: RollingUpdate` | faible |
| overlay network + routing mesh | Service (ClusterIP) + kube-proxy | moyen |
| Traefik par labels Docker | Ingress (objet YAML), Traefik embarque dans K3s | moyen |
| `docker-compose.yml` | manifests YAML (`kind: ...`) | faible |
| secrets Swarm | Secrets / ConfigMaps | faible |
| (rien) | Pod, Namespace | from scratch |
| (rien) | `kubectl` | from scratch |
| (rien) | Argo CD / reconciliation loop | investissement principal |

---

## Objets K8s essentiels (a maitriser en P2)

- **Pod** : la plus petite unite deployable (1+ conteneurs qui partagent reseau/stockage). Ephemere, IP qui change.
- **Deployment** : declare l'etat desire d'un ensemble de Pods (image, replicas, strategie de mise a jour). Cree un ReplicaSet qui maintient le compte de Pods.
- **Service** : adresse reseau stable (IP/nom DNS) devant un groupe de Pods. Resout le probleme "les Pods vont et viennent".
- **Ingress** : regles de routing HTTP L7 (par Host / path) vers des Services. Execute par un Ingress controller (Traefik dans K3s).
- **Namespace** : cloisonnement logique des objets dans le cluster (ex. `argocd`, `dev`).

---

## Commandes kubectl a connaitre

```bash
kubectl get nodes                      # verif Part 1 (2 nodes Ready)
kubectl get pods -n <namespace>        # lister les pods d'un namespace
kubectl get ns                         # lister les namespaces
kubectl apply -f <fichier.yaml>        # appliquer un manifest
kubectl describe <type> <nom>          # detail / debug d'un objet
kubectl logs <pod>                     # logs d'un pod
kubectl get pods -n kube-system | grep traefik   # verif Traefik embarque
kubectl get nodes -o wide              # P1 : nodes + leurs IPs (verifier 192.168.56.x)
kubectl get all -n <namespace>         # tout voir d'un coup (pods, services, deployments)
kubectl get ingress                    # P2 : montrer l'Ingress (demande en defense)
kubectl delete -f <fichier.yaml>       # supprimer ce qu'un manifest a cree
```

## Commandes Vagrant a connaitre

A lancer depuis le dossier qui contient le `Vagrantfile`.

```bash
export VAGRANT_HOME=/goinfre/$USER/.vagrant.d   # boxes sur goinfre (home trop petit) #propore au projet ne pas mettre dans vault.

vagrant up                       # creer + demarrer + provisionner les VMs
vagrant status                   # etat des VMs (running, poweroff, not created)
vagrant ssh <nom>                # entrer dans une VM (ex: vagrant ssh artbernaS)
vagrant ssh <nom> -c "<cmd>"     # lancer une commande dans la VM sans y entrer
vagrant provision                # relancer les scripts sans recreer les VMs
vagrant halt                     # eteindre les VMs (garde le disque)
vagrant destroy -f               # supprimer les VMs (repartir de zero)
vagrant box list                 # boxes telechargees
```

Raccourci P1 : `vagrant ssh artbernaS -c "kubectl get nodes"`

---

## Mini-comprehension (Vagrant / VM / reseau)

- **Vagrant = telecommande**, il ne fait pas tourner les VMs. Le **provider** (VirtualBox, VMware, libvirt, Docker...) les fait tourner.
- **Vagrant vs Terraform** : Vagrant = VMs **locales** jetables (dev, labo). Terraform = **vraie infra** cloud (prod).
- **KVM** = hyperviseur integre au noyau Linux. **libvirt** = outil de gestion au-dessus de KVM. **VirtualBox** = autre hyperviseur
- **K8s dans Docker (K3d)** = dev / CI, rapide, jetable. **K8s dans VM / serveurs** = prod, vrai reseau.
- **K8s s'installe sur CHAQUE machine du cluster** : 1 en mode **server** (le chef), les autres en mode **agent** (= worker) qui le rejoignent avec un token.
- **Vagrantfile** = s'execute sur mon PC, cree le *materiel* (Terraform-like). **Script** = s'execute DANS la VM, installe les *logiciels* (Ansible-like).
- **`config.vm.box`** = global (toutes les VMs). `server.vm.box` dans un bloc = remplace pour cette VM seulement.
- **`do |x| ... end`** = un bloc (comme `{ }` en C). 1 `do` = 1 `end`. L'indentation ne compte pas.
- **Provisioning** = le script de config lance dans la VM. Auto au 1er `vagrant up` seulement. Script modifie -> `vagrant provision`.
- **`inline:`** = script ecrit dans le Vagrantfile. **`path:`** = script dans un fichier (`scripts/`, exige par le sujet).
- **Shebang** = 1re ligne `#!/bin/bash` : dit quel programme execute le script.
- **Chaque VM a 2 cartes reseau** : `eth0` = NAT (10.0.2.15, identique partout, Internet + SSH), `eth1` = reseau prive (192.168.56.x, pour que les VMs se parlent). K3s doit utiliser **eth1**.
- **`ip -4 a`** = affiche les cartes reseau et leurs IPv4.

---

## Docs officielles

- [K3s](https://docs.k3s.io/)
- [K3d](https://k3d.io/)
- [Argo CD](https://argo-cd.readthedocs.io/)
- [Vagrant](https://developer.hashicorp.com/vagrant/docs)
- [Kubernetes concepts](https://kubernetes.io/docs/concepts/)

---

## Quiz de revision

Les questions (groupees bases / notions nouvelles) + le corrige sont dans [quiz.md](quiz.md). A refaire de tete avant de coder et avant la soutenance.
