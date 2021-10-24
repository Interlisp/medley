FROM interlisp/maiko:latest
ARG BUILD_DATE
LABEL name="Medley"
# LABEL tags=${tags}
LABEL description="The Medley Interlisp environment"
LABEL url="https://github.com/Interlisp/medley"
LABEL build-time=$BUILD_DATE

RUN apt-get update && apt-get install -y tightvncserver

EXPOSE 5900

# Copy and uncompress loadup and required source files.
ADD *.tgz /app

WORKDIR /app/medley

RUN adduser --disabled-password --gecos "" medley
USER medley
ENTRYPOINT USER=medley Xvnc -geometry 1280x720 :0 & DISPLAY=:0 PATH="/app/maiko:$PATH" ./run-medley -full -g 1280x720 -sc 1280x720