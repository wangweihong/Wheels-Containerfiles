# RTX 5090 安装 MMCV / MMDetection3D 环境踩坑总结（实战版）
https://github.com/open-mmlab/mmcv/issues/3327
> 适用场景：
>
> - Ubuntu Linux 服务器
> - NVIDIA RTX 5090
> - 目标是安装 **PyTorch + MMCV + MMEngine + MMDetection + MMDetection3D**
> 
>说明：下面重点聚焦 **RTX 5090 上安装 MMCV / MMDetection3D 时与 mmcv 编译、build isolation、编译器版本、CUDA 12.8 相关的问题**。像“服务器最初没有 conda / 系统 Python 版本过旧”这类通用环境准备问题，不作为本文的重点展开。

> 这份文档不是“理论最优解”，而是一套**实际踩坑后验证可用**的方案。核心思路是：
>
> 1. 先确认 GPU 驱动正常；
> 2. 不碰系统 Python，单独装 conda 环境；
> 3. 先装 PyTorch；
> 4. MMCV 如果没有对应 wheel，就在 conda 环境里补 `nvcc + cuda-toolkit` 后源码编译；
> 5. 对 `mmcv` 和 `mmdetection3d` 的 editable 安装都关闭 build isolation；
> 6. 遇到编译器版本过高时，强制切回系统 gcc/g++。

---

## 1. 我最终成功的环境

这是我最后跑通的版本组合：

```text
conda env: mmdet3d-vod
Python: 3.10.20
PyTorch: 2.11.0+cu128
Torch CUDA: 12.8
MMEngine: 0.10.7
MMCV: 2.1.0
MMDetection: 3.3.0
MMDetection3D: 1.4.0
MMDetection3D repo: /home/husenjie/workspace/mmdetection3d
GPU: NVIDIA GeForce RTX 5090
```

这个组合是**实际验证可 import、可继续开发**的组合。

---

## 2. 我遇到的典型问题

### 2.1 `nvidia-smi` 显示 CUDA 13.0，但 PyTorch 装的是 cu128

这是一个非常容易误解的点。

`nvidia-smi` 里显示的 CUDA Version，更多表示**当前驱动支持到的 CUDA 能力上限**，不等于你必须安装同版本 toolkit。只要驱动足够新，通常可以运行更低版本的 CUDA runtime / toolkit。

因此：

- 驱动显示 `CUDA Version: 13.0`
- 但环境里装 `PyTorch cu128`
- 这是**可以成立**的

---

### 2.2 `mim install mmcv ...` 失败，或者 `import mmcv` 报错

表现通常有两类：

1. 安装时拿不到合适的 wheel，开始源码构建
2. 安装后 `import mmcv` 失败，或 `mmcv._ext` 缺失

本质原因通常是：

- 你这组 **PyTorch / CUDA / MMCV** 没有现成预编译包
- 需要源码编译 mmcv

对于 **RTX 5090 + torch 2.11.0 + cu128** 这一类比较新的组合，这种情况并不少见。

---

### 2.3 `ModuleNotFoundError: No module named 'pkg_resources'`

这是我最开始碰到的坑之一。

根因：

- `mmcv` 的构建脚本仍使用 `pkg_resources`
- 较新的 `setuptools`（尤其 82 相关）会导致这个问题暴露出来

表面现象是你明明主环境里已经降过 `setuptools`，但安装时还是报这个错误。

真正原因是：

- `pip install -e .` 默认会启用 **build isolation**
- 它会在一个**临时构建环境**里重新拉依赖
- 于是又把 `setuptools` 升回去了

所以只在主环境里 `pip install 'setuptools<82'` **还不够**。

---

### 2.4 `ModuleNotFoundError: No module named 'torch'`（安装 mmdetection3d 时）

这不是没装 torch，而是**editable 安装时临时构建环境看不到你当前 conda 环境里的 torch**。

本质还是：

- `pip install -e .` 默认 build isolation
- 临时环境和你的 conda 环境脱钩了

解决方式和 `mmcv` 一样：

- 关闭 build isolation

---

### 2.5 `RuntimeError: current installed version of ... c++ (14.3.0) is greater than the maximum required version by CUDA 12.8`

这是我在 mmcv 真正开始编译 C++ / CUDA 扩展时碰到的核心问题。

现象：

- conda 环境里的 host compiler 是 `x86_64-conda-linux-gnu-c++ 14.3.0`
- CUDA 12.8 这里要求 `<14.0`
- 结果直接被 PyTorch 的 `cpp_extension` 拦下来了

但我检查系统编译器后发现：

