# 3DGS官方依赖发行材料

不编译源码。按artifacts.lock.json下载、校验并发布官方PyCOLMAP wheel、Brush归档、通用Vulkan Loader RPM，以及SHA256SUMS和SOURCE_MANIFEST.json。

```bash
make prepare-3dgs
make verify-3dgs
make release-3dgs THREE_DGS_RELEASE_TARGET=<包含本发行配方的已发布提交SHA>
```

本地材料默认进入被Git忽略的`_artifacts/3dgs-v1`。已有文件摘要不匹配立即失败，不覆盖；可通过`THREE_DGS_OUTPUT`指定目录。发布先建立草稿并回读校验，再公开；已公开资产不覆盖，不允许向不完整的公开版本追加材料，应发布新版本。专用手动Actions执行相同流程，现有wheel矩阵流程不变。

Release：`https://github.com/wangweihong/Wheels-Containerfiles/releases/tag/3dgs-v1`。

ComfyUI节点和示例由ComfyUI-ToolBox维护；ComfyUI-Custom从本Release安装运行依赖。首次只验证Linux amd64、Python3.13及Rocky Linux10镜像组合。材料中的许可证随上游原始文件保留，不包含任何宿主机设备驱动或H3权重。
