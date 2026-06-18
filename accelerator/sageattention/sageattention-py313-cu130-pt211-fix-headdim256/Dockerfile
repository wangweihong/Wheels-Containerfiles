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
RUN pip install pybind11

ARG UPSTREAM_REPO="https://github.com/woct0rdho/SageAttention"
ARG UPSTREAM_BRANCH="head_dim_256"
ARG UPSTREAM_COMMIT="5bcf8c3"
ARG CUDA_VERSION="cu130"
ARG TORCH_VERSION="pt211"
ARG VIRIANT="fix-headdim256"
# docker build cache id, 避免缓存冲突
ARG CACHE_KEY="sageattn-py313-${CUDA_VERSION}-${TORCH_VERSION}-${VIRIANT}"

RUN echo "===> [MATRIX CHECK] Repo: ${UPSTREAM_REPO} | Branch: ${UPSTREAM_BRANCH} | COMMIT: ${UPSTREAM_COMMIT} | CUDA: ${CUDA_VERSION}"
# 修复了ideogram4 headdim 256问题
# https://github.com/woct0rdho/SageAttention/issues/93
RUN ${HTTPS_PROXY:+git config --global https.proxy $HTTPS_PROXY} && \
    ${HTTP_PROXY:+git config --global http.proxy $HTTP_PROXY} && \
    git clone --single-branch --branch ${UPSTREAM_BRANCH} --recurse-submodules\
    ${UPSTREAM_REPO} \
/WORK/SageAttention-head_dim_256

WORKDIR /WORK/SageAttention-head_dim_256
# 切换到 meta.yaml 指定的精准分支、Tag 或 Commit SHA
RUN git checkout ${UPSTREAM_COMMIT}

################################################################################
WORKDIR /WORK/SageAttention-head_dim_256

RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=cache,target=/WORK/SageAttention-head_dim_256/build \
    --mount=type=cache,target=/WORK/SageAttention-head_dim_256/dist \
    python3.13 -m build --wheel --no-isolation  --verbose --outdir /WORK/wheels . 

RUN set -eu \
    && BUILD_SHA=$(git rev-parse --short=7 HEAD) \
    && cd /WORK/wheels \
    && for f in *.whl; do \
         PREFIX=${f%%-cp313-*} \
         && mv "$f" "${PREFIX}+git@${BUILD_SHA}-py313-${CUDA_VERSION}-${TORCH_VERSION}-linux_x86_64.whl"; \
       done

################################################################################
# Save the result
FROM ${REGISTRY}/library/alpine:latest AS saving-stage

LABEL maintainer="Wangweihong <wangweihong2018@qq.com>"

COPY --from=building-stage /WORK/wheels /wheels
