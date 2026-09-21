using UnityEngine;

public class ChangeLanguage : MonoBehaviour
{
	[SerializeField]
	[Tooltip("Connection to give the TMpro the different strings for the texts")]
	private TutorialTextSO SOLangugeBool;

	public void OnClickEnglish()
	{
		SOLangugeBool.textIsEnglish = true;
	}

	public void OnClickGerman()
	{
		SOLangugeBool.textIsEnglish = false;
	}
}
