Running the Benchmarks
All the files for doing benchmarks were in this folder.
This file would have told you where to find the files you need, and how to run the various benchmarks.dir

Overall directory layout:
	Information	Gabriel>, this file.
	Procedures	Gabriel>Admin> for overall procedure files, rather than specific test plans or scripts
	Benchmarks	Gabriel>Benchmarks> for lisp source & compiled files containing specific benchmarks
	Results		Gabriel>Results> for the results of benchmark runs.
	Tools		Gabriel>Tools> for general-purpose files like gabriel-timers.
	Auxiliary Files	Gabriel>Aux> for auxiliary files, e.g., the file of FLOATs that gets read in by the floating-point-read benchmark.
	Interlisp 	Gabriel>Interlisp> for the old, Interlisp-only versions of the Gabriel benchmarks that were run before Common Lisp existed.
The directory in detail:
.
The Benchmarks you might want to run
.
Creating a Benchmark
1.	Load Tools>GABRIEL-TIMERS.LCOM, which defines all the functions you'll need.
2.	Use the function GABRIEL::DEFINE-TIMER (documented below) to create each benchmark.  You'll be assigning the benchmark a name, and you may want to define auxiliary functions for the benchmark (e.g. for cleanup) as well.
3.	To try out your benchmarks, first compile all the TIMERS definitions and auxiliary functions (I use ^C in SEdit quite nicely), then say to an Exec:
			 GABRIEL::RUN-BENCHMARKS((>>your b/m names here<<))
	to try them out.
4.	Save all the timers and functions on a file, MAKEFILE it, and compile it.  After you load the compiled file, you'll be able to run the new benchmarks wherever you loaded it.

(GABRIEL::DEFINE-TIMER
	(name
		[(:SETUP single-setup-form)]
		[(:AFTER-EVERY single-cleanup-form)]
		[(:AFTER single-cleanup-form)] )
	"optional documentation string"
	forms-to-run-for-the-benchmark )

Defines a benchmark named name, which will run forms-to-run-for-the-benchmark for every iteration of the benchmark.  If you specify the :SETUP clause, the single form single-setup-form you supply will be run once before the first iteration of the benchmark.  If you specify :AFTER, that single cleanup form will be run after the last iteration of the benchmark has been run; the :AFTER-EVERY cleanup form will be run after each iteration (including the last one).
Running Benchmarks
1.	Load Tools>GABRIEL-TIMERS.LCOM, which defines all the functions you'll need.
2.	Load the files that contain the benchmarks you want to run.  Loading a file of benchmarks adds the names of those benchmarks to the list GABRIEL::*ALL-TIMERS*.
3.	Use the function GABRIEL:RUN-BENCHMARKS, described below.

(GABRIEL::RUN-BENCHMARKS
   &OPTIONAL	(BENCHMARKS GABRIEL::*ALL-TIMERS*)
			(DRIBBLE-FILE (QUOTE {DSK}GABRIEL.BENCHMARKS))
			(NUMBER-OF-ITERATIONS GABRIEL::*MINIMUM-TESTS*))

Runs the benchmarks named in BENCHMARKS, defaulting to the list of all the benchmarks that you've loaded.  The timing results are printed in the Exec window, and on the file DRIBBLE-FILE.  Each test will be run NUMBER-OF-ITERATIONS times, defaulting to 2.
Running the Standard Benchmark Set
1.	Load the files :
		Tools>GABRIEL-TIMERS.LCOM
		{ERIS}<LispCore>Benchmarks>GABRIEL-OTHER.dfasl
		{ERIS}<LispCore>Benchmarks>GABRIEL-TAK.dfasl
		{ERIS}<LispCore>Benchmarks>ARITH-BENCHMARKS.dfasl
		{ERIS}<LispCore>Benchmarks>IO-BENCHMARKS.LCOM
