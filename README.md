# Tanx

## Prerequisites

1. Install elixir: http://elixir-lang.org/install.html
2. Install hex: `mix local.hex`
3. Install node.js: http://nodejs.org/download/

## Running a development server

1. Install dependencies with `mix deps.get`
2. Start Phoenix endpoint with `mix phoenix.server`

Now you can visit `localhost:4000` from your browser.

## Production deployment with Docker and Google Compute Engine

### Prerequisites

1. Set up a project on Google Cloud Console if you don't have one. Make sure Compute Engine is enabled. http://cloud.google.com/console

2. Configure the gcloud SDK if you don't have it.
   a. Install: `curl -sSL https://sdk.cloud.google.com | bash`
   b. Log in: `gcloud auth login`
   c. Make sure gcloud points to your project: `gcloud config set project <your-project-id>`

3. Install Docker. https://docs.docker.com/installation/

### Provision a server

1. Launch a GCE instance. Choose a name for your instance. (I'll use "my-tanx-server-1" in the example below.) Also, feel free to use a different zone and machine type.

`gcloud compute instances create my-tanx-server-1 --image container-vm --zone us-central1-b --machine-type n1-highcpu-2`

2. Check the cloud console at http://cloud.google.com/console to see that your server is running.

### Build and deploy the docker image

1. Create a Docker image. `docker build -t mydockername/tanx .`

2. Upload your docker image to Docker Hub: `docker push mydockername/tanx`

3. SSH into your server: `gcloud compute ssh --zone us-central1-a my-tanx-server-1`

4. Pull down the Docker image: `sudo docker pull mydockername/tanx`

5. Run the application: `sudo docker run -d -p 80:8080 mydockername/tanx`

### To update your deployment

1. SSH into your server.

2. Find the running container: `sudo docker ps -l`

3. Stop the service: `sudo docker stop <container-id>`

4. Build and install the new Docker image and start the app as above.
