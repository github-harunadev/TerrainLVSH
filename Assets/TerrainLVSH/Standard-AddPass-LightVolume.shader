// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)
// Modified to integrate VRC Light Volumes & Bakery SH/MonoSH lightmap support.

Shader "Hidden/TerrainEngine/Splatmap/Standard-AddPass-LightVolumeSH" {
    Properties {
        [HideInInspector] _TerrainHolesTexture("Holes Map (RGB)", 2D) = "white" {}
        [Toggle(_VRCLIGHTVOLUME_ADDITIVE_ONLY)] _VRCLightVolumeAdditiveOnly ("Additive Light Volume Only", Float) = 0
    }
    SubShader {
        Tags {
            "Queue" = "Geometry-99"
            "IgnoreProjector"="True"
            "RenderType" = "Opaque"
        }

        CGPROGRAM
        #pragma surface surf Standard decal:add vertex:SplatmapVert finalcolor:SplatmapFinalColor finalgbuffer:SplatmapFinalGBuffer fullforwardshadows nometa
        #pragma instancing_options assumeuniformscaling nomatrices nolightprobe nolightmap forwardadd
        #pragma multi_compile_fog
        #pragma target 3.0
        #include "UnityCG.cginc"
        #include "UnityPBSLighting.cginc"

        #pragma multi_compile_local_fragment __ _ALPHATEST_ON
        #pragma multi_compile_local __ _NORMALMAP
        #pragma shader_feature_local _VRCLIGHTVOLUME_ADDITIVE_ONLY

        #define TERRAIN_SPLAT_ADDPASS
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

            // --- VRC Light Volumes Integration ---
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

                o.Emission = lvDiffuse * o.Albedo + lvSpecular;
            #endif
        }
        ENDCG
    }

    Fallback "Hidden/TerrainEngine/Splatmap/Diffuse-AddPass"
}
