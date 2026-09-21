using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class JetPipeController : MovableParentWaterObject
{
	private const float MIN_WATER_PRESSURE = 0.5f;

	[Header("Connection")]
	[SerializeField]
	[Tooltip("The input connection of the jet pipe")]
	private ConnectionController inputConnection;

	[Header("Animation")]
	[SerializeField]
	[Tooltip("The animated lever that shows whether the pipe is opened or not")]
	private Transform openerLever;

	[SerializeField]
	[Tooltip("How much time the opening or closing animation takes")]
	private float openingClosingAnimationLength = 0.1f;

	[Header("Particles")]
	[SerializeField]
	[Tooltip("The water particle system")]
	private ParticleSystem waterParticleSystem;

	[Header("Sound")]
	[SerializeField]
	[Tooltip("Audiosource of the JetPipe")]
	private AudioSource waterSound;

	private Queue<IEnumerator> animationQueue = new Queue<IEnumerator>();

	private bool isOpeningOrClosing;

	private bool isActive;

	private void Update()
	{
		if (!isOpeningOrClosing && animationQueue.Count > 0)
		{
			StartCoroutine(animationQueue.Dequeue());
		}
		if (isActive && base.OutputWaterPressure > 0.5f)
		{
			waterParticleSystem.Play();
			if (!waterSound.isPlaying)
			{
				waterSound.Play();
			}
		}
		else
		{
			waterParticleSystem.Stop();
			waterSound.Stop();
		}
	}

	public override void UpdateWaterPressure()
	{
		base.InputWaterPressure = inputConnection.OutputWaterPressure;
		base.OutputWaterPressure = base.InputWaterPressure;
	}

	public override void AdjustTransformOnConnection(Transform currentConnectionTransform, Transform targetTransform, bool fixedConnection, bool isHose)
	{
		if (fixedConnection)
		{
			base.AdjustTransformOnConnection(currentConnectionTransform, targetTransform, fixedConnection, isHose);
			rigidBody.constraints = RigidbodyConstraints.FreezeAll;
			inputConnection.Fixate();
		}
	}

	public override void OnClearConnection(bool wasFixedConnection)
	{
		if (wasFixedConnection)
		{
			setTransform = false;
			rigidBody.constraints = RigidbodyConstraints.None;
			inputConnection.UnFixate();
		}
	}

	public override void UnFixate()
	{
		if (!isUnfixating)
		{
			base.UnFixate();
			inputConnection.UnFixate();
			isUnfixating = false;
		}
	}

	private IEnumerator RotateOpener(bool isOpening)
	{
		float rotationPerSecond = (isOpening ? (-90f) : 90f) / openingClosingAnimationLength;
		float wholeAnimationTime = 0f;
		while (wholeAnimationTime < openingClosingAnimationLength)
		{
			float num = Time.deltaTime;
			wholeAnimationTime += num;
			if (wholeAnimationTime > openingClosingAnimationLength)
			{
				num -= wholeAnimationTime % openingClosingAnimationLength;
			}
			openerLever.Rotate(0f, 0f, rotationPerSecond * num, Space.Self);
			yield return null;
		}
		isOpeningOrClosing = false;
	}

	public void OnActivate()
	{
		if (!isActive)
		{
			isActive = true;
			animationQueue.Enqueue(RotateOpener(isOpening: true));
		}
	}

	public void OnDeactivate()
	{
		if (isActive)
		{
			isActive = false;
			animationQueue.Enqueue(RotateOpener(isOpening: false));
		}
	}
}
