/**
 * Yorick Cobb
 * 2018
 * With help from many sources
 * Technically, I think the government owns this code.
 */

Shader "YCMatcapSpec"
{
	Properties
	{
		_MainTex ("Albedo (RGBA) (Alpha controls lighting)", 2D) = "white" {}
		_Normalia ("Normal Map", 2D) = "bump" {}
		_LightTex ("Lights (RGBA)", 2D) = "black" {}
      	_RimPower ("Rim Power", Range(0.0,1.0)) = 0.5
      	_RimWidth ("Rim Width", Range(0,1.0)) = 0.2

	}
	SubShader
	{
		Tags { "RenderType" = "Opaque" }

		Pass
		{
			CGPROGRAM
			//declare our vertex shader function will be called 'vert'
			#pragma vertex vert
			//declare our fragment shader function will be called 'frag'
			#pragma fragment frag
			//this tells the compiler to add in some fog stuff I think
			#pragma multi_compile_fog

			
			#include "UnityCG.cginc"

			struct v2f //this struct is the OUTPUT of vert()
			{
				half4 vertex : SV_POSITION;
				half3 normal : NORMAL;
				half4 tangent : TANGENT;
                half2 cap : TEXCOORD0;
				half2 uv : TEXCOORD1;
				UNITY_FOG_COORDS(2)
				float2 depth : TEXCOORD3;
				//3x3 matrix for bringing normals into tangent space
				half3 tspace0 : TEXCOORD4;
                half3 tspace1 : TEXCOORD5;
                half3 tspace2 : TEXCOORD6;
				//used for rim light calculations
				float dotProduct : TEXCOORD7;	//keep
				//preserve world-space coordinates even when the frag shaders puts us in clip-space
				float3 pos : TEXCOORD8;

			};

			sampler2D _MainTex;
			//sampler2D _ShadowTex;
			sampler2D _LightTex;
			sampler2D _Normalia;

			float _RimPower;
			float _RimWidth;

			half4 _MainTex_ST;

			uniform half4 _Normalia_ST;

			//this function takes the vertex* and gives us a fragment holding its data
			//		*nearest vertex? hypothetical vertex?
			//		-SEEMS like I misunderstood how it's executed - looks like this part runs once
			//			per vertex instead of once per pixel
			//		-The v2f struct, which could be called vertexOutput, defines all the
			//			data this function should calculate
			//		-Here, vert() is receiving a struct of type appdata_full, but you can define
			//			a struct such as vertexInput to pare down the data (for optimization)
			v2f vert (appdata_full v)
			{
				//struct to pass out
				v2f o;
				
				//some initial data that we know won't change between here and the frag shader
				o.pos = v.vertex.xyz;
                o.normal = v.normal;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.texcoord, _Normalia);
				UNITY_TRANSFER_FOG(o,o.vertex);
				UNITY_TRANSFER_DEPTH(o.depth);
				
				
				//--Calculate Dot Product for the Rim Light
				//		Direction from the vertex to the camera? Or vice-versa (not persp correct)
				half3 viewDir = normalize(ObjSpaceViewDir(v.vertex));
				//		Basically, how close is this surface to being perpendicular to the camera
				//		(Higher value = closer)
                o.dotProduct = 1 - dot(v.normal, viewDir);
				
				
				//--Calculate 3x3 Rotation Matrix
				//		This aligns the tangent-space normals to the surface, rather than naively
				//		interpreting them in upright camera space like I did initially
				half3 wNormal = UnityObjectToWorldNormal(v.normal);
                half3 wTangent = UnityObjectToWorldDir(v.tangent.xyz);
                half tangentSign = v.tangent.w * unity_WorldTransformParams.w;
                half3 wBitangent = cross(wNormal, wTangent) * tangentSign;
				o.tspace0 = half3(wTangent.x, wBitangent.x, wNormal.x);
                o.tspace1 = half3(wTangent.y, wBitangent.y, wNormal.y);
                o.tspace2 = half3(wTangent.z, wBitangent.z, wNormal.z);

				
				return o;
			}
			


			//this function processes the fragment data generated in v2f
			fixed4 frag (v2f i) : SV_Target
			{
				
				//Initial stuff
				fixed4 mainCol = tex2D(_MainTex, i.uv);
				
				
				
				
				//As early as possible: don't waste time on calculations if we're going to discard the fragment or shade it flat black
				//if (mainCol.a < 0.5) discard;
				//if (length(float3(mainCol.xyz)) < 0.02) return float4(0, 0, 0, 1);
				
				//Calculate fog here (stored in variable fogCol)
				fixed4 fogCol = {1, 1, 1, 1};
				UNITY_APPLY_FOG(i.fogCoord, fogCol);
				
				
			
			
			
				//--Apply Normals
				//		Unpack them (this is the bit where it swizzles, I believe)
				half3 tnormal = UnpackNormal(tex2D(_Normalia, i.uv));
				//tnormal now holds the tangent-space normal
				half3 worldNormal;
				
				worldNormal.x = dot(i.tspace0, tnormal);
                worldNormal.y = dot(i.tspace1, tnormal);
                worldNormal.z = dot(i.tspace2, tnormal);
				
				
				
				//correct perspective for those normals
				float3 worldNorm = UnityObjectToWorldNormal(i.normal);
                float3 viewNorm = mul((float3x3)UNITY_MATRIX_V, worldNormal);
				
				
				
				//debug statement:
				//return float4(viewNorm.x * 0.5 + 0.5, viewNorm.y * 0.5 + 0.5, viewNorm.z * 0.5 + 0.5, 1);
				
				float3 viewPos = UnityObjectToViewPos(i.pos);
				float3 viewDir = normalize(viewPos);
				
				
				
				// get vector perpendicular to both view direction and view normal
                float3 viewCross = cross(viewDir, viewNorm);
			   
				// swizzle perpendicular vector components to create a new perspective corrected view normal
				viewNorm = float3(-viewCross.y, viewCross.x, 0.0);
				
				//matcap coordinates
				i.cap = viewNorm.xy * 0.5 + 0.5;
				
				
				
				float avgColor = (mainCol.r + mainCol.g + mainCol.b)/3;
				float sat = pow(1 - sqrt(pow(mainCol.r - avgColor, 2) + pow(mainCol.g - avgColor, 2) + pow(mainCol.b - avgColor, 2)), 3.5) / 2;
				//sat = 0;
				
				
				//can I do the rim lighting here, right before the swizzle
                half3 rimCol = 2*smoothstep(1 - _RimWidth, 1.0, i.dotProduct);
                rimCol *= float3(0.4, 0.388, 0.2667) * _RimPower;

				half4 lighting = tex2D(_LightTex, i.cap);
				half lightVal = ((lighting.g * mainCol.a) + (lighting.b * (1 - mainCol.a)));
				half shadowVal = ((mainCol.a * lighting.a) + ((1 - mainCol.a) * lighting.r));
				
				
				//return mainCol;
				
				//enable this line to skip lighting calculations:
				//return mainCol;
				
				//enable this line to render screen space normals:
				//return float4(viewNorm.xyz * 0.5 + 0.5, 1);
				
				//apply lighting to the raw albedo
				mainCol *= (half4(
									1 - (((1 - shadowVal) * (1.100 + sat)) + sat/4),						//reduce red component in shadow
									1 - (((1 - shadowVal) * (2.34 - sat)) + sat/4),							//reduce green component in shadow
									1 - (((1 - shadowVal) * (0.835 + sat)) + sat/4),						//reduce blue component in shadow
									1)
					+ abs(half4(rimCol, 1)));
				mainCol *= fogCol;
				
				mainCol += (half4(lightVal * 1.15 * 1.2, lightVal * 1.1 * 1.2, lightVal * 0.7 * 1.2, 1) + (half4(rimCol, 1))) * (1 - (fogCol.a /3));
				mainCol.a = 1;
				
				
				//enable these three lines to render out only the lighting data for the scene:
				//mainCol.r = lighting.a;
				//mainCol.g = lighting.a;
				//mainCol.b = lighting.a;
				

				
                return mainCol;
			}
			ENDCG
		}

	}
	Fallback "Diffuse"
}