-- 基础快捷键配置
local keymap = vim.keymap

-- 取消高亮搜索
keymap.set("n", "<leader>nh", ":nohl<CR>", { desc = "Clear highlights" })

-- 保存文件
keymap.set("n", "<leader>w", ":w<CR>", { desc = "Save file" })

-- 退出
keymap.set("n", "<leader>q", ":q<CR>", { desc = "Quit" })

-- 窗口导航（使用 Ctrl + hjkl）
keymap.set("n", "<C-h>", "<C-w>h", { desc = "Go to left window" })
keymap.set("n", "<C-j>", "<C-w>j", { desc = "Go to bottom window" })
keymap.set("n", "<C-k>", "<C-w>k", { desc = "Go to top window" })
keymap.set("n", "<C-l>", "<C-w>l", { desc = "Go to right window" })

-- 调整窗口大小
keymap.set("n", "<C-Up>", ":resize -2<CR>", { desc = "Resize window up" })
keymap.set("n", "<C-Down>", ":resize +2<CR>", { desc = "Resize window down" })
keymap.set("n", "<C-Left>", ":vertical resize -2<CR>", { desc = "Resize window left" })
keymap.set("n", "<C-Right>", ":vertical resize +2<CR>", { desc = "Resize window right" })

-- 移动当前行（在可视模式下）
keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move line down" })
keymap.set("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move line up" })

-- 保持光标位置不变时向下滚动
keymap.set("n", "J", "mzJ`z")

-- 半页滚动时保持光标在中间
keymap.set("n", "<C-d>", "<C-d>zz")
keymap.set("n", "<C-u>", "<C-u>zz")

-- 搜索时保持光标在中间
keymap.set("n", "n", "nzzzv")
keymap.set("n", "N", "Nzzzv")

-- 删除到系统剪贴板（macOS）
keymap.set("n", "<leader>d", '"_d', { desc = "Delete without yank" })
keymap.set("v", "<leader>d", '"_d', { desc = "Delete without yank" })

-- 复制到系统剪贴板
keymap.set("n", "<leader>y", '"+y', { desc = "Yank to clipboard" })
keymap.set("v", "<leader>y", '"+y', { desc = "Yank to clipboard" })
keymap.set("n", "<leader>Y", '"+Y', { desc = "Yank line to clipboard" })
