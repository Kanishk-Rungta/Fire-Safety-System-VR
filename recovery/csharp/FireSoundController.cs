using UnityEngine;

public class FireSoundController : MonoBehaviour
{
	[SerializeField]
	[Tooltip("Audiosource from the Fires")]
	private AudioSource fireSound;

	[SerializeField]
	[Tooltip("Connection to the tutorial manager")]
	private TutorialManager tutorialManager;

	private int activeFires;

	public void AddActiveFire()
	{
		activeFires++;
		if (!fireSound.isPlaying)
		{
			fireSound.Play();
		}
	}

	public void RemoveActiveFire()
	{
		activeFires--;
		if (activeFires == 0)
		{
			fireSound.Stop();
			tutorialManager.TutProgress++;
			tutorialManager.ChangeTask();
		}
	}
}
