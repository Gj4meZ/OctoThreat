-- ==========================================================
-- OctoThreat v4.2 - WotLK Beveled Threat Tab + Target Glow
-- + ALT + Left-Click Free Drag & Drop Placement
-- + Plater-Style TargetFrame Debuff Clock & Countdown (OmniCC Blocked)
-- + Full Hunter Pet Growl / Taunt Sync
-- For WoW Vanilla 1.12.1 (Lua 5.0)
-- ==========================================================

OctoThreatDB = OctoThreatDB or {
    customTank = nil,
    anchorMode = "NAME", -- "NAME", "PORTRAIT", or "CUSTOM" (when dragged via ALT + Left-Click)
    offsetX = 0,
    offsetY = 2,
    dragX = nil,
    dragY = nil,
    tabWidth = 64,
    tabHeight = 22,
    showPlayerBar = false,
    showTargetDebuffTimers = true,
    enableGlow = true,
}

local ThreatData = {}          -- ThreatData[unitName] = numeric threat value
local CurrentTank = nil        -- Name of current tank / pet aggro holder
local LastAggroHolder = nil    -- Tracks targettarget transitions for instant Taunt/Growl sync
local LastTargetName = nil     -- Tracks target switches
local LastPetCDs = {}          -- Tracks Pet Action Bar cooldown timestamps (Growl/Torment)
local WasFeignDeath = false    -- Tracks Hunter Feign Death state
local TestMode = false
local TestPctValue = 93        -- Defaults to 93% (like the screenshot) in test mode
local UpdateTimer = 0

-- Standalone Target Debuff Tracking Tables (Self-Contained Plater-Style Counter, OmniCC Blocked)
local TargetDebuffTimers = {}      -- TargetDebuffTimers[unitKey][shortTex] = { spell, tex, startTime, duration }
local LearnedSpellDurations = {}   -- Dynamically scanned from player's Spellbook (includes Rank + Talents)
local LearnedSpellIcons = {}       -- SpellName -> Icon texture path
local LearnedTextureDurations = {} -- shortTex -> duration
local LastCastSpellDuration = {}   -- Captures exact rank duration when pressing an ActionBar button
local LastComboPoints = 1
local DebuffHooked = {}            -- Plater-style Clock + Countdown overlays on TargetFrameDebuff1..16

-- Custom TGA Texture Paths bundled in Interface\AddOns\OctoThreat\Textures\
local TEX_TAB_BORDER = "Interface\\AddOns\\OctoThreat\\Textures\\ThreatTabBorder"
local TEX_TAB_FILL   = "Interface\\AddOns\\OctoThreat\\Textures\\ThreatTabFill"
local TEX_TOP_GLOW   = "Interface\\AddOns\\OctoThreat\\Textures\\ThreatTopGlow"

-- Hidden Tooltip for scanning Spellbook, ActionBars, and Target Debuffs
local ScanTooltip = CreateFrame("GameTooltip", "OctoThreat_ScanTooltip", UIParent, "GameTooltipTemplate")
ScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")

-- ==========================================================
-- 1. BUILT-IN CLASS/RANK/LEVEL DEBUFF DATABASE (STANDALONE)
-- ==========================================================

