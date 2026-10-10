vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.o.number = true
vim.o.relativenumber = true
vim.o.wrap = true
vim.o.linebreak = true
vim.o.swapfile = false
vim.o.showtabline = 0
vim.o.winborder = "rounded"
vim.o.scrolloff = 3
vim.o.timeoutlen = 250

vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.signcolumn = "yes"
vim.opt.clipboard = "unnamedplus"
vim.opt.autoread = true
vim.opt.cursorline = true
vim.opt.cursorlineopt = "number"
vim.api.nvim_set_hl(0, "CursorLineNr", { fg = "#ffffff", bg = "none", bold = true })
vim.opt.conceallevel = 2
vim.opt.concealcursor = "nc"
vim.opt.completeopt:append("noselect")

vim.diagnostic.config({
  virtual_text = {
    spacing = 2,
    prefix = "●",
  },
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
})

local map = vim.keymap.set

function _G.markdown_foldexpr(lnum)
  local line = vim.fn.getline(lnum)
  if line:match("^#%S") or line:match("^#+%s") then
    local level = #line:match("^#+")
    return ">" .. level
  end
  return "="
end

local function toggle_markdown_checkbox()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
  if not line then
    return
  end

  local updated, count = line:gsub("^(%s*[-*+]%s+)%[([ xX])%](%s*)", function(prefix, mark, padding)
    local next_mark = mark:lower() == "x" and " " or "x"
    return prefix .. "[" .. next_mark .. "]" .. (padding ~= "" and padding or " ")
  end, 1)

  if count == 0 then
    updated, count = line:gsub("^(%s*[-*+]%s+)%[%](%s*)", function(prefix, padding)
      return prefix .. "[x]" .. (padding ~= "" and padding or " ")
    end, 1)
  end

  if count == 0 then
    updated, count = line:gsub("^(%s*[-*+]%s+)(.*%S.*)$", "%1[x] %2", 1)
  end

  if count == 0 then
    updated = line:gsub("^(%s*)", "%1- [x] ", 1)
  end

  vim.api.nvim_buf_set_lines(0, row - 1, row, false, { updated })
end

local function markdown_list_text_col(line)
  local patterns = {
    "^%s*[-*+]%s+%[[ xX]%]%s*()",
    "^%s*[-*+]%s+%[%]%s*()",
    "^%s*[-*+]%s+()",
    "^%s*%d+[.)]%s+()",
  }

  for _, pattern in ipairs(patterns) do
    local pos = line:match(pattern)
    if pos then
      return pos - 1
    end
  end
end

local function snap_markdown_cursor_to_list_text(force)
  if vim.bo.filetype ~= "markdown" or vim.fn.mode() ~= "n" or vim.b.pi_snapping_markdown_cursor then
    return
  end

  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local previous_row = vim.b.pi_markdown_cursor_row
  vim.b.pi_markdown_cursor_row = row
  if not force and previous_row == row then
    return
  end

  local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
  local target_col = line and markdown_list_text_col(line)
  if not target_col or col >= target_col then
    return
  end

  vim.b.pi_snapping_markdown_cursor = true
  pcall(vim.api.nvim_win_set_cursor, 0, { row, target_col })
  vim.b.pi_snapping_markdown_cursor = false
end

local markdown_literal_strong_ns = vim.api.nvim_create_namespace("pi_markdown_literal_strong")

local function markdown_char_is_escaped(line, index)
  local backslashes = 0
  local cursor = index - 1
  while cursor >= 1 and line:sub(cursor, cursor) == "\\" do
    backslashes = backslashes + 1
    cursor = cursor - 1
  end
  return backslashes % 2 == 1
end

