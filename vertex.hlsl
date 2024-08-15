float4x4 rMatrixW, rMatrixWVP;
float4x4 rJointMatrix[32];
bool rSkinEnabled;

struct VS_INPUT {
    float3 normal: NORMAL;
    float3 tangent: TANGENT0;
    float4 position: POSITION0;
    float2 texcoord: TEXCOORD0;
    int4 joints: BLENDINDICES0;
    float4 weights: BLENDWEIGHT0;
};

struct VS_OUTPUT {
    float4 position: POSITION0;
    float2 texcoord: TEXCOORD0;
    //float4 light_col_front: COLOR0;
    //float4 light_col_back: COLOR1;
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
    output.texcoord = input.texcoord;

    return output;
}