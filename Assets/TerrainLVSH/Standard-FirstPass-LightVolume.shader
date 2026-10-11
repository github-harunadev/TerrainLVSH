// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)
// Modified to integrate VRC Light Volumes & Bakery SH/MonoSH lightmap support.

Shader "Nature/Terrain/Standard LightVolume SH" {
    Properties {
        // used in fallback on old cards & base map
        [HideInInspector] _MainTex ("BaseMap (RGB)", 2D) = "white" {}
        [HideInInspector] _Color ("Main Color", Color) = (1,1,1,1)
        [HideInInspector] _TerrainHolesTexture("Holes Map (RGB)", 2D) = "white" {}

        [Header(VRC Light Volumes)]
        [Toggle(_VRCLIGHTVOLUME_ADDITIVE_ONLY)] _VRCLightVolumeAdditiveOnly ("Additive Light Volume Only", Float) = 0

        [Header(Bakery Lightmapping)]
        [Toggle(BAKERY_SH)] _BAKERY_SH ("Enable Bakery SH", Float) = 0
        [Toggle(BAKERY_MONOSH)] _BAKERY_MONOSH ("Enable Bakery MonoSH", Float) = 0
        [Toggle(BAKERY_SHNONLINEAR)] _BAKERY_SHNONLINEAR ("Non-linear SH", Float) = 1
        [Toggle(BAKERY_LMSPEC)] _BAKERY_LMSPEC ("Enable Lightmap Specular", Float) = 0
        [Toggle(BAKERY_BICUBIC)] _BAKERY_BICUBIC ("Enable Bicubic Filter", Float) = 0

        [HideInInspector] _RNM0 ("RNM0", 2D) = "black" {}
        [HideInInspector] _RNM1 ("RNM1", 2D) = "black" {}
        [HideInInspector] _RNM2 ("RNM2", 2D) = "black" {}
    }

    SubShader {
        Tags {
            "Queue" = "Geometry-100"
            "RenderType" = "Opaque"
            "TerrainCompatible" = "True"
        }

        CGPROGRAM
        #pragma surface surf Standard vertex:SplatmapVert finalcolor:SplatmapFinalColor finalgbuffer:SplatmapFinalGBuffer addshadow fullforwardshadows
        #pragma instancing_options assumeuniformscaling nomatrices nolightprobe nolightmap forwardadd
        #pragma multi_compile_fog // needed because finalcolor oppresses fog code generation.
        #pragma target 3.0
        #include "UnityCG.cginc"
        #include "UnityPBSLighting.cginc"

        // Bakery lightmap integration (evaluates directly in surf)
        #include "BakeryTerrainEmission.cginc"

        #pragma multi_compile_local_fragment __ _ALPHATEST_ON
        #pragma multi_compile_local __ _NORMALMAP
        #pragma shader_feature_local _VRCLIGHTVOLUME_ADDITIVE_ONLY

        #pragma shader_feature_local BAKERY_SH
        #pragma shader_feature_local BAKERY_MONOSH
        #pragma shader_feature_local BAKERY_SHNONLINEAR
        #pragma shader_feature_local BAKERY_LMSPEC
        #pragma shader_feature_local BAKERY_BICUBIC

        #define TERRAIN_STANDARD_SHADER
        #define TERRAIN_INSTANCED_PERPIXEL_NORMAL
        #define TERRAIN_SURFACE_OUTPUT SurfaceOutputStandard
        #include "TerrainSplatmapCommonLV.cginc"

        // VRC Light Volumes
        #include "Packages/red.sim.lightvolumes/Shaders/LightVolumes.cginc"

        half _Metallic0;
        half _Metallic1;
        half _Metallic2;
        half _Metallic3;

        half _Smoothness0;
        half _Smoothness1;
        half _Smoothness2;
        half _Smoothness3;

        void surf (Input IN, inout SurfaceOutputStandard o) {
            half4 splat_control;
            half weight;
            fixed4 mixedDiffuse;
            half4 defaultSmoothness = half4(_Smoothness0, _Smoothness1, _Smoothness2, _Smoothness3);
            SplatmapMix(IN, defaultSmoothness, splat_control, weight, mixedDiffuse, o.Normal);
            o.Albedo = mixedDiffuse.rgb;
            o.Alpha = weight;
            o.Smoothness = mixedDiffuse.a;
            o.Metallic = dot(splat_control, half4(_Metallic0, _Metallic1, _Metallic2, _Metallic3));

            // --- VRC Light Volumes & Bakery Integration ---
            #if !defined(UNITY_PASS_SHADOWCASTER) && !defined(UNITY_PASS_META)
                float3 L0, L1r, L1g, L1b;
            #if defined(_VRCLIGHTVOLUME_ADDITIVE_ONLY)
                LightVolumeAdditiveSH(IN.worldPos, L0, L1r, L1g, L1b);
            #else
                LightVolumeSH(IN.worldPos, L0, L1r, L1g, L1b);
            #endif

                // Evaluate diffuse lighting from Light Volumes
                float3 worldNormal = WorldNormalVector(IN, o.Normal);
                float3 lvDiffuse = LightVolumeEvaluate(worldNormal, L0, L1r, L1g, L1b);

                // Evaluate specular from Light Volumes (Dominant direction, better for static PBR surfaces)
                float3 viewDir = normalize(_WorldSpaceCameraPos - IN.worldPos);
                float3 lvSpecular = LightVolumeSpecularDominant(o.Albedo, o.Smoothness, o.Metallic, worldNormal, viewDir, L0, L1r, L1g, L1b);

                // --- Bakery GI Injection ---
                float3 bakeryDiffDiff = 0;
                float3 bakerySpecAdd = 0;
                #if defined(LIGHTMAP_ON)
                    float2 lmUV = IN.tc.xy * unity_LightmapST.xy + unity_LightmapST.zw;
                    ApplyBakeryGI(lmUV, worldNormal, viewDir, o.Smoothness, bakeryDiffDiff, bakerySpecAdd);
                #endif

                // Add Light Volume lighting + Bakery Differential
                o.Emission = lvDiffuse * o.Albedo + lvSpecular + bakeryDiffDiff * o.Albedo + bakerySpecAdd;
            #endif
        }
        ENDCG

        UsePass "Hidden/Nature/Terrain/Utilities/PICKING"
        UsePass "Hidden/Nature/Terrain/Utilities/SELECTION"
    }

    Dependency "AddPassShader"    = "Hidden/TerrainEngine/Splatmap/Standard-AddPass-LightVolumeSH"
    Dependency "BaseMapShader"    = "Hidden/TerrainEngine/Splatmap/Standard-Base-LightVolumeSH"
    Dependency "BaseMapGenShader" = "Hidden/TerrainEngine/Splatmap/Standard-BaseGen"

    CustomEditor "TerrainLVSHGUI"
    Fallback "Nature/Terrain/Diffuse"
}