local function markdown_double_quote_ranges(line)
  local ranges = {}
  local open_quote
  local index = 1

  while index <= #line do
    if line:sub(index, index) == '"' and not markdown_char_is_escaped(line, index) then
      if open_quote then
        table.insert(ranges, { open_quote - 1, index - 1 })
        open_quote = nil
      else
        open_quote = index
      end
    end
    index = index + 1
  end

  if open_quote then
    table.insert(ranges, { open_quote - 1, #line })
  end

  return ranges
end

local function markdown_range_is_in_double_quotes(ranges, start_col, end_col)
  for _, range in ipairs(ranges) do
    if start_col > range[1] and end_col <= range[2] then
      return true
    end
  end
  return false
end

local function reveal_markdown_literal_strong_delimiters(buf, row, start_col, end_col, hl_group)
  vim.api.nvim_buf_set_extmark(buf, markdown_literal_strong_ns, row, start_col, {
    end_row = row,
    end_col = end_col,
    hl_group = hl_group,
    priority = 9999,
  })

  for col = start_col, start_col + 1 do
    vim.api.nvim_buf_set_extmark(buf, markdown_literal_strong_ns, row, col, {
      end_row = row,
      end_col = col + 1,
      conceal = "_",
      hl_group = hl_group,
      priority = 10000,
    })
  end

  for col = end_col - 2, end_col - 1 do
    vim.api.nvim_buf_set_extmark(buf, markdown_literal_strong_ns, row, col, {
      end_row = row,
      end_col = col + 1,
      conceal = "_",
      hl_group = hl_group,
      priority = 10000,
    })
  end
end

local function update_markdown_literal_strong()
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(buf, markdown_literal_strong_ns, 0, -1)

  if vim.bo[buf].filetype ~= "markdown" then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  for row, line in ipairs(lines) do
    local in_block_quote = line:match("^%s*>") ~= nil
    local quote_ranges = markdown_double_quote_ranges(line)
    local search_from = 1

    while true do
      local match_start, match_end = line:find("__[^_].-__", search_from)
      if not match_start then
        break
      end

      local start_col = match_start - 1
      local end_col = match_end
      local in_double_quotes = markdown_range_is_in_double_quotes(quote_ranges, start_col, end_col)

      if in_block_quote or in_double_quotes then
        local hl_group = in_block_quote and "PiMarkdownQuoteLiteralStrong" or "PiMarkdownLiteralStrong"
        reveal_markdown_literal_strong_delimiters(buf, row - 1, start_col, end_col, hl_group)
      end

      search_from = match_end + 1
    end
  end
end

map("n", "<leader>o", "<cmd>update<CR><cmd>source %<CR>", { desc = "Reload config" })
map("i", "jk", "<Esc>", { silent = true, desc = "Exit insert mode" })
map("n", "<Esc>", "<cmd>nohlsearch<CR>")
map("n", "<leader>r", vim.diagnostic.open_float, { silent = true, desc = "Show diagnostic" })
map("n", "<leader>lc", function()
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  if #clients == 0 then
    vim.notify("No LSP clients attached", vim.log.levels.INFO)
    return
  end
  local names = {}
  for _, client in ipairs(clients) do
    table.insert(names, client.name)
  end
  vim.notify(table.concat(names, ", "), vim.log.levels.INFO, { title = "LSP Clients" })
end, { silent = true, desc = "Show LSP clients" })

local function lsp_action(method, action, missing_message)
  return function()
    local clients = vim.lsp.get_clients({ bufnr = 0 })
    if #clients == 0 then
      vim.notify("No LSP clients attached", vim.log.levels.INFO)
      return
    end

    for _, client in ipairs(clients) do
      if client:supports_method(method) then
        action()
        return
      end
    end

    vim.notify(missing_message, vim.log.levels.INFO)
  end
end

map("n", "gd", lsp_action("textDocument/definition", vim.lsp.buf.definition, "LSP does not support definition here"), { desc = "Go to definition" })
map("n", "gD", lsp_action("textDocument/declaration", vim.lsp.buf.declaration, "LSP does not support declaration here"), { desc = "Go to declaration" })
map("n", "gi", lsp_action("textDocument/implementation", vim.lsp.buf.implementation, "LSP does not support implementation here"), { desc = "Go to implementation" })
map("n", "gt", lsp_action("textDocument/typeDefinition", vim.lsp.buf.type_definition, "LSP does not support type definition here"), { desc = "Go to type definition" })
map("n", "gr", lsp_action("textDocument/references", vim.lsp.buf.references, "LSP does not support references here"), { desc = "Show references" })
map("n", "N", lsp_action("textDocument/hover", vim.lsp.buf.hover, "LSP does not support hover here"), { desc = "Show hover documentation" })
map("n", "<leader>P", "<cmd>vsplit<CR>", { silent = true, desc = "Vertical split" })
pcall(vim.keymap.del, "n", "bd")
map("n", "<leader>bd", "<cmd>bd<CR>", { silent = true, desc = "Delete buffer" })

map("n", "<C-h>", "<C-w>h", { silent = true, desc = "Move to left window" })
map("n", "<C-j>", "<C-w>j", { silent = true, desc = "Move to lower window" })
map("n", "<C-k>", "<C-w>k", { silent = true, desc = "Move to upper window" })
map("n", "<C-l>", "<C-w>l", { silent = true, desc = "Move to right window" })

map("n", "<leader>w", function()
  if vim.t.pi_zoomed_tab then
    vim.cmd("tabclose")
  else
    vim.cmd("tab split")
    vim.t.pi_zoomed_tab = true
  end
end, { silent = true, desc = "Toggle zoom window" })

local function paragraph_jump(direction)
  vim.cmd("normal! " .. direction)

  local context = 3
  local view = vim.fn.winsaveview()
  local height = vim.api.nvim_win_get_height(0)
  local bottom = view.topline + height - 1

  if direction == "}" and view.lnum > bottom - context then
    view.topline = math.max(1, view.lnum - height + 1 + context)
    vim.fn.winrestview(view)
  elseif direction == "{" and view.lnum < view.topline + context then
    view.topline = math.max(1, view.lnum - context)
    vim.fn.winrestview(view)
  end
end

map("n", "J", function()
  paragraph_jump("}")
end, { desc = "Jump paragraph down with 3-line edge" })
map("n", "K", function()
  paragraph_jump("{")
end, { desc = "Jump paragraph up with 3-line edge" })
map("v", "J", "}", { desc = "Jump paragraph down" })
map("v", "K", "{", { desc = "Jump paragraph up" })
map("n", "<leader>x", toggle_markdown_checkbox, { desc = "Toggle markdown checkbox" })

pcall(vim.keymap.del, "n", "H")
pcall(vim.keymap.del, "n", "L")
map("n", "H", "<cmd>bprevious<CR>", { desc = "Previous buffer" })
map("n", "L", "<cmd>bnext<CR>", { desc = "Next buffer" })

local function get_project_root()
  local buf_path = vim.api.nvim_buf_get_name(0)
  local start = buf_path ~= "" and vim.fs.dirname(buf_path) or vim.fn.getcwd()
  local git_dir = vim.fs.find({ ".git" }, { upward = true, path = start })[1]
  return git_dir and vim.fs.dirname(git_dir) or start
end

local function toggle_terminal()
  local term_buf = vim.g.pi_terminal_buf

  if term_buf and vim.api.nvim_buf_is_valid(term_buf) and vim.bo[term_buf].buftype == "terminal" then
    local term_wins = {}
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(win) == term_buf then
        table.insert(term_wins, win)
      end
    end

    if #term_wins > 0 then
      for _, win in ipairs(term_wins) do
        vim.api.nvim_win_hide(win)
      end
      return
    end

    vim.cmd("botright split")
    vim.api.nvim_win_set_buf(0, term_buf)
    vim.cmd("startinsert")
    return
  end

  vim.cmd("botright split")
  vim.cmd("enew")

  local root = get_project_root()
  local shell = vim.o.shell
  local cmd = { shell, "-ic", "cd " .. vim.fn.shellescape(root) .. "; exec " .. vim.fn.shellescape(shell) .. " -i" }

  vim.fn.termopen(cmd)
  vim.g.pi_terminal_buf = vim.api.nvim_get_current_buf()
  vim.cmd("startinsert")
end

map({ "n", "t" }, "<C-_>", toggle_terminal, { silent = true, desc = "Toggle terminal" })
map({ "n", "t" }, "<C-/>", toggle_terminal, { silent = true, desc = "Toggle terminal" })
map("t", "<Esc>", function()
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)
end, { silent = true, desc = "Exit terminal mode" })

local function floating_terminal(cmd, opts)
  opts = opts or {}

  -- Let TUI popups use Ghostty's transparent terminal background.
  vim.api.nvim_set_hl(0, "PiFloatNormal", { bg = "none", fg = "#cdd6f4" })
  vim.api.nvim_set_hl(0, "PiFloatBorder", { bg = "none", fg = "#585b70" })

  local width = math.floor(vim.o.columns * (opts.width or 0.85))
  local height = math.floor(vim.o.lines * (opts.height or 0.85))
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
  })
  vim.wo[win].winhighlight = "Normal:PiFloatNormal,NormalFloat:PiFloatNormal,FloatBorder:PiFloatBorder"

  vim.fn.termopen(cmd, {
    cwd = opts.cwd or vim.fn.getcwd(),
    on_exit = function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end,
  })

  vim.cmd("startinsert")

  map("t", "<Esc>", [[<C-\><C-n>]], { buffer = buf, silent = true, desc = "Exit terminal mode" })
  map("n", "q", function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end, { buffer = buf, silent = true, desc = "Close popup" })
