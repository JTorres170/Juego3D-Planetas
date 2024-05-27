using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

[CustomEditor (typeof(GenTest))]
public class GenTestEditor : Editor
{
    public override void OnInspectorGUI()
    {
        DrawDefaultInspector();

        GenTest genTest = (GenTest)target;
        if (GUILayout.Button("Generate Terrain"))
        {
            genTest.GenerateTerrain();
        }
    }
}
