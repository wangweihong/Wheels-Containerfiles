# ==============================================================================
# Makefile for Matrix Docker Builds
# ==============================================================================

REGISTRY ?= docker.io
IMAGE_NAME = yanwk/comfyui-extras
WHEELS_HOST_DIR = $(shell pwd)/_wheels/linux


# Build arguments with defaults
MAX_JOBS ?= 1
## 12.0+PTX 表示支持5090兼容未来架构的中间代码
TORCH_CUDA_ARCH_LIST ?= 8.0;8.6;10.0;12.0;12.0+PTX

# ==============================================================================
# yq 依赖检查与预警机制
# ==============================================================================
CHECK_YQ := $(shell command -v yq 2>/dev/null)

.PHONY: check-yq-dependency

check-yq-dependency:
ifndef CHECK_YQ
	@echo "========================================================================"
	@echo "⚠️  [WARNING] 'yq' command not found! "
	@echo "   This repository uses 'meta.yaml' to track upstream commits and variants."
	@echo "   Without 'yq', matrix builds will skip metadata injection."
	@echo "========================================================================"
	@echo "💡 To install 'yq', run the following command:"
	@echo "   Linux (AMD64):"
	@echo "     sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq && sudo chmod +x /usr/bin/yq"
	@echo "   macOS (Homebrew):"
	@echo "     brew install yq"
	@echo "========================================================================"
	@echo ""
	@exit 1
endif

# --- 1. 定义维度 ---

# 所有组件
ALL_COMPONENTS = cumesh flexGEMM o_voxel sageattention sageattn3 spargeatten nvdiffrec nvdiffrast fastvideo-kernel xformers audiotools mmcv pytorch3d
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
.PHONY: build-comp-% release-comp-% collect-comp-%
.PHONY: help build-all collect-all clean-all release-all

# --- 3. 帮助信息 ---

help:
	@echo "Usage Examples:"
	@echo "  make build-all             - Build everything (Matrix)"
	@echo "  make build-comp-cumesh     - Build one component for all envs"
	@echo "  make build-m-cumesh@py313  - Build specific component-env combo"

	@echo "  make collect-all             - Collect everything (Matrix)"
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
build-m-$(1)@$(2): check-yq-dependency
	@DIR="$$($(1)_$(2)_DIR)"; \
	TAG="$$($(1)_$(2)_TAG)"; \
	if [ ! -d "$$$$DIR" ]; then \
		echo "  [SKIP] Directory $$$$DIR not found. Skipping."; \
		exit 0; \
	fi; \
	echo "------------------------------------------------"; \
	echo "BUILDING COMPONENT: $(1) | ENV: $(2)"; \
	META_FILE="$$$$DIR/meta.yaml"; \
	UPSTREAM_REPO=""; UPSTREAM_COMMIT=""; UPSTREAM_BRANCH=""; COMP_NOTE=""; \
	if [ -f "$$$$META_FILE" ]; then \
		echo "Found $$$$META_FILE, parsing metadata..."; \
		UPSTREAM_REPO=$$$$(yq eval '.upstream.repo' $$$$META_FILE); \
		UPSTREAM_COMMIT=$$$$(yq eval '.upstream.commit' $$$$META_FILE); \
		UPSTREAM_BRANCH=$$$$(yq eval '.upstream.branch' $$$$META_FILE); \
		COMP_NOTE=$$$$(yq eval '.notes' $$$$META_FILE); \
	fi; \
	PROXY_ARGS=""; \
	[ -n "$$$$http_proxy" ] && PROXY_ARGS="$$$$PROXY_ARGS --build-arg HTTP_PROXY=$$$$http_proxy"; \
	[ -n "$$$$https_proxy" ] && PROXY_ARGS="$$$$PROXY_ARGS --build-arg HTTPS_PROXY=$$$$https_proxy"; \
	[ -n "$$$$no_proxy" ] && PROXY_ARGS="$$$$PROXY_ARGS --build-arg NO_PROXY=$$$$no_proxy"; \
	\
	echo "Target Tags: $$$$TAG and $$$$TAG-$(DATE)"; \
	echo "Proxy Args: $$$$PROXY_ARGS"; \
	docker build \
		$$$$PROXY_ARGS \
		--build-arg REGISTRY=$(REGISTRY) \
		--build-arg MAX_JOBS=$(MAX_JOBS) \
		--build-arg TORCH_CUDA_ARCH_LIST='$(TORCH_CUDA_ARCH_LIST)' \
		--build-arg UPSTREAM_REPO="$$$$UPSTREAM_REPO" \
		--build-arg UPSTREAM_COMMIT="$$$$UPSTREAM_COMMIT" \
		--build-arg UPSTREAM_BRANCH="$$$$UPSTREAM_BRANCH" \
		-t $(REGISTRY)/$(IMAGE_NAME):$$$$TAG \
		-t $(REGISTRY)/$(IMAGE_NAME):$$$$TAG-$(DATE) \
		"$$$$DIR"; \
	

