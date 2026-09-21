using UnityEngine;

public class HydrantController : WaterObjectController
{
	private const float WATER_PRESSURE = 3f;

	[SerializeField]
	[Tooltip("The output connection of the hydrant")]
	private ConnectionController connection;

	private bool isOpen;

	private void Start()
	{
		base.InputWaterPressure = 3f;
	}

	private void OnTriggerEnter(Collider other)
	{
		if (other.CompareTag("HydrantKey"))
		{
			isOpen = !isOpen;
			UpdateWaterPressure();
		}
	}

	public override void UpdateWaterPressure()
	{
		base.InputWaterPressure = 3f;
		if (isOpen)
		{
			base.OutputWaterPressure = base.InputWaterPressure;
		}
		else
		{
			base.OutputWaterPressure = 0f;
		}
		connection.UpdateWaterPressure(base.OutputWaterPressure);
	}
}
