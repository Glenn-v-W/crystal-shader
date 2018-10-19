//************
// VARIABLES *
//************
cbuffer cbPerObject
{
	float4x4 m_MatrixWorldViewProj : WORLDVIEWPROJECTION;
	float4x4 m_MatrixWorld : WORLD;
	float3 m_LightDir={0.2f,-1.0f,0.2f};
}

RasterizerState FrontCulling 
{ 
	CullMode = NONE; 
	//FillMode = WireFrame;
};

BlendState gBS_EnableBlending 
{     
	BlendEnable[0] = TRUE;
	SrcBlend = SRC_ALPHA;
    DestBlend = INV_SRC_ALPHA;
};


SamplerState samLinear
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Wrap;// of Mirror of Clamp of Border
    AddressV = Wrap;// of Mirror of Clamp of Border
};

//Texture2D m_TextureDiffuse;
Texture2D m_TextureDiffuse
<
	string UIName = "Diffuse Texture";
	string UIWidget = "Texture";
	string ResourceName = "TexturesCom_2.5x2.5_A_CaveRock_1024_albedo.tif";
>;

Texture2D m_TextureCrystalHeight
<
	string UIName = "Crystal Height Map";
	string UIWidget = "Texture";
	//string ResourceName = "Crystal_CD.jpg";
	string ResourceName = "CobbleStone_HeightMap.dds";
>;

float m_Sides
<
	string UIName = "Sides";
	string UIWidget = "slider";
	float UIMin = 3;
	float UIMax = 7;
	float UIStep = 1;
> = float(6);

float m_BotRadius
<
	string UIName = "Base Radius";
	string UIWidget = "slider";
	float UIMin = 0;
	float UIMax = 2;
	float UIStep = 0.01;
> = float(1);

float m_TopRadius
<
	string UIName = "Top Radius";
	string UIWidget = "slider";
	float UIMin = 0;
	float UIMax = 2;
	float UIStep = 0.01;
> = float(1);

float m_TopHeight
<
	string UIName = "Top Height";
	string UIWidget = "slider";
	float UIMin = 0;
	float UIMax = 1;
	float UIStep = 0.01;
> = float(0.25);

float m_SizeMultiplier
<
	string UIName = "Size Multiplier";
	string UIWidget = "slider";
	float UIMin = 0;
	float UIMax = 10;
	float UIStep = 0.01;
> = float(5);


float m_MinSize
<
	string UIName = "Min Size";
	string UIWidget = "slider";
	float UIMin = 0;
	float UIMax = 1;
	float UIStep = 0.01;
> = float(0);

float3 m_TopCrystalColor
<
	string UIName = "Top Color";
	string UIWidget = "Color";
> = float3(1,0,0);

float3 m_BotCrystalColor
<
	string UIName = "Bottom Color";
	string UIWidget = "Color";
> = float3(0,0,1);

float m_BlendFactor
<
	string UIName = "Blend Factor";
	string UIWidget = "slider";
	float UIMin = 0;
	float UIMax = 1;
	float UIStep = 0.01;
> = float(0.5);

float m_Opacity
<
	string UIName = "Opacity";
	string UIWidget = "slider";
	float UIMin = 0;
	float UIMax = 1;
	float UIStep = 0.01;
> = float(1);


//**********
// STRUCTS *
//**********
struct VS_DATA
{
	float3 Position : POSITION;
	float3 Normal : NORMAL;
    float2 TexCoord : TEXCOORD;
};

struct GS_DATA
{
	float4 Position : SV_POSITION;
	float3 Normal : NORMAL;
	float2 TexCoord : TEXCOORD0;
	float4 CrystalColor: COLOR0;
};

//****************
// VERTEX SHADER *
//****************
VS_DATA MainVS(VS_DATA vsData)
{
	return vsData;
}

//******************
// GEOMETRY SHADER *
//******************
void CreateVertex(inout TriangleStream<GS_DATA> triStream, float3 pos, float3 normal, float2 texCoord, float4 color)
{
	GS_DATA temp = (GS_DATA)0;
	temp.Position = mul(float4(pos,1),m_MatrixWorldViewProj);
	temp.Normal = mul(normal, (float3x3)m_MatrixWorld);
	temp.TexCoord = texCoord;
	temp.CrystalColor = color;
	triStream.Append(temp);
}

float3 RotatePointAroundVector(float3 pointToRotate, float3 vectorToRotateAround, float3 locationOfVector,  float degrees)
{
	float3 v = pointToRotate;
	float3 k = normalize(vectorToRotateAround);
	
	return (v * cos(degrees) + cross(k,v) * sin(degrees) + k * dot(k,v) * (1-cos(degrees)));	
}

