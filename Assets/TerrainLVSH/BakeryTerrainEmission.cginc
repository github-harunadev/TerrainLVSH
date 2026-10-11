#ifndef BAKERY_TERRAIN_EMISSION_CGINC_INCLUDED
#define BAKERY_TERRAIN_EMISSION_CGINC_INCLUDED

#include "UnityCG.cginc"
#include "UnityPBSLighting.cginc"

// Declare Bakery texture maps when SH mode is enabled
#if defined(BAKERY_SH)
    UNITY_DECLARE_TEX2D(_RNM0);
    UNITY_DECLARE_TEX2D(_RNM1);
    UNITY_DECLARE_TEX2D(_RNM2);
#endif

// Mode set by Bakery runtime (ftLightmaps.cs via Terrain.SetSplatMaterialPropertyBlock)
float bakeryLightmapMode;
#define BAKERYMODE_DEFAULT 0
#define BAKERYMODE_VERTEXLM 1.0f
#define BAKERYMODE_RNM 2.0f
#define BAKERYMODE_SH 3.0f

#define BAKERY_LUMA_CONV float3(0.2125f, 0.7154f, 0.0721f)

// Bicubic filter support (optional)
#if defined(BAKERY_BICUBIC)
float BakeryBicubic_w0(float a) { return (1.0f/6.0f)*(a*(a*(-a + 3.0f) - 3.0f) + 1.0f); }
float BakeryBicubic_w1(float a) { return (1.0f/6.0f)*(a*a*(3.0f*a - 6.0f) + 4.0f); }
float BakeryBicubic_w2(float a) { return (1.0f/6.0f)*(a*(a*(-3.0f*a + 3.0f) + 3.0f) + 1.0f); }
float BakeryBicubic_w3(float a) { return (1.0f/6.0f)*(a*a*a); }
float BakeryBicubic_g0(float a) { return BakeryBicubic_w0(a) + BakeryBicubic_w1(a); }
float BakeryBicubic_g1(float a) { return BakeryBicubic_w2(a) + BakeryBicubic_w3(a); }
float BakeryBicubic_h0(float a) { return -1.0f + BakeryBicubic_w1(a) / (BakeryBicubic_w0(a) + BakeryBicubic_w1(a)) + 0.5f; }
float BakeryBicubic_h1(float a) { return 1.0f + BakeryBicubic_w3(a) / (BakeryBicubic_w2(a) + BakeryBicubic_w3(a)) + 0.5f; }

float4 SampleBakeryTex2DBicubic(sampler2D tex, float2 uv, float4 texelSize)
{
    float x = uv.x * texelSize.z - 0.5f;
    float y = uv.y * texelSize.w - 0.5f;
    float px = floor(x);
    float py = floor(y);
    float fx = x - px;
    float fy = y - py;
    float g0x = BakeryBicubic_g0(fx);
    float g1x = BakeryBicubic_g1(fx);
    float h0x = BakeryBicubic_h0(fx);
    float h1x = BakeryBicubic_h1(fx);
    float g0y = BakeryBicubic_g0(fy);
    float g1y = BakeryBicubic_g1(fy);
    float h0y = BakeryBicubic_h0(fy);
    float h1y = BakeryBicubic_h1(fy);

    return g0y * (g0x * tex2D(tex, float2(px + h0x, py + h0y) * texelSize.xy) +
                  g1x * tex2D(tex, float2(px + h1x, py + h0y) * texelSize.xy)) +
           g1y * (g0x * tex2D(tex, float2(px + h0x, py + h1y) * texelSize.xy) +
                  g1x * tex2D(tex, float2(px + h1x, py + h1y) * texelSize.xy));
}
#endif

