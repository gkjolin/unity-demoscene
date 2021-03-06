Shader "Raymarching/Lava"
{

Properties
{
    [Header(GBuffer)]
    _Diffuse("Diffuse", Color) = (1.0, 1.0, 1.0, 1.0)
    _Specular("Specular", Color) = (0.0, 0.0, 0.0, 0.0)
    _Emission("Emission", Color) = (0.0, 0.0, 0.0, 0.0)

    [Header(Raymarching Settings)]
    _Loop("Loop", Range(1, 100)) = 30
    _MinDistance("Minimum Distance", Range(0.001, 0.1)) = 0.01
    _ShadowLoop("Shadow Loop", Range(1, 100)) = 10
    _ShadowMinDistance("Shadow Minimum Distance", Range(0.001, 0.1)) = 0.01
    _ShadowExtraBias("Shadow Extra Bias", Range(0.0, 1.0)) = 0.01

// @block Properties
_CellularPower("Cellular Power", Range(0.0, 1.0)) = 0.5
[HDR] _LavaEmmisiveHigh("Lava Emmisive High", Color) = (1.0, 0.0, 0.0, 1.0)
[HDR] _LavaEmmisiveLow("Lava Emmisive Low", Color) = (1.0, 0.0, 0.0, 1.0)
_Noise("Noise", 2D) = "gray" {}
_FlowThreshold("Flow Threshold", Range(1.0, 2.0)) = 0.5
_FlowIntensity("Flow Intensity", Range(0.0, 1.0)) = 0.2
_FlowSpeed("Flow Speed", Range(0.0, 5.0)) = 0.2
// @endblock
}

SubShader
{

Tags
{
    "RenderType" = "Opaque"
    "DisableBatching" = "True"
}

Cull Off

CGINCLUDE

#define WORLD_SPACE

#define DISTANCE_FUNCTION DistanceFunction
#define POST_EFFECT PostEffect
#define PostEffectOutput GBufferOut

#include "Assets/uRaymarching/Shaders/Include/Common.cginc"
#include "Assets/uRaymarchingCustom/Common.cginc"

// @block DistanceFunction
#include "Assets/Demoscene/Shaders/Includes/Common.cginc"
#include "Assets/Demoscene/Shaders/Includes/Noise.cginc"

float _CellularPower;

inline float DistanceFunction(float3 pos)
{
    float2 c = cellular(float2(pos.xz));
    float h = pow(c.y - c.x, _CellularPower);

    float2 c2 = cellular(float2(3.0 * pos.xz));
    h += 0.5 * pow((c2.y - c2.x), _CellularPower);

    float2 c3 = cellular(float2(20.0 * pos.xz));
    //h += 0.05 * pow((c3.y - c3.x), _CellularPower);

    h += 0.002 * snoise(50.0 * pos.xz);
    return pos.y - h;
}
// @endblock

// @block PostEffect
float _TimelineTime;
float4 _LavaEmmisiveLow;
float4 _LavaEmmisiveHigh;
sampler2D _Noise;
float _FlowThreshold;
float _FlowIntensity;
float _FlowSpeed;

// https://www.shadertoy.com/view/lslXRS
float noise( in vec2 x ){
    return tex2D(_Noise, x*.01).x;
}

vec2 gradn(vec2 p)
{
	float ep = .09;
	float gradx = noise(vec2(p.x+ep,p.y))-noise(vec2(p.x-ep,p.y));
	float grady = noise(vec2(p.x,p.y+ep))-noise(vec2(p.x,p.y-ep));
	return vec2(gradx,grady);
}

float lavaFlow(in vec2 p)
{
	float z=2.;
	float rz = 0.;
	vec2 bp = p;
	for (float i= 1.; i < 4.; i++)
	{
		//primary flow speed
		p += _TimelineTime * .6 * _FlowSpeed;

		//secondary flow speed (speed of the perceived flow)
		bp += _TimelineTime * 1.9 * _FlowSpeed;

		//displacement field (try changing _TimelineTime multiplier)
		vec2 gr = gradn(i*p*.34 + _TimelineTime * 1.);

		//rotation of the displacement field
		// gr *= rotateMat(_TimelineTime * 6.-(0.05 * p.x + 0.03 * p.y) * 40.);
		gr = mul(rotateMat(_TimelineTime * 6.-(0.05 * p.x + 0.03 * p.y) * 40.), gr);

		//displace the system
		p += gr*.5;

		//add noise octave
		rz+= (sin(noise(p) * 7.) * 0.5 + 0.5) / z;

		//blend factor (blending displaced system with base system)
		//you could call this advection factor (.5 being low, .95 being high)
		p = mix(bp, p, .77);

		//intensity scaling
		z *= 1.4;
		//octave scaling
		p *= 2.;
		bp *= 1.9;
	}
	return rz;
}

inline void PostEffect(RaymarchInfo ray, inout PostEffectOutput o)
{
    float flow = lavaFlow(ray.endPos.xz);
    float4 emission = lerp(_LavaEmmisiveLow, _LavaEmmisiveHigh, saturate(remap(flow, 0.7, 0.8)));
    float flooded = step(ray.endPos.y, _FlowThreshold + _FlowIntensity * flow);
    o.emission = flooded * emission;
    o.normal.rgb = normalize(lerp(half3(0.0, 1.0, 0.0), o.normal.rgb, saturate(remap(ray.endPos.y - _FlowThreshold, -0.05, 0.1))));

    // debug flow
    // o.emission = lavaFlow(ray.endPos.xz) * _LavaEmmisiveHigh;
}
// @endblock

#include "Assets/uRaymarching/Shaders/Include/Raymarching.cginc"

ENDCG

Pass
{
    Tags { "LightMode" = "Deferred" }

    Stencil
    {
        Comp Always
        Pass Replace
        Ref 128
    }

    CGPROGRAM
    #include "Assets/uRaymarching/Shaders/Include/VertFragDirectScreen.cginc"
    #pragma target 3.0
    #pragma vertex Vert
    #pragma fragment Frag
    #pragma exclude_renderers nomrt
    #pragma multi_compile_prepassfinal
    #pragma multi_compile ___ UNITY_HDR_ON
    #pragma multi_compile OBJECT_SHAPE_CUBE OBJECT_SHAPE_SPHERE ___
    ENDCG
}

Pass
{
    Tags { "LightMode" = "ShadowCaster" }

    CGPROGRAM
    #include "Assets/uRaymarching/Shaders/Include/VertFragShadowObject.cginc"
    #pragma target 3.0
    #pragma vertex Vert
    #pragma fragment Frag
    #pragma fragmentoption ARB_precision_hint_fastest
    #pragma multi_compile_shadowcaster
    #pragma multi_compile OBJECT_SHAPE_CUBE OBJECT_SHAPE_SPHERE ___
    ENDCG
}

}

Fallback "Diffuse"

CustomEditor "uShaderTemplate.MaterialEditor"

}
