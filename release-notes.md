There are separate releases of medley and maiko.
Just get the latest version of each.

Alternatively, you can pick up the medley release, and build your own maiko.

Get the Maiko release [here](https://github.com/Interlisp/maiko/releases).

The medley release comes in two parts:
1. The "loadups" (download `$tag-loadups.tgz` below)
2. The "runtime" (download `$tag-runtime.tgz` below)

You won't need the "runtime" if you clone medley; it's just a subset. 
   
To download both using 'gh' GitHub command line:
```
   gh release download -R Interlisp/medley -p "*"
```

To use (from a shell/terminal window):

1. Unpack the medley tar file(s)
```
  tar -xvfz $tag-loadups.tgz
  tar -xvfz $tag-runtime.tgz
```

2. Unpack the maiko file for your operating system and CPU type, e.g.,

   ```
     tar -xvfz maiko-210823.linux.x86_64.tgz
   ```

3. This should leave you with two directories, `medley` and `maiko`.
  Then you can 
   ```
   cd medley
   ./run-medley -full
   ```



