# IOP

FROM httpd:alpine
MAINTAINER docker@iop.org
LABEL org.iop.tech=Perl
EXPOSE 8888:80

COPY ./httpd.conf /usr/local/apache2/conf/httpd.conf
COPY ./html /usr/local/apache2/htdocs
COPY ./perl /usr/local/apache2/cgi-bin
RUN mkdir /var/log/httpd
RUN apk update
RUN apk add perl-cgi
RUN apk add perl-lwp-useragent-determined
RUN apk add perl-mime-lite
RUN apk add -f perl-encode
# RUN apk add perl-data-dumper | available from alpine 3.5 only
# RUN apk add perl-html
# RUN apk add perl-lwp-simple | not available
# RUN apk add perl-posix ?part of core perl?
RUN apk add perl-uri
RUN chmod -R 0555 /usr/local/apache2/cgi-bin
WORKDIR /usr/src/iop/uat_review

RUN apk add ca-certificates wget
wget https://www.dropbox.com/s/92th9xaew01ewm2/apj_metadata.nt?dl=0 -O metadata.nt
wget https://www.dropbox.com/s/vhc2ampsjgawqrr/2016R3_rc1.rdf?dl=0 -O thesaurus.rdf
