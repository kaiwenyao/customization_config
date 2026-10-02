#!/usr/bin/env bash
# Debian / Ubuntu 一键安装:tmux + Neovim(LazyVim)及本仓库的配置。
#
#   bash <(curl -Ls https://raw.githubusercontent.com/kaiwenyao/customization_config/master/install.sh)
#
# 可重复执行;已有的配置会被改名备份,不会被删除。

set -Eeuo pipefail

readonly REPO_URL="https://github.com/kaiwenyao/customization_config.git"
readonly REPO_DIR="${CUSTOMIZATION_CONFIG_DIR:-$HOME/customization_config}"
readonly NVIM_CONFIG_NAME="nvim-for-macmini"
readonly TMUX_CONFIG_PATH="tmux/tmux.conf"

readonly NVIM_MIN_VERSION="0.11.2" # LazyVim 15.x 的最低要求
readonly TMUX_MIN_VERSION="3.2"    # terminal-features / copy-command 需要
readonly NODE_MIN_MAJOR=18
readonly NODE_CHANNEL="latest-v22.x"
readonly JDK_PACKAGE="openjdk-21-jdk-headless" # jdtls 需要 JDK 21+
readonly JDK_FALLBACK_PACKAGE="default-jdk-headless"
readonly PLUGIN_SYNC_TIMEOUT_SECONDS=900
readonly PLUGIN_RESTORE_MAX_ATTEMPTS=3

readonly OPT_DIR="/opt"
readonly BIN_DIR="/usr/local/bin"
readonly NVIM_RELEASE_URL="https://github.com/neovim/neovim/releases/latest/download"
readonly LAZYGIT_RELEASE_URL="https://github.com/jesseduffield/lazygit/releases"
readonly NODE_DIST_URL="https://nodejs.org/dist"
readonly TREE_SITTER_RELEASE_URL="https://github.com/tree-sitter/tree-sitter/releases/latest/download"
readonly TREE_SITTER_PREBUILT_MIN_GLIBC="2.39" # 官方预编译的 tree-sitter CLI 的最低 glibc
readonly RUSTUP_URL="https://sh.rustup.rs"

readonly APT_PACKAGES=(
  git curl ca-certificates tar gzip unzip
  build-essential
  tmux ripgrep fd-find
  python3 python3-venv python3-pip
)

BACKUP_SUFFIX=".bak.$(date +%Y%m%d-%H%M%S)"
readonly BACKUP_SUFFIX

WITH_JAVA=0
SHOULD_SYNC_PLUGINS=1
ARCH=""     # x86_64 | arm64(Neovim、lazygit 的命名)
ALT_ARCH="" # x64 | arm64(Node.js、tree-sitter 的命名)
TMP_DIR=""
BACKUPS=()

# --- 输出 ---

log() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[警告]\033[0m %s\n' "$*" >&2; }
die() {
  printf '\033[1;31m[错误]\033[0m %s\n' "$*" >&2
  exit 1
}

on_error() {
  local exit_code=$? line=$1 failed_command=$2
  printf '\033[1;31m[错误]\033[0m 第 %s 行执行失败(退出码 %s):%s\n' \
    "$line" "$exit_code" "$failed_command" >&2
}

cleanup() {
  if [ -n "$TMP_DIR" ]; then rm -rf "$TMP_DIR"; fi
}

usage() {
  cat <<'EOF'
用法: install.sh [选项]

在 Debian / Ubuntu 上安装 tmux、Neovim(LazyVim)并应用本仓库的配置。

选项:
  --with-java   额外安装 JDK(Java LSP jdtls 需要)
  --no-sync     跳过无头安装 Neovim 插件(首次打开 nvim 时再装)
  -h, --help    显示本帮助

环境变量:
  CUSTOMIZATION_CONFIG_DIR   仓库克隆位置,默认 ~/customization_config
EOF
}

# --- 小工具 ---

has() { command -v "$1" >/dev/null 2>&1; }

as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

# version_ge A B:A >= B 时返回 0
version_ge() {
  [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]
}

download() {
  local url=$1 dest=$2
  curl -fsSL --retry 3 --retry-delay 2 -o "$dest" "$url" || die "下载失败:$url"
}

apt_install() {
  as_root env DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends "$@"
}

nvim_version() {
  nvim --version 2>/dev/null | head -n1 | sed -E 's/^NVIM v([0-9.]+).*/\1/'
}

tmux_version() {
  tmux -V 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -n1
}

node_is_new_enough() {
  has node || return 1
  local major
  major="$(node --version 2>/dev/null | sed -nE 's/^v([0-9]+).*/\1/p')"
  [ "${major:-0}" -ge "$NODE_MIN_MAJOR" ]
}

# --- 步骤 ---

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --with-java) WITH_JAVA=1 ;;
      --no-sync) SHOULD_SYNC_PLUGINS=0 ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        usage >&2
        die "未知参数:$1"
        ;;
    esac
    shift
  done
}

