# TerrainLVSH
Unity Built-in Terrain shader with **VRC Light Volume** and **Bakery GPU Lightmapper (SH / MonoSH)** support.

<img src="https://github.com/github-harunadev/TerrainLV/blob/main/preview.png?raw=true" />

I (personally) wanted a fast way to use LV and Bakery SH/Mono SH with Unity Terrain, so I used Claude to implement the LV, and Gemini to implement the SH.
This means the result shader is made by AI, so keep that in mind if you're aware of.

TerrainLVSH is an enhanced fork of [TerrainLV](https://github.com/github-harunadev/TerrainLV). It brings native support for **Bakery's SH (Spherical Harmonics) and MonoSH directional lightmaps** to Unity terrains while retaining full compatibility with **VRC Light Volumes**.

## Features
- **Bakery SH Support**: Decodes full 3-texture ($L1_x, L1_y, L1_z$) spherical harmonics lightmaps (`_RNM0`, `_RNM1`, `_RNM2`) assigned by Bakery to terrains.
- **Bakery MonoSH Support**: Decodes dominant direction lightmaps via Unity's directional lightmap (`unity_LightmapInd`).
- **Non-Linear SH Mode**: Geomerics non-linear contrast weighting (`BAKERY_SHNONLINEAR`) to eliminate negative lobes and enhance lighting contrast.
- **Baked Lightmap Specular**: Directional lightmap GGX specular highlights (`BAKERY_LMSPEC`) based on dominant direction and terrain smoothness.
- **Bicubic Filtering**: Optional bicubic filtering (`BAKERY_BICUBIC`) for smooth lightmap evaluation without texel blockiness.
- **VRC Light Volumes**: Full support for VRC Light Volumes (`LightVolumeSH` & `LightVolumeAdditiveSH`).
  - **Additive Only Mode**: Allows VRC Light Volumes to act additively over pre-baked Bakery static lighting without double-counting ambient light.
- **Custom Inspector GUI**: Intuitive material inspector (`TerrainLVSHGUI`) for configuring Bakery modes and Light Volume settings.

### Prerequisites
- **[VRC Light Volume](https://redsim.github.io/vpmlisting/)** installed in your project via VCC/ALCOM (references `Packages/red.sim.lightvolumes`).
- *(Optional)* **[Bakery - GPU Lightmapper](https://assetstore.unity.com/packages/tools/level-design/bakery-gpu-lightmapper-122218)** for baking SH or MonoSH lightmaps.

## Usage
1. Move the `TerrainLVSH` folder into your Unity project's `Assets` folder (or import the package).
2. Create a material, and set the shader to:
   - `Nature/Terrain/Standard LightVolume SH`
3. In the material inspector:
   - Under **VRC Light Volumes Settings**, optionally enable **Additive Only Mode** if you are using baked lightmaps.
   - Under **Bakery Lightmapping Settings**, select your Directional Mode:
     - **Bakery MonoSH**: if baked with Bakery's *MonoSH* mode.
     - **Bakery SH**: if baked with Bakery's *SH* mode.
     - *(Optional)* Enable **Non-Linear SH**, **Lightmap Specular**, and **Bicubic Filtering**.
4. Assign the material to your Terrain:
   - **Terrain Settings** > **Basic Terrain** > **Material**.

## License
This project is licensed under the MIT License.
For information on Unity Built-in shaders license, see [unity_builtin_license.txt](unity_builtin_license.txt).
