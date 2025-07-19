# Quick start guide for Kubernetes

This option will walk through creating a light weight Kubernetes cluster, after which you will be able to deploy the Tinkerbell stack via the Helm chart, and then provision a machine.
You will need to bring your own hardware (machine) for this guide.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [K3D](https://k3d.io/#installation)
- [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [Helm](https://helm.sh/docs/intro/install/)
- A machine to provision

## Steps

1. Create a Kubernetes cluster with K3D

   ```bash
   k3d cluster create --network host --no-lb --k3s-arg "--disable=traefik,servicelb,metrics-server,local-storage"
   # `--network host` : host network is used to allow the load balancer to advertise a layer 2 address.
   # `--no-lb` : the K3D built in load balancer is disabled so we don't have conflicts with the stack load balancer.
   # `--k3s-arg "--disable=traefik,servicelb,metrics-server,local-storage"` : disable the built in K3S load balancer, metrics server, and local storage.
   ```

1. Install the Tinkerbell stack Helm chart

   To install Tinkerbell, follow the official [install documentation](https://tinkerbell.org/docs/setup/install/).

1. Verify the stack is up and running

   ```bash
   kubectl get pods -n tinkerbell # verify all pods are running
   kubectl get svc -n tinkerbell # Verify the tink-stack service has the IP you specified with $LB_IP under the EXTERNAL-IP column
   ```

1. Download and convert a cloud image to a raw image

   ```bash
   kubectl apply -n tinkerbell -f https://raw.githubusercontent.com/tinkerbell/playground/refs/heads/main/stack/vagrant/ubuntu-download.yaml
   # This will download and convert the Ubuntu Jammy 22.04 cloud image.
   ```

1. Create and/or customize Hardware, Template, and Workflow objects and apply them to the cluster. You can use the Hardware, Template, and Workflow in this repo, in the `stack/vagrant/` directory, as a base from which to start.

   ```bash
   kubectl apply -n tinkerbell -f my-hardware.yaml
   kubectl apply -n tinkerbell -f my-template.yaml
   kubectl apply -n tinkerbell -f my-workflow.yaml
   ```

1. Start the machine provision process by rebooting, into a netbooting state, the machine you have specified in the Hardware object above.

1. Watch the progress of the workflow.

   ```bash
   kubectl get workflow -n tinkerbell --watch
   # Once the workflow state is `SUCCESS`, you can login to the machine via the console or via SSH.
   ```
