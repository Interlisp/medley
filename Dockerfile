FROM ubuntu:focal
ARG build_date
ARG medley_release
ARG maiko_release
LABEL name="Medley"
# LABEL tags=${tags}
LABEL description="The Medley Interlisp environment"
LABEL url="https://github.com/Interlisp/medley"
LABEL build-time=$build_date
ENV BUILD_DATE=$build_date
ENV MEDLEY_RELEASE=$medley_release
ENV MAIKO_RELEASE=$maiko_release

RUN apt-get update && apt-get install -y tightvncserver

EXPOSE 5900

# Copy and uncompress loadup and required source files.
ADD *.tgz /home

WORKDIR /home/medley

RUN adduser --disabled-password --gecos "" medley
USER medley
ENTRYPOINT USER=medley Xvnc -geometry 1280x720 :0 & DISPLAY=:0 PATH="/app/maiko:$PATH" ./run-medley -full -g 1280x720 -sc 1280x720