detect_platform() {
  [ "$(uname -s)" = "Linux" ] || die "本脚本只支持 Linux;macOS 请按 README 手动配置。"
  [ -r /etc/os-release ] || die "找不到 /etc/os-release,无法识别发行版。"

  local os_ids
  # shellcheck disable=SC1091
  os_ids="$(. /etc/os-release && echo "${ID:-} ${ID_LIKE:-}")"
  case " $os_ids " in
    *" debian "* | *" ubuntu "*) ;;
    *) die "只支持 Debian / Ubuntu 系发行版,当前是:$os_ids" ;;
  esac
  has apt-get || die "找不到 apt-get。"

  case "$(uname -m)" in
    x86_64 | amd64)
      ARCH="x86_64"
      ALT_ARCH="x64"
      ;;
    aarch64 | arm64)
      ARCH="arm64"
      ALT_ARCH="arm64"
      ;;
    *) die "不支持的 CPU 架构:$(uname -m)(只支持 x86_64 和 arm64)" ;;
  esac
}

check_privileges() {
  [ "$(id -u)" -eq 0 ] && return 0
  has sudo || die "当前不是 root 且没有 sudo,请用 root 执行或先安装 sudo。"
  log "需要 sudo 权限来安装软件包"
  sudo -v || die "获取 sudo 权限失败。"
}

install_apt_packages() {
  log "安装系统软件包"
  as_root apt-get update || warn "apt-get update 有报错,继续尝试安装。"
  apt_install "${APT_PACKAGES[@]}" || die "apt 安装软件包失败,请检查网络和软件源后重试。"
}

install_node_from_tarball() {
  local base_url="$NODE_DIST_URL/$NODE_CHANNEL"
  local sums_file="$TMP_DIR/node-SHASUMS256.txt"
  download "$base_url/SHASUMS256.txt" "$sums_file"

  local checksum_line tarball
  checksum_line="$(grep -E "  node-v[0-9.]+-linux-${ALT_ARCH}\.tar\.gz\$" "$sums_file" | head -n1)" ||
    die "在 Node.js 发布列表里找不到 linux-${ALT_ARCH} 的安装包。"
  tarball="${checksum_line##* }"

  download "$base_url/$tarball" "$TMP_DIR/$tarball"
  (cd "$TMP_DIR" && echo "$checksum_line" | sha256sum -c - >/dev/null) ||
    die "Node.js 安装包校验失败:$tarball"

  as_root rm -rf "$OPT_DIR/node"
  as_root mkdir -p "$OPT_DIR/node"
  as_root tar -xzf "$TMP_DIR/$tarball" -C "$OPT_DIR/node" --strip-components=1
  local tool
  for tool in node npm npx; do
    as_root ln -sfn "$OPT_DIR/node/bin/$tool" "$BIN_DIR/$tool"
  done
  hash -r
}

ensure_node() {
  if node_is_new_enough; then
    log "Node.js $(node --version) 已满足要求,跳过"
    return 0
  fi

  # 不用 apt:Ubuntu 22.04 的版本太旧,而且 npm 包会带进来几百个 node-* 依赖。
  log "安装 Node.js 官方二进制($NODE_CHANNEL)到 $OPT_DIR/node"
  install_node_from_tarball

  node_is_new_enough ||
    die "Node.js 安装后版本仍不满足 >= $NODE_MIN_MAJOR,请检查 PATH 里是否有旧版本。"
}

install_java() {
  [ "$WITH_JAVA" -eq 1 ] || return 0
  if apt-cache show "$JDK_PACKAGE" >/dev/null 2>&1; then
    log "安装 $JDK_PACKAGE"
    apt_install "$JDK_PACKAGE"
  else
    warn "软件源里没有 $JDK_PACKAGE,改装 $JDK_FALLBACK_PACKAGE;jdtls 需要 JDK 21+,版本不够时 Java LSP 无法启动。"
    apt_install "$JDK_FALLBACK_PACKAGE"
  fi
}

