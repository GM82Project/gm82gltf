float4x4 rMatrixW, rMatrixWVP;
float4x4 rJointMatrix[32];
bool rSkinEnabled;

struct VS_INPUT {
    float3 normal: NORMAL;
    float3 tangent: TANGENT0;
    float4 position: POSITION0;
    float2 texcoord_base: TEXCOORD0;
    float2 texcoord_occ: TEXCOORD1;
    float2 texcoord_norm: TEXCOORD2;
    float2 texcoord_rough: TEXCOORD3;
    float2 texcoord_emi: TEXCOORD4;
    int4 joints: BLENDINDICES0;
    float4 weights: BLENDWEIGHT0;
};

struct VS_OUTPUT {
    float4 position: POSITION0;
    float2 texcoord_base: TEXCOORD0;
    float2 texcoord_occ: TEXCOORD1;
    float2 texcoord_norm: TEXCOORD2;
    float2 texcoord_rough: TEXCOORD3;
    float2 texcoord_emi: TEXCOORD4;
};

VS_OUTPUT main(VS_INPUT input) {
	VS_OUTPUT output;

    if (rSkinEnabled) {
        float4x4 skin_mtx =
            rJointMatrix[input.joints.x] * input.weights.x +
            rJointMatrix[input.joints.y] * input.weights.y +
            rJointMatrix[input.joints.z] * input.weights.z +
            rJointMatrix[input.joints.w] * input.weights.w;
        input.position = mul(skin_mtx, input.position);
        input.normal = mul(skin_mtx, float4(input.normal, 0)).xyz;
    }

    output.position = mul(rMatrixWVP, input.position);
    output.texcoord_base = input.texcoord_base;
    output.texcoord_occ = input.texcoord_occ;
    output.texcoord_norm = input.texcoord_norm;
    output.texcoord_rough = input.texcoord_rough;
    output.texcoord_emi = input.texcoord_emi;

    return output;
}