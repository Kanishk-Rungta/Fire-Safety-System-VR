namespace ExtensionMethods;

public static class FloatExtensionMethods
{
	public static float Map(this float value, float fromLow, float fromUp, float toLow, float toUp)
	{
		return (value - fromLow) / (fromUp - fromLow) * (toUp - toLow) + toLow;
	}
}
