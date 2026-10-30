# The base image is the IRIS Community build with AI Hub from the Early Access Program portal
# (https://evaluation.intersystems.com/Eval/early-access/AIHub); load it with `docker load` first.
ARG IRIS_IMAGE=docker.iscinternal.com/docker-intersystems/intersystems/iris-community:2026.3.0AI.154.0
FROM ${IRIS_IMAGE}

USER root
RUN mkdir -p /data/inbox /data/processed /opt/triage && chown -R ${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} /data /opt/triage
USER ${ISC_PACKAGE_MGRUSER}

# InterSystems Package Manager (IPM); the module is then installed with `zpm "load"`.
ADD --chown=${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} https://pm.community.intersystems.com/packages/zpm/latest/installer /opt/triage/zpm-installer.xml
COPY --chown=${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} module.xml iris.script configure.script after-start.sh /opt/triage/
COPY --chown=${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} src /opt/triage/src
COPY --chown=${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} python /opt/triage/python
COPY --chown=${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} tests /opt/triage/tests
COPY --chown=${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} scripts /opt/triage/scripts

RUN iris start IRIS && iris session IRIS < /opt/triage/iris.script && iris stop IRIS quietly
