import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const cors={
  "Access-Control-Allow-Origin":"*",
  "Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods":"GET, OPTIONS",
  "content-type":"application/json; charset=utf-8",
  "cache-control":"public, max-age=120"
};

const contract={
  version:4302,
  product:"BridgePoint Horizon",
  state:"playable-lobby-and-match-control-plane",
  commerce_enabled:false,
  lobby:{
    max_party:4,
    starter_characters:10,
    tabs:["PLAY","BATTLE_PASS","LOCKER","LOADOUTS","STORE","ARENA"],
    invite:"shareable party link/code",
    character_slots:"party members render side-by-side in lobby"
  },
  modes:[
    {key:"YEAR_ONE",solo:true,target_players:1,max_lives:3},
    {key:"TDM",solo:false,target_players:12,team_size:6,bot_backfill_after_seconds:20},
    {key:"EXTRACTION",solo:false,target_players:16,squad_size:4,bot_backfill_after_seconds:20}
  ],
  mobile_controls:{
    right_side_buttons:["AIM","SHOOT","RUN","BUILD"],
    small_equal:["AIM","SHOOT","RUN"],
    large:"BUILD",
    aim:"toggle",
    pickup:{input:"none",mode:"dwell",seconds:1.75,ui:"radial-around-item"}
  },
  traversal_collision:{
    ground_props:"solid-colliders-required",
    cars:"solid",
    walls:"solid",
    closed_doors:"solid",
    open_doors:"passable",
    open_or_broken_windows:"contextual-hurdle",
    intact_glass:"solid"
  },
  killcam:{
    pre_seconds:5,
    kill_slow_motion:true,
    slow_motion_rate:.35,
    post_seconds:5,
    skippable:true,
    storage:"client-side-ring-buffer",
    video_upload:false
  },
  loadouts:{
    count:5,
    categories:["primary","secondary","tactical","lethal","melee","field"],
    examples:["Smoke Bomb","Bouncy Grenade","Sticky Grenade","Claymore","Bouncing Betty","Hatchet","Boxing Gloves","Baseball Bat"]
  },
  world:{
    source:"BridgePoint world cell stream",
    match_cells:"real source-backed US world cells selected deterministically",
    render:"local client/device",
    cache:"IndexedDB/PWA cache by cell/version",
    procedural_dressing:"deterministic from match seed",
    cover_density:"high",
    cover_families:["pallet","barrel","concrete-barrier","desk","pillar","wrecked-car","dumpster","crate","fence","sandbag","generator","planter"],
    interiors:"fictional generated layouts inside real building envelopes",
    whole_nation_flat_file_required:false
  },
  network:{
    gameplay_transport:"WebRTC DataChannel",
    signaling:"Supabase Realtime Broadcast until peers connect",
    topology:"listen-host P2P",
    host_eligible:["phone","desktop"],
    host_election:"party host first; migrate toward best eligible peer",
    nat:"STUN first; TURN relay fallback when direct path is impossible",
    backend_gameplay_tick:false,
    server_cost_rule:"backend stores identity, party, queue, progression and compact events; not high-frequency movement/physics",
    zero_cost_guarantee:false
  },
  matchmaking:{
    tick_seconds:5,
    party_atomic:true,
    load_gate:"all real players ready or 30-second deadline",
    synchronized_start:true,
    deterministic_seed:true
  },
  anti_cheat_direction:{
    phase1:["host sanity checks","signed compact match result","rate limits","movement envelopes","weapon-fire cadence validation"],
    phase2:["peer witness snapshots","server result validation","ranked-mode stricter authority"]
  },
  next_runtime_wiring:[
    "feed cached BridgePoint world cell into Horizon renderer",
    "bind solid colliders to streamed buildings/props",
    "bind killcam ring buffer to combat snapshots",
    "bind dwell pickup to loot overlap volumes",
    "host migration and optional TURN credentials",
    "proximity voice later using separate WebRTC audio channels"
  ]
};

Deno.serve((req:Request)=>{
  if(req.method==="OPTIONS")return new Response("ok",{headers:cors});
  if(req.method!=="GET")return new Response(JSON.stringify({ok:false,error:"GET only"}),{status:405,headers:cors});
  return new Response(JSON.stringify({ok:true,contract,server_time:new Date().toISOString()}),{headers:cors});
});