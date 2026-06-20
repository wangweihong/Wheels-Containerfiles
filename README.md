# ComfyUI 容器构建系统

## 项目概述

本项目提供了一个**矩阵构建系统**，用于构建ComfyUI扩展组件的Docker镜像。支持多种CUDA加速的Python扩展组件在不同环境下的构建。

## 矩阵构建系统

矩阵由 **组件 × 环境** 笛卡尔积构成。所有组合目标名使用 `@` 作为分隔符，例如 `cumesh@py313-cu130-pt211`。

### 支持的组件

| 组件名称 | 根目录 | 说明 |
|---------|--------|------|
| cumesh | `3d/trellies/` | Trellis 相关 |
| flexGEMM | `3d/trellies/` | Trellis 相关 |
| o_voxel | `3d/trellies/` | Trellis 相关 |
| nvdiffrec | `3d/trellies/` | 3D 重建 |
| nvdiffrast | `3d/trellies/` | 3D 渲染 |
| pytorch3d | `3d/lito/` | PyTorch3D |
| sageattention | `accelerator/sageattention/` | SageAttention 2.x |
| sageattn3 | `accelerator/sageattn3/` | SageAttention 3.x |
| spargeattn | `accelerator/spargeattn/` | SpargeAttn |
| xformers | `accelerator/xformers/` | xFormers |
| fastvideo-kernel | `fastvideo/` | FastVideo 算子 |
| audiotools | `tts/` | Descript AudioTools |
| mmcv | `sdpose/` | MMCV |

### 组件总览（上游仓库与功能描述）

