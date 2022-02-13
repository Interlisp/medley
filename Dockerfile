#*******************************************************************************
# 
# Dockerfile to build Medley image from latest Maiko image 
# plus latest release tars from github
#
# Copyright 2022 by Interlisp.org
#
# ******************************************************************************

ARG DOCKER_NAMESPACE=interlisp

FROM ${DOCKER_NAMESPACE}/maiko:latest

# Add tightvnc server to the image
RUN apt-get update && apt-get install -y tightvncserver

#  Handle ARGs, ENV variables, and LABELs
ARG BUILD_DATE=unknown
ARG RELEASE_TAG=unknown
ARG MAIKO_RELEASE=unknown
ARG REPO_OWNER=Interlisp
LABEL name="Medley"
LABEL description="The Medley Interlisp environment"
LABEL url="https://github.com/${REPO_OWNER}/medley"
LABEL build-time=$BUILD_DATE
LABEL release_tag=$RELEASE_TAG
LABEL maiko_release=$MAIKO_RELEASE

ENV MEDLEY_BUILD_DATE=$BUILD_DATE
ENV MEDLEY_RELEASE=$RELEASE_TAG

ARG INSTALL_LOCATION=/usr/local/interlisp
ENV INSTALL_LOCATION=${INSTALL_LOCATION}

ARG DOCKER_NAMESPACE=interlisp
ENV DOCKER_NAMESPACE=${DOCKER_NAMESPACE}

# Copy over the release tars
RUN mkdir -p ${INSTALL_LOCATION}
ADD ./*.tgz ${INSTALL_LOCATION}

# Create a run_medley script in /usr/local/bin
RUN mkdir -p /usr/local/bin                                     && \
    echo "#!/bin/bash"              > /usr/local/bin/run-medley && \
    echo "cd ${INSTALL_LOCATION}"  >> /usr/local/bin/run-medley && \
    echo './run-medley "$@"'       >> /usr/local/bin/run-medley && \
    chmod ugo+x /usr/local/bin/run-medley
    
# "Finalize" image
EXPOSE 5900
RUN adduser --disabled-password --gecos "" medley
USER medley
WORKDIR /home/medley
ENTRYPOINT USER=medley Xvnc -geometry 1280x720 :0 & DISPLAY=:0 ${INSTALL_LOCATION}/medley/run-medley -full -g 1280x720 -sc 1280x720
