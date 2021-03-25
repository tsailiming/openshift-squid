# squid-openshift
FROM quay.io/centos/centos:stream8

LABEL io.k8s.description="Squid Proxy" \
      io.k8s.display-name="Squid 4.x" \
      io.openshift.tags="squid"

RUN yum clean all -y && yum -y update && yum install -y squid telnet && yum clean all -y

ADD squid.conf /etc/squid/squid.conf
#ADD sites.whitelist.txt /etc/squid/sites.whitelist.txt

COPY entrypoint.sh /sbin/entrypoint.sh
RUN chmod 755 /sbin/entrypoint.sh

USER 1001
EXPOSE 3128/tcp

CMD  /sbin/entrypoint.sh
#ENTRYPOINT ["/sbin/entrypoint.sh"]
