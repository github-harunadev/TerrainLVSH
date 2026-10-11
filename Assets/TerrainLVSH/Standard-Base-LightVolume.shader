// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)
// Modified to integrate VRC Light Volumes & Bakery SH/MonoSH lightmap support.

Shader "Hidden/TerrainEngine/Splatmap/Standard-Base-LightVolumeSH" {
    Properties {
        _MainTex ("Base (RGB) Smoothness (A)", 2D) = "white" {}
        _MetallicTex ("Metallic (R)", 2D) = "white" {}

        // used in fallback on old cards
        _Color ("Main Color", Color) = (1,1,1,1)

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
            "RenderType" = "Opaque"
            "Queue" = "Geometry-100"
        }
        LOD 200

        CGPROGRAM
        #pragma surface surf Standard vertex:SplatmapVert addshadow fullforwardshadows
        #pragma instancing_options assumeuniformscaling nomatrices nolightprobe nolightmap forwardadd
        #pragma target 3.0

        #pragma multi_compile_local_fragment __ _ALPHATEST_ON
        #pragma shader_feature_local _VRCLIGHTVOLUME_ADDITIVE_ONLY

        #pragma shader_feature_local BAKERY_SH
        #pragma shader_feature_local BAKERY_MONOSH
        #pragma shader_feature_local BAKERY_SHNONLINEAR
        #pragma shader_feature_local BAKERY_LMSPEC
        #pragma shader_feature_local BAKERY_BICUBIC

        #include "UnityCG.cginc"

        #define TERRAIN_BASE_PASS
        #define TERRAIN_INSTANCED_PERPIXEL_NORMAL
        #include "TerrainSplatmapCommonLV.cginc"
        #include "UnityPBSLighting.cginc"

        // Bakery lightmap integration
        #include "BakeryTerrainEmission.cginc"
        // VRC Light Volumes
        #include "Packages/red.sim.lightvolumes/Shaders/LightVolumes.cginc"

        sampler2D _MainTex;
        sampler2D _MetallicTex;

        void surf (Input IN, inout SurfaceOutputStandard o) {
            #ifdef _ALPHATEST_ON
                ClipHoles(IN.tc.xy);
            #endif
            half4 c = tex2D (_MainTex, IN.tc.xy);
            o.Albedo = c.rgb;
            o.Alpha = 1;
            o.Smoothness = c.a;
            o.Metallic = tex2D (_MetallicTex, IN.tc.xy).r;

            #if defined(INSTANCING_ON) && defined(SHADER_TARGET_SURFACE_ANALYSIS) && defined(TERRAIN_INSTANCED_PERPIXEL_NORMAL)
                o.Normal = float3(0, 0, 1); // make sure that surface shader compiler realizes we write to normal, as UNITY_INSTANCING_ENABLED is not defined for SHADER_TARGET_SURFACE_ANALYSIS.
            #endif

            #if defined(UNITY_INSTANCING_ENABLED) && !defined(SHADER_API_D3D11_9X) && defined(TERRAIN_INSTANCED_PERPIXEL_NORMAL)
                #if defined(TERRAIN_USE_SEPARATE_VERTEX_SAMPLER)
                    o.Normal = normalize(_TerrainNormalmapTexture.Sample(sampler__TerrainNormalmapTexture, IN.tc.zw).xyz * 2 - 1).xzy;
                #else
                    o.Normal = normalize(tex2D(_TerrainNormalmapTexture, IN.tc.zw).xyz * 2 - 1).xzy;
                #endif
            #endif

            // --- VRC Light Volumes & Bakery Integration ---
            #if !defined(UNITY_PASS_SHADOWCASTER) && !defined(UNITY_PASS_META)
                float3 L0, L1r, L1g, L1b;
            #if defined(_VRCLIGHTVOLUME_ADDITIVE_ONLY)
                LightVolumeAdditiveSH(IN.worldPos, L0, L1r, L1g, L1b);
            #else
                LightVolumeSH(IN.worldPos, L0, L1r, L1g, L1b);
            #endif

                float3 worldNormal = WorldNormalVector(IN, o.Normal);
                float3 lvDiffuse = LightVolumeEvaluate(worldNormal, L0, L1r, L1g, L1b);

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

    FallBack "Diffuse"
}
