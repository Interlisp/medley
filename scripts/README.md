# The Medley scripts directory

## doing different kinds of "load ups"

Loading from an old 'starter' sysout
* loadup-init.sh           -- phase 1 (create init.dlinit)
* loadup-mid-from-init.sh  -- phase 2 (creates init.sysout)
* loadup-lisp-from-mid.sh  -- phase 3 (creates lisp.sysout)
* loadup-full-from-lisp.sh -- phase 4 (creates full.sysout)
* loadup-aux.sh            -- phase 5,(creates exports.all whereis.hash

* loadup-full.sh  -- Phase 1-4 only

* loadup-db.sh    -- phase 6 (makes unreleased 'fuller.sysout' and fuller.database
* copy-all.sh     -- copy loadups from tmp/ to loadups/ and library/


## possibly handy scripts

* lsee <lispfile>  -- show lisp file with font-control-characters rendered as linux color changes
* cpv file1 file2  -- copies file1 to file2 (or directory name) adding versions
* restore-versions.sh -- pulls out old versions from git history and links in with medley versioning conventions

## Not useful anymore 

* eolconv.sh  -- convert CR to LF and delete font control characters (use lsee)
* install-diff-filter.sh -- installed eolconv.sh as a filter before using github diff (use Lisp GitFns instead)
* fixlinks & fixlinks.aux  -- put back hardlinks between file and file.~NN~ where NN is highest version (restore-versions does this)

