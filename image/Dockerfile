FROM ubuntu:24.04
ARG RUNNER_VERSION=2.336.0
ARG RUNNER_SHA256_AMD64=04cf0be1aff4c3ec3554466c39124ca250e3effd8873bb7e8d68535aa9505d5d
ENV DEBIAN_FRONTEND=noninteractive RUNNER_ALLOW_RUNASROOT=0
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git jq sudo tar gzip coreutils tini docker.io \
    build-essential pkg-config libssl-dev cmake clang lld protobuf-compiler \
    software-properties-common gnupg wget file procps psmisc lsof libicu-dev \
    libsqlite3-dev sqlite3 uidmap iproute2 iputils-ping dnsutils && \
    rm -rf /var/lib/apt/lists/*
RUN groupadd --gid 1001 runner && useradd --uid 1001 --gid 1001 --create-home \
    --shell /bin/bash runner && echo 'runner ALL=(ALL) NOPASSWD:ALL' >/etc/sudoers.d/runner && chmod 0440 /etc/sudoers.d/runner && \
    install -d -o runner -g runner /opt/actions-runner /runner-data/state /runner-data/_work /runner-data/tmp
RUN set -eu; archive="actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"; \
    curl --fail --location --retry 3 "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${archive}" -o "/tmp/${archive}"; \
    printf "%s  %s\n" "${RUNNER_SHA256_AMD64}" "/tmp/${archive}" > /tmp/actions-runner.sha256; \
    sha256sum --check --strict /tmp/actions-runner.sha256; rm /tmp/actions-runner.sha256; \
    tar -xzf "/tmp/${archive}" -C /opt/actions-runner; rm "/tmp/${archive}"; \
    chown -R runner:runner /opt/actions-runner
COPY --chmod=0755 entrypoint.sh /usr/local/bin/lerd-runner-entrypoint
COPY --chmod=0755 job-cleanup.sh /usr/local/bin/lerd-runner-job-cleanup.sh
USER runner
WORKDIR /opt/actions-runner
ENV RUNNER_WORKDIR=/runner-data/_work DOCKER_HOST=tcp://127.0.0.1:2375
ENTRYPOINT ["/usr/bin/tini","--","/usr/local/bin/lerd-runner-entrypoint"]
