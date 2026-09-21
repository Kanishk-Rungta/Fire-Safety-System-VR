using UnityEngine;

public class SetObjectActive : MonoBehaviour
{
	[SerializeField]
	[Tooltip("Put here the field for the task")]
	private GameObject obj;

	private void OnEnable()
	{
		obj.SetActive(value: true);
	}

	private void OnDisable()
	{
		obj.SetActive(value: false);
	}
}
