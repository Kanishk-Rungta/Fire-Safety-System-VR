using UnityEngine;

public class SuctionStrainerController : MovableParentWaterObject
{
	[SerializeField]
	[Tooltip("The output connection")]
	private ConnectionController outputConnection;

	[SerializeField]
	[Tooltip("How much Pressure should the suction strainer have, when in the lake")]
	private float connectedPressure = 3f;

	private bool isConnectedToLake;

	public override void AdjustTransformOnConnection(Transform currentConnectionTransform, Transform targetTransform, bool fixedConnection, bool isHose)
	{
		if (!isHose)
		{
			base.AdjustTransformOnConnection(currentConnectionTransform, targetTransform, fixedConnection, isHose);
			if (fixedConnection)
			{
				rigidBody.constraints = RigidbodyConstraints.FreezeAll;
				outputConnection.Fixate();
			}
		}
	}

	public override void UpdateWaterPressure()
	{
		base.InputWaterPressure = (isConnectedToLake ? connectedPressure : 0f);
		base.OutputWaterPressure = base.InputWaterPressure;
		outputConnection.UpdateWaterPressure(base.OutputWaterPressure);
	}

	public override void OnClearConnection(bool wasFixedConnection)
	{
		if (wasFixedConnection)
		{
			setTransform = false;
			rigidBody.constraints = RigidbodyConstraints.None;
			outputConnection.UnFixate();
		}
	}

	public override void UnFixate()
	{
		if (!isUnfixating)
		{
			base.UnFixate();
			outputConnection.UnFixate();
			isUnfixating = false;
		}
	}

	public void SetConnectionToLake(bool isConnected)
	{
		isConnectedToLake = isConnected;
		UpdateWaterPressure();
	}
}
