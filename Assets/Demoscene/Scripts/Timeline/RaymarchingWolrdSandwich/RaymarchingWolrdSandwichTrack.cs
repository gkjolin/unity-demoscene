using UnityEngine;
using UnityEngine.Playables;
using UnityEngine.Timeline;

namespace Demoscene
{
    [TrackColor(0.855f, 0.8623f, 0.87f)]
    [TrackClipType(typeof(RaymarchingWolrdSandwichClip))]
    [TrackBindingType(typeof(LocalTimeComponet))]
    public class RaymarchingWolrdSandwichTrack : TrackAsset
    {
        public override Playable CreateTrackMixer(PlayableGraph graph, GameObject go, int inputCount)
        {
            return ScriptPlayable<RaymarchingWolrdSandwichMixerBehaviour>.Create(graph, inputCount);
        }
    }
}