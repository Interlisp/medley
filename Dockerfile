FROM ubuntu:focal
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y make clang libx11-dev
COPY ./maiko/ /build/
WORKDIR /build/bin
RUN rm -rf /build/linux*
RUN ./makeright x


FROM ubuntu:focal
ENV DEBIAN_FRONTEND=noninteractive

EXPOSE 5900

RUN apt-get update && apt-get install -y tightvncserver
RUN mkdir -p /app/maiko
WORKDIR /app
COPY ./* ./
COPY --from=0 /build/bin ./maiko/bin
COPY --from=0 /build/linux* ./maiko/

RUN adduser --disabled-password --gecos "" medley
USER medley
ENTRYPOINT USER=medley Xvnc -geometry 1280x720 :0 & DISPLAY=:0 PATH="/app/maiko:$PATH" ./run-medley -g 1280x720 -sc 1280x720
