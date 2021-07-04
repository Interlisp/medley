FROM billstumbo/maiko:latest

RUN apt-get update && apt-get install -y tightvncserver

EXPOSE 5900

# Need to refine this down to only needed directories.
COPY . /app/medley

WORKDIR /app/medley

ENV MEDLEYDIR=/app/medley
ENV MAIKODIR=/app/maiko

RUN adduser --disabled-password --gecos "" medley
USER medley
ENTRYPOINT USER=medley Xvnc -geometry 1280x720 :0 & DISPLAY=:0 PATH="/app/maiko:$PATH" ./run-medley -full -g 1280x720 -sc 1280x720