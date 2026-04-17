# MECH FISHING — Game Design Document
*Living document. Last updated: April 2026.*

---

## 1. Concept Overview

**Mech Fishing** is a 2D real-time action game in which players pilot customizable mech suits called Gears to hunt massive mutant fish in a dystopian far-future Earth. The defining design conceit is that the fish is simultaneously the enemy, the terrain, and the puzzle. Players drop into a hot zone or are launched from orbit, land on the creature's body, and must climb, fight, and survive on its surface until the hunt is complete.

The closest reference points are **Shadow of the Colossus** (boss as terrain, weak point navigation) and **Monster Hunter** (pre-mission loadout preparation, telegraphed boss behaviors, part-based interactions). The visual direction draws from **Battletoads/Sega Genesis era** pixel art — chunky, high contrast, bold silhouettes.

---

## 2. Setting

Far-future Earth. Civilization is dystopian and resource-depleted. The oceans have produced massive mutant fish — atomic, eldritch, incomprehensibly large. Mech fishing began as a survival practice: a way to actually feed desperate communities when conventional food systems collapsed. It has since been co-opted by military and scientific interests, creating political tension among the three major factions. The player is a Fisher — a working-class operator in a dangerous industry, caught between those competing interests.

The world is grimy and industrial above the surface. Below the surface it is alien and bioluminescent — terrifying and beautiful simultaneously. The fish are the last wild magnificent things left.

---

## 3. Core Fantasy

You are a pilot in a jury-rigged war machine, launched from orbit or dropped into a hot zone, landing on the back of something the size of a city. It moves. It fights back. It is the ground beneath your feet. You have to read it, climb it, crack it open, and bring it home.

---

## 4. Core Game Loop

```
Mission Select → Intel Briefing → Loadout Configuration → Drop → Fish Encounter → Extract → Debrief/Progression
```

### 4.1 Mission Select
Player chooses a target fish from available contracts. Fish type, location, and behavioral data are surfaced here depending on Intel upgrades unlocked.

### 4.2 Intel Briefing
Information about the target fish is displayed before the drop. The depth and accuracy of this information depends on faction alignment and Intel upgrade investment. Early game intel may only confirm a fish type exists in a region. Late game intel can provide full resistance profiles, behavioral flags, surface zone analysis, and movement vectors.

### 4.3 Loadout Configuration
Player configures their Gear before the drop. Three loadout slots plus frame selection. See Section 6.

### 4.4 The Drop
The mission begins with the player dropping onto or being launched toward the fish. Entry point selection may be a tactical decision — landing on the dorsal surface vs. approaching from below carries different risk/reward.

### 4.5 Fish Encounter
The primary gameplay loop. The fish is the terrain. Player navigates its surface, manages grip, identifies and attacks weak points, and responds to fish behaviors. See Section 7.

### 4.6 Extract / Debrief
On successful hunt, the fish (or its remains) is donated to a faction of the player's choosing. Faction donation unlocks progression rewards. Failed hunts may still yield partial rewards depending on damage dealt.

---

## 5. Setting and Tone

### Visual Direction
- **Above surface:** Corroded industrial decay. Launch facilities, prep areas, UI all feel like salvaged military hardware. Grey, rust, wear.
- **Below surface:** Alien beauty. Bioluminescence, strange deep color, horrifying grandeur. The fish glow.
- **Art style:** 2D pixel art in the Battletoads/Genesis tradition — chunky sprites, bold outlines, high contrast, readable silhouettes. Fewer frames, strong shape language.

### Faction Aesthetics
UI and equipment visually reflect faction alignment:
- **Military:** Army surplus hardware aesthetic. Angular, utilitarian, stamped with insignia.
- **Populist:** Hand-modified, stickered, repaired. Community-built feel.
- **Science:** Clinical, cold, precise. Data-forward interfaces.

### Thematic Weight
The fish are magnificent. Destroying them is an act of survival and violence simultaneously. This should be felt, not explained.

---

## 6. Mech System (Gears)

### 6.1 Base Frames
Two base frame options, differentiated by grip profile and mobility:

| Frame | Grip | Mobility | Playstyle |
|-------|------|----------|-----------|
| **Spider** | High baseline grip, stable on shifting surfaces | Slower repositioning | Defensive, methodical |
| **Bipedal** | Skill-dependent grip | Fast repositioning | Aggressive, mobile |

