using UnityEngine;

public class TutorialConnectionControler : MonoBehaviour
{
	[SerializeField]
	private TutorialManager tutManger;

	[SerializeField]
	[Tooltip("Number from TMPro")]
	private int tutorialNumber;

	public int TutorialNumber
	{
		get
		{
			return tutorialNumber;
		}
		set
		{
			tutorialNumber = value;
		}
	}

	private void OnTriggerEnter(Collider other)
	{
		if (other.gameObject.CompareTag("TubeB"))
		{
			if (TutorialNumber == tutManger.TutProgress)
			{
				tutManger.TutProgress++;
				tutManger.ChangeTask();
			}
		}
		else if (other.gameObject.CompareTag("TubeC"))
		{
			if (TutorialNumber == tutManger.TutProgress)
			{
				tutManger.TutProgress++;
				tutManger.ChangeTask();
			}
		}
		else if (other.gameObject.CompareTag("Connection"))
		{
			if (TutorialNumber == tutManger.TutProgress)
			{
				tutManger.TutProgress++;
				tutManger.ChangeTask();
			}
		}
		else if (other.gameObject.CompareTag("HydrantKey") && TutorialNumber == tutManger.TutProgress)
		{
			tutManger.TutProgress++;
			tutManger.ChangeTask();
		}
	}

	public void OnSelectEntered()
	{
		if (TutorialNumber == tutManger.TutProgress)
		{
			tutManger.TutProgress++;
			tutManger.ChangeTask();
		}
	}
}
