#*******************************************************************************
# 
# Dockerfile to build Medley image from latest Maiko image 
# plus latest release tars from github
#
# Copyright 2022-2023 by Interlisp.org
#
# ******************************************************************************

ARG DOCKER_NAMESPACE=interlisp

FROM ${DOCKER_NAMESPACE}/maiko:latest

# Add tightvnc server and xclip to the image
RUN apt-get update && apt-get install -y tightvncserver && apt-get install -y xclip

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

ARG IL_INSTALLDIR=/usr/local/interlisp
ENV IL_INSTALLDIR=${IL_INSTALLDIR}
ENV MAIKO_INSTALLDIR=${IL_INSTALLDIR}/maiko
ENV MEDLEY_INSTALLDIR=${IL_INSTALLDIR}/medley

ARG DOCKER_NAMESPACE=interlisp
ENV DOCKER_NAMESPACE=${DOCKER_NAMESPACE}

ENV LANG=C.UTF-8

# Copy over the release tars
RUN mkdir -p ${IL_INSTALLDIR}
ADD ./*.tgz ${IL_INSTALLDIR}

# Link run_medley script into /usr/local/bin
RUN mkdir -p /usr/local/bin && \
    ln -s ${MEDLEY_INSTALLDIR}/run-medley /usr/local/bin/run-medley
    
# "Finalize" image
EXPOSE 5900
RUN adduser --disabled-password --gecos "" medley
USER medley
WORKDIR /home/medley
ENTRYPOINT USER=medley Xvnc -geometry 1280x720 :0 & DISPLAY=:0 ${MEDELY_INSTALLDIR}/run-medley -full -g 1280x720 -sc 1280x720
