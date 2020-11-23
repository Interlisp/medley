# Running Medley with Docker

If this is your first time working with Docker, you'll want to [install it](https://docs.docker.com/get-docker/) before continuing. You'll also need a modern VNC client; [TightVNC](https://www.tightvnc.com/) works well.

Next, you can either pull a prebuilt image or build from scratch:

## Using a prebuilt image (recommended)

1. `$ docker run -p 5900:5900 interlisp/medley`
2. Run a VNC viewer and connect to localhost.

## Building from scratch

1. Pull the latest Medley repo.
2. `$ cd medley`
3. Pull Maiko: `$ git submodule update --init --recursive`
4. `$ docker build . -t interlisp/medley`
5. And then as above.
