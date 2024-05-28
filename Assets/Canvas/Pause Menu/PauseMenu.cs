using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class PauseMenu : MonoBehaviour
{
    // Scriptable objects
    public PlayerData playerData;
    public FirstPlanetData fpData;

    public void SaveGame()
    {
        StartCoroutine(SaveSystem.SaveGame(playerData, fpData, 1));
    }

    public void LoadGame()
    {
        StartCoroutine(SaveSystem.LoadGame(playerData, fpData, 1));
    }

    public void QuitGame()
    {
        Application.Quit();
        Debug.Log("Goodbye!");
    }
}
