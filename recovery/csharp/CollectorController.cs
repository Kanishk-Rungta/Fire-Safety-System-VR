using UnityEngine;

public class CollectorController : MovableParentWaterObject
{
	[Header("Connections")]
	[SerializeField]
	[Tooltip("Array including all input connections")]
	private ConnectionController[] inputConnections = new ConnectionController[2];

	[SerializeField]
	[Tooltip("The output connection")]
	private ConnectionController outputConnection;

	public override void UpdateWaterPressure()
	{
		float num = 0f;
		ConnectionController[] array = inputConnections;
		foreach (ConnectionController connectionController in array)
		{
			num += connectionController.OutputWaterPressure;
		}
		base.InputWaterPressure = num;
		base.OutputWaterPressure = base.InputWaterPressure;
		outputConnection.UpdateWaterPressure(base.OutputWaterPressure);
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
			ConnectionController[] array = inputConnections;
			for (int i = 0; i < array.Length; i++)
			{
				array[i].Fixate();
			}
			outputConnection.Fixate();
		}
	}

	public override void OnClearConnection(bool wasFixedConnection)
	{
		if (wasFixedConnection)
		{
			setTransform = false;
			UnFixate();
		}
	}

	public override void UnFixate()
	{
		if (!isUnfixating)
		{
			base.UnFixate();
			ConnectionController[] array = inputConnections;
			for (int i = 0; i < array.Length; i++)
			{
				array[i].UnFixate();
			}
			outputConnection.UnFixate();
			isUnfixating = false;
		}
	}
}
