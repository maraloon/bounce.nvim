-- require "logging.file"
-- local logger = logging.file {
--     filename = "debug.log",
-- }

---@class Bounce
local M = {}
local strFuncs = require("bounce.utf8-support").stringFuncs

local marks = {}
local namespace = vim.api.nvim_create_namespace("bounce")
local config = { highlight_group_name = "@text.todo", delay_time = 1000, more_jumps = false, display_mode = "overlay" }

local function find_jump_points(forward, jump_table)
  local line = vim.api.nvim_get_current_line()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local word_count = 1
  while true do
    if forward then
      vim.api.nvim_command("norm w")
    else
      vim.api.nvim_command("norm b")
    end
    local current_row, current_col = unpack(vim.api.nvim_win_get_cursor(0))
    current_col = strFuncs.posOffset(line, current_col)
    if current_row ~= row or current_col >= strFuncs.len(line) or strFuncs.len(line) == 0 then
      break
    end
    if not config.more_jumps and word_count > 9 then
      break
    end

    if word_count > 99 then
        break
    end

    if #jump_table > 0 and jump_table[#jump_table].pos == current_col - 1 then
      break
    end

    local count = ''
    local count_i = word_count % 10
    if word_count < 2 then
        if forward then
            count = 'w'
        else
            count = 'b'
        end
    else
        count = tostring(count_i)
    end

    table.insert(jump_table, {
      line = current_row - 1,
      pos = current_col - 1,
      char = strFuncs.sub(line, current_col, current_col),
      count = count,
    })
    word_count = word_count + 1
  end
  vim.api.nvim_win_set_cursor(0, { row, col })
  return jump_table
end

local function replace_char(str, n, ch)
  return strFuncs.sub(str, 0, n) .. ch .. strFuncs.sub(str, n + 2, strFuncs.len(str))
end

local function sort_by_pos(a, b)
  return a.pos < b.pos
end

local function assemble_virtual_line(jump_table)
  local win = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]
  local max_width = win.width - win.textoff
  local line_table = {}
  table.sort(jump_table, sort_by_pos)
  if #jump_table > 0 then
    local last_visible = 0
    for i = 1, #jump_table do
      if jump_table[i].pos < max_width then
        last_visible = i
      end
    end
    if last_visible > 0 then
      local truncated_table = {}
      for i = 1, last_visible do
        table.insert(truncated_table, jump_table[i])
      end
      local max_pos = truncated_table[#truncated_table].pos
      local extended_line = string.rep(" ", max_pos + 1)
      for i = 1, #truncated_table do
        extended_line = replace_char(extended_line, truncated_table[i].pos, truncated_table[i].count)
      end
      local padding_len = max_width - strFuncs.len(extended_line)
      if padding_len > 0 then
        extended_line = extended_line .. string.rep(" ", padding_len)
      end
      table.insert(line_table, extended_line)
    end
  end
  return line_table
end

local function update_word_buffer()
  for i = 1, #marks do
    vim.api.nvim_buf_del_extmark(0, namespace, marks[i])
  end
  marks = {}

  local temp_words = {}
  find_jump_points(true, temp_words)
  find_jump_points(false, temp_words)
  if config.display_mode == "overlay" then
    if #temp_words > 0 then
      for i = 1, #temp_words do
        local mark = vim.api.nvim_buf_set_extmark(0, namespace, temp_words[i].line, temp_words[i].pos, {
          virt_text = { { tostring(temp_words[i].count), config.highlight_group_name } },
          virt_text_pos = "overlay",
          virt_text_hide = true,
          hl_mode = "replace",
        })
        table.insert(marks, mark)
      end
    end
  elseif config.display_mode == "virtual_line" then
    local lines = assemble_virtual_line(temp_words)
    if #lines > 0 then
      for i = 1, #lines do
        local mark = vim.api.nvim_buf_set_extmark(0, namespace, temp_words[1].line, i, {
          hl_mode = "replace",
          virt_lines = { { { lines[i], config.highlight_group_name } } },
        })
        table.insert(marks, mark)
      end
    end
  end
end

local function hide_word_numbers()
  for i = 1, #marks do
    vim.api.nvim_buf_del_extmark(0, namespace, marks[i])
  end
  marks = {}
end

local function show_word_numbers()
  -- TODO: plugin must be ignored in Telescope 
  -- hide_word_numbers()
  -- update_timer:start(config.delay_time, 0, vim.schedule_wrap(update_word_buffer))
  update_word_buffer()
end

local function setup(user_config)
  config = vim.tbl_deep_extend("force", config, user_config or {})
  vim.api.nvim_create_autocmd({ "CursorMoved" }, { callback = show_word_numbers })
  vim.api.nvim_create_autocmd(
    { "ModeChanged", "CmdlineEnter", "WinResized", "VimResized", "BufEnter", "BufLeave" },
    { callback = hide_word_numbers }
  )

  vim.api.nvim_create_autocmd("ModeChanged", {
        pattern = { "*:[n\x16]*" }, -- back to normal mode
        callback = show_word_numbers,
  })
end

M = {
  setup = setup,
  show_word_numbers = show_word_numbers,
  hide_word_numbers = hide_word_numbers,
}

return M
