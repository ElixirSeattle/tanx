# Tanx

This is a multiplayer online tank game originally written by Daniel Azuma,
Greg Hill, Kyle Rippey, and Ben Stephens during a study group covering
[Programming Elixir](https://pragprog.com/book/elixir/programming-elixir). It
is a [Phoenix](http://phoenixframework.org/) umbrella application with a
Javascript front-end.

## Running a development server

This procedure will get the server running on your local workstation.

### Prerequisites

Generally, you should know how to run Phoenix applications. See the
[Phoenix guides](https://hexdocs.pm/phoenix/overview.html) for more details.

1.  Install elixir: http://elixir-lang.org/install.html
2.  Install hex: `mix local.hex`
3.  Install node.js: http://nodejs.org/download/

### Running a development server

1.  Install dependencies with `mix deps.get`
2.  Start Phoenix endpoint with `mix phx.server`

Now you can visit `localhost:4000` from your browser.

## Production deployment with Google Kubernetes Engine

This procedure will guide you through building the tanx server as an OTP
release in a Docker image, and deploying that image to Kubernetes via
Google Kubernetes Engine.

### Prerequisites

1.  Set up a project on [Google Cloud Console](http://cloud.google.com/console)
    if you don't have one, and enable billing.

    Optional: Set the `PROJECT_ID` environment variable in your shell, to the
    ID of the project you created. Some commands below will use this variable
    substitution. (Or you can just substitue the value yourself.)

2.  Install the [Google Cloud SDK](https://cloud.google.com/sdk/) on your
    workstation if you don't have it. This includes:

    1.  Install gcloud. See the
        [quickstarts](https://cloud.google.com/sdk/docs/quickstarts) if you
        need instructions.

    2.  Install kubectl, the command line for controlling Kubernetes:

            gcloud components install kubectl

    3.  Log in using gcloud so it can access your cloud account and resources.

            gcloud auth login

3.  Configure gcloud for your project.

    1.  Set the default project. (Substitute your project ID.)

            gcloud config set project ${PROJECT_ID}

    2.  Set a default zone (i.e. data center location). I think "us-central1-c"
        is generally a good one for much of the US, but you may choose one
        closer to your location.

            gcloud config set compute/zone us-central1-c

4.  Enable the Kubernetes Engine API and Container Builder API, using the
    following commands:

        gcloud services enable container.googleapis.com
        gcloud services enable cloudbuild.googleapis.com

5.  Optional: if you want to do local builds,
    [install Docker](https://docs.docker.com/installation/). This is not
    needed if you just want to deploy.

### Building

We will use Google's [Cloud Build](https://cloud.google.com/cloud-build/)
service to build the Tanx application in a Docker image. Notice that there is
a Dockerfile provided. It uses Distillery to produce an OTP release, and
installs it in a Docker image based on bitwalker's Alpine-Erlang image. We
will just hand this to Google Cloud Build to build an image and upload it to
your project's container registry.

To perform the first build.

    gcloud builds submit --config deploy/cloudbuild.yml .

The period at the end is required; it is the root directory for the application
you are building.

This will build your image in the cloud, and upload it to your project's image
registry.

### Local builds (optional)

You may also build an image locally using, for example:

    docker build -f deploy/Dockerfile -t tanx .

Note that Docker 17.05 or later is required.

You may run a local build using:

    docker run --rm -p 8080:8080 tanx

This will run on port 8080. You may need to use `docker kill` to stop the
container.

### Create a cluster

Now we'll set up Google Kubernetes Engine to host an online tanx server.

1.  Choose a cluster name. For the rest of these instructions, I'll assume that
    name is "tanx-cluster-1".

2.  Create the cluster.

        gcloud container clusters create tanx-cluster-1 --num-nodes=2

    You can of course replace the cluster name with a name of your choosing, as
    well as change the number of nodes in the cluster and the machine type.
    For now, the defaults will get you started.

3.  Configure gcloud to use your cluster as default so you don't have to
    specify it every time for the remaining gcloud commands.

        gcloud config set container/cluster tanx-cluster-1

    Replace the name if you named your cluster differently.

4.  Check the cloud console at http://console.cloud.google.com/kubernetes to
    make sure your cluster is running. Note that once the cluster is running,
    you will be charged for the VM usage.

5.  The app will need to access the kubernetes API so it can configure the OTP
    cluster. To set up that access, first give yourself the ability to edit
    your cluster's role bindings.

        kubectl create clusterrolebinding my-admin-binding \
          --clusterrole cluster-admin \
          --user $(gcloud config get-value account)

6.  Now give the necessary access to the cluster default service account. The
    necessary role and binding objects are provided in a config file:

        kubectl create -f deploy/cluster-roles.yml

### Deploy to the cluster

A production deployment comprises two parts: a cluster of running containers
managed by a Kubernetes _deployment_, and a front-end load balancer.

We'll assume that you've built the image and created the Kubernetes cluster as
described above.

First we'll create the deployment and load balancer:

    kubectl create -f deploy/tanx-deployment.yml

This will create the Kubernetes resources and start up containers in pods. The
initial deployment, however, just runs nginx in a container (rather than your
app). So next you'll need to set the image:

    kubectl set image deployment/tanx tanx=gcr.io/${PROJECT_ID}/tanx:latest

You may view the running pods using:

    kubectl get pods

And the load balancer using:

    kubectl get service

Initially, the "external IP" for the service will be pending while Kubernetes
Engine works to procure an IP address for you. If you rerun the `get service`
command, eventually the IP address will appear. You can then point your browser
at that URL to view the running application.

### Updating the app

To update the tanx app to reflect changes you have made, rebuild with a new
version tag. For example, if your original build image was tagged
`gcr.io/${PROJECT_ID}/tanx:v1`, you might do a new build as:

    gcloud builds submit --config deploy/cloudbuild.yml \
      --substitutions _BUILD_ID=v2 .

Now the new image `gcr.io/${PROJECT_ID}/tanx:v2` will be available in your
project's container registry. You may deploy it by setting the pod's image
to the new image:

    kubectl set image deployment/tanx tanx=gcr.io/${PROJECT_ID}/tanx:v2

This performs a "rolling" update for zero downtime deploys.

### Cleanup and tearing down a deployment

To clean up a deployment of tanx and stop incurring hosting costs, do the
following.

1.  Delete the service

        kubectl delete service tanx

2.  Wait for the load balancer to go away. This may take a few minutes. You
    may watch the output of the following command to see when this is complete.

        gcloud compute forwarding-rules list

3.  Delete the cluster. This will delete the resources making up the cluster,
    including the VMs provisioned.

        gcloud container clusters delete tanx-cluster-1