[maxvertexcount(78)]
void SpikeGenerator(triangle VS_DATA vertices[3], inout TriangleStream<GS_DATA> triStream)
{
	
	//Create Existing Geometry
	CreateVertex(triStream,vertices[0].Position,vertices[0].Normal,vertices[0].TexCoord, float4(0,0,0,0));
	CreateVertex(triStream,vertices[1].Position,vertices[1].Normal,vertices[1].TexCoord, float4(0,0,0,0));
	CreateVertex(triStream,vertices[2].Position,vertices[2].Normal,vertices[2].TexCoord, float4(0,0,0,0));
	//Restart the strip so we can add another (independent) triangle!
	triStream.RestartStrip();

	 
	
	//Calculate the height of the crystal	
	float sampledCrystalHeight[3];
	sampledCrystalHeight[0] = m_TextureCrystalHeight.SampleLevel( samLinear,vertices[0].TexCoord , 0).r;
	sampledCrystalHeight[1] = m_TextureCrystalHeight.SampleLevel( samLinear,vertices[1].TexCoord , 0).r;
	sampledCrystalHeight[2] = m_TextureCrystalHeight.SampleLevel( samLinear,vertices[2].TexCoord , 0).r;
	
	float crystalHeightScale = 7;
	float crystalHeight = (sampledCrystalHeight[0] + sampledCrystalHeight[1] + sampledCrystalHeight[2])/3 / crystalHeightScale;

	crystalHeight -= m_MinSize;

	if(crystalHeight > 0)
	{
	float3 crystalVertex[200]; //max number of sides supported is 100 (100*2+1) (2 verts per sides + top vert)

	
	
	//Step 1. Calculate The basePoint of the Crystal
	float3 crystalBaseCenterPoint = (vertices[0].Position + vertices[1].Position + vertices[2].Position) / 3;
	//Step 2. Calculate The normal of the basePoint
	float3 crystalBaseNormal = (vertices[0].Normal + vertices[1].Normal + vertices[2].Normal) / 3;
	//Step 3. Calculate The Cryastal spike's Base Point & Top  Point
	float crystalSpikeRatio = 1-m_TopHeight;
	float3 crystalSpikeCenterPoint = crystalBaseCenterPoint + (crystalSpikeRatio * m_SizeMultiplier * crystalHeight * crystalBaseNormal);
	float3 crystalSpikeTopPoint = crystalBaseCenterPoint + (m_SizeMultiplier * crystalHeight * crystalBaseNormal);
	
	
	
	
	//Step 4. Calculate The Crystal Base Points
		//4.1 Vector between the Center of the Base of the Crystal and vertex[0] 
		//of the triangle this crystal is on
	float3 centerBaseTo0 = normalize(vertices[0].Position - crystalBaseCenterPoint);
	float crystalBottomRadius = crystalHeight * m_BotRadius;	
	crystalVertex[0] = crystalBaseCenterPoint + centerBaseTo0 * crystalBottomRadius;
		
		//4.2 Now we use crystalVertex[0], and rotate it around the crZystalBaseNormal 
		//by 360/numSides to get the other base points
	int index = 1;
	while(index < m_Sides) 
	{
	float angle = 360.0 / m_Sides * index * 3.14 / 180;
    crystalVertex[index] = RotatePointAroundVector(crystalVertex[0], crystalBaseNormal, crystalBaseCenterPoint, angle);
	++index;
   	}
	
	
	
	
	//Step 5. Calculate The Crystal Spike Points
		//5.1 Calculate the first point, which is crystalSpikeCenterPoint * centerBaseTo0
	float crystalTopRadius = crystalHeight * m_TopRadius;	
	crystalVertex[m_Sides] = crystalSpikeCenterPoint + centerBaseTo0 * crystalTopRadius;
		
		//5.2 Now we use crystalVertex[m_Sides], and rotate it around the crystalBaseNormal 
		//by 360/numSides to get the other base points
	index = 1;
	while(index < m_Sides) 
	{
	float angle = 360.0 / m_Sides * index * 3.14 / 180;
     crystalVertex[index+m_Sides] = RotatePointAroundVector(crystalVertex[m_Sides], crystalBaseNormal, crystalSpikeCenterPoint, angle);
	 ++index;
   	}
	
	
	
	//Set Crystal Colors
	float4 topColor;
	float4 botColor;

	if(m_BlendFactor == 0.5)
	{
		topColor = float4(m_TopCrystalColor, 1);
		botColor = float4(m_BotCrystalColor, 1);
	}
	else if(m_BlendFactor > 0.5)
	{
		topColor =  float4(m_TopCrystalColor, 1);
		botColor = float4(m_BotCrystalColor, 1) + (float4(m_TopCrystalColor, 1) - float4(m_BotCrystalColor, 1)) *((m_BlendFactor-0.5)*2);
	}
	else
	{
		topColor = float4(m_BotCrystalColor, 1) + (float4(m_TopCrystalColor, 1) - float4(m_BotCrystalColor, 1)) *((m_BlendFactor)*2);
		botColor = float4(m_BotCrystalColor, 1);
	}
	
	//Create Crystal-Spike Geometry
	
	index = 0;
	while(index <= m_Sides) 
	{	
		
	int index1 = index;
	int index2 = index;
	int index3 = index-1;
	
	if(index1 >= m_Sides)
	{
		index1-=m_Sides;
	}
	if(index1 < 0)
	{
		index1+=m_Sides;
	}
	if(index2 >= m_Sides)
	{
		index2-=m_Sides;
	}
	if(index2 < 0)
	{
		index2+=m_Sides;
	}
	if(index3 >= m_Sides)
	{
		index3-=m_Sides;
	}
	if(index3 < 0)
	{
		index3+=m_Sides;
	}
	
	float3 surfaceNormal;
	surfaceNormal = -cross((crystalVertex[index1]-crystalVertex[index2+m_Sides]), (crystalVertex[index3]-crystalVertex[index2+m_Sides]));
	
	CreateVertex(triStream, crystalVertex[index1], surfaceNormal, float2(0,0), botColor);
	CreateVertex(triStream, crystalVertex[index2+m_Sides], surfaceNormal, float2(0,0), topColor);
	CreateVertex(triStream, crystalVertex[index3], surfaceNormal, float2(0,0), botColor);
	triStream.RestartStrip();
		
	index1 = index;
	index2 = index-1;
	index3 = index-1;
	
	if(index1 >= m_Sides)
	{
		index1-=m_Sides;
	}
	if(index1 < 0)
	{
		index1+=m_Sides;
	}
	if(index2 >= m_Sides)
	{
		index2-=m_Sides;
	}
	if(index2 < 0)
	{
		index1+=m_Sides;
	}
	if(index3 >= m_Sides)
	{
		index3-=m_Sides;
	}
	if(index3 < 0)
	{
		index1+=m_Sides;
	}
	
	surfaceNormal = -cross((crystalVertex[index1+m_Sides]-crystalVertex[index2+m_Sides]), (crystalVertex[index3]-crystalVertex[index2+m_Sides]));

	CreateVertex(triStream, crystalVertex[index1+m_Sides], surfaceNormal, float2(0,0), topColor);
	CreateVertex(triStream, crystalVertex[index2+m_Sides], surfaceNormal, float2(0,0), topColor);
	CreateVertex(triStream, crystalVertex[index3], surfaceNormal, float2(0,0), botColor);
	triStream.RestartStrip(); 
	
	index1 = index;
	index3 = index-1;	
	if(index1 >= m_Sides)
	{
		index1-=m_Sides;
	}
	if(index1 < 0)
	{
		index1+=m_Sides;
	}
	if(index3 >= m_Sides)
	{
		index3-=m_Sides;
	}
	if(index3 < 0)
	{
		index3+=m_Sides;
	}
	
	surfaceNormal = -cross((crystalVertex[index1+m_Sides]-crystalSpikeTopPoint), (crystalVertex[index3+m_Sides]-crystalSpikeTopPoint));

	CreateVertex(triStream, crystalVertex[index1+m_Sides], surfaceNormal, float2(0,0), topColor);
	CreateVertex(triStream, crystalSpikeTopPoint, surfaceNormal, float2(0,0), topColor);
	CreateVertex(triStream, crystalVertex[index3+m_Sides], surfaceNormal, float2(0,0), topColor);
	triStream.RestartStrip();
	
	++index;
   	}
	
	}
}