local Octo_DebuffByName = {
    -- Warrior
    ["Rend"] = { duration = 21, icon = "Interface\\Icons\\Ability_Gouge", ranks = { {1, 9}, {10, 12}, {20, 15}, {30, 18}, {40, 21} } },
    ["Thunder Clap"] = { duration = 30, icon = "Interface\\Icons\\Spell_Nature_ThunderClap", ranks = { {1, 10}, {18, 14}, {28, 18}, {38, 22}, {48, 26}, {58, 30} } },
    ["Hamstring"] = { duration = 15, icon = "Interface\\Icons\\Ability_ShockWave" },
    ["Piercing Howl"] = { duration = 6, icon = "Interface\\Icons\\Spell_Shadow_DeathScream" },
    ["Sunder Armor"] = { duration = 30, icon = "Interface\\Icons\\Ability_Warrior_Sunder" },
    ["Demoralizing Shout"] = { duration = 30, icon = "Interface\\Icons\\Ability_Warrior_WarCry" },
    ["Intimidating Shout"] = { duration = 8, icon = "Interface\\Icons\\Ability_GolemThunderClap" },
    ["Challenging Shout"] = { duration = 6, icon = "Interface\\Icons\\Ability_BullRush" },
    ["Mortal Strike"] = { duration = 10, icon = "Interface\\Icons\\Ability_Warrior_SavageBlow" },
    ["Deep Wounds"] = { duration = 12, icon = "Interface\\Icons\\Ability_BackStab" },
    ["Taunt"] = { duration = 3, icon = "Interface\\Icons\\Spell_Nature_Reincarnation" },
    ["Mocking Blow"] = { duration = 6, icon = "Interface\\Icons\\Ability_Warrior_PunishingBlow" },
    ["Disarm"] = { duration = 10, icon = "Interface\\Icons\\Ability_Warrior_Disarm" },
    ["Concussion Blow"] = { duration = 5, icon = "Interface\\Icons\\Ability_ThunderBolt" },
    ["Charge Stun"] = { duration = 1, icon = "Interface\\Icons\\Spell_Frost_Stun" },
    ["Intercept Stun"] = { duration = 3, icon = "Interface\\Icons\\Spell_Frost_Stun" },
    ["Revenge Stun"] = { duration = 3, icon = "Interface\\Icons\\Ability_Warrior_Revenge" },
    ["Shield Bash - Silenced"] = { duration = 3, icon = "Interface\\Icons\\Ability_Warrior_ShieldBash" },

    -- Warlock
    ["Corruption"] = { duration = 18, icon = "Interface\\Icons\\Spell_Shadow_AbominationExplosion", ranks = { {1, 12}, {14, 15}, {24, 18} } },
    ["Immolate"] = { duration = 15, icon = "Interface\\Icons\\Spell_Fire_Immolation" },
    ["Curse of Agony"] = { duration = 24, icon = "Interface\\Icons\\Spell_Shadow_CurseOfSargeras" },
    ["Siphon Life"] = { duration = 30, icon = "Interface\\Icons\\Spell_Shadow_Requiem" },
    ["Curse of Weakness"] = { duration = 120, icon = "Interface\\Icons\\Spell_Shadow_CurseOfMannoroth" },
    ["Curse of Recklessness"] = { duration = 120, icon = "Interface\\Icons\\Spell_Shadow_UnholyStrength" },
    ["Curse of Tongues"] = { duration = 30, icon = "Interface\\Icons\\Spell_Shadow_CurseOfTounges" },
    ["Curse of the Elements"] = { duration = 300, icon = "Interface\\Icons\\Spell_Shadow_ChillTouch" },
    ["Curse of Shadow"] = { duration = 300, icon = "Interface\\Icons\\Spell_Shadow_CurseOfAchimonde" },
    ["Curse of Exhaustion"] = { duration = 12, icon = "Interface\\Icons\\Spell_Shadow_GrimWard" },
    ["Curse of Doom"] = { duration = 60, icon = "Interface\\Icons\\Spell_Shadow_AuraOfDarkness" },
    ["Fear"] = { duration = 20, icon = "Interface\\Icons\\Spell_Shadow_Possession", ranks = { {1, 10}, {32, 15}, {56, 20} } },
    ["Howl of Terror"] = { duration = 15, icon = "Interface\\Icons\\Spell_Shadow_DeathScream", ranks = { {1, 10}, {54, 15} } },
    ["Banish"] = { duration = 30, icon = "Interface\\Icons\\Spell_Shadow_Cripple", ranks = { {1, 20}, {48, 30} } },
    ["Death Coil"] = { duration = 3, icon = "Interface\\Icons\\Spell_Shadow_DeathCoil" },
    ["Shadowburn"] = { duration = 5, icon = "Interface\\Icons\\Spell_Shadow_ScourgeBuild" },
    ["Drain Life"] = { duration = 5, icon = "Interface\\Icons\\Spell_Shadow_LifeDrain02" },
    ["Drain Soul"] = { duration = 15, icon = "Interface\\Icons\\Spell_Shadow_Haunting" },
    ["Drain Mana"] = { duration = 5, icon = "Interface\\Icons\\Spell_Shadow_SiphonMana" },
    ["Shadow Vulnerability"] = { duration = 12, icon = "Interface\\Icons\\Spell_Shadow_BlackPlague" },
    ["Seduction"] = { duration = 15, icon = "Interface\\Icons\\Spell_Shadow_MindSteal" },
    ["Spell Lock"] = { duration = 8, icon = "Interface\\Icons\\Spell_Shadow_MindRot", ranks = { {1, 6}, {52, 8} } },

    -- Mage
    ["Polymorph"] = { duration = 50, icon = "Interface\\Icons\\Spell_Nature_Polymorph", ranks = { {1, 20}, {20, 30}, {40, 40}, {60, 50} } },
    ["Frostbolt"] = { duration = 9, icon = "Interface\\Icons\\Spell_Frost_FrostBolt02", ranks = { {1, 5}, {8, 6}, {20, 7}, {26, 8}, {38, 9} } },
    ["Fireball"] = { duration = 8, icon = "Interface\\Icons\\Spell_Fire_FlameBolt", ranks = { {1, 4}, {6, 6}, {24, 8} } },
    ["Frost Nova"] = { duration = 8, icon = "Interface\\Icons\\Spell_Frost_FrostNova" },
    ["Cone of Cold"] = { duration = 8, icon = "Interface\\Icons\\Spell_Frost_Glacier" },
    ["Pyroblast"] = { duration = 12, icon = "Interface\\Icons\\Spell_Fire_Fireball02" },
    ["Ignite"] = { duration = 4, icon = "Interface\\Icons\\Spell_Fire_Incinerate" },
    ["Flamestrike"] = { duration = 8, icon = "Interface\\Icons\\Spell_Fire_SelfDestruct" },
    ["Blast Wave"] = { duration = 6, icon = "Interface\\Icons\\Spell_Holy_Excorcism_02" },
    ["Winter's Chill"] = { duration = 15, icon = "Interface\\Icons\\Spell_Frost_ChillingBlast" },
    ["Fire Vulnerability"] = { duration = 30, icon = "Interface\\Icons\\Spell_Fire_SoulBurn" },
    ["Counterspell - Silenced"] = { duration = 4, icon = "Interface\\Icons\\Spell_Frost_IceShock" },

    -- Priest
    ["Shadow Word: Pain"] = { duration = 18, icon = "Interface\\Icons\\Spell_Shadow_ShadowWordPain" },
    ["Mind Flay"] = { duration = 3, icon = "Interface\\Icons\\Spell_Shadow_SiphonMana" },
    ["Psychic Scream"] = { duration = 8, icon = "Interface\\Icons\\Spell_Shadow_PsychicScream" },
    ["Silence"] = { duration = 5, icon = "Interface\\Icons\\Spell_Shadow_ImpPhaseShift" },
    ["Vampiric Embrace"] = { duration = 60, icon = "Interface\\Icons\\Spell_Shadow_UnsummonBuilding" },
    ["Devouring Plague"] = { duration = 24, icon = "Interface\\Icons\\Spell_Shadow_BlackPlague" },
    ["Holy Fire"] = { duration = 10, icon = "Interface\\Icons\\Spell_Holy_SearingLight" },
    ["Shackle Undead"] = { duration = 50, icon = "Interface\\Icons\\Spell_Nature_Slow", ranks = { {1, 30}, {40, 40}, {60, 50} } },

    -- Druid
    ["Moonfire"] = { duration = 12, icon = "Interface\\Icons\\Spell_Nature_StarFall", ranks = { {1, 9}, {10, 12} } },
    ["Entangling Roots"] = { duration = 27, icon = "Interface\\Icons\\Spell_Nature_StrangleVines", ranks = { {1, 12}, {18, 15}, {28, 18}, {38, 21}, {48, 24}, {58, 27} } },
    ["Hibernate"] = { duration = 40, icon = "Interface\\Icons\\Spell_Nature_Sleep", ranks = { {1, 20}, {38, 30}, {58, 40} } },
    ["Bash"] = { duration = 4, icon = "Interface\\Icons\\Ability_Druid_Bash", ranks = { {1, 2}, {30, 3}, {46, 4} } },
    ["Insect Swarm"] = { duration = 12, icon = "Interface\\Icons\\Spell_Nature_InsectSwarm" },
    ["Rake"] = { duration = 9, icon = "Interface\\Icons\\Ability_Druid_Disembowel" },
    ["Rip"] = { duration = 12, icon = "Interface\\Icons\\Ability_GhoulFrenzy" },
    ["Pounce"] = { duration = 2, icon = "Interface\\Icons\\Ability_Druid_SupriseAttack" },
    ["Pounce Bleed"] = { duration = 18, icon = "Interface\\Icons\\Ability_Druid_SupriseAttack" },
    ["Faerie Fire"] = { duration = 40, icon = "Interface\\Icons\\Spell_Nature_FaerieFire" },
    ["Faerie Fire (Feral)"] = { duration = 40, icon = "Interface\\Icons\\Spell_Nature_FaerieFire" },
    ["Demoralizing Roar"] = { duration = 30, icon = "Interface\\Icons\\Ability_Druid_DemoralizingRoar" },
    ["Growl"] = { duration = 3, icon = "Interface\\Icons\\Ability_Physical_Taunt" },

    -- Rogue
    ["Sap"] = { duration = 45, icon = "Interface\\Icons\\Ability_Sap", ranks = { {1, 25}, {28, 35}, {48, 45} } },
    ["Cheap Shot"] = { duration = 4, icon = "Interface\\Icons\\Ability_CheapShot" },
    ["Kidney Shot"] = { duration = 5, icon = "Interface\\Icons\\Ability_Rogue_KidneyShot", comboScale = "KIDNEY" },
    ["Gouge"] = { duration = 4, icon = "Interface\\Icons\\Ability_Gouge" },
    ["Blind"] = { duration = 10, icon = "Interface\\Icons\\Spell_Shadow_MindSteal" },
    ["Garrote"] = { duration = 18, icon = "Interface\\Icons\\Ability_Rogue_Garrote" },
    ["Rupture"] = { duration = 12, icon = "Interface\\Icons\\Ability_Rogue_Rupture", comboScale = "RUPTURE" },
    ["Expose Armor"] = { duration = 30, icon = "Interface\\Icons\\Ability_Warrior_Riposte" },
    ["Deadly Poison"] = { duration = 12, icon = "Interface\\Icons\\Ability_Rogue_DualWeild" },
    ["Crippling Poison"] = { duration = 12, icon = "Interface\\Icons\\Ability_PoisonSting" },
    ["Mind-numbing Poison"] = { duration = 14, icon = "Interface\\Icons\\Spell_Nature_NullifyDisease" },
    ["Wound Poison"] = { duration = 15, icon = "Interface\\Icons\\INV_Misc_Herb_16" },

    -- Hunter
    ["Serpent Sting"] = { duration = 15, icon = "Interface\\Icons\\Ability_Hunter_Quickshot" },
    ["Scorpid Sting"] = { duration = 20, icon = "Interface\\Icons\\Ability_Hunter_CriticalShot" },
    ["Viper Sting"] = { duration = 8, icon = "Interface\\Icons\\Ability_Hunter_AimedShot" },
    ["Wyvern Sting"] = { duration = 12, icon = "Interface\\Icons\\INV_Spear_02" },
    ["Concussive Shot"] = { duration = 4, icon = "Interface\\Icons\\Spell_Frost_Stun" },
    ["Scatter Shot"] = { duration = 4, icon = "Interface\\Icons\\Ability_GolemStormBolt" },
    ["Intimidation"] = { duration = 3, icon = "Interface\\Icons\\Ability_Devour" },
    ["Wing Clip"] = { duration = 10, icon = "Interface\\Icons\\Ability_Rogue_Trip" },
    ["Improved Wing Clip"] = { duration = 5, icon = "Interface\\Icons\\Ability_Rogue_Trip" },
    ["Hunter's Mark"] = { duration = 120, icon = "Interface\\Icons\\Ability_Hunter_SniperShot" },
    ["Scare Beast"] = { duration = 20, icon = "Interface\\Icons\\Ability_Druid_Cower", ranks = { {1, 10}, {30, 15}, {46, 20} } },
    ["Freezing Trap Effect"] = { duration = 20, icon = "Interface\\Icons\\Spell_Frost_ChainsOfIce", ranks = { {1, 10}, {40, 15}, {60, 20} } },
    ["Immolation Trap Effect"] = { duration = 15, icon = "Interface\\Icons\\Spell_Fire_FlameShock" },

    -- Paladin & Shaman
    ["Hammer of Justice"] = { duration = 6, icon = "Interface\\Icons\\Spell_Holy_SealOfMight", ranks = { {1, 3}, {24, 4}, {40, 5}, {56, 6} } },
    ["Repentance"] = { duration = 6, icon = "Interface\\Icons\\Spell_Holy_PrayerOfHealing" },
    ["Turn Undead"] = { duration = 20, icon = "Interface\\Icons\\Spell_Holy_TurnUndead", ranks = { {1, 10}, {38, 15}, {52, 20} } },
    ["Flame Shock"] = { duration = 12, icon = "Interface\\Icons\\Spell_Fire_FlameShock" },
    ["Frost Shock"] = { duration = 8, icon = "Interface\\Icons\\Spell_Frost_FrostShock" },
    ["Stormstrike"] = { duration = 12, icon = "Interface\\Icons\\Spell_Holy_SealOfMight" },
}

