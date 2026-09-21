using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class DistributorController : MovableParentWaterObject
{
	[Header("Connections")]
	[SerializeField]
	[Tooltip("The input connection")]
	private ConnectionController inputConnection;

	[SerializeField]
	[Tooltip("Array of the output connections")]
	private ConnectionController[] outputConnections = new ConnectionController[3];

	[Header("Animation")]
	[SerializeField]
	[Tooltip("Array of the objects that are animated when opening or closing a connection")]
	private Transform[] outputOpener = new Transform[3];

	[SerializeField]
	[Tooltip("How long the animation takes")]
	private float openingClosingAnimationLength = 1f;

	private bool[] isOpenOutputConnection;

	private bool[] isOpeningOrClosing;

	protected override void Start()
	{
		base.Start();
		int num = outputConnections.Length;
		isOpenOutputConnection = new bool[num];
		isOpeningOrClosing = new bool[num];
	}

	public override void UpdateWaterPressure()
	{
		base.InputWaterPressure = inputConnection.OutputWaterPressure;
		base.OutputWaterPressure = base.InputWaterPressure;
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

	public override void AdjustTransformOnConnection(Transform currentConnectionTransform, Transform targetTransform, bool fixedConnection, bool isHose)
	{
		if (isHose)
		{
			return;
		}
		base.AdjustTransformOnConnection(currentConnectionTransform, targetTransform, fixedConnection, isHose);
		if (fixedConnection)
		{
			rigidBody.constraints = RigidbodyConstraints.FreezeAll;
			ConnectionController[] array = outputConnections;
			for (int i = 0; i < array.Length; i++)
			{
				array[i].Fixate();
			}
			inputConnection.Fixate();
		}
	}

	public override void OnClearConnection(bool wasFixedConnection)
	{
		if (wasFixedConnection)
		{
			setTransform = false;
			rigidBody.constraints = RigidbodyConstraints.None;
			ConnectionController[] array = outputConnections;
			for (int i = 0; i < array.Length; i++)
			{
				array[i].UnFixate();
			}
			inputConnection.UnFixate();
		}
	}

	public override void UnFixate()
	{
		if (!isUnfixating)
		{
			base.UnFixate();
			ConnectionController[] array = outputConnections;
			for (int i = 0; i < array.Length; i++)
			{
				array[i].UnFixate();
			}
			inputConnection.UnFixate();
			isUnfixating = false;
		}
	}

	private IEnumerator RotateOpener(int index, bool isOpening)
	{
		float rotationPerSecond = (isOpening ? 90f : (-90f)) / openingClosingAnimationLength;
		float wholeAnimationTime = 0f;
		while (wholeAnimationTime < openingClosingAnimationLength)
		{
			float num = Time.deltaTime;
			wholeAnimationTime += num;
			if (wholeAnimationTime > openingClosingAnimationLength)
			{
				num -= wholeAnimationTime % openingClosingAnimationLength;
			}
			outputOpener[index].Rotate(0f, rotationPerSecond * num, 0f, Space.Self);
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
