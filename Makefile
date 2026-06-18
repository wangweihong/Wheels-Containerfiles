# ==============================================================================
# Makefile for Matrix Docker Builds
# ==============================================================================

REGISTRY ?= docker.io
IMAGE_NAME = yanwk/comfyui-extras
DATE := $(shell date +%Y%m%d)
WHEELS_HOST_DIR = $(shell pwd)/wheels/linux


# Build arguments with defaults
MAX_JOBS ?= 1
## 12.0+PTX 表示支持5090兼容未来架构的中间代码
TORCH_CUDA_ARCH_LIST ?= 8.0;8.6;10.0;12.0;12.0+PTX

# Current date for timestamped tags (format: YYYYMMDD)
DATE := $(shell date +%Y%m%d)

# Wheel output directory
WHEELS_HOST_DIR = ./_wheels/linux
# --- 1. 定义维度 ---

# 所有组件
ALL_COMPONENTS = cumesh flexGEMM o_voxel sageattention sageattn3 spargeattn nvdiffrec nvdiffrast fastvideo-kernel xformers audiotools mmcv pytorch3d
# 所有支持的环境版本
ALL_ENVS = py313-cu130-pt211 py312-cu128-pt29 py312-cu128-pt28  py313-cu130-pt211-r2 py313-cu130-pt211-fix-headdim256

# 自动推导组件的根目录 (根据组件名返回其父路径)
# 格式: $(if $(filter 组件名,$(1)),路径)
define get_comp_root
$(strip \
    $(if $(filter cumesh flexGEMM o_voxel nvdiffrec nvdiffrast,$(1)),3d/trellies/,\
    $(if $(filter sageattention,$(1)),accelerator/sageattention/,\
    $(if $(filter sageattn3,$(1)),accelerator/sageattn3/,\
    $(if $(filter spargeattn,$(1)),accelerator/spargeattn/,\
    $(if $(filter fastvideo-kernel,$(1)),fastvideo/,\
    $(if $(filter xformers,$(1)),accelerator/xformers/,\
	$(if $(filter audiotools,$(1)),tts/,\
	$(if $(filter mmcv,$(1)),sdpose/,\
	$(if $(filter pytorch3d,$(1)),3d/lito/,\
    ./))))))))) \
)
endef

# --- 2. 伪目标声明 ---

# 动态生成所有可能的组合目标名（分隔符改为@）
MATRIX_COMBO = $(foreach c,$(ALL_COMPONENTS),$(foreach e,$(ALL_ENVS),$(c)@$(e)))

.PHONY: help build-all collect-all clean-all status \
        $(addprefix build-env-,$(ALL_ENVS)) \
        $(addprefix build-comp-,$(ALL_COMPONENTS))

# --- 3. 帮助信息 ---

help:
	@echo "Usage Examples:"
	@echo "  make build-all             - Build everything (Matrix)"
	@echo "  make build-env-py313...    - Build all components for one env"
	@echo "  make build-comp-cumesh     - Build one component for all envs"
	@echo "  make build-m-cumesh@py313  - Build specific component-env combo"

	@echo "  make collect-all             - Collect everything (Matrix)"
	@echo "  make collect-env-py313...    - Collect all components for one env"
	@echo "  make collect-comp-cumesh..     - Collect one component for all envs"
	@echo "  make collect-m-cumesh@py313..  - Collect specific component-env combo"

	@echo "  make status                - Show what is built locally"
	@echo ""
	@echo "Components: $(ALL_COMPONENTS)"
	@echo "Envs:       $(ALL_ENVS)"

# --- 4. 矩阵模板 (核心逻辑) ---

define MATRIX_TEMPLATE
# 参数 $(1): 组件名, $(2): 环境名
# 内部变量定义
$(1)_$(2)_DIR  := $$(call get_comp_root,$(1))$(1)-$(2)
$(1)_$(2)_TAG  := $(1)-$(2)

