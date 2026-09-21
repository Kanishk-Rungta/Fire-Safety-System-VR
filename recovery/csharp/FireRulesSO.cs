using UnityEngine;

[CreateAssetMenu]
public class FireRulesSO : ScriptableObject
{
	[Tooltip("How much HP a single Particle removes on hit")]
	public float particleDamage;

	[Tooltip("Maximal fire HP when neighbouring fires will be ignited")]
	public float fireUpperBorder;

	[Tooltip("Minimal fire HP when a fire is put out")]
	public float fireLowerBorder;

	[Tooltip("How many HP a fire gains per second")]
	public float fireMultiplicator;

	[Tooltip("Maximal RateOverTime value of smoke particle system")]
	public int maxSmokeParticles;

	[Tooltip("Maximal RateOverTime value of spark particle system")]
	public int maxSparkParticles;
}
