# How to contribute to the [Medley Interlisp project](https://Interlisp.org)

First, we want to thank you for helping reach the goal of restoring Medley Interlisp
to the point where it is as useful today as it was 30 years ago.

This guide is meant to help you make useful contributions, whether to the [Maiko](https://github.com/Interlisp/maiko) C-based virtual machine implementation, the [Medley](https://github.com/Interlisp/medley) Lisp code (in Interlisp and Common Lisp), or [documentation](https://github.com/Interlisp/medley/wiki). There are a number of [GitHub](https://github.com/Interlisp/medley/discussions/categories/github-use) problems that could use some attention.

## Working with Maiko

Be aware that we are working with 30-year-old code, and there are quite a few unforseen interactions.
The C code was originally written to K&R C before C standards, for a big-endian 32-bit machine.

## Working with Medley 

The current arrangement of files and extentions is awkward for working on the implementation. We're still cataloging what we have and how well it works.

* The most useful contributions are reproducible errors -- things that don't work as documented.
* Second most useful are reports of unexpected behavior -- things that aren't documented but behave unexpectedly.

## Reporting a bug or feature request
* Ensure the bug was not already reported by searching on GitHub under [Issues](https://github.com/Interlisp/medley/issues) or [Discussions](https://github.com/Interlisp/medley/discussions). Note that all issues and Discussions are found in the Medley repository, using labels to distinguish. Discussions are for questions or topics where there is some disagreement or uncertainty about the "right" direction.
* If you're unable to find a discussion or open issue addressing the problem, open a new one. Be sure to include a title 
and clear description, as much relevant information as possible. Use the issue templates to guide you. See [this guide](https://github.com/ncovercash/reporting-bugs-effectively/blob/master/ENGLISH.md).

## Did you write a patch that fixes a bug?  
* Some bug fixes and "improvements" have unintended consequences, well beyond what you might expect for well-written modern code. We don't have testing new builds automated or integrated. Be sure you've tested your patch.
* Open a new [GitHub pull request](https://github.com/Interlisp/maiko/pulls) with the patch.
* Ensure the PR description clearly describes the problem and solution. Include the relevant issue number if applicable.
* Keep Pull Requests small and easily reviewable.  https://www.thedroidsonroids.com/blog/splitting-pull-request for
a writeup of good practices.

Note that changes that are cosmetic in nature and do not add anything substantial to the stability, functionality, or testability of Medley Interlisp will generally not be accepted.


## Do you intend to add a new feature or change an existing one?
* Suggest your change as a Discussion before starting to write code. Is the feature consistent with the overall Medley Interlisp project goals?
* Do not open an issue on GitHub until you have collected positive feedback about the change. GitHub issues are primarily intended for bug reports and fixes.

Medley Interlisp is a volunteer effort. We want to make this a fun experience for everyone. We encourage you to pitch in and join the team.


(These guidelines adapted from https://github.com/rails/rails/blob/master/CONTRIBUTING.md )