end

map("n", "<leader>gg", function()
  floating_terminal("lazygit")
end, { silent = true, desc = "Lazygit popup" })

-- plugins
vim.pack.add({
  -- { src = "https://github.com/vague2k/vague.nvim" },
  { src = "https://github.com/dgrco/monolith.nvim" },
  { src = "https://github.com/stevearc/oil.nvim" },
  { src = "https://github.com/lewis6991/gitsigns.nvim" },
  { src = "https://github.com/neovim/nvim-lspconfig" },
  { src = "https://github.com/chomosuke/typst-preview.nvim" },
  { src = "https://github.com/echasnovski/mini.pick" },
  { src = "https://github.com/nvim-treesitter/nvim-treesitter" },
  { src = "https://github.com/nvim-lua/plenary.nvim" },
  { src = "https://github.com/epwalsh/obsidian.nvim" },
  { src = "https://github.com/MeanderingProgrammer/render-markdown.nvim" },
  { src = "https://github.com/folke/snacks.nvim" },
  { src = "https://github.com/windwp/nvim-autopairs" },
  { src = "https://github.com/windwp/nvim-ts-autotag" },
  { src = "https://github.com/nvim-lualine/lualine.nvim" },
})

vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
  pattern = "*",
  command = "checktime",
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.opt_local.foldmethod = "expr"
    vim.opt_local.foldexpr = "v:lua.markdown_foldexpr(v:lnum)"
    vim.opt_local.foldlevel = 99
    vim.opt_local.foldlevelstart = 99
    vim.opt_local.concealcursor = ""
    -- Prose wraps unless an inline table is visible (managed below).
    vim.opt_local.wrap = true
    update_markdown_literal_strong()
  end,
})