```bash
gcc --version
# 11.4.0

g++ --version
# 11.4.0
```

这说明不需要推倒重来，只需要：

- 强制构建流程使用 `/usr/bin/gcc` 和 `/usr/bin/g++`

---

## 3. 推荐安装路线（最终验证可用）

下面这套流程是我最后走通的版本。

---

## 4. Step-by-step 安装流程

### Step 0：先确认驱动和 GPU 没问题

```bash
nvidia-smi
```

如果这里都不正常，就先别折腾 Python 环境。

---

### Step 1：准备独立 conda 环境（没有的话再安装 Miniconda / Miniforge）

我这里最终使用的是 Miniconda。

```bash
cd ~
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O Miniconda3.sh
bash Miniconda3.sh -b -p $HOME/miniconda3

source ~/miniconda3/etc/profile.d/conda.sh
conda init bash
source ~/.bashrc
```

如果第一次 `conda create` 被 ToS 拦住，执行：

```bash
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r
```

---

### Step 2：创建 Python 3.10 环境

```bash
conda create -n mmdet3d-vod python=3.10 -y
conda activate mmdet3d-vod

python --version
which python
```

期望看到：

```text
Python 3.10.x
/home/xxx/miniconda3/envs/mmdet3d-vod/bin/python
```

---

### Step 3：先安装 PyTorch（CUDA 12.8）

```bash
pip install -U pip setuptools wheel
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128
```

验证：

```bash
python - <<'PY'
import torch
print('torch:', torch.__version__)
print('cuda available:', torch.cuda.is_available())
print('torch cuda:', torch.version.cuda)
if torch.cuda.is_available():
    print('gpu:', torch.cuda.get_device_name(0))
PY
```

我的输出类似：

```text
torch: 2.11.0+cu128
cuda available: True
torch cuda: 12.8
gpu: NVIDIA GeForce RTX 5090
```

---

### Step 4：补齐 CUDA 编译工具（给源码编译 MMCV 用）

如果没有可用的 mmcv wheel，这一步很关键。

```bash
conda install -c nvidia cuda-nvcc=12.8 -y
conda install -c nvidia cuda-toolkit=12.8 -y
```

然后设置环境变量：

```bash
export CUDA_HOME=$CONDA_PREFIX
export CUDACXX=$CONDA_PREFIX/bin/nvcc
export CPATH=$CONDA_PREFIX/targets/x86_64-linux/include:$CPATH
export LIBRARY_PATH=$CONDA_PREFIX/targets/x86_64-linux/lib:$LIBRARY_PATH

nvcc --version
```

注意：

- 这些 `export` 只对当前终端有效
- 关掉终端再开，需要重新 export，除非你写进 `~/.bashrc`

---

### Step 5：准备编译依赖

```bash
pip install -U pip wheel ninja psutil openmim opencv-python-headless
```

这里建议单独处理 `setuptools`：

```bash
pip install "setuptools<82"
```

> 如果你环境里已经有一些包依赖更老的 setuptools，比如 `openxlab~=60.2.0`，可能会有冲突提示。我的经验是：
>
> - 针对 mmcv/mmdet3d 编译流程，重点是**别让它进 82.0+**
> - 真正避免踩坑的关键，不只是降 setuptools，而是**安装时加 `--no-build-isolation`**

---

### Step 6：源码编译 MMCV（关键步骤）

先克隆 MMCV，并固定到和 MMDetection3D 1.4.0 兼容的版本：

```bash
cd ~
git clone https://github.com/open-mmlab/mmcv.git
cd ~/mmcv
git checkout v2.1.0
```

#### 6.1 如果你的 conda 编译器版本过高，先切系统 gcc/g++

先检查：

```bash
gcc --version
g++ --version
which gcc
which g++
```

如果系统是 11.x / 12.x / 13.x，而 conda 里是 14.x，那么建议强制使用系统编译器：

```bash
export CC=/usr/bin/gcc
export CXX=/usr/bin/g++
export CUDAHOSTCXX=/usr/bin/g++
export NVCC_CCBIN=/usr/bin/g++
hash -r
```

#### 6.2 关闭 build isolation 再安装

这一点非常关键。

```bash
cd ~/mmcv
rm -rf build dist mmcv.egg-info
MAX_JOBS=1 CC=/usr/bin/gcc CXX=/usr/bin/g++ CUDAHOSTCXX=/usr/bin/g++ NVCC_CCBIN=/usr/bin/g++ \
    pip install -v --no-build-isolation -e .
```

说明：

- `MAX_JOBS=1`：更稳，但会比较慢
- `--no-build-isolation`：避免 pip 临时新建构建环境，把 setuptools / torch 又搞乱
- `-e .`：editable 安装，方便后续调试源码

