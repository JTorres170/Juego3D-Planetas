using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class PauseMenu : MonoBehaviour
{
    public void SaveGame()
    {
        Debug.Log("SAVE");
    }

    public void LoadGame()
    {
        Debug.Log("LOAD");
    }

    public void QuitGame()
    {
        Application.Quit();
    }
}
