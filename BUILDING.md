# How to build a medley release

Originally done only with shell scripts:

./scripts/loadup-all.sh 
./scripts/loadup-and-release.sh


# Using github actions

In the github medley repository (Interlisp/medley) go to the Actions tab. 

It should list the available github actions, select the bottom one, Build Medley Release. 

In the middle of the screen there's a box labeled workflow runs.
There should be a row in it that states 'This workflow has a workflow_dispatch event trigger' with a drop down menu (it really looks more like a button) on the right side labeled 'Run workflow'.  Select that and you'll get a form allowing you to select the branch (I've only used Master) and enter the release name.  Enter a name or leave it empty and press the green 'Run workflow' button. The workflow should queue up and run.  
