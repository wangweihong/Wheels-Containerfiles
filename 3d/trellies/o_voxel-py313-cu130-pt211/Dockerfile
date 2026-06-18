################################################################################
# Dockerfile that builds 'yanwk/comfyui-extras:o_voxel-py313-cu130-pt211'.
# Used for compiling o_voxel.
################################################################################

ARG REGISTRY=docker.io

FROM ${REGISTRY}/yanwk/comfyui-boot:base-cu130-pt211 AS buildingStage

RUN set -eu \
    && mkdir -p /WORK/wheels

# Limit CPU/RAM usage during builds. Set to 1 to avoid crash on GitHub CI.
ARG MAX_JOBS=1
# 必须加，不然会报错：
# 1.020   File "/usr/local/lib64/python3.13/site-packages/torch/utils/cpp_extension.py", line 2600, in _get_cuda_arch_flags
# 1.020     arch_list[-1] += '+PTX'
# 1.020     ~~~~~~~~~^^^^
# 1.020 IndexError: list index out of range
ARG TORCH_CUDA_ARCH_LIST='8.0;8.6;10.0'
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG NO_PROXY

###################################################sou#############################
ARG UPSTREAM_REPO="https://github.com/visualbruno/TRELLIS.2"
ARG UPSTREAM_BRANCH="main"
ARG UPSTREAM_COMMIT="65d1e13"
ARG CUDA_VERSION="cu130"
ARG TORCH_VERSION="pt211"
ARG VIRIANT="standard"
# docker build cache id, 避免缓存冲突
ARG CACHE_KEY="o_voxel-py313-${CUDA_VERSION}-${TORCH_VERSION}-${VIRIANT}"

# Download repo and fix
RUN ${HTTPS_PROXY:+git config --global https.proxy $HTTPS_PROXY} && \
    ${HTTP_PROXY:+git config --global http.proxy $HTTP_PROXY} && \
     git clone --single-branch --branch ${UPSTREAM_BRANCH} --recurse-submodules\
    ${UPSTREAM_REPO} \
/WORK/TRELLIS.2

WORKDIR /WORK/TRELLIS.2
# 切换到 meta.yaml 指定的精准分支、Tag 或 Commit SHA
RUN git checkout ${UPSTREAM_COMMIT}

WORKDIR /WORK/TRELLIS.2/o-voxel

    
RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=cache,id=${CACHE_KEY}-build,target=/WORK/TRELLIS.2/o-voxel/build \
    --mount=type=cache,id=${CACHE_KEY}-dist,target=/WORK/TRELLIS.2/o-voxel/dist \
    python3.13 setup.py bdist_wheel -d /WORK/wheels 

RUN set -eu \
    && BUILD_SHA=$(git rev-parse --short=7 HEAD) \
    && cd /WORK/wheels \
    && for f in *.whl; do \
         PREFIX=${f%%-cp313*} \
         && mv "$f" "${PREFIX}-${VIRIANT}+git.${UPSTREAM_BRANCH}.${BUILD_SHA}-py313-${CUDA_VERSION}-${TORCH_VERSION}-linux_x86_64.whl"; \
       done


################################################################################
# Save the result
FROM ${REGISTRY}/library/alpine:latest AS savingStage

LABEL maintainer="Wangweihong <wangweihong2018@qq.com>"

COPY --from=buildingStage /WORK/wheels /wheels
