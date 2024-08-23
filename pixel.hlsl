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

    float4 doDirLight(float3 normal, float3 dir, float4 color) {
        return (saturate(dot(normalize(normal), normalize(dir))) * color);
    }

    float4 doPointLight(float3 wpos, float3 normal, float4 posrange, float4 color) {
        float3 diffvec = wpos - posrange.xyz;
        float len = length(diffvec);        
        float atten = posrange.w / len;
        
        if (len > posrange.w) {
            atten = 0.0;
        }
        
        return (saturate(dot(normal, diffvec/len)) * atten) * color;
    }

    float4 doLighting(float4 color, float3 wpos, float3 normal, float4 ambient) {
        float4 accumcol = ambient;

        for (int i = 0; i < 8; i++) {
            accumcol += doDirLight(normal, uLightDirection[i].xyz, uLightColor[i]);
            accumcol += doPointLight(wpos, normal, uLightPosRange[i], uLightColor[i]);
        }

        return saturate(accumcol) * color;
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

SamplerState uBaseTexture: register(s0);
SamplerState uNormTexture;
SamplerState uEmissiveTexture;
SamplerState uOccTexture;
SamplerState uRoughTexture;

float uNormalMap_enabled;
float uEmissiveMap_enabled;
float uOcclusionMap_enabled;
float uRoughnessMap_enabled;
float3 uEyePos;

PS_OUTPUT main(PS_INPUT input) {
    PS_OUTPUT output;

    //diffuse
    float4 albedo = tex2D(uBaseTexture, input.texcoord);
    float4 emissive = tex2D(uEmissiveTexture, input.texcoord);
    float4 occlusion = tex2D(uOccTexture, input.texcoord).r;


    //metalrough
    float4 color = tex2D(uRoughTexture, input.texcoord);
    float rough = color.g;
    float metal = color.b;
    
    
    //normals
    float3 inormnorm = normalize(input.normal);
    float3 itangnorm = normalize(input.tangent);
    float3 binormal = normalize(cross(itangnorm,inormnorm));
    float3 finormal = inormnorm;

    float3 normap = tex2D(uNormTexture, input.texcoord).rgb * 2 - 1;
    if (uNormalMap_enabled>0.5) finormal = normalize(itangnorm * normap.r + binormal * normap.g + inormnorm * normap.b);
    
    
    //finalize
    color = albedo * input.color;
    
    if (uOcclusionMap_enabled<0.5) occlusion=float4(1.0,1.0,1.0,1.0);
    
    if (uLightingEnabled>0.5) color = doLighting(color, input.worldpos, finormal, uAmbientColor * occlusion);
    
    if (uEmissiveMap_enabled>0.5) color = saturate(color+emissive)* occlusion;

    //if (uFogSettings.x) color = doFog(input.worldpos.xyz, uEyePos, color);

    output.color = color;

    return output;
}