local Octo_DebuffByTexture = {
    ["spell_shadow_abominationexplosion"] = "Corruption",
    ["spell_fire_immolation"] = "Immolate",
    ["spell_shadow_curseofsargeras"] = "Curse of Agony",
    ["spell_shadow_requiem"] = "Siphon Life",
    ["spell_shadow_curseofmannoroth"] = "Curse of Weakness",
    ["spell_shadow_unholystrength"] = "Curse of Recklessness",
    ["spell_shadow_curseoftounges"] = "Curse of Tongues",
    ["spell_shadow_chilltouch"] = "Curse of the Elements",
    ["spell_shadow_curseofachimonde"] = "Curse of Shadow",
    ["spell_shadow_grimward"] = "Curse of Exhaustion",
    ["spell_shadow_auraofdarkness"] = "Curse of Doom",
    ["spell_shadow_possession"] = "Fear",
    ["spell_shadow_deathscream"] = "Howl of Terror",
    ["spell_shadow_deathcoil"] = "Death Coil",
    ["spell_shadow_cripple"] = "Banish",
    ["spell_shadow_scourgebuild"] = "Shadowburn",
    ["spell_shadow_lifedrain02"] = "Drain Life",
    ["spell_shadow_haunting"] = "Drain Soul",
    ["spell_shadow_siphonmana"] = "Mind Flay",
    ["spell_shadow_blackplague"] = "Shadow Vulnerability",
    ["spell_shadow_mindsteal"] = "Blind",
    ["spell_shadow_mindrot"] = "Spell Lock",
    ["spell_shadow_shadowwordpain"] = "Shadow Word: Pain",
    ["spell_shadow_psychicscream"] = "Psychic Scream",
    ["spell_shadow_impphaseshift"] = "Silence",
    ["spell_shadow_unsummonbuilding"] = "Vampiric Embrace",
    ["spell_holy_searinglight"] = "Holy Fire",
    ["spell_nature_polymorph"] = "Polymorph",
    ["spell_frost_frostnova"] = "Frost Nova",
    ["spell_frost_frostbolt02"] = "Frostbolt",
    ["spell_frost_glacier"] = "Cone of Cold",
    ["spell_fire_flamebolt"] = "Fireball",
    ["spell_fire_fireball02"] = "Pyroblast",
    ["spell_fire_incinerate"] = "Ignite",
    ["spell_frost_chillingblast"] = "Winter's Chill",
    ["spell_nature_starfall"] = "Moonfire",
    ["spell_nature_insectswarm"] = "Insect Swarm",
    ["ability_druid_disembowel"] = "Rake",
    ["ability_ghoulfrenzy"] = "Rip",
    ["spell_nature_faeriefire"] = "Faerie Fire",
    ["spell_nature_stranglevines"] = "Entangling Roots",
    ["spell_nature_sleep"] = "Hibernate",
    ["ability_druid_bash"] = "Bash",
    ["ability_druid_demoralizingroar"] = "Demoralizing Roar",
    ["ability_cheapshot"] = "Cheap Shot",
    ["ability_rogue_kidneyshot"] = "Kidney Shot",
    ["ability_gouge"] = "Rend",
    ["ability_sap"] = "Sap",
    ["ability_rogue_garrote"] = "Garrote",
    ["ability_rogue_rupture"] = "Rupture",
    ["ability_warrior_riposte"] = "Expose Armor",
    ["ability_rogue_dualweild"] = "Deadly Poison",
    ["ability_poisonsting"] = "Crippling Poison",
    ["ability_shockwave"] = "Hamstring",
    ["ability_warrior_sunder"] = "Sunder Armor",
    ["spell_nature_thunderclap"] = "Thunder Clap",
    ["ability_warrior_warcry"] = "Demoralizing Shout",
    ["ability_golemthunderclap"] = "Intimidating Shout",
    ["ability_warrior_savageblow"] = "Mortal Strike",
    ["ability_backstab"] = "Deep Wounds",
    ["ability_hunter_quickshot"] = "Serpent Sting",
    ["ability_hunter_criticalshot"] = "Scorpid Sting",
    ["ability_hunter_aimedshot"] = "Viper Sting",
    ["spell_frost_stun"] = "Concussive Shot",
    ["ability_hunter_snipershot"] = "Hunter's Mark",
    ["spell_frost_chainsofice"] = "Freezing Trap Effect",
    ["spell_holy_sealofmight"] = "Hammer of Justice",
    ["spell_fire_flameshock"] = "Flame Shock",
    ["spell_frost_frostshock"] = "Frost Shock",
}

-- ==========================================================
-- 2. SPELLBOOK & TOOLTIP DURATION SCANNER
-- ==========================================================

local function ExtractShortTexture(texPath)
    if not texPath then return "" end
    local lower = string.lower(texPath)
    local _, _, shortName = string.find(lower, "([^\\]+)$")
    return shortName or lower
end

local function FormatCooldownTime(remaining)
    if remaining <= 0 then return "" end
    if remaining >= 60 then
        return string.format("%dm", math.ceil(remaining / 60))
    elseif remaining >= 4 then
        return tostring(math.floor(remaining + 0.5))
    else
        return string.format("%.1f", remaining)
    end
end

local function ParseDurationFromText(txt)
    if not txt or txt == "" then return nil end
    local lower = string.lower(txt)

    local _, _, overSec = string.find(lower, "over (%d+%.?%d*) sec")
    if overSec then return tonumber(overSec) end

    local _, _, upToSec = string.find(lower, "for up to (%d+%.?%d*) sec")
    if upToSec then return tonumber(upToSec) end

    local _, _, lastsSec = string.find(lower, "lasts (%d+%.?%d*) sec")
    if lastsSec then return tonumber(lastsSec) end
    local _, _, lastsForSec = string.find(lower, "lasts for (%d+%.?%d*) sec")
    if lastsForSec then return tonumber(lastsForSec) end

    local _, _, forSec = string.find(lower, "for (%d+%.?%d*) sec")
    if forSec then return tonumber(forSec) end

    local _, _, forMin = string.find(lower, "for (%d+%.?%d*) min")
    if forMin then return tonumber(forMin) * 60 end
    local _, _, lastsMin = string.find(lower, "lasts (%d+%.?%d*) min")
    if lastsMin then return tonumber(lastsMin) * 60 end
    local _, _, overMin = string.find(lower, "over (%d+%.?%d*) min")
    if overMin then return tonumber(overMin) * 60 end

    return nil
end

local function ScanPlayerSpellbook()
    ScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    local i = 1
    while true do
        local spellName = GetSpellName(i, BOOKTYPE_SPELL)
        if not spellName then break end

        ScanTooltip:ClearLines()
        ScanTooltip:SetSpell(i, BOOKTYPE_SPELL)

        local tex = GetSpellTexture(i, BOOKTYPE_SPELL)
        if tex then
            LearnedSpellIcons[spellName] = tex
        end

        local foundDur = nil
        for lineIdx = 2, ScanTooltip:NumLines() do
            local leftRegion = getglobal("OctoThreat_ScanTooltipTextLeft" .. lineIdx)
            local txt = leftRegion and leftRegion:GetText()
            if txt then
                local d = ParseDurationFromText(txt)
                if d and d > 0 then
                    foundDur = d
                end
            end
        end

        if foundDur and foundDur > 0 then
            LearnedSpellDurations[spellName] = foundDur
            if tex then
                LearnedTextureDurations[ExtractShortTexture(tex)] = foundDur
            end
        end

        i = i + 1
    end
end

local function InspectActionSlotDuration(slot)
    if not slot then return end
    if GetComboPoints and GetComboPoints() > 0 then
        LastComboPoints = GetComboPoints()
    end
    ScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    ScanTooltip:ClearLines()
    ScanTooltip:SetAction(slot)

    local nameRegion = getglobal("OctoThreat_ScanTooltipTextLeft1")
    local spellName = nameRegion and nameRegion:GetText()
    if not spellName or spellName == "" then return end

    for lineIdx = 2, ScanTooltip:NumLines() do
        local leftRegion = getglobal("OctoThreat_ScanTooltipTextLeft" .. lineIdx)
        local txt = leftRegion and leftRegion:GetText()
        if txt then
            local d = ParseDurationFromText(txt)
            if d and d > 0 then
                LastCastSpellDuration[spellName] = d
            end
        end
    end
end

local Orig_UseAction = UseAction
UseAction = function(slot, checkCursor, onSelf)
    InspectActionSlotDuration(slot)
    return Orig_UseAction(slot, checkCursor, onSelf)
end

local function GetDynamicDebuffDuration(spellName, shortTex)
    if (not spellName or spellName == "") and shortTex and Octo_DebuffByTexture then
        spellName = Octo_DebuffByTexture[shortTex]
        if shortTex == "ability_gouge" then
            local _, playerClass = UnitClass("player")
            if playerClass == "ROGUE" then
                spellName = "Gouge"
            else
                spellName = "Rend"
            end
        end
    end

    local dbEntry = spellName and Octo_DebuffByName and Octo_DebuffByName[spellName]

    if dbEntry and dbEntry.comboScale then
        local cp = LastComboPoints or 1
        if GetComboPoints and GetComboPoints() > 0 then
            cp = GetComboPoints()
        end
        if dbEntry.comboScale == "KIDNEY" then
            return 1 + cp
        elseif dbEntry.comboScale == "RUPTURE" then
            return 6 + (cp * 2)
        end
    end

    if spellName and LastCastSpellDuration[spellName] then
        return LastCastSpellDuration[spellName]
    end

    if spellName and LearnedSpellDurations[spellName] then
        return LearnedSpellDurations[spellName]
    end

    if dbEntry then
        if dbEntry.ranks then
            local pLvl = UnitLevel("player") or 60
            local scaledDur = dbEntry.ranks[1][2]
            for r = 1, table.getn(dbEntry.ranks) do
                local reqLvl = dbEntry.ranks[r][1]
                local rDur = dbEntry.ranks[r][2]
                if pLvl >= reqLvl then
                    scaledDur = rDur
                end
            end
            return scaledDur
        end
        if dbEntry.duration then
            return dbEntry.duration
        end
    end

    if shortTex and LearnedTextureDurations[shortTex] then
        return LearnedTextureDurations[shortTex]
    end

    return 12
