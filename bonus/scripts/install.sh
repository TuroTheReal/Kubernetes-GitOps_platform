#!/bin/bash
set -e

#install docker if not installed
if ! command -v docker > /dev/null; then
    echo "Installing docker..."
    curl -fsSL https://get.docker.com | sh
fi

#add current user to docker group
sudo usermod -aG docker $USER

#install kubectl if not installed
if ! command -v kubectl > /dev/null; then
    echo "Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
fi

#install k3d if not installed
if ! command -v k3d > /dev/null; then
    echo "Installing k3d..."
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
fi

#create k3d cluster if not exists
if ! sg docker -c "k3d cluster get iot" > /dev/null 2>&1; then
    echo "Installing k3d cluster..."
    sg docker -c 'k3d cluster create iot -p "8888:8888@loadbalancer" -p "80:80@loadbalancer"'
fi

#create namespaces if not exists
if ! kubectl get namespace argocd > /dev/null 2>&1; then
    echo "Creating argocd namespace..."
    kubectl create namespace argocd
fi
if ! kubectl get namespace dev > /dev/null 2>&1; then
    echo "Creating dev namespace..."    
    kubectl create namespace dev
fi

#install argocd if not installed
if ! kubectl get deployment -n argocd argocd-server > /dev/null 2>&1; then
    echo "Installing ArgoCD..."
    kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
fi

kubectl wait --for=condition=available deployment --all -n argocd --timeout=300s

#create argocd application (TODO etape 6 : application.yaml encore vide)
#kubectl apply -f "$(dirname "$0")/../confs/application.yaml"

#create gitlab namespace if not exists
if ! kubectl get namespace gitlab > /dev/null 2>&1; then
    echo "Creating gitlab namespace..."
    kubectl create namespace gitlab
fi

#install gitlab
echo "Installing GitLab (3-5 min)..."
kubectl apply -f "$(dirname "$0")/../confs/gitlab.yaml"
kubectl wait --for=condition=available deployment/gitlab -n gitlab --timeout=900s

#show gitlab root password
echo "GitLab root password:"
kubectl exec -n gitlab deploy/gitlab -- grep 'Password:' /etc/gitlab/initial_root_password

#show argocd admin password
echo "ArgoCD admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

#ArgoCD UI (run manually, blocks the terminal):
#kubectl port-forward svc/argocd-server -n argocd 8080:443 --address 0.0.0.0
#then on the PC: https://192.168.57.10:8080 (user: admin)