-- 'wrap' is window-local: preserve inline tables by turning it off only
-- while a Markdown table intersects the viewport. Treesitter excludes pipes
-- inside fenced code blocks and ordinary prose.
local table_wrap_pending = false
local function update_markdown_table_wrap()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "markdown" then
      local visible_table = false
      vim.api.nvim_win_call(win, function()
        local top, bottom = vim.fn.line("w0") - 1, vim.fn.line("w$") - 1
        local ok, parser = pcall(vim.treesitter.get_parser, buf, "markdown")
        if ok and parser then
          local parsed, trees = pcall(function() return parser:parse() end)
          if parsed and trees then
            local query = vim.treesitter.query.parse("markdown", "(pipe_table) @table")
            for _, tree in ipairs(trees) do
              for _, node in query:iter_captures(tree:root(), buf, 0, -1) do
                local first, _, last, end_col = node:range()
                if end_col == 0 then last = last - 1 end
                if first <= bottom and last >= top then
                  for row = math.max(first, top), math.min(last, bottom) do
                    if vim.fn.foldclosed(row + 1) == -1 then
                      visible_table = true
                      break
                    end
                  end
                end
                if visible_table then break end
              end
              if visible_table then break end
            end
          end
        end
      end)
      if vim.wo[win].wrap == visible_table then
        vim.wo[win].wrap = not visible_table
      end
    end
  end
