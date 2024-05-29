using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;

public class MainMenu : MonoBehaviour
{
    public void NewGame()
    {
        SceneManager.LoadScene("NewGameScene");
    }

    public void LoadGame()
    {
        Debug.Log("Working on it...");
    }

    public void QuitGame()
    {
        Application.Quit();
    }
}
