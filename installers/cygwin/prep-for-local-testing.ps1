#
#  Prep the installer/cygwin directory to locally test the medley.iss installer
#  Normally these downloads are done by the github workflow
#
#  fgh 2024-11-15
#
wget https://cygwin.com/setup-x86_64.exe -OutFile setup-x86_64.exe
gh release download --repo interlisp/maiko --pattern *-cygwin.x86_64.tgz --output maiko-cygwin.x86_64.tgz --clobber
gh release download --repo interlisp/medley --pattern medley-full-linux-x86_64-*.tgz --output medley.tgz --clobber