end
vim.api.nvim_create_autocmd({
  "FileType", "BufWinEnter", "WinEnter", "WinScrolled", "WinResized",
  "CursorMoved", "TextChanged", "TextChangedI", "InsertLeave",
}, {
  group = vim.api.nvim_create_augroup("PiMarkdownTableWrap", { clear = true }),
  callback = function()
    if table_wrap_pending then return end
    table_wrap_pending = true
    vim.schedule(function()
      table_wrap_pending = false
      update_markdown_table_wrap()
    end)
  end,
})

vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
  pattern = "*",
  callback = function()
    snap_markdown_cursor_to_list_text(true)
  end,
})

vim.api.nvim_create_autocmd({ "BufEnter", "TextChanged", "TextChangedI", "InsertLeave" }, {
  pattern = "*",
  callback = update_markdown_literal_strong,
})

vim.api.nvim_create_autocmd("CursorMoved", {
  pattern = "*",
  callback = function()
    snap_markdown_cursor_to_list_text(false)
  end,
})

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)

    vim.bo[ev.buf].omnifunc = "v:lua.vim.lsp.omnifunc"

    if client and client.name == "jdtls" then
      client.server_capabilities.semanticTokensProvider = nil
    end

    if client and client:supports_method("textDocument/completion") then
      vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })
    end

    local opts = { buffer = ev.buf }
    map("n", "<leader>rn", vim.lsp.buf.rename, opts)
    map("n", "<leader>ca", vim.lsp.buf.code_action, opts)
  end,
})

vim.cmd("packadd nvim-treesitter")

require("nvim-treesitter").setup({
  install_dir = vim.fn.stdpath("data") .. "/site",
})

pcall(function()
  require("nvim-treesitter").install({ "html", "javascript", "typescript", "tsx", "markdown", "markdown_inline", "latex", "python", "java", "bash", "sql", "lua", "yaml" })
end)

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "html", "javascript", "javascriptreact", "typescript", "typescriptreact", "markdown", "python", "xml", "vue", "svelte" },
  callback = function()
    pcall(vim.treesitter.start)
  end,
})

require("mini.pick").setup()
require("oil").setup()
local gitsigns = require("gitsigns")
if not vim.g.pi_gitsigns_setup then
  gitsigns.setup({
    signs = {
      add = { text = "+" },
      change = { text = "~" },
      delete = { text = "_" },
      topdelete = { text = "‾" },
      changedelete = { text = "~" },
      untracked = { text = "+" },
    },
  })
  vim.g.pi_gitsigns_setup = true
