using UnityEngine;

[RequireComponent(typeof(Rigidbody))]
public class HoseConnectionController : ConnectionController
{
	[SerializeField]
	[Tooltip("The Rigidbody of this connection (if not set, it will be retrieved in the Start method)")]
	private Rigidbody rigidBody;

	private Vector3 targetPosition;

	private Quaternion targetRotation;

	private bool setTransform;

	private bool isFollowing;

	public bool WaterPressureViaConnection
	{
		set
		{
			waterPressureViaConnection = value;
		}
	}

	private void Start()
	{
		if (!rigidBody)
		{
			rigidBody = GetComponent<Rigidbody>();
		}
	}

	private void Update()
	{
		if (isFollowing)
		{
			MoveAccordingly(base.ConnectedObject.transform);
		}
	}

	private void LateUpdate()
	{
		if (setTransform)
		{
			base.transform.position = targetPosition;
			base.transform.rotation = targetRotation;
		}
	}

	private void OnTriggerEnter(Collider other)
	{
		if ((bool)base.ConnectedObject || other.gameObject.layer != base.gameObject.layer)
		{
			return;
		}
		ConnectionController component = other.GetComponent<ConnectionController>();
		if (!component.CheckOnTriggerEnter(this))
		{
			return;
		}
		base.ConnectedObject = component;
		if (base.ConnectedObject.GetType() == typeof(HoseConnectionController))
		{
			if (!((HoseConnectionController)base.ConnectedObject).isFollowing)
			{
				isFollowing = true;
				setTransform = true;
			}
		}
		else
		{
			MoveAccordingly(base.ConnectedObject.transform);
			setTransform = true;
			rigidBody.constraints = RigidbodyConstraints.FreezeAll;
		}
		UpdateWaterPressure();
	}

	private void StartFollowing()
	{
		if (base.ConnectedObject.GetType() == typeof(HoseConnectionController))
		{
			if (!isFollowing)
			{
				((HoseConnectionController)base.ConnectedObject).StopFollowing();
			}
			isFollowing = true;
			setTransform = true;
		}
	}

	private void StopFollowing()
	{
		if (base.ConnectedObject.GetType() == typeof(HoseConnectionController))
		{
			isFollowing = false;
			setTransform = false;
		}
	}

	protected override void MoveAccordingly(Transform other)
	{
		base.transform.position = other.position;
		base.transform.rotation = other.rotation;
		base.transform.Rotate(0f, 180f, 0f, Space.Self);
		targetPosition = base.transform.position;
		targetRotation = base.transform.rotation;
	}

	public override void OnClearConnection()
	{
		if (!isClearing && (bool)base.ConnectedObject)
		{
			rigidBody.constraints = RigidbodyConstraints.None;
			isClearing = true;
			base.ConnectedObject.OnClearConnection();
			base.ConnectedObject = null;
			setTransform = false;
			UpdateWaterPressure();
			parentObject.UpdateWaterPressure();
		}
		isClearing = false;
	}

	public void OnSelectEntered()
	{
		if ((bool)base.ConnectedObject && base.ConnectedObject.GetType() == typeof(HoseConnectionController))
		{
			((HoseConnectionController)base.ConnectedObject).StartFollowing();
		}
	}
}
