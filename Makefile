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
TORCH_CUDA_ARCH_LIST ?= 8.0;8.6;10.0;12.0+PTX

# Current date for timestamped tags (format: YYYYMMDD)
DATE := $(shell date +%Y%m%d)

# Wheel output directory
WHEELS_HOST_DIR = ./wheels/linux

# --- 1. 定义维度 ---

# 所有组件
ALL_COMPONENTS = cumesh flexGEMM o_voxel sageattn nvdiffrec nvdiffrast fastvideo-kernel xformers
# 所有支持的环境版本
ALL_ENVS = py313-cu130-pt211 py312-cu128-pt29 py312-cu128-pt28

# 自动推导组件的根目录 (根据组件名返回其父路径)
# 格式: $(if $(filter 组件名,$(1)),路径)
define get_comp_root
$(strip \
    $(if $(filter cumesh flexGEMM o_voxel nvdiffrec nvdiffrast,$(1)),3d/trellies/,\
    $(if $(filter sageattn,$(1)),accelerator/,\
    $(if $(filter fastvideo-kernel,$(1)),fastvideo/,\
    $(if $(filter xformers,$(1)),accelerator/,\
    ./)))) \
)
endef

# --- 2. 伪目标声明 ---

# 动态生成所有可能的组合目标名
MATRIX_COMBO = $(foreach c,$(ALL_COMPONENTS),$(foreach e,$(ALL_ENVS),$(c)_$(e)))

.PHONY: help build-all collect-all clean-all status \
        $(addprefix build-env-,$(ALL_ENVS)) \
        $(addprefix build-comp-,$(ALL_COMPONENTS))

# --- 3. 帮助信息 ---

help:
	@echo "Usage Examples:"
	@echo "  make build-all             - Build everything (Matrix)"
	@echo "  make build-env-py313...    - Build all components for one env"
	@echo "  make build-comp-cumesh     - Build one component for all envs"
	@echo "  make build-m-cumesh_py313  - Build specific component-env combo"

	@echo "  make collect-all             - Collect everything (Matrix)"
	@echo "  make collect-env-py313...    - Collect all components for one env"
	@echo "  make collect-comp-cumesh..     - Collect one component for all envs"
	@echo "  make collect-m-cumesh_py313..  - Collect specific component-env combo"



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

# 构建目标
# 参数 $(1): 组件名, $(2): 环境名
build-m-$(1)_$(2):
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
push-m-$(1)_$(2):
	@TAG=$$($(1)_$(2)_TAG); \
	docker push $(REGISTRY)/$(IMAGE_NAME):$$$$TAG; \
	docker push $(REGISTRY)/$(IMAGE_NAME):$$$$TAG-$(DATE)

# 采集目标
collect-m-$(1)_$(2):
	@TAG=$$($(1)_$(2)_TAG); \
	if [ "$(REGISTRY)" = "docker.io" ]; then IMG="$(IMAGE_NAME):$$$$TAG"; else IMG="$(REGISTRY)/$(IMAGE_NAME):$$$$TAG"; fi; \
	if [ -z "$$$$(docker images -q $$$$IMG)" ]; then \
		echo "  [SKIP] Image $$$$IMG not found."; \
	else \
		echo "  [OK] Collecting from $$$$IMG..."; \
		mkdir -p $(WHEELS_HOST_DIR); \
		docker run --rm -v "$(WHEELS_HOST_DIR):/extras" $$$$IMG sh -c 'cp -rv /wheels/*.whl /extras/ 2>/dev/null || true'; \
	fi

# 清理目标
clean-m-$(1)_$(2):
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
	@$(MAKE) $(addprefix build-m-,$(foreach c,$(ALL_COMPONENTS),$(c)_$*))

# 按组件构建 (例如: make build-comp-cumesh)
build-comp-%:
	@$(MAKE) $(addprefix build-m-,$(foreach e,$(ALL_ENVS),$*_$(e)))

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