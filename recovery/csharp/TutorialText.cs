using TMPro;
using UnityEngine;

public class TutorialText : MonoBehaviour
{
	[SerializeField]
	private TutorialTextSO tutorialText;

	[SerializeField]
	private TutorialManager tM;

	[SerializeField]
	[Tooltip("Number from TMPro")]
	private int tutorialNumber;

	private TextMeshProUGUI textMeshPro;

	private void Awake()
	{
		textMeshPro = GetComponentInChildren<TextMeshProUGUI>();
		if (tM.CityScene)
		{
			if (tutorialText.textIsEnglish)
			{
				textMeshPro.text = tutorialText._tutTextsEnglishCity[tutorialNumber];
			}
			else if (!tutorialText.textIsEnglish)
			{
				textMeshPro.text = tutorialText._tutTextsGermanCity[tutorialNumber];
			}
		}
		else if (tM.ForestScene)
		{
			if (tutorialText.textIsEnglish)
			{
				textMeshPro.text = tutorialText._tutTextsEnglishForest[tutorialNumber];
			}
			else if (!tutorialText.textIsEnglish)
			{
				textMeshPro.text = tutorialText._tutTextsGermanForest[tutorialNumber];
			}
		}
	}
}