install_neovim() {
  if has nvim && version_ge "$(nvim_version)" "$NVIM_MIN_VERSION"; then
    log "Neovim $(nvim_version) 已满足要求,跳过"
    return 0
  fi

  log "安装 Neovim 官方最新版到 $OPT_DIR/nvim(apt 里的版本低于 LazyVim 要求的 $NVIM_MIN_VERSION)"
  local tarball="nvim-linux-${ARCH}.tar.gz"
  download "$NVIM_RELEASE_URL/$tarball" "$TMP_DIR/$tarball"

  as_root rm -rf "$OPT_DIR/nvim"
  as_root mkdir -p "$OPT_DIR/nvim"
  as_root tar -xzf "$TMP_DIR/$tarball" -C "$OPT_DIR/nvim" --strip-components=1
  as_root ln -sfn "$OPT_DIR/nvim/bin/nvim" "$BIN_DIR/nvim"
  hash -r

  "$BIN_DIR/nvim" --version >/dev/null 2>&1 ||
    die "Neovim 无法运行,多半是系统 glibc 太旧。可改用 https://github.com/neovim/neovim-releases 的兼容构建。"
  version_ge "$(nvim_version)" "$NVIM_MIN_VERSION" ||
    die "PATH 里的 nvim 仍是旧版本($(command -v nvim)),请卸载它或把 $BIN_DIR 放到 PATH 前面。"
}

# lazygit 只是 LazyVim 的可选集成,失败时只警告。
install_lazygit() {
  if has lazygit; then
    log "lazygit 已安装,跳过"
    return 0
  fi

  log "安装 lazygit"
  local latest_url tag version tarball
  latest_url="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "$LAZYGIT_RELEASE_URL/latest")" || return 1
  tag="${latest_url##*/}"
  version="${tag#v}"
  [[ "$version" =~ ^[0-9]+(\.[0-9]+)+$ ]] || return 1
  tarball="lazygit_${version}_linux_${ARCH}.tar.gz"

  curl -fsSL --retry 3 -o "$TMP_DIR/$tarball" "$LAZYGIT_RELEASE_URL/download/$tag/$tarball" || return 1
  curl -fsSL --retry 3 -o "$TMP_DIR/lazygit-checksums.txt" "$LAZYGIT_RELEASE_URL/download/$tag/checksums.txt" || return 1
  (cd "$TMP_DIR" && grep "  $tarball\$" lazygit-checksums.txt | sha256sum -c - >/dev/null) || return 1

  tar -xzf "$TMP_DIR/$tarball" -C "$TMP_DIR" lazygit || return 1
  as_root install -m 0755 "$TMP_DIR/lazygit" "$BIN_DIR/lazygit" || return 1
}

install_tree_sitter_prebuilt() {
  local archive="$TMP_DIR/tree-sitter.gz"
  curl -fsSL --retry 3 -o "$archive" "$TREE_SITTER_RELEASE_URL/tree-sitter-linux-${ALT_ARCH}.gz" || return 1
  gunzip -f "$archive" || return 1
  as_root install -m 0755 "$TMP_DIR/tree-sitter" "$BIN_DIR/tree-sitter" || return 1
}

# 用装在临时目录里的 Rust 工具链编译,脚本退出时随 TMP_DIR 一起删掉。
build_tree_sitter_from_source() {
  local rust_dir="$TMP_DIR/rust" out_dir="$TMP_DIR/tree-sitter-build"
  curl -fsSL --retry 3 -o "$TMP_DIR/rustup-init.sh" "$RUSTUP_URL" || return 1
  RUSTUP_HOME="$rust_dir/rustup" CARGO_HOME="$rust_dir/cargo" \
    sh "$TMP_DIR/rustup-init.sh" -y --profile minimal --no-modify-path >/dev/null || return 1
  RUSTUP_HOME="$rust_dir/rustup" CARGO_HOME="$rust_dir/cargo" \
    "$rust_dir/cargo/bin/cargo" install --locked --root "$out_dir" tree-sitter-cli || return 1
  as_root install -m 0755 "$out_dir/bin/tree-sitter" "$BIN_DIR/tree-sitter" || return 1
}

