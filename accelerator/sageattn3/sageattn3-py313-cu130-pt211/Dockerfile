################################################################################
# Dockerfile that builds 'yanwk/comfyui-extras:sageattn-py312-cu128-pt28'.
# Used for compiling SageAttention.
################################################################################

FROM docker.io/yanwk/comfyui-boot:cu130-megapak-pt211 AS building-stage

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
ARG UPSTREAM_REPO="https://github.com/thu-ml/SageAttention"
ARG UPSTREAM_BRANCH="main"
ARG UPSTREAM_COMMIT="d1a57a5"
ARG CUDA_VERSION="cu130"
ARG TORCH_VERSION="pt211"
ARG PYTHON_VERSION="cp313"
ARG VIRIANT="standard"
# docker build cache id, 避免缓存冲突
ARG CACHE_KEY="sageattn3-${PYTHON_VERSION}-${CUDA_VERSION}-${TORCH_VERSION}-${VIRIANT}"

RUN echo "===> [MATRIX CHECK] Repo: ${UPSTREAM_REPO} | Branch: ${UPSTREAM_BRANCH} | COMMIT: ${UPSTREAM_COMMIT} | CUDA: ${CUDA_VERSION}"
################################################################################

RUN ${HTTPS_PROXY:+git config --global https.proxy $HTTPS_PROXY} && \
    ${HTTP_PROXY:+git config --global http.proxy $HTTP_PROXY} && \
    git clone --single-branch --branch ${UPSTREAM_BRANCH} --recurse-submodules\
    ${UPSTREAM_REPO} \
/WORK/SageAttention

WORKDIR /WORK/SageAttention
# 切换到 meta.yaml 指定的精准分支、Tag 或 Commit SHA
RUN git checkout ${UPSTREAM_COMMIT}


WORKDIR /WORK/SageAttention/sageattention3_blackwell

# Fix for the dumb code asking for a freaking GPU
RUN sed -i \
'/cc_major, cc_minor = torch.cuda.get_device_capability()/,/raise RuntimeError("Unsupported GPU")/c\    cc_flag.append("-gencode")\n    cc_flag.append("arch=compute_100a,code=sm_100a")' \
setup.py


WORKDIR /WORK/SageAttention/sageattention3_blackwell

RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=cache,id=${CACHE_KEY}-build,target=/WORK/SageAttention/sageattention3_blackwell/build \
    --mount=type=cache,id=${CACHE_KEY}-dist,target=/WORK/SageAttention/sageattention3_blackwell/dist \
    python3.12 -m build --wheel --no-isolation --outdir /WORK/wheels .

RUN set -eu \
    && BUILD_SHA=$(git rev-parse --short=7 HEAD) \
    && cd /WORK/wheels \
    && for f in *.whl; do \
         PREFIX=${f%%-cp313*} \
         && mv "$f" "${PREFIX}+git.${BUILD_SHA}.${CUDA_VERSION}.${TORCH_VERSION}-${PYTHON_VERSION}-${PYTHON_VERSION}-linux_x86_64.whl"; \
       done
################################################################################
# Save the result
FROM docker.io/library/alpine:latest AS saving-stage

LABEL maintainer="Wangweihong <wangweihong2018@qq.com>"

COPY --from=building-stage /WORK/wheels /wheels