Faction tech visually and statistically differentiates frames within each type. A Military Spider and a Science Spider share geometry but play differently.

### 6.2 Loadout Slots
Three loadout categories configured before each mission:

**Engine / Propulsion**
Determines movement speed, climb rate, and behavior during fish movement events.
- Turbines
- Thrusters
- *(others TBD)*

**Utility**
Directly affects grip, bracing, and recovery. Survival tools.
- Clamps
- Belaying Systems
- *(others TBD)*

**Weapon**
Damage and weak point interaction tools. Different weapons interact with fish surface zones and resistance flags differently.
- Harpoons with tractor lines
- Saws
- Depth charges
- Electrical systems
- Poison injectors
- *(others TBD)*

### 6.3 Dodge Slot
The dodge/evasion action is its own loadout category, giving evasion a distinct tactical character per build.
- Turbine burst (speed-based reposition)
- Clamp-brace (grip-based anchor)
- Tractor line swing (positional swing/grapple)
- *(others TBD)*

### 6.4 Visual Customization
Loadout choices manifest visually on the sprite via layered attachment points (shoulder, arm, back). The frame is recognizable; the attachments tell the story of this specific Fisher's build.

---

## 7. Fish Encounter Design

### 7.1 The Fish as Terrain
The fish body is divided into **surface zones** — scales, membrane, armor plating, gill slits, eye clusters, underbelly, etc. Each zone has distinct:
- Grip characteristics (grippy scales vs. slick membrane vs. repellent bio-armor)
- Damage type interactions (resistance/vulnerability flags)
- Weak point potential

### 7.2 Grip System
Grip is a continuous resource. It drains passively and drains faster on hostile surfaces or during fish behaviors. It is restored by deliberate actions (deploying clamps, using belaying systems, finding stable zones). Losing grip causes the player to fall — recovering or dying depending on circumstances.

The core tension: every decision is weighed against grip management. Do you spend this moment climbing toward the weak point or restoring your grip before the next behavior fires?

### 7.3 Fish Behaviors
Fish act on a timer/initiative system. Large behaviors are **telegraphed** with visible windup — players can read them and respond (brace, reposition, use a dodge action). Fish behaviors include but are not limited to:
- Shudder / full body convulsion (grip disruption)
- Roll (surface accessibility changes, repositioning threat)
- Depth dive (pressure resource management)
- Bite/tail sweep (positional threat to specific zones)
- Bioluminescent pulse (electrical/visibility effect)

Fish behavior frequency and severity scale with damage taken — the terrain becomes more dangerous as the hunt progresses.

### 7.4 Procedural Fish Flag System
Each fish instance is generated with an RNG flag set appended to the fish type template. Flags define:

**Damage Flags (per surface zone)**
- Resistance / vulnerability / neutrality to: piercing, slashing, explosive, electrical, chemical, kinetic
- Example: "Scales are too tough for piercing except at gill margins. Underbelly is highly vulnerable to slashing."

**Behavioral Reaction Flags**
Separate from damage — some flags define how the fish *reacts* to damage types regardless of effectiveness:
- Electrical damage → spasm/shudder (repositions enemies, disrupts grip)
- Saw/slashing → enrage (speeds up behavior timer, fish becomes more dangerous)
- Poison → slowed behavior timer but unpredictable movement
- These create genuine tactical tension: the optimal damage solution is not always the optimal survival solution.

This system ensures replayability — the same fish type behaves differently each hunt, and pre-mission intel becomes valuable.

---

## 8. Fish Roster (Proof of Concept)

Small roster, meaningful variety. Each fish is a fully realized puzzle-boss-terrain combination. Variety comes from how differently each plays, not quantity.

### Planned Archetypes

| Fish | Terrain Character | Primary Challenge |
|------|-----------------|-------------------|
| **Dreadnought** | Slow, heavily armored, stable terrain | Peeling back layers to reach core; methodical |
| **Serpentine** | Fast, constantly moving | Staying mounted; unpredictable repositioning |
| **Depth Diver** | Drags player into crushing pressure zones | Resource/system management alongside combat |
| **Swarm Architect** | Covered in symbiotic smaller creatures | Clear the ecosystem before reaching the fish |

Each fish teaches different mech loadout priorities and rewards different grip/movement strategies.

