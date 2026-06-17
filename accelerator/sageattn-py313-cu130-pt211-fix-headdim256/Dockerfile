################################################################################
# Dockerfile that builds 'yanwk/comfyui-extras:sageattn-py313-cu130-pt211'.
# Used for compiling SageAttention.
################################################################################

ARG REGISTRY=docker.io

FROM ${REGISTRY}/yanwk/comfyui-boot:base-cu130-pt211-cache AS buildingStage

WORKDIR /WORK/wheels

# Limit CPU/RAM usage during builds. Set to 1 to avoid crash on GitHub CI.
ARG MAX_JOBS=2

ARG BUILD_BUNDLE_PTXAS=1

RUN pip install build "wheel<0.44" "packaging<24"

################################################################################
# Download repo and fix
RUN pip install pybind11
# 在这一行之后,通过参数修改CACHEBUST的值触发重建来决定是否缓存,避免缓存过期
ARG CACHEBUST=1

# RUN git clone --depth=1 --no-tags --recurse-submodules --shallow-submodules \
# https://github.com/thu-ml/SageAttention.git \
# /WORK/SageAttention


# 修复了ideogram4 headdim 256问题
# https://github.com/woct0rdho/SageAttention/issues/93
RUN git clone --depth=1 --no-tags --recurse-submodules --shallow-submodules -b head_dim_256 \
https://github.com/woct0rdho/SageAttention.git \
/WORK/SageAttention


WORKDIR /WORK/SageAttention/sageattention3_blackwell

# Fix for the dumb code asking for a freaking GPU
RUN sed -i \
'/cc_major, cc_minor = torch.cuda.get_device_capability()/,/raise RuntimeError("Unsupported GPU")/c\    cc_flag.append("-gencode")\n    cc_flag.append("arch=compute_100a,code=sm_100a")' \
setup.py

################################################################################
# SageAttention

# TORCH_CUDA_ARCH_LIST can only contain architectures supported by both PyTorch and SageAttention.
# Check before set:
# https://github.com/pytorch/pytorch/blob/v2.11.0/.ci/manywheel/build_cuda.sh
# https://github.com/thu-ml/SageAttention/blob/main/setup.py
# Or check in Python:
# python3.13 -c 'import torch; print(torch._C._cuda_getArchFlags())'

ARG TORCH_CUDA_ARCH_LIST='12.0;12.0+PTX'

WORKDIR /WORK/SageAttention

RUN python3.13 -m build --wheel --no-isolation --outdir /WORK/wheels .

################################################################################
# SageAttention 3 (Blackwell only)
# https://github.com/thu-ml/SageAttention/blob/main/sageattention3_blackwell/setup.py

ARG TORCH_CUDA_ARCH_LIST='12.0;12.0+PTX'

WORKDIR /WORK/SageAttention/sageattention3_blackwell

RUN python3.13 -m build --wheel --no-isolation  --verbose --outdir /WORK/wheels .

################################################################################
# Save the result
FROM ${REGISTRY}/library/alpine:latest AS savingStage

LABEL maintainer="Wangweihong <wangweihong2018@qq.com>"

COPY --from=buildingStage /WORK/wheels /wheels
