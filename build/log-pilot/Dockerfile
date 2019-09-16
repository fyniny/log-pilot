FROM cargo.caicloud.xyz/library/golang:1.12.9-stretch

COPY bin/log-pilot /opt/log-pilot/bin/log-pilot
COPY assets/filebeat/filebeat.tpl /opt/log-pilot

WORKDIR /opt/log-pilot
CMD ["/opt/log-pilot/bin/log-pilot"]
