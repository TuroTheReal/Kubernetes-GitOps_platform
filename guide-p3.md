# Guide pas-à-pas — Part 3 : K3d + Argo CD (GitOps)

> Objectif : cluster K3d + Argo CD qui deploie une app depuis un repo GitHub public,
> et resynchronise seul quand tu changes la version dans Git.
> Critere de succes : bump v1 -> v2 sur GitHub => l'app se met a jour toute seule.

C'est **le coeur du sujet**. Relis "GitOps" et "K3s vs K3d" dans [note.md](note.md).

## Deux repos differents (a bien distinguer)

1. **Ce repo** (`Kubernetes-GitOps_platform`) : contient `p3/` avec le script d'install et le manifest de l'Application Argo CD.
2. **Un repo GitHub PUBLIC separe** (login dans le nom) : contient le `deployment.yaml` de l'app. C'est CE repo qu'Argo CD surveille. Git = source de verite.

## Structure du dossier `p3`

```text
p3/
├── scripts/
│   └── install.sh          # docker + k3d + kubectl + cluster + namespaces + argocd
└── confs/
    └── application.yaml     # l'objet Application Argo CD
```

Et dans le **repo app separe** :

```text
<repo-app>/
└── deployment.yaml         # Deployment + Service de wil42/playground
```

---

## 1. scripts/install.sh (tout ce qu'il faut, executable en defense)

```bash
#!/bin/bash
set -e

# 1. Docker (K3d en a besoin : chaque node K3d est un conteneur Docker)
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker "$USER"   # relogin necessaire pour l'appliquer
fi

# 2. kubectl (version stable officielle)
if ! command -v kubectl >/dev/null 2>&1; then
  curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  rm -f kubectl
fi

# 3. K3d
if ! command -v k3d >/dev/null 2>&1; then
  curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
fi

# 4. Cluster K3d
k3d cluster create iot

# 5. Les 2 namespaces exiges
kubectl create namespace argocd
kubectl create namespace dev

# 6. Argo CD (manifest d'install officiel)
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 7. Attendre qu'Argo CD soit pret
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

echo "Argo CD pret. Mot de passe admin :"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d ; echo
```

---

## 2. Le manifest de l'app (dans le repo GitHub SEPARE)

`deployment.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wil-playground
  namespace: dev
spec:
  replicas: 1
  selector:
    matchLabels:
      app: wil-playground
  template:
    metadata:
      labels:
        app: wil-playground
    spec:
      containers:
        - name: wil-playground
          image: wil42/playground:v1     # <-- la version qu'on changera en v2
          ports:
            - containerPort: 8888
---
apiVersion: v1
kind: Service
metadata:
  name: wil-playground
  namespace: dev
spec:
  selector:
    app: wil-playground
  ports:
    - port: 8888
      targetPort: 8888
```

Pousse ce fichier sur un repo GitHub **public** (login dans le nom).

---

## 3. confs/application.yaml (l'Application Argo CD)

C'est l'objet qui dit a Argo CD : "surveille ce repo, deploie-le dans `dev`, garde tout synchronise".

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: playground
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/<login>/<repo-app>.git   # <-- ton repo app public
    targetRevision: HEAD
    path: .                    # dossier contenant deployment.yaml (racine ici)
  destination:
    server: https://kubernetes.default.svc
    namespace: dev
  syncPolicy:
    automated:
      prune: true              # supprime ce qui n'est plus dans Git
      selfHeal: true           # recorrige si le cluster derive (la reconciliation loop)
    syncOptions:
      - CreateNamespace=true
```

Applique-le :

```bash
kubectl apply -f confs/application.yaml
```

`selfHeal: true` + `prune: true` = la boucle de reconciliation active : Argo CD force en permanence le cluster a correspondre a Git.

---

## 4. Acceder aux interfaces (port-forward)

```bash
# UI Argo CD (login: admin, mdp: celui affiche par install.sh)
kubectl port-forward svc/argocd-server -n argocd 8080:443
# -> https://localhost:8080

# L'application
kubectl port-forward svc/wil-playground -n dev 8888:8888
# -> curl http://localhost:8888
```

Verif :

```bash
kubectl get ns                 # argocd + dev presents
kubectl get pods -n dev        # wil-playground Running
curl http://localhost:8888     # {"status":"ok","message":"v1"}
```

---

## 5. Le test GitOps (le moment cle de la defense)

Dans le **repo app separe**, change la version puis push :

```bash
sed -i 's/playground:v1/playground:v2/' deployment.yaml
git commit -am "bump v2"
git push
```

Sans rien faire d'autre, Argo CD detecte le changement dans Git et resynchronise le cluster :

```bash
curl http://localhost:8888     # {"status":"ok","message":"v2"}
```

**Critere de succes** : le simple `git push` a fait passer l'app de v1 a v2, prouve par le `curl`. Tu n'as jamais fait de `kubectl apply` a la main pour l'app. Sache expliquer a l'oral : Git = etat desire, Argo CD reconcilie (pull), vs un CD classique qui pousserait (push).

---

## Debug rapide

- **Application `OutOfSync` / `Unknown`** : mauvais `repoURL` ou `path`. Verifier dans l'UI Argo CD l'onglet de l'app (message d'erreur explicite).
- **Le repo n'est pas lu** : il doit etre **public** (sinon il faut configurer des credentials).
- **`port-forward` coupe** : il faut le relancer, il ne tient que le temps de la commande. Ou exposer via NodePort.
- **v2 ne s'applique pas** : `selfHeal`/`automated` absent -> Argo CD attend un sync manuel. Verifier `syncPolicy.automated`.
- **`docker` permission denied** : le `usermod -aG docker` exige un relogin (ferme/rouvre la session).

---

## Reutilise / neuf

- **Reutilise** : Docker (K3d = K3s en conteneurs), les manifests YAML de P2, Git.
- **Neuf** : K3d, Argo CD, la boucle de reconciliation, le flux GitOps de bout en bout.
