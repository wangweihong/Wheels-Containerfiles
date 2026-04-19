################################################################################
# Dockerfile that builds 'yanwk/comfyui-extras:xformers-py313-cu130-pt211'.
# Used for compiling XFormers.
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
################################################################################ 
# Download repo and fix
RUN  ${HTTPS_PROXY:+git config --global https.proxy $HTTPS_PROXY} && \
    ${HTTP_PROXY:+git config --global http.proxy $HTTP_PROXY} && \
    git clone --depth=1 --no-tags --recurse-submodules --shallow-submodules \
https://github.com/facebookresearch/xformers.git \
/WORK/xformers

WORKDIR /WORK/xformers


################################################################################
# XFormers

# TORCH_CUDA_ARCH_LIST can only contain architectures supported by both PyTorch and XFormers.
# Check before set:
# https://github.com/pytorch/pytorch/blob/v2.11.0/.ci/manywheel/build_cuda.sh
# https://github.com/thu-ml/SageAttention/blob/main/setup.py
# Or check in Python:
# python3.13 -c 'import torch; print(torch._C._cuda_getArchFlags())'

ARG TORCH_CUDA_ARCH_LIST='8.0;8.6;10.0;12.0+PTX'

WORKDIR /WORK/xformers

RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=cache,target=/WORK/xformers/build \
    --mount=type=cache,target=/WORK/xformers/dist \
    python3.13 setup.py bdist_wheel -d /WORK/wheels


################################################################################
# Save the result
FROM ${REGISTRY}/library/alpine:latest AS savingStage

LABEL maintainer="wangweihong <wangweihong2018@qq.com>"

COPY --from=buildingStage /WORK/wheels /wheels
