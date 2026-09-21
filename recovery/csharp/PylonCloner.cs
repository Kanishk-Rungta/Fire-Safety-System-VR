using System;
using System.Collections.Generic;
using UnityEngine;

public class PylonCloner : MonoBehaviour
{
	[Serializable]
	public class Pool
	{
		public string tag;

		public GameObject pylonPrefab;

		public int size;
	}

	[SerializeField]
	private TutorialManager tM;

	public List<Pool> pools;

	private Dictionary<string, Queue<GameObject>> _poolDictionary;

	private void Start()
	{
		_poolDictionary = new Dictionary<string, Queue<GameObject>>();
		foreach (Pool pool in pools)
		{
			Queue<GameObject> queue = new Queue<GameObject>();
			for (int i = 0; i < pool.size; i++)
			{
				GameObject gameObject = UnityEngine.Object.Instantiate(pool.pylonPrefab);
				gameObject.SetActive(value: false);
				queue.Enqueue(gameObject);
			}
			_poolDictionary.Add(pool.tag, queue);
		}
	}

	public GameObject GetPylonInstance()
	{
		foreach (KeyValuePair<string, Queue<GameObject>> item in _poolDictionary)
		{
			foreach (GameObject item2 in item.Value)
			{
				if (!item2.activeSelf)
				{
					item2.SetActive(value: true);
					return item2;
				}
			}
		}
		return null;
	}

	public void OnGrabObject()
	{
		GetPylonInstance();
		if (tM.TutProgress == 0)
		{
			tM.TutProgress++;
			tM.ChangeTask();
		}
		else if (tM.TutProgress == 2)
		{
			tM.TutProgress++;
			tM.ChangeTask();
		}
	}
}
