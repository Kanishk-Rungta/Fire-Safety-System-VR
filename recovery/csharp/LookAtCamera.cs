using UnityEngine;

public class LookAtCamera : MonoBehaviour
{
	public Camera m_Camera;

	private void LateUpdate()
	{
		base.transform.LookAt(base.transform.position + m_Camera.transform.rotation * Vector3.forward, Vector3.up);
	}
}