# nvim-treesitter 编译语法解析器要用 tree-sitter CLI。失败时只警告:Neovim 仍可用,只是没有语法高亮。
install_tree_sitter() {
  if has tree-sitter && tree-sitter --version >/dev/null 2>&1; then
    log "tree-sitter CLI 已安装,跳过"
    return 0
  fi

  local glibc
  glibc="$(getconf GNU_LIBC_VERSION 2>/dev/null | awk '{print $2}')"
  if version_ge "${glibc:-0}" "$TREE_SITTER_PREBUILT_MIN_GLIBC"; then
    log "安装 tree-sitter CLI"
    install_tree_sitter_prebuilt || return 1
  else
    log "系统 glibc ${glibc:-未知} 低于 $TREE_SITTER_PREBUILT_MIN_GLIBC,官方预编译的 tree-sitter CLI 跑不了,改为从源码编译(需要几分钟)"
    build_tree_sitter_from_source || return 1
  fi
  hash -r
  tree-sitter --version >/dev/null 2>&1 || return 1
}

# Debian 系把 fd 装成 fdfind,LazyVim 找的是 fd。
link_fd() {
  has fd && return 0
  has fdfind || return 0
  as_root ln -sfn "$(command -v fdfind)" "$BIN_DIR/fd"
}

check_tmux_version() {
  local current
  current="$(tmux_version)"
  if ! version_ge "${current:-0}" "$TMUX_MIN_VERSION"; then
    warn "tmux ${current:-未知} 低于 $TMUX_MIN_VERSION,真彩色和剪贴板相关配置会报错,建议升级系统。"
  fi
}

sync_repo() {
  if [ -d "$REPO_DIR/.git" ]; then
    log "更新已有仓库 $REPO_DIR"
    git -C "$REPO_DIR" pull --ff-only ||
      warn "git pull 失败(可能有本地改动或不在 master 分支),继续使用当前内容。"
  elif [ -e "$REPO_DIR" ]; then
    die "$REPO_DIR 已存在但不是 git 仓库。请移走它,或用 CUSTOMIZATION_CONFIG_DIR 指定别的位置。"
  else
    log "克隆仓库到 $REPO_DIR"
    git clone "$REPO_URL" "$REPO_DIR"
  fi

  [ -f "$REPO_DIR/$TMUX_CONFIG_PATH" ] || die "仓库里缺少 $TMUX_CONFIG_PATH"
  [ -d "$REPO_DIR/$NVIM_CONFIG_NAME" ] || die "仓库里缺少 $NVIM_CONFIG_NAME/"
}

is_linked_to() {
  local src=$1 dest=$2
  [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]
}

backup_path() {
  local path=$1
  [ -e "$path" ] || [ -L "$path" ] || return 0
  mv "$path" "$path$BACKUP_SUFFIX"
  BACKUPS+=("$path$BACKUP_SUFFIX")
}

link_config() {
  local src=$1 dest=$2
  if is_linked_to "$src" "$dest"; then
    log "$dest 已指向仓库,跳过"
    return 0
  fi
  backup_path "$dest"
  mkdir -p "$(dirname "$dest")"
  ln -s "$src" "$dest"
  log "$dest -> $src"
}

apply_configs() {
  local repo_root
  repo_root="$(cd "$REPO_DIR" && pwd)"
  local nvim_src="$repo_root/$NVIM_CONFIG_NAME"
  local nvim_dest="$HOME/.config/nvim"

  link_config "$repo_root/$TMUX_CONFIG_PATH" "$HOME/.tmux.conf"

  # 换掉别的 Neovim 配置时,旧插件和缓存一并备份,避免冲突。
  if [ -e "$nvim_dest" ] && ! is_linked_to "$nvim_src" "$nvim_dest"; then
    backup_path "$HOME/.local/share/nvim"
    backup_path "$HOME/.local/state/nvim"
    backup_path "$HOME/.cache/nvim"
  fi
  link_config "$nvim_src" "$nvim_dest"
}

# 打印没有检出到锁文件所记提交的插件名,每行一个。
unpinned_plugins() {
  local lock_file=$1 name locked actual
  local lazy_dir="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy"
  while read -r name locked; do
    actual="$(git -C "$lazy_dir/$name" rev-parse HEAD 2>/dev/null)" || actual=""
    [ "$actual" = "$locked" ] || echo "$name"
  done < <(sed -nE 's/^ *"([^"]+)": \{.*"commit": "([0-9a-f]+)".*/\1 \2/p' "$lock_file")
}

