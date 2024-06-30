preliminary documentation -- needs validation
HCFILES writes in {MEDLEYDIR} but it should write in something like (SRCDIR)

# setup

## Remove extraneous files

There are lots of ways to get there but basically set up the execution environment with everything clean but notecards loops, test are copied in. If you don't make fresh, at least 'git clean'.

```
gh repo clone interlisp/medley
gh repo clone interlisp/notecards
gh repo clone interlisp/loops
gh repo clone interlisp/test

cp -r notecards loops test medley
rm -rf notecards/.git loops/.git test/.git
```

# making the .pdfs and index.html files

## best start with a fresh loadup
```
./scripts/loadup-all.sh
```

# Now run in Medley "apps" loadup 
```
  ./medley -a &
```
and enter the following to make the PDFs and the index.html files that links them.

```
(DRIBBLE "medley/loadups/hcfiles.dribble")

(FILESLOAD MEDLEY-UTILS PDFSTREAM GITFNS)

(SETQ NO-HELP NIL)
ADVISE(HELP :BEFORE (IF NO-HELP THEN ( (ERROR MESS1 MESS2)))
    (LET ((NO-HELP T)) (DECLARE (SPECIAL NO-HELP)) (HCFILES)))

(MAKE-INDEX-HTML)
```
# Deploying

The trick is to take a repository based on the master branch of medley and produce a gh-pages branch in the Interlisp/src reposiory.

```
git remote set-url --push https://github.com/Interlisp/src
git branch -D gh-pages  ## if necessary
git checkout -b gh-pages ## make the current directory content the same

## make sure the .gitignore DOESN'T ignore .pdf and index.html files

git add .
git commit -m "add created pdf's and index.html's"
git push --force

# Put it all back

after you've done this, you can clean up (from the medley folder):
```
find . -iname "*.pdf" -exec rm {} \;
git remote set-url --push https://github.com/Interlisp/medley
rm -rf loops notecards test
```

