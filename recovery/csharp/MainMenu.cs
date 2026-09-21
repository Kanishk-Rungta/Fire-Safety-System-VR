using UnityEngine;
using UnityEngine.SceneManagement;

public class MainMenu : MonoBehaviour
{
	public void OnPlayForest()
	{
		SceneManager.LoadScene("ForestScene");
	}

	public void OnPlayCity()
	{
		SceneManager.LoadScene("CityScene");
	}

	public void OnBackToMenu()
	{
		SceneManager.LoadScene("Menue");
	}

	public void OnQuitGame()
	{
		Debug.Log("Quit");
		Application.Quit();
	}
}
