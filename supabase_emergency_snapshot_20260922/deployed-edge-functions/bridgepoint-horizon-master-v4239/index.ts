import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, OPTIONS"
};

const master = {
  version: 4239,
  mode: "continuous_us_streamed_world",
  replaces: "50-map-demo-selector",
  productRule: "One persistent Horizon survival universe. Stream local world cells; never render all national geometry at once.",
  engineStrategy: {
    currentClient: "Three.js/WebGL streaming client for immediate browser/mobile play",
    aaaClient: "Unreal Engine 5.x client sharing BridgePoint world APIs and persistent game state",
    browserAAA: "Unreal Pixel Streaming when a GPU host is economically justified",
    dataAuthority: "BridgePoint source-backed parcels, buildings, roads, terrain and public/open world layers",
    fictionalLayer: "Enemies, loot, barricades, fires, camps, corpses and survival dressing are game fiction and never property evidence"
  },
  legalAssetPolicy: {
    allowed: ["CC0","CC-BY with attribution","MIT","Apache-2.0","Fab Standard License when acquired by BridgePoint","Epic samples where license permits project use"],
    blocked: ["ripped Call of Duty assets","Resident Evil assets","World War Z assets","Lord of the Rings assets","unlicensed mirrors","unknown-license packs"],
    styleOnlyReferences: ["AAA military shooter movement","cinematic horror infected","dark fantasy raider/orc packs","dense open-world city life"]
  },
  world: {
    geography: "United States and jurisdictions as BridgePoint coverage becomes authoritative",
    streaming: ["geospatial cells","LOD/HLOD","async assets","occlusion","instancing","world partition in UE","cell persistence"],
    noEmptySpaceRule: "Populate traversal corridors with source-backed environment plus biome-appropriate fictional survival dressing without falsifying real-world facts",
    interiors: ["real building envelope","multiple floors","stairs","elevators where generated/known","rooms","loot containers","breakable glass","doors","rooftops","basements when data or procedural rules allow"]
  },
  movementCombat: {
    locomotion: ["walk","sprint","crouch","prone/army crawl","slide","vault","jump","lean","swim","underwater"],
    gunplay: ["ADS","reticles","scopes","snipers","recoil","spread","reload states","weapon switching","melee","hit reactions","armor zones"],
    animationGoals: ["motion matching / blend spaces","turn-in-place","correct travel-facing","upper-body aim layers","IK hand placement","foot grounding","contextual doors/vehicles"]
  },
  enemies: {
    infected: ["walker","runner","sprinter","screamer","armored police","SWAT armored","helmeted","brute","hound","bear","crow","spider"],
    raiders: ["original dark-fantasy orc-like highway packs; never LOTR assets"],
    behavior: ["precomputed patrol routes","sound/vision aggro","pack tactics","door pursuit","climbing variants","regional spawning","difficulty scaling"]
  },
  inventoryLoot: {
    hotbarSlots: 7,
    coloredIcons: true,
    backpackUX: "rarity color, stack count, weight/capacity, drag/equip/drop, quick-use",
    flashlight: "starter item occupying a usable slot; darkness matters when unequipped",
    wallCases: "clear display cases show special weapon, stats and in-game price/currency before purchase"
  },
  vehiclesTraversal: {
    road: ["cars","pickup trucks","repairable trucks","bikes"],
    air: ["airplanes/helicopters as later streaming-safe systems"],
    water: ["boats","swimming","underwater","spearfishing"],
    repair: ["battery","spark plug","tires","radiator hose","fuel","tool requirements"]
  },
  survivalBuilding: {
    resources: ["wood","metal","brick","wire","barbed wire","fencing","fuel","electronics"],
    craftables: ["campfire","wood wall","fence","barbed-wire barrier","brick barricade","generator","electric fence","storage","workbench"],
    wilderness: ["hunt regional animals","cook food","fire warmth/light","water and fishing systems"]
  },
  lighting: {
    solarCycle: "local solar day/night",
    cityLights: "streetlights and selected building lights switch on at night",
    handheld: "flashlight/weapon lights",
    weather: "BridgePoint live weather can influence fictional rendering without being confused with verified property facts"
  },
  progression: {
    battlePassLevels: 150,
    cadence: "monthly rotating season",
    rewardPolicy: "game cosmetics, characters, emotes, blueprints and approved real-world partner rewards only after legal/fulfillment review",
    endLoadedRewards: true
  },
  performance: {
    principle: "No-lag target via streaming and budgets, not by loading the entire nation at once",
    systems: ["World Partition/HLOD","Nanite where suitable in UE","virtual textures","instancing","async loading","AI significance","spawn budgets","network relevance","quality tiers","mobile fallback"]
  },
  upgradeAutopilot: {
    scoutCategories: ["graphics","characters","infected","creatures","weapons","animations","emotes","vehicles","interiors","building kits","VFX","audio","UI","gameplay systems"],
    preferredSources: ["Fab free assets","Epic samples","Quaternius","Kenney","Poly Haven","OpenGameArt where license is explicit","GitHub only with explicit reusable license"],
    gates: ["license verified","commercial-use compatible","performance budget","visual quality","does not regress current mechanics","test before promotion"],
    replacementPolicy: "Replace current placeholder assets only when the candidate passes every gate."
  }
};

Deno.serve((req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "GET") return new Response(JSON.stringify({ok:false,error:"method_not_allowed"}), {status:405,headers:{...cors,"content-type":"application/json"}});
  return new Response(JSON.stringify({ok:true,master}), {headers:{...cors,"content-type":"application/json","cache-control":"public, max-age=300"}});
});