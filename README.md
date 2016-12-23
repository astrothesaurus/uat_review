# uat_review
UAT review frontend Perl

This repository contains the Perl CGI scripts, JavaScript and CSS files for the UAT review webapp.

Approach:
Clone gorbynet/docker-4store
Build 4store instance & run it with a label of '4store'. Expose Port 8080 on container.
Run build.sh and run.sh scripts from this repo.

The webapp should be available via port 8888 from the 'uat' container

TODO:
* Upload data to 4store Docker container. It should have been downloaded from Dropbox via wget.
