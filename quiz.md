# Quiz — bases & notions du projet IoT

> But : verifier AVANT de coder que (A) les bases sur lesquelles on s'appuie sont solides,
> et (B) que les notions nouvelles sont ancrees. Sert aussi de prep a la soutenance.
> Reponds de tete, puis compare au corrige en bas. Ne le regarde pas avant d'avoir repondu.

## Partie A — bases que tu as deja (a reactiver)

1. En Swarm tu deploies un service avec N replicas. Quel objet K8s joue ce role, et quel objet gere concretement les replicas en dessous ?
2. Tes Pods meurent et renaissent avec des IP qui changent. Quel objet K8s donne une adresse stable pour joindre un groupe de Pods ?
3. Router app1.com / app2.com / defaut sur une seule IP : quel objet K8s fait ca, et quel composant deja embarque dans K3s l'execute ?
4. "Part 1, c'est surtout de l'ops" : ops, ca veut dire quoi ?

## Partie B — notions nouvelles (a ancrer)

5. Difference K3s / K3d en une phrase.
6. En GitOps, ou vit la "verite" de ce qui doit tourner dans le cluster, et qui se charge de faire correspondre le cluster a cette verite ?
7. CD classique (un Jenkins qui fait `kubectl apply` vers le cluster) vs GitOps : dans chaque cas, qui initie le deploiement (qui pousse vers qui) ?

---

## Corrige (ne regarder qu'apres avoir repondu)

1. Le **Deployment** (declare l'etat desire). En dessous, c'est le **ReplicaSet** (cree par le Deployment) qui maintient le nombre de replicas.
2. Le **Service** : une IP / un nom DNS stable devant un groupe de Pods, selectionnes par label. Il masque le fait que les Pods vont et viennent.
3. L'**Ingress** (regles de routing HTTP L7 par Host). Il est execute par le **Traefik embarque** dans K3s (Ingress controller par defaut).
4. **Ops = operations** : administration / exploitation systeme (installer, configurer, faire tourner et maintenir l'infra). Par opposition au dev (code applicatif). DevOps = Dev + Ops.
5. **K3s** = distribution Kubernetes legere, un binaire qui tourne directement sur la machine. **K3d** = ce meme K3s empaquete dans des conteneurs Docker (chaque node = un conteneur).
6. La verite vit dans **Git** (etat desire). L'**agent Argo CD** reconcilie en continu l'etat reel du cluster avec Git (reconciliation loop).
7. **CD classique = push** : le pipeline (CI) pousse vers le cluster depuis l'exterieur (`kubectl apply`), c'est le CI qui initie. **GitOps = pull** : un agent DANS le cluster tire depuis Git et applique, c'est l'agent qui initie.
