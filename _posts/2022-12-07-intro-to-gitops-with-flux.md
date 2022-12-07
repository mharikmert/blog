---
layout: post
title: Introduction to GitOps with Flux on Kubernetes
permalink: /intro-to-gitops-with-flux/
---
There are many ways to manage your Kubernetes cluster, but one of the most popular ways and the one we'll be looking at in this post is [GitOps](https://www.weave.works/technologies/gitops/).

### What is GitOps? ###

GitOps is a way of managing your infrastructure by using Git as a single source of truth for your <strong>desired state</strong>. This means that you can use Git to manage your cluster by keeping your cluster in sync with your repository. This allows you to creating new resources, updating existing resources, and deleting resources by simply committing changes to the repository.

 To briefly mention about the <strong>desired state</strong>, it is the state that you want your cluster to be in. For example, you might want to have a deployment with 3 replicas, or you might want to have a service with a specific port. These are all examples of the desired state.

So, how can we practically use <strong>GitOps </strong>to manage our cluster? That's where <strong>Flux</strong> comes in.

### What is Flux? ###

Flux is a GitOps operator for Kubernetes, which means that it can keep your cluster in sync with your Git repository by continuously reconciling the cluster state with the desired state that you have specified in your Git repository.

In this post, we'll be looking at how to use Flux to manage your Kubernetes cluster using GitOps.

### Prerequisites ###

To follow along with this post, you'll need:

- A Kubernetes cluster. You can use [kind](https://kind.sigs.k8s.io/) to create a local cluster for testing.
- [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl) installed and configured to connect to your cluster.

### Installing Flux ###

Linux and macOS users can install Flux using the following command:

```bash
curl -s https://fluxcd.io/install.sh | sudo bash
```

Windows users can install Flux using [Chocolatey](https://chocolatey.org/):

```powershell
choco install flux
```

### Bootstrapping Flux on your cluster ###

To bootstrap Flux, you can use [`flux bootstrap`](https://fluxcd.io/flux/cmd/flux_bootstrap/) command, which will create a Git repository for you if it doesn't already exist. The repository will contain the Flux manifests, and a sample workload. This command can be used for GitHub, GitLab, and Bitbucket. For this post, we'll be using GitHub.

To authenticate with GitHub, you'll need to create a [personal access token](https://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token) with the `repo` scope. You can export this as an environment variable to allow Flux to use it:

```bash
export GITHUB_TOKEN=<token>
export GITHUB_USER=<username>
```

```bash
flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=<repository-name> 
  --branch=master \
  --path=./clusters/my-cluster \ 
  --personal
```

![flux-bootstrap](https://user-images.githubusercontent.com/42295478/205458288-bfd5d503-7b36-44ee-9cb3-e2524a0c46ae.png)

- This command will create a `flux-system` namespace, and deploy the Flux components to the cluster using the manifests in the `clusters/my-cluster` directory. This directory will be created in the repository you specified.
- This command will also create two [custom resources](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/) by default, which are a `GitRepository` and a `Kustomization`.
    - [`GitRepository`](https://fluxcd.io/flux/components/source/gitrepositories/) resource points to the repository that Flux is watching.
    - [`Kustomization`](https://fluxcd.io/flux/components/kustomize/kustomization/) resource points to the directory that Flux should apply to the cluster by referencing the `GitRepository` resource.

Once the Flux components have been deployed to the cluster, you can check the status of the `GitRepository` and `Kustomization` resources using the following command:

```bash
kubectl get gitrepositories,kustomizations -n flux-system
```

### Deploying an application ###

Now Flux is installed and configured, we can deploy an application to our cluster. We'll use the [blog](https://github.com/mharikmert/blog) application that you're currently reading for this example.

### Creating the manifests ###

To deploy the application, we'll need to create the manifests for the application. We'll create a file called `blog.yaml` with the following contents:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: blog-deploy
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: blog
  template:
    metadata:
      labels:
          app: blog
    spec:
      containers:
      - name: blog
        image: ghcr.io/mharikmert/blog:v0.0.12
---
apiVersion: v1
kind: Service
metadata:
  name: blog-svc
  namespace: default
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 80
  selector:
      app: blog
```

This manifest will create a deployment and a service for the blog application.

### Committing the manifests ###

Now that we've created the manifests, we can commit them to our repository:

```bash
git add blog.yaml
git commit -m "Add blog application"
git push
```

### Checking the status ###

Now that we've pushed the changes to our repository, Flux should apply the changes to the cluster. We can check the status of the kustomization to see if the changes that we made have been applied to the cluster:

```bash
flux get kustomizations
```

or

```bash
kubectl get kustomizations -n flux-system
```

This command will show us the status of the kustomization. If everything is working correctly, we should see the `STATUS` of the kustomization as `Applied` and the `READY` condition as `True`:

![kustomizations](https://user-images.githubusercontent.com/42295478/205511968-d2d79a00-2d4f-49c4-ba9f-3a336b805d9f.png)

We can also check the status of the deployment using:

```bash
kubectl get deployments,svc -n default
```

This command will show us the status of the deployment. If everything is working correctly, we should see the following output:

![get-deploy-svc](https://user-images.githubusercontent.com/42295478/205512493-b49bbde9-7dfe-42fc-81be-e82854516ba8.png)

### Conclusion ###

In this post, we've introduced GitOps with Flux, and looked at how to use Flux to manage your Kubernetes cluster. Flux is a powerful tool that can help you to manage your cluster, and we've only scratched the surface of what it can do. If you want to learn more about Flux, check out the [official documentation](https://fluxcd.io/docs/).

### Further reading ###

- [GitOps](https://www.gitops.tech)
- [Guide to GitOps](https://www.weave.works/technologies/gitops/)
- [Flux Documentation](https://fluxcd.io/flux/)
- [Flux GitHub Repository](https://github.com/fluxcd/flux2)
- [Flux in Weaveworks](https://www.weave.works/oss/flux)