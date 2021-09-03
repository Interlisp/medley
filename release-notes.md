There are separate releases of medley and maiko.
Just get the latest version of each.

Alternatively, you can pick up the medley release, and build your own maiko.

Get the Maiko release [here](https://github.com/Interlisp/maiko/releases).

To use (from a shell/terminal window):

1. Unpack the medley tar file
  ```
  tar -xvfz $tag.tgz
  ```

2. Unpack the maiko file for your operating system and CPU type,e.g.,

```
     tar -xvfz maiko-210823.linux.x86_64.tgz
```

3. This should leave you with two directories, `medley` and `maiko`.
  Then you can 
   ```
   cd medley
   ./run-medley -full
   ```