| 组件 | 上游仓库 | 功能描述 |
|------|---------|----------|
| cumesh | [visualbruno/CuMesh](https://github.com/visualbruno/CuMesh) | 基于 CUDA 的高性能网格处理库，为 TRELLIS 3D 生成提供网格算子支持 |
| flexGEMM | [visualbruno/FlexGEMM](https://github.com/visualbruno/FlexGEMM) | 灵活的 CUDA 通用矩阵乘法(GEMM)库，为 TRELLIS 3D 生成提供算子支持 |
| o_voxel | [visualbruno/TRELLIS.2](https://github.com/visualbruno/TRELLIS.2) | 基于结构化 3D 隐空间的高保真 3D 资产生成模型，可从单张图片生成高质量 3D 资产 |
| nvdiffrec | [JeffreyXiang/nvdiffrec](https://github.com/JeffreyXiang/nvdiffrec) | 从图像集合中高效恢复 3D 几何与材质的可微渲染库 |
| nvdiffrast | [NVlabs/nvdiffrast](https://github.com/NVlabs/nvdiffrast) | 模块化可微渲染原语库，提供高质量光栅化与可微渲染 |
| pytorch3d | [facebookresearch/pytorch3d](https://github.com/facebookresearch/pytorch3d) | FAIR 推出的基于 PyTorch 的 3D 计算机视觉深度学习组件库，提供 3D 数据结构、渲染与可微算子 |
| sageattention | [thu-ml/SageAttention](https://github.com/thu-ml/SageAttention) | 即插即用的高效精确注意力算子，通过 8-bit/4-bit 量化实现接近无损的推理加速 |
| sageattn3 | [thu-ml/SageAttention](https://github.com/thu-ml/SageAttention) | 即插即用的高效精确注意力算子，通过 8-bit/4-bit 量化实现接近无损的推理加速 |
| spargeattn | [thu-ml/SpargeAttn](https://github.com/thu-ml/SpargeAttn) | 无需训练的稀疏注意力算子，通过两阶段在线过滤器与 8-bit 量化加速任意模型推理，几乎不损失精度 |
| fastvideo-kernel | [hao-ai-lab/FastVideo](https://github.com/hao-ai-lab/FastVideo) | 用于加速视频扩散模型推理与后训练的统一框架 |
| audiotools | [descriptinc/audiotools](https://github.com/descriptinc/audiotools) | 面向音频信号处理的全方位工具库，提供可微分的音频变换、特征提取与数据增强 |
| mmcv | [open-mmlab/mmcv](https://github.com/open-mmlab/mmcv) | OpenMMLab 系列计算机视觉项目的基础库，提供自定义 CUDA 算子、配置系统与通用工具 |

> 注：`sageattention` 的 `fix-headdim256` 变体使用 fork 仓库 [woct0rdho/SageAttention](https://github.com/woct0rdho/SageAttention)，用于修复 head_dim=256 不被支持的问题。

### 支持的环境

- **py313-cu130-pt211** - Python 3.13 + CUDA 13.0 + PyTorch 2.11
- **py312-cu128-pt29** - Python 3.12 + CUDA 12.8 + PyTorch 2.9
- **py312-cu128-pt28** - Python 3.12 + CUDA 12.8 + PyTorch 2.8
- **py313-cu130-pt211-r2** - py313-cu130-pt211 的 r2 变体
- **py313-cu130-pt211-fix-headdim256** - py313-cu130-pt211 的 fix-headdim256 变体


## Makefile 使用指南

### 主要功能

- **矩阵构建**：支持所有组件×环境的组合构建
- **双标签构建**：每个镜像生成基础标签和时间戳标签
- **批量操作**：支持按组件批量构建、采集、发布
- **代理支持**：自动检测并使用系统代理设置
- **Wheel 采集**：从构建好的镜像中提取 wheel 文件
- **一键发布**：将采集的 wheel 上传到 GitHub Release，并自动维护变更说明表格
- **元数据驱动**：通过 `meta.yaml` 跟踪上游仓库、分支、提交与变体信息（依赖 `yq`）
- **智能清理**：自动清理构建的镜像

### 命令示例

#### 基本命令

```bash
# 查看帮助信息
make help

# 检查 yq 依赖（构建前会自动调用）
make check-yq-dependency
```

#### 构建命令

```bash
# 构建所有组件-环境组合
make build-all

# 构建特定组件的所有环境
make build-comp-cumesh

# 构建特定组件-环境组合
make build-m-cumesh@py313-cu130-pt211

# 构建带变体的组件-环境组合
make build-m-sageattention@py313-cu130-pt211-fix-headdim256
```

#### 推送命令

```bash
# 推送所有构建的镜像
make push-all

# 推送特定组件-环境组合
make push-m-cumesh@py313-cu130-pt211
```

#### 从已构建好的组件镜像提取 Wheels

```bash
# 从所有镜像中采集 wheel 文件
make collect-all

# 从特定组件的所有环境中采集 wheel 文件
make collect-comp-cumesh

# 从特定组件-环境组合中采集 wheel 文件
make collect-m-cumesh@py313-cu130-pt211

# 清理已采集的 wheel 文件
make collect-clean
```

#### 发布命令

将采集到的 wheel 上传到 GitHub Release，并自动维护变更说明表格（以组件名作为 Release Tag，支持多环境、多变体追加）。

```bash
# 发布所有组件
make release-all

# 发布特定组件的所有环境
make release-comp-cumesh

# 发布特定组件-环境组合
make release-m-cumesh@py313-cu130-pt211
```

#### 清理命令

```bash
# 清理所有构建的镜像
make clean-all

# 清理特定组件-环境组合的镜像
make clean-m-cumesh@py313-cu130-pt211
```

### 自定义构建参数

可以通过环境变量自定义构建参数：

```bash
# 设置并行作业数（默认为 1）
export MAX_JOBS=4

# 设置 CUDA 架构支持（默认为 8.0;8.6;10.0;12.0;12.0+PTX）
export TORCH_CUDA_ARCH_LIST='8.0;8.6;10.0;12.0;12.0+PTX'

# 使用私有注册表（默认为 docker.io）
export REGISTRY=myregistry.example.com

# 构建所有组件
make build-all
```

默认镜像名为 `yanwk/comfyui-extras`，wheel 输出目录为 `./_wheels/linux`。

### 代理支持

在需要代理的环境下，系统会自动检测并使用以下环境变量：
- `http_proxy` / `HTTP_PROXY`
- `https_proxy` / `HTTPS_PROXY`
- `no_proxy` / `NO_PROXY`

### 元数据与 yq 依赖

每个组件-环境目录可包含一个 `meta.yaml`，用于跟踪上游仓库、分支、提交、变体与说明。构建与发布时会通过 `yq` 解析该文件，将上游信息注入为 Docker 构建参数，并写入 Release 变更说明表格。

```yaml
module: "sageattention"
variant: "standard"   # 变体，如 standard / r2 / fix-headdim256
upstream:
  repo: "https://github.com/thu-ml/SageAttention"
  description: "即插即用的高效精确注意力算子，通过 8-bit/4-bit 量化实现接近无损的推理加速"
  branch: "main"
  commit: "d1a57a5"
env:
  python: "3.13"
  cuda: "13.0"
  pytorch: "2.11"
```

若未安装 `yq`，构建前会报错退出。安装方式：

```bash
# Linux (AMD64)
sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq && sudo chmod +x /usr/bin/yq
# macOS
brew install yq
```

### 组件目录结构

每个组件-环境组合对应一个独立目录，命名格式为 `<组件>-<环境>`，目录内包含 `Dockerfile` 与可选的 `meta.yaml`。

| 组件名称 | 目录路径 |
|---------|----------|
| cumesh / flexGEMM / o_voxel / nvdiffrec / nvdiffrast | `3d/trellies/<组件>-<环境>` |
| pytorch3d | `3d/lito/pytorch3d-<环境>` |
| sageattention | `accelerator/sageattention/sageattention-<环境>` |
| sageattn3 | `accelerator/sageattn3/sageattn3-<环境>` |
| spargeattn | `accelerator/spargeattn/spargeattn-<环境>` |
| xformers | `accelerator/xformers/xformers-<环境>` |
| fastvideo-kernel | `fastvideo/fastvideo-kernel-<环境>` |
| audiotools | `tts/audiotools-<环境>` |
| mmcv | `sdpose/mmcv-<环境>` |

### 镜像标签策略

每个组件-环境组合构建时会生成两个镜像标签：

1. **基础标签**：如 `cumesh-py313-cu130-pt211`
2. **时间戳标签**：如 `cumesh-py313-cu130-pt211-20260412`

这种策略便于版本管理和回滚操作。

## 开发说明

### 添加新组件

要添加新的组件支持，需要：

1. 在 `ALL_COMPONENTS` 变量中添加组件名称
2. 在 `get_comp_root` 函数中添加组件的根目录映射
3. 创建对应的目录结构（`<根目录>/<组件>-<环境>/`）和 `Dockerfile`
4. （可选）添加 `meta.yaml` 以支持上游元数据注入与发布

### 添加新环境

要添加新的环境支持，需要：

1. 在 `ALL_ENVS` 变量中添加环境名称
2. 创建对应组件的环境目录和 `Dockerfile`

### 构建参数说明

- `MAX_JOBS`：控制并行编译作业数，设置为 1 可避免在资源受限环境（如 GitHub CI）中崩溃
- `TORCH_CUDA_ARCH_LIST`：指定支持的 CUDA 计算架构，必须设置以避免 PyTorch 编译错误
- `REGISTRY`：镜像仓库地址（默认为 `docker.io`）
- `IMAGE_NAME`：镜像名称（默认为 `yanwk/comfyui-extras`）
- `WHEELS_HOST_DIR`：wheel 文件的输出目录（默认为 `./_wheels/linux`）

## 故障排除

### 常见问题

1. **构建失败**：检查网络连接和代理设置
2. **内存不足**：降低 `MAX_JOBS` 值
3. **CUDA架构错误**：确保 `TORCH_CUDA_ARCH_LIST` 包含正确的架构
4. **目录不存在**：检查组件-环境组合的目录是否存在

### 调试技巧

```bash
# 查看详细的构建日志
make build-m-cumesh@py313-cu130-pt211 2>&1 | tee build.log

# 检查Docker镜像
docker images | grep comfyui-extras

# 测试构建的镜像
docker run --rm yanwk/comfyui-extras:cumesh-py313-cu130-pt211 ls -la /wheels

# 查看wheel文件
ls -la wheels/linux/
```

## 示例工作流

### 构建并采集所有wheel文件

```bash
# 构建所有组件-环境组合
make build-all

# 采集所有wheel文件
make collect-all

# 查看采集的wheel文件
ls -la wheels/linux/
```

### 构建特定组件的所有环境

```bash
# 构建sageattn的所有环境
make build-comp-sageattn

# 采集sageattn的所有wheel文件
make collect-comp-sageattn
```

### 构建并发布特定组件

```bash
# 构建 sageattention 的所有环境
make build-comp-sageattention

# 采集 sageattention 的所有 wheel 文件
make collect-comp-sageattention

# 发布 sageattention 到 GitHub Release
make release-comp-sageattention
```