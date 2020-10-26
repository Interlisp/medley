FROM ubuntu:focal
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update
RUN apt-get install -y build-essential clang libx11-dev tightvncserver xfce4 xfce4-goodies
COPY . /build
WORKDIR /build/maiko/bin
RUN ./makeright x
RUN mkdir /app
RUN cp ../linux.x86_64/* /app
COPY loadups/xfull35.sysout /app

RUN adduser --disabled-password --gecos "" medley
USER medley
WORKDIR /app
ENTRYPOINT USER=medley Xvnc -geometry 1270x720 :0 & DISPLAY=:0 /app/ldex -g 1280x720 xfull35.sysout
