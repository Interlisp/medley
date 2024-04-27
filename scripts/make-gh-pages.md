preliminary documentation -- needs validation
HCFILES writes in {MEDLEYDIR} but it should write in something like (SRCDIR)

# setup

 github pages are maintained in the 'src' repository as a forked repo
 If you don't have a clone of src: 
```
   gh repo clone interlisp/src # make one
   cd src                      # all other commands 
```
the first time once you've cloned, point the 'src' clone 
```
   gh remote add upstream https://github.com/interlisp/medley

```
now update src repository to match 'medley'
Run these in the 'src' repository!

```
   git fetch upstream                # pull down remote branches
   git checkout master               # make sure you're in master
   git rebase upstream/master        # update src's master
                                      # to latest medley's master
   git push -f origin master          # push back go sfc
```

# Run Medly to create PDFs.

Start with the apps sysout to spare yourself package problems
In an Interlisp exec:
```
  (FILESLOAD PDFSTREAM GITFNS MEDLEY-UTILS)
  (HCFILES)
  (MAKE-INDEX-HTMLS)
```
check out that it looks right if you point your browser the index/index.hrml at the top level

# deploying

* find the current release tags
Not sure how to do that.

```
   wget -l 1 https://github.com/interlisp/medley/releases/latest
```
will retrieve a 3xx redirect from the web server;
But all you need is the name, not the web page.
anyway, assuming the release is medley-YYMMDD-xxxxxxx. 

put release name in variable
```
  export release=medley-240420-1234567
```
## make a new branch
```
   git checkout -b pages-$release
```
*temporarily* change .gitignore to allow checkin of pdfs and index.html
```
cp .gitignore /tmp/save$release
cp .gitignore.for.pages .gitignore
```
Now you can push this to the github-pages
```
	git add .
	git commit -m "rerun making ghpages and index"
	git push
```




