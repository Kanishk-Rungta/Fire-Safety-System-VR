using UnityEngine;

[RequireComponent(typeof(Rigidbody))]
public abstract class MovableParentWaterObject : WaterObjectController
{
	[SerializeField]
	[Tooltip("The Rigidbody of this Object (if not set, it will be retrieved in the Start method)")]
	protected Rigidbody rigidBody;

	protected bool setTransform;

	protected Vector3 targetPosition;

	protected Quaternion targetRotation;

	protected bool isUnfixating;

	protected virtual void Start()
	{
		if (!rigidBody)
		{
			rigidBody = GetComponent<Rigidbody>();
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

	public virtual void AdjustTransformOnConnection(Transform currentConnectionTransform, Transform targetTransform, bool fixedConnection, bool isHose)
	{
		setTransform = true;
		Quaternion quaternion = targetTransform.rotation * Quaternion.Inverse(currentConnectionTransform.rotation);
		base.transform.rotation = quaternion * base.transform.rotation;
		base.transform.Rotate(0f, 180f, 0f, Space.Self);
		base.transform.position += targetTransform.position - currentConnectionTransform.position;
		targetPosition = base.transform.position;
		targetRotation = base.transform.rotation;
	}

	public virtual void UnFixate()
	{
		isUnfixating = true;
		setTransform = false;
		rigidBody.constraints = RigidbodyConstraints.None;
	}

	public abstract void OnClearConnection(bool wasFixedConnection);
}
