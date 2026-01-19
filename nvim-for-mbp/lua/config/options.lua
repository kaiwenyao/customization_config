-- 设置 Leader 键为空格 (非常重要！后续很多插件快捷键都依赖它)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- 界面显示
vim.opt.number = true          -- 显示行号
vim.opt.relativenumber = true  -- 显示相对行号 (方便跳转，比如 '5j' 向下跳5行)
vim.opt.cursorline = true      -- 高亮当前行
vim.opt.termguicolors = true   -- 开启真彩色支持
vim.opt.signcolumn = "yes"     -- 始终显示左侧符号列 (防止错误提示出现时文字抖动)

-- 缩进与排版 (默认为 2 个空格，适合 Lua/Web 开发)
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true       -- 将 Tab 转为空格
vim.opt.smartindent = true     -- 智能缩进
vim.opt.wrap = false           -- 禁止自动换行 (代码太长时左右滚动)

-- 搜索体验
vim.opt.ignorecase = true      -- 搜索忽略大小写
vim.opt.smartcase = true       -- 如果输入了由大写字母，则自动区分大小写

-- 系统交互
vim.opt.mouse = "a"            -- 允许鼠标点击和滚动
vim.opt.clipboard = "unnamedplus" -- 关键：打通 macOS 系统剪贴板 (Ctrl+C/V 互通)

-- 分屏行为
vim.opt.splitright = true      -- 竖直分屏时，新窗口在右边
vim.opt.splitbelow = true      -- 水平分屏时，新窗口在下边
