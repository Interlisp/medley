We've moved to separate releases of medley and maiko.
Just get the latest version of each.

Or, you could pick up the medley release and build your own maiko.
Medley release is here:

     `$tag.tgz`

Maiko relese is [here](https://github.com/Interlisp/maiko/releases)

To use (from a shell/terminal window):

1. Unpack the medley tar file
  ```
  tar -xvfz $tag.tgz
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
   

