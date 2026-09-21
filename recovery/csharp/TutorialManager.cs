using System.Collections.Generic;
using UnityEngine;

public class TutorialManager : MonoBehaviour
{
	[SerializeField]
	private List<GameObject> tutTexts = new List<GameObject>();

	[SerializeField]
	private int tutProgress;

	[SerializeField]
	private bool cityScene;

	[SerializeField]
	private bool forestScene;

	public int TutProgress
	{
		get
		{
			return tutProgress;
		}
		set
		{
			tutProgress = value;
		}
	}

	public bool ForestScene
	{
		get
		{
			return forestScene;
		}
		set
		{
			forestScene = value;
		}
	}

	public bool CityScene
	{
		get
		{
			return cityScene;
		}
		set
		{
			cityScene = value;
		}
	}

	public void ChangeTask()
	{
		tutTexts[tutProgress].gameObject.SetActive(value: true);
		tutTexts[tutProgress - 1].gameObject.SetActive(value: false);
	}
}
