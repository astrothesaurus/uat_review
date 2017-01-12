# uat_review
UAT review frontend Perl

This repository contains the Perl CGI scripts, JavaScript and CSS files for the UAT review webapp.

Approach:
Clone gorbynet/docker-4store
run dump.sh from that repo. This does the following:
Stop & remove 4store container if it's already running
Build 4store instance & run it with a label of '4store'. Expose Port 8080 on container.
* docker build -t iop/4store .
* docker run -dit -p8080:8080 --name 4store iop/4store

Configure credentials for Github deposit and SNS notification service in files ./perl/github_config and ./perl/sns_credentials

Run build.sh and run.sh scripts from this repo.

run.sh is now configured to expose uat container port 80 to localhost port 80.
