################################################################################
# Dockerfile that builds 'yanwk/comfyui-extras:mmmcv-py313-cu130-pt211'.
# Used for compiling mmcv.
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
ARG TORCH_CUDA_ARCH_LIST='8.0;8.6;10.0;12.0+PTX'
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG NO_PROXY

###################################################sou#############################
# Download repo and fix
RUN git clone -b v2.1.0 --depth=1 --no-tags --recurse-submodules --shallow-submodules \
https://github.com/open-mmlab/mmcv.git \
/WORK/mmcv

RUN pip uninstall -y setuptools
RUN pip install "setuptools<82"        

WORKDIR /WORK/mmcv

# 将约束文件复制进镜像， 禁止pip pip3.13 install -v --no-build-isolation -时将setuptools升级到82
# 82的steuptools这会报错:ModuleNotFoundError: No module named 'pkg_resources'
# 以上只能限制主线程
#
# 解决的方法：使用pyproject.toml
COPY constraints.txt /constraints.txt
COPY pyproject.toml /WORK/mmcv/

COPY setup.py .
RUN --mount=type=cache,target=/root/.cache/pip \
    PIP_UPGRADE_STRATEGY=only-if-needed \
    pip3.13 install -v --no-build-isolation -e . -c /constraints.txt && \
    pip3.13 wheel . -w /WORK/wheels -v --no-deps -c /constraints.txt


################################################################################
# Save the result
FROM ${REGISTRY}/library/alpine:latest AS savingStage

LABEL maintainer="Wangweihong <wangweihong2018@qq.com>"

COPY --from=buildingStage /WORK/wheels /wheels
