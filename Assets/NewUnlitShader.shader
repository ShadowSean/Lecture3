Shader "Unlit/FirstShaderMultiUV"
{
    Properties
    {
       _myColor ("Sample Color", Color) = (1,1,1,1)
       _myRange ("Sample Range", Range(0.5)) = 1
       _myTex   ("Sample Texture", 2D) = "White" {}
       _myCube  ("Sample Cube", CUBE) = "" {}
       _myFloat ("Sample Float", Float) = 0.5
       _myVector("Sample vector", Vector) = (0.5,1,1,1)
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" "RenderPipeline"="UniversalRenderPipeline" } 
        LOD 200

        Pass
        {
            Name "UnLit" // (Sampling only; no lighting here)
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            // If you had UV set switching:
            // #pragma shader_feature_local _UVSET_UV0 _UVSET_UV1

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // ===== Vertex I/O =====
            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv0        : TEXCOORD0; 
            };

            struct Varyings
            {
               float4 positionHCS : SV_POSITION;
               float3 positionWS  : TEXCOORD0;
               float3 normalWS    : TEXCOORD1;
               float2 uv          : TEXCOORD2;
            };

            TEXTURE2D(_myTex);
            SAMPLER(sampler_myTex);

            TEXTURECUBE(_myCube);
            SAMPLER(sampler_myCube);

            CBUFFER_START(UnityPerMaterial)
                float4 _myColor;
                float  _myRange;
                float  _myFloat;
                float4 _myVector;
            CBUFFER_END


            Varyings vert (Attributes IN)
            {
                Varyings OUT;

                // World space position & normal
                float3 posWS = TransformObjectToWorld(IN.positionOS.xyz);
                float3 nrmWS = TransformObjectToWorldNormal(IN.normalOS);

                OUT.positionWS  = posWS;
                OUT.normalWS    = nrmWS;
                OUT.positionHCS = TransformWorldToHClip(posWS);

                // UV selection (only uv0 for now)
                OUT.uv = TRANSFORM_TEX(IN.uv0, _myTex);


                return OUT;
            }

            // ===== Fragment =====
            half4 frag (Varyings IN) : SV_Target
            {
                // Base Layer
                half3 texCol = SAMPLE_TEXTURE2D(_myTex, sampler_myTex, IN.uv).rgb;
                half3 albedo = texCol * _myRange * _myColor.rgb;

                // View direction (WS)
                float3 N = SafeNormalize(IN.normalWS);
                float3 V = SafeNormalize(GetWorldSpaceViewDir(IN.positionWS));


                //Simple lambert main light 
                Light mainLight = GetMainLight();
                float NdotL = saturate(dot(N,mainLight.direction));
                half3 diffuse = albedo * mainLight.color.rgb * NdotL;

                // Ambient from SH (like Unity's baked ambient)
                half3 ambient = SampleSH(N) * albedo;

                // --- Emission from cubemap using world reflection (surface Input.worldRefl equivalent)
                float3 R = reflect(-V,N);
                half3 env = SAMPLE_TEXTURECUBE(_myCube, sampler_myCube, R).rgb;

                env *= _myFloat;
                env *= _myVector.xyz;

                //Final color = diffuse + ambient + emission 
                half3 color = diffuse + ambient + env;

                return half4(color,1);

            }
            ENDHLSL
        }
    }

    FallBack Off
}