run_nvim_headless() {
  timeout "$PLUGIN_SYNC_TIMEOUT_SECONDS" nvim --headless "$@" +qa >>"$TMP_DIR/nvim-sync.log" 2>&1
}

sync_plugins() {
  [ "$SHOULD_SYNC_PLUGINS" -eq 1 ] || return 0
  local lock_file="$REPO_DIR/$NVIM_CONFIG_NAME/lazy-lock.json"
  local pinned_lock="$TMP_DIR/lazy-lock.json"
  if [ ! -f "$lock_file" ]; then
    warn "找不到 $lock_file,跳过无头安装插件。"
    return 0
  fi

  if [ -z "$(unpinned_plugins "$lock_file")" ]; then
    log "Neovim 插件已是 lazy-lock.json 锁定的版本,跳过"
    return 0
  fi

  log "按 lazy-lock.json 安装 Neovim 插件(首次需要几分钟)"
  cp "$lock_file" "$pinned_lock"

  # lazy.nvim 首次启动分批安装,第一批装完就会改写锁文件,后面的插件拿到的是最新提交。
  # 所以第一遍只负责装齐,之后还原锁文件再 restore 到锁定的版本。
  run_nvim_headless || warn "首次无头启动 Neovim 异常退出,继续尝试恢复插件版本。"

  # 慢网络下个别插件的 git 任务会超时,而 nvim 仍然返回 0,所以自己核对并重试。
  local attempt remaining=""
  for attempt in $(seq 1 "$PLUGIN_RESTORE_MAX_ATTEMPTS"); do
    cp "$pinned_lock" "$lock_file"
    run_nvim_headless "+Lazy! restore" || true
    cp "$pinned_lock" "$lock_file"
    remaining="$(unpinned_plugins "$pinned_lock" | tr '\n' ' ')"
    [ -z "$remaining" ] && return 0
    log "第 $attempt/$PLUGIN_RESTORE_MAX_ATTEMPTS 次恢复后仍有插件不在锁定版本:$remaining"
  done

  warn "这些插件没能恢复到 lazy-lock.json 锁定的版本(多半是网络超时):$remaining"
  warn "配置仍然可用;网络好的时候在 nvim 里执行 :Lazy restore 即可。最后的输出:"
  tail -n 20 "$TMP_DIR/nvim-sync.log" >&2
}

reload_tmux() {
  tmux list-sessions >/dev/null 2>&1 || return 0
  tmux source-file "$HOME/.tmux.conf" || warn "重载 tmux 配置失败,请手动执行:tmux source-file ~/.tmux.conf"
}

print_summary() {
  echo
  log "完成"
  echo "  tmux    $(tmux -V 2>/dev/null)  ->  ~/.tmux.conf"
  echo "  Neovim  $(nvim_version)  ->  ~/.config/nvim"
  echo "  仓库    $REPO_DIR"
  if [ "${#BACKUPS[@]}" -gt 0 ]; then
    echo
    echo "原有配置已备份为:"
    printf '  %s\n' "${BACKUPS[@]}"
  fi
  cat <<'EOF'

接下来:
  - 执行 nvim。首次启动会继续安装 LSP(Mason)和语法解析器(treesitter),等它装完后重启一次。
  - 图标乱码时,在你本地的终端里装一个 Nerd Font 并启用:https://www.nerdfonts.com/
  - tmux 前缀键是 Ctrl-a;通过 SSH 复制到本地剪贴板依赖终端支持 OSC 52。
EOF
  if [ "$WITH_JAVA" -eq 0 ]; then
    echo "  - 需要 Java LSP 时,带 --with-java 重新执行本脚本。"
  fi
}

main() {
  parse_args "$@"
  detect_platform
  check_privileges

  TMP_DIR="$(mktemp -d)"
  trap cleanup EXIT
  trap 'on_error "$LINENO" "$BASH_COMMAND"' ERR

  install_apt_packages
  ensure_node
  install_java
  install_neovim
  install_lazygit || warn "lazygit 安装失败,已跳过(不影响 tmux 和 Neovim)。"
  install_tree_sitter || warn "tree-sitter CLI 安装失败,Neovim 的语法高亮会缺失;可稍后重新执行本脚本。"
  link_fd
  check_tmux_version

  sync_repo
  apply_configs
  sync_plugins
  reload_tmux
  print_summary
}

main "$@"
