# syntax=docker/dockerfile:1
#
# Build context is this folder:
#   docker build -t contoso-fabric-worker:dev app/src/worker-python
#
# CF-SUP-031 (planted, two findings in one file):
#   1. There is no USER instruction, so the container runs as root. A container escape or an
#      exploited path-traversal (CF-SEC-012) then has root in the container filesystem.
#   2. There is no HEALTHCHECK instruction, so an image-only consumer has no way to tell a
#      wedged worker from a healthy one.
# Container scanning flags both. Do not fix them unless the task asks - see seeds/FINDINGS.md.

FROM python:3.12-slim AS runtime

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# requirements.txt carries the planted vulnerable pins (CF-DEP-023/024/025) that Dependabot
# raises against. They are deliberately versions that still install and import on 3.12.
COPY requirements.txt ./
RUN pip install --requirement requirements.txt

COPY pyproject.toml ./
COPY worker/ worker/

ENTRYPOINT ["python", "-m", "worker"]
