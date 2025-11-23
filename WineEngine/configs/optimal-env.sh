#!/bin/bash

# Optimal Wine Environment Variables for GTA SA on macOS
# Source this file or copy these exports to your launch script

# Wine Prefix
export WINEPREFIX="$HOME/Library/Application Support/SA-MP Runner/wine"
export WINEARCH=win32
export WINEDEBUG=-all

# DXVK (DirectX to Vulkan)
export DXVK_HUD=fps                    # Show FPS counter (can be: fps, devinfo, memory, or full)
export DXVK_ASYNC=1                    # Enable async shader compilation (eliminates stuttering)
export DXVK_STATE_CACHE_PATH="$WINEPREFIX/../dxvk_cache"  # Shader cache location
export DXVK_LOG_LEVEL=warn             # Reduce log spam

# MoltenVK (Vulkan to Metal for macOS)
export MVK_CONFIG_LOG_LEVEL=1                          # Only errors
export MVK_CONFIG_TRACE_VULKAN_CALLS=0                 # Disable call tracing
export MVK_CONFIG_SYNCHRONOUS_QUEUE_SUBMITS=0          # Async submissions
export MVK_CONFIG_PREFILL_METAL_COMMAND_BUFFERS=1      # Pre-fill for performance
export MVK_ALLOW_METAL_FENCES=1                        # Use Metal fences
export MVK_ALLOW_METAL_EVENTS=1                        # Use Metal events
export MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS=1         # Argument buffers (faster)

# Wine Performance
export STAGING_SHARED_MEMORY=1         # Shared memory for better IPC
export WINE_LARGE_ADDRESS_AWARE=1      # Allow 32-bit apps to use more RAM

# Graphics
export __GL_THREADED_OPTIMIZATIONS=1   # Enable threaded optimizations
export MTL_HUD_ENABLED=0               # Disable Metal HUD (use DXVK HUD instead)

# macOS specific
export FREETYPE_PROPERTIES="truetype:interpreter-version=35"  # Better font rendering

# Esync/Fsync (if available)
# Reduces Wine overhead significantly
export WINEESYNC=1
export WINEFSYNC=1

# CPU affinity (optional - for power users)
# On Apple Silicon, use performance cores
# Uncomment if you want to manually set affinity
# export WINE_CPU_TOPOLOGY="4:0,1,2,3"  # Use first 4 P-cores

echo "🍷 Wine environment configured for optimal GTA SA performance on macOS"
echo "   WINEPREFIX: $WINEPREFIX"
echo "   DXVK Async: Enabled"
echo "   MoltenVK: Configured"
