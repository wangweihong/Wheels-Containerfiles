# FlashVSR Triton wheel

源码来自 [smthemex/ComfyUI_FlashVSR](https://github.com/smthemex/ComfyUI_FlashVSR/tree/153cf03343a116c85aee40d291125921cc33935a/operators/flashvsr_attn)，
固定提交 `153cf03343a116c85aee40d291125921cc33935a` 的 `operators/flashvsr_attn`。
`flashvsr-attn-py313-cu130-pt211/src` 保存未经修改的 Python 包、打包配置和 README，
另附上游仓库的 Apache-2.0 LICENSE。不包含模型或 ComfyUI 节点代码。

该算子为纯 Python / Triton 源码，产物为 `flashvsr_attn-0.1.0-py3-none-any.whl`。
运行时要求 PyTorch >=2.2、Triton >=3.0，首次执行时 JIT 编译；wheel 不捆绑 CUDA 二进制。
本矩阵目标使用 Python 3.13 / CUDA 13.0 / PyTorch 2.11 环境打包，打包阶段无需 GPU、网络或下载依赖。

```bash
make build-m-flashvsr-attn@py313-cu130-pt211
make collect-m-flashvsr-attn@py313-cu130-pt211
make release-m-flashvsr-attn@py313-cu130-pt211
```

发布到本仓库的 `flashvsr-attn` Release，供 ComfyUI-Custom 的 Dockerfile 直接下载。
发布时附带 SHA256SUMS。修改源码版本后应使用新的 wheel 版本，保留已发布文件。
