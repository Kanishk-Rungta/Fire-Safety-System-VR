using System.Collections.Generic;
using UnityEngine;
using UnityEngine.XR;

[RequireComponent(typeof(Animator))]
public class HandAnimationController : MonoBehaviour
{
	[SerializeField]
	[Tooltip("Is it a Left or a Right hand")]
	private HandTypes handType;

	[SerializeField]
	[Tooltip("Flag whether every button should curl all fingers")]
	private bool useAsFist;

	[SerializeField]
	[Tooltip("How fast the Thumb curls when A/B/X/Y is pressed since those are no triggers")]
	[Range(0f, 10f)]
	private float thumbMoveSpeed = 0.25f;

	[SerializeField]
	[Tooltip("The animator of the hand (when not set in inspector, it will be retrieved in Start)")]
	private Animator animator;

	private InputDevice inputDevice;

	private float thumbValue;

	private float indexValue;

	private float threeFingersValue;

	private void Start()
	{
		if (!animator)
		{
			animator = GetComponent<Animator>();
		}
		inputDevice = GetInputDevice();
	}

	private void Update()
	{
		AnimateHand();
	}

	private InputDevice GetInputDevice()
	{
		int desiredCharacteristics = 0x44 | ((handType == HandTypes.LEFT) ? 256 : 512);
		List<InputDevice> list = new List<InputDevice>();
		InputDevices.GetDevicesWithCharacteristics((InputDeviceCharacteristics)desiredCharacteristics, list);
		return list[0];
	}

	private void AnimateHand()
	{
		inputDevice.TryGetFeatureValue(CommonUsages.primaryButton, out var value);
		inputDevice.TryGetFeatureValue(CommonUsages.secondaryButton, out var value2);
		thumbValue += ((value || value2) ? thumbMoveSpeed : (0f - thumbMoveSpeed)) * Time.deltaTime;
		thumbValue = Mathf.Clamp01(thumbValue);
		inputDevice.TryGetFeatureValue(CommonUsages.trigger, out indexValue);
		inputDevice.TryGetFeatureValue(CommonUsages.grip, out threeFingersValue);
		if (useAsFist)
		{
			float value3 = Mathf.Max(thumbValue, indexValue, threeFingersValue);
			animator.SetFloat("Thumb", value3);
			animator.SetFloat("Index", value3);
			animator.SetFloat("ThreeFingers", value3);
		}
		else
		{
			animator.SetFloat("Thumb", thumbValue);
			animator.SetFloat("Index", indexValue);
			animator.SetFloat("ThreeFingers", threeFingersValue);
		}
	}
}
