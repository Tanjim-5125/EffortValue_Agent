-- Read-only probing file

local PARTY_COUNT_ADDR = 0x020244E9
local PARTY_BASE_ADDR = 0x020244EC
local POKEMON_SIZE = 100

-- Species name table in Emerald ROM
local SPECIES_NAMES_ADDR = 0x083185C8
local SPECIES_NAME_LENGTH = 11

-- Growth, Attacks, EVs, Misc substructure permutations
local SUBSTRUCT_ORDERS = {
    "GAEM", "GAME", "GEAM", "GEMA", "GMAE", "GMEA",
    "AGEM", "AGME", "AEGM", "AEMG", "AMGE", "AMEG",
    "EGAM", "EGMA", "EAGM", "EAMG", "EMGA", "EMAG",
    "MGAE", "MGEA", "MAGE", "MAEG", "MEGA", "MEAG"
}

-- Decode the common Western Gen III character set
local SPECIAL_CHARS = {
    [0x00] = " ",
    [0xAB] = "!",
    [0xAC] = "?",
    [0xAD] = ".",
    [0xAE] = "-",
    [0xB4] = "'",
    [0xB5] = "♂",
    [0xB6] = "♀",
    [0xB8] = ",",
    [0xBA] = "/"
}

local function decode_name(address, length)
    local characters = {}

    for i = 0, length - 1 do
        local byte = emu:read8(address + i)

        if byte == 0xFF then
            break
        end

        local character

        if byte >= 0xBB and byte <= 0xD4 then
            character = string.char(65 + byte - 0xBB)
        elseif byte >= 0xD5 and byte <= 0xEE then
            character = string.char(97 + byte - 0xD5)
        elseif byte >= 0xA1 and byte <= 0xAA then
            character = string.char(48 + byte - 0xA1)
        else
            character = SPECIAL_CHARS[byte]
                or string.format("{%02X}", byte)
        end

        table.insert(characters, character)
    end

    return table.concat(characters):gsub("%s+$", "")
end

-- Decrypt the Gen III secure data and extract species ID
local function read_species_id(address, personality, ot_id)
    local key = personality ~ ot_id
    local words = {}
    local checksum = 0

    for i = 0, 11 do
        local encrypted = emu:read32(address + 0x20 + i * 4)
        local decrypted = encrypted ~ key

        words[i] = decrypted

        checksum = (
            checksum
            + (decrypted & 0xFFFF)
            + ((decrypted >> 16) & 0xFFFF)
        ) & 0xFFFF
    end

    local stored_checksum = emu:read16(address + 0x1C)

    if checksum ~= stored_checksum then
        return nil, "Checksum mismatch"
    end

    local order = SUBSTRUCT_ORDERS[(personality % 24) + 1]
    local growth_position = order:find("G", 1, true) - 1

    -- Each substructure is 3 x 32-bit words
    local growth_word = words[growth_position * 3]
    local species_id = growth_word & 0xFFFF

    if species_id < 1 or species_id >= 412 then
        return nil, "Invalid species ID: " .. species_id
    end

    return species_id
end

local function read_species_name(species_id)
    local address = SPECIES_NAMES_ADDR
        + species_id * SPECIES_NAME_LENGTH

    return decode_name(address, SPECIES_NAME_LENGTH)
end

-- Main party inspection
console:log("=== Party Probe ===")

local party_count = emu:read8(PARTY_COUNT_ADDR)
console:log("Party count: " .. party_count)

if party_count > 6 then
    console:warn("Invalid party count")
    return
end

for slot = 0, party_count - 1 do
    local address = PARTY_BASE_ADDR + slot * POKEMON_SIZE

    local personality = emu:read32(address)
    local ot_id = emu:read32(address + 0x04)

    local nickname = decode_name(address + 0x08, 10)

    local level = emu:read8(address + 0x54)
    local hp = emu:read16(address + 0x56)
    local max_hp = emu:read16(address + 0x58)

    local species_id, error_message =
        read_species_id(address, personality, ot_id)

    local species_name = "UNKNOWN"

    if species_id then
        species_name = read_species_name(species_id)
    else
        console:warn(
            string.format("Slot %d: %s", slot + 1, error_message)
        )
    end

    console:log(string.format(
        "Slot %d | %s | Nickname: %s | Species ID: %s | Lv %d | HP %d/%d | PID %08X | OT %08X",
        slot + 1,
        species_name,
        nickname,
        tostring(species_id or "?"),
        level,
        hp,
        max_hp,
        personality,
        ot_id
    ))
end

console:log("=== Party Probe Complete ===")
