import re

with open("standstick.lua", "r") as f:
    standstick_code = f.read()

with open("sticker.lua", "r") as f:
    sticker_code = f.read()

# Remove the SCRIPT_URL definition
sticker_code = re.sub(r'local SCRIPT_URL = "https://raw.githubusercontent.com/KieuroBeep/TrixSpoits/refs/heads/main/StandStickScript"\n', '', sticker_code)

pattern = r"-- The actual code we want to run after teleport \(string\)\nlocal main_code = \(\"loadstring\(game:HttpGet\('%s'\)\)\(\)\"\):format\(SCRIPT_URL\)\n\nif game\.PlaceId == TARGET_PLACE then\n    -- In correct place: load immediately\n    local ok, err = pcall\(function\(\)\n        loadstring\(game:HttpGet\(SCRIPT_URL\)\)\(\)\n    end\)"

replacement = f"""-- The actual code we want to run after teleport (string)
local main_code = [=[
{standstick_code}
]=]

if game.PlaceId == TARGET_PLACE then
    -- In correct place: load immediately
    local ok, err = pcall(function()
        -- Запускаем оригинальный скрипт из строки
        local func = loadstring(main_code)
        if func then func() end
    end)"""

new_sticker = re.sub(pattern, replacement, sticker_code)

with open("sticker.lua", "w") as f:
    f.write(new_sticker)
