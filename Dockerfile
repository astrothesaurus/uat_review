# IOP

# FROM phusion/baseimage
FROM httpd:alpine
MAINTAINER docker@iop.org
LABEL org.iop.tech=Perl
EXPOSE 8888:80

#	COPY ./httpd.conf /usr/local/apache2/conf/httpd.conf
#	COPY ./html /usr/local/apache2/htdocs
#	COPY ./perl /usr/local/apache2/cgi-bin
#	COPY ./export /usr/local/apache2/export
RUN mkdir /var/log/httpd
RUN apk update && apk add perl-cgi perl-lwp-useragent-determined perl-uri perl-lwp-protocol-https && apk add -f perl-encode
RUN apk add -f perl-dev && apk add build-base gcc make perl-mime-base64 perl-xml-simple perl-digest-hmac perl-mime-tools perl-http-message
RUN wget http://search.cpan.org/CPAN/authors/id/S/SH/SHERZODR/Net-AWS-SES-0.04.tar.gz && wget http://search.cpan.org/CPAN/authors/id/E/ES/ESAYM/Time-Piece-1.31.tar.gz
RUN tar -xvf Net-AWS-SES-0.04.tar.gz && tar -xvf Time-Piece-1.31.tar.gz
RUN pwd && ls
RUN cd ./Time-Piece-1.31 && perl Makefile.PL && make && make -i test && make install
RUN cd ./Net-AWS-SES-0.04 && perl Makefile.PL && make && make -i test && make install
#	RUN chmod -R 0555 /usr/local/apache2/cgi-bin
#	RUN chmod -R 0555 /usr/local/apache2/export
#	WORKDIR /usr/src/iop/uat_review