# 推送目标
push-m-$(1)@$(2):
	@TAG=$$($(1)_$(2)_TAG); \
	docker push $(REGISTRY)/$(IMAGE_NAME):$$$$TAG; \
	docker push $(REGISTRY)/$(IMAGE_NAME):$$$$TAG-$(DATE)

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

# 独立组件的 Release 目标（自动追加或新建）
# 独立组件的 Release 目标（Tag 仅为模块名，支持多环境、多变体追加）
release-m-$(1)@$(2):
	@TARGET_DIR="$(WHEELS_HOST_DIR)/$(1)/$(2)"; \
	if [ ! -d "$$$$TARGET_DIR" ] || [ -z "$$$$(ls $$$$TARGET_DIR/*.whl 2>/dev/null)" ]; then \
		exit 0; \
	fi; \
	META_FILE="$$($(1)_$(2)_DIR)/meta.yaml"; \
	VVARIANT="standard"; \
	UPSTREAM_REPO=""; UPSTREAM_COMMIT=""; UPSTREAM_BRANCH=""; COMP_NOTE="";UPSTREAM_REPO_SHORTCUT="GitHub"; \
	if [ -f "$$$$META_FILE" ]; then \
		echo "Found $$$$META_FILE, parsing metadata..."; \
		UPSTREAM_REPO=$$$$(yq eval '.upstream.repo' $$$$META_FILE); \
		if [ -n "$$$$UPSTREAM_REPO" ]; then \
			UPSTREAM_REPO_SHORTCUT=$$$$(echo "$$$$UPSTREAM_REPO" | sed -E 's|https://github.com/||; s|\.git$$$$||'); \
		fi; \
		UPSTREAM_COMMIT=$$$$(yq eval '.upstream.commit' $$$$META_FILE); \
		UPSTREAM_BRANCH=$$$$(yq eval '.upstream.branch' $$$$META_FILE); \
		COMP_NOTE=$$$$(yq eval '.notes' $$$$META_FILE); \
		VARIANT=$$$$(yq -r '.variant' $$$$META_FILE 2>/dev/null); \
	fi; \
	RELEASE_TAG="$(1)"; \
	RELEASE_TITLE="$(1) Precompiled Wheels Repository"; \
	NOTES_FILE="/tmp/release_notes_$(1).md"; \
	\
	if gh release view "$$$$RELEASE_TAG" --json body -q .body > $$$$NOTES_FILE 2>/dev/null; then \
		echo "Fetched existing release notes from GitHub."; \
	else \
		if [ -f "./RELEASE_TEMPLATE.md" ]; then \
			cp "./RELEASE_TEMPLATE.md" $$$$NOTES_FILE; \
		else \
			echo "## $$$$RELEASE_TITLE" > $$$$NOTES_FILE; \
			echo "| Wheel包 | 上游仓库 | 分支 | 提交 | 说明 |" >> $$$$NOTES_FILE; \
			echo "| :--- | :--- | :--- | :--- | :--- |" >> $$$$NOTES_FILE; \
		fi; \
	fi; \
	\
	cd $$$$TARGET_DIR; \
	for f in *.whl; do \
		if ! grep -q "$$$$f" $$$$NOTES_FILE; then \
			echo "| \`$$$$f\` | [$$$$UPSTREAM_REPO_SHORTCUT]($$$$UPSTREAM_REPO) | \`$$$$UPSTREAM_BRANCH\` | [$$$$UPSTREAM_COMMIT]($$$$UPSTREAM_REPO/commit/$$$$UPSTREAM_COMMIT) | $$$$COMP_NOTE |" >> $$$$NOTES_FILE; \
		fi; \
	done; \
	\
	echo "------------------------------------------------"; \
	echo "UPLOADING WHEELS TO RELEASE TAG: $$$$RELEASE_TAG"; \
	\
	if gh release view "$$$$RELEASE_TAG" >/dev/null 2>&1; then \
		echo "Release $$$$RELEASE_TAG exists. Checking for existing assets..."; \
		EXISTING_ASSETS="$$$$(gh release view "$$$$RELEASE_TAG" --json assets -q '.assets[].name' 2>/dev/null)"; \
		for f in *.whl; do \
			if ! echo "$$$$EXISTING_ASSETS" | grep -Fqx "$$$$f"; then \
				echo "Uploading new asset: $$$$f"; \
				gh release upload "$$$$RELEASE_TAG" "$$$$f"; \
			else \
				echo "Asset $$$$f already exists, skipping."; \
			fi; \
		done; \
		gh release edit "$$$$RELEASE_TAG" --notes-file $$$$NOTES_FILE; \
	else \
		echo "Release $$$$RELEASE_TAG not found. Creating a new one with dynamic matrix table..."; \
		gh release create "$$$$RELEASE_TAG" $$$$TARGET_DIR/*.whl \
			--title "$$$$RELEASE_TITLE" \
			--notes-file $$$$NOTES_FILE; \
	fi; \
	rm -f $$$$NOTES_FILE
endef

# --- 5. 实例化矩阵 ---

$(foreach c,$(ALL_COMPONENTS),$(foreach e,$(ALL_ENVS),$(eval $(call MATRIX_TEMPLATE,$(c),$(e)))))

# --- 6. 批量汇总规则 ---
# 按组件构建 (例如: make build-comp-cumesh)
build-comp-%:
	@for e in $(ALL_ENVS); do \
		DIR="$(call get_comp_root,$*)$*-$$e"; \
		if [ -d "$$DIR" ]; then \
			$(MAKE) build-m-$*@$$e; \
		fi; \
	done

# 按组件采集 (例如: make collect-comp-cumesh)
collect-comp-%:
	@for e in $(ALL_ENVS); do \
		DIR="$(call get_comp_root,$*)$*-$$e"; \
		if [ -d "$$DIR" ]; then \
			$(MAKE) collect-m-$*@$$e; \
		fi; \
	done

# 它会智能遍历所有环境目录，把属于该组件的所有本地轮子打包/追加到 GitHub 对应的模块 Release 中
release-comp-%:
	@echo "------------------------------------------------"
	@echo "STARTING RELEASE FOR COMPONENT: $*"
	@echo "------------------------------------------------"
	@for e in $(ALL_ENVS); do \
		DIR="$(call get_comp_root,$*)$*-$$e"; \
		if [ -d "$$DIR" ]; then \
			$(MAKE) release-m-$*@$$e; \
		fi; \
	done
	@echo "Finished release process for component: $*"

# 全量构建
build-all: $(addprefix build-m-,$(MATRIX_COMBO))
# 批量推送
push-all: $(addprefix push-m-,$(MATRIX_COMBO))

# 批量采集
collect-all: $(addprefix collect-m-,$(MATRIX_COMBO))

# 核心修改 1：组件级一键批量发布
release-all: $(addprefix release-m-,$(MATRIX_COMBO))

# 删除采集的 wheel 文件
collect-clean: 
	rm -rf ./$(WHEELS_HOST_DIR)/*

# 批量清理
clean-all: $(addprefix clean-m-,$(MATRIX_COMBO))