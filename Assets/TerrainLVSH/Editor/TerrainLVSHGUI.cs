#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

public class TerrainLVSHGUI : ShaderGUI
{
    private MaterialProperty vrcAdditiveOnly;
    private MaterialProperty bakerySH;
    private MaterialProperty bakeryMonoSH;
    private MaterialProperty bakerySHNonLinear;
    private MaterialProperty bakeryLMSpec;
    private MaterialProperty bakeryBicubic;

    private static bool foldoutVRC = true;
    private static bool foldoutBakery = true;

    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        Material material = materialEditor.target as Material;
        if (material == null) return;

        FindProperties(properties);

        EditorGUILayout.Space();
        EditorGUILayout.LabelField("TerrainLVSH — VRC Light Volumes & Bakery", EditorStyles.boldLabel);
        EditorGUILayout.Space();

        // --- VRC Light Volumes Section ---
        foldoutVRC = EditorGUILayout.BeginFoldoutHeaderGroup(foldoutVRC, "VRC Light Volumes Settings");
        if (foldoutVRC)
        {
            EditorGUI.indentLevel++;
            if (vrcAdditiveOnly != null)
            {
                materialEditor.ShaderProperty(vrcAdditiveOnly, new GUIContent("Additive Only Mode", "Only adds dynamic light volume irradiance without replacing or double-counting baked ambient. Recommended when using baked Bakery lightmaps."));
            }
            EditorGUI.indentLevel--;
        }
        EditorGUILayout.EndFoldoutHeaderGroup();
        EditorGUILayout.Space();

        // --- Bakery Lightmapping Section ---
        foldoutBakery = EditorGUILayout.BeginFoldoutHeaderGroup(foldoutBakery, "Bakery Lightmapping Settings");
        if (foldoutBakery)
        {
            EditorGUI.indentLevel++;

            int currentMode = 0; // 0 = Disabled, 1 = MonoSH, 2 = Full SH
            if (bakerySH != null && bakerySH.floatValue > 0.5f) currentMode = 2;
            else if (bakeryMonoSH != null && bakeryMonoSH.floatValue > 0.5f) currentMode = 1;

            string[] modeOptions = new string[] {
                "Disabled (Standard Unity GI)",
                "Bakery MonoSH (Dominant Direction)",
                "Bakery SH (Full 3-Texture L1 Spherical Harmonics)"
            };

            EditorGUI.BeginChangeCheck();
            int newMode = EditorGUILayout.Popup(new GUIContent("Directional Mode", "Select directional lightmapping mode baked with Bakery."), currentMode, modeOptions);
            if (EditorGUI.EndChangeCheck())
            {
                if (newMode == 0)
                {
                    SetKeyword(material, "BAKERY_SH", false, bakerySH);
                    SetKeyword(material, "BAKERY_MONOSH", false, bakeryMonoSH);
                }
                else if (newMode == 1)
                {
                    SetKeyword(material, "BAKERY_SH", false, bakerySH);
                    SetKeyword(material, "BAKERY_MONOSH", true, bakeryMonoSH);
                }
                else if (newMode == 2)
                {
                    SetKeyword(material, "BAKERY_SH", true, bakerySH);
                    SetKeyword(material, "BAKERY_MONOSH", false, bakeryMonoSH);
                }
            }

            if (newMode != 0)
            {
                if (bakerySHNonLinear != null)
                {
                    EditorGUI.BeginChangeCheck();
                    materialEditor.ShaderProperty(bakerySHNonLinear, new GUIContent("Non-Linear SH", "Applies Geomerics non-linear contrast weighting to prevent negative lobes and enhance shadow contrast."));
                    if (EditorGUI.EndChangeCheck())
                    {
                        SetKeyword(material, "BAKERY_SHNONLINEAR", bakerySHNonLinear.floatValue > 0.5f, null);
                    }
                }

                if (bakeryLMSpec != null)
                {
                    EditorGUI.BeginChangeCheck();
                    materialEditor.ShaderProperty(bakeryLMSpec, new GUIContent("Lightmap Specular", "Calculates baked directional specular using lightmap dominant direction and terrain smoothness."));
                    if (EditorGUI.EndChangeCheck())
                    {
                        SetKeyword(material, "BAKERY_LMSPEC", bakeryLMSpec.floatValue > 0.5f, null);
                    }
                }

                if (bakeryBicubic != null)
                {
                    EditorGUI.BeginChangeCheck();
                    materialEditor.ShaderProperty(bakeryBicubic, new GUIContent("Bicubic Filtering", "Enables bicubic filtering on Bakery lightmaps to eliminate pixelation artifacts."));
                    if (EditorGUI.EndChangeCheck())
                    {
                        SetKeyword(material, "BAKERY_BICUBIC", bakeryBicubic.floatValue > 0.5f, null);
                    }
                }
            }
            else
            {
                EditorGUILayout.HelpBox("Bakery lightmap enhancements are disabled. Standard Unity baked GI will be used.", MessageType.Info);
            }

            EditorGUI.indentLevel--;
        }
        EditorGUILayout.EndFoldoutHeaderGroup();
        EditorGUILayout.Space();

        // Advanced / Standard options
        materialEditor.RenderQueueField();
        materialEditor.EnableInstancingField();
    }

    private void FindProperties(MaterialProperty[] props)
    {
        vrcAdditiveOnly = FindProperty("_VRCLightVolumeAdditiveOnly", props, false);
        bakerySH = FindProperty("_BAKERY_SH", props, false);
        bakeryMonoSH = FindProperty("_BAKERY_MONOSH", props, false);
        bakerySHNonLinear = FindProperty("_BAKERY_SHNONLINEAR", props, false);
        bakeryLMSpec = FindProperty("_BAKERY_LMSPEC", props, false);
        bakeryBicubic = FindProperty("_BAKERY_BICUBIC", props, false);
    }

    private static void SetKeyword(Material m, string keyword, bool state, MaterialProperty prop)
    {
        if (state)
            m.EnableKeyword(keyword);
        else
            m.DisableKeyword(keyword);

        if (prop != null)
            prop.floatValue = state ? 1.0f : 0.0f;
    }
}
#endif
