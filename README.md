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

## Production deployment with Google Container Engine

This procedure will guide you through building the tanx server as an OTP
release in a Docker image, and deploying that image to Kubernetes via
Google Container Engine.

### Prerequisites

1.  Set up a project on [Google Cloud Console](http://cloud.google.com/console)
    if you don't have one, and enable billing.

2.  Enable the Google Container Engine API and Container Builder API. In the
    cloud console, pull down the left nav and go to "APIs and services".

3.  Install the [Google Cloud SDK](https://cloud.google.com/sdk/) on your
    workstation if you don't have it. This includes:

    1.  Install gcloud. See the
        [quickstarts](https://cloud.google.com/sdk/docs/quickstarts) if you
        need instructions.
    2.  Install kubectl, the command line for controlling Kubernetes:
        `gcloud components install kubectl`
    3.  Log in: `gcloud auth login`

4.  Configure gcloud for your project.

    1.  Make sure gcloud points to your project: `gcloud config set project <your-project-id>`
    2.  Set a default zone (i.e. data center location). I think "us-central1-c"
        is a good one. `gcloud config set compute/zone us-central1-c`

5.  Optional: if you want to do local builds,
    [install Docker](https://docs.docker.com/installation/). This is not
    needed if you just want to deploy.

### Building

We will use Google's [Container Builder](https://cloud.google.com/container-builder/)
service to build the tanx application in a Docker image. Notice that there is
a Dockerfile provided. It uses Distillery to produce an OTP release, and
installs it in a Docker image based on bitwalker's Alpine-Erlang image. We
will just hand this to Container Builder to build an image and upload it to
your project's container registry.

To perform the first build:

    gcloud container builds submit --tag=gcr.io/${PROJECT_ID}/tanx:v1 .

Make sure you substitute your project ID. The period at the end is required; it
is the root directory for the application you are building.

This will build your image in the cloud, and upload it to the tag you provided.

### Local builds (optional)

You may also build an image locally using, for example,
`docker build -t tanx .`. Note that Docker 17.05 or later is required because
the Dockerfile is a multistage script.

You may run a local build using:

    docker run --rm -p 8080:8080 tanx

This will run on port 8080. You may need to use `docker kill` to stop the
container.

### Create a cluster

Now we'll set up container engine to host an online tanx server.

1.  Choose a cluster name. For the rest of these instructions, I'll assume that
    name is "tanx-cluster-1".

2.  Create the cluster.

        gcloud container clusters create tanx-cluster-1 --machine-type=n1-highcpu-2 --num-nodes=1

    You can of course replace the cluster name with a name of your choosing.
    You can use a different machine type as well, although for now I recommend
    highcpu types since the application seems CPU bound for the moment.

3.  Configure gcloud to use your cluster as default so you don't have to
    specify it every time for the remaining gcloud commands.

        gcloud config set container/cluster tanx-cluster-1

    Replace the name if you named your cluster differently.

Check the cloud console at http://cloud.google.com/console under container
engine to see that your cluster is running. Note that once the cluster is
running, you will be charged for the VM usage.

### Deploy to the cluster

A production deployment comprises two parts: a running phoenix container, and a
front-end load balancer (which doesn't do much load balancing per se, but
provides a public IP address.)

We'll assume that you built the image to `gcr.io/${PROJECT_ID}/tanx:v1` and
you've created the Kubernetes cluster as described above.

Next we'll create a deployment

    kubectl run tanx-1 --image=gcr.io/${PROJECT_ID}/tanx:v1 --port 8080

This will run your image on a Kubernetes pod. You may view the running pods
using:

    kubectl get pods

Now, we need to "expose" the application using a load balancer.

    kubectl expose deployment tanx-1 --type=LoadBalancer --port 80 --target-port 8080

This creates a "service" resource pointing at your running tanx pod. After
creating the service, run

    kubectl get service

to view the service. Initially, the "external IP" will be pending while
container engine works to procure an IP address for you. If you rerun the
`kubectl get service` command, eventually the IP address will appear. You can
then point your browser at that URL to view the running application.

### Updating the app

To update the tanx app to reflect changes you have made, rebuild with a new
version tag. For example, if your original build image was tagged
`gcr.io/${PROJECT_ID}/tanx:v1`, you might do a new build as:

    gcloud container builds submit --tag=gcr.io/${PROJECT_ID}/tanx:v2 .

Now the new image `gcr.io/${PROJECT_ID}/tanx:v2` will be available in your
project's container registry. You may deploy it by setting the pod's image
to the new image:

    kubectl set image deployment/tanx-1 tanx-1=gcr.io/${PROJECT_ID}/tanx:v2

This generally performs a "rolling" update for zero downtime deploys. However,
since our service has only one instance, it simply stops and starts that single
instance.

### Cleanup and tearing down a deployment

To clean up a deployment of tanx and stop incurring hosting costs, do the
following.

1.  Delete the service

        kubectl delete service tanx-1

2.  Wait for the load balancer to go away. This may take a few minutes. You
    may watch the output of the following command to see when this is complete.

        gcloud compute forwarding-rules list

3.  Delete the cluster. This will delete the resources making up the cluster,
    including the VMs provisioned.

        gcloud container clusters delete tanx-cluster-1
