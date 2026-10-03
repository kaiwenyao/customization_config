# customization_config

个人开发环境配置:tmux、Neovim、Vim。

| 路径 | 内容 | 应用到本地的位置 |
|---|---|---|
| `tmux/tmux.conf` | tmux 配置 | `~/.tmux.conf` |
| `nvim-for-macmini/` | Neovim 配置(基于 LazyVim) | `~/.config/nvim` |
| `config_of_vim` | 旧的 Vim 配置 | `~/.vimrc` |
| `install.sh` | Debian / Ubuntu 一键安装脚本 | — |

## Linux 一键安装(Debian / Ubuntu)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/kaiwenyao/customization_config/master/install.sh)
```

root 或带 sudo 的普通用户都可以执行(普通用户请直接执行,不要在前面加 `sudo`,脚本会在需要时自己调用),支持 x86_64 和 arm64。脚本会:

- 用 apt 安装 tmux、git、ripgrep、fd、编译器、python3-venv 等依赖
- 把 Neovim 官方最新版装到 `/opt/nvim`(apt 里的版本低于 LazyVim 的要求),Node.js 官方二进制装到 `/opt/node`,lazygit 和 tree-sitter CLI 装到 `/usr/local/bin`
- 把仓库克隆到 `~/customization_config`,并软链 `~/.tmux.conf` 和 `~/.config/nvim`
- 按 `lazy-lock.json` 无头安装 Neovim 插件

官方预编译的 tree-sitter CLI 要求 glibc 2.39(Ubuntu 24.04、Debian 13 及以上)。在更旧的系统上(Ubuntu 22.04、Debian 12),脚本会用临时的 Rust 工具链从源码编译它,多花几分钟,编译完工具链即删除。

已有的配置不会被删除,而是改名为 `<原路径>.bak.<时间戳>`。脚本可以重复执行,已经装好的部分会跳过。

装完后执行 `nvim`,首次启动还会继续安装 LSP(Mason)和语法解析器,等它装完后重启一次。图标需要在**本地终端**里启用一个 [Nerd Font](https://www.nerdfonts.com/)。

可选参数加在命令末尾:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/kaiwenyao/customization_config/master/install.sh) --with-java
```

| 参数 | 作用 |
|---|---|
| `--with-java` | 额外安装 JDK 21(Java LSP 需要,体积较大所以默认不装) |
| `--no-sync` | 跳过无头安装插件,留到首次打开 `nvim` 时再装 |

环境变量 `CUSTOMIZATION_CONFIG_DIR` 可以改变仓库的克隆位置。

改动脚本后,可以在容器里端到端验证(需要 Docker):

```bash
tests/docker-test.sh ubuntu:24.04
```

下面是 macOS 上的手动步骤。

## 拉取仓库

```bash
git clone https://github.com/kaiwenyao/customization_config.git ~/customization_config
cd ~/customization_config
```

下面的命令都假设当前目录是仓库根目录。配置用软链接的方式应用,这样本地改动直接落在仓库里,`git pull` 之后也立即生效。

## tmux

### 安装

```bash
brew install tmux
```

### 应用配置

```bash
[ -e ~/.tmux.conf ] && mv ~/.tmux.conf ~/.tmux.conf.bak
ln -s "$PWD/tmux/tmux.conf" ~/.tmux.conf
```

新开的 tmux 会自动加载。如果 tmux 已经在运行,执行一次:

```bash
tmux source-file ~/.tmux.conf
```

### 配置内容

- 前缀键改为 `Ctrl-a`(连按两次把 `Ctrl-a` 发给 shell)
- 开启鼠标:滚动、点选窗格、拖拽调整大小
- 回滚历史 50000 行
- `escape-time` 降到 10ms,避免 Neovim 里按 `Esc` 卡顿
- 窗口和窗格从 1 开始编号,关闭窗口后自动重新编号
- 真彩色(`tmux-256color` + RGB)
- 分屏和新窗口沿用当前目录
- 复制模式使用 vi 键位,复制内容进入系统剪贴板(macOS 和 Linux 通用)

