float4x4 tW : WORLD;

Texture2D texRGB <string uiname="RGB";>;
Texture2D texDepth <string uiname="Depth";>;
Texture2D texRayTable <string uiname="RayTable";>;
Texture2D texRGBDepth <string uiname="RGBDepth";>;
int drawIndex : DRAWINDEX;
int IdOffset;
float2 FOV;
float2 Resolution;
bool useRayTable;
bool useRawData;

SamplerState sPoint : IMMUTABLE
{
    Filter = MIN_MAG_MIP_POINT;
    AddressU = Border;
    AddressV = Border;
};

#include "_PointData.fxh"
AppendStructuredBuffer<pointData> pcBuffer : BACKBUFFER;

//==============================================================================
//COMPUTE SHADER ===============================================================
//==============================================================================

[numthreads(8, 8, 1)]
void CSBuildPointcloudBuffer( uint3 i : SV_DispatchThreadID )
{
	uint w,h, dummy;
	texDepth.GetDimensions(0,w,h,dummy);
	if (i.x >= asuint(Resolution.x) || i.y >= asuint(Resolution.y)) { return; }
	
	float2 coord = i.xy * float2(w / Resolution.x, h / Resolution.y) / float2(w,h);
	float depth =  texDepth.SampleLevel(sPoint, coord,0 ).r * 65.535 ;

	if (depth > 0){
		
		
		float4 pos = float4(0,0,0,1);
		// calculate worldposition		
		if (useRayTable){
			float2 raytable =  texRayTable.SampleLevel(sPoint,coord,0).xy;
			pos.x = depth * raytable.x * -1;
			pos.y = depth * raytable.y;
			pos.z = depth;
		}
		else{
			float XtoZ = tan(FOV.x/2) * 2;
		    float YtoZ = tan(FOV.y/2) * 2;
			pos.x = ((coord.x - 0.5) * depth * XtoZ * -1);
			pos.y = ((0.5 - coord.y) * depth * YtoZ);		
			pos.z = depth;
		}
		
		pos = mul(pos, tW);
		
		// sample color
		float2 map = texRGBDepth.SampleLevel(sPoint,coord,0).rg;
		if(useRawData){
			map.x /= 1920.0f;
			map.y /= 1080.0f;
		}
		float4 col = texRGB.SampleLevel(sPoint,map,0);
		
		pointData pd = {pos.xyz, col, drawIndex + IdOffset};
		pcBuffer.Append(pd);
	}
}

//==============================================================================
//TECHNIQUES ===================================================================
//==============================================================================

technique11 BuildPointcloudBuffer
{
	pass P0
	{
		SetComputeShader( CompileShader( cs_5_0, CSBuildPointcloudBuffer() ) );
	}
}
