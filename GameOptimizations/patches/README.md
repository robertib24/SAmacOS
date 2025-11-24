# GTA SA Performance Patches

Patches pentru optimizarea GTA San Andreas pe low-end systems (MacBook Pro M2 8GB).

## apply-low-end-settings.sh

**Scop:** Aplică setări extreme de performance pentru FPS maxim pe sisteme cu RAM limitat.

### Optimizări aplicate:

#### Graphics
- ✅ **Shadows: DISABLED** - cel mai mare boost de FPS!
- ✅ **Reflections: DISABLED** - water + vehicle reflections off
- ✅ **Visual Effects: 0** - minimal particles
- ✅ **Draw Distance: 0.4** - foarte low
- ✅ **MipMapping: DISABLED**
- ✅ **Anti-Aliasing: DISABLED**

#### Display
- Resolution: 640x480 (minimum)
- VSync: OFF
- Frame Limiter: OFF

#### Performance Impact
- **Expected FPS boost:** 2-3x îmbunătățire
- **Quality:** Grafică foarte slabă, dar PLAYABLE
- **Pentru SA-MP:** Perfect pentru multiplayer pe low-end

### Usage

Automat aplicat de launcher când pornești jocul.

Manual:
```bash
./apply-low-end-settings.sh /path/to/gta-sa-directory
```

### Moduri recomandate (opțional)

Pentru FPS și mai bun, instalează manual:

1. **SA-MP Low PC Mod**
   - Reduce texture resolution
   - Simplify models
   - Download: sa-mp.com forums

2. **No Grass Mod**
   - Remove all grass (big FPS boost in countryside)

3. **Low Quality Vehicles**
   - Replace vehicle models with low-poly versions

4. **Texture Reduction Pack**
   - 256x256 textures instead of 1024x1024

### Note

Aceste setări fac jocul să arate foarte prost, dar oferă cel mai bun FPS posibil pe:
- MacBook Pro M2 8GB RAM
- Wine + WineD3D (fără DXVK)
- Sisteme low-end

Pentru gameplay decent la 40-60 FPS, aceste sacrificii sunt necesare.
