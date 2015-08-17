#include "_ForceData.fxh"
RWStructuredBuffer<forceData> rwForceBuffer : BACKBUFFER;

float miny = 0.0f;
bool Apply;
bool Bounce;
int groupId = -1;

//==============================================================================
//COMPUTE SHADER ===============================================================
//==============================================================================

[numthreads(64, 1, 1)]
void CS_Apply( uint3 i : SV_DispatchThreadID)
{
	uint cnt, stride;
	rwForceBuffer.GetDimensions(cnt,stride);
	if (i.x >= cnt) { return; }
	
	if (Apply) {
		if ( groupId == -1 || rwForceBuffer[i.x].groupId == groupId){
			
			if (rwForceBuffer[i.x].position.y < miny)
			{
				rwForceBuffer[i.x].position.y = miny;
				if (Bounce) rwForceBuffer[i.x].velocity.y *= -1;
			}
			
			
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




