
-- EffortValueAgent
-- Phase 1: Read-only memory verification

console:log("=== EffortValueAgent Memory Probe ===")

-- Identify the loaded game
local title = emu:getGameTitle()
local game_code = emu:getGameCode()

console:log("Game Title: " .. title)
console:log("Game Code: " .. game_code)

-- Read the ROM revision byte
local revision = emu:read8(0x080000BC)
console:log("ROM Revision: " .. revision)

-- Read one byte from External Work RAM
local ram_value = emu:read8(0x02000000)

console:log(string.format(
    "EWRAM [0x02000000]: 0x%02X",
    ram_value
))

console:log("Memory read successful!")
console:log("=== Probe Complete ===")