end
local npairs = require("nvim-autopairs")
local Rule = require("nvim-autopairs.rule")
local pair_cond = require("nvim-autopairs.conds")
npairs.setup({})
npairs.add_rule(Rule("*", "*", "markdown"):with_move(pair_cond.move_right()))
require("nvim-ts-autotag").setup({
  opts = {
    enable_close = true,
    enable_rename = true,
    enable_close_on_slash = false,
  },
})
require("render-markdown").setup({
  preset = "obsidian",
  file_types = { "markdown" },
  render_modes = { "n" },
  anti_conceal = {
    enabled = true,
  },
  heading = {
    position = "inline",
    backgrounds = {},
  },
  bullet = {
    icons = { "•" },
    right_pad = 1,
  },
  checkbox = {
    bullet = false,
    right_pad = 1,
    unchecked = { icon = "□ ", highlight = "RenderMarkdownUnchecked" },
    checked = { icon = "☑ ", highlight = "RenderMarkdownChecked" },
    custom = {
      empty = { raw = "[]", rendered = "□ ", highlight = "RenderMarkdownUnchecked" },
    },
  },
  quote = {
    icon = "▎",
    highlight = "RenderMarkdownQuote",
  },
  inline_highlight = {
    enabled = true,
    highlight = "RenderMarkdownInlineHighlight",
  },
  latex = {
    enabled = true,
    converter = { "utftex", "latex2text" },
    highlight = "RenderMarkdownMath",
    position = "center",
  },
})
require("obsidian").setup({
  ui = { enable = false },
  attachments = {
    img_folder = ".",
    img_name_func = function()
      return "Pasted image " .. os.date("%Y%m%d%H%M%S")
    end,
    img_text_func = function(_, path)
      local name = path.name
      return string.format("![%s](%s)", name, require("obsidian.util").urlencode(name))
    end,
    confirm_img_paste = false,
  },
  workspaces = {
    {
      name = "main",
      path = "~/Documents/Notes",
    },
  },
})

vim.env.SNACKS_GHOSTTY = "true"

local snacks = require("snacks")
if not snacks.did_setup then
  snacks.setup({
    image = {
      resolve = function(_, src)
        local candidate = vim.fs.joinpath(vim.fn.expand("~/Documents/Notes"), src)
        if vim.fn.filereadable(candidate) == 1 then
          return candidate
        end
      end,
      doc = {
        -- Snacks can render images in HTML/CSS/JSX/etc. Keep it available, but
        -- attach the document renderer manually for Markdown only.
        enabled = false,
        inline = true,
        float = true,
        max_width = 80,
        max_height = 35,
      },
      math = { enabled = false },
    },
    indent = {
      enabled = true,
      indent = { enabled = true },
      scope = { enabled = true },
    },
  })
end

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("PiMarkdownImagesOnly", { clear = true }),
  pattern = "markdown",
  callback = function(ev)
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(ev.buf) then
        require("snacks.image.doc").attach(ev.buf)
      end
    end)
  end,
})

map("n", "<leader>f", "<cmd>Pick files<CR>", { desc = "Find files" })
map("n", "<leader>,", "<cmd>Pick buffers<CR>", { desc = "Open buffers" })
map("n", "<leader>h", "<cmd>Pick help<CR>", { desc = "Help tags" })
map("n", "<leader>e", "<cmd>Oil<CR>", { desc = "File explorer" })
map("n", "<leader>ip", "<cmd>ObsidianPasteImg<CR>", { desc = "Paste clipboard image" })

vim.lsp.config("lua_ls", {
  settings = {
    Lua = {
      diagnostics = { globals = { "vim" } },
    },
  },
})

vim.lsp.config("ts_ls", {
  filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
})

vim.lsp.config("rust_analyzer", {})
vim.lsp.config("pyright", {})

local jdtls_workspace = vim.fn.stdpath("cache") .. "/jdtls/" .. vim.fn.fnamemodify(vim.fn.getcwd(), ":p"):gsub("[/\\:]", "_")
vim.lsp.config("jdtls", {
  cmd = { "jdtls", "-data", jdtls_workspace },
  root_markers = { ".git", "mvnw", "gradlew", "pom.xml", "build.gradle", "build.gradle.kts" },
})

vim.lsp.enable({ "lua_ls", "ts_ls", "rust_analyzer", "pyright", "jdtls" })

vim.cmd("colorscheme monolith")
vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
vim.api.nvim_set_hl(0, "LineNr", { fg = "#606079", bg = "none" })
vim.api.nvim_set_hl(0, "CursorLineNr", { fg = "#cdcdcd", bg = "none" })
vim.api.nvim_set_hl(0, "Directory", { fg = "#7e98e8" })
vim.api.nvim_set_hl(0, "OilDir", { fg = "#7e98e8" })
vim.api.nvim_set_hl(0, "OilDirIcon", { fg = "#7e98e8" })
vim.api.nvim_set_hl(0, "CursorLine", { bg = "#252530" })
vim.api.nvim_set_hl(0, "Visual", { bg = "#333738" })
for _, group in ipairs({ "SignColumn", "FoldColumn" }) do
  vim.api.nvim_set_hl(0, group, { bg = "none" })
