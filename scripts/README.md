# The Medley scripts directory

## doing different kinds of "load ups"

Loading from an old 'starter' sysout
* loadup-init.sh           -- phase 1 (create init.dlinit)
* loadup-mid-from-init.sh  -- phase 2 (creates init.sysout)
* loadup-lisp-from-mid.sh  -- phase 3 (creates lisp.sysout)
* loadup-full-from-lisp.sh -- phase 4 (creates full.sysout)
* loadup-apps-from-full.sh -- phase 5 (creates app.sysout, with notecards, rooms and clos; optional)
* loadup-aux.sh            -- phase 6 (creates exports.all whereis.hash)
* loadup-db-from-full.sh   -- phase 7 (makes unreleased 'fuller.sysout' and fuller.database)

All of these scripts read from and write to a directory specified by the env variable LOADUP_WORKDIR.
LOADUP_WORKDIR defaults to /tmp/loadups-$$ (where $$ is the PID of the script). Note that all /tmp files
are cleared after 10 days or upon system reboot. You can replicate the old work directory scheme 
where files were never deleted automatically by simply setting LOADUP_WORKDIR to "./tmp"

* loadup-all.sh [-apps] -- Phases 1-4 & 6 (plus Phase 5 with -apps flag)
* loadup-db.sh    -- phase 7 only based on full.syout in loadup directory

These two scripts call the 7 scripts above as specified and then (if successful) copy (ln) the results
to the loadups directory using a versioned copy.  The files are hardlinked into loadups from the workdir
if workdir and loadups are on the same filesystem, otherwise they are copied. 

* loadup-full.sh  -- Phases 1-4 only, no copy into loadups at the end.

## releases

* release-medley.sh --  will create Medley release tars and upload as a release on github.  
                      Arguments: -d to make a draft release. \<Tag> to use as a tag for this 
                      release on github (defaults to meldey-\<date>-\<seconds since epoch>).
                      Both are optional.

* release-make-tars.sh -- will create the Medley release tars and store them in the releases directory.

## possibly handy scripts

* lsee <lispfile>  -- show lisp file with font-control-characters rendered as linux color changes
* cpv file1 file2  -- hardlinks (or copies) file1 to file2 (or directory name) adding versions
                      choice of hardlink or copy depends on whether the files are on the same filesystem.
* restore-versions.sh -- pulls out old versions from git history and links in with medley versioning conventions

## Not useful anymore 

* eolconv.sh  -- convert CR to LF and delete font control characters (use lsee)
* install-diff-filter.sh -- installed eolconv.sh as a filter before using github diff (use Lisp GitFns instead)
* fixlinks & fixlinks.aux  -- put back hardlinks between file and file.~NN~ where NN is highest version (restore-versions does this)

