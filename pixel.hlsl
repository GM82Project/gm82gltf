SamplerState rBaseTexture: register(s0);
SamplerState rNormTexture;
SamplerState rEmissiveTexture;
SamplerState rOccTexture;
SamplerState rRoughTexture;
float4 rBaseColor;

float bNormalMap_enabled;
float bEmissiveMap_enabled;
float bOcclusionMap_enabled;
float bRoughnessMap_enabled;

struct PS_INPUT {
    float2 texcoord_base: TEXCOORD0;
    float2 texcoord_occ: TEXCOORD1;
    float2 texcoord_norm: TEXCOORD2;
    float2 texcoord_rough: TEXCOORD3;
    float2 texcoord_emi: TEXCOORD4;
    float4 color: COLOR0;
};

struct PS_OUTPUT {
    float4 color: COLOR0;
};

PS_OUTPUT main(PS_INPUT input) {
    PS_OUTPUT output;

    float4 albedo = tex2D(rBaseTexture, input.texcoord_base);
    float4 emissive = tex2D(rEmissiveTexture, input.texcoord_base);
    float4 occlusion = tex2D(rOccTexture, input.texcoord_base).r;
    
    float4 temp = tex2D(rRoughTexture, input.texcoord_base);
    float rough = temp.g;
    float metal = temp.b;

    temp = albedo * input.color;

    if (bEmissiveMap_enabled) temp += emissive;

    //temp, correct is occlusion multiplies ambient color  
    if (bOcclusionMap_enabled) temp *= occlusion;
    
    output.color = temp * rBaseColor;
    
    return output;
}