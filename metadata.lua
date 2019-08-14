return PlaceObj('ModDef', {
	'title', "Moisture Reclamation System",
	'description', "Allows building Moisture Vaporators indoors.\n\nA Moisture Vaporator logically scavenges moisture from the air in the dome, it is limited to the smaller of its own capacity, and half of the water consumed by farms, ranches, hanging gardens or the dome inself, the thought being that the water is added to the air inside the dome. Multiple Moisture vaporators will not interfere directly with each other, but are limited to the total moisure added to the air in the dome. If the dome is open, Moisture Vaporators revert to their vanilla behaviour.\n\nPermission is granted to update this mod to support the latest version of the game if I'm not around to do it myself.",
	'last_changes', "Initial version.",
	'dependencies', {
		PlaceObj('ModDependency', {
			'id', "mrudat_AllowBuildingInDome",
			'title', "Allow Building In Dome",
		}),
	},
	'id', "mrudat_MoistureReclamationSystem",
	'steam_id', "1832558644",
	'pops_desktop_uuid', "c84e9d34-2d3b-496d-a642-832aca182f2f",
	'pops_any_uuid', "910ea975-bb21-4571-83b3-ffc73739556c",
	'author', "mrudat",
	'version', 4,
	'lua_revision', 233360,
	'saved_with_revision', 245618,
	'code', {
		"Code/MoistureReclamationSystem.lua",
	},
	'saved', 1565608817,
})