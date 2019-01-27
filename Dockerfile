FROM docker.io/alpine:3.8

MAINTAINER Kris Reese <ktreese@gmail.com>

WORKDIR /root

RUN apk --update add --no-cache bash git openssh openssh-server-pam rsync augeas alpine-sdk openssl-dev linux-pam-dev \
  && deluser $(getent passwd 33 | cut -d: -f1) \
  && delgroup $(getent group 33 | cut -d: -f1) 2>/dev/null || true \
  && mkdir -p ~root/.ssh /etc/authorized_keys && chmod 700 ~root/.ssh/

COPY resources/sshd_config /etc/ssh/
COPY resources/pam.d/sshd /etc/pam.d/

ADD https://dl.duosecurity.com/duo_unix-latest.tar.gz /root

RUN tar zxvf duo_unix-latest.tar.gz \
 && cd ./duo* \
 && ./configure --with-pam --prefix=/usr \
 && make \
 && sudo make install \
 && sed -i '/host = /a ; enable autopush\nautopush = yes' /etc/duo/pam_duo.conf \
 && sed -i '/autopush = /a ; limit prompts to 1\nprompts = 1' /etc/duo/pam_duo.conf

EXPOSE 22

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["/usr/sbin/sshd", "-D", "-f", "/etc/ssh/sshd_config"]
