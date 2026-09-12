-- Employment - Redistribution
-- Rule: a colonist that has a specialization and stays continuously unemployed
-- for N sols (mod option, default 3, 1-30) is reset to 'No specialization'.
-- Excluded: Children, Seniors, and colonists that already have no specialization.

local rawget = rawget
local pcall = pcall
local pairs = pairs
local type = type
local tostring = tostring

local DEBUG = false -- set to true to log to the game console

local function Log(...)
	if DEBUG then
		print("[EmploymentRedist]", ...)
	end
end

-- Option keys (must match the ModItemOptionToggle / ModItemOptionNumber names)
local enable_key     = "Enable_Unemployment_Redist"
local threshold_key = "Unemployment_Redist_Sols"

local mod = {}
mod[enable_key]    = true
mod[threshold_key] = 3

-- consecutive-unemployment counter per colonist (weak keys: entries vanish
-- automatically when the colonist is destroyed)
local unemp_days = setmetatable({}, { __mode = "k" })

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function GetThreshold()
	local t = mod[threshold_key]
	if type(t) ~= "number" or t < 1 then
		t = 3
	end
	return math.floor(t + 0.5)
end

-- The game models every specialization as a trait; 'none' is the
-- 'No specialization' trait. We only act on a real specialization.
local function HasRealSpecialization(c)
	local spec = c.specialist
	if type(spec) ~= "string" or spec == "" or spec == "none" then
		return false
	end
	-- the game registers every valid specialization as a key of const.ColonistSpecialization
	local const_tbl = rawget(_G, "const")
	if const_tbl and const_tbl.ColonistSpecialization and not const_tbl.ColonistSpecialization[spec] then
		return false
	end
	return true
end

-- Eligible for the rule: not a child, not a senior, has a real specialization
local function IsEligible(c)
	if not IsValid(c) then
		return false
	end
	local traits = c.traits
	if not traits then
		return false
	end
	if traits.Child or traits.Senior then
		return false
	end
	return HasRealSpecialization(c)
end

local function ResetSpecialization(c)
	local spec = c.specialist
	Log("ResetSpecialization:", c.name or tostring(c), "spec=", tostring(spec))
	local ok1, err1 = pcall(function()
		c:RemoveTrait(spec, true) -- ignore_missing = true
	end)
	local ok2, err2 = pcall(function()
		c:AddTrait("none") -- its OnApply calls colonist:SetSpecialization("none")
	end)
	if not ok1 then
		Log("ResetSpecialization: RemoveTrait error:", tostring(err1))
	end
	if not ok2 then
		Log("ResetSpecialization: AddTrait error:", tostring(err2))
	end
	return ok1 and ok2
end

-- Counters must reflect CONSECUTIVE unemployment: clear them for anyone
-- who is no longer in the Unemployed label, or whose object has vanished.
local function CleanupCounters(unemployed)
	local present = {}
	for _, c in ipairs(unemployed) do
		present[c] = true
	end
	for c in pairs(unemp_days) do
		if not IsValid(c) or not present[c] then
			Log("CleanupCounters: clearing counter for", c.name or tostring(c), "days=", tostring(unemp_days[c]))
			unemp_days[c] = nil
		end
	end
end

local function ClearAllCounters(reason)
	for c in pairs(unemp_days) do
		unemp_days[c] = nil
	end
	Log("ClearAllCounters:", tostring(reason))
end

--------------------------------------------------------------------------------
-- Mod options
--------------------------------------------------------------------------------

local function ModOptions(id)
	if id and id ~= CurrentModId then
		return
	end

	local options = CurrentModOptions
	if not options then
		Log("ModOptions: CurrentModOptions is nil")
		return
	end

	local ok1, enable_val = pcall(options.GetProperty, options, enable_key)
	local ok2, sol_val    = pcall(options.GetProperty, options, threshold_key)

	if ok1 then
		mod[enable_key] = enable_val and true or false
	end
	if ok2 and type(sol_val) == "number" then
		mod[threshold_key] = math.floor(sol_val + 0.5)
	end

	Log(
		"ModOptions: enabled=", tostring(mod[enable_key]),
		" threshold_sols=", tostring(mod[threshold_key])
	)
end

OnMsg.ModsReloaded    = ModOptions
OnMsg.ApplyModOptions = ModOptions

--------------------------------------------------------------------------------
-- Counters reset on new game / load / unload
--------------------------------------------------------------------------------

function OnMsg.NewGame()
	ClearAllCounters("NewGame")
end

function OnMsg.PostLoadGame()
	ClearAllCounters("PostLoadGame")
end

function OnMsg.ModUnloadLua(id)
	ClearAllCounters("ModUnloadLua")
end

--------------------------------------------------------------------------------
-- Main: once per sol
--------------------------------------------------------------------------------

function OnMsg.NewDay(day)
	if not mod[enable_key] then
		Log("NewDay: mod disabled, skipping")
		return
	end

	local unemployed = UICity.labels.Unemployed or empty_table
	local threshold = GetThreshold()

	Log("NewDay: unemployed=", #unemployed, "threshold=", threshold)

	-- 1) increment counters for eligible, still-unemployed colonists
	for _, c in ipairs(unemployed) do
		if IsEligible(c) then
			local d = (unemp_days[c] or 0) + 1
			unemp_days[c] = d

			if d >= threshold then
				Log("NewDay:", c.name or tostring(c), "unemployed", d, "sols -> reset to 'No specialization'")
				if ResetSpecialization(c) then
					unemp_days[c] = nil -- done: no more counting for this colonist
				end
				-- on failure, keep the counter so it retries next sol
			end
		end
	end

	-- 2) clear counters of everyone else (re-employed, moved, died, or no longer eligible)
	CleanupCounters(unemployed)
end
