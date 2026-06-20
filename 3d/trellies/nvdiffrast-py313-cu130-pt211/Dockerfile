################################################################################
# Dockerfile that builds 'yanwk/comfyui-extras:nviffrast-py313-cu130-pt211'.
# Used for compiling NVdiffrast.
################################################################################

ARG REGISTRY=docker.io

FROM ${REGISTRY}/yanwk/comfyui-boot:base-cu130-pt211 AS building-stage

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
ARG TORCH_CUDA_ARCH_LIST='8.0;8.6;10.0;12.0+PTX'
################################################################################
# ==============================================================================
# 新增：从 meta.yaml 映射进来的构建参数（提供默认值以防手动构建时报错）
# ==============================================================================
ARG UPSTREAM_REPO="https://github.com/NVlabs/nvdiffrast.git"
ARG UPSTREAM_BRANCH="v0.4.0"
ARG UPSTREAM_COMMIT="253ac4f"
ARG CUDA_VERSION="cu130"
ARG TORCH_VERSION="pt211"
ARG VIRIANT="standard"
# docker build cache id, 避免缓存冲突
ARG CACHE_KEY="nvdiffrast-py313-${CUDA_VERSION}-${TORCH_VERSION}-${VIRIANT}"

RUN echo "===> [MATRIX CHECK] Repo: ${UPSTREAM_REPO} | Branch: ${UPSTREAM_BRANCH} | COMMIT: ${UPSTREAM_COMMIT} | CUDA: ${CUDA_VERSION}"

# Download repo and fix
## -depth=1 仅下载最新版本
## --single-branch 仅下载指定分支
RUN ${HTTPS_PROXY:+git config --global https.proxy $HTTPS_PROXY} && \
    ${HTTP_PROXY:+git config --global http.proxy $HTTP_PROXY} && \
     git clone --single-branch --branch ${UPSTREAM_BRANCH} --recurse-submodules\
    ${UPSTREAM_REPO} \
/WORK/nvdiffrast

WORKDIR /WORK/nvdiffrast

# 切换到 meta.yaml 指定的精准分支、Tag 或 Commit SHA
RUN git checkout ${UPSTREAM_COMMIT}

RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=cache,id=${CACHE_KEY}-build,target=/WORK/nvdiffrast/build \
    --mount=type=cache,id=${CACHE_KEY}-dist,target=/WORK/nvdiffrast/dist \
    python3.13 setup.py bdist_wheel -d /WORK/wheels 

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