end

local function GetTargetDebuffName(slotIndex)
    ScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    ScanTooltip:ClearLines()
    ScanTooltip:SetUnitDebuff("target", slotIndex)
    local nameRegion = getglobal("OctoThreat_ScanTooltipTextLeft1")
    local name = nameRegion and nameRegion:GetText()
    if name and name ~= "" then
        return name
    end
    return nil
end

-- ==========================================================
-- 3. UI CREATION: WOTLK BEVELED THREAT TAB + ALT-DRAG SUPPORT
-- ==========================================================

local ApplyBoxLayout -- forward declaration

local function CreateWotLKThreatTab(name, parent, width, height, point, relFrame, relPoint, xOff, yOff, hasTopGlow)
    local f = CreateFrame("Frame", name, parent)
    f:SetWidth(width)
    f:SetHeight(height)
    f:SetPoint(point, relFrame, relPoint, xOff, yOff)
    f:SetFrameLevel(parent:GetFrameLevel() + 6)

    -- Optional Top Aura Glow (sits behind the tab and spreads along the top border of TargetFrame)
    if hasTopGlow then
        local topGlow = f:CreateTexture(name.."TopGlow", "BACKGROUND")
        topGlow:SetTexture(TEX_TOP_GLOW)
        topGlow:SetBlendMode("ADD")
        topGlow:SetWidth(width * 2.5)
        topGlow:SetHeight(height * 1.9)
        topGlow:SetPoint("BOTTOM", f, "BOTTOM", 0, -5)
        topGlow:SetVertexColor(1.0, 0.85, 0.15, 0.85)
        topGlow:Hide()
        f.topGlow = topGlow
    end

    -- Layer 1: Inner Glossy Colored Fill (shaped to fit inside the chamfered tab)
    local fill = f:CreateTexture(name.."Fill", "BORDER")
    fill:SetTexture(TEX_TAB_FILL)
    fill:SetTexCoord(0, 1, 0, 0.6875)
    fill:SetAllPoints(f)
    fill:SetVertexColor(0.95, 0.82, 0.18, 1)

    -- Layer 2: Beveled Metallic WotLK Tab Frame (with chamfered top & flared bottom feet)
    local border = f:CreateTexture(name.."Border", "ARTWORK")
    border:SetTexture(TEX_TAB_BORDER)
    border:SetTexCoord(0, 1, 0, 0.6875)
    border:SetAllPoints(f)

    -- Layer 3: Centered Percentage Text (like "93%")
    local text = f:CreateFontString(name.."Text", "OVERLAY", "GameFontHighlightSmall")
    text:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    text:SetPoint("CENTER", f, "CENTER", 0, -1)
    text:SetTextColor(1, 1, 1, 1)
    text:SetText("0%")

    f.fill = fill
    f.border = border
    f.text = text
    f:Hide()
    return f
end

-- Primary WotLK Numerical Threat Tab on TargetFrame
local TargetThreatUI = CreateWotLKThreatTab(
    "OctoThreat_TargetTab", TargetFrame, 64, 22,
    "BOTTOM", TargetFrameNameBackground, "TOP", 0, 2, true
)

-- Enable ALT + Left-Click Drag & Drop on TargetThreatUI
TargetThreatUI:EnableMouse(true)
TargetThreatUI:SetMovable(true)
TargetThreatUI:RegisterForDrag("LeftButton")

local function StartTargetTabDrag(frame)
    if IsAltKeyDown() and not frame.isDragging then
        frame.isDragging = true
        frame:StartMoving()
    end
end

local function StopTargetTabDrag(frame)
    if frame.isDragging then
        frame:StopMovingOrSizing()
        frame.isDragging = false

        local cx, cy = frame:GetCenter()
        local px, py = TargetFrame:GetCenter()
        if cx and cy and px and py then
            OctoThreatDB.anchorMode = "CUSTOM"
            OctoThreatDB.dragX = math.floor((cx - px) + 0.5)
            OctoThreatDB.dragY = math.floor((cy - py) + 0.5)
            ApplyBoxLayout()
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[OctoThreat]|r Threat Tab position saved (X=" .. OctoThreatDB.dragX .. ", Y=" .. OctoThreatDB.dragY .. ").")
        end
    end
end

TargetThreatUI:SetScript("OnMouseDown", function()
    if arg1 == "LeftButton" and IsAltKeyDown() then
        StartTargetTabDrag(this)
    end
end)

TargetThreatUI:SetScript("OnMouseUp", function()
    if arg1 == "LeftButton" and this.isDragging then
        StopTargetTabDrag(this)
    end
end)

TargetThreatUI:SetScript("OnDragStart", function()
    StartTargetTabDrag(this)
end)

TargetThreatUI:SetScript("OnDragStop", function()
    StopTargetTabDrag(this)
end)

TargetThreatUI:SetScript("OnHide", function()
    if this.isDragging then
        StopTargetTabDrag(this)
    end
end)

-- Optional WotLK Numerical Threat Tab on PlayerFrame
local PlayerThreatUI = CreateWotLKThreatTab(
    "OctoThreat_PlayerTab", PlayerFrame, 58, 20,
    "TOP", PlayerFrameManaBar, "BOTTOM", 6, -3, false
)

-- Full TargetFrame Wrap-Around Glow (UI-TargetingFrame-Flash)
local TargetFrameGlow = TargetFrame:CreateTexture("OctoThreat_TargetFrameGlow", "BACKGROUND")
TargetFrameGlow:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Flash")
TargetFrameGlow:SetBlendMode("ADD")
TargetFrameGlow:SetWidth(242)
TargetFrameGlow:SetHeight(93)
TargetFrameGlow:SetPoint("TOPLEFT", TargetFrame, "TOPLEFT", -24, 0)
TargetFrameGlow:SetTexCoord(0, 0.9453125, 0, 0.181640625)
TargetFrameGlow:SetVertexColor(1, 0.2, 0.1, 0.85)
TargetFrameGlow:Hide()

-- Party 1-4 Threat Tabs (Right of Party Member Health/Mana Bars)
local PartyThreatUI = {}
for i = 1, 4 do
    local partyFrame = getglobal("PartyMemberFrame"..i)
    local healthBar = getglobal("PartyMemberFrame"..i.."HealthBar")
    if partyFrame and healthBar then
        PartyThreatUI[i] = CreateWotLKThreatTab(
            "OctoThreat_PartyTab"..i, partyFrame, 48, 18,
            "LEFT", healthBar, "RIGHT", 4, -4, false
        )
    end
end

local function EnsureDefaults()
    if not OctoThreatDB then OctoThreatDB = {} end
    if not OctoThreatDB.anchorMode then OctoThreatDB.anchorMode = "NAME" end
    if OctoThreatDB.offsetX == nil then OctoThreatDB.offsetX = 0 end
    if OctoThreatDB.offsetY == nil then OctoThreatDB.offsetY = 2 end
    if not OctoThreatDB.tabWidth then OctoThreatDB.tabWidth = 64 end
    if not OctoThreatDB.tabHeight then OctoThreatDB.tabHeight = 22 end
    if OctoThreatDB.showPlayerBar == nil then OctoThreatDB.showPlayerBar = false end
    if OctoThreatDB.showTargetDebuffTimers == nil then OctoThreatDB.showTargetDebuffTimers = true end
    if OctoThreatDB.enableGlow == nil then OctoThreatDB.enableGlow = true end
end

ApplyBoxLayout = function()
    EnsureDefaults()
    local xOff = OctoThreatDB.offsetX
    local yOff = OctoThreatDB.offsetY
    local w = OctoThreatDB.tabWidth
    local h = OctoThreatDB.tabHeight

    TargetThreatUI:ClearAllPoints()
    TargetThreatUI:SetWidth(w)
    TargetThreatUI:SetHeight(h)

    if OctoThreatDB.anchorMode == "CUSTOM" and OctoThreatDB.dragX and OctoThreatDB.dragY then
        -- Custom dragged position via ALT + Left-Click
        TargetThreatUI:SetPoint("CENTER", TargetFrame, "CENTER", OctoThreatDB.dragX, OctoThreatDB.dragY)
    elseif OctoThreatDB.anchorMode == "PORTRAIT" then
        TargetThreatUI:SetPoint("BOTTOM", TargetFramePortrait, "TOP", xOff, yOff)
    else
        -- Default "NAME": Sits flush on top of the gold border above Target's Name Bar
        TargetThreatUI:SetPoint("BOTTOM", TargetFrameNameBackground, "TOP", xOff, yOff)
    end

    if TargetThreatUI.topGlow then
        TargetThreatUI.topGlow:SetWidth(w * 2.5)
        TargetThreatUI.topGlow:SetHeight(h * 1.9)
    end
end