# 构建目标 (分隔符改为@)
build-m-$(1)@$(2):
	@DIR="$$($(1)_$(2)_DIR)"; \
	TAG="$$($(1)_$(2)_TAG)"; \
	if [ ! -d "$$$$DIR" ]; then \
		echo "  [SKIP] Directory $$$$DIR not found. Skipping."; \
	else \
		echo "------------------------------------------------"; \
		echo "BUILDING COMPONENT: $(1) | ENV: $(2)"; \
		PROXY_ARGS=""; \
		if [ -n "$$$$http_proxy" ]; then \
			echo "Using http_proxy: $$$$http_proxy"; \
			PROXY_ARGS="$$$$PROXY_ARGS --build-arg HTTP_PROXY=$$$$http_proxy"; \
		elif [ -n "$$$$HTTP_PROXY" ]; then \
			echo "Using HTTP_PROXY: $$$$HTTP_PROXY"; \
			PROXY_ARGS="$$$$PROXY_ARGS --build-arg HTTP_PROXY=$$$$HTTP_PROXY"; \
		fi; \
		if [ -n "$$$$https_proxy" ]; then \
			echo "Using https_proxy: $$$$https_proxy"; \
			PROXY_ARGS="$$$$PROXY_ARGS --build-arg HTTPS_PROXY=$$$$https_proxy"; \
		elif [ -n "$$$$HTTPS_PROXY" ]; then \
			echo "Using HTTPS_PROXY: $$$$HTTPS_PROXY"; \
			PROXY_ARGS="$$$$PROXY_ARGS --build-arg HTTPS_PROXY=$$$$HTTPS_PROXY"; \
		fi; \
		if [ -n "$$$$no_proxy" ]; then \
			PROXY_ARGS="$$$$PROXY_ARGS --build-arg NO_PROXY=$$$$no_proxy"; \
		elif [ -n "$$$$NO_PROXY" ]; then \
			PROXY_ARGS="$$$$PROXY_ARGS --build-arg NO_PROXY=$$$$NO_PROXY"; \
		fi; \
		\
		echo "Target Tags: $$$$TAG and $$$$TAG-$(DATE)"; \
		echo "Proxy Args: $$$$PROXY_ARGS"; \
		docker build \
			$$$$PROXY_ARGS \
			--build-arg REGISTRY=$(REGISTRY) \
			--build-arg MAX_JOBS=$(MAX_JOBS) \
			--build-arg TORCH_CUDA_ARCH_LIST='$(TORCH_CUDA_ARCH_LIST)' \
			-t $(REGISTRY)/$(IMAGE_NAME):$$$$TAG \
			-t $(REGISTRY)/$(IMAGE_NAME):$$$$TAG-$(DATE) \
			"$$$$DIR"; \
	fi

# 推送目标
push-m-$(1)@$(2):
	@TAG=$$($(1)_$(2)_TAG); \
	docker push $(REGISTRY)/$(IMAGE_NAME):$$$$TAG; \
	docker push $(REGISTRY)/$(IMAGE_NAME):$$$$TAG-$(DATE)

# 采集目标 (wheel 保存到 组件/环境 子目录下)
# sageattn/
# ├── py313-cu130-pt211/
# ├── py313-cu130-pt211-fix-headdim256/
# ├── py313-cu130-pt211-fix-sm120/
# └── py313-cu130-pt211-fix-blackwell/
collect-m-$(1)@$(2):
	@TAG=$$($(1)_$(2)_TAG); \
	if [ "$(REGISTRY)" = "docker.io" ]; then IMG="$(IMAGE_NAME):$$$$TAG"; else IMG="$(REGISTRY)/$(IMAGE_NAME):$$$$TAG"; fi; \
	if [ -z "$$$$(docker images -q $$$$IMG)" ]; then \
		echo "  [SKIP] Image $$$$IMG not found."; \
	else \
		echo "  [OK] Collecting from $$$$IMG into $(1)/$(2)/..."; \
		mkdir -p "$(WHEELS_HOST_DIR)/$(1)/$(2)"; \
		docker run --rm -v "$(WHEELS_HOST_DIR)/$(1)/$(2):/extras" $$$$IMG sh -c 'cp -rv /wheels/*.whl /extras/ 2>/dev/null || true'; \
	fi

# 清理目标
clean-m-$(1)@$(2):
	@TAG=$$($(1)_$(2)_TAG); \
	docker rmi $(REGISTRY)/$(IMAGE_NAME):$$$$TAG 2>/dev/null || true; \
	docker rmi $(REGISTRY)/$(IMAGE_NAME):$$$$TAG-$(DATE) 2>/dev/null || true
endef

# --- 5. 实例化矩阵 ---

$(foreach c,$(ALL_COMPONENTS),$(foreach e,$(ALL_ENVS),$(eval $(call MATRIX_TEMPLATE,$(c),$(e)))))

