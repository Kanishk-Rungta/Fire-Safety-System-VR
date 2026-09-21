using System.Collections.Generic;
using UnityEngine;
using UnityEngine.XR;
using UnityEngine.XR.Interaction.Toolkit;

public class TeleportationController : MonoBehaviour
{
	[SerializeField]
	[Tooltip("How much the stick must be moved to activate the line")]
	[Range(0.1f, 0.95f)]
	private float deadzone = 0.5f;

	[SerializeField]
	[Tooltip("What kind of hand is it")]
	private HandTypes handType;

	private InputDevice inputDevice;

	private XRInteractorLineVisual lineVisual;

	private void Start()
	{
		int desiredCharacteristics = 0x44 | ((handType == HandTypes.LEFT) ? 256 : 512);
		List<InputDevice> list = new List<InputDevice>();
		InputDevices.GetDevicesWithCharacteristics((InputDeviceCharacteristics)desiredCharacteristics, list);
		if (list.Count > 0)
		{
			inputDevice = list[0];
		}
		lineVisual = GetComponent<XRInteractorLineVisual>();
	}

	private void Update()
	{
		inputDevice.TryGetFeatureValue(CommonUsages.primary2DAxis, out var value);
		lineVisual.enabled = value.y > deadzone;
	}
}
