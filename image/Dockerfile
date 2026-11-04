FROM eclipse-temurin:17-jre-jammy

# URL or local path (inside the build context) of the StarRocks Cluster Sync tarball
ARG SYNC_TGZ=https://releases.starrocks.io/starrocks/starrocks-cluster-sync.tar.gz

WORKDIR /opt/starrocks-cluster-sync
ADD ${SYNC_TGZ} /tmp/starrocks-cluster-sync.tar.gz
RUN tar xzf /tmp/starrocks-cluster-sync.tar.gz --strip-components=1 -C /opt/starrocks-cluster-sync \
 && rm /tmp/starrocks-cluster-sync.tar.gz \
 && sed -i 's/^rootLogger = .*/rootLogger = INFO, consoleAppender/' conf/log4j2.properties \
 && chmod +x bin/*.sh

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
