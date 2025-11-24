# ⚠️ Ordinea Corectă de Instalare - SAMP Addon + SA-MP

## ❌ GREȘIT - Jocul nu va porni!

```
1. GTA San Andreas
2. SA-MP
3. SAMP Addon ❌  <- GREȘIT! Jocul nu va porni
```

## ✅ CORECT - Jocul va funcționa!

```
1. GTA San Andreas
2. SAMP Addon 2.6
3. SA-MP (REINSTALARE) ✅  <- CORECT! Jocul va porni
```

## De ce această ordine?

### Ce face SAMP Addon:
- Modifică `gta_sa.exe` pentru optimizări
- Override-uiește anumite DLL-uri (d3d9.dll, etc.)
- Adaugă texturi optimizate
- Modifică settings files

### Problema:
SAMP Addon **modifică și suprascrie** fișiere critice SA-MP:
- `samp.dll` - core SA-MP library
- `samp.exe` - SA-MP launcher
- Network components
- Audio/Video hooks

### Soluția:
**Reinstalare SA-MP peste SAMP Addon** restabilește fișierele SA-MP corecte, păstrând optimizările SAMP Addon pentru GTA SA base game.

## Pași detaliați:

### 1️⃣ Instalează GTA San Andreas

```bash
wine GTA_SA_Setup.exe
```

- Instalează complet
- Nu rula încă jocul

### 2️⃣ Instalează SAMP Addon 2.6

```bash
cd GameOptimizations/samp-addon
./install-samp-addon.sh
```

SAU manual:
```bash
wine SAMP_Addon_2.6_Setup.exe
```

- Selectează folderul GTA SA
- Bifează toate componentele
- "Performance mode" ON
- Instalează

### 3️⃣ ⚠️ REINSTALEAZĂ SA-MP (CRIITIC!)

```bash
wine samp_install.exe
```

- Selectează **ACELAȘI** folder GTA SA
- Reinstalează complet
- Nu schimba locația

### 4️⃣ Verifică instalarea

După reinstalare SA-MP, verifică că există:
- `samp.exe` (SA-MP launcher)
- `samp.dll` (SA-MP core)
- `gta_sa.exe` (GTA SA optimizat de SAMP Addon)

Dacă toate există, ești gata! 🎉

### 5️⃣ Pornește jocul

```bash
wine samp.exe
```

Ar trebui să pornească cu:
- ✅ Optimizări SAMP Addon (FPS mai bun)
- ✅ SA-MP funcțional (multiplayer merge)
- ✅ Culorile corecte
- ✅ Performance îmbunătățit

## Ce se întâmplă dacă NU reinstalezi SA-MP?

### Erori tipice:

1. **"Failed to load SAMP.DLL"**
   - SAMP Addon a override-uit `samp.dll`
   - Fix: Reinstalează SA-MP

2. **"Cannot initialize network"**
   - Network components suprascrise de SAMP Addon
   - Fix: Reinstalează SA-MP

3. **Jocul pur și simplu nu pornește**
   - Multiple fișiere în conflict
   - Fix: Reinstalează SA-MP

4. **"Missing d3d9.dll"**
   - SAMP Addon a instalat o versiune incompatibilă
   - Fix: Reinstalează SA-MP

## TL;DR - Quick Guide

**Instalare nouă:**
```bash
# 1. GTA SA
wine GTA_SA_Setup.exe

# 2. SAMP Addon
wine SAMP_Addon_2.6_Setup.exe

# 3. SA-MP (REINSTALARE!)
wine samp_install.exe
```

**Jocul nu pornește după SAMP Addon?**
```bash
# FIX: Reinstalează SA-MP
wine samp_install.exe
```

**Simplificat:**
> GTA SA → SAMP Addon → **REINSTALEAZĂ SA-MP** → Play!

## Performance Expected (M2 8GB)

După instalare corectă:
- **FPS:** 30-50 (de la 20)
- **Stuttering:** Minimal
- **RAM usage:** ~4-5GB (optimizat)
- **Load times:** Mai rapide
- **Graphics:** Decent (nu extreme low!)

---

**Remember:** Întotdeauna reinstalează SA-MP după SAMP Addon! 🔄
