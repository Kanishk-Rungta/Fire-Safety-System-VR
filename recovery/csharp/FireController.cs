using System.Collections.Generic;
using ExtensionMethods;
using UnityEngine;

public class FireController : MonoBehaviour
{
	private const float ERROR_MARGIN = 1f;

	[Header("Fire values")]
	[SerializeField]
	[Tooltip("Multiple 'constants' saved in a scriptable object")]
	private FireRulesSO fireRulesVariables;

	[SerializeField]
	[Tooltip("The neighbouring FireControllers")]
	private FireController[] neighbours = new FireController[0];

	[SerializeField]
	[Tooltip("The current FireState")]
	private FireStates state;

	[Header("Sound")]
	[SerializeField]
	[Tooltip("The Sound controller of the fires")]
	private FireSoundController fireSound;

	[Header("Particle Systems")]
	[SerializeField]
	[Tooltip("The smoke particle system")]
	private ParticleSystem smokeParticleSystem;

	[SerializeField]
	[Tooltip("The sparks particle system")]
	private ParticleSystem sparksParticleSystem;

	private ParticleSystem.EmissionModule smokeEmission;

	private ParticleSystem.EmissionModule sparksEmission;

	private float fireHP;

	private Material fireMaterial;

	private int alphaID;

	private void Awake()
	{
		fireMaterial = GetComponent<Renderer>().material;
		alphaID = Shader.PropertyToID("Vector1_4341703ff49e4488933ac95a1c03527f");
		smokeEmission = smokeParticleSystem.emission;
		sparksEmission = sparksParticleSystem.emission;
	}

	private void OnEnable()
	{
		state = FireStates.ONFIRE;
		fireHP = fireRulesVariables.fireLowerBorder + 0.001f;
		fireSound.AddActiveFire();
		UpdateVisuals();
	}

	private void Update()
	{
		switch (state)
		{
		case FireStates.NONE:
			base.gameObject.SetActive(value: false);
			break;
		case FireStates.ONFIRE:
			if (fireHP < fireRulesVariables.fireUpperBorder && fireHP >= fireRulesVariables.fireLowerBorder)
			{
				fireHP = Mathf.Clamp(fireHP + fireRulesVariables.fireMultiplicator * Time.deltaTime, fireRulesVariables.fireLowerBorder - 1f, fireRulesVariables.fireUpperBorder + 1f);
				UpdateVisuals();
			}
			else if (fireHP >= fireRulesVariables.fireUpperBorder)
			{
				FireController[] array = neighbours;
				for (int i = 0; i < array.Length; i++)
				{
					array[i].gameObject.SetActive(value: true);
				}
			}
			break;
		}
	}

	private void OnParticleCollision(GameObject other)
	{
		if (state == FireStates.ONFIRE)
		{
			int collisionEvents = other.GetComponent<ParticleSystem>().GetCollisionEvents(base.gameObject, new List<ParticleCollisionEvent>());
			fireHP = Mathf.Clamp(fireHP - (float)collisionEvents * fireRulesVariables.particleDamage, fireRulesVariables.fireLowerBorder - 1f, fireRulesVariables.fireUpperBorder + 1f);
			if (fireHP < fireRulesVariables.fireLowerBorder)
			{
				state = FireStates.PUTOUT;
				fireSound.RemoveActiveFire();
				UpdateVisuals();
				smokeParticleSystem.Stop();
				sparksParticleSystem.Stop();
			}
		}
	}

	private void UpdateVisuals()
	{
		float num = fireHP.Map(fireRulesVariables.fireLowerBorder, fireRulesVariables.fireUpperBorder, 0f, 1f);
		fireMaterial.SetFloat(alphaID, num);
		smokeEmission.rateOverTime = new ParticleSystem.MinMaxCurve(num * (float)fireRulesVariables.maxSmokeParticles);
		sparksEmission.rateOverTime = new ParticleSystem.MinMaxCurve(num * (float)fireRulesVariables.maxSparkParticles);
	}
}
