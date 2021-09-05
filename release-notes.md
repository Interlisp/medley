There are separate releases of medley and maiko.
Get the latest version of each.

From a shell/terminal window:

1. Get the medley release `$tag.tgz` below.

Unpack the medley tar file
  ```
  tar -xvfz $tag.tgz
  ```

2. Get the Maiko release [here](https://github.com/Interlisp/maiko/releases).
Unpack the Maiko file for your operating system and CPU type, e.g.,

```
     tar -xvfz maiko-210823.linux.x86_64.tgz
```

3. This should leave you with two directories, `medley` and `maiko`.
  Then you can 
   ```
   cd medley
   ./run-medley -full
   ```
---
Alternatives:

1. Medley
* Instead of $tag.tgz, get $tag-loadups-only.tgz and 
   * the sources below, or
   * checkout tag $tag in your own clone of the repo
* You can make your own loadups; see scripts/loadup-and-release.sh
2. Maiko
* Get the latest maiko sources and make your own
```
  cd maiko/bin
  ./makeright x
```
and, if you're doing a loadup
```
   ./makeright init
```

  
