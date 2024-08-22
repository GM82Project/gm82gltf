struct VS_INPUT {
    float4 normal: NORMAL;
    float4 position: POSITION0;
    float2 texcoord_base: TEXCOORD0;
    float2 texcoord_occ: TEXCOORD1;
    float2 texcoord_norm: TEXCOORD2;
    float2 texcoord_rough: TEXCOORD3;
    float2 texcoord_emi: TEXCOORD4;
    float4 color: COLOR0;
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
    float4 normal: TEXCOORD5;
    float4 wpos: TEXCOORD6;
    float4 ipos: TEXCOORD7;
    float4 color: COLOR0;
};

matrix uMatrixW, uMatrixWV, uMatrixWVP;
matrix uJointMatrix[32];
float  uSkinEnabled;
float  uHasVertexColor;
float4 uBaseColor;

VS_OUTPUT main(VS_INPUT input) {
	VS_OUTPUT output;

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

    output.texcoord_base = input.texcoord_base;
    output.texcoord_occ = input.texcoord_occ;
    output.texcoord_norm = input.texcoord_norm;
    output.texcoord_rough = input.texcoord_rough;
    output.texcoord_emi = input.texcoord_emi;

    output.normal = mul(uMatrixWV, input.normal);
    output.normal.z = -output.normal.z;

    output.wpos = mul((uMatrixW), input.position);
    output.ipos = float4(uMatrixWV._41,uMatrixWV._42,uMatrixWV._43,1.0);

    if (uHasVertexColor<0.5) input.color = float4(1,1,1,1);
    
    output.color = input.color * uBaseColor;

    return output;
}