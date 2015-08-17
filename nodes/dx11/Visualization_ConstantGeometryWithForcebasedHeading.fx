//@author: tmp
//@help: Draws a PointCloud
//@tags: DX11.Pointcloud
//@credits: vvvv


#include "_PointData.fxh"
StructuredBuffer<pointData> pcBuffer;

#include "_ForceData.fxh"
StructuredBuffer<forceData> forceBuffer<String uiname="ForceBuffer";>;
StructuredBuffer<uint> indexBuffer<String uiname="ForceIndexBuffer";>;

cbuffer cbPerDraw : register( b0 )
{
	float4x4 tVP : VIEWPROJECTION;
};

cbuffer cbPerObj : register( b1 )
{
	float4x4 tW : WORLD;
	int groupFilter;
	float forceContrast=0.5;
};

float4 cAmb <bool color=true;String uiname="Color";> = { 1.0f,1.0f,1.0f,1.0f };

struct vsInput
{
	float4 pos : POSITION;
	uint ii : SV_InstanceID;
};

struct vs2ps
{
	float4 pos: SV_POSITION;
	float4 col: COLOR;
	float4 col_pos : TEXCOORD0;
	float4 col_group : TEXCOORD1;
	float4 col_group_force : TEXCOORD2;
	float4 col_force : TEXCOORD3;
};

float3 HUEtoRGB(in float H)
{
	float R = abs(H * 6 - 3) - 1;
	float G = 2 - abs(H * 6 - 2);
	float B = 2 - abs(H * 6 - 4);
	return saturate(float3(R,G,B));
}
float3 HSVtoRGB(in float3 HSV)
{
	float3 RGB = HUEtoRGB(HSV.x);
	return ((RGB - 1) * HSV.y + 1) * HSV.z;
}
float Epsilon = 1e-10;

float3 RGBtoHCV(in float3 RGB)
{
	// Based on work by Sam Hocevar and Emil Persson
	float4 P = (RGB.g < RGB.b) ? float4(RGB.bg, -1.0, 2.0/3.0) : float4(RGB.gb, 0.0, -1.0/3.0);
	float4 Q = (RGB.r < P.x) ? float4(P.xyw, RGB.r) : float4(RGB.r, P.yzx);
	float C = Q.x - min(Q.w, Q.y);
	float H = abs((Q.w - Q.y) / (6 * C + Epsilon) + Q.z);
	return float3(H, C, Q.x);
}

/* ===================== VERTEX SHADER ===================== */

float4 randColor(in float id) {
	float noiseX = (frac(sin(dot(float2(id,id), float2(12.9898,78.233) 	 )) * 43758.5453));
	float noiseY = (frac(sin(dot(float2(id,id), float2(12.9898,78.233) * 2.0)) * 43758.5453));
	float noiseZ = sqrt(1 - noiseX * noiseX);
	return float4(noiseX, noiseY,noiseZ,1);
}