# --- 6. 批量汇总规则 ---

# 全量构建
build-all: $(addprefix build-m-,$(MATRIX_COMBO))

# 按环境构建 (例如: make build-env-py313-cu130-pt211)
build-env-%:
	@$(MAKE) $(addprefix build-m-,$(foreach c,$(ALL_COMPONENTS),$(c)@$*))

# 按组件构建 (例如: make build-comp-cumesh)
build-comp-%:
	@$(MAKE) $(addprefix build-m-,$(foreach e,$(ALL_ENVS),$*@$(e)))

# 批量推送
push-all: $(addprefix push-m-,$(MATRIX_COMBO))

# 批量采集
collect-all: $(addprefix collect-m-,$(MATRIX_COMBO))

# 删除采集的 wheel 文件
collect-clean: 
	rm -rf $(WHEELS_HOST_DIR)/*

# 批量清理
clean-all: $(addprefix clean-m-,$(MATRIX_COMBO))

# --- 7. 状态查看 ---

status:
	@echo "Matrix Build Status (Local Images):"
	@for c in $(ALL_COMPONENTS); do \
		for e in $(ALL_ENVS); do \
			TAG="$$c-$$e"; \
			if [ "$(REGISTRY)" = "docker.io" ]; then IMG="$(IMAGE_NAME):$$TAG"; else IMG="$(REGISTRY)/$(IMAGE_NAME):$$TAG"; fi; \
			if [ -n "$$(docker images -q $$IMG)" ]; then \
				echo "  [✓] $$c | $$e"; \
			else \
				echo "  [ ] $$c | $$e"; \
			fi; \
		done; \
	done


# 默认 Release 标题和说明（可以通过参数覆盖）
TITLE ?= $(DATE)
NOTES ?= Release built on $(DATE)

.PHONY: release

# 创建 GitHub Release
## 需要先执行 gh auth login 来登录 GitHub
release:
	@echo "Checking for wheel files..."
	@if [ -z "$$(ls $(WHEELS_HOST_DIR)/*.whl 2>/dev/null)" ]; then \
		echo "Error: No .whl files found in $(WHEELS_HOST_DIR)."; \
		exit 1; \
	fi
	@echo "Creating GitHub Release: $(DATE)..."
	gh release create $(DATE) $(WHEELS_HOST_DIR)/*.whl \
		--title "$(TITLE)" \
		--notes "$(NOTES)"


# --- 8. 特定模块特定环境的自定义规则 (Custom Matrix) ---
# --- 8. 自定义特殊环境编译规则 (独立于 build-m) ---

# 专供 build-c 规则使用的映射变量 (格式: 组件名@环境名)
# 注意：为了让 Makefile 处理起来最稳健，建议变量里直接用 @ 符号连接
CUSTOM_TARGETS ?= sageattn@py313-cu130-pt211-fix-headdim256

# 转换为 build-c- 前缀的目标列表
CUSTOM_BUILD_TARGETS = $(addprefix build-c-,$(CUSTOM_TARGETS))

.PHONY: build-c-all

# 规则 1：编译 CUSTOM_TARGETS 变量中指定的全部内容
build-c-all: $(CUSTOM_BUILD_TARGETS)
	@echo "================================================"
	@echo "All specific custom targets built successfully!"

# 批量采集
collect-c-all: $(CUSTOM_COLLECT_TARGETS)
	@echo "================================================"
	@echo "All specific custom wheels collected successfully!"

# 批量清理
clean-c-all: $(CUSTOM_CLEAN_TARGETS)
	@echo "================================================"
	@echo "All specific custom images cleaned successfully!"

# 规则 2：编译单个特定项的模式匹配规则
# 支持：make build-c-sageattn@py313-cu130-pt211-fix-headdim256
build-c-%:
	@# 1. 在 Shell 中利用 Python 或 Cut 精准切分组件名和环境名
	@COMP=$$(echo "$*" | cut -d'@' -f1); \
	ENV=$$(echo "$*" | cut -d'@' -f2); \
	\
	# 2. 仿照 get_comp_root 的逻辑，在 Shell 中进行路径分支判断 \
	if echo "$$COMP" | grep -qE "^(cumesh|flexGEMM|o_voxel|nvdiffrec|nvdiffrast)$$"; then ROOT="3d/trellies/"; \
	elif [ "$$COMP" = "sageattn" ]; then ROOT="accelerator/"; \
	elif [ "$$COMP" = "fastvideo-kernel" ]; then ROOT="fastvideo/"; \
	elif [ "$$COMP" = "xformers" ]; then ROOT="accelerator/"; \
	elif [ "$$COMP" = "audiotools" ]; then ROOT="tts/"; \
	elif [ "$$COMP" = "mmcv" ]; then ROOT="sdpose/"; \
	elif [ "$$COMP" = "pytorch3d" ]; then ROOT="3d/lito/"; \
	else ROOT="./"; fi; \
	\
	DIR="$${ROOT}$${COMP}-$${ENV}"; \
	TAG="$${COMP}-$${ENV}"; \
	\
	# 3. 执行核心 Docker 构建逻辑 \
	if [ ! -d "$$DIR" ]; then \
		echo "  [SKIP] Directory $$DIR not found. Skipping."; \
	else \
		echo "------------------------------------------------"; \
		echo "BUILDING CUSTOM COMPONENT: $$COMP | ENV: $$ENV"; \
		PROXY_ARGS=""; \
		if [ -n "$$http_proxy" ]; then PROXY_ARGS="$$PROXY_ARGS --build-arg HTTP_PROXY=$$http_proxy"; \
		elif [ -n "$$HTTP_PROXY" ]; then PROXY_ARGS="$$PROXY_ARGS --build-arg HTTP_PROXY=$$HTTP_PROXY"; fi; \
		if [ -n "$$https_proxy" ]; then PROXY_ARGS="$$PROXY_ARGS --build-arg HTTPS_PROXY=$$https_proxy"; \
		elif [ -n "$$HTTPS_PROXY" ]; then PROXY_ARGS="$$PROXY_ARGS --build-arg HTTPS_PROXY=$$HTTPS_PROXY"; fi; \
		if [ -n "$$no_proxy" ]; then PROXY_ARGS="$$PROXY_ARGS --build-arg NO_PROXY=$$no_proxy"; \
		elif [ -n "$$NO_PROXY" ]; then PROXY_ARGS="$$PROXY_ARGS --build-arg NO_PROXY=$$NO_PROXY"; fi; \
		\
		docker build \
			$$PROXY_ARGS \
			--build-arg REGISTRY=$(REGISTRY) \
			--build-arg MAX_JOBS=$(MAX_JOBS) \
			--build-arg TORCH_CUDA_ARCH_LIST='$(TORCH_CUDA_ARCH_LIST)' \
			-t $(REGISTRY)/$(IMAGE_NAME):$$TAG \
			-t $(REGISTRY)/$(IMAGE_NAME):$$TAG-$(DATE) \
			"$$DIR"; \
	fi

# 2. 单项采集规则
# 支持：make collect-c-sageattn@py313-cu130-pt211-fix-headdim256
collect-c-%:
	@COMP=$$(echo "$*" | cut -d'@' -f1); \
	ENV=$$(echo "$*" | cut -d'@' -f2); \
	TAG="$${COMP}-$${ENV}"; \
	if [ "$(REGISTRY)" = "docker.io" ]; then IMG="$(IMAGE_NAME):$$TAG"; else IMG="$(REGISTRY)/$(IMAGE_NAME):$$TAG"; fi; \
	if [ -z "$$(docker images -q $$IMG)" ]; then \
		echo "  [SKIP] Image $$IMG not found."; \
	else \
		echo "  [OK] Collecting from custom image $$IMG..."; \
		mkdir -p "$(WHEELS_HOST_DIR)/$${COMP}/$${ENV}"; \
		docker run --rm -v "$(WHEELS_HOST_DIR)/$${COMP}/$${ENV}:/extras" $$IMG sh -c 'cp -rv /wheels/*.whl /extras/ 2>/dev/null || true'; \
	fi

# 3. 单项清理规则
# 支持：make clean-c-sageattn@py313-cu130-pt211-fix-headdim256
clean-c-%:
	@COMP=$$(echo "$*" | cut -d'@' -f1); \
	ENV=$$(echo "$*" | cut -d'@' -f2); \
	TAG="$${COMP}-$${ENV}"; \
	echo "  [CLEAN] Removing local images for $$TAG"; \
	docker rmi $(REGISTRY)/$(IMAGE_NAME):$$TAG 2>/dev/null || true; \
	docker rmi $(REGISTRY)/$(IMAGE_NAME):$$TAG-$(DATE) 2>/dev/null || tru