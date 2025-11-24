# SAMP Addon 2.6 - Performance Optimization

SAMP Addon este cel mai bun mod pentru a optimiza SA-MP pe low-end systems.

## Ce face SAMP Addon?

✅ **Graphics optimizations:**
- Reduce texture quality automat pentru FPS mai bun
- Optimizeaza shadows si reflections
- Better LOD (Level of Detail) management
- Reduce draw distance inteligent

✅ **Performance improvements:**
- 20-30% FPS boost pe low-end systems
- Reduce stuttering
- Better memory management
- Frame pacing mai bun

✅ **SA-MP specific:**
- Optimizeaza player rendering
- Reduce vehicle poly count
- Better streaming pentru obiecte SA-MP
- Lag compensation

## Instalare

### Metoda 1: Script automat (recomandat)

```bash
cd GameOptimizations/samp-addon
./install-samp-addon.sh
```

Scriptul va:
1. Deschide link-ul de download în browser
2. Te va ghida să descarci SAMP_Addon_2.6_Setup.exe
3. Va rula installer-ul automat

### Metoda 2: Manual

1. **Download:**
   - Link: https://www.mediafire.com/file/tas2s0a1f75e3oz/SAMP_Addon_2.6_Setup.exe/file
   - Salvează în: `GameOptimizations/samp-addon/SAMP_Addon_2.6_Setup.exe`

2. **Install:**
   ```bash
   cd ~/Library/Application\ Support/SA-MP\ Runner/wine/drive_c/
   wine ~/path/to/SAMP_Addon_2.6_Setup.exe
   ```

3. **Configure:**
   - Selectează folderul GTA San Andreas
   - Bifează "Install all components"
   - Finalizează instalarea

## Performance pe M2 8GB

Cu SAMP Addon instalat, ar trebui să vezi:

| Înainte | După SAMP Addon |
|---------|-----------------|
| 20 FPS  | 30-40 FPS      |
| Stuttering | Smooth        |
| High RAM usage | Optimized |

## Setări recomandate

După instalare, din jocul SA-MP:
1. Options → Graphics
2. Draw Distance: Medium (nu Low - SAMP Addon optimizează automat)
3. Visual FX: Medium
4. Shadows: ON (SAMP Addon optimizează shadows)

SAMP Addon va face optimizările automat, nu trebuie setări extreme low!

## Troubleshooting

**Problem:** Installer nu pornește
- **Fix:** Rulează din Safe Mode (launcher detectează automat)

**Problem:** Culori stricate după instalare
- **Fix:** Deja fixat în Wine registry (ARB shaders)

**Problem:** FPS încă scăzut
- **Fix:** Reinstall SAMP Addon, asigură-te că ai bifat "Performance mode"

## Alternative

Dacă SAMP Addon nu ajută:
- **CLEO Mods:** FPS Boost scripts
- **SA-MP Low PC Pack:** Community optimization pack
- **Texture Reduction:** Manual texture replacements
