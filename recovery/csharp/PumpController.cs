using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class PumpController : WaterObjectController
{
	[SerializeField]
	[Tooltip("Factor that is multiplied by the input pressure to calculate the output pressure")]
	private float pumpMultiplier = 3f;

	[Header("Connections")]
	[SerializeField]
	[Tooltip("The input connection")]
	private ConnectionController inputConnection;

	[SerializeField]
	[Tooltip("Array of the output connections")]
	private ConnectionController[] outputConnections = new ConnectionController[2];

	[Header("Animation")]
	[SerializeField]
	[Tooltip("Array of the objects that are animated when opening or closing a connection")]
	private Transform[] outputOpener = new Transform[2];

	[SerializeField]
	[Tooltip("How long the animation takes")]
	private float openingClosingAnimationLength = 1f;

	private bool[] isOpenOutputConnection;

	private bool[] isOpeningOrClosing;

	private void Start()
	{
		int num = outputConnections.Length;
		isOpenOutputConnection = new bool[num];
		isOpeningOrClosing = new bool[num];
	}

	public override void UpdateWaterPressure()
	{
		base.InputWaterPressure = inputConnection.OutputWaterPressure;
		base.OutputWaterPressure = base.InputWaterPressure * pumpMultiplier;
		List<int> list = new List<int>();
		for (int i = 0; i < isOpenOutputConnection.Length; i++)
		{
			if (isOpenOutputConnection[i])
			{
				list.Add(i);
			}
		}
		float num = base.OutputWaterPressure / (float)list.Count;
		for (int j = 0; j < isOpenOutputConnection.Length; j++)
		{
			outputConnections[j].UpdateWaterPressure(isOpenOutputConnection[j] ? num : 0f);
		}
	}

	private IEnumerator RotateOpener(int index, bool isOpening)
	{
		float rotationPerSecond = (isOpening ? (-360f) : 360f) / openingClosingAnimationLength;
		float wholeAnimationTime = 0f;
		while (wholeAnimationTime < openingClosingAnimationLength)
		{
			float num = Time.deltaTime;
			wholeAnimationTime += num;
			if (wholeAnimationTime > openingClosingAnimationLength)
			{
				num -= wholeAnimationTime % openingClosingAnimationLength;
			}
			outputOpener[index].Rotate(0f, 0f, rotationPerSecond * num, Space.Self);
			yield return null;
		}
		isOpeningOrClosing[index] = false;
	}

	public void OnToggleConnection(int index)
	{
		if (!isOpeningOrClosing[index])
		{
			isOpeningOrClosing[index] = true;
			isOpenOutputConnection[index] = !isOpenOutputConnection[index];
			UpdateWaterPressure();
			StartCoroutine(RotateOpener(index, isOpenOutputConnection[index]));
		}
	}
}
