# Tanx

## Prerequisites

1.  Install elixir: http://elixir-lang.org/install.html
2.  Install hex: `mix local.hex`
3.  Install node.js: http://nodejs.org/download/

## Running a development server

1.  Install dependencies with `mix deps.get`
2.  Start Phoenix endpoint with `mix phoenix.server`

Now you can visit `localhost:4000` from your browser.

## Production deployment with Google Container Engine

### Prerequisites

This information is also available at https://cloud.google.com/container-engine/docs/before-you-begin

1.  Set up a project on Google Cloud Console if you don't have one. You will need to enable billing, and enable the Google Container Engine API. http://cloud.google.com/console

2.  Install the gcloud SDK if you don't have it.
    1. Install gcloud: `curl -sSL https://sdk.cloud.google.com | bash`
    2. Install kubectl: `gcloud components update kubectl`
    3. Log in: `gcloud auth login`

3.  Configure gcloud for your project.
    1. Make sure gcloud points to your project: `gcloud config set project <your-project-id>`
    2. Set a default zone (i.e. data center location). I think "us-central1-c" is a good one. `gcloud config set compute/zone us-central1-c`

4.  Install Docker. https://docs.docker.com/installation/

### Create a cluster

This information is also available at https://cloud.google.com/container-engine/docs/clusters/operations

1.  Choose a cluster name. For the rest of these instructions, I'll assume that name is "tanx-1".

2.  Create the cluster. `gcloud container clusters create tanx-1 --machine-type=n1-highcpu-2 --num-nodes=1` You can of course replace the cluster name with a name of your choosing. You can use a different machine type as well, although for now I recommend highcpu types since the application seems CPU bound for the moment.

3.  Configure gcloud to use your cluster as default so you don't have to specify it every time for the remaining gcloud commands. `gcloud config set container/cluster tanx-1` Replace the name if you named your cluster differently.

4.  I'm not completely clear on this, but you may need to configure kubectl to point to this cluster with `gcloud container clusters get-credentials`

Check the cloud console at http://cloud.google.com/console under container engine to see that your cluster is running. Note that once the cluster is running, you will be charged for the VMs.

### Build and deploy

A production deployment comprises two parts: a running phoenix container, and a front-end load balancer (which doesn't do much load balancing per se, but provides a public IP address.)

We have provided mix commands to do builds and deployments. These commands require that you have gcloud's project configuration set to point to your project (see prerequisites).

To build your tanx container: `mix kube.build` which builds a Docker image and pushes it to your project's private image storage.

To start/stop the front-end load balancer: `mix kube.balancer.start` and `mix kube.balancer.stop` Note that the start command will print out the public IP address for you.

To start/stop the phoenix container using the latest build: `mix kube.phoenix.start` and `mix kube.phoenix.stop`

To update the phoenix container to a new build, perform the build, then stop and start the container. We don't have a zero-downtime or state-preserving update procedure yet.

### Cleanup and tearing down a deployment

First make sure your container and load balancer are stopped. (See above.)

Tear down your cluster: `gcloud container clusters delete tanx-1` (replace "tanx-1" with the name of your cluster.) Once the cluster is down, you will no longer be charged.
