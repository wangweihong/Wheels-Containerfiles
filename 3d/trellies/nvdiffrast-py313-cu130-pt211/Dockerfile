################################################################################
# Dockerfile that builds 'yanwk/comfyui-extras:nviffrast-py313-cu130-pt211'.
# Used for compiling NVdiffrast.
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
# 必须加，不然会报错：
# 1.020   File "/usr/local/lib64/python3.13/site-packages/torch/utils/cpp_extension.py", line 2600, in _get_cuda_arch_flags
# 1.020     arch_list[-1] += '+PTX'
# 1.020     ~~~~~~~~~^^^^
# 1.020 IndexError: list index out of range
ARG TORCH_CUDA_ARCH_LIST='8.0;8.6;10.0'
################################################################################
# Download repo and fix
## -depth=1 仅下载最新版本
## --single-branch 仅下载指定分支
RUN git clone -b v0.4.0 --single-branch --depth=1 https://github.com/NVlabs/nvdiffrast.git  \
/WORK/nvdiffrast

WORKDIR /WORK/nvdiffrast


RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=cache,target=/WORK/nvdiffrast/build \
    --mount=type=cache,target=/WORK/nvdiffrast/dist \
    python3.13 setup.py bdist_wheel -d /WORK/wheels


################################################################################
# Save the result
FROM ${REGISTRY}/library/alpine:latest AS savingStage

LABEL maintainer="Wangweihong <wangweihong2018@qq.com>"

COPY --from=buildingStage /WORK/wheels /wheels
