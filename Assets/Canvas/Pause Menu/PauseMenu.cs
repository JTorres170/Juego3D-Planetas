using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;

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

    public void MainMenu()
    {
        SceneManager.LoadScene("MainMenuScene");
    }

    public void QuitGame()
    {
        Application.Quit();
    }
}
