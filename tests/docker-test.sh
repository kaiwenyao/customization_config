#!/usr/bin/env bash
# 在干净的容器里端到端跑 install.sh 并检查结果。
#
#   tests/docker-test.sh [镜像]                      # 默认 ubuntu:24.04,以 root 执行
#   TEST_USER=tester tests/docker-test.sh debian:12  # 以普通用户 + sudo 执行
#   PLATFORM=linux/amd64 tests/docker-test.sh        # 指定架构
#
# 测的是当前工作区的内容(只读挂载后复制进容器),不是 GitHub 上的 master。

set -euo pipefail

readonly DEFAULT_IMAGE="ubuntu:24.04"
readonly SRC_MOUNT="/src"
readonly NVIM_MIN_VERSION="0.11.2"
readonly LOCK_FILE="nvim-for-macmini/lazy-lock.json"

FAILURES=0

run_container() {
  local image=${1:-$DEFAULT_IMAGE}
  local repo_root
  repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

  local platform_args=()
  if [ -n "${PLATFORM:-}" ]; then platform_args=(--platform "$PLATFORM"); fi

  echo "### $image ${PLATFORM:-} user=${TEST_USER:-root}"
  docker run --rm ${platform_args[@]+"${platform_args[@]}"} \
    -e TEST_USER="${TEST_USER:-}" \
    -v "$repo_root:$SRC_MOUNT:ro" \
    "$image" bash "$SRC_MOUNT/tests/docker-test.sh" --inside
}

# 以 root 进入容器后,按需建一个带免密 sudo 的普通用户并切换过去。
switch_to_test_user() {
  local user=$1
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq sudo >/dev/null
  useradd -m -s /bin/bash "$user"
  echo "$user ALL=(ALL) NOPASSWD:ALL" >"/etc/sudoers.d/$user"
  exec sudo -u "$user" -H bash "$SRC_MOUNT/tests/docker-test.sh" --inside
}

check() {
  local description=$1
  shift
  if "$@" >/dev/null 2>&1; then
    echo "PASS  $description"
  else
    echo "FAIL  $description"
    FAILURES=$((FAILURES + 1))
  fi
}

version_ge() {
  [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]
}

nvim_is_new_enough() {
  local version
  version="$(nvim --version | head -n1 | sed -E 's/^NVIM v([0-9.]+).*/\1/')"
  version_ge "$version" "$NVIM_MIN_VERSION"
}

node_is_new_enough() {
  [ "$(node --version | sed -E 's/^v([0-9]+).*/\1/')" -ge 18 ]
}

tmux_config_loads() {
  tmux -L install-test -f /dev/null new-session -d
  tmux -L install-test source-file "$HOME/.tmux.conf"
  local status=$?
  tmux -L install-test kill-server
  return "$status"
}

# 锁文件里的每个插件都已安装,且检出的提交和锁定的一致。
plugins_match_lockfile() {
  local repo=$1 name locked actual plugin_count=0
  while read -r name locked; do
    actual="$(git -C "$HOME/.local/share/nvim/lazy/$name" rev-parse HEAD 2>/dev/null)" || actual="未安装"
    if [ "$locked" != "$actual" ]; then
      echo "  $name: 锁定 $locked,实际 $actual" >&2
      return 1
    fi
    plugin_count=$((plugin_count + 1))
  done < <(sed -nE 's/^ *"([^"]+)": \{.*"commit": "([0-9a-f]+)".*/\1 \2/p' "$repo/$LOCK_FILE")
  [ "$plugin_count" -gt 0 ]
}

backup_count() {
  find "$HOME" -maxdepth 3 -name '*.bak.*' | wc -l | tr -d ' '
}

run_checks() {
  local repo=$1
  local tool
  for tool in tmux nvim rg fd lazygit node npm git cc; do
    check "$tool 可执行" command -v "$tool"
  done
  check "Neovim >= $NVIM_MIN_VERSION" nvim_is_new_enough
  check "Node.js >= 18" node_is_new_enough
  check ".tmux.conf 软链到仓库" test "$(readlink "$HOME/.tmux.conf")" = "$repo/tmux/tmux.conf"
  check ".config/nvim 软链到仓库" test "$(readlink "$HOME/.config/nvim")" = "$repo/nvim-for-macmini"
  check "tmux 配置加载无报错" tmux_config_loads
  check "所有插件已安装且与 lazy-lock.json 一致" plugins_match_lockfile "$repo"
  plugins_match_lockfile "$repo" >/dev/null || true # 失败时打印是哪个插件
  check "nvim 无头启动正常退出" nvim --headless +qa
  check "tree-sitter CLI 可运行" tree-sitter --version
  check "lazy-lock.json 未被改动" cmp "$SRC_MOUNT/$LOCK_FILE" "$repo/$LOCK_FILE"
  diff "$SRC_MOUNT/$LOCK_FILE" "$repo/$LOCK_FILE" || true
}

run_inside() {
  if [ -n "${TEST_USER:-}" ] && [ "$(id -u)" -eq 0 ]; then
    switch_to_test_user "$TEST_USER"
  fi

  local repo="$HOME/customization_config"
  cp -r "$SRC_MOUNT" "$repo"
  echo "# 原有配置" >"$HOME/.tmux.conf" # 用来验证备份逻辑

  echo "--- 第一次安装"
  bash "$repo/install.sh"
  run_checks "$repo"
  check "原有 .tmux.conf 被备份(恰好 1 个备份)" test "$(backup_count)" -eq 1

  echo "--- 第二次安装(幂等性)"
  bash "$repo/install.sh"
  run_checks "$repo"
  check "重复执行没有产生新备份" test "$(backup_count)" -eq 1

  echo "--- 未知参数应报错"
  check "未知参数返回非零" bash -c "! bash '$repo/install.sh' --bogus"

  if [ "$FAILURES" -gt 0 ]; then
    echo "### $FAILURES 项检查失败"
    exit 1
  fi
  echo "### 全部通过"
}

main() {
  if [ "${1:-}" = "--inside" ]; then
    run_inside
  else
    run_container "$@"
  fi
}

main "$@"
