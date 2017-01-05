# uat_review
UAT review frontend Perl

This repository contains the Perl CGI scripts, JavaScript and CSS files for the UAT review webapp.

Approach:
Clone gorbynet/docker-4store
Build 4store instance & run it with a label of '4store'. Expose Port 8080 on container.
* docker build -t iop/4store .
* docker run -dit -p8080:8080 --name 4store iop/4store

Run build.sh and run.sh scripts from this repo.

The webapp should be available via port 8888 from the 'uat' container

TODO:
* Generate full 2016 data dump
* Transfer data to IOP dropbox account