#### 6.3 验证 mmcv

```bash
python .dev_scripts/check_installation.py

python - <<'PY'
import mmcv
print('mmcv:', mmcv.__version__)
PY
```

我最终拿到的是：

```text
mmcv: 2.1.0
```

---

### Step 7：安装 MMEngine 和 MMDetection

```bash
mim install "mmengine>=0.8.0,<1.0.0"
pip install "mmdet>=3.0.0rc5,<3.4.0"
```

验证：

```bash
python - <<'PY'
import mmengine, mmcv, mmdet
print('mmengine:', mmengine.__version__)
print('mmcv:', mmcv.__version__)
print('mmdet:', mmdet.__version__)
PY
```

---

### Step 8：安装 MMDetection3D 本体

进入你自己的 MMDetection3D 仓库：

```bash
cd /path/to/mmdetection3d
```

我的路径是：

```bash
cd /home/husenjie/workspace/mmdetection3d
```

然后同样使用：

```bash
rm -rf build dist *.egg-info
pip install -v --no-build-isolation -e .
```

验证：

```bash
python - <<'PY'
import mmengine, mmcv, mmdet, mmdet3d
print('mmengine:', mmengine.__version__)
print('mmcv:', mmcv.__version__)
print('mmdet:', mmdet.__version__)
print('mmdet3d:', mmdet3d.__version__)
PY
```

我最终成功输出的是：

```text
mmengine: 0.10.7
mmcv: 2.1.0
mmdet: 3.3.0
mmdet3d: 1.4.0
```

---

## 5. 一套我最终可复现的命令清单

如果你想要一份更接近“照着敲”的版本，可以参考下面这份。

> 注意：这里假设你已经有正常的 NVIDIA 驱动，并且 `nvidia-smi` 正常。

```bash
# 1) 准备独立 conda 环境（下面示例为安装 Miniconda）
cd ~
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O Miniconda3.sh
bash Miniconda3.sh -b -p $HOME/miniconda3
source ~/miniconda3/etc/profile.d/conda.sh
conda init bash
source ~/.bashrc

# 如果被 ToS 拦住
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r

# 2) 新建环境
conda create -n mmdet3d-vod python=3.10 -y
conda activate mmdet3d-vod

# 3) 安装 PyTorch cu128
pip install -U pip setuptools wheel
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128

# 4) 安装 CUDA 编译工具
conda install -c nvidia cuda-nvcc=12.8 -y
conda install -c nvidia cuda-toolkit=12.8 -y

# 5) 设置 CUDA 环境变量
export CUDA_HOME=$CONDA_PREFIX
export CUDACXX=$CONDA_PREFIX/bin/nvcc
export CPATH=$CONDA_PREFIX/targets/x86_64-linux/include:$CPATH
export LIBRARY_PATH=$CONDA_PREFIX/targets/x86_64-linux/lib:$LIBRARY_PATH

# 6) 基础工具
pip install -U pip wheel ninja psutil openmim opencv-python-headless
pip install "setuptools<82"

# 7) 编译 MMCV
cd ~
git clone https://github.com/open-mmlab/mmcv.git
cd ~/mmcv
git checkout v2.1.0

export CC=/usr/bin/gcc
export CXX=/usr/bin/g++
export CUDAHOSTCXX=/usr/bin/g++
export NVCC_CCBIN=/usr/bin/g++

rm -rf build dist mmcv.egg-info
MAX_JOBS=1 CC=/usr/bin/gcc CXX=/usr/bin/g++ CUDAHOSTCXX=/usr/bin/g++ NVCC_CCBIN=/usr/bin/g++ \
    pip install -v --no-build-isolation -e .

# 8) 安装 mmengine + mmdet
mim install "mmengine>=0.8.0,<1.0.0"
pip install "mmdet>=3.0.0rc5,<3.4.0"

# 9) 安装 mmdetection3d
cd /home/husenjie/workspace/mmdetection3d
rm -rf build dist *.egg-info
pip install -v --no-build-isolation -e .

# 10) 验证
python - <<'PY'
import torch, mmengine, mmcv, mmdet, mmdet3d
print('torch:', torch.__version__)
print('torch cuda:', torch.version.cuda)
print('mmengine:', mmengine.__version__)
print('mmcv:', mmcv.__version__)
print('mmdet:', mmdet.__version__)
print('mmdet3d:', mmdet3d.__version__)
PY
```

---

## 6. 问题 -> 原因 -> 解决方案 对照表

