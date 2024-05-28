using System.Collections;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using UnityEngine;

public static class SaveSystem
{
    // Rutas de guardado
    public static readonly string savePathSlot1 = Application.persistentDataPath + "/game_01.save";
    public static readonly string savePathSlot2 = Application.persistentDataPath + "/game_02.save";
    public static readonly string savePathSlot3 = Application.persistentDataPath + "/game_03.save";

    // Encriptado
    private static readonly byte[] aesKey = Encoding.UTF8.GetBytes("ClaveSecretisima");
    private static readonly byte[] aesIV = Encoding.UTF8.GetBytes("ClaveSecretisima");

    // Guardar
    public static IEnumerator SaveGame(PlayerData playerData, FirstPlanetData fpData, int slot)
    {
        GameData gameData = new GameData(playerData, fpData);

        string json_gameData = JsonUtility.ToJson(playerData);

        byte[] encryptedGameData = EncryptStringToBytes_Aes(json_gameData);

        switch (slot)
        {
            case 1:
                File.WriteAllBytes(savePathSlot1, encryptedGameData);
                PlayerPrefs.SetString("slotDate1", System.DateTime.Now.ToString());

                break;
            case 2:
                File.WriteAllBytes(savePathSlot2, encryptedGameData);
                PlayerPrefs.SetString("slotDate2", System.DateTime.Now.ToString());

                break;
            case 3:
                File.WriteAllBytes(savePathSlot3, encryptedGameData);
                PlayerPrefs.SetString("slotDate3", System.DateTime.Now.ToString());

                break;
        }

        Debug.Log("Data saved at " + slot);
        yield return null;
    }

    // Cargar
    public static IEnumerator LoadGame(PlayerData playerData, FirstPlanetData fpData, int slot)
    {
        byte[] encryptedData;

        switch (slot)
        {
            case 1:
                encryptedData = File.ReadAllBytes(savePathSlot1);
                break;
            case 2:
                encryptedData = File.ReadAllBytes(savePathSlot2);
                break;
            case 3:
                encryptedData = File.ReadAllBytes(savePathSlot3);
                break;
            default:
                yield break;
        }

        if (encryptedData != null)
        {
            string decryptedData = DecryptStringFromBytes_Aes(encryptedData);
            Debug.Log(decryptedData);
            JsonUtility.FromJsonOverwrite(decryptedData, playerData);
            Debug.Log(playerData.playerPosition);
            // GameData gameData = JsonUtility.FromJson<GameData>(decryptedData);
            // JsonUtility.FromJsonOverwrite(JsonUtility.ToJson(gameData.playerData), playerData);
            // JsonUtility.FromJsonOverwrite(JsonUtility.ToJson(gameData.firstPlanetData), fpData);
        }

        Debug.Log("Data from slot " + slot + " loaded correctly");
        yield return null;
    }

    // Encriptar
    private static byte[] EncryptStringToBytes_Aes(string plainText)
    {
        byte[] encrypted;

        using (Aes aesAlg = Aes.Create())
        {
            aesAlg.Key = aesKey;
            aesAlg.IV = aesIV;

            ICryptoTransform encryptor = aesAlg.CreateEncryptor(aesAlg.Key, aesAlg.IV);

            using (MemoryStream msEncrypt = new MemoryStream())
            {
                using (CryptoStream csEncrypt = new CryptoStream(msEncrypt, encryptor, CryptoStreamMode.Write))
                {
                    using (StreamWriter swEncrypt = new StreamWriter(csEncrypt))
                    {
                        swEncrypt.Write(plainText);
                    }
                }
                encrypted = msEncrypt.ToArray();
            }
        }
        return encrypted;
    }

    // Decriptar
    private static string DecryptStringFromBytes_Aes(byte[] cipherText)
    {
        string plaintext = null;

        using (Aes aesAlg = Aes.Create())
        {
            aesAlg.Key = aesKey;
            aesAlg.IV = aesIV;

            ICryptoTransform decryptor = aesAlg.CreateDecryptor(aesAlg.Key, aesAlg.IV);

            using (MemoryStream msDecrypt = new MemoryStream(cipherText))
            {
                using (CryptoStream csDecrypt = new CryptoStream(msDecrypt, decryptor, CryptoStreamMode.Read))
                {
                    using (StreamReader srDecrypt = new StreamReader(csDecrypt))
                    {
                        plaintext = srDecrypt.ReadToEnd();
                    }
                }
            }
        }
        return plaintext;
    }
}

[System.Serializable]
public class GameData
{
    public PlayerData playerData;
    public FirstPlanetData firstPlanetData;

    public GameData(PlayerData playerData, FirstPlanetData firstPlanetData)
    {
        this.playerData = playerData;
        this.firstPlanetData = firstPlanetData;
    }
}
