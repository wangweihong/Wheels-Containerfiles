################################################################################
# Dockerfile that builds 'yanwk/comfyui-extras:mmmcv-py313-cu130-pt211'.
# Used for compiling mmcv.
################################################################################

ARG REGISTRY=docker.io

FROM ${REGISTRY}/yanwk/comfyui-boot:base-cu130-pt211 AS building-stage

RUN set -eu \
    && mkdir -p /WORK/wheels

# Limit CPU/RAM usage during builds. Set to 1 to avoid crash on GitHub CI.
ARG MAX_JOBS=1
# 必须加，不然会报错：
# 1.020   File "/usr/local/lib64/python3.13/site-packages/torch/utils/cpp_extension.py", line 2600, in _get_cuda_arch_flags
# 1.020     arch_list[-1] += '+PTX'
# 1.020     ~~~~~~~~~^^^^
# 1.020 IndexError: list index out of range
ARG TORCH_CUDA_ARCH_LIST='8.0;8.6;10.0;12.0+PTX'
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG NO_PROXY
###################################################sou############################## Download repo and fix
RUN pip uninstall -y setuptools
RUN pip install "setuptools<82"        


ARG UPSTREAM_REPO="https://github.com/open-mmlab/mmcv"
ARG UPSTREAM_BRANCH="v2.1.0"
ARG UPSTREAM_COMMIT="57c4e25"
ARG CUDA_VERSION="cu130"
ARG TORCH_VERSION="pt211"
ARG VIRIANT="standard"
# docker build cache id, 避免缓存冲突
ARG CACHE_KEY="mmcv-py313-${CUDA_VERSION}-${TORCH_VERSION}-${VIRIANT}"

RUN echo "===> [MATRIX CHECK] Repo: ${UPSTREAM_REPO} | Branch: ${UPSTREAM_BRANCH} | COMMIT: ${UPSTREAM_COMMIT} | CUDA: ${CUDA_VERSION}"

RUN ${HTTPS_PROXY:+git config --global https.proxy $HTTPS_PROXY} && \
    ${HTTP_PROXY:+git config --global http.proxy $HTTP_PROXY} && \
    git clone --single-branch --branch ${UPSTREAM_BRANCH} --recurse-submodules\
    ${UPSTREAM_REPO} \
/WORK/mmcv

WORKDIR /WORK/mmcv
# 切换到 meta.yaml 指定的精准分支、Tag 或 Commit SHA
RUN git checkout ${UPSTREAM_COMMIT}


# 将约束文件复制进镜像， 禁止pip pip3.13 install -v --no-build-isolation -时将setuptools升级到82
# 82的steuptools这会报错:ModuleNotFoundError: No module named 'pkg_resources'
# 以上只能限制主线程
#
# 解决的方法：使用pyproject.toml
COPY constraints.txt /constraints.txt
COPY pyproject.toml /WORK/mmcv/

COPY setup.py .
RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=cache,id=${CACHE_KEY}-build,target=/WORK/mmcv/build \
    --mount=type=cache,id=${CACHE_KEY}-dist,target=/WORK/mmcv/dist \
    PIP_UPGRADE_STRATEGY=only-if-needed \
    pip3.13 install -v --no-build-isolation -e . -c /constraints.txt  \
    && pip3.13 wheel . -w /WORK/wheels -v --no-deps -c /constraints.txt 

RUN    set -eu \
    && BUILD_SHA=$(git rev-parse --short=7 HEAD) \
    && cd /WORK/wheels \
    && for f in *.whl; do \
         PREFIX=${f%%-py2.py3*} \
         && mv "$f" "${PREFIX}+git@${BUILD_SHA}-py313-${CUDA_VERSION}-${TORCH_VERSION}-linux_x86_64.whl"; \
       done

################################################################################
# Save the result
FROM ${REGISTRY}/library/alpine:latest AS saving-stage

LABEL maintainer="Wangweihong <wangweihong2018@qq.com>"

COPY --from=building-stage /WORK/wheels /wheels
