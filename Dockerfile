FROM docker.io/alpine:3.8 as builder

MAINTAINER Kris Reese <ktreese@gmail.com>

RUN apk --update add alpine-sdk \
 && adduser -D builder \
 && addgroup builder abuild \
 && sed -i 's/#PACKAGER="Your Name <your@email.address>"/PACKAGER="Kris Reese <ktreese@gmail.com>"/' /etc/abuild.conf \
 && sed -i 's/#MAINTAINER/MAINTAINER/' /etc/abuild.conf \
 && mkdir -p /var/cache/distfiles \
 && chmod a+w /var/cache/distfiles

WORKDIR /home/builder
RUN su builder -c "abuild-keygen -na" \
 && su builder -c "newapkbuild duo_unix"
COPY resources/APKBUILD /home/builder/duo_unix

WORKDIR /home/builder/duo_unix
RUN su builder -c "abuild -r"

FROM docker.io/alpine:3.8

MAINTAINER Kris Reese <ktreese@gmail.com>

RUN apk --update add --no-cache bash openssh openssh-server-pam rsync augeas \
  && deluser $(getent passwd 33 | cut -d: -f1) \
  && delgroup $(getent group 33 | cut -d: -f1) 2>/dev/null || true \
  && mkdir -p ~root/.ssh /etc/authorized_keys && chmod 700 ~root/.ssh/

COPY resources/sshd_config /etc/ssh/
COPY resources/pam.d/sshd /etc/pam.d/
COPY --from=builder /home/builder/.abuild/ktreese@gmail.com*.rsa.pub /etc/apk/keys
COPY --from=builder /home/builder/packages/builder/x86_64/duo_unix-1.11.1-r0.apk /tmp

RUN apk add /tmp/duo_unix-1.11.1-r0.apk \
 && sed -i '/host = /a ; enable autopush\nautopush = yes' /etc/duo/pam_duo.conf \
 && sed -i '/autopush = /a ; limit prompts to 1\nprompts = 1' /etc/duo/pam_duo.conf \
 && rm -f /tmp/duo_unix-1.11.1-r0.apk

EXPOSE 22

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["/usr/sbin/sshd", "-D", "-f", "/etc/ssh/sshd_config"]
