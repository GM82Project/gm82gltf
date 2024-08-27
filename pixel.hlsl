SamplerState uBaseTexture: register(s0);
SamplerState uNormTexture;
SamplerState uEmissiveTexture;
SamplerState uOccTexture;
SamplerState uRoughTexture;
SamplerState uEnvMap;

matrix uMatrixV;

float uNormalMap_enabled;
float uEmissiveMap_enabled;
float uOcclusionMap_enabled;
float uRoughnessMap_enabled;
float3 uEyePos;


//game maker lighting
    float4 uLightColor[8];
    float4 uLightPosRange[8];
    float4 uLightDirection[8];

    float  uLightingEnabled;
    float4 uAmbientColor;

    float4 uFogSettings; //x=enabled y=start z=rcprange
    float4 uFogColor;

    float4 doFog(float3 wpos, float3 ipos, float4 color) {
        return lerp(color, uFogColor, saturate((distance(wpos,ipos) - uFogSettings.y) * uFogSettings.z));
    }

    float4 doPointLight(float3 wpos, float3 normal, float4 posrange, float4 color) {
        float3 diffvec = wpos - posrange.xyz;
        float len = length(diffvec);        
        float atten = posrange.w / len;
        
        if (len > posrange.w) {
            atten = 0.0;
        }
        
        return (saturate(dot(-normal, diffvec/len)) * atten) * color;
    }

    float4 doLighting(float4 color, float3 wpos, float3 normal, float4 ambient, float metal, float rough, float3 eyevector, float4 environment) {
        float4 diffuse = ambient;
        float4 specular = float4(0,0,0,0);            

        for (int i = 0; i < 8; i++) {
            float3 dir = -normalize(uLightDirection[i].xyz);
        
            diffuse += saturate(dot(normal,dir)) * uLightColor[i];
            specular += (1.0-0.9*rough) * pow(max(dot(reflect(dir,normal),eyevector), 0.0), 200.0/(1.0+rough*100.0)) * uLightColor[i];    

            //accumcol += doPointLight(wpos, normal, uLightPosRange[i], uLightColor[i]);
        }

        diffuse = lerp(diffuse,diffuse*lerp(environment,ambient,rough),metal);

        return saturate(diffuse) * color + saturate(specular) * color.a;
    }
//end game maker lighting

struct PS_INPUT {
    float2 texcoord: TEXCOORD0;
    float3 normal: TEXCOORD1;
    float3 tangent: TEXCOORD2;
    float3 worldpos: TEXCOORD3;
    float4 color: COLOR0;
};

struct PS_OUTPUT {
    float4 color: COLOR0;
};

PS_OUTPUT main(PS_INPUT input) {
    PS_OUTPUT output;

    //diffuse
    float4 albedo = tex2D(uBaseTexture, input.texcoord);
    float4 emissive = tex2D(uEmissiveTexture, input.texcoord);
    float4 occlusion = tex2D(uOccTexture, input.texcoord).r;


    //normals
    float3 inormnorm = normalize(input.normal);
    float3 itangnorm = normalize(input.tangent);
    float3 binormal = normalize(cross(inormnorm,itangnorm));
    float3 finormal = inormnorm;

    float3 normap = tex2D(uNormTexture, input.texcoord).rgb * 2 - 1;
    if (uNormalMap_enabled>0.5) finormal = normalize(itangnorm * normap.r + binormal * normap.g + inormnorm * normap.b);
    float3 eyevector = normalize(input.worldpos - uEyePos);
    
    
    //metalrough
    float4 color = tex2D(uRoughTexture, input.texcoord);
    float rough = color.g;
    float metal = color.b;
    
    if (uRoughnessMap_enabled<0.5) {
        rough = 0.0;
        metal = 0.0;
    }
    
    float4 environment = tex2D(uEnvMap, normalize(mul(uMatrixV,float4(finormal,0.0))).xy*float2(0.5,-0.5)+0.5);
    
    
    //finalize
    color = albedo * input.color;
    
    if (uOcclusionMap_enabled<0.5) occlusion=float4(1.0,1.0,1.0,1.0);
    
    if (uLightingEnabled>0.5) color = doLighting(color, input.worldpos, finormal, uAmbientColor * occlusion, metal, rough, eyevector, environment);
    
    if (uEmissiveMap_enabled>0.5) color = saturate(color+emissive);

    //if (uFogSettings.x) color = doFog(input.worldpos.xyz, uEyePos, color);

    output.color = color;

    return output;
}