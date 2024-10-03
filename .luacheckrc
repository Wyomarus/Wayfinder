std = "lua51"
max_line_length = false
exclude_files = {
	"**/Libs/**/*.lua",
	".luacheckrc"
}
ignore = {
}

globals = {
	-- Saved Variables

	-- WIM
	"WIM",
	"debug",

	-- Lua

	-- Utility functions

	-- WoW
	"CreateFrame",
    "GetPlayerFacing",
    "IsInInstance",
    "UIParent",
    "C_Map",
    "C_QuestLog",
    "C_QuestOffer",
    "C_SuperTrack",
    "C_AreaPoiInfo",
    "C_TaxiMap",

    -- Libs
    "LibStub"
}