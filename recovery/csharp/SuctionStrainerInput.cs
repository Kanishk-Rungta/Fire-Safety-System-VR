using UnityEngine;

public class SuctionStrainerInput : MonoBehaviour
{
	[SerializeField]
	[Tooltip("The suction strainer")]
	private SuctionStrainerController suctionStrainer;

	private void OnTriggerEnter(Collider other)
	{
		if (other.CompareTag("Lake"))
		{
			suctionStrainer.SetConnectionToLake(isConnected: true);
		}
	}

	private void OnTriggerExit(Collider other)
	{
		if (other.CompareTag("Lake"))
		{
			suctionStrainer.SetConnectionToLake(isConnected: false);
		}
	}
}
