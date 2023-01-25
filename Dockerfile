ARG IMAGE=intersystemsdc/irishealth-community
FROM $IMAGE

USER root   
# Add Git
RUN apt update && apt-get -y install git
        
WORKDIR /opt/irisbuild
RUN chown ${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} /opt/irisbuild
USER ${ISC_PACKAGE_MGRUSER}

# COPY  Installer.cls .
COPY src src
COPY module.xml module.xml
COPY iris.script iris.script
COPY do-conversion.sh do-conversion.sh

RUN iris start IRIS \
	&& iris session IRIS < iris.script \
    && iris stop IRIS quietly

ENTRYPOINT [ "/iris-main" ]
CMD ["-a", "/opt/irisbuild/do-conversion.sh", "-l", "/usr/irissys/mgr/messages.log", "--check-caps", "false", "--ISCAgent", "false"]