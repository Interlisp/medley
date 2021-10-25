# How to build a medley release

Originally done only with shell scripts:

./scripts/loadup-all.sh 
./scripts/loadup-and-release.sh


# Using github actions

In the github medley repository (Interlisp/medley) go to the Actions tab. 

It will list the available github actions, select: **Build Medley Release**. 

In the middle of the screen there's a box labeled workflow runs.
There should be a row in it that states 'This workflow has a workflow_dispatch event trigger' with a drop down menu (it really looks more like a button) on the right side labeled 'Run workflow'.  Select that and you'll get a form allowing you to select the branch (I've only used Master) and enter the release name.  Enter a name or leave it empty and press the green 'Run workflow' button. The workflow should queue up and run.  

# How to create a Docker image for the latest Medley release

In the github medley repository (Interlisp/medley) go to the Actions tab. 

It will list the available github actions, select: **Build Medley Docker image**. 

A table is presented which lists the previous runs of the workflow.  If the workflow has never been run, it will be empty.  A the top of the list is a row labeled, 'This workflow has a workflow_dispatch event trigger.' with a drop down menu labeled 'Run workflow'.  Select it.

A box will be presented asking, 'Use workflow from' with a drop down menu of all available branches.  The default branch is **master**.  Leave it selected and push the green 'Run workflow' button.

The workflow will be queued to run and start running.

The workflow pulls the latest Maiko image from Docker Hub and the Release Assets from the latest Medley release, generally defined as medley-YYMMDD.  The Medley Docker image adds in Tight VNC Server and retrieves the two tarballs associated with a release, one containing the sysouts and the other the other needed files source, fonts, etc.  The contents are uncompressed and loaded into the Medley directory structure.