-- ==========================================================
-- 4. PLATER-STYLE TARGET DEBUFF CLOCK & COUNTDOWN (OMNICC BLOCKED)
-- ==========================================================

-- Completely blocks OmniCC / CooldownCount on TargetFrameDebuff buttons
local function SuppressExternalCooldownsOnButton(btn)
    if not btn then return end
    btn.noomnicc = true
    btn.noCooldownCount = true

    local children = { btn:GetChildren() }
    for i = 1, table.getn(children) do
        local child = children[i]
        if child and child ~= btn.octoOverlay and child ~= btn.octoTextFrame then
            child.noomnicc = true
            child.noCooldownCount = true
            if child:GetObjectType() == "Model" then
                child:Hide()
                child:SetAlpha(0)
            end
        end
    end
end

local function GetOrCreateTargetDebuffOverlay(index)
    if DebuffHooked[index] then return DebuffHooked[index] end

    local btn = getglobal("TargetFrameDebuff" .. index)
    if not btn then return nil end

    -- Mark button so OmniCC / CooldownCount never hooks it
    btn.noomnicc = true
    btn.noCooldownCount = true

    -- Layer 1: Clockwise 4-Quadrant Shade Sweep Frame (Matches Plater's exact clock-sweep look, zero CooldownFrameTemplate!)
    local overlay = CreateFrame("Frame", "OctoThreat_TargetDebuffSweep" .. index, btn)
    overlay:EnableMouse(false)
    overlay:SetAllPoints(btn)
    overlay:SetFrameLevel(btn:GetFrameLevel() + 2)
    overlay.noomnicc = true
    overlay.noCooldownCount = true
    btn.octoOverlay = overlay

    local qTR = overlay:CreateTexture(nil, "ARTWORK")
    qTR:SetTexture("Interface\\Buttons\\WHITE8X8")
    qTR:SetVertexColor(0.02, 0.02, 0.02, 0.76)
    qTR:SetPoint("TOPLEFT", overlay, "TOP", 0, 0)
    qTR:SetWidth(9)
    qTR:SetHeight(0.1)
    qTR:Hide()

    local qBR = overlay:CreateTexture(nil, "ARTWORK")
    qBR:SetTexture("Interface\\Buttons\\WHITE8X8")
    qBR:SetVertexColor(0.02, 0.02, 0.02, 0.76)
    qBR:SetPoint("TOPRIGHT", overlay, "RIGHT", 0, 0)
    qBR:SetHeight(9)
    qBR:SetWidth(0.1)
    qBR:Hide()

    local qBL = overlay:CreateTexture(nil, "ARTWORK")
    qBL:SetTexture("Interface\\Buttons\\WHITE8X8")
    qBL:SetVertexColor(0.02, 0.02, 0.02, 0.76)
    qBL:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", 0, 0)
    qBL:SetWidth(9)
    qBL:SetHeight(0.1)
    qBL:Hide()

    local qTL = overlay:CreateTexture(nil, "ARTWORK")
    qTL:SetTexture("Interface\\Buttons\\WHITE8X8")
    qTL:SetVertexColor(0.02, 0.02, 0.02, 0.76)
    qTL:SetPoint("TOPLEFT", overlay, "TOPLEFT", 0, 0)
    qTL:SetHeight(9)
    qTL:SetWidth(0.1)
    qTL:Hide()

    -- Layer 2: High-Level Plater-Style Countdown Text Frame
    local textFrame = CreateFrame("Frame", "OctoThreat_TargetDebuffText" .. index, btn)
    textFrame:EnableMouse(false)
    textFrame:SetAllPoints(btn)
    textFrame:SetFrameLevel(btn:GetFrameLevel() + 5)
    textFrame.noomnicc = true
    textFrame.noCooldownCount = true
    btn.octoTextFrame = textFrame

    local timeText = textFrame:CreateFontString(nil, "OVERLAY")
    timeText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    timeText:SetPoint("CENTER", textFrame, "CENTER", 0, 0)
    timeText:SetTextColor(1, 1, 1, 1)
    timeText:SetShadowColor(0, 0, 0, 1)
    timeText:SetShadowOffset(1, -1)

    DebuffHooked[index] = {
        btn = btn,
        overlay = overlay,
        textFrame = textFrame,
        qTR = qTR,
        qBR = qBR,
        qBL = qBL,
        qTL = qTL,
        timeText = timeText,
    }
    return DebuffHooked[index]
end

local function UpdateTargetDebuffClockVisual(ov, startTime, duration, now)
    local elapsed = now - startTime
    local remaining = duration - elapsed
    if remaining < 0 then remaining = 0 end
    local progress = elapsed / duration
    if progress < 0 then progress = 0 end
    if progress > 1 then progress = 1 end

    -- Dynamically adapt to 1.12.1 TargetFrameDebuff icon size (17x17 or 21x21)
    local btnW = ov.btn:GetWidth() or 17
    local btnH = ov.btn:GetHeight() or 17
    local halfW = btnW * 0.5
    local halfH = btnH * 0.5

    local q1 = math.min(1, progress * 4)
    local q2 = math.max(0, math.min(1, (progress - 0.25) * 4))
    local q3 = math.max(0, math.min(1, (progress - 0.50) * 4))
    local q4 = math.max(0, math.min(1, (progress - 0.75) * 4))

    if q1 > 0 then
        ov.qTR:SetWidth(halfW)
        ov.qTR:SetHeight(math.max(0.1, halfH * q1))
        ov.qTR:Show()
    else
        ov.qTR:Hide()
    end

    if q2 > 0 then
        ov.qBR:SetHeight(halfH)
        ov.qBR:SetWidth(math.max(0.1, halfW * q2))
        ov.qBR:Show()
    else
        ov.qBR:Hide()
    end

    if q3 > 0 then
        ov.qBL:SetWidth(halfW)
        ov.qBL:SetHeight(math.max(0.1, halfH * q3))
        ov.qBL:Show()
    else
        ov.qBL:Hide()
    end

    if q4 > 0 then
        ov.qTL:SetHeight(halfH)
        ov.qTL:SetWidth(math.max(0.1, halfW * q4))
        ov.qTL:Show()
    else
        ov.qTL:Hide()
    end

    -- Plater-Style Numeric Countdown & Color Transitions
    ov.timeText:SetText(FormatCooldownTime(remaining))
    if remaining <= 3.5 then
        ov.timeText:SetTextColor(1.0, 0.22, 0.22, 1) -- Urgent Red (decimal)
    elseif remaining <= 6.0 then
        ov.timeText:SetTextColor(1.0, 0.88, 0.12, 1) -- Warning Yellow
    else
        ov.timeText:SetTextColor(1.0, 1.0, 1.0, 1)   -- Crisp White
    end

    ov.overlay:Show()
    ov.textFrame:Show()
end

local function HideTargetDebuffOverlay(ov)
    if not ov then return end
    ov.qTR:Hide()
    ov.qBR:Hide()
    ov.qBL:Hide()
    ov.qTL:Hide()
    ov.timeText:SetText("")
    ov.overlay:Hide()
    ov.textFrame:Hide()
end

local function RecordTargetDebuff(unitName, spellName)
    if not unitName or not spellName then return end
    local entry = Octo_DebuffByName and Octo_DebuffByName[spellName]
    local icon = (entry and entry.icon) or LearnedSpellIcons[spellName] or nil

    if not icon and UnitExists("target") and UnitName("target") == unitName then
        for d = 1, 16 do
            local dTex = UnitDebuff("target", d)
            if dTex then
                local sName = GetTargetDebuffName(d)
                if sName == spellName then
                    icon = dTex
                    break
                end
            end
        end
    end

    if not icon then return end
    local shortTex = ExtractShortTexture(icon)
    local duration = GetDynamicDebuffDuration(spellName, shortTex)

    if not TargetDebuffTimers[unitName] then
        TargetDebuffTimers[unitName] = {}
    end

    TargetDebuffTimers[unitName][shortTex] = {
        spell = spellName,
        tex = icon,
        startTime = GetTime(),
        duration = duration,
    }
end

local function RemoveTargetDebuff(unitName, spellName)
    if not unitName or not spellName or not TargetDebuffTimers[unitName] then return end
    local entry = Octo_DebuffByName and Octo_DebuffByName[spellName]
    local icon = (entry and entry.icon) or LearnedSpellIcons[spellName]
    if icon then
        local shortTex = ExtractShortTexture(icon)
        TargetDebuffTimers[unitName][shortTex] = nil
    end
    for k, v in pairs(TargetDebuffTimers[unitName]) do
        if v.spell == spellName then
            TargetDebuffTimers[unitName][k] = nil
        end
    end
end

local function UpdateTargetFrameDebuffTimers()
    if not OctoThreatDB.showTargetDebuffTimers or not UnitExists("target") then
        for i = 1, 16 do
            HideTargetDebuffOverlay(DebuffHooked[i])
        end
        return
    end

    local targetName = UnitName("target")
    if not targetName or targetName == "" then return end

    if not TargetDebuffTimers[targetName] then
        TargetDebuffTimers[targetName] = {}
    end

    local now = GetTime()
    local seenOnTarget = {}

    for i = 1, 16 do
        local dTex = UnitDebuff("target", i)
        local ov = GetOrCreateTargetDebuffOverlay(i)

        if dTex and ov and ov.btn:IsShown() then
            SuppressExternalCooldownsOnButton(ov.btn)

            local shortTex = ExtractShortTexture(dTex)
            seenOnTarget[shortTex] = true

            local tracked = TargetDebuffTimers[targetName][shortTex]
            if not tracked or (now - tracked.startTime) >= tracked.duration then
                local sName = GetTargetDebuffName(i)
                local exactDur = GetDynamicDebuffDuration(sName, shortTex)
                tracked = {
                    spell = sName,
                    tex = dTex,
                    startTime = now,
                    duration = exactDur,
                }
                TargetDebuffTimers[targetName][shortTex] = tracked
            end

            UpdateTargetDebuffClockVisual(ov, tracked.startTime, tracked.duration, now)
        elseif ov then
            HideTargetDebuffOverlay(ov)
        end
    end

    for k, _ in pairs(TargetDebuffTimers[targetName]) do
        if not seenOnTarget[k] then
            TargetDebuffTimers[targetName][k] = nil
        end
    end
end

-- ==========================================================
-- 5. WOTLK THREAT TAB COLOR & TARGET GLOW ENGINE
-- ==========================================================

local function ApplyThreatTabStyle(uiFrame, pct, isMainTarget)
    local rounded = math.floor(pct + 0.5)
    uiFrame.text:SetText(rounded .. "%")

    -- Gentle pulse factor (0.70 .. 1.0) for high-threat / aggro glow
    local pulse = 0.84 + 0.16 * math.sin(GetTime() * 6.5)

    if pct >= 100 then
        -- STATUS 3: AGGRO / OVER-THREAT (Crimson Red Fill + Pulsing Red Glows)
        uiFrame.fill:SetVertexColor(0.95, 0.14, 0.14, 1.0)
        if isMainTarget then
            if OctoThreatDB.enableGlow then
                if uiFrame.topGlow then
                    uiFrame.topGlow:SetVertexColor(1.0, 0.12, 0.12, 0.95 * pulse)
                    uiFrame.topGlow:Show()
                end
                TargetFrameGlow:SetVertexColor(1.0, 0.10, 0.10, 0.90 * pulse)
                TargetFrameGlow:Show()
            else
                if uiFrame.topGlow then uiFrame.topGlow:Hide() end
                TargetFrameGlow:Hide()
            end
        end
    elseif pct >= 80 then
        -- STATUS 2: HIGH THREAT WARNING 80-99% (WotLK Gold/Yellow Fill like 93% in screenshot + Warm Glow)
        uiFrame.fill:SetVertexColor(0.96, 0.82, 0.22, 1.0)
        if isMainTarget then
            if OctoThreatDB.enableGlow then
                if uiFrame.topGlow then
                    uiFrame.topGlow:SetVertexColor(1.0, 0.85, 0.20, 0.90 * pulse)
                    uiFrame.topGlow:Show()
                end
                TargetFrameGlow:SetVertexColor(1.0, 0.65, 0.12, 0.65 * pulse)
                TargetFrameGlow:Show()
            else
                if uiFrame.topGlow then uiFrame.topGlow:Hide() end
                TargetFrameGlow:Hide()
            end
        end
    elseif pct >= 50 then
        -- STATUS 1: MEDIUM THREAT 50-79% (Amber-Olive Fill + Subtle Top Glow)
        uiFrame.fill:SetVertexColor(0.85, 0.72, 0.24, 1.0)
        if isMainTarget then
            if OctoThreatDB.enableGlow and uiFrame.topGlow then
                uiFrame.topGlow:SetVertexColor(1.0, 0.85, 0.25, 0.55)
                uiFrame.topGlow:Show()
            elseif uiFrame.topGlow then
                uiFrame.topGlow:Hide()
            end
            TargetFrameGlow:Hide()
        end
    else
        -- STATUS 0: SAFE ZONE <50% (Muted Olive-Green / Grey-Bronze, No Glow)
        uiFrame.fill:SetVertexColor(0.42, 0.62, 0.38, 1.0)
        if isMainTarget then
            if uiFrame.topGlow then uiFrame.topGlow:Hide() end
            TargetFrameGlow:Hide()
        end
    end
end

-- ==========================================================
-- 6. THREAT & TAUNT/GROWL ENGINE (1.12.1 + Hunter Pet Fix)
-- ==========================================================

local function AddUnitThreat(unitName, amount)
    if not unitName or unitName == "" then return end
    local current = ThreatData[unitName] or 0
    local updated = current + amount
    if updated < 0 then updated = 0 end
    ThreatData[unitName] = updated
end

local function ResetAllThreat()
    ThreatData = {}
    CurrentTank = OctoThreatDB and OctoThreatDB.customTank or nil
    LastAggroHolder = nil
end

local function GetUnitThreatValue(unitName)
    if not unitName then return 0 end
    if klhtm and klhtm.table and klhtm.table.raiddata and klhtm.table.raiddata[unitName] then
        return klhtm.table.raiddata[unitName]
    end
    return ThreatData[unitName] or 0
end

local function GetHighestTableThreat()
    local playerName = UnitName("player")
    local maxThreat = GetUnitThreatValue(playerName)

    if UnitExists("pet") then
        local petT = GetUnitThreatValue(UnitName("pet"))
        if petT > maxThreat then maxThreat = petT end
    end

    for i = 1, 4 do
        if UnitExists("party"..i) then
            local pT = GetUnitThreatValue(UnitName("party"..i))
            if pT > maxThreat then maxThreat = pT end
        end
    end

    for name, val in pairs(ThreatData) do
        if val > maxThreat then
            maxThreat = val
        end
    end

    return maxThreat
end

local function GetPetTauntBonusThreat()
    local lvl = 20
    if UnitExists("pet") then
        lvl = UnitLevel("pet") or 20
    else
        lvl = UnitLevel("player") or 20
    end
    return math.max(80, lvl * 7)
end

local function ApplyTauntThreatSync(taunterName)
    if not taunterName or taunterName == "" then return end
    local highestNow = GetHighestTableThreat()
    local bonus = GetPetTauntBonusThreat()
    local currentTaunterThreat = ThreatData[taunterName] or 0

    ThreatData[taunterName] = math.max(currentTaunterThreat + bonus, highestNow + bonus)
    CurrentTank = taunterName
end

local function CheckPetActionBarTaunt()
    if not UnitExists("pet") or UnitIsDead("pet") then return end
    local petName = UnitName("pet")
    if not petName then return end

    for i = 1, 10 do
        local name, _, texture = GetPetActionInfo(i)
        if name or texture then
            local lname = string.lower(name or "")
            local ltex = string.lower(texture or "")
            local isPetTaunt = (lname == "growl" or lname == "torment" or lname == "suffering")
                or string.find(ltex, "ability_physical_taunt")
                or string.find(ltex, "spell_shadow_gathershadows")
                or string.find(ltex, "spell_shadow_blackplague")

            if isPetTaunt then
                local start, duration = GetPetActionCooldown(i)
                if start and start > 0 and duration and duration >= 4.0 then
                    if not LastPetCDs[i] or math.abs(start - LastPetCDs[i]) > 0.5 then
                        LastPetCDs[i] = start
                        ApplyTauntThreatSync(petName)
                    end
                end
            elseif lname == "cower" then
                local start, duration = GetPetActionCooldown(i)
                if start and start > 0 and duration and duration >= 4.0 then
                    if not LastPetCDs[i] or math.abs(start - LastPetCDs[i]) > 0.5 then
                        LastPetCDs[i] = start
                        AddUnitThreat(petName, -150)
                    end
                end
            end
        end
    end
end

local function CheckPlayerFeignDeath()
    local isFD = false
    for i = 1, 16 do
        local buffTex = UnitBuff("player", i)
        if not buffTex then break end
        if string.find(string.lower(buffTex), "ability_rogue_feigndeath") then
            isFD = true
            break
        end
    end

    if isFD and not WasFeignDeath then
        WasFeignDeath = true
        ThreatData[UnitName("player")] = 0
    elseif not isFD and WasFeignDeath then
        WasFeignDeath = false
    end
end

local function CheckAggroTransition()
    if not UnitExists("target") or not UnitCanAttack("player", "target") then
        LastAggroHolder = nil
        return
    end

    if not UnitExists("targettarget") then return end

    local totName = UnitName("targettarget")
    local playerName = UnitName("player")
    if not totName or totName == "" then return end

    if totName ~= playerName and UnitIsFriend("player", "targettarget") then
        local myThreat = GetUnitThreatValue(playerName)
        local tankThreat = GetUnitThreatValue(totName)

        if LastAggroHolder ~= totName and myThreat > tankThreat then
            ThreatData[totName] = myThreat + GetPetTauntBonusThreat()
            tankThreat = ThreatData[totName]
        end

        if myThreat > tankThreat and myThreat > 0 then
            ThreatData[totName] = myThreat + math.max(40, math.floor(myThreat * 0.12))
        end

        CurrentTank = totName
    end

    LastAggroHolder = totName
end

local function GetBaselineTankThreat()
    local playerName = UnitName("player")

    if OctoThreatDB.customTank and GetUnitThreatValue(OctoThreatDB.customTank) > 0 then
        CurrentTank = OctoThreatDB.customTank
        return GetUnitThreatValue(CurrentTank)
    end

    if UnitExists("targettarget") and UnitIsFriend("player", "targettarget") then
        local totName = UnitName("targettarget")
        if totName and totName ~= playerName then
            CurrentTank = totName
            local totThreat = GetUnitThreatValue(totName)
            if totThreat > 0 then
                return totThreat
            end
        end
    end

    if UnitExists("pet") and not UnitIsDead("pet") then
        local petName = UnitName("pet")
        local petThreat = GetUnitThreatValue(petName)
        if petThreat > 0 then
            CurrentTank = petName
            return petThreat
        end
    end

    local highestPartyThreat = 0
    for i = 1, 4 do
        if UnitExists("party"..i) then
            local pName = UnitName("party"..i)
            local pThreat = GetUnitThreatValue(pName)
            if pThreat > highestPartyThreat then
                highestPartyThreat = pThreat
                CurrentTank = pName
            end
        end
    end

    if highestPartyThreat > 0 then
        return highestPartyThreat
    end

    return GetUnitThreatValue(playerName)
end

-- ==========================================================
-- 7. UI UPDATE LOOP (WotLK Threat Tab + Glow + Debuff Timers)
-- ==========================================================

local function UpdateThreatUI()
    UpdateTargetFrameDebuffTimers()

    -- Handle Test Mode (/ot test)
    if TestMode then
        TargetThreatUI:Show()
        ApplyThreatTabStyle(TargetThreatUI, TestPctValue, true)

        if OctoThreatDB.showPlayerBar then
            PlayerThreatUI:Show()
            ApplyThreatTabStyle(PlayerThreatUI, TestPctValue, false)
        else
            PlayerThreatUI:Hide()
        end

        local samplePct = { 100, 93, 62, 24 }
        for i = 1, 4 do
            if PartyThreatUI[i] then
                PartyThreatUI[i]:Show()
                ApplyThreatTabStyle(PartyThreatUI[i], samplePct[i], false)
            end
        end
        return
    end

    -- Hide Threat UI if no valid attackable target is selected
    if not UnitExists("target") or not UnitCanAttack("player", "target") or UnitIsDead("target") then
        TargetThreatUI:Hide()
        if TargetThreatUI.topGlow then TargetThreatUI.topGlow:Hide() end
        PlayerThreatUI:Hide()
        TargetFrameGlow:Hide()
        for i = 1, 4 do
            if PartyThreatUI[i] then PartyThreatUI[i]:Hide() end
        end
        return
    end

    CheckPetActionBarTaunt()
    CheckPlayerFeignDeath()
    CheckAggroTransition()

    local tankThreat = GetBaselineTankThreat()
    local playerName = UnitName("player")
    local myThreat = GetUnitThreatValue(playerName)

    if tankThreat <= 0 and myThreat <= 0 then
        TargetThreatUI:Hide()
        if TargetThreatUI.topGlow then TargetThreatUI.topGlow:Hide() end
        PlayerThreatUI:Hide()
        TargetFrameGlow:Hide()
        for i = 1, 4 do
            if PartyThreatUI[i] then PartyThreatUI[i]:Hide() end
        end
        return
    end

    local myPctVsTank = 0
    if tankThreat > 0 then
        myPctVsTank = (myThreat / tankThreat) * 100
    elseif myThreat > 0 then
        myPctVsTank = 100
    end

    if UnitExists("targettarget") and UnitName("targettarget") == playerName and myThreat > 0 then
        if myPctVsTank < 100 then
            myPctVsTank = 100
        end
    end

    -- 1. Update WotLK Beveled Threat Tab & Glows on TargetFrame
    TargetThreatUI:Show()
    ApplyThreatTabStyle(TargetThreatUI, myPctVsTank, true)

    -- 2. Update Optional Tab on PlayerFrame
    if OctoThreatDB.showPlayerBar then
        PlayerThreatUI:Show()
        ApplyThreatTabStyle(PlayerThreatUI, myPctVsTank, false)
    else
        PlayerThreatUI:Hide()
    end

    -- 3. Update Party 1-4 Threat Tabs
    for i = 1, 4 do
        local pFrame = PartyThreatUI[i]
        if pFrame then
            if UnitExists("party"..i) then
                local pName = UnitName("party"..i)
                local pThreat = GetUnitThreatValue(pName)
                if pThreat > 0 and tankThreat > 0 then
                    local pPct = (pThreat / tankThreat) * 100
                    pFrame:Show()
                    ApplyThreatTabStyle(pFrame, pPct, false)
                else
                    pFrame:Hide()
                end
            else
                pFrame:Hide()
            end
        end
    end
end

-- ==========================================================
-- 8. COMBAT LOG PARSER (Threat + Target Debuff Timers)
-- ==========================================================

local BonusThreatSpells = {
    ["Sunder Armor"] = 260,
    ["Revenge"] = 355,
    ["Shield Slam"] = 250,
    ["Heroic Strike"] = 145,
    ["Maul"] = 300,
    ["Swipe"] = 100,
    ["Mind Blast"] = 180,
    ["Searing Pain"] = 160,
    ["Holy Shield"] = 150,
    ["Distracting Shot"] = 350,
    ["Torment"] = 250,
    ["Suffering"] = 300,
    ["Cower"] = -150,
}

local function ParseCombatMessage(msg)
    if not msg then return end
    local playerName = UnitName("player")

    -- 1. Debuff / DoT Application: "X is afflicted by Y."
    local _, _, afflictedUnit, debuffSpell = string.find(msg, "^(.+) is afflicted by ([^%(]+)%.$")
    if not afflictedUnit then
        _, _, afflictedUnit, debuffSpell = string.find(msg, "^(.+) is afflicted by (.+)%.$")
    end
    if afflictedUnit and debuffSpell then
        RecordTargetDebuff(afflictedUnit, debuffSpell)
    end

    -- 2. Debuff / DoT Removal: "Y fades from X."
    local _, _, fadedSpell, fadedUnit = string.find(msg, "^(.+) fades from (.+)%.$")
    if fadedSpell and fadedUnit then
        RemoveTargetDebuff(fadedUnit, fadedSpell)
        return
    end

    local isFailure = string.find(msg, "immune") or string.find(msg, "resist") or string.find(msg, "missed") or string.find(msg, "fades")

    -- 3. Taunt / Growl / Torment / Suffering Detection
    if not isFailure then
        if string.find(msg, "Growl") or string.find(msg, "Torment") or string.find(msg, "Suffering") then
            if UnitExists("pet") then
                ApplyTauntThreatSync(UnitName("pet"))
                return
            end
        end

        if string.find(msg, "Taunt") or string.find(msg, "Challenging Shout") or string.find(msg, "Challenging Roar") or string.find(msg, "Mocking Blow") then
            local taunter = nil
            if UnitExists("targettarget") and UnitIsFriend("player", "targettarget") then
                taunter = UnitName("targettarget")
            elseif CurrentTank then
                taunter = CurrentTank
            end
            if taunter and taunter ~= playerName then
                ApplyTauntThreatSync(taunter)
                return
            end
        end
    end

    -- 4. Hunter Feign Death / Rogue Feint / Priest Fade / Disengage
    if string.find(msg, "Feign Death") then
        ThreatData[playerName] = 0
        return
    elseif string.find(msg, "You perform Feint") or string.find(msg, "You cast Fade") then
        AddUnitThreat(playerName, -600)
        return
    elseif string.find(msg, "You perform Disengage") then
        AddUnitThreat(playerName, -300)
        return
    end

    -- 5. Self melee/ranged Auto-Shot & hits: "You hit/crit X for Y..."
    local _, _, dmg = string.find(msg, "You hit .+ for (%d+)")
    if not dmg then
        _, _, dmg = string.find(msg, "You crit .+ for (%d+)")
    end
    if dmg then
        AddUnitThreat(playerName, tonumber(dmg))
        return
    end

    -- 6. Self spell & ranged shots: "Your X hits/crits Y for Z..."
    local _, _, spell, hitTarget, sDmg = string.find(msg, "^Your (.+) hits (.+) for (%d+)")
    if not sDmg then
        _, _, spell, hitTarget, sDmg = string.find(msg, "^Your (.+) crits (.+) for (%d+)")
    end
    if spell and hitTarget and sDmg then
        if (Octo_DebuffByName and Octo_DebuffByName[spell]) or LearnedSpellDurations[spell] then
            RecordTargetDebuff(hitTarget, spell)
        end
        local bonus = BonusThreatSpells[spell] or 0
        AddUnitThreat(playerName, tonumber(sDmg) + bonus)
        return
    end

    -- 7. Distracting Shot
    if string.find(msg, "Distracting Shot") then
        AddUnitThreat(playerName, 350)
        return
    end

    -- 8. Periodic DoT damage:
    local _, _, dotDmg = string.find(msg, "suffers (%d+) .+ damage from your ")
    if dotDmg then
        AddUnitThreat(playerName, tonumber(dotDmg))
        return
    end

    -- 9. Sunder Armor
    if string.find(msg, "You perform Sunder Armor") or string.find(msg, "You cast Sunder Armor") then
        if UnitExists("target") then
            RecordTargetDebuff(UnitName("target"), "Sunder Armor")
        end
        AddUnitThreat(playerName, 260)
        return
    end

    -- 10. Pet / Party melee hits
    local _, _, actor, oDmg = string.find(msg, "^([^%s]+) hits .+ for (%d+)")
    if not oDmg then
        _, _, actor, oDmg = string.find(msg, "^([^%s]+) crits .+ for (%d+)")
    end
    if actor and oDmg then
        AddUnitThreat(actor, tonumber(oDmg))
        return
    end

    -- 11. Pet / Party spell & special attacks
    local _, _, sActor, oSpell, osDmg = string.find(msg, "^([^%s]+)'s (.+) hits .+ for (%d+)")
    if not osDmg then
        _, _, sActor, oSpell, osDmg = string.find(msg, "^([^%s]+)'s (.+) crits .+ for (%d+)")
    end
    if sActor and osDmg then
        local bonus = BonusThreatSpells[oSpell] or 0
        AddUnitThreat(sActor, tonumber(osDmg) + bonus)
        return
    end
end

-- ==========================================================
-- 9. EVENT HANDLER & SLASH COMMANDS
-- ==========================================================

local EventFrame = CreateFrame("Frame", "OctoThreat_EventFrame")
EventFrame:RegisterEvent("VARIABLES_LOADED")
EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
EventFrame:RegisterEvent("PLAYER_LEVEL_UP")
EventFrame:RegisterEvent("SPELLS_CHANGED")
EventFrame:RegisterEvent("LEARNED_SPELL_IN_TAB")
EventFrame:RegisterEvent("CHARACTER_POINTS_CHANGED")
EventFrame:RegisterEvent("PLAYER_COMBO_POINTS")
EventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
EventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
EventFrame:RegisterEvent("UNIT_AURA")
EventFrame:RegisterEvent("CHAT_MSG_COMBAT_SELF_HITS")
EventFrame:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
EventFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE")
EventFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE")
EventFrame:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_OTHER")
EventFrame:RegisterEvent("CHAT_MSG_COMBAT_PARTY_HITS")
EventFrame:RegisterEvent("CHAT_MSG_SPELL_PARTY_DAMAGE")
EventFrame:RegisterEvent("CHAT_MSG_COMBAT_PET_HITS")
EventFrame:RegisterEvent("CHAT_MSG_SPELL_PET_DAMAGE")
EventFrame:RegisterEvent("CHAT_MSG_SPELL_PET_BUFF")
EventFrame:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE")
EventFrame:RegisterEvent("CHAT_MSG_SPELL_SELF_BUFF")
EventFrame:RegisterEvent("CHAT_MSG_SPELL_PARTY_BUFF")
EventFrame:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")

EventFrame:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        ApplyBoxLayout()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[OctoThreat]|r v4.2 loaded (WotLK Tab + ALT+Click Drag + Plater-Style Debuff Counter, OmniCC Blocked). Type |cffffff00/ot|r for commands.")
    elseif event == "PLAYER_ENTERING_WORLD" then
        ApplyBoxLayout()
        ScanPlayerSpellbook()
    elseif event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_TAB" or event == "PLAYER_LEVEL_UP" or event == "CHARACTER_POINTS_CHANGED" then
        ScanPlayerSpellbook()
    elseif event == "PLAYER_COMBO_POINTS" then
        if GetComboPoints and GetComboPoints() > 0 then
            LastComboPoints = GetComboPoints()
        end
    elseif event == "PLAYER_REGEN_ENABLED" or event == "CHAT_MSG_COMBAT_HOSTILE_DEATH" then
        ResetAllThreat()
        UpdateThreatUI()
    elseif event == "PLAYER_TARGET_CHANGED" then
        local newTarget = UnitExists("target") and UnitName("target") or nil
        if newTarget ~= LastTargetName then
            LastTargetName = newTarget
            LastAggroHolder = nil
        end
        UpdateThreatUI()
    elseif event == "UNIT_AURA" then
        if arg1 == "target" then
            UpdateTargetFrameDebuffTimers()
        end
    else
        ParseCombatMessage(arg1)
    end
end)

