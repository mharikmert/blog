---
layout: post
title: "From GitOps to Continuous Delivery: Using FluxCD to Automate Kubernetes Deployments"
permalink: /continuous-delivery-with-fluxcd/
---

### Introduction ###

In the previous [post](/intro-to-gitops-with-flux/), we've introduced the concept of GitOps and looked at how to use Flux to manage your Kubernetes cluster using GitOps. If you are new to GitOps and Flux, I recommend that you read the previous post before continuing with this one.  

In this post, we'll be looking at how to use FluxCD to perform continuous delivery in your Kubernetes cluster.

### Prerequisites ###

To follow along with this post, you'll need:

- A Kubernetes cluster. You can use [kind](https://kind.sigs.k8s.io/) to create a local cluster for testing.
- [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl) installed and configured to connect to your cluster.
- [Flux CLI](https://fluxcd.io/docs/installation/) installed.

### Bootstrapping Flux ###

We will use the same repository that we created in the previous post, but we will reboostrap Flux with a different set of components. We will be using the `--components-extra` flag to add the `image-reflector-controller` and `image-automation-controller` components to the default set of components. These components will allow us to automate the deployment of our workloads.

- `image-reflector-controller` scans image repositories and reflects the image metadata in Kubernetes resources.
- `image-automation-controller` updates YAML files based on the latest images scanned, and commits the changes to a given Git repository.

![image-update-automation](https://user-images.githubusercontent.com/42295478/212482135-ff225221-83a7-4565-bf68-ffe4ce668411.png)

If you use `bootstrap` command more than once in the same cluster, Flux will overwrite the existing manifests in the repository with the new ones.

```bash
flux bootstrap github \
  --components-extra=image-reflector-controller,image-automation-controller \
  --owner=$GITHUB_USER \
  --repository=intro-to-gitops-with-flux-demo \
  --branch=master \
  --path=./clusters/my-cluster \
  --read-write-key \ # This flag is required for the write access to the repository.
  --personal
```

![flux-bootstrap](https://user-images.githubusercontent.com/42295478/212529583-816cacbf-dda8-4e50-8537-fdeed43a791c.png)

After bootstrap is complete, Flux will update our manifests in the repository by adding the `image-reflector-controller` and `image-automation-controller` components.

If you bootstrap Flux for the first time, you will also see the deployment and service for the blog application that we created in the previous post.

![k get svc,deploy](https://user-images.githubusercontent.com/42295478/212532424-9059374e-356e-451f-9e4a-fe2cad936f2a.png)

### Creating Manifests for Image Update Automation ###

As we've seen in the diagram above, Flux will need a few resources to perform image update automation. These resources are:

- `image-repository` resource that defines the container registry to scan.
- `image-policy` resource that defines [semver range](https://semver.org/) to use when filtering tags.
- `image-update-automation` resource that defines the required configuration to commit the changes to the Git repository and perform image updates.
- `git-repository` resource that defines the Git repository to commit the changes. (This resource is created by Flux during bootstrap.)

We will use the `flux create` command to create these resources instead of creating them manually. We will also use the `--export` flag to export the manifests to a file instead of applying them to the cluster.

```bash
flux create image repository blog-image-repository \
  --image=ghcr.io/mharikmert/blog \
  --interval=1m \
  --export > ./clusters/my-cluster/blog/image-repository.yaml
```

```bash
flux create image policy blog-image-policy \
  --image-ref=blog-image-repository \
  --select-semver="0.0.x" \
  --export > ./clusters/my-cluster/blog/image-policy.yaml

```

```bash
flux create image update automation image-update-automation \
  --git-repo-ref=flux-system \
  --git-repo-path="./clusters/my-cluster" \
  --checkout-branch=master \
  --push-branch=master \
  --author-name=fluxcdbot \
  --author-email=fluxcdbot@users.noreply.github.com \
  {% raw %}--commit-template="{{range .Updated.Images}}{{println .}}{{end}}" \{% endraw %}
  --export > ./clusters/my-cluster/flux-system/image-update-automation.yaml
```

![flux-create-manifests](https://user-images.githubusercontent.com/42295478/212532420-4bc11098-ec1c-4eac-9c90-3d3874b16ccd.png)

After creating the manifests, the folder structure should look like this:

```bash
├── clusters
│   └── my-cluster
│       ├── blog
│       │   ├── blog-image-repository.yaml
│       │   ├── blog-image-policy.yaml
│       │   └── blog.yaml
│       └── flux-system
│           ├── gotk-components.yaml
│           ├── gotk-sync.yaml
│           ├── kustomization.yaml
│           └── image-update-automation.yaml
└── README.md
```

Since we are using the same folder for the image update automation with flux components, we need to add the `image-update-automation.yaml` to the `kustomization.yaml` file as a resource. If we used the same folder with the blog application, we wouldn't need to do this. We do so because we will be using the same `image-update-automation` for other applications as well.

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - gotk-components.yaml
  - gotk-sync.yaml
  - image-update-automation.yaml
```

Now, our manifests are ready to be applied to the cluster.
As the last step, we will add an image policy marker to the deployment manifest of our blog application. This marker will be used by the `image-automation-controller` to update the image tag of the deployment.

Image policy markers are used to refer to an image policy resource. There are three types of markers:

- `{"$imagepolicy": "<policy-namespace>:<policy-name>"}`
- `{"$imagepolicy": "<policy-namespace>:<policy-name>:tag"}`
- `{"$imagepolicy": "<policy-namespace>:<policy-name>:name"}`

These markers are placed inline in the target YAML, as a comment. The “Setter” strategy refers to [kyaml setters](https://github.com/fluxcd/flux2/discussions/107#discussioncomment-82746) which Flux can find and replace during reconciliation, when directed to do so by an `image-update-automation`.

We will use the first type of marker in our deployment manifest.

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
          image: ghcr.io/mharikmert/blog:v0.0.15 # {"$imagepolicy": "flux-system:blog-image-policy"}
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

### Committing the Manifests ###

Now, we are ready to commit the manifests and push them to the Git repository.
To look over our changes,

- Created `blog-image-repository.yaml` and `blog-image-policy.yaml` files under `clusters/my-cluster/blog` folder.
- Created `image-update-automation.yaml` file under `clusters/my-cluster/flux-system` folder.
- Added `image-update-automation.yaml` file to the `kustomization.yaml` file under `clusters/my-cluster/flux-system` folder.
- Added an image policy marker to the deployment manifest `blog.yaml` under `clusters/my-cluster/blog` folder.

```bash
git add .
git commit -m "Add image repository & image policy & image update automation"
git push
```

### Reconciling the Manifests ###

After pushing the manifests to the Git repository, Flux will reconcile them and apply to the cluster.
If everything goes well, we should see the following resources created in the cluster.

```bash
kubectl get imagerepositories,imagepolicies,imageupdateautomations -n flux-system
```

![k-get-resources-created](https://user-images.githubusercontent.com/42295478/212561141-242077c5-6813-40dd-a033-b8109d0f60d7.png)

If our setup for the continuous delivery works correctly, `image-automation-controller` will update the image tag of the deployment to the latest version depending on the policy we defined.

```bash
kubectl get deploy -o wide --watch
```

![reconcile](https://user-images.githubusercontent.com/42295478/212557235-14c83c2c-1c44-4679-a409-c9156cead836.gif)

### Conclusion ###

 In this post, we've seen how to set up a GitOps continous delivery workflow with FluxCD and automate deployments. GitOps is a powerful approach to manage and automate Kubernetes deployments. By using a tool like FluxCD, it becomes even easier to implement GitOps and achieve continuous delivery. Overall, GitOps and FluxCD are powerful tools that can help you streamline your deployment process and improve the reliability of your Kubernetes deployments.

 You can also check out my original continuous delivery workflow that runs for multiple applications in multiple subdomains of [mharikmert.dev](https://mharikmert.dev) in the same cluster [here](https://github.com/mharikmert/mharikmert.dev-infra).

### Resources ###

- [Flux Documentation](https://fluxcd.io/flux)
- [Image Reflector and Automation Controllers](https://fluxcd.io/docs/components/image/)
- [GitHub Repository](https://github.com/mharikmert/intro-to-gitops-with-flux-demo)

### Further Reading ###

- [Continuous Integration & Delivery & Deployment](https://www.atlassian.com/continuous-delivery/principles/continuous-integration-vs-delivery-vs-deployment)
- [GitOps Style Continuous Delivery with Cloud Build](https://cloud.google.com/kubernetes-engine/docs/tutorials/gitops-cloud-build)
- [GitOps Continuous Delivery Workflow](https://www.xenonstack.com/blog/gitops-continuous-delivery-workflow)