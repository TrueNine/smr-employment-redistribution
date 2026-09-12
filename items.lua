return {
	PlaceObj('ModItemCode', {
		'CodeFileName', "Code/Script.lua",
	}),
	PlaceObj('ModItemOptionToggle', {
		'name', "Enable_Unemployment_Redist",
		'DisplayName', "Enable Unemployment Redistribution",
		'Help', "If a colonist with a specialization stays unemployed for the number of sols set below, their specialization is reset to 'No specialization'. Children, Seniors and colonists that already have no specialization are excluded. Disable to turn the mod off.",
		'DefaultValue', true,
	}),
	PlaceObj('ModItemOptionNumber', {
		'name', "Unemployment_Redist_Sols",
		'DisplayName', "Resident Unemployment Redistribution Sols",
		'Help', "A specialized colonist (excluding Children, Seniors and those without a specialization) who is continuously unemployed for this many sols is reset to 'No specialization'. Choose an integer between 1 and 30. Default is 3.",
		'DefaultValue', 3,
		'MinValue', 1,
		'MaxValue', 30,
	}),
}