// Safe Geomerics diffuse L1 evaluation with exp2/log2 to avoid compiler hangs on pow()
#if defined(BAKERY_SHNONLINEAR)
float shEvaluateDiffuseL1Geomerics_Bakery(float L0, float3 L1, float3 n)
{
    float R0 = max(L0, 1e-5f);
    float3 R1 = 0.5f * L1;
    float lenR1 = length(R1);
    float lenR1Safe = max(lenR1, 1e-5f);
    float q = saturate(dot(R1 / lenR1Safe, n) * 0.5f + 0.5f);
    float ratio = saturate(lenR1 / R0);
    float p = 1.0f + 2.0f * ratio;
    float a = (1.0f - ratio) / (1.0f + ratio);
    return R0 * (a + (1.0f - a) * (p + 1.0f) * exp2(p * log2(max(q, 1e-5f))));
}
#endif

// Calculates Bakery GI and the difference from Unity Standard GI.
// Resulting outDiffuseDiff * o.Albedo and outSpecularAdd are injected into o.Emission in surf().
inline void ApplyBakeryGI(
    float2 lmUV, 
    float3 worldNormal, 
    float3 viewDirWorld, 
    float smoothness,
    out float3 outDiffuseDiff,
    out float3 outSpecularAdd)
{
    outDiffuseDiff = 0;
    outSpecularAdd = 0;

#if defined(LIGHTMAP_ON)

    // 1. Evaluate baseline Unity Lightmap (what Unity's surface shader will evaluate)
    float4 bakedColorTex = UNITY_SAMPLE_TEX2D(unity_Lightmap, lmUV);
    float3 L0 = DecodeLightmap(bakedColorTex);
    float3 unityGI = L0;

    #ifdef DIRLIGHTMAP_COMBINED
        float4 bakedDirTex = UNITY_SAMPLE_TEX2D_SAMPLER(unity_LightmapInd, unity_Lightmap, lmUV);
        unityGI = DecodeDirectionalLightmap(L0, bakedDirTex, worldNormal);
    #endif

    float3 bakeryDiffuse = L0;
    float3 bakerySpecular = 0;

    // 2. Evaluate Bakery SH Mode
    #if defined(BAKERY_SH)
        #if defined(BAKERY_BICUBIC)
            float3 nL1x = SampleBakeryTex2DBicubic(_RNM0, lmUV, unity_Lightmap_TexelSize).xyz * 2.0f - 1.0f;
            float3 nL1y = SampleBakeryTex2DBicubic(_RNM1, lmUV, unity_Lightmap_TexelSize).xyz * 2.0f - 1.0f;
            float3 nL1z = SampleBakeryTex2DBicubic(_RNM2, lmUV, unity_Lightmap_TexelSize).xyz * 2.0f - 1.0f;
        #else
            float3 nL1x = UNITY_SAMPLE_TEX2D_SAMPLER(_RNM0, unity_Lightmap, lmUV).xyz * 2.0f - 1.0f;
            float3 nL1y = UNITY_SAMPLE_TEX2D_SAMPLER(_RNM1, unity_Lightmap, lmUV).xyz * 2.0f - 1.0f;
            float3 nL1z = UNITY_SAMPLE_TEX2D_SAMPLER(_RNM2, unity_Lightmap, lmUV).xyz * 2.0f - 1.0f;
        #endif

        float3 L1x = nL1x * L0 * 2.0f;
        float3 L1y = nL1y * L0 * 2.0f;
        float3 L1z = nL1z * L0 * 2.0f;

        #if defined(BAKERY_SHNONLINEAR)
            float lumaL0 = dot(L0, 1.0f);
            float lumaL1x = dot(L1x, 1.0f);
            float lumaL1y = dot(L1y, 1.0f);
            float lumaL1z = dot(L1z, 1.0f);
            float lumaSH = shEvaluateDiffuseL1Geomerics_Bakery(lumaL0, float3(lumaL1x, lumaL1y, lumaL1z), worldNormal);

            float3 sh = L0 + worldNormal.x * L1x + worldNormal.y * L1y + worldNormal.z * L1z;
            float regularLumaSH = dot(sh, 1.0f);
            sh *= lerp(1.0f, lumaSH / max(regularLumaSH, 1e-4f), saturate(regularLumaSH * 16.0f));
            bakeryDiffuse = max(sh, 0.0f);
        #else
            bakeryDiffuse = max(L0 + worldNormal.x * L1x + worldNormal.y * L1y + worldNormal.z * L1z, 0.0f);
        #endif

        #if defined(BAKERY_LMSPEC)
            float3 dominantDir = float3(dot(nL1x, BAKERY_LUMA_CONV), dot(nL1y, BAKERY_LUMA_CONV), dot(nL1z, BAKERY_LUMA_CONV));
            half3 halfDir = Unity_SafeNormalize(normalize(dominantDir) - viewDirWorld);
            half nh = saturate(dot(worldNormal, halfDir));
            half perceptualRoughness = SmoothnessToPerceptualRoughness(smoothness);
            half roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
            half spec = GGXTerm(nh, roughness);
            float3 specSH = max(L0 + dominantDir.x * L1x + dominantDir.y * L1y + dominantDir.z * L1z, 0.0f);
            bakerySpecular = max(spec * specSH, 0.0f);
        #endif

    // 3. Evaluate Bakery MonoSH Mode
    #elif defined(BAKERY_MONOSH) && defined(DIRLIGHTMAP_COMBINED)
        #if defined(BAKERY_BICUBIC)
            float3 dominantDir = SampleBakeryTex2DBicubic(unity_LightmapInd, lmUV, unity_Lightmap_TexelSize).xyz;
        #else
            float3 dominantDir = UNITY_SAMPLE_TEX2D_SAMPLER(unity_LightmapInd, unity_Lightmap, lmUV).xyz;
        #endif

        float3 nL1 = dominantDir * 2.0f - 1.0f;
        float3 L1x = nL1.x * L0 * 2.0f;
        float3 L1y = nL1.y * L0 * 2.0f;
        float3 L1z = nL1.z * L0 * 2.0f;

        #if defined(BAKERY_SHNONLINEAR)
            float lumaL0 = dot(L0, 1.0f);
            float lumaL1x = dot(L1x, 1.0f);
            float lumaL1y = dot(L1y, 1.0f);
            float lumaL1z = dot(L1z, 1.0f);
            float lumaSH = shEvaluateDiffuseL1Geomerics_Bakery(lumaL0, float3(lumaL1x, lumaL1y, lumaL1z), worldNormal);

            float3 sh = L0 + worldNormal.x * L1x + worldNormal.y * L1y + worldNormal.z * L1z;
            float regularLumaSH = dot(sh, 1.0f);
            sh *= lerp(1.0f, lumaSH / max(regularLumaSH, 1e-4f), saturate(regularLumaSH * 16.0f));
            bakeryDiffuse = max(sh, 0.0f);
        #else
            bakeryDiffuse = max(L0 + worldNormal.x * L1x + worldNormal.y * L1y + worldNormal.z * L1z, 0.0f);
        #endif

        #if defined(BAKERY_LMSPEC)
            half3 halfDir = Unity_SafeNormalize(normalize(nL1) - viewDirWorld);
            half nh = saturate(dot(worldNormal, halfDir));
            half perceptualRoughness = SmoothnessToPerceptualRoughness(smoothness);
            half roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
            half spec = GGXTerm(nh, roughness);
            float3 specSH = max(L0 + nL1.x * L1x + nL1.y * L1y + nL1.z * L1z, 0.0f);
            bakerySpecular = max(spec * specSH, 0.0f);
        #endif
    #endif

    // 4. Differential needed to correct Unity GI to Bakery GI
    outDiffuseDiff = bakeryDiffuse - unityGI;
    outSpecularAdd = bakerySpecular;

#endif
}

#endif // BAKERY_TERRAIN_EMISSION_CGINC_INCLUDED
