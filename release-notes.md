We're moving to having separate releases of medley and maiko.
Just get the latest version of each.

You can pick up the medley release and build your own maiko.

     `medley-`releasename`.tgz`

To use (from a shell/terminal window):

1. Unpack the medley tar file
  ```
  tar -xvfz medley-$tag.tgz
  ```
  and the maiko file for your os.arch, e.g.,
```
     tar -xvfz maiko-210823.linux.x86_64.tgz
```
  
  This should leave you with two directories, `medley` and `maiko`.
  Then you can 
   ```
   cd medley
   ./run-medley -full
   ```
   

