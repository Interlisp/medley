Each release has a subset of the medley repo in a file
   medley-releasename.tar.gz

and at least one 
   maiko-releasename,osname.arch.tar.gz
   
e.g., maiko-v3.5.1.6.linux.x86_64.tar.gz

Unpack the medley tar file
```
  tar -xvfz medley-v3.5.1.6.tar.gz
  ```
  and the zip file for your OS
  ```
  tar -xvfz maiko-v3.5.1.linux.x86_64.tar.gz
  ```
   To start up, open a Terminal window
```
cd medley
run-medley -full
```