---

## 9. Faction System

Three factions with competing interests in the fish and in the Fisher. Faction alignment is built through **fish donation on mission completion** — what you do with the catch tells the story of whose side you're on.

### 9.1 Military
**What they want:** The fish as a resource for industry and warfare. They have the satellites, sonar arrays, and patrol networks.
**What they provide:** Tracking and location intel. Movement vectors, approach routes, hot zone coordinates. Tactical gear — heavy weapons, durable frames.
**Upgrade tree flavor:** Firepower, durability, precision targeting.

### 9.2 Populist
**What they want:** To feed communities. The original purpose of mech fishing. They carry experiential, community knowledge.
**What they provide:** Folk intel — Fisher community observations passed down over generations. Less precise, occasionally reveals flags the other factions have missed. Jury-rigged community gear.
**Upgrade tree flavor:** Utility, grip systems, adaptability, belaying tech.

### 9.3 Science
**What they want:** To study the creatures. Morally ambiguous — studying them while people are still hungry is a distinctly dystopian tension.
**What they provide:** Biological intel. Full resistance profiles, behavioral flag analysis, surface zone breakdowns. Experimental tech.
**Upgrade tree flavor:** Exotic weapons, poison systems, electrical rigs, experimental propulsion.

### 9.4 Intel as Upgrade Path
Intel depth scales with faction investment:

| Intel Level | Information Available |
|-------------|----------------------|
| Tier 1 | "We know it's here." Location only. |
| Tier 2 | Fish type confirmed. General behavioral category. |
| Tier 3 | Movement vector, speed, estimated location. Surface coating description. |
| Tier 4 | Full resistance profile, behavioral flags, surface zone breakdown, estimated weak points. |

Full Tier 4 intel requires either deep investment in all three factions or coordinated co-op crews with diverse faction alignment.

---

## 10. Progression Structure

Between hunts, players optimize their Gear using rewards earned through faction donations. Progression happens on several layers:

- **Gear upgrades** — improved frames, new loadout options unlocked via faction trees
- **Intel infrastructure** — deeper pre-mission information
- **Faction standing** — gates higher tier rewards and unlocks faction-specific gear and tech

Progression feeds back into the hunt loop — better intel means better loadout decisions, better loadouts mean more successful hunts, more successful hunts mean better faction standing.

---

## 11. Multiplayer

Both solo and co-op are supported.

Co-op crews naturally distribute across faction alignments — each player bringing different intel and different gear to the briefing. The fish encounter scales for multiple players on the CT/behavior timer.

Crew coordination around telegraphed fish behaviors becomes meaningful — players in different roles (heavy weapon, utility/grip support, fast repositioner) covering different zones of the fish simultaneously.

Async multiplayer potential exists given the autobattler backend heritage — this is a future consideration.

---

## 12. Technical Direction

| Layer | Technology |
|-------|-----------|
| Game engine | Phaser.js (browser-native, JS comfort zone) |
| Art | 2D pixel art; Midjourney for concept/reference, Aseprite for sprite work |
| Backend | Node.js + SQLite3 on Railway (carries over from autobattler) |
| Platform | Web-first, system independent; mobile consideration later |

### Sprite Architecture
Layered sprite system for visual loadout customization. Base frame sprite + attachment point overlays (shoulder, arm, back) reflect loadout choices without requiring unique art for every combination.

---

## 13. Proof of Concept Scope

**Goal:** One fish, fully realized, validating the core feel.

**Must work:**
- Grip system — continuous drain, deliberate restoration, falling on loss
- Vertically scrolling fish terrain with distinct surface zones
- At least one telegraphed fish behavior
- Basic loadout selection affecting play
- One complete hunt loop (drop → fight → extract)

**Art minimum:**
- Hero mech sprite (one frame per base frame)
- One fish with readable surface zones
- Basic UI

The Scratch prototype already validated the grip/climb core. The proof of concept proves the full encounter loop.

---

## 14. Open Questions

- Exact weapon interaction depth — damage types vs. zone system specifics
- Number of attachment/loadout visual variants to art for POC
- Pressure/depth mechanic implementation details
- Faction UI differentiation scope for POC
- Music and sound direction
- Mobile vs. desktop input handling (grip drain pacing differs)

---

*This document captures design decisions as of April 2026. Update as decisions are made.*
