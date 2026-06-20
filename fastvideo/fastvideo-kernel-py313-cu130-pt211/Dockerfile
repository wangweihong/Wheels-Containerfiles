################################################################################
# Dockerfile that builds 'yanwk/comfyui-extras:fastvideo-kernel-py313'.
# Used for compiling fastvideo-kernel.
################################################################################

ARG REGISTRY=docker.io

FROM ${REGISTRY}/yanwk/comfyui-boot:base-cu130-pt211-cache AS building-stage

WORKDIR /WORK/wheels

# Limit CPU/RAM usage during builds. Set to 1 to avoid crash on GitHub CI.
ARG MAX_JOBS=2
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG NO_PROXY
ARG TORCH_CUDA_ARCH_LIST='7.5;8.0;8.6;8.9;10.0;12.0+PTX'

################################################################################
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install uv build

ARG UPSTREAM_REPO="https://github.com/hao-ai-lab/FastVideo"
ARG UPSTREAM_BRANCH="main"
ARG UPSTREAM_COMMIT="87f98c9"
ARG CUDA_VERSION="cu130"
ARG TORCH_VERSION="pt211"
ARG VIRIANT="standard"
# docker build cache id, 避免缓存冲突
ARG CACHE_KEY="fastvideo-kernel-py313-${CUDA_VERSION}-${TORCH_VERSION}-${VIRIANT}"

RUN echo "===> [MATRIX CHECK] Repo: ${UPSTREAM_REPO} | Branch: ${UPSTREAM_BRANCH} | COMMIT: ${UPSTREAM_COMMIT} | CUDA: ${CUDA_VERSION}"

RUN ${HTTPS_PROXY:+git config --global https.proxy $HTTPS_PROXY} && \
    ${HTTP_PROXY:+git config --global http.proxy $HTTP_PROXY} && \
    git clone --single-branch --branch ${UPSTREAM_BRANCH} --recurse-submodules\
    ${UPSTREAM_REPO} \
/WORK/FastVideo

WORKDIR /WORK/FastVideo

# 切换到 meta.yaml 指定的精准分支、Tag 或 Commit SHA
RUN git checkout ${UPSTREAM_COMMIT}

# Fix for CMAKE missing package configuration file
ENV CMAKE_PREFIX_PATH=/usr/local/lib64/python3.13/site-packages/torch/share/cmake
ENV CUDACXX=$CUDA_HOME/bin/nvcc


WORKDIR /WORK/FastVideo/fastvideo-kernel

RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=cache,id=${CACHE_KEY}-build,target=/WORK/FastVideo/fastvideo-kernel/build \
    --mount=type=cache,id=${CACHE_KEY}-dist,target=/WORK/FastVideo/fastvideo-kernel/dist \
    python3.13 -m build --wheel --no-isolation --outdir /WORK/wheels . 

RUN set -eu \
    && BUILD_SHA=$(git rev-parse --short=7 HEAD) \
    && cd /WORK/wheels \
    && for f in *.whl; do \
         PREFIX=${f%%-cp313*} \
         && mv "$f" "${PREFIX}+git.${BUILD_SHA}-py313.${CUDA_VERSION}.${TORCH_VERSION}-cp313-cp313-linux_x86_64.whl"; \
       done

################################################################################
# Save the result
FROM ${REGISTRY}/library/alpine:latest AS saving-stage

LABEL maintainer="Wangweihong <wangweihong2018@qq.com>"

COPY --from=building-stage /WORK/wheels /wheels
