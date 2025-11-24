# SAMP Addon 2.6 - Performance Optimization

SAMP Addon este cel mai bun mod pentru a optimiza SA-MP pe low-end systems.

## ⚠️ IMPORTANT - Ordinea de instalare!

**ORDINEA CORECTĂ:**
1. ✅ Instalează GTA San Andreas
2. ✅ Instalează SAMP Addon 2.6
3. ✅ **REINSTALEAZĂ SA-MP** (peste SAMP Addon)

**Dacă nu reinstalezi SA-MP după SAMP Addon, jocul NU VA PORNI!**

SAMP Addon modifică fișiere care trebuie suprascrise de SA-MP pentru ca multiplayer-ul să funcționeze.

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

### ⚠️ CRITICIAL - Pași în ordinea corectă:

**Pasul 1: Instalează GTA San Andreas**
- Rulează installer-ul GTA SA normal
- Finalizează instalarea

**Pasul 2: Instalează SAMP Addon**

Script automat (recomandat):
```bash
cd GameOptimizations/samp-addon
./install-samp-addon.sh
```

Manual:
1. Download: https://www.mediafire.com/file/tas2s0a1f75e3oz/SAMP_Addon_2.6_Setup.exe/file
2. Salvează ca: `SAMP_Addon_2.6_Setup.exe`
3. Rulează installer-ul:
   ```bash
   wine SAMP_Addon_2.6_Setup.exe
   ```
4. Selectează folderul GTA San Andreas
5. Bifează toate componentele
6. Instalează

**Pasul 3: ⚠️ REINSTALEAZĂ SA-MP (OBLIGATORIU!)**

```bash
# Rulează din nou installer-ul SA-MP
wine samp_install.exe
```

**De ce?** SAMP Addon modifică anumite DLL-uri și fișiere care trebuie suprascrise de SA-MP pentru ca multiplayer-ul să funcționeze. Dacă nu reinstalezi SA-MP, jocul nu va porni!

### Quick reinstall command:

```bash
# După ce ai instalat SAMP Addon, rulează:
wine /path/to/samp_install.exe
```

Selectează același folder GTA SA și reinstalează.

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

**Problem:** Jocul nu pornește după SAMP Addon
- **Fix:** ⚠️ **TREBUIE să reinstalezi SA-MP!** (vezi Pasul 3 de mai sus)
- SAMP Addon override-uiește fișiere SA-MP critice
- Reinstalare SA-MP suprascrie cu versiunile corecte

**Problem:** Installer nu pornește
- **Fix:** Rulează din Safe Mode (launcher detectează automat)

**Problem:** Culori stricate după instalare
- **Fix:** Deja fixat în Wine registry (ARB shaders)

**Problem:** FPS încă scăzut
- **Fix:**
  1. Verifică că ai reinstalat SA-MP după SAMP Addon
  2. Reinstall SAMP Addon, asigură-te că ai bifat "Performance mode"
  3. Verifică că jocul rulează în 1024x768 sau mai mic

## Alternative

Dacă SAMP Addon nu ajută:
- **CLEO Mods:** FPS Boost scripts
- **SA-MP Low PC Pack:** Community optimization pack
- **Texture Reduction:** Manual texture replacements
