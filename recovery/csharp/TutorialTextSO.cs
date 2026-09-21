using System.Collections.Generic;
using UnityEngine;

[CreateAssetMenu]
public class TutorialTextSO : ScriptableObject
{
	public List<string> _tutTextsGermanCity = new List<string>();

	public List<string> _tutTextsEnglishCity = new List<string>();

	public List<string> _tutTextsGermanForest = new List<string>();

	public List<string> _tutTextsEnglishForest = new List<string>();

	public bool textIsEnglish;
}
