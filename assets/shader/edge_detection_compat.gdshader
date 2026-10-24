shader_type spatial;
// Variante von edge_detection.gdshader für den Compatibility-Renderer (Web / WebGL2).
// Unterschiede zum Forward+-Original:
// - Es gibt keinen Normal-Roughness-Buffer: Normalen werden aus dem Tiefenpuffer rekonstruiert.
// - Die Outline-Maske kommt nicht aus ROUGHNESS = 0, sondern aus dem Stencil-Buffer:
//   Materialien, die Stencil-Wert 1 schreiben (z. B. Gras), bekommen keine Outline.
// - OpenGL-Tiefenbereich (-1..1, kein Reverse-Z).
render_mode specular_disabled, ambient_light_disabled, depth_test_disabled;
stencil_mode read, compare_not_equal, 1;

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_nearest;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;

uniform float lightIntensity = 1.25;
uniform float lineAlpha = 0.7;
uniform bool useLighting = true;
uniform float lineHighlight = 0.2;
uniform float lineShadow = 0.55;
// Rekonstruierte Normalen sind facettiert (kein Smooth Shading). Erst ab diesem Knick (1 - cos) gilt
// eine Normalen-Kante, damit runde Low-Poly-Formen keine Linien auf jeder Facette bekommen.
uniform float normalEdgeThreshold : hint_range(0.0, 1.0) = 0.5;

varying vec3 centerNormal;
varying float lineMask;


vec3 GetViewPosition(vec2 sUV, mat4 invProjectionMat){
	float depth = texture(DEPTH_TEXTURE, sUV).x;
	vec3 ndc = vec3(sUV, depth) * 2.0 - 1.0;
	vec4 view = invProjectionMat * vec4(ndc, 1.0);
	return view.xyz / view.w;
}

float GetLinearDepth(vec2 sUV, mat4 invProjectionMat){
	return -GetViewPosition(sUV, invProjectionMat).z;
}

// Normale (View-Space) aus den Nachbarpixeln. Pro Achse wird die Seite mit dem kleineren
// Tiefensprung genommen, damit Kanten nicht in die Normale der Fläche einbluten.
vec3 GetNormal(vec2 uv, vec2 texelSize, mat4 invProjectionMat){
	vec3 c = GetViewPosition(uv, invProjectionMat);
	vec3 r = GetViewPosition(uv + vec2(texelSize.x, 0.0), invProjectionMat);
	vec3 l = GetViewPosition(uv - vec2(texelSize.x, 0.0), invProjectionMat);
	vec3 u = GetViewPosition(uv + vec2(0.0, texelSize.y), invProjectionMat);
	vec3 d = GetViewPosition(uv - vec2(0.0, texelSize.y), invProjectionMat);
	vec3 dx = abs(r.z - c.z) < abs(c.z - l.z) ? r - c : c - l;
	vec3 dy = abs(u.z - c.z) < abs(c.z - d.z) ? u - c : c - d;
	vec3 normal = normalize(cross(dx, dy));
	return normal.z < 0.0 ? -normal : normal; // sichtbare Flächen zeigen zur Kamera
}

float NormalEdgeIndicator(vec3 normalEdgeBias, vec3 normal, vec3 neighborNormal, float depthDifference){
	//From Kody King: https://threejs.org/examples/webgl_postprocessing_pixel.html
	float normalDifference = dot(normal - neighborNormal, normalEdgeBias);
	float normalIndicator = clamp(smoothstep(-.01, .01, normalDifference), 0.0, 1.0);
	float depthIndicator = clamp(sign(depthDifference * .25 + .0025), 0.0, 1.0);
	return (1.0 - dot(normal, neighborNormal)) * depthIndicator * normalIndicator;
}

void vertex(){
	POSITION = vec4(VERTEX.xy, 0.0, 1.0);
}

void fragment() {
	vec2 texelSize = 1.0 / VIEWPORT_SIZE.xy;

	// UV offsets
	vec2 UVOffsets[4];
	UVOffsets[0] = SCREEN_UV + vec2(0.0, -1.0) * texelSize;
	UVOffsets[1] = SCREEN_UV + vec2(0.0, 1.0) * texelSize;
	UVOffsets[2] = SCREEN_UV + vec2(1.0, 0.0) * texelSize;
	UVOffsets[3] = SCREEN_UV + vec2(-1.0, 0.0) * texelSize;

	// Edge detection with Depth
	float depthDifference = 0.0;
	float invDepthDifference = 0.5;
	float depth = GetLinearDepth(SCREEN_UV, INV_PROJECTION_MATRIX);

	for (int i = 0; i < UVOffsets.length(); i++){
		float dOff = GetLinearDepth(UVOffsets[i], INV_PROJECTION_MATRIX);
		depthDifference += clamp(dOff - depth, 0.0, 1.0);
		invDepthDifference += depth - dOff;
	}
	invDepthDifference = clamp(invDepthDifference, 0.0, 1.0);
	invDepthDifference = clamp(smoothstep(0.9, 0.9, invDepthDifference) * 10.0 , 0.0, 1.0);
	depthDifference = smoothstep(0.25, 0.3, depthDifference);

	// Edge detection with Normals
	float normalDifference = 0.;
	vec3 normalEdgeBias = vec3(1.0, 1.0, 1.0);
	vec3 normal = GetNormal(SCREEN_UV, texelSize, INV_PROJECTION_MATRIX);
	centerNormal = normal;

	for (int i = 0; i < UVOffsets.length(); i++){
		vec3 nOff = GetNormal(UVOffsets[i], texelSize, INV_PROJECTION_MATRIX);
		normalDifference += NormalEdgeIndicator(normalEdgeBias, normal, nOff, depthDifference);
	}
	normalDifference = step(normalEdgeThreshold, normalDifference);
	normalDifference = clamp(normalDifference - invDepthDifference, 0.0, 1.0);


	ALBEDO = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
	lineMask = clamp(0.1, lineAlpha, (depthDifference + normalDifference * 5.0));


	if (!useLighting){
		ALBEDO += clamp((normalDifference - depthDifference), 0.0, 1.0) * lineHighlight;
		ALBEDO -= ALBEDO * depthDifference * lineShadow;
	}
}

void light (){
	if (useLighting){
		// Calculate light direction
		float dotNL = dot(centerNormal, LIGHT);
		dotNL = pow(dotNL, 2.5);
		dotNL = clamp(dotNL, 0.0, 1.0);

		if(LIGHT_IS_DIRECTIONAL)
			DIFFUSE_LIGHT += mix(vec3(1.0), dotNL * LIGHT_COLOR * lightIntensity, lineMask);
	}
	else
		DIFFUSE_LIGHT = vec3(1.0);
}
