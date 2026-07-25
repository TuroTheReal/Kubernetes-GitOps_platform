# Roadmap — Inception-of-Things (IoT)

> Plan d'attaque calibré sur mon knowledge vault (`~/vaults/devops-cloud_vault`).
> Sujet : intro Kubernetes via K3s / K3d + GitOps (Argo CD). Repo 42, dossiers `p1`, `p2`, `p3`, `bonus`.

## Objectif

Construire une plateforme K8s en 3 marches : cluster brut (Vagrant + K3s) -> routing d'apps (Ingress) -> deploiement automatique pilote par Git (K3d + Argo CD = GitOps). Puis bonus GitLab local.

---

## Calibration (ce que je connais deja vs les gaps)

**Acquis a reexploiter (ne pas reapprendre) :** Docker, Docker Swarm (services, replicas, rolling updates, overlay networks, manager/worker), Traefik (routing dynamique), networking L3/L4/L7, deployment strategies, Git, mindset IaC (Terraform/Ansible).

**Gaps a investir :** modele objet Kubernetes + `kubectl`, K3s vs K3d, Argo CD / GitOps (reconciliation loop), Vagrant, Helm (bonus).

Regle : effort inverse a la familiarite. Survoler P1, prendre le temps sur les objets en P2, investir vraiment P3 (GitOps).

---

## Environnement (contrainte materielle, verifiee)

Le sujet impose de tout faire dans une VM. Mais P1/P2 lancent Vagrant qui cree 2 vraies VMs : il faut de la virtualisation materielle (VT-x/AMD-V). Diagnostic fait :

- **orion (VPS Hetzner Cloud, CPX/CX)** : PAS de nested virtualization (`kvm-ok` = KO, `vmx/svm` = 0, `modprobe kvm_intel` = Operation not supported). Verrouille cote hebergeur, non activable. Docker deja installe.
- **Machines 42** : x86 avec VirtualBox, virtu materielle dispo.

Repartition figee :

| Parts | Machine | Provider / techno |
| --- | --- | --- |
| P1, P2 | Machines 42 | Vagrant + VirtualBox |
| P3, bonus | orion (Hetzner Cloud) | Docker / K3d (pas de VM imbriquee) |

---

## Prerequis

- [x] Provider P1/P2 : Vagrant + VirtualBox sur machines 42 (orion / Hetzner Cloud incapable de nested virt)
- [ ] `kubectl` installe sur la machine de travail
- [ ] Docs ouvertes :
  - [K3s](https://docs.k3s.io/)
  - [K3d](https://k3d.io/)
  - [Argo CD](https://argo-cd.readthedocs.io/)
  - [Vagrant](https://developer.hashicorp.com/vagrant/docs)
  - [Kubernetes (concepts)](https://kubernetes.io/docs/concepts/)
  - [App de test wil42/playground](https://hub.docker.com/r/wil42/playground)

---

## Part 1 — K3s + Vagrant  (dossier `p1`, ~4-6h, surtout ops)

> Guide pas-a-pas detaille (Vagrantfile + scripts commentes) : [guide-p1.md](guide-p1.md)

Neuf : Vagrant, install K3s server/agent, join worker via token.
Reexploite : modele manager/worker (= Swarm), provisioning (bloc shell du Vagrantfile).

- [ ] `Vagrantfile` : 2 VMs `<login>S` (192.168.56.110) et `<login>SW` (192.168.56.111), 1 CPU / 512-1024 MB, reseau prive, SSH sans password
- [ ] Provisioning : install K3s mode server sur `<login>S`, recuperer le node-token
- [ ] Provisioning : install K3s mode agent sur `<login>SW` pointant IP server + token
- [ ] `kubectl` installe et fonctionnel

**Critere de succes :** `kubectl get nodes` montre 2 nodes `Ready` (1 control-plane, 1 worker).
**Piege :** interfaces reseau modernes (enp0s8...), pas eth0. Lier K3s a 192.168.56.110, pas au NAT Vagrant.

---

## Part 2 — K3s + 3 apps + Ingress  (dossier `p2`, ~6-10h, modele objet K8s)

> Guide pas-a-pas detaille : [guide-p2.md](guide-p2.md)

C'est ici que j'apprends le modele objet : Pod -> Deployment -> Service -> Ingress + Namespace.

- [ ] 1 VM, K3s mode server
- [ ] 3 apps : pour chacune un Deployment + un Service (app2 avec `replicas: 3`)
- [ ] 1 Ingress routant par Host : app1.com -> app1, app2.com -> app2, defaut -> app3, sur 192.168.56.110
- [ ] Verifier le Traefik embarque : `kubectl get pods -n kube-system | grep traefik`

**Critere de succes :** `curl -H "Host: app1.com" http://192.168.56.110` (idem app2/defaut) renvoie la bonne app ; `kubectl get pods` montre 3 replicas pour app2 ; savoir montrer l'Ingress (exige en defense).
**Pont Traefik :** l'Ingress est consomme par le Traefik embarque dans K3s. Je passe de "routing par labels Docker" a "routing par objet Ingress" : meme moteur, autre declaration.

---

## Part 3 — K3d + Argo CD  (dossier `p3`, ~8-12h, GITOPS = le coeur)

> Guide pas-a-pas detaille : [guide-p3.md](guide-p3.md)

Distinction a ancrer (tombe en defense) : K3s = binaire sur la machine ; K3d = ce meme K3s empaquete dans des conteneurs Docker (chaque node = un conteneur), plus jetable, ideal CI/local.

- [ ] Script d'install (Docker, K3d, kubectl) executable en defense
- [ ] Creer le cluster K3d
- [ ] 2 namespaces : `argocd` (installer Argo CD dedans) et `dev`
- [ ] Repo GitHub PUBLIC (login dans le nom) avec le manifest de l'app (`deployment.yaml`, `wil42/playground:v1`, port 8888)
- [ ] Application Argo CD pointant sur le repo -> namespace `dev`, auto-sync
- [ ] Test GitOps : bump v1 -> v2 dans le YAML sur GitHub, push, verifier resync auto

**Critere de succes :** le bump de version sur GitHub se propage seul au cluster, prouve par `curl localhost:8888` -> `"message": "v2"`. Savoir expliquer la reconciliation loop a l'oral (pull GitOps vs push CD classique).

---

## Bonus — GitLab local + Helm  (dossier `bonus`, ~10h+)  [ENGAGE]

> Guide detaille : [guide-bonus.md](guide-bonus.md)

- [ ] Instance GitLab locale (namespace `gitlab`), install via Helm
- [ ] Reconfigurer Part 3 pour tirer depuis le GitLab local au lieu de GitHub
- [ ] Tout Part 3 fonctionne avec le GitLab local

**Contrainte de notation :** le bonus n'est evalue QUE si l'obligatoire est parfait (P1-P3 completes, zero bug). Mandatory-first, toujours.

---

## Sorties vault (a produire au fil de l'eau)

- [ ] `MOCs/MOC-Kubernetes-Fundamentals.md`
- [ ] `concepts/kubernetes/k8s-object-model.md`, `.../k3s-vs-k3d.md`
- [ ] `concepts/ci-cd/gitops-argocd.md` (reconciliation loop, push vs pull)
- [ ] `projects/2026-07-inception-of-things.md` (fiche projet)

---

## Ordre

Sequentiel impose : P1 -> P2 -> P3 -> bonus.