vs2ps VS(vsInput input)
{
	vs2ps output = (vs2ps)0;
	
	uint idx = input.ii;
	uint idf = indexBuffer[idx];
	//Rotation Matrix
	
	static const float PI = 3.14159265f;
	//normalize
	float velX = forceBuffer[idf].velocity.x;
	float velY = forceBuffer[idf].velocity.y;
	float velZ = forceBuffer[idf].velocity.z;
	
	float length = sqrt(velX*velX + velY*velY  + velZ*velZ); //length
	float nVelX = velX;
	float nVelY = velY;
	float nVelZ = velZ;
	
	if (length != 0)
	{
		nVelX = velX / length;
		nVelY = velY / length;
		nVelZ = velZ / length;
	}
	
	//converter
	float conv = (2 * PI);
	float3 rotationV;
	
	//CONVERT FROM POLAR TO CARTESIAN VVVV-STYLE
	float lengthPol = nVelX * nVelX + nVelY * nVelY + nVelZ * nVelZ;
	
	if (lengthPol > 0)
	{
		lengthPol = sqrt(lengthPol);
		float pitch = asin(nVelY / lengthPol);
		float yaw = 0.0;
		if(nVelZ != 0)
		yaw = atan2(-nVelX, -nVelZ);
		else if (nVelX > 0)
		yaw = -PI / 2;
		else
		yaw = PI / 2;
		
		rotationV = float3(pitch, yaw, lengthPol) / conv ;
	}
	
	else
	
	{
		rotationV = float3(0,0,0);
	}
	
	rotationV*= 2*PI;
	
	float sx = sin(rotationV.x);
	float cx = cos(rotationV.x);
	float sy = sin(rotationV.y);
	float cy = cos(rotationV.y);
	float sz = sin(rotationV.z);
	float cz = cos(rotationV.z);
	
	float4x4 RotationMatrix = float4x4(	 cz*cy+sz*sx*sy, sz*cx, cz*-sy+sz*sx*cy, 0,
	-sz*cy+cz*sx*sy, cz*cx, sz*sy+cz*sx*cy , 0,
	cx * sy       ,-sx   , cx * cy        , 0,
	0             , 0    , 0              , 1);
	
	float4 p = input.pos;
	p = mul(p,RotationMatrix); //Rotate the model
	
	// apply groupfilter
	if (groupFilter != pcBuffer[idx].groupId && groupFilter != -1) p.w = 0.0f;
	p.xyz += pcBuffer[idx].pos.xyz;
	output.pos = mul(p,mul(tW,tVP));
	
	output.col = pcBuffer[idx].col;
	output.col_pos = float4(pcBuffer[idx].pos,1);
	output.col_group = randColor(pcBuffer[idx].groupId);
	output.col_group_force = randColor(forceBuffer[idf].groupId);
	
	// LOAD ADDITIONAL DATA from the extension of the pointcloud buffer
	//uint idf = indexBuffer[idx];
	output.col_force = float4(forceBuffer[idf].velocity , 1) * 100; // the data of the RWStructuredBuffer
	
	return output;
}



/* ===================== PIXEL SHADER ===================== */

float4 PS_RGB(vs2ps input): SV_Target
{
	float4 col = input.col * cAmb;
	return col;
}

float4 PS_POS(vs2ps input): SV_Target
{
	return input.col_pos * cAmb;
}

float4 PS_GROUP(vs2ps input): SV_Target
{
	return input.col_group * cAmb;
}

float4 PS_GROUP_FORCE(vs2ps input): SV_Target
{
	return input.col_group_force * cAmb;
}

float4 PS_FORCE(vs2ps input): SV_Target
{
	return input.col_force * cAmb;
}

float4 PS_FORCEADVANCED(vs2ps input): SV_Target
{
	//return input.col_force * cAmb;
	
	float4 forceclr = input.col_force;
	float forcepwr = (abs(forceclr.x)+abs(forceclr.y)+abs(forceclr.z))/3;
	float4 hsva = float4(HSVtoRGB(float3(0,1-(forcepwr/100),pow(forcepwr,6)/100000)),1);
	return hsva * cAmb;
}

/* ===================== TECHNIQUE ===================== */

technique10 RGB
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_4_0, VS() ) );
		SetPixelShader( CompileShader( ps_4_0, PS_RGB() ) );
	}
}

technique10 Position
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_4_0, VS() ) );
		SetPixelShader( CompileShader( ps_4_0, PS_POS() ) );
	}
}

technique10 GroupId
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_4_0, VS() ) );
		SetPixelShader( CompileShader( ps_4_0, PS_GROUP() ) );
	}
}

technique10 GroupIdForce
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_4_0, VS() ) );
		SetPixelShader( CompileShader( ps_4_0, PS_GROUP_FORCE() ) );
	}
}

technique10 Force
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_4_0, VS() ) );
		SetPixelShader( CompileShader( ps_4_0, PS_FORCE() ) );
	}
}

technique10 ForceAdvanced
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_4_0, VS() ) );
		SetPixelShader( CompileShader( ps_4_0, PS_FORCEADVANCED() ) );
	}
}