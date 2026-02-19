# DamageAgent

A PowerShell tool for monitoring your Contractors Showdown game log in real time, parsing of the damage events, and for generating per-raid reports. Built to detect anomalies ingame and suspicious damage patterns,to give a clear picture of what happened each raid.

## What it does

- Monitors the ExfilZone log file live as you play
<img width="1600" height="376" alt="image" src="https://github.com/user-attachments/assets/de62d925-b2ab-484d-912f-9d1a8cfab63c" />

- Real-time OBS damage overlay (damage.txt)
<img width="500" height="49300" alt="image" src="https://github.com/user-attachments/assets/9c49b2cf-d022-4873-94d7-7db528108f3f" />

- Records your loadout, map, raid duration, and killer name
- Filters out micro-damage (bleed ticks, passive drain) for cleaner reports
- Writes a per-raid report file, useful for reviewing raids or reporting cheaters

## what it should do when devs add outgoing shot/damage logging
The damage thresholds system is already built. Once the log registers damage you deal, the agent will be able to cross-reference hit values against weapon and ammo profiles to flag whether incoming damage was realistically possible — making cheat detection much better
