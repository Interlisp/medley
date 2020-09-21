FROM node:12-alpine
WORKDIR /app
COPY lde* /usr/locsl/bin
RUN 
CMD lde -g 1000z800 -d host.internal full35.sysout
