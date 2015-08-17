#include "_ForceData.fxh"
RWStructuredBuffer<forceData> rwForceBuffer : BACKBUFFER;

int groupId = -1;

float4x4 tVP;

SamplerState volumeSampler // : IMMUTABLE
{
	Filter  = MIN_MAG_MIP_LINEAR;
	AddressU = Border;
	AddressV = Border;
	AddressW = Border;
};
Texture3D VolumeTexture3D ;

bool Apply;

float3 fieldPower = 1;

[numthreads(64, 1, 1)]
void CS_Apply( uint3 i : SV_DispatchThreadID)
{
	uint cnt, stride;
	rwForceBuffer.GetDimensions(cnt,stride);
	if (i.x >= cnt) { return; }
	
	if(Apply){
		
		float4 p = mul(float4(rwForceBuffer[i.x].position,1), tVP);
		
		float4 c =  VolumeTexture3D.SampleLevel(volumeSampler,((p.xyz+1)/2),0);
		//p =(c.xyz)*fieldPower;
		p =c*float4(fieldPower,1);
		
		if ( groupId == -1 || rwForceBuffer[i.x].groupId == groupId){
			
			rwForceBuffer[i.x].acceleration += p.xyz*.0005;
			
		}
		
	}
	
}

technique11 ApplyForce
{
	pass P0
	{
		SetComputeShader( CompileShader( cs_5_0, CS_Apply() ) );
	}
}
