################################################################################
# Dockerfile that builds 'yanwk/comfyui-extras:audiotools-py313-cu130-pt211'.
# Used for compiling AudioTools.py.
################################################################################

ARG REGISTRY=docker.io


FROM ${REGISTRY}/yanwk/comfyui-boot:base-cu130-pt211 AS buildingStage

RUN set -eu \
    && mkdir -p /WORK/wheels

# Limit CPU/RAM usage during builds. Set to 1 to avoid crash on GitHub CI.
ARG MAX_JOBS=1
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG NO_PROXY
ARG TORCH_CUDA_ARCH_LIST='8.0;8.6;10.0;12.0+PTX'
################################################################################ 
ARG UPSTREAM_REPO="https://github.com/descriptinc/audiotools"
ARG UPSTREAM_BRANCH="master"
ARG UPSTREAM_COMMIT="348ebf2"
ARG CUDA_VERSION="cu130"
ARG TORCH_VERSION="pt211"
ARG VIRIANT="standard"
# docker build cache id, 避免缓存冲突
ARG CACHE_KEY="audiotools-py313-${CUDA_VERSION}-${TORCH_VERSION}-${VIRIANT}"

# Download repo and fix
RUN  ${HTTPS_PROXY:+git config --global https.proxy $HTTPS_PROXY} && \
    ${HTTP_PROXY:+git config --global http.proxy $HTTP_PROXY} && \
    git clone --single-branch --branch ${UPSTREAM_BRANCH} --recurse-submodules\
    ${UPSTREAM_REPO} \
/WORK/audiotools

WORKDIR /WORK/audiotools
# 切换到 meta.yaml 指定的精准分支、Tag 或 Commit SHA
RUN git checkout ${UPSTREAM_COMMIT}

################################################################################
# AudioTools.py

# TORCH_CUDA_ARCH_LIST can only contain architectures supported by both PyTorch and AudioTools.py.
# Check before set:
# https://github.com/pytorch/pytorch/blob/v2.11.0/.ci/manywheel/build_cuda.sh
# https://github.com/thu-ml/SageAttention/blob/main/setup.py
# Or check in Python:
# python3.13 -c 'import torch; print(torch._C._cuda_getArchFlags())'


RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=cache,id=${CACHE_KEY}-build,target=/WORK/audiotools/build \
    --mount=type=cache,id=${CACHE_KEY}-dist,target=/WORK/audiotools/dist \
    python3.13 setup.py bdist_wheel -d /WORK/wheels 

RUN set -eu \
    && BUILD_SHA=$(git rev-parse --short=7 HEAD) \
    && cd /WORK/wheels \
    && for f in *.whl; do \
         PREFIX=${f%%-py2.py3*} \
         && mv "$f" "${PREFIX}-${VIRIANT}+git.${UPSTREAM_BRANCH}.${BUILD_SHA}-py313-${CUDA_VERSION}-${TORCH_VERSION}-linux_x86_64.whl"; \
       done


################################################################################
# Save the result
FROM ${REGISTRY}/library/alpine:latest AS savingStage

LABEL maintainer="wangweihong <wangweihong2018@qq.com>"

COPY --from=buildingStage /WORK/wheels /wheels
