using UnityEngine;

[ExecuteAlways]
public class HoseController : WaterObjectController
{
	[SerializeField]
	[Tooltip("The connections of the hose")]
	private HoseConnectionController[] connections = new HoseConnectionController[2];

	[SerializeField]
	[Tooltip("The size of the hose")]
	private HoseTypes hoseType = HoseTypes.C;

	[SerializeField]
	[Tooltip("The line renderer")]
	private LineRenderer lineRenderer;

	[SerializeField]
	[Tooltip("The positions of the line ends")]
	private Transform[] lineEnds = new Transform[2];

	private float pressureLoss;

	private int inputConnectionIndex = -1;

	private void Start()
	{
		switch (hoseType)
		{
		case HoseTypes.A:
			pressureLoss = 0f;
			break;
		case HoseTypes.B:
			pressureLoss = 0.2f;
			break;
		case HoseTypes.C:
			pressureLoss = 0.35f;
			break;
		default:
			Debug.LogError("This should never happen!");
			break;
		}
	}

	private void Update()
	{
		lineRenderer.SetPosition(0, lineEnds[0].position);
		lineRenderer.SetPosition(1, lineEnds[1].position);
		UpdateWaterPressure();
	}

	public override void UpdateWaterPressure()
	{
		if (inputConnectionIndex == -1)
		{
			int num = 0;
			while (inputConnectionIndex == -1 && num < connections.Length)
			{
				if (connections[num].OutputWaterPressure > 0f)
				{
					inputConnectionIndex = num;
					connections[(num + 1) % connections.Length].WaterPressureViaConnection = false;
				}
				num++;
			}
		}
		else
		{
			base.InputWaterPressure = connections[inputConnectionIndex].OutputWaterPressure;
			base.OutputWaterPressure = Mathf.Clamp(base.InputWaterPressure - pressureLoss, 0f, float.MaxValue);
			connections[(inputConnectionIndex + 1) % connections.Length].UpdateWaterPressure(base.OutputWaterPressure);
			if (!connections[inputConnectionIndex].ConnectedObject)
			{
				connections[(inputConnectionIndex + 1) % connections.Length].WaterPressureViaConnection = true;
				inputConnectionIndex = -1;
			}
		}
	}
}