### 常用键位

都先按前缀键 `Ctrl-a`:

| 按键 | 作用 |
|---|---|
| `\|` | 左右分屏 |
| `-` | 上下分屏 |
| `h` `j` `k` `l` | 切换到左 / 下 / 上 / 右窗格 |
| `c` | 新窗口 |
| `[` | 进入复制模式,`v` 开始选择,`y` 复制 |
| `r` | 重载配置 |

开启鼠标后,终端自带的拖选会被 tmux 接管,拖选结束即复制到系统剪贴板。

复制到剪贴板有两条路,配置会自动选择:

- 本机有剪贴板工具时直接调用:macOS 用 `pbcopy`,Linux 桌面用 `wl-copy`(Wayland)或 `xclip`(X11)
- 同时开启 OSC 52(`set-clipboard on`):通过 SSH 连到没有桌面的服务器时,复制内容会经终端传回本地剪贴板。这需要终端支持 OSC 52,比如 iTerm2、kitty、WezTerm、Ghostty、Windows Terminal

## Neovim

配置基于 [LazyVim](https://www.lazyvim.org/),目录名是 `nvim-for-macmini`。

### 依赖

```bash
brew install neovim git ripgrep fd lazygit
```

另外需要:

- 一个 [Nerd Font](https://www.nerdfonts.com/) 并在终端里启用,否则图标显示为乱码
- C 编译器(macOS 上执行 `xcode-select --install`),nvim-treesitter 编译语法解析器时要用
- Node.js、JDK、Python:对应语言的 LSP 需要,只装自己用得到的即可

### 应用配置

```bash
[ -e ~/.config/nvim ] && mv ~/.config/nvim ~/.config/nvim.bak
mkdir -p ~/.config
ln -s "$PWD/nvim-for-macmini" ~/.config/nvim
```

如果之前用过别的 Neovim 配置,建议同时清掉旧的插件和缓存,避免冲突:

```bash
mv ~/.local/share/nvim ~/.local/share/nvim.bak
mv ~/.local/state/nvim ~/.local/state/nvim.bak
mv ~/.cache/nvim ~/.cache/nvim.bak
```

然后启动 `nvim`。首次启动会自动安装 lazy.nvim 和所有插件,等它装完后重启一次。

要让插件版本和仓库里的 `lazy-lock.json` 完全一致,在 Neovim 里执行:

```vim
:Lazy restore
```

装完后可以用 `:checkhealth` 检查缺少的依赖。

### 配置内容

- 配色:Catppuccin Latte(浅色,和 VS Code 主题保持一致),见 `lua/plugins/colorscheme.lua`
- 启用的 LazyVim extras(见 `lazyvim.json`):
  - 语言:Java、Python、TypeScript、Docker、JSON、Markdown
  - 编辑器:mini-files 文件浏览
  - 工具:project 项目切换
- Java 用 `google-java-format` 格式化,见 `lua/plugins/conform.lua`。如果没有自动装上,在 Neovim 里执行 `:MasonInstall google-java-format`
- `lua/config/` 下的 `options.lua`、`keymaps.lua`、`autocmds.lua` 目前是空的,用的都是 LazyVim 默认值

### 更新插件

在 Neovim 里执行 `:Lazy sync`,它会更新 `lazy-lock.json`。因为是软链接,改动直接出现在仓库里,提交即可:

```bash
git add nvim-for-macmini/lazy-lock.json
git commit -m "chore: update lazy-lock"
git push
```

## Vim

`config_of_vim` 是一份旧的 `.vimrc`,不依赖任何插件:

```bash
[ -e ~/.vimrc ] && mv ~/.vimrc ~/.vimrc.bak
ln -s "$PWD/config_of_vim" ~/.vimrc
```

## 同步更新

```bash
cd ~/customization_config
git pull
```

用软链接应用的配置在 `git pull` 后直接生效:tmux 按 `Ctrl-a` 再按 `r` 重载,Neovim 重启即可。
