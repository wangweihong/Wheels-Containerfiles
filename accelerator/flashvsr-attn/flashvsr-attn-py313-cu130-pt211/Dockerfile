# Triton kernels are packaged as Python source; compilation happens on first use.
ARG REGISTRY=docker.io
FROM ${REGISTRY}/yanwk/comfyui-boot:base-cu130-pt211-cache AS building-stage
WORKDIR /WORK/flashvsr-attn
COPY src/ ./
ENV SOURCE_DATE_EPOCH=1792202410
RUN --network=none python3.13 -m pip wheel --no-deps --no-build-isolation \
    --wheel-dir /WORK/wheels .

FROM ${REGISTRY}/library/alpine:3.20 AS saving-stage
COPY --from=building-stage /WORK/wheels /wheels
