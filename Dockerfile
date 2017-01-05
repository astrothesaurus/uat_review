# IOP

# FROM phusion/baseimage
FROM httpd:alpine
MAINTAINER docker@iop.org
LABEL org.iop.tech=Perl
EXPOSE 8888:80

COPY ./httpd.conf /usr/local/apache2/conf/httpd.conf
COPY ./html /usr/local/apache2/htdocs
COPY ./perl /usr/local/apache2/cgi-bin
RUN mkdir /var/log/httpd
RUN apk update && apk add perl-cgi perl-lwp-useragent-determined perl-mime-lite perl-uri perl-lwp-protocol-https && apk add -f perl-encode
RUN apk add postfix
RUN echo "relayhost = internal.mailrouter.iop.org" >> /etc/postfix/main.cf && postfix start
RUN chmod -R 0555 /usr/local/apache2/cgi-bin
WORKDIR /usr/src/iop/uat_review

