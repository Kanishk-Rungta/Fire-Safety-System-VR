using UnityEngine;

public class ConnectionController : WaterObjectController
{
	[SerializeField]
	[Tooltip("Flag whether the water pressure is updated via the connected ConnectionController")]
	protected bool waterPressureViaConnection = true;

	[SerializeField]
	[Tooltip("The size of the connection")]
	protected HoseTypes connectionSize = HoseTypes.C;

	[SerializeField]
	[Tooltip("Flag whether the connection is movable")]
	protected bool isMovable;

	[SerializeField]
	[Tooltip("The parent object of the connection")]
	protected WaterObjectController parentObject;

	protected bool isClearing;

	protected bool isFixating;

	protected bool isUnfixating;

	protected bool isConnectedToFixated;

	protected bool isFixated;

	protected Vector3 lastPosition;

	protected Quaternion lastRotation;

	protected bool isParentMovable;

	public ConnectionController ConnectedObject { get; protected set; }

	private void Start()
	{
		lastPosition = base.transform.position;
		lastRotation = base.transform.rotation;
		isParentMovable = (bool)parentObject && parentObject.GetType().IsSubclassOf(typeof(MovableParentWaterObject));
	}

	private void Update()
	{
		if (!isFixated && (bool)ConnectedObject && (!lastPosition.Equals(base.transform.position) || !lastRotation.Equals(base.transform.rotation)))
		{
			ConnectedObject.MoveAccordingly(base.transform);
		}
		lastPosition = base.transform.position;
		lastRotation = base.transform.rotation;
	}

	private void OnTriggerEnter(Collider other)
	{
		if ((bool)ConnectedObject || other.gameObject.layer != base.gameObject.layer)
		{
			return;
		}
		ConnectionController component = other.GetComponent<ConnectionController>();
		if (((bool)component.ConnectedObject && !(component.ConnectedObject == this)) || component.connectionSize != connectionSize)
		{
			return;
		}
		ConnectedObject = component;
		if (isMovable && !isFixated)
		{
			isConnectedToFixated = !component.isMovable || component.isFixated;
			if (isParentMovable)
			{
				((MovableParentWaterObject)parentObject).AdjustTransformOnConnection(base.transform, other.transform, isConnectedToFixated, ConnectedObject.GetType() == typeof(HoseConnectionController));
			}
		}
	}

	public override void UpdateWaterPressure()
	{
		if (waterPressureViaConnection)
		{
			base.InputWaterPressure = (ConnectedObject ? ConnectedObject.OutputWaterPressure : 0f);
			base.OutputWaterPressure = base.InputWaterPressure;
			parentObject.UpdateWaterPressure();
		}
	}

	protected virtual void MoveAccordingly(Transform other)
	{
	}

	public void UpdateWaterPressure(float waterPressure)
	{
		if (!waterPressureViaConnection)
		{
			base.InputWaterPressure = waterPressure;
			base.OutputWaterPressure = waterPressure;
			if ((bool)ConnectedObject)
			{
				ConnectedObject.UpdateWaterPressure();
			}
		}
	}

	public virtual void OnClearConnection()
	{
		if (!isClearing && (bool)ConnectedObject)
		{
			isClearing = true;
			ConnectedObject.OnClearConnection();
			ConnectedObject = null;
			if (isParentMovable)
			{
				((MovableParentWaterObject)parentObject).OnClearConnection(isConnectedToFixated);
			}
			isConnectedToFixated = false;
			UpdateWaterPressure();
		}
		isClearing = false;
	}

	public bool CheckOnTriggerEnter(ConnectionController connection)
	{
		if (connection.connectionSize == connectionSize)
		{
			if ((bool)ConnectedObject)
			{
				return ConnectedObject == connection;
			}
			return true;
		}
		return false;
	}

	public void Fixate()
	{
		if (!isFixating)
		{
			isFixating = true;
			if ((bool)ConnectedObject)
			{
				ConnectedObject.Fixate();
			}
			isFixated = true;
		}
		isFixating = false;
	}

	public void UnFixate()
	{
		if (!isUnfixating)
		{
			isUnfixating = true;
			if ((bool)ConnectedObject)
			{
				ConnectedObject.UnFixate();
			}
			if (isParentMovable)
			{
				((MovableParentWaterObject)parentObject).UnFixate();
			}
			isFixated = false;
		}
		isUnfixating = false;
	}
}
