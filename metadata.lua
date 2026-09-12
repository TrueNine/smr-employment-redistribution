return PlaceObj('ModDef', {
	'title', "Employment - Redistribution",
	'description', "If a colonist that has a specialization stays continuously unemployed for the configured number of sols (default 3, adjustable 1-30), their specialization is reset to 'No specialization'. Children, Seniors and colonists that already have no specialization are not affected. Can be disabled at any time in Mod Options.",
	'short_description', "Specialized colonists continuously unemployed for N sols (default 3) are reset to 'No specialization'. Children, Seniors and already-unspecialized colonists are excluded.",
	'last_changes', "Added Unemployment Redistribution option: specialized colonists continuously unemployed for N sols are reset to 'No specialization' (excluding Children, Seniors and those without a specialization)",
	'id', "dyLFuib",
	'author', "TrueNine",
	'version', 3,
	'lua_revision', 350453,
	'saved_with_revision', 403908,
	'code', {
		"Code/Script.lua",
	},
	'default_options', {
		Enable_Unemployment_Redist = true,
		Unemployment_Redist_Sols = 3,
	},
	'saved', 1789186851,
	'code_hash', -9036395441162026515,
	'steam_id', "3800017811",
	'TagGameplay', true,
	'TagTools', true,
})