end
local keyword_color = { fg = "#BAC6FF" }
for _, group in ipairs({
  "Keyword", "Statement", "@keyword", "@keyword.conditional", "@keyword.coroutine",
  "@keyword.debug", "@keyword.directive", "@keyword.directive.define", "@keyword.exception",
  "@keyword.function", "@keyword.import", "@keyword.modifier", "@keyword.operator",
  "@keyword.repeat", "@keyword.return", "@keyword.type", "@keyword.storage",
}) do
  vim.api.nvim_set_hl(0, group, keyword_color)
end
local statusline_bg = "#282727"
vim.api.nvim_set_hl(0, "StatusLine", { bg = statusline_bg })
vim.api.nvim_set_hl(0, "StatusLineNC", { bg = statusline_bg })

-- Heading shades: a ramp built off vague's keyword blue (#6e94b2).
-- H1 brightest -> H3 deepest; H4-6 reuse the deepest shade.
local heading_colors = {
  "#a9cdea", -- h1
  "#7ba7c9", -- h2
  "#54788f", -- h3
  "#54788f",
  "#54788f",
  "#54788f",
}

for i = 1, 6 do
  local fg = heading_colors[i]
  vim.api.nvim_set_hl(0, "RenderMarkdownH" .. i, { fg = fg, bold = true })
  vim.api.nvim_set_hl(0, "RenderMarkdownH" .. i .. "Bg", { bg = "none" })
  -- Keep insert mode (raw treesitter highlights) matching the rendered view.
  vim.api.nvim_set_hl(0, "@markup.heading." .. i .. ".markdown", { fg = fg, bold = true })
  vim.api.nvim_set_hl(0, "@markup.heading." .. i .. ".marker.markdown", { fg = fg, bold = true })
end

-- Rendered list markers default to Normal; match the editing (treesitter) color.
-- Covers both bullets and ordered "1." markers.
local markdown_list_marker = { fg = "#d59a9a" }
vim.api.nvim_set_hl(0, "RenderMarkdownBullet", markdown_list_marker)
vim.api.nvim_set_hl(0, "@markup.list", markdown_list_marker)
vim.api.nvim_set_hl(0, "RenderMarkdownUnchecked", { fg = "#d59a9a" })
vim.api.nvim_set_hl(0, "RenderMarkdownChecked", { fg = "#f3d488", bold = true })
vim.api.nvim_set_hl(0, "@markup.list.unchecked", { fg = "#d59a9a" })
vim.api.nvim_set_hl(0, "@markup.list.checked", { fg = "#f3d488", bold = true })

local markdown_strong = { fg = "#f3d488", bold = true }
vim.api.nvim_set_hl(0, "RenderMarkdownStrong", markdown_strong)
vim.api.nvim_set_hl(0, "@markup.strong", markdown_strong)
vim.api.nvim_set_hl(0, "@markup.strong.markdown", markdown_strong)
vim.api.nvim_set_hl(0, "@markup.strong.markdown_inline", markdown_strong)

local markdown_italic = { fg = "#d7c79e", italic = true }
vim.api.nvim_set_hl(0, "@markup.italic", markdown_italic)
vim.api.nvim_set_hl(0, "@markup.italic.markdown", markdown_italic)
vim.api.nvim_set_hl(0, "@markup.italic.markdown_inline", markdown_italic)
vim.api.nvim_set_hl(0, "RenderMarkdownInlineHighlight", { fg = "#f3d488", bg = "#3a3324", bold = true })
vim.api.nvim_set_hl(0, "RenderMarkdownMath", { fg = "#d7c79e", italic = true })
vim.api.nvim_set_hl(0, "@markup.math", { fg = "#d7c79e", italic = true })
vim.api.nvim_set_hl(0, "@markup.link.label", { fg = "#e8b589" })
vim.api.nvim_set_hl(0, "@markup.link.label.tsx", { fg = "#e8b589" })

