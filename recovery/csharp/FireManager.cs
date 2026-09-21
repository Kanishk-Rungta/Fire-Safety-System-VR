using UnityEngine;

public class FireManager : MonoBehaviour
{
	[SerializeField]
	[Tooltip("Array of all the Fires in the scene")]
	private FireController[] fires;

	private void Start()
	{
		int num = Random.Range(0, fires.Length);
		fires[num].gameObject.SetActive(value: true);
	}
}
