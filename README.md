# uat_review
UAT review frontend Perl

This repository contains the Perl CGI scripts, JavaScript and CSS files for the UAT review webapp.

TODO:
* ~~Taint checking~~
* ~~Update references to Corichi - switch to localhost~~
* ~~Tidy code - remove debugging & redundant commented code~~
* Make data available - metadata, thesaurus.
* ~~Update references to thesaurus graph - from 2016R3rc1 to 2016R3~~



General TODO for Dockerfile:

* Apache CGI config - enable CGI, directory aliasing
* Clone this repo into cgi-bin directory
* Check 4store port - new 4store config file?
* Script for pulling data files & loading them into 4store

General Docker approach:
* Use Debian base
* Install/enable apache, avahi, dbus services (update files to ensure services run at start?)
* Clone & compile 4store
* 4store database config (ports, database name) - update/replace conf file
* Start 4store backend daemons
 * 4s-boss
 * 4s-backend-setup articles
 * 4s-backend articles
* Apache CGI config
* Clone this repo to cgi-bin directory with +x permissions
* Move js/css to /var/www/html/js & css dirs
* Expose ports outside container - 80 (8080?)
* Load graphs into 4store
 * 4s-import articles -fturtle -mhttp://data.iop.org/uat_review metadata.nt
 * 4s-import articles -fturtle -mhttp://data.iop.org/thesaurus/2016R3 2016R3.rdf
* Start 4store HTTP daemon
 *  4s-httpd articles
* Check app is available over web interface