| 问题 | 常见原因 | 解决方案 |
|---|---|---|
| `nvidia-smi` 显示 CUDA 13.0，但想装 cu128 | 驱动版本与 toolkit/runtime 概念混淆 | 直接在 conda 环境里安装 PyTorch cu128 |
| `mim install mmcv` 找不到可用 wheel | 当前 torch/cu128/mmcv 没有对应预编译包 | 改为源码编译 mmcv |
| `No module named 'pkg_resources'` | setuptools / build isolation 问题 | `setuptools<82` + `pip install --no-build-isolation -e .` |
| `No module named 'torch'`（装 mmdet3d） | 构建隔离环境中没有 torch | `pip install --no-build-isolation -e .` |
| `c++ 14.3.0 is greater than maximum required version by CUDA 12.8` | conda 编译器太新 | 强制 `CC=/usr/bin/gcc`, `CXX=/usr/bin/g++` |
| 编译停在 `[39/136]` 很久 | 编译 CUDA 扩展本来就慢，尤其 `MAX_JOBS=1` | 看 `ps -ef | grep -E 'nvcc|gcc|g\+\+'` 判断是否还在跑 |
| `mmcv._ext` 缺失 | 扩展没编出来 / 安装不完整 | 重新源码编译 mmcv 并执行安装验证 |

---

## 7. 两个最关键的经验

### 经验 1：别在一开始就怀疑“5090 不支持”

很多时候不是“5090 不支持”，而是：

- 当前组合没有现成 wheel
- 需要源码编译
- 编译器 / setuptools / build isolation 某一环出问题了

---

### 经验 2：`--no-build-isolation` 非常关键

这次踩坑里最容易忽略、但又最关键的一点就是这个：

```bash
pip install -v --no-build-isolation -e .
```

对我来说：

- `mmcv` 靠它绕开了临时构建环境里的 setuptools 82 问题
- `mmdetection3d` 靠它避免了“临时构建环境里没有 torch”的问题

很多“明明环境里已经装好了，但安装还在报莫名其妙错误”的情况，本质都和 build isolation 有关。

---

## 8. 这套方案更适合谁

更适合：

- Ubuntu 服务器用户
- 有 NVIDIA 驱动，但没有完整 CUDA toolkit 的用户
- 已经能装好 PyTorch，但 `mmcv` 安装总失败的人
- 需要继续做 MMDetection3D 开发的人

不一定最适合：

- 只想快速跑一个纯 Python 小 demo 的人
- 完全不需要 `mmcv` CUDA ops 的人
- 不准备继续用 OpenMMLab 这套栈的人

---

## 9. 我最终建议的检查顺序

如果你卡住了，按这个顺序查，不要乱：

1. `nvidia-smi` 是否正常
2. 当前是不是 conda 环境里的 Python 3.10
3. `torch.cuda.is_available()` 是否为 True
4. `nvcc --version` 是否正常
5. `mmcv` 是 wheel 还是源码编译路线
6. 是否用了 `--no-build-isolation`
7. 当前 `gcc/g++` 版本是否过高
8. `mmcv` 是否能 `import`
9. `mmdet3d` 是否能 `import`

---

## 10. 最后的建议

如果你是第一次在 RTX 5090 上折腾 OpenMMLab：

- **先把环境装通，再接数据集**
- **先做单模态 baseline，再做多模态融合**
- **先确认官方仓库可 import，再开始改代码**

别一上来就同时改：

- 环境
- 数据集
- 项目结构
- 融合模型

不然问题会全搅在一起，根本没法定位。

---

## 11. 参考资料

- [MMCV 安装文档（官方）](https://mmcv.readthedocs.io/en/2.x/get_started/installation.html)
- [MMDetection3D 安装文档（官方）](https://mmdetection3d.readthedocs.io/en/latest/get_started.html)
- [MMDetection3D FAQ：版本兼容说明（官方）](https://mmdetection3d.readthedocs.io/en/latest/notes/faq.html)
- [PyTorch 官方安装页面](https://pytorch.org/get-started/locally/)
- [PyTorch 历史版本页面](https://pytorch.org/get-started/previous-versions/)
- [NVIDIA CUDA Compatibility 文档](https://docs.nvidia.com/deploy/cuda-compatibility/)
- [MMCV Issue #3325：setuptools 82 / pkg_resources 问题](https://github.com/open-mmlab/mmcv/issues/3325)
- [MMCV Issue #3327：RTX 5090 + CUDA 12.8 编译经验](https://github.com/open-mmlab/mmcv/issues/3327)

---

如果你也在 RTX 5090 上装 MMCV / MMDetection3D 卡了很久，希望这篇能帮你少绕一点路。
