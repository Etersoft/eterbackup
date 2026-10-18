# Test environment for eterbackup: run tests only inside this container
ARG BASE=alt:sisyphus
FROM ${BASE}

RUN apt-get update && \
    apt-get install -y zpaq metastore pax rsync pylog2rotate eepm bats dash \
        diffutils findutils coreutils util-linux && \
    apt-get clean

# non-root tester with an extra group to check group restoring
RUN groupadd eterbackup-test && \
    useradd -m -G eterbackup-test tester

USER tester
ENV TEST_GROUP=eterbackup-test
WORKDIR /src
