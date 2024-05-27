using UnityEngine;

[CreateAssetMenu(menuName = "Juego3D-Planetas/PlayerData")]
public class PlayerData : ScriptableObject
{
    public Vector3 playerPosition;
    public float mouseSensitivityX;
	public float mouseSensitivityY;
}