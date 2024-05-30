Shader "Hidden/Clouds"
{
	
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		Cull Off ZWrite Off ZTest Always

		Pass
		{
			CGPROGRAM

			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			struct appdata {
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f {
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 viewVector : TEXCOORD1;
			};
			
			v2f vert (appdata v) {
				v2f output;
				output.pos = UnityObjectToClipPos(v.vertex);
				output.uv = v.uv;
				float3 viewVector = mul(unity_CameraInvProjection, float4(v.uv * 2 - 1, 0, -1));
				output.viewVector = mul(unity_CameraToWorld, float4(viewVector,0));
				return output;
			}

			Texture3D<float4> NoiseTex;
			Texture3D<float4> DetailNoiseTex;
			Texture2D<float4> BlueNoise;
			
			SamplerState samplerNoiseTex;
			SamplerState samplerDetailNoiseTex;
			SamplerState samplerBlueNoise;

			sampler2D _MainTex;
			sampler2D _CameraDepthTexture;
			sampler2D _LastCameraDepthTexture;

			float4 params;
			float densityMultiplier;
			float densityOffset;
			float scale;
			float detailNoiseScale;
			float detailNoiseWeight;
			float3 detailWeights;
			float4 shapeNoiseWeights;
			float4 phaseParams;

			float innerShellRadius;
			float outerShellRadius;

			float animSpeed;

			int numStepsLight;
			int numStepsMain;
			float minMainStepSize;
			float rayOffsetStrength;

			float3 shapeOffset;
			float3 detailOffset;

			float lightAbsorptionTowardSun;
			float lightAbsorptionThroughCloud;
			float darknessThreshold;
			float4 _LightColor0;
			float3 dirToSun;

			float2 squareUV(float2 uv) {
				float width = _ScreenParams.x;
				float height =_ScreenParams.y;
				float scale = 1000;
				float x = uv.x * width;
				float y = uv.y * height;
				return float2 (x/scale, y/scale);
			}

			float2 raySphere(float3 sphereCentre, float sphereRadius, float3 rayOrigin, float3 rayDir) {
				float3 offset = rayOrigin - sphereCentre;
				float a = 1;
				float b = 2 * dot(offset, rayDir);
				float c = dot (offset, offset) - sphereRadius * sphereRadius;
				float d = b * b - 4 * a * c;

				if (d > 0) {
					float s = sqrt(d);
					float dstToSphereNear = max(0, (-b - s) / (2 * a));
					float dstToSphereFar = (-b + s) / (2 * a);

					if (dstToSphereFar >= 0) {
						return float2(dstToSphereNear, dstToSphereFar - dstToSphereNear);
					}
				}
				static const float maxFloat = 3.402823466e+38;
				return float2(maxFloat, 0);
			}

			float2 rayShellInfo(float3 rayPos, float3 rayDir) {
				float2 innerSphereHitInfo = raySphere(0, innerShellRadius, rayPos, rayDir);
				float2 outerSphereHitInfo = raySphere(0, outerShellRadius, rayPos, rayDir);
				float dstToInnerSphere = innerSphereHitInfo.x;
				float dstThroughInnerSphere = innerSphereHitInfo.y;
				float dstToOuterSphere = outerSphereHitInfo.x;
				float dstThroughOuterSphere = outerSphereHitInfo.y;
				float dstFromCentre = length(rayPos - 0);

				float dstToShell = 0;
				float dstThroughShell = 0;

				if (dstFromCentre > outerShellRadius) {
					dstToShell = dstToOuterSphere;
					dstThroughShell = (dstThroughInnerSphere > 0) ? dstToInnerSphere - dstToOuterSphere : dstThroughOuterSphere;
				}
				else if (dstFromCentre > innerShellRadius) {
					dstToShell = 0;
					dstThroughShell = (dstThroughInnerSphere > 0) ? dstToInnerSphere : dstThroughOuterSphere;
				}
				else {
					dstToShell = dstThroughInnerSphere;
					dstThroughShell = dstThroughOuterSphere - dstThroughInnerSphere;
				}

				return float2(dstToShell, dstThroughShell);
			}

			

			float hg(float a, float g) {
				float g2 = g*g;
				return (1-g2) / (4*3.1415*pow(1+g2-2*g*(a), 1.5));
			}

			float phase(float a) {
				float blend = .5;
				float hgBlend = hg(a,phaseParams.x) * (1-blend) + hg(a,-phaseParams.y) * blend;
				return phaseParams.z + hgBlend*phaseParams.w;
			}

			float beer(float d) {
				float beer = exp(-d);
				return beer;
			}

			float remap(float v, float minOld, float maxOld, float minNew, float maxNew) {
				return minNew + (v-minOld) * (maxNew - minNew) / (maxOld-minOld);
			}

			float remap01(float v, float low, float high) {
				return (v-low)/(high-low);
			}


			float sampleDensity(float3 rayPos) {
				const int mipLevel = 0;
				const float baseScale = 1 / 1000.0;

				float finalDensity = 0;

				float3 uvw = rayPos * baseScale * scale;
				float3 shapeSamplePos = uvw + (shapeOffset + float3(_Time.x, 0, 0) * animSpeed) * 0.001;
				
				float gMin = 0.2;
				float gMax = 0.7;
				float heightPercent = (length(rayPos) - innerShellRadius) / (outerShellRadius - innerShellRadius);
			
				float heightGradient = saturate(heightPercent/gMin) * saturate((1-heightPercent)/(1-gMax));
	
				float4 shapeNoise = NoiseTex.SampleLevel(samplerNoiseTex, shapeSamplePos, mipLevel);
				float4 normalizedShapeWeights = shapeNoiseWeights / dot(shapeNoiseWeights, 1);
				float shapeFBM = dot(shapeNoise, normalizedShapeWeights) * heightGradient;
				float baseShapeDensity = shapeFBM + densityOffset * 0.1;

				if (baseShapeDensity > 0) {
					float3 detailSamplePos = uvw*detailNoiseScale + detailOffset;
					float4 detailNoise = DetailNoiseTex.SampleLevel(samplerDetailNoiseTex, detailSamplePos, mipLevel);
					float3 normalizedDetailWeights = detailWeights / dot(detailWeights, 1);
					float detailFBM = dot(detailNoise, normalizedDetailWeights);

					float oneMinusShape = 1 - shapeFBM;
					float detailErodeWeight = oneMinusShape * oneMinusShape * oneMinusShape;
					float cloudDensity = baseShapeDensity - (1-detailFBM) * detailErodeWeight * detailNoiseWeight;
			
					finalDensity = cloudDensity * densityMultiplier * 0.1;
				}

				return finalDensity;
			}

			float lightmarch(float3 rayOrigin) {
	
				float dstThroughShellToSun = raySphere(0, outerShellRadius, rayOrigin, dirToSun).y;
				
				float stepSize = dstThroughShellToSun / numStepsLight;
				float totalDensity = 0;

				for (int step = 0; step < numStepsLight; step ++) {
					rayOrigin += dirToSun * stepSize;
					float density = sampleDensity(rayOrigin);
					totalDensity += max(0, density);
				}

				float transmittance = exp(-totalDensity * stepSize * lightAbsorptionTowardSun);
				return darknessThreshold + transmittance * (1-darknessThreshold);
			}

			float4 march(float3 rayPos, float3 rayDir, float distance, float transmittance, float3 lightEnergy) {

				float cosAngle = dot(rayDir, dirToSun);
				float phaseVal = phase(cosAngle);

				float dstLimit = distance;
				float dstTravelled = 0;

				float stepSize = (distance) / (numStepsMain - 1);
				stepSize = max(minMainStepSize, stepSize);

				while (dstTravelled < distance) {
				
					float density = sampleDensity(rayPos);
					
					if (density > 0) {
						float lightTransmittance = lightmarch(rayPos);
						lightEnergy += density * stepSize * transmittance * lightTransmittance * phaseVal;
						transmittance *= exp(-density * stepSize * lightAbsorptionThroughCloud);
					
						if (transmittance < 0.01) {
							break;
						}
					}
					dstTravelled += stepSize;
					rayPos += rayDir * stepSize;
				}

				return float4(lightEnergy, transmittance);
			}

		
			float4 frag (v2f i) : SV_Target
			{
				float3 camPos = _WorldSpaceCameraPos;
				float viewLength = length(i.viewVector);
				float3 rayDir = i.viewVector / viewLength;
				
				float nonlin_depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv);
				float geometryDepth = LinearEyeDepth(nonlin_depth) * viewLength;

				float waterDepthNonLinear = SAMPLE_DEPTH_TEXTURE(_LastCameraDepthTexture, i.uv);
				float waterDepth = LinearEyeDepth(waterDepthNonLinear) * length(i.viewVector);

				float depth = min(geometryDepth, waterDepth);


				float2 shellHitinfo = rayShellInfo(camPos, rayDir);
				float dstToShell = shellHitinfo.x;
				float dstThroughShell = min(shellHitinfo.y, depth - dstToShell);

			
				if (dstThroughShell > 0) {
					float randomOffset = BlueNoise.SampleLevel(samplerBlueNoise, squareUV(i.uv*3), 0) * rayOffsetStrength;
					float3 shellEntryPoint = camPos + rayDir * (dstToShell + randomOffset);
					
					float transmittance = 1;
					float3 lightEnergy = 0;
					
					float4 lightInfo = march(shellEntryPoint, rayDir, dstThroughShell - randomOffset, transmittance, lightEnergy);
					lightEnergy = lightInfo.xyz;
					transmittance = lightInfo.w;

					float3 rayExitPoint = shellEntryPoint + rayDir * (dstThroughShell + 0.1);
					shellHitinfo = rayShellInfo(rayExitPoint, rayDir);
					dstToShell = shellHitinfo.x;
					dstThroughShell = min(shellHitinfo.y, depth - length(camPos - rayExitPoint) - dstToShell);

					if (dstThroughShell > 0) {
						shellEntryPoint = rayExitPoint + rayDir * (dstToShell + randomOffset);
						lightInfo = march(shellEntryPoint, rayDir, dstThroughShell - randomOffset, transmittance, lightEnergy);
						lightEnergy = lightInfo.xyz;
						transmittance = lightInfo.w;
					}

					float lightIntensity = 1.25;
					float3 cloudCol = lightEnergy * lightIntensity;
					return float4(cloudCol, transmittance);
				}
				return float4(0, 0, 0, 1);
			}

			ENDCG
		}
	}
}