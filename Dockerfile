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

