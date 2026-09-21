using UnityEngine;

public abstract class WaterObjectController : MonoBehaviour
{
	public float InputWaterPressure { get; protected set; }

	public float OutputWaterPressure { get; protected set; }

	public abstract void UpdateWaterPressure();
}
