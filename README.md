- [CS 1632 - Software Quality Assurance](#cs-1632---software-quality-assurance)
  * [Description](#description)
  * [Part 2: Dockers](#part-2-dockers)
    + [Prerequisites](#prerequisites)
    + [Do some sanity tests](#do-some-sanity-tests)
    + [Create Docker image](#create-docker-image)
    + [Create Docker Container](#create-docker-container)
    + [Import Playwright Tests](#import-playwright-tests)
    + [Add CI Test Workflow](#add-ci-test-workflow)
    + [Add Docker Publish Workflow](#add-docker-publish-workflow)
    + [Pull published Docker image and launch from desktop](#pull-published-docker-image-and-launch-from-desktop)
- [Submission](#submission)

# CS 1632 - Software Quality Assurance
Spring Semester 2026 - Supplementary Exercise 4

* DUE: April 21 (Tuesday), 2026 before start of class

## Description

During the semester, we learned various ways in which we can automate testing.
But all that automation is of no use if your software organization as a whole
does not invoke those automated test scripts diligently.  Preferably, those test
scripts should be run before every single source code change to the repository,
and for good measure, regularly every night or every weekend just in case.  Now,
there are many reasons why this does not happen if left to individual
developers:

1. Developers are human beings so they forget.  Or, they remember to run
   some tests, but not all the test suites that are relevant to the changes
they have made.

1. Developers are sometimes on a tight schedule, so they are tempted to skip
   testing that may delay them, especially if they are not automated.  They
justify their actions by telling themselves that they will fix the failing
tests "as soon as possible", or that the test cases are not testing anything
important, or that failing test cases in modules under the purview of
another team "is not my problem".

In Part 1 of this exercise, we will learn how to build an automated
"pipeline" of events that get triggered automatically under certain
conditions (e.g. a source code push).  A pipeline can automate the entire
process from source code push to software delivery to end users, making sure
that a suite of tests are invooked as part of the process before software is
delivered.  Pipelines that are built for this purpose are called CI/CD
(Continuous Integration / Continuous Delivery) pipelines, because they
enable continuous delivery of software to the end user at at high velocity
while still maintaining high quality.  We will learn how to build a fully
functioning pipeline for the (Rent-A-Cat application)[../exercises/2] that
we tested for Exercise 2 on our GitHub repository.

In Part 2, we will learn how to use dockers to both test and deploy
software as part of a CI/CD pipeline.  Dockers are virtualized execution
environments which can emulate the execution environments in the deployment
sites (OS, libraries, webservers, databases, etc.) so that software can be
tested in situ.  In our case, we will create a docker image out of the
(Rent-A-Cat website)[cs1632.appspot.com] that we tested for Deliverable 3
for testing and deployment.

## Part 2: Dockers

**GitHub Classroom Link:** TBD

In Part 2, we will use Docker to test and deploy the Rent-A-Cat website that we
tested in Deliverable 3.  We will test the website using the Playwright tests
that you wrote for the assignment.

Docker runs software in a self-contained virtualized environment called
containers.  A container is launched from a Docker image, which is a binary
file that contains the file system that the container is launched from.  You
can think of Docker images as comparable to Linux images.  Docker images can
be built from any operating system version supported by Docker and can come
with any software or files pre-installed.  As such, Docker images are the
preferred method of deployment for many software organizations.  The Docker
image is to run reliably on any user machine or on a cloud service provider
without a hitch since everything comes pre-packaged.

Deploying software encapsulated in a Docker image makes testing simpler and
more rigorous at the same time. Now the tester does not have to think about
myriad preconditions that can impact the software such as operating system
versions, whether libraries and packages of certain version are installed,
or whether environment variables and configuration files are set with
correct values.  And these preconditions are usually what causes software to
fail during deployment.

### Prerequisites

1. Download and install Docker Desktop to be able to launch Docker containers:
   https://www.docker.com/products/docker-desktop/

1. install Playwright Test package as a dev dependency in the Node.js project:

   ```
   npm install -D @playwright/test
   ```

1. Install chromium as the Playwright test browser

   ```
   npx playwright install --with-deps chromium
   ```

### Do some sanity tests

This project contains a Spring Boot application, which is a Java framework
for creating web servers.  First, let's start by launching the web server
and making sure it is working.  You can launch using the following command:

```
mvn spring-boot:run
```

The output from this command should end in these two lines:

```
...
2026-3-25 18:33:15.380  INFO 21180 --- [           main] o.s.b.w.embedded.tomcat.TomcatWebServer  : Tomcat started on port(s): 8080 (http) with context path ''
2026-3-25 18:33:15.395  INFO 21180 --- [           main] c.s.ServingWebContentApplication         : Started ServingWebContentApplication in 2.46 seconds (JVM running for 2.852)
```

Note this starts the Tomcat web server listening on port 8080.  Try opening
the web app on a browser using the URL:

```
http://localhost:8080/
```

You should see our Rent-A-Cat website.

Now leave the server running and open another terminal to invoke Playwright test:

```
npx playwright test
```

There is a single [Playwright test](tests/rentacat.spec.ts) in this project
that tests that the web server can service HTTP reqeusts on port 8080:

```
test('TEST-CONNECTION', async ({ page }) => {
  await page.goto(baseURL);
});
```

And of course, it should pass.

### Create Docker image

We want to deploy our web app as a Docker image.  Creating a Docker image is
much simpler than you think!  You simply start from a base Linux image and
then "layer" changes on top of it to create your custom image.  You
write this process into something called a Dockerfile and you are done.

Create a Dockerfile at the root of your repository with the following content:

```
# Base image from https://hub.docker.com/layers/library/maven/3.9.14-eclipse-temurin-11-noble/
FROM maven:3.9.14-eclipse-temurin-11-noble

# define working directory
WORKDIR /app

# copy over app files
COPY pom.xml .
COPY src src

# expose default Spring Boot port 8080
EXPOSE 8080

# define default command
CMD ["/bin/sh", "-c", "mvn spring-boot:run"]
```

The description of the base image adoptopenjdk/openjdk11:ubi can be found here:
https://hub.docker.com/layers/library/maven/3.9.14-eclipse-temurin-11-noble/

If you navigate to the above URL, you will see that a Docker image is
constructed in layers, starting from the kernel layer.  Each command that
copies files or installs software packages creates a new layer on top of the
kernel layer.  This layered structure [allows one or more layers to be shared
between multiple images, improving storage
efficiency](https://docs.docker.com/get-started/docker-concepts/building-images/understanding-image-layers/).
As such, our image builds several layers on top of the base image, so if there
was another image using the same base image, the base image layers would be
shared.

For our image, we start with a base image image with the Ubuntu 24 LTS OS
(that's what "noble" means) preinstalled with Maven and Temurin JDK 11.  On top
of it we copy over files required to launch our web app to the work directory
specified as /app.  We also expose TCP port 8080 to the outside world since
that is the port that Spring Boot is going to be using.  If we don't explicitly
expose ports, they will not be accessible in the Docker container created out
of this image.  Lastly, we define the command that will be executed by default
when the image is launched in a container, which is "mvn spring-boot:run".

Third party base images for popular Linux distributions and CPU architectures
preinstalled with a variety of software packages can be found at [Docker
Hub](https://hub.docker.com/search).

### Create Docker Container

Now let's try creating a Docker container out of this image to test it.  By
passing the "compose" argument to the docker tool, we can compose one or more
Docker containers and network them together into a distributed system.  It is
configured using another file in YAML format named docker-compose.yaml.  In our
case, we just have one container so it is rather simple:

```
services:
  server:
    build:
      context: '.'
      dockerfile: Dockerfile
    container_name: rentacat
    ports:
      - "8080:8080"
```

Add a docker-compose.yaml file with the above content at the root of the
repository.  The file consists of a list of services that are launched
together.  In our case, we just have one service named "server".  A service
can be created from a Docker image pulled from Docker Hub or some other
registry, or, as in our case, built locally when the "build:" keyword is
specified.  The "context:" and "dockerfile:" values specify the context
within which the Docker image will be built and the name of the Dockerfile.
The "ports:" values specify a port mapping between container and host --- in
this case, port 8080 is mapped to the same port on the host.

Now we are going to use this YAML file to launch a container listening on
port 8080.  But before doing so, we need to kill the web server that we
launched previously or we are going to have a port conflict.  Go to the
terminal where Spring Boot is running and kill the process using Ctrl+C.
Make sure the server is dead by reloading the page http://localhost:8080/ on
your web browser and confirming that the server is not found.

Now let's first start Docker Desktop, which will start Docker Engine
included in the application.  After it is running, invoke the
"docker compose up" to bring up the container:

```
docker compose up
```

You should soon see the image registered on Docker Desktop:

<img alt="Docker Desktop Images" src=img/docker_1.png>

And also a container instance running with the name "rentacat" with port
8080 open:

<img alt="Docker Desktop Containers" src=img/docker_2.png>

Now try reloading http://localhost:8080/ again and you should see the page
back up.  Congrats, you have created your first Docker container!

To stop the container, you only need to click on the trash bin icon that
appears when you hover over the container.  Or you can do on the
commandline:

```
docker compose down
```

You may also go to the "Images" menu and delete the image if you wish to do
so.  As long as the image is still there, you can relaunch the container
using the "Run" button, but when you do, make sure that you open the
"Optional Settings" and enter the port mapping 8080 on Local Host:

<img alt="Port mapping to 8080" src=img/docker_3.png>

### Import Playwright Tests

If you have stopped the container, fire up the container again because we
are going to write some tests for it.  We want to add some actual Playwright
tests that test the web app.  Well, we already wrote those tests for
Deliverable 3, so let's just import rentacat.spec.ts from that project into
tests/rentacat.spec.ts.

You need to do these three things though in D3Test.java:

1. Replace the base URL of the web pages accessed with "http://localhost:8080".
Please make sure you use http:// and not https://.

1. Remove the tests that fail because they trigger defects on the web app
   (remember the tests whose names start with DEFECT?).

Make sure everything passes with:

```
npx playwright test
```

Detailed test results are under the playwright-report/ folder.

### Add CI Test Workflow

Now let's automate the test environment setup for the web app and the testing
itself in a CI pipeline.  Add a new workflow file named docker-ci.yml to your
GitHub repository with the following content (if you forgot how to do that
already, review the [instructions for Maven CI](#add-maven-ci-workflow)):

```
name: Docker CI

on:
  workflow_dispatch:
  push:
    branches: [ "main" ]
  pull_request:
    branches: [ "main" ]

jobs:

  test_dockerized_webserver:

    runs-on: ubuntu-latest

    permissions:
      contents: read

    steps:

      - name: Checkout repository
        uses: actions/checkout@v3

      - name: Set up Playwright
        run: npm install -D @playwright/test
      
      - name: Set up Playwright Browsers
        run: npx playwright install --with-deps chromium

      - name: Setup Docker buildx
        uses: docker/setup-buildx-action@v3

      - name: Launch Web Service
        run: docker compose up -d

      - name: Run Playwright Tests
        run: npx playwright test --project=chromium

        # https://github.com/marketplace/actions/upload-a-build-artifact
      - name: Upload Playwright results as artifact
        uses: actions/upload-artifact@v4
        with:
          name: Playwright results
          path: playwright-report/

```

The steps are a replica of what we just did manually.

Commit and push all these changes and the Docker CI workflow will trigger
immediately.  Now, the Playwright tests may pass but it may also fail.  If you
run it a few times, you may notice that it sometimes passes and sometimes
fails, and when it fails, it fails in different ways.  Here is an example of a
failure (stress on example, since you will likely see a different failure):

```
    Retry #1 ───────────────────────────────────────────────────────────────────────────────────────

    Error: page.goto: net::ERR_CONNECTION_RESET at http://localhost:8080/
    Call log:
      - navigating to "http://localhost:8080/", waiting until "load"


      24 |
      25 | test('TEST-3-LISTING', async ({ page }) => {
    > 26 |   await page.goto(baseURL);
         |              ^
        at /home/runner/work/CS1632_CICD_Docker_Solution/CS1632_CICD_Docker_Solution/tests/rentacat.spec.ts:26:14

    Error Context: test-results/rentacat-TEST-3-LISTING-chromium-retry1/error-context.md

    attachment #2: trace (application/zip) ─────────────────────────────────────────────────────────
    test-results/rentacat-TEST-3-LISTING-chromium-retry1/trace.zip
    Usage:

        npx playwright show-trace test-results/rentacat-TEST-3-LISTING-chromium-retry1/trace.zip

    ────────────────────────────────────────────────────────────────────────────────────────────────

  2 failed
    [chromium] › tests/rentacat.spec.ts:5:5 › TEST-1-RESET ─────────────────────────────────────────
    [chromium] › tests/rentacat.spec.ts:19:5 › TEST-2-CATALOG ──────────────────────────────────────
  1 flaky
    [chromium] › tests/rentacat.spec.ts:25:5 › TEST-3-LISTING ──────────────────────────────────────
  8 passed (22.9s)
Error: Process completed with exit code 1.
```

Some tests fail due to net::ERR_CONNECTION_RESET and some due to other reasons.
What's happening?  The fact that the test results are nondeterministic tells
you that it is due to either memory errors or race conditions (the two sources
of nondeterminism by mistake we learned in class).  It is definitely not a
memory error since neither Java (the language the web server is written in) and
TypeScript (the language the Playwright tests are written in) allow memory
errors to happen.  So it must be a **race condition**, and you would be right.

Let's go back to our docker-ci.yml file.  The step "docker compose up -d"
includes an option "-d" that we didn't use before.  The "-d" option is short
for "detached" and allows docker compose to execute detached from the
terminal so that the commandline can immediately return and continue
executing the next steps (you can try it yourself on a terminal if you wish
to).  That means that by the time you get to the Playwright tests, the
container may still be in the middle of launch.  Or, even if the container
is up, the web server may not be ready yet.

Again, to solve this issue, we have to put in some kind of synchronization
to avoid the race condition.  The form of synchronization will necessarily
differ depending on the type of service you are waiting to be ready (e.g.
checking that a web server is ready will look different from checking that a
database server is ready).  I wrote a custom script for you to wait for the
web server:

```
#!/bin/sh

set -e
  
until curl http://localhost:8080/; do
  >&2 echo "Web service is unavailable - sleeping"
  sleep 1
done
  
>&2 echo "Webservice is up - continuing"
```

The curl comamndline tool fetches the page from the given URL and prints it
on the screen.  More important for our purposes, it returns an exit code of
0 if successful and a non-zero value if not (just like most Linux tools).
So the script will poll the URL every second until it can fetch the page.

Save the above script to a file named "wait-for-webserver.sh".  And insert
the invocation of that script right before running the Playwright tests.  I'll
leave it to you to name the step however you want.

After you push that change, try launching the workflow several times.  Now,
you will see the workflow reliably succeeding.  In fact, if you peek into a
workflow and look into the "wait-for-webserver.sh" step, you will see the
script waiting for the web server to start up:

<img alt="Waiting for web server to start" src=img/wait_for_webserver_1.png>

Only when the web server responds with a page does the script return and
allow the workflow to continue on to Playwright testing:

<img alt="Waiting for web server to start" src=img/wait_for_webserver_2.png>

Just like for Part 1, the Docker CI workflow stores Playwright test results as
an artifact visible at the bottom of the Summary page for a workflow run:

<img alt="Docker artifact" src=img/docker_artifact.png>

Try downloading it and opening the index.html file in a browser.

### Add Docker Publish Workflow

Now we CI tests all set up and passing, time to create the delivery
workflow.  Create a new docker-publish.yml file with the following content:

```
name: Docker Publish

on:
  workflow_dispatch:
  release:
    types: [created]

env:
  # ghcr.io is the Docker registery maintained by GitHub
  REGISTRY: ghcr.io
  # github.repository as <account>/<repo>
  IMAGE_NAME: ${{ github.repository }}


jobs:
  build:

    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - name: Checkout repository
        uses: actions/checkout@v3

      - name: Setup Docker buildx
        uses: docker/setup-buildx-action@v3

      # Login against a Docker registry
      # https://github.com/docker/login-action
      - name: Log into registry ${{ env.REGISTRY }}
        uses: docker/login-action@v2
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      # Extract metadata (tags, labels) for Docker
      # https://github.com/docker/metadata-action
      - name: Extract Docker metadata
        id: meta
        uses: docker/metadata-action@v4
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}

      # Build and push Docker image with Buildx
      # https://github.com/docker/build-push-action
      - name: Build and push Docker image
        id: build-and-push
        uses: docker/build-push-action@v3
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          platforms: linux/amd64,linux/arm64,linux/arm/v7
```

The workflow publishes the web server Docker image to ghcr.io (the GitHub
Docker image registery).  The docker/build-push-action@v3 GitHub action does
all the heavy lifting.

Once this workflow is committed and pushed, trigger it by creating a new
release on the "<> Code" tab.  Add a tag by clicking on the "Choose a tag" drop
down, such as "v1.2" (since that is the version number in the pom.xml file).
After the worflow completes, go to the "<> Code" tab and you should see a new
package in the Packages section on the bottom right.  If you click on the
package link, you should see something like the below:

<img alt="Published Docker package" src=img/docker_publish.png>

### Pull published Docker image and launch from desktop

Since your repository is private, you need to authenticate to your GitHub
repository before pulling the package.  You can use the PAT (Personal
Authentication Token) that you generated previously in Part 1 for this purpose.
If have not yet generated the token, please refer to the [Deploy Maven package
and use in your Maven project](#deploy-maven-package-and-use-in-your-maven-project) section in Part 1.

Now on the commandline do:

```
docker login ghcr.io -u <github_username>
```

It is going to ask for your password and this is where you provide your PAT.
This is how the interaction should look like:

```
$ docker login ghcr.io -u wonsunahn
Password: 
Login Succeeded
```

Next, copy the "Install from the command line" text from your GitHub package
page, which was in my case:

```
docker pull ghcr.io/cs1632-Spring2026/supplementary-exercise-4-dockers-wonsunahn:main
```

Then your commandline on the terminal.  This will pull the published image
on to your Docker Desktop.  If you check the "Images" menu, you will see a new
image created:

<img alt="Published Docker image pulled" src=img/docker_4.png>

Try removing the container you created from your locally built image (if you
haven't already), and then run the published image (taking care that you map
port 8080 in "Optional Settings").  Now if load http://localhost:8080/ on
your browser, it should work as expected.

# Submission

When you have done all the tasks you can, please submit "Supplementary Exercise
4 Report" on GradeScope.  The report consists of "Yes" or "No" questions on
whether you were able to complete a task and reflections.  If you were not able
to complete a task, please mark "No".  For the tasks that you said "No", I
expect you to explain the issue that prevented you from fulfilling the task on
the reflections questions at the end of Part 1 and Part 2.
