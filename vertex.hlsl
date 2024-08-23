struct VS_INPUT {
    float4 position: POSITION0;
    float2 texcoord: TEXCOORD0;
    float4 normal: NORMAL0;
    float4 tangent: TANGENT0;
    int4 joints: BLENDINDICES0;
    float4 weights: BLENDWEIGHT0;
    float4 color: COLOR0;
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
    output.texcoord = input.texcoord;
    output.normal = normalize(mul(uMatrixWV, input.normal).xyz);
    output.tangent = normalize(mul(uMatrixWV, input.tangent).xyz);
    output.worldpos = mul((uMatrixW), input.position).xyz;
    
    //output.normal.z = -output.normal.z;
    //output.ipos = float4(uMatrixWV._41,uMatrixWV._42,uMatrixWV._43,1.0);

    if (uHasVertexColor<0.5) input.color = float4(1,1,1,1);
    
    output.color = input.color * uBaseColor;

    return output;
}