local markdown_quote = { fg = "#8fb6a3", italic = true }
vim.api.nvim_set_hl(0, "PiMarkdownLiteralStrong", { link = "Normal" })
vim.api.nvim_set_hl(0, "PiMarkdownQuoteLiteralStrong", markdown_quote)
vim.api.nvim_set_hl(0, "RenderMarkdownQuote", { fg = "#8fb6a3", bold = true })
for i = 1, 6 do
  vim.api.nvim_set_hl(0, "RenderMarkdownQuote" .. i, { link = "RenderMarkdownQuote" })
end
vim.api.nvim_set_hl(0, "@markup.quote", markdown_quote)
vim.api.nvim_set_hl(0, "@markup.quote.markdown", markdown_quote)

vim.o.laststatus = 3

local function lsp_client_names()
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  if #clients == 0 then
    return ""
  end

  local names = {}
  local seen = {}
  for _, client in ipairs(clients) do
    if not seen[client.name] then
      table.insert(names, client.name)
      seen[client.name] = true
    end
  end

  return table.concat(names, ",")
end

local transparent_lualine = {
  normal = {
    a = { bg = statusline_bg },
    b = { bg = statusline_bg },
    c = { bg = statusline_bg },
    x = { bg = statusline_bg },
    y = { bg = statusline_bg },
    z = { bg = statusline_bg },
  },
  insert = {
    a = { bg = statusline_bg },
    b = { bg = statusline_bg },
    c = { bg = statusline_bg },
    x = { bg = statusline_bg },
    y = { bg = statusline_bg },
    z = { bg = statusline_bg },
  },
  visual = {
    a = { bg = statusline_bg },
    b = { bg = statusline_bg },
    c = { bg = statusline_bg },
    x = { bg = statusline_bg },
    y = { bg = statusline_bg },
    z = { bg = statusline_bg },
  },
  replace = {
    a = { bg = statusline_bg },
    b = { bg = statusline_bg },
    c = { bg = statusline_bg },
    x = { bg = statusline_bg },
    y = { bg = statusline_bg },
    z = { bg = statusline_bg },
  },
  command = {
    a = { bg = statusline_bg },
    b = { bg = statusline_bg },
    c = { bg = statusline_bg },
    x = { bg = statusline_bg },
    y = { bg = statusline_bg },
    z = { bg = statusline_bg },
  },
  inactive = {
    a = { bg = statusline_bg },
    b = { bg = statusline_bg },
    c = { bg = statusline_bg },
    x = { bg = statusline_bg },
    y = { bg = statusline_bg },
    z = { bg = statusline_bg },
  },
}

require("lualine").setup({
  options = {
    theme = transparent_lualine,
    globalstatus = true,
    component_separators = "",
    section_separators = "",
    disabled_filetypes = {
      statusline = { "oil" },
    },
  },

  sections = {
    lualine_a = {},
    lualine_b = {
      {
        "filename",
        path = 4, -- nested-folder/filename
        symbols = {
          modified = " ●",
          readonly = " ",
          unnamed = "[No Name]",
        },
      },
      {
        "branch",
        icon = "",
      },
    },
    lualine_c = {},

    lualine_x = {
      {
        lsp_client_names,
        icon = "",
      },
    },
    lualine_y = {},
    lualine_z = {
      {
        "diagnostics",
        sources = { "nvim_diagnostic" },
        symbols = {
          error = "✘ ",
          warn = "▲ ",
          info = "● ",
          hint = "󰌵 ",
        },
      },
    },
  },

  inactive_sections = {
    lualine_a = {},
    lualine_b = {
      {
        "filename",
        path = 4,
      },
    },
    lualine_c = {},
    lualine_x = {},
    lualine_y = {},
    lualine_z = {},
  },
})
