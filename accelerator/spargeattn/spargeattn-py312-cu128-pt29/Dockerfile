################################################################################
# Dockerfile that builds 'yanwk/comfyui-extras:sageattn-py312-cu128-pt28'.
# Used for compiling SageAttention.
################################################################################

FROM docker.io/yanwk/comfyui-boot:cu128-megapak-pt29 AS building-stage

RUN set -eu \
    && mkdir -p /WORK/wheels

# Limit CPU/RAM usage during builds. Set to 1 to avoid crash on GitHub CI.
ARG MAX_JOBS=1
ARG TORCH_CUDA_ARCH_LIST='8.0;8.6;10.0;12.0+PTX;12.0'
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG NO_PROXY
ARG BUILD_BUNDLE_PTXAS=1

################################################################################
ARG UPSTREAM_REPO="https://github.com/thu-ml/SpargeAttn"
ARG UPSTREAM_BRANCH="main"
ARG UPSTREAM_COMMIT="d1a57a5"
ARG CUDA_VERSION="cu128"
ARG TORCH_VERSION="pt29"
ARG VIRIANT="standard"
# docker build cache id, 避免缓存冲突
ARG CACHE_KEY="spargeattn-py312-${CUDA_VERSION}-${TORCH_VERSION}-${VIRIANT}"    

RUN echo "===> [MATRIX CHECK] Repo: ${UPSTREAM_REPO} | Branch: ${UPSTREAM_BRANCH} | COMMIT: ${UPSTREAM_COMMIT} | CUDA: ${CUDA_VERSION}"
################################################################################

RUN ${HTTPS_PROXY:+git config --global https.proxy $HTTPS_PROXY} && \
    ${HTTP_PROXY:+git config --global http.proxy $HTTP_PROXY} && \
    git clone --single-branch --branch ${UPSTREAM_BRANCH} --recurse-submodules\
    ${UPSTREAM_REPO} \
/WORK/SpargeAttn

WORKDIR /WORK/SpargeAttn

# 切换到 meta.yaml 指定的精准分支、Tag 或 Commit SHA
RUN git checkout ${UPSTREAM_COMMIT}

WORKDIR /WORK/SpargeAttn
# Fix for the dumb code incompatible with GCC 14
RUN sed -i \
'/"-include,cassert",/d' \
setup.py

# Fix for dumb autogen.py
RUN alternatives --install /usr/bin/python python /usr/bin/python3.13 100
RUN alternatives --install /usr/bin/python3 python3 /usr/bin/python3.13 100

RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=cache,id=${CACHE_KEY}-build,target=/WORK/SpargeAttn/build \
    --mount=type=cache,id=${CACHE_KEY}-dist,target=/WORK/SpargeAttn/dist \
    python3 setup.py bdist_wheel -d /WORK/wheels

RUN set -eu \
    && BUILD_SHA=$(git rev-parse --short=7 HEAD) \
    && cd /WORK/wheels \
    && for f in *.whl; do \
         PREFIX=${f%%-cp312*} \
         && mv "$f" "${PREFIX}+git@${BUILD_SHA}-py312-${CUDA_VERSION}-${TORCH_VERSION}-linux_x86_64.whl"; \
       done

################################################################################
# Save the result
FROM docker.io/library/alpine:latest AS saving-stage

LABEL maintainer="Wangweihong <wangweihong2018@qq.com>"

COPY --from=building-stage /WORK/wheels /wheels