2a.	If you are running on an 1186, run the following functions:
		(GABRIEL::RUN-BENCHMARKS
		GABRIEL::*TAK-TIMERS*
		'Results>Maiko>1186-PAV-TAK.Results)
		(GABRIEL::RUN-BENCHMARKS
		GABRIEL::*IO-BENCHMARKS*
		'Results>Maiko>1186-IO.Results)
		(GABRIEL::RUN-BENCHMARKS
		IL:*ARITH-BENCHMARKS*
		'Results>Maiko>1186-PAV-ARITH.Results)
		(GABRIEL::RUN-BENCHMARKS
		GABRIEL::*AREFY-BENCHMARKS*
		'Results>Maiko>1186-PAV-AREFY.Results)
		(GABRIEL::RUN-BENCHMARKS
		GABRIEL::*CONSY-BENCHMARKS*
		'Results>Maiko>1186-PAV-CONSY.Results)
		(GABRIEL::RUN-BENCHMARKS
		GABRIEL::*POLY-BENCHMARKS*
		'Results>Maiko>1186-PAV-POLY.Results)
		(GABRIEL::RUN-BENCHMARKS
		GABRIEL::*MISC-BENCHMARKS*
		'Results>Maiko>1186-PAV-MISC.Results)

2b.	If you are running on a Sun, run the following:
		(GABRIEL::RUN-BENCHMARKS
		GABRIEL::*TAK-TIMERS*
		'Results>Maiko>SUN-PAV-TAK.Results)
		(GABRIEL::RUN-BENCHMARKS
		GABRIEL::*MAIKO-IO-BENCHMARKS*
		'Results>Maiko>SUN-IO.Results)
		(GABRIEL::RUN-BENCHMARKS
		IL:*ARITH-BENCHMARKS*
		'Results>Maiko>SUN-PAV-ARITH.Results)
		(GABRIEL::RUN-BENCHMARKS
		GABRIEL::*AREFY-BENCHMARKS*
		'Results>Maiko>SUN-PAV-AREFY.Results)
		(GABRIEL::RUN-BENCHMARKS
		GABRIEL::*CONSY-BENCHMARKS*
		'Results>Maiko>SUN-PAV-CONSY.Results)
		(GABRIEL::RUN-BENCHMARKS
		GABRIEL::*POLY-BENCHMARKS*
		'Results>Maiko>SUN-PAV-POLY.Results)
		(GABRIEL::RUN-BENCHMARKS
		GABRIEL::*MISC-BENCHMARKS*
		'Results>Maiko>SUN-PAV-MISC.Results)
2c.	If you are running on an 1108, run the following:
		(GABRIEL::RUN-BENCHMARKS
		GABRIEL::*TAK-TIMERS*
		'Results>Maiko>1108-PAV-TAK.Results)
		(GABRIEL::RUN-BENCHMARKS
		GABRIEL::*MAIKO-IO-BENCHMARKS*
		'Results>Maiko>1108-IO.Results)
		(GABRIEL::RUN-BENCHMARKS
		IL:*ARITH-BENCHMARKS*
		'Results>Maiko>1108-PAV-ARITH.Results)
		(GABRIEL::RUN-BENCHMARKS
		GABRIEL::*AREFY-BENCHMARKS*
		'Results>Maiko>1108-PAV-AREFY.Results)
		(GABRIEL::RUN-BENCHMARKS
		GABRIEL::*CONSY-BENCHMARKS*
		'Results>Maiko>1108-PAV-CONSY.Results)
		(GABRIEL::RUN-BENCHMARKS
		GABRIEL::*POLY-BENCHMARKS*
		'Results>Maiko>1108-PAV-POLY.Results)
		(GABRIEL::RUN-BENCHMARKS
		GABRIEL::*MISC-BENCHMARKS*
		'Results>Maiko>1108-PAV-MISC.Results)
2d.	If you are running on a Dorado, run the following:
		(GABRIEL::RUN-BENCHMARKS
		GABRIEL::*TAK-TIMERS*
		'Results>Maiko>1132-PAV-TAK.Results)
		(GABRIEL::RUN-BENCHMARKS
		GABRIEL::*MAIKO-IO-BENCHMARKS*
		'Results>Maiko>1132-IO.Results)
		(GABRIEL::RUN-BENCHMARKS
		IL:*ARITH-BENCHMARKS*
		'Results>Maiko>1132-PAV-ARITH.Results)
		(GABRIEL::RUN-BENCHMARKS
		GABRIEL::*AREFY-BENCHMARKS*
		'Results>Maiko>1132-PAV-AREFY.Results)
		(GABRIEL::RUN-BENCHMARKS
		GABRIEL::*CONSY-BENCHMARKS*
		'Results>Maiko>1132-PAV-CONSY.Results)
		(GABRIEL::RUN-BENCHMARKS
		GABRIEL::*POLY-BENCHMARKS*
		'Results>Maiko>1132-PAV-POLY.Results)
		(GABRIEL::RUN-BENCHMARKS
		GABRIEL::*MISC-BENCHMARKS*
		'Results>Maiko>1132-PAV-MISC.Results)
3.	Load the files:
	{ERIS}<LispCore>Benchmarks>GABRIEL-OTHER.LCOM
		{ERIS}<LispCore>Benchmarks>GABRIEL-TAK.LCOM
		{ERIS}<LispCore>Benchmarks>ARITH-BENCHMARKS.LCOM
4a.	If you are running on an 1186, run the following functions:
		(GABRIEL::RUN-BENCHMARKS
		GABRIEL::*TAK-TIMERS*
		'Results>Maiko>1186-BYTE-TAK.Results)
		(GABRIEL::RUN-BENCHMARKS
		IL:*ARITH-BENCHMARKS*
		'Results>Maiko>1186-BYTE-ARITH.Results)
		(GABRIEL::RUN-BENCHMARKS
		GABRIEL::*AREFY-BENCHMARKS*
		'Results>Maiko>1186-BYTE-AREFY.Results)
		(GABRIEL::RUN-BENCHMARKS
		GABRIEL::*CONSY-BENCHMARKS*
		'Results>Maiko>1186-BYTE-CONSY.Results)
		(GABRIEL::RUN-BENCHMARKS
		GABRIEL::*POLY-BENCHMARKS*
		'Results>Maiko>1186-BYTE-POLY.Results)

4b.	If you are running on a Sun, run the following:
		(GABRIEL::RUN-BENCHMARKS
		GABRIEL::*TAK-TIMERS*
		'Results>Maiko>SUN-BYTE-TAK.Results)
		(GABRIEL::RUN-BENCHMARKS
		IL:*ARITH-BENCHMARKS*
		'Results>Maiko>SUN-BYTE-ARITH.Results)
		(GABRIEL::RUN-BENCHMARKS
		GABRIEL::*AREFY-BENCHMARKS*
		'Results>Maiko>SUN-BYTE-AREFY.Results)
		(GABRIEL::RUN-BENCHMARKS
		GABRIEL::*CONSY-BENCHMARKS*
		'Results>Maiko>SUN-BYTE-CONSY.Results)
		(GABRIEL::RUN-BENCHMARKS
		GABRIEL::*POLY-BENCHMARKS*
		'Results>Maiko>SUN-BYTE-POLY.Results)
4c.	If you are running on an 1108, run the following:
		(GABRIEL::RUN-BENCHMARKS
		GABRIEL::*TAK-TIMERS*
		'Results>Maiko>1108-BYTE-TAK.Results)
		(GABRIEL::RUN-BENCHMARKS
		IL:*ARITH-BENCHMARKS*
		'Results>Maiko>1108-BYTE-ARITH.Results)
		(GABRIEL::RUN-BENCHMARKS
		GABRIEL::*AREFY-BENCHMARKS*
		'Results>Maiko>1108-BYTE-AREFY.Results)
		(GABRIEL::RUN-BENCHMARKS
		GABRIEL::*CONSY-BENCHMARKS*
		'Results>Maiko>1108-BYTE-CONSY.Results)
		(GABRIEL::RUN-BENCHMARKS
		GABRIEL::*POLY-BENCHMARKS*
		'Results>Maiko>1108-BYTE-POLY.Results)
4d.	If you are running on a Dorado, run the following:
		(GABRIEL::RUN-BENCHMARKS
		GABRIEL::*TAK-TIMERS*
		'Results>Maiko>1132-BYTE-TAK.Results)
		(GABRIEL::RUN-BENCHMARKS
		IL:*ARITH-BENCHMARKS*
		'Results>Maiko>1132-BYTE-ARITH.Results)
		(GABRIEL::RUN-BENCHMARKS
		GABRIEL::*AREFY-BENCHMARKS*
		'Results>Maiko>1132-BYTE-AREFY.Results)
		(GABRIEL::RUN-BENCHMARKS
		GABRIEL::*CONSY-BENCHMARKS*
		'Results>Maiko>1132-BYTE-CONSY.Results)
		(GABRIEL::RUN-BENCHMARKS
		GABRIEL::*POLY-BENCHMARKS*

'Results>Maiko>1132-BYTE-POLY.Results)
5.	SEE each of the .Results files listed above, average the run times (mentally is probably fine), and enter the results in the benchmark log.
