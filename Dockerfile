# IOP

FROM httpd:alpine
MAINTAINER docker@iop.org
LABEL org.iop.tech=Perl
EXPOSE 8888:80

COPY ./httpd.conf /usr/local/apache2/conf/httpd.conf
COPY ./html /usr/local/apache2/htdocs
COPY ./perl /usr/local/apache2/cgi-bin
RUN chmod -R 0700 /usr/local/apache2/cgi-bin
WORKDIR /usr/src/iop/uat_review

