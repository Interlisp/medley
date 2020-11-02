FROM ubuntu:focal
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y build-essential clang libx11-dev
COPY maiko /build/
WORKDIR /build/bin
RUN rm -rf /build/linux*
RUN ./makeright x


FROM ubuntu:focal
ENV DEBIAN_FRONTEND=noninteractive

EXPOSE 5900

RUN apt-get update && apt-get install -y tightvncserver
RUN mkdir /app
WORKDIR /app
COPY loadups ./
COPY --from=0 /build/linux.x86_64/* ./

RUN adduser --disabled-password --gecos "" medley
USER medley
ENTRYPOINT USER=medley Xvnc -geometry 1270x720 :0 & DISPLAY=:0 /app/ldex -g 1280x720 xfull35.sysout
