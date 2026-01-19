return {
  -- 1. Mason: 语言服务器安装器 (LSP 的 App Store)
  {
    "williamboman/mason.nvim",
    cmd = "Mason",
    keys = { { "<leader>cm", "<cmd>Mason<cr>", desc = "Mason" } },
    config = true, -- 启动时自动 setup
  },

  -- 2. LSP Config: 连接 Neovim 和语言服务器
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "williamboman/mason-lspconfig.nvim", -- 桥接 Mason 和 LSPConfig
      "hrsh7th/cmp-nvim-lsp",              -- 让 LSP 支持补全
      { "folke/neodev.nvim", opts = {} },  -- 让你写 Neovim 配置时有补全 (vim.xxx)
    },
    config = function()
      -- 自动安装语言服务器（Mason 已经通过 config = true 自动 setup，这里不需要重复调用）
      require("mason-lspconfig").setup({
        -- 确保安装 Lua 和 Python 服务器 (你可以根据需要加 "clangd" 等)
        ensure_installed = { "lua_ls", "pyright" }, 
        
        -- 自动配置所有通过 Mason 安装的服务器
        handlers = {
          function(server_name)
            require("lspconfig")[server_name].setup({
              -- 将补全能力传给 LSP
              capabilities = require("cmp_nvim_lsp").default_capabilities(),
            })
          end,
        },
      })

      -- 全局快捷键：当 LSP 启动时生效
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("UserLspConfig", {}),
        callback = function(ev)
          local opts = { buffer = ev.buf }
          -- gd: 跳转到定义 (Go to Definition)
          vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
          -- K: 查看文档 (Hover)
          vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
          -- <leader>rn: 重命名变量 (Rename)
          vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
          -- <leader>ca: 代码操作 (Code Action, 比如自动修复)
          vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts)
          -- 诊断相关快捷键
          vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
          vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
          vim.keymap.set("n", "<leader>d", vim.diagnostic.open_float, opts)
        end,
      })
    end,
  },

  -- 3. CMP: 自动补全引擎 (那个弹出的列表)
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-buffer", -- 补全当前文件内容的单词
      "hrsh7th/cmp-path",   -- 补全文件路径
      "L3MON4D3/LuaSnip",   -- 代码片段引擎
      "saadparwaiz1/cmp_luasnip",
      "rafamadriz/friendly-snippets", -- 常见代码片段库
      "onsails/lspkind.nvim", -- 给补全菜单加图标
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")
      require("luasnip.loaders.from_vscode").lazy_load()

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        -- 补全源优先级
        sources = cmp.config.sources({
          { name = "nvim_lsp" }, -- 优先显示 LSP 推荐
          { name = "luasnip" },  -- 其次是代码片段
          { name = "buffer" },   -- 最后是当前文件单词
          { name = "path" },     -- 路径补全
        }),
        -- 快捷键设置
        mapping = cmp.mapping.preset.insert({
          ["<C-k>"] = cmp.mapping.select_prev_item(), -- 上一个建议
          ["<C-j>"] = cmp.mapping.select_next_item(), -- 下一个建议
          ["<CR>"] = cmp.mapping.confirm({ select = true }), -- 回车确认
          ["<Tab>"] = cmp.mapping.select_next_item(), -- Tab 也可以选下一个
        }),
        -- 界面美化
        formatting = {
          format = require("lspkind").cmp_format({
            mode = "symbol", -- 显示图标
            maxwidth = 50,
          }),
        },
      })
    end,
  },
}
