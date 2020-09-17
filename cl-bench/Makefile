# To modify optimization settings, you can change the $(OPTIMIZE)
# variable below. This is prepended to the lisp source files before
# they are compiled.
#
# Requires GNU Make or equivalent.

SHELL = /bin/sh
OPTIMIZE = "(declaim (optimize (speed 3) (space 1) (safety 0) (debug 0) (compilation-speed 0)))"


FILES := $(patsubst %.lisp,%.olisp, $(wildcard files/*.lisp))
vpath %.lisp   files

%.olisp: %.lisp
	echo $(OPTIMIZE) > $@
	cat $< >> $@


optimize-files: $(FILES)



clean-results:
	-rm -f /var/tmp/CL-bench*

clean: 
	find . \( -name '*.abcl' -o -name '*.cls' -o -name '*.sparcf' -o -name "*.ppcf" -o -name '*.x86f' -o -name '*.lbytef' -o -name "*.err" -o -name '*.fas' -o -name '*.fasl' -o -name "*.faslmt" -o -name '*.lib' -o -name '*.o' -o -name '*.so' -o -name "*.pfsl" -o -name "*.ufsl" -o -name "*.dfsl" -o -name "*.olisp" -o -name "*.dfsl" -o -name "*.fsl" -o -name "*.nfasl" \) -print | xargs rm -f

distclean: clean clean-results

.PHONY: clean clean-results distclean optimize-files

# EOF
