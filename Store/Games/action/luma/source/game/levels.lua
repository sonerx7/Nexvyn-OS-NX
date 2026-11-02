-- Authored routes, not random generation. All coordinates use metres; Y is up.
local levels = {}
local palettes = {
  {sky="#72BBD4",horizon="#D4E9DC",ground="#83B87C",edge="#B8D692",rock="#A78B76",accent="#FFC880",prop="tree",detail="flowers"},
  {sky="#75A7C5",horizon="#EAD6BB",ground="#D7AE78",edge="#F4CF92",rock="#AA7866",accent="#F5AD77",prop="ruins",detail="cactus"},
  {sky="#6CBACD",horizon="#C3E8DE",ground="#E4D4A3",edge="#F5E7BB",rock="#A9ADA0",accent="#6ED5C8",prop="palm",detail="coral"},
  {sky="#655D97",horizon="#BBA7CA",ground="#B498B6",edge="#D5B8CD",rock="#786B90",accent="#F3A2BD",prop="mushroom",detail="crystals"},
  {sky="#8DADC0",horizon="#DDCDBB",ground="#AA9C84",edge="#DEC395",rock="#7B8090",accent="#FFD289",prop="windmill",detail="crate"},
  {sky="#92BACC",horizon="#DDEAEF",ground="#DCE9E5",edge="#F7F4E9",rock="#8AA9BA",accent="#A6E8F4",prop="pine",detail="crystals"},
  {sky="#C4A6AD",horizon="#F0D1AB",ground="#D5AD7E",edge="#F5D09B",rock="#B78776",accent="#F7CB81",prop="cactus",detail="ruins"},
  {sky="#6F7FA9",horizon="#C0C5DB",ground="#A9BBD0",edge="#D2DEE7",rock="#737D9E",accent="#A2E3E0",prop="tower",detail="crystals"},
  {sky="#675D78",horizon="#BD8D8A",ground="#827783",edge="#B5A1A2",rock="#5B556A",accent="#FFB079",prop="brazier",detail="crystals"},
  {sky="#434B77",horizon="#B5A0B7",ground="#AAA3BC",edge="#D9C9CD",rock="#73748E",accent="#FFD48B",prop="tower",detail="lantern"},
}

function levels.count() return 10 end
function levels.palette(n) return palettes[n] end
function levels.build(n) return require("game.adventure").build(n,palettes[n]) end
return levels
