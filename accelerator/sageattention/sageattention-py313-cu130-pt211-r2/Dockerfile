################################################################################
# Dockerfile that builds 'yanwk/comfyui-extras:sageattn-py313-cu130-pt211'.
# Used for compiling SageAttention.
################################################################################

ARG REGISTRY=docker.io

FROM ${REGISTRY}/yanwk/comfyui-boot:base-cu130-pt211-cache AS building-stage

WORKDIR /WORK/wheels

# Limit CPU/RAM usage during builds. Set to 1 to avoid crash on GitHub CI.
ARG MAX_JOBS=1
ARG TORCH_CUDA_ARCH_LIST='8.0;8.6;10.0;12.0+PTX'
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG NO_PROXY
ARG BUILD_BUNDLE_PTXAS=1


RUN pip install build "wheel<0.44" "packaging<24"

################################################################################
# Download repo and fix
ARG UPSTREAM_REPO="https://github.com/thu-ml/SageAttention"
ARG UPSTREAM_BRANCH="main"
ARG UPSTREAM_COMMIT="d1a57a5"
ARG CUDA_VERSION="cu130"
ARG TORCH_VERSION="pt211"
ARG PYTHON_VERSION="cp313"
ARG VIRIANT="r2"
# docker build cache id, 避免缓存冲突
ARG CACHE_KEY="sageattn-${PYTHON_VERSION}-${CUDA_VERSION}-${TORCH_VERSION}-${VIRIANT}"

RUN echo "===> [MATRIX CHECK] Repo: ${UPSTREAM_REPO} | Branch: ${UPSTREAM_BRANCH} | COMMIT: ${UPSTREAM_COMMIT} | CUDA: ${CUDA_VERSION}"

RUN ${HTTPS_PROXY:+git config --global https.proxy $HTTPS_PROXY} && \
    ${HTTP_PROXY:+git config --global http.proxy $HTTP_PROXY} && \
    git clone --single-branch --branch ${UPSTREAM_BRANCH} --recurse-submodules\
    ${UPSTREAM_REPO} \
/WORK/SageAttention

WORKDIR /WORK/SageAttention
# 切换到 meta.yaml 指定的精准分支、Tag 或 Commit SHA
RUN git checkout ${UPSTREAM_COMMIT}
################################################################################
# SageAttention

# TORCH_CUDA_ARCH_LIST can only contain architectures supported by both PyTorch and SageAttention.
# Check before set:
# https://github.com/pytorch/pytorch/blob/v2.11.0/.ci/manywheel/build_cuda.sh
# https://github.com/thu-ml/SageAttention/blob/main/setup.py
# Or check in Python:
# python3.13 -c 'import torch; print(torch._C._cuda_getArchFlags())'
WORKDIR /WORK/SageAttention

RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=cache,id=${CACHE_KEY}-build,target=/WORK/SageAttention/build \
    --mount=type=cache,id=${CACHE_KEY}-dist,target=/WORK/SageAttention/dist \
    python3.13 -m build --wheel --no-isolation --outdir /WORK/wheels .

RUN set -eu \
    && BUILD_SHA=$(git rev-parse --short=7 HEAD) \
    && cd /WORK/wheels \
    && for f in *.whl; do \
         PREFIX=${f%%-cp313*} \
         && mv "$f" "${PREFIX}+git.${BUILD_SHA}.${CUDA_VERSION}.${TORCH_VERSION}-${PYTHON_VERSION}-${PYTHON_VERSION}-linux_x86_64.whl"; \
       done

################################################################################
# Save the result
FROM ${REGISTRY}/library/alpine:latest AS saving-stage

LABEL maintainer="YAN Wenkun <code@yanwk.fun>"

COPY --from=building-stage /WORK/wheels /wheels
