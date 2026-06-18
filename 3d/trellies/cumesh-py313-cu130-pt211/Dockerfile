################################################################################
# Dockerfile that builds 'yanwk/comfyui-extras:cumesh-py313-cu130-pt211'.
# Used for compiling CumMesh.
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
ARG TORCH_CUDA_ARCH_LIST='8.0;8.6;10.0;12.0;'
################################################################################
# ==============================================================================
# 新增：从 meta.yaml 映射进来的构建参数（提供默认值以防手动构建时报错）
# ==============================================================================
ARG UPSTREAM_REPO="https://github.com/visualbruno/CuMesh"
ARG UPSTREAM_BRANCH="main"
ARG UPSTREAM_COMMIT="d10e54c"
ARG CUDA_VERSION="cu130"
ARG TORCH_VERSION="pt211"
ARG VIRIANT="standard"
# docker build cache id, 避免缓存冲突
ARG CACHE_KEY="cumesh-py313-${CUDA_VERSION}-${TORCH_VERSION}-${VIRIANT}"

RUN ${HTTPS_PROXY:+git config --global https.proxy $HTTPS_PROXY} && \ 
    ${HTTP_PROXY:+git config --global http.proxy $HTTP_PROXY} && \
    git clone --single-branch --branch ${UPSTREAM_BRANCH} --recurse-submodules\
    ${UPSTREAM_REPO} \
/WORK/CuMesh

WORKDIR /WORK/CuMesh

# 切换到 meta.yaml 指定的精准分支、Tag 或 Commit SHA
RUN git checkout ${UPSTREAM_COMMIT}

# https://github.com/visualbruno/CuMesh/issues/1
RUN cd third_party/cubvh \
    && mkdir third_party \
    && cd third_party \
    && ln -s ../../../ eigen

RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=cache,id=${CACHE_KEY}-build,target=/WORK/CuMesh/build \
    --mount=type=cache,id=${CACHE_KEY}-dist,target=/WORK/CuMesh/dist \
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