//***************
// PIXEL SHADER *
//***************
float4 MainPS(GS_DATA input) : SV_TARGET 
{
	float alpha;
	float3 color;
	if(input.CrystalColor.x == 0 && input.CrystalColor.y == 0 && input.CrystalColor.z == 0 && input.CrystalColor.w == 0)
	{
		//This pixel is a part of the mesh
	input.Normal=-normalize(input.Normal);
	alpha = m_TextureDiffuse.Sample(samLinear,input.TexCoord).a;
	color = m_TextureDiffuse.Sample( samLinear,input.TexCoord ).rgb;
	}
	else	
	{
		//This pixel is a part of the crystals
	input.Normal=-normalize(input.Normal);
	alpha = m_Opacity;
	color = input.CrystalColor.xyz;
	}
	
	float s = max(dot(m_LightDir,input.Normal), 0.4f);

	return float4(color*s,alpha);

}


//*************
// TECHNIQUES *
//*************
technique10 DefaultTechnique 
{
	pass p0 {
		SetRasterizerState(FrontCulling);	
		SetBlendState(gBS_EnableBlending,float4(0.0f, 0.0f, 0.0f, 0.0f), 0xFFFFFFFF);
		SetVertexShader(CompileShader(vs_4_0, MainVS()));
		SetGeometryShader(CompileShader(gs_4_0, SpikeGenerator()));
		SetPixelShader(CompileShader(ps_4_0, MainPS()));
	}
}