EventFrame:SetScript("OnUpdate", function()
    UpdateTimer = UpdateTimer + arg1
    if UpdateTimer >= 0.05 then
        UpdateTimer = 0
        UpdateThreatUI()
    end
end)

-- Slash Commands (/ot or /octothreat)
SLASH_OCTOTHREAT1 = "/ot"
SLASH_OCTOTHREAT2 = "/octothreat"
SlashCmdList["OCTOTHREAT"] = function(msg)
    local raw = msg or ""
    local _, _, cmd, rest = string.find(raw, "^(%S*)%s*(.-)$")
    cmd = string.lower(cmd or "")

    if cmd == "test" then
        local numArg = tonumber(rest)
        if numArg then
            TestPctValue = numArg
            TestMode = true
        else
            TestMode = not TestMode
            TestPctValue = 93
        end
        if TestMode then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[OctoThreat]|r Test Mode enabled ("..TestPctValue.."%). Hold |cffffff00ALT + Left-Click|r to drag the tab anywhere!")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[OctoThreat]|r Test Mode disabled.")
        end
        UpdateThreatUI()
    elseif cmd == "pos" then
        local mode = string.upper(rest or "")
        OctoThreatDB.dragX = nil
        OctoThreatDB.dragY = nil
        if mode == "PORTRAIT" or (mode == "" and OctoThreatDB.anchorMode == "NAME") then
            OctoThreatDB.anchorMode = "PORTRAIT"
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[OctoThreat]|r Threat Tab position set to: ABOVE PORTRAIT.")
        else
            OctoThreatDB.anchorMode = "NAME"
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[OctoThreat]|r Threat Tab position set to: ABOVE TARGET NAME BAR (WotLK Style).")
        end
        ApplyBoxLayout()
    elseif cmd == "glow" then
        OctoThreatDB.enableGlow = not OctoThreatDB.enableGlow
        UpdateThreatUI()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[OctoThreat]|r Target Threat Glow: " .. (OctoThreatDB.enableGlow and "ON" or "OFF"))
    elseif cmd == "offset" then
        local _, _, xStr, yStr = string.find(rest, "^([%-]?%d+)%s+([%-]?%d+)$")
        if xStr and yStr then
            OctoThreatDB.anchorMode = "NAME"
            OctoThreatDB.dragX = nil
            OctoThreatDB.dragY = nil
            OctoThreatDB.offsetX = tonumber(xStr)
            OctoThreatDB.offsetY = tonumber(yStr)
            ApplyBoxLayout()
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[OctoThreat]|r Tab offset set to X="..xStr..", Y="..yStr)
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[OctoThreat]|r Usage: /ot offset <x> <y> (Default: /ot offset 0 2)")
        end
    elseif cmd == "size" then
        local _, _, wStr, hStr = string.find(rest, "^(%d+)%s+(%d+)$")
        if wStr and hStr then
            OctoThreatDB.tabWidth = tonumber(wStr)
            OctoThreatDB.tabHeight = tonumber(hStr)
            ApplyBoxLayout()
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[OctoThreat]|r Tab size set to "..wStr.."x"..hStr)
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[OctoThreat]|r Usage: /ot size <width> <height> (Default: /ot size 64 22)")
        end
    elseif cmd == "debuffs" then
        OctoThreatDB.showTargetDebuffTimers = not OctoThreatDB.showTargetDebuffTimers
        UpdateTargetFrameDebuffTimers()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[OctoThreat]|r Plater-Style Target Debuff Timers: " .. (OctoThreatDB.showTargetDebuffTimers and "ON" or "OFF"))
    elseif cmd == "playerbar" then
        OctoThreatDB.showPlayerBar = not OctoThreatDB.showPlayerBar
        UpdateThreatUI()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[OctoThreat]|r Secondary tab under PlayerFrame: " .. (OctoThreatDB.showPlayerBar and "ON" or "OFF"))
    elseif cmd == "tank" then
        if UnitExists("target") and UnitIsFriend("player", "target") then
            OctoThreatDB.customTank = UnitName("target")
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[OctoThreat]|r Main Tank locked to: " .. OctoThreatDB.customTank)
        else
            OctoThreatDB.customTank = nil
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[OctoThreat]|r Tank detection set to Automatic.")
        end
    elseif cmd == "reset" then
        ResetAllThreat()
        UpdateThreatUI()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[OctoThreat]|r Threat table has been reset.")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[OctoThreat v4.2 Commands]:|r")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00ALT + Left-Click Drag|r - Move Threat Tab anywhere & auto-save position")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/ot test|r - Preview 93% WotLK Tab + Yellow Glow (or |cffffff00/ot test 100|r for Red Aggro Glow)")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/ot pos|r - Reset position to Target Name Bar (WotLK) or Target Portrait")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/ot glow|r - Toggle Target threat glow ON/OFF")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/ot size <w> <h>|r - Adjust tab width & height (Default: 64 22)")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/ot debuffs|r - Toggle Plater-style countdown timers on TargetFrame debuffs")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/ot tank|r - Lock friendly target as Main Tank")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/ot reset|r - Reset threat table")
    end
end
