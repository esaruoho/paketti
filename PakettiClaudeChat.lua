-- PakettiClaudeChat.lua
-- A chat dialog inside Renoise that talks to a Claude Code session via OSC + filesystem.
--
-- Architecture:
--   You type → Send → message written to /tmp/claude-inbox.txt
--   Claude (running /loop on your Mac) polls the inbox, replies via OSC /renoise/evaluate
--   Claude's reply calls _PakettiClaudeReply(text), which appends to the response area.
--
-- The OSC bridge for Claude → Renoise is ~/.claude/bin/renoise-eval.

local INBOX_PATH = "/tmp/claude-inbox.txt"
local OUTBOX_LOG = "/tmp/claude-chat-log.txt"

-- Migration verification marker — set on every file load so we can confirm
-- Renoise auto-reload picked up edits made directly in /work/paketti
-- (which is now a symlink to the iCloud xrnx dir, post .git relocation).
_PakettiMigrationProbe = "loaded-at-" .. os.date("%H:%M:%S")

local dialog = nil
local vb = nil
local response_view = nil
local input_view = nil
local conversation = {}
local message_counter = 0

local function timestamp()
  return os.date("[%H:%M:%S]")
end

local function refresh_response_view()
  if not response_view then return end
  local lines = {}
  for _, entry in ipairs(conversation) do
    table.insert(lines, entry.role .. " " .. entry.time .. ":")
    table.insert(lines, entry.text)
    table.insert(lines, "")
  end
  response_view.text = table.concat(lines, "\n")
end

local function append_entry(role, text)
  table.insert(conversation, { role = role, text = text, time = timestamp() })
  refresh_response_view()
  local f = io.open(OUTBOX_LOG, "a")
  if f then
    f:write(timestamp() .. " " .. role .. ": " .. text .. "\n")
    f:close()
  end
end

-- Public: called from outside (via OSC /renoise/evaluate) to deliver Claude's reply
function _PakettiClaudeReply(text)
  if type(text) ~= "string" then text = tostring(text) end
  append_entry("Claude", text)
end

-- Public: clear the conversation view
function _PakettiClaudeChatClear()
  conversation = {}
  refresh_response_view()
end

local function on_send_clicked()
  if not input_view then return end
  local msg = input_view.text or ""
  if msg:match("^%s*$") then return end

  message_counter = message_counter + 1
  append_entry("Esa", msg)

  -- Write to inbox with a fresh-mtime guarantee (truncate first)
  local f, err = io.open(INBOX_PATH, "w")
  if f then
    f:write(os.date("[%Y-%m-%d %H:%M:%S] msg#") .. message_counter .. "\n")
    f:write(msg)
    f:close()
  else
    append_entry("System", "ERROR writing inbox: " .. tostring(err))
  end

  input_view.text = ""
end

function PakettiClaudeChatShow()
  if dialog and dialog.visible then
    dialog:show()
    return
  end

  vb = renoise.ViewBuilder()

  response_view = vb:multiline_textfield {
    width = 640,
    height = 420,
    text = "",
    style = "border",
    font = "mono",
    edit_mode = false
  }

  input_view = vb:textfield {
    width = 560,
    text = ""
  }

  local send_button = vb:button {
    text = "Send",
    width = 70,
    notifier = on_send_clicked
  }

  local clear_button = vb:button {
    text = "Clear",
    width = 60,
    notifier = _PakettiClaudeChatClear
  }

  local content = vb:column {
    margin = 8,
    spacing = 6,
    vb:text {
      text = "Paketti × Claude — chat (replies arrive via OSC; ~20-60s lag)",
      font = "italic"
    },
    response_view,
    vb:row {
      spacing = 4,
      input_view,
      send_button
    },
    vb:row {
      spacing = 4,
      clear_button,
      vb:text {
        text = "Inbox: " .. INBOX_PATH,
        font = "mono"
      }
    }
  }

  local function key_handler(d, key)
    if key.name == "return" and not (key.modifiers and key.modifiers:find("shift")) then
      on_send_clicked()
      return nil
    end
    if key.name == "esc" then
      d:close()
      return nil
    end
    return key
  end

  dialog = renoise.app():show_custom_dialog("Paketti × Claude Chat", content, key_handler)
  refresh_response_view()
end

renoise.tool():add_keybinding{
  name = "Global:Paketti:Claude Chat Dialog",
  invoke = PakettiClaudeChatShow
}

PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:!Preferences:Claude Chat Dialog...",
  invoke = PakettiClaudeChatShow
}
