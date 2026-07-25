# Guide — Bonus : GitLab local + Helm

> Objectif : heberger une instance GitLab locale (namespace `gitlab`) et refaire tourner
> tout le flux de Part 3 en tirant depuis CE GitLab au lieu de GitHub.
> Rappel sujet : le bonus n'est evalue QUE si l'obligatoire (P1-P3) est parfait.

## Avertissements avant de te lancer

- **Ressources** : le chart Helm officiel GitLab est **lourd** (plusieurs Go de RAM, plusieurs pods). Une VM a 1 CPU / 1 Go ne suffit pas. Prevois une VM dediee genereuse (idealement 4+ Go de RAM, 2+ CPU). Le sujet lui-meme dit "Beware this bonus is complex".
- **Helm, c'est quoi** : le "package manager" de Kubernetes. Un *chart* = une appli packagee (tous ses manifests), configurable via un fichier `values`. `helm install` deploie le chart, `helm upgrade` le met a jour. C'est ton concept neuf ici.
- Ce guide donne le squelette. Les valeurs exactes du chart GitLab evoluent : appuie-toi sur la [doc officielle du chart](https://docs.gitlab.com/charts/) plutot que de copier des valeurs en aveugle.

## Structure du dossier `bonus`

```text
bonus/
├── scripts/
│   └── install.sh          # helm + gitlab
└── confs/
    ├── values.yaml         # config du chart GitLab
    └── application.yaml     # Application Argo CD pointant sur le GitLab local
```

---

## 1. Installer Helm + GitLab

```bash
#!/bin/bash
set -e

# Helm
if ! command -v helm >/dev/null 2>&1; then
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# Namespace dedie
kubectl create namespace gitlab

# Ajouter le repo de charts GitLab
helm repo add gitlab https://charts.gitlab.io/
helm repo update

# Installer GitLab dans le namespace gitlab avec ta config
helm install gitlab gitlab/gitlab \
  --namespace gitlab \
  -f confs/values.yaml \
  --timeout 600s

# GitLab met plusieurs minutes a etre pret. Suivre :
kubectl get pods -n gitlab -w
```

Le `values.yaml` minimal doit au moins definir le domaine et desactiver ce qui est inutile en local (voir la doc du chart). Recupere le mot de passe root initial :

```bash
kubectl get secret gitlab-gitlab-initial-root-password -n gitlab \
  -o jsonpath='{.data.password}' | base64 -d ; echo
```

---

## 2. Basculer Argo CD sur le GitLab local

Une fois GitLab accessible :

1. Cree un projet **public** dans ton GitLab local, pousse-y le `deployment.yaml` (le meme qu'en P3).
2. Modifie l'Application Argo CD pour pointer sur l'URL interne du GitLab local au lieu de GitHub :

```yaml
# bonus/confs/application.yaml (extrait)
spec:
  source:
    repoURL: http://gitlab-webservice-default.gitlab.svc.cluster.local/<user>/<repo>.git
    targetRevision: HEAD
    path: .
```

3. Applique et refais le test GitOps de P3 (bump v1 -> v2, push sur le GitLab local, Argo CD resynchronise).

---

## Critere de succes

Tout le flux de Part 3 fonctionne, mais la source de verite est ton **GitLab local** (namespace `gitlab`), plus GitHub. Le bump de version pousse sur le GitLab local se propage seul au cluster.

## Debug rapide

- **Pods GitLab `Pending`** : manque de ressources (CPU/RAM/disk). C'est la cause n°1. Augmente la VM.
- **Install Helm qui traine** : normal, GitLab prend du temps. Augmente `--timeout`, surveille `kubectl get pods -n gitlab`.
- **Argo CD ne joint pas le GitLab local** : verifie l'URL interne du service (`kubectl get svc -n gitlab`) et que le repo est public.

## Neuf ici

- **Helm** (charts, values, install/upgrade).
- Heberger un service lourd (GitLab) dans le cluster et l'integrer a la chaine GitOps existante.
