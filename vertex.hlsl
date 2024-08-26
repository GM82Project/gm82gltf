#define MAX_JOINTS 32
#define MAX_MORPHS 3

struct VS_INPUT {
    float4 position: POSITION0;
    float2 texcoord: TEXCOORD0;
    float4 normal: NORMAL0;
    float4 tangent: TANGENT0;
    int4 joints: BLENDINDICES0;
    float4 weights: BLENDWEIGHT0;
    float4 color: COLOR0;
    float3 position_morph[MAX_MORPHS]: POSITION1;
    float3 normal_morph[MAX_MORPHS]: NORMAL1;
    float3 tangent_morph[MAX_MORPHS]: TANGENT1;
};

struct VS_OUTPUT {
    float4 position: POSITION0;
    float2 texcoord: TEXCOORD0;
    float3 normal: TEXCOORD1;
    float3 tangent: TEXCOORD2;
    float3 worldpos: TEXCOORD3;
    float4 color: COLOR0;
};

matrix uMatrixW, uMatrixWV, uMatrixWVP;
matrix uJointMatrix[MAX_JOINTS];
float  uSkinEnabled;
float  uMorphWeights[MAX_MORPHS];
int    uMorphCount;
float  uHasVertexColor;
float4 uBaseColor;

VS_OUTPUT main(VS_INPUT input) {
	VS_OUTPUT output;

    for (int i = 0; i < uMorphCount; i++) {
        input.position.xyz += input.position_morph[i] * uMorphWeights[i];
        input.normal.xyz += input.normal_morph[i] * uMorphWeights[i];
        input.tangent.xyz += input.tangent_morph[i] * uMorphWeights[i];
    }

    if (uSkinEnabled) {
        matrix skin_mtx =
            uJointMatrix[input.joints.x] * input.weights.x +
            uJointMatrix[input.joints.y] * input.weights.y +
            uJointMatrix[input.joints.z] * input.weights.z +
            uJointMatrix[input.joints.w] * input.weights.w;
        
        input.position = mul(skin_mtx, input.position);
        input.normal = mul(skin_mtx, input.normal);
    }

    output.position = mul(uMatrixWVP, input.position);  
    output.texcoord = input.texcoord;
    output.normal = normalize(mul(uMatrixW, float4(input.normal.xyz,0.0)).xyz);
    output.tangent = normalize(mul(uMatrixW, float4(input.tangent.xyz,0.0)).xyz);
    output.worldpos = mul(uMatrixW, input.position).xyz;

    if (uHasVertexColor<0.5) input.color = float4(1,1,1,1);
    
    output.color = input.color * uBaseColor;

    